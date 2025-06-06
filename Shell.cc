
#include <unistd.h>
#include <cstdio>
#include <signal.h>
#include <sys/wait.h>



#include "Command.hh"
#include "Shell.hh"

#define MAX_VARNAME 1024

int yyparse(void);


Shell * Shell::TheShell;

Shell::Shell() {
    this->_level = 0;
    this->_enablePrompt = true;
    this->_listCommands = new ListCommands(); 
    this->_simpleCommand = new SimpleCommand();
    this->_pipeCommand = new PipeCommand();
    this->_currentCommand = this->_pipeCommand;
    if ( !isatty(0)) {
	this->_enablePrompt = false;
    }
    this->_inWhile = false;
    this->_inFor = false;

}

void Shell::prompt() {
    if (_enablePrompt) {
      //to print the prompt at the beginning of line
        printf("myshell>");	
	fflush(stdout);
    }
}

void Shell::print() {
    printf("\n--------------- Command Table ---------------\n");
    this->_listCommands->print();
}

void Shell::clear() {
    this->_listCommands->clear();
    this->_simpleCommand->clear();
    this->_pipeCommand->clear();
    this->_currentCommand->clear();
    this->_level = 0;
    this->_bgPid.clear();
}

void Shell::execute() {
  if (this->_level == 0 ) {
    //this->print();
    this->_listCommands->execute();
    if(this->_inWhile == false  && this->_inFor == false) {
      this->_listCommands->clear();
      this->prompt();
    }
  }
}

void yyset_in (FILE *  in_str );

extern "C" void ctrc_handler(int sig) {
  fprintf( stderr, "\n");
  (void)(sig); // suppress unused parameter warning
  //Shell::TheShell->clear();
  Shell::TheShell->prompt();
}

extern "C" void zombie_handler(int sig) {

  (void)(sig); // suppress unused parameter warning
  //int pid = wait3(0, 0, NULL);
  int pid = waitpid(-1, 0, WNOHANG);
  while(waitpid(-1, 0, WNOHANG) > 0)
    {
      // do nothingh
    } 
  
  for(unsigned i = 0; i < Shell::TheShell->_bgPid.size(); i++) {
    if(pid == Shell::TheShell->_bgPid[i]) {
      fprintf(stdout, "[%d] exited.\n", pid);
      break;
    }    
  }   
}





int 
main(int argc, char **argv) {
  
  // Signal Handling Ctrl-C
  // The sa_flags has to be SA_RESTART to
  // avoid "input in flex scanner failed" error
  struct sigaction sa;
  sa.sa_handler = ctrc_handler;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;

  if(sigaction(SIGINT, &sa, NULL)){
    perror("sigaction");
    exit(1);
  }   

  // set argument environment variables
  char argBuff[MAX_VARNAME];
  int numArg = argc - 2;
  sprintf(argBuff, "numArg=%d", numArg);
  putenv(argBuff);

  /*
  char argBuff1[MAX_VARNAME];
  sprintf(argBuff1, "Arg0=%s", argv[1]);
  putenv(argBuff1);
  */
  
  char ** argBuffs = (char **)malloc((argc - 1)*sizeof(char*));
  for(int i = 0; i < argc - 1; i++) {
    argBuffs[i] = (char *)malloc(MAX_VARNAME);
    sprintf(argBuffs[i], "Arg%d=%s", i, argv[i + 1]);
    //printf("%s\n", argBuffs[i]);
    putenv(argBuffs[i]);
  }
  
  char * input_file = NULL;
  if ( argc > 1 ) {
    input_file = argv[1];
    FILE * f = fopen(input_file, "r");
    if (f==NULL) {
	fprintf(stderr, "Cannot open file %s\n", input_file);
        perror("fopen");
        exit(1);
    }

    // set argument environment variables
    
    
    yyset_in(f);
  }  

  Shell::TheShell = new Shell();

  Shell::TheShell->_numArg = argc - 2;

  if (input_file != NULL) {
    // No prompt if running a script
    Shell::TheShell->_enablePrompt = false;
  }
  else {
    Shell::TheShell->prompt();
  }
 
  
  // Signal Handling Zombie process  
  struct sigaction sa2;
  sa2.sa_handler = zombie_handler;
  sigemptyset(&sa2.sa_mask);
  //sa2.sa_flags = SA_RESTART | SA_NOCLDSTOP;
  sa2.sa_flags = SA_RESTART;

  if(sigaction(SIGCHLD, &sa2, NULL)){
    perror("sigaction");
    exit(-1);
  }

  // set "SHELL" as environment variable
  std::string * shellStr = new std::string();
  shellStr->append("SHELL=");
  //printf("argv0 is: %s\n", argv[0]);
  //printf("shellStr is: %s\n", shellStr->c_str());
  char rPath[100];
  realpath(argv[0], rPath);
  shellStr->append(rPath);
  putenv((char *) shellStr->c_str());
  
  // set "pidShell" as environment variable
  std::string * pidStr = new std::string();
  pidStr->append("pidShell=");
  pidStr->append(std::to_string(getpid()));
  putenv((char *) pidStr->c_str());
  
  yyparse();
}


