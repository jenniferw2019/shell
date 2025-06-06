#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>

#include <cstdio>
#include <cstdlib>
#include <iostream>

#include "PipeCommand.hh"
#include "Shell.hh"

#define MAX_VAR 1024

extern char * replaceEnVar(char * varStr);
extern char * subShell(char * cmd);
extern char * rmBackTick(char * str);

PipeCommand::PipeCommand() {
    // Initialize a new vector of Simple PipeCommands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _append = false;
}

void PipeCommand::insertSimpleCommand( SimpleCommand * simplePipeCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simplePipeCommand);
}

void PipeCommand::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simplePipeCommand : _simpleCommands) {
        delete simplePipeCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
}

void PipeCommand::print() {
    printf("\n\n");
    //printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple PipeCommands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simplePipeCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simplePipeCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

extern char ** environ;

void printArg(char ** args) {
  if(args != NULL) {
    for(char ** cur = args; *cur != NULL; cur++) {
      printf("%s, ", *cur);
    }
    printf("\n");
  }
}

void PipeCommand::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::TheShell->prompt();
        return;
    }
    

    // if the command word is "exit", quit the shell
    const char * str = _simpleCommands[0]->_arguments[0]->c_str();
    if(strcmp(str, "exit") == 0) {
      fprintf(stdout, "\nGood bye!!\n\n");
      //printf("\nGood bye!!\n");
      clear();
      exit(1);
    }
    

    // Print contents of PipeCommand data structure
    // comment out it for test
    
    //print();

    // save in/out/err
    int tmpin = dup(0);
    int tmpout = dup(1);
    int tmperr = dup(2);

    // set the initial input
    int fdin;
    if(_inFile) {
      fdin = open(_inFile->c_str(), O_RDONLY, 0400);
      if(fdin < 0) {
	fprintf(stderr, "/bin/sh: 1: cannot open %s: No such file\n", _inFile->c_str());
	exit(1);
      }
    }
    else {
      fdin = dup(tmpin);
    }
    
    int ret;
    int fdout;
    int fderr;
    
    for(unsigned long i = 0; i < _simpleCommands.size(); i++) {
      // redirect input
      dup2(fdin, 0);
      close(fdin);  
      
      if(i == _simpleCommands.size() - 1) {
	// last simple command
	// set "argLast" as environment variable
	unsigned long l = _simpleCommands[i]->_arguments.size() - 1;	
	std::string * argStr = new std::string();
	char * tempStr = strdup(_simpleCommands[i]->_arguments[l]->c_str());
	argStr->append("argLast=");
	argStr->append(tempStr);
	putenv((char *)argStr->c_str());
	  

	// setup output and error
	if(_outFile) {
	  if(_append) {
	    fdout = open(_outFile->c_str(), O_WRONLY | O_CREAT | O_APPEND, 0600);
	  }
	  else {
	    fdout = open(_outFile->c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
	  }
	}
	else {
	  // use default output
	  fdout = dup(tmpout);
	}
	
	if(_errFile) {
	  if(_append) {
	    fderr = open(_errFile->c_str(), O_WRONLY | O_CREAT | O_APPEND, 0600);
	  }
	  else {
	    fderr = open(_errFile->c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
	  }
	}
	else {
	  // use default output
	  fderr = dup(tmperr);
	}
	
      }
      else {
	// not last simple command
	// create pipe
	int fdpipe[2];
	pipe(fdpipe);
	fdout = fdpipe[1];
	fdin = fdpipe[0];
      } // if/else

      // redirect output
      dup2(fdout, 1);
      close(fdout);
      // redirect err
      dup2(fderr, 2);
      close(fderr); 
      
      // Convert string * to char **
      const char ** args = (const char **)
	malloc((_simpleCommands[i]->_arguments.size() + 1) * sizeof(char *));

      //_simpleCommands[i]->print();
      
      for(unsigned long j = 0; j < _simpleCommands[i]->_arguments.size(); j++) {
	args[j] = _simpleCommands[i]->_arguments[j]->c_str();
	//printf("args[%ld] is %s ", j, args[j]);
	
	
	if(args[j][0] == '`'
		|| (args[j][0] == '$' && args[j][1] == '(')) {
	  // this is the case of subshell command as argument,
	  // run subshell command and replace with its result

	  char * rmArg = rmBackTick((char *)args[j]);
	  
	  char * nArg = subShell(rmArg);

	  // remove the extra bytes generated by subShell()
	  // at the end of nArg
 	  nArg[strlen(nArg) - strlen("\n\nGood Bye!!\n\n")] = '\0';
	  //printf("nArg is: %s", nArg);
	  
	  args[j] = nArg;
	  //printf("args[%ld] is %s ", j, args[j]);
	}
	else {
	  char * nArg = replaceEnVar((char *)args[j]);
	  args[j] = nArg;
	}
				      
      }
      args[_simpleCommands[i]->_arguments.size()] = NULL;
      //printArg(args);
      

      // Buildin of "setenv", "unsetenv" and "cd"
      if(strcmp(args[0], "setenv") == 0) {
      	char * str = (char *)malloc(strlen(args[1]) + strlen(args[2]) + 2);
	strcpy(str, args[1]);
	strcat(str, "=");
	strcat(str, args[2]);
	//fprintf(stdout, "the env string is: %s\n", str);
	putenv(str);
      }
      else if(strcmp(args[0], "unsetenv") == 0) {
	int len = strlen(args[1]);
	//char ** envptr;
	for(char ** envptr = environ; *envptr != NULL; envptr++) {

	  //printf("entry of envrion: %s\n", *envptr);
	  
	  if(strncmp(args[1], *envptr, len) == 0 && (*envptr)[len] == '=') {
	    //printf("match entry is: %s\n", *envptr);
	    
	    while(*(envptr + 1) != NULL) {
	      
	      *envptr = *(envptr + 1); 
	      envptr++;
	    }
	    envptr = NULL;
	    break;
	  }
	  
	}
      }
      else if(strcmp(args[0], "cd") == 0) {
	if(args[1] == NULL || strcmp(args[1], "~") == 0) { // home derectory
	  char * homeDir = getenv("HOME");
	  chdir(homeDir);
	}
	else {
	  int ret1 = chdir(args[1]);
	  if(ret1 < 0) {
	    fprintf(stderr, "cd: can't cd to %s\n", args[1]);
	  }
	}
      }
      else {
	ret = fork();
	if(ret == 0) { // child process
       	  // Buildin of printenv
	  if(strcmp(args[0], "printenv") == 0) {
	    /*
	    for(char ** envptr = environ; *envptr != NULL; envptr++) {
	      fprintf(stdout, "%s\n", *envptr);
	    }
	    */
	    char ** envptr = environ;
	    while( *envptr != NULL) {
	      fprintf(stdout, "%s\n", *envptr);
	      envptr++;
	    }
	    exit(0); // end child process
	  }
	  else {
	    //printf("%s\n", args[0]);
	    //printf("%s\n", args[1]);
	    execvp(args[0], (char * const *)args);
	    perror("execvp 0:");
	    exit(1);
	  }
	}
	else if(ret < 0) {
	  // error
	  perror("fork");
	  return;
	}
      }

	      
    } // for _simpleCommands

    // restore in/out/err defaults
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperr, 2);
    close(tmpin);
    close(tmpout);
    close(tmperr);

    if(!_background) {
      // wait for last process
      int status;
      std::string * statStr = new std::string();
      waitpid(ret, &status, 0);
      // set "exitStatus" as  enviroment variable
      if(WIFEXITED(status)) {
	statStr->append("exitStatus=");
	statStr->append(std::to_string(WEXITSTATUS(status)));
	//printf("statStr is: %s\n", statStr->c_str());
	putenv((char *)statStr->c_str());      
      }
    }
    else {
      Shell::TheShell->_bgPid.push_back(ret);
      // set "pidBackgd" as  enviroment variable
      std::string * pidStr = new std::string();
      pidStr->append("pidBackgd=");
      pidStr->append(std::to_string(ret));
      //printf("pidStr is: %s\n", pidStr->c_str());
      putenv((char *)pidStr->c_str()); 
    
    }

    // Clear to prepare for next command
    //clear();
    if(Shell::TheShell->_inWhile == false
       && Shell::TheShell->_inFor == false) {
      clear();
    }

    // Print new prompt
    //Shell::TheShell->prompt();
}

// Expands environment vars and wildcards of a SimpleCommand and
// returns the arguments to pass to execvp.
char ** 
PipeCommand::expandEnvVarsAndWildcards(SimpleCommand * simpleCommandNumber)
{
    simpleCommandNumber->print();
    return NULL;
}


