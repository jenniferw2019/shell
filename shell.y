
/*
 * shell.y: parser for shell
 *
 */

%code requires 
{
#include <string>
#include <cstring>
#include <regex.h>
#include <dirent.h>
#include <algorithm>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN TWOGREAT GREAT GREATGREAT GREATAMPERSAND GREATGREATAMPERSAND 
%token AMPERSAND PIPE LESS NEWLINE IF FI THEN LBRACKET RBRACKET SEMI
%token DO DONE WHILE FOR IN

%{
//#define yylex yylex
 #include <cstdio>
#include "Shell.hh"

#define MAXFILENAME 1024
  
void yyerror(const char * s);
int yylex();
char * buildNewPreStr(char * preStr, char * component);
void convertRegex(char * a, char * r);
void expandWildcardsIfNecessary(std::string * argument);
void expandWildcard(std::string * prefix, std::string * suffix, int & count);


%}

%%
  
goal: command_list;

arg_list:
        arg_list WORD {
	  //Shell::TheShell->_simpleCommand->insertArgument( $2 );

	  // implement wildcard expansion
	  if(strchr($2->c_str(), '*') == NULL
	     && strchr($2->c_str(), '?') == NULL) {
	    // no wildcard
	    Shell::TheShell->_simpleCommand->insertArgument( $2 );
	  }
	  else if(strstr($2->c_str(), "{?}") != NULL) {
	    Shell::TheShell->_simpleCommand->insertArgument( $2 );
	  }
	  else if(strstr($2->c_str(), "{*}") != NULL) {
	    for(int i = 0; i < Shell::TheShell->_numArg; i++) {
	      char tmpStr[MAXFILENAME];
	      sprintf(tmpStr, "Arg%d", i + 1);
	      char * temp = getenv(tmpStr);
	      Shell::TheShell->_simpleCommand->
		insertArgument(new std::string(temp));
	    }
	    //Shell::TheShell->_simpleCommand->insertArgument( $2 );
	  }
 	  else if(strchr($2->c_str(), '/') == NULL) {
	    // expand wildcard in current directory
	    expandWildcardsIfNecessary($2);
	  }
 	  else {
	    // expand wildcard in subdirectory
	    std::string * initPre = new std::string("");
	    int num = 0;
	    expandWildcard(initPre, $2, num);
	    if(num == 0) {
	      Shell::TheShell->_simpleCommand->insertArgument( $2 );
	    }
	  }
	  
	  
	  
	}
        | /*empty string*/
	;

cmd_and_args:
  	WORD { 
          Shell::TheShell->_simpleCommand = new SimpleCommand(); 
          Shell::TheShell->_simpleCommand->insertArgument( $1 );	  
        } 
        arg_list
	;

pipe_list:
        cmd_and_args 
	    { 
		Shell::TheShell->_pipeCommand->insertSimpleCommand( 
		    Shell::TheShell->_simpleCommand ); 
		Shell::TheShell->_simpleCommand = new SimpleCommand();
	    }
	| pipe_list PIPE cmd_and_args 
	    {
	      Shell::TheShell->_pipeCommand->insertSimpleCommand( 
		    Shell::TheShell->_simpleCommand ); 
		Shell::TheShell->_simpleCommand = new SimpleCommand();
	    }
	;

io_modifier:
	   GREATGREAT WORD
	   {
	     Shell::TheShell->_pipeCommand->_append = true;
	     if(Shell::TheShell->_pipeCommand->_outFile == NULL) {	
		Shell::TheShell->_pipeCommand->_outFile = $2;
	      }
	      else {
		fprintf(stderr, "Ambiguous output redirect.\n");
	      }
	   }
	 | GREAT WORD 
	    {
	      if(Shell::TheShell->_pipeCommand->_outFile == NULL) {	
		Shell::TheShell->_pipeCommand->_outFile = $2;
	      }
	      else {
		fprintf(stderr, "Ambiguous output redirect.\n");
	      }
	    }
	 | GREATGREATAMPERSAND WORD
	    {
	      Shell::TheShell->_pipeCommand->_append = true;
	      if(Shell::TheShell->_pipeCommand->_outFile == NULL) {
		Shell::TheShell->_pipeCommand->_outFile = $2;
	      }
	      else {
		fprintf(stderr, "Ambiguous output redirect.\n");
	      }
	      if(Shell::TheShell->_pipeCommand->_errFile == NULL) {
		std::string * str2 = new std::string($2->c_str());
		Shell::TheShell->_pipeCommand->_errFile = str2;
	      }
	      else {
		fprintf(stderr, "Ambiguous output redirect.\n");
	      }	    
	    }
	 | GREATAMPERSAND WORD
	    {
	      if(Shell::TheShell->_pipeCommand->_outFile == NULL) {
		Shell::TheShell->_pipeCommand->_outFile = $2;
	      }
	      else {
		fprintf(stderr, "Ambiguous output redirect.\n");
	      }
	      if(Shell::TheShell->_pipeCommand->_errFile == NULL) {
		std::string * str2 = new std::string($2->c_str());
		Shell::TheShell->_pipeCommand->_errFile = str2;
	      }
	      else {
		fprintf(stderr, "Ambiguous output redirect.\n");
	      }
	    }
         | TWOGREAT WORD
	    {
	      if(Shell::TheShell->_pipeCommand->_errFile == NULL) {
	        Shell::TheShell->_pipeCommand->_errFile = $2;
	      }
	      else {
		fprintf(stderr, "Ambiguous error redirect.\n");
	      }
	    }
	 | LESS WORD
	    {
	      if(Shell::TheShell->_pipeCommand->_inFile == NULL) {
		Shell::TheShell->_pipeCommand->_inFile = $2;
	      }
	      else {
		fprintf(stderr, "Ambiguous in redirect.\n");
	      }
	    }
	;

io_modifier_list:
	io_modifier_list io_modifier
	| /*empty*/
	;

background_optional: 
	AMPERSAND
	{
		Shell::TheShell->_pipeCommand->_background = true;
	}
	| /*empty*/
	;

SEPARATOR:
	NEWLINE
	| SEMI
	;

command_line:
	 pipe_list io_modifier_list background_optional SEPARATOR 
         { 
	    Shell::TheShell->_listCommands->
		insertCommand(Shell::TheShell->_pipeCommand);
	    Shell::TheShell->_pipeCommand = new PipeCommand(); 
         }
        | if_command SEPARATOR 
         {
	    Shell::TheShell->_listCommands->
		insertCommand(Shell::TheShell->_ifCommand);
         }
        | while_command SEPARATOR
	{
	  if(Shell::TheShell->_level == 0) {
	   Shell::TheShell->_listCommands->
		insertCommand(Shell::TheShell->_whileCommand[0]);
	  }
	   //printf("while\n");
	 }
        | for_command SEPARATOR
	{
	  if(Shell::TheShell->_level == 0) {
	    Shell::TheShell->_listCommands->
	      insertCommand(Shell::TheShell->_forCommand[0]);
	  }
	  //printf("for\n");
	}
        | SEPARATOR /*accept empty cmd line*/
        | error SEPARATOR {yyerrok; Shell::TheShell->clear(); }
	;          /*error recovery*/

command_list :
     command_line 
	{ 
	   Shell::TheShell->execute();
	}
     | 
     command_list command_line 
	{
	    Shell::TheShell->execute();
	}
     ;  /* command loop*/

if_command:
    IF LBRACKET 
	{ 
	    Shell::TheShell->_level++; 
	    Shell::TheShell->_ifCommand = new IfCommand();
	} 
    arg_list RBRACKET SEMI THEN 
	{
	    Shell::TheShell->_ifCommand->insertCondition( 
		    Shell::TheShell->_simpleCommand);
	    Shell::TheShell->_simpleCommand = new SimpleCommand();
	}
    command_list FI 
	{ 
	    Shell::TheShell->_level--; 
	    Shell::TheShell->_ifCommand->insertListCommands( 
		    Shell::TheShell->_listCommands);
	    Shell::TheShell->_listCommands = new ListCommands();
	}
    ;

while_command:
    WHILE LBRACKET
    {
      
      Shell::TheShell->_level++;
      if(Shell::TheShell->_level == 1) {
	Shell::TheShell->_whileCommand[0] = new WhileCommand();
	Shell::TheShell->_whileCommand[0]->_wlevel = Shell::TheShell->_level;
	Shell::TheShell->_inWhile = true;
      }
      else {
	int i = Shell::TheShell->_level - 1;
	Shell::TheShell->_whileCommand[i] = new WhileCommand();
	Shell::TheShell->_listCommands_temp[i - 1] = Shell::TheShell->_listCommands;
	Shell::TheShell->_whileCommand[i]->_wlevel = Shell::TheShell->_level;
	Shell::TheShell->_listCommands = new ListCommands();
      }

     
      //Shell::TheShell->_inWhile = true;
      
      
    }
    arg_list RBRACKET SEMI DO
    {
      if(Shell::TheShell->_level == 1) {
	Shell::TheShell->_whileCommand[0]->insertCondition( 
		    Shell::TheShell->_simpleCommand);
	Shell::TheShell->_simpleCommand = new SimpleCommand();
      }
      else {
	int i = Shell::TheShell->_level - 1;
	Shell::TheShell->_whileCommand[i]->insertCondition( 
		    Shell::TheShell->_simpleCommand);
	Shell::TheShell->_simpleCommand = new SimpleCommand();
      }
    }
    command_list DONE
    {
      Shell::TheShell->_level--;
      if(Shell::TheShell->_level == 0) {
	Shell::TheShell->_whileCommand[0]->insertListCommands( 
		    Shell::TheShell->_listCommands);
	Shell::TheShell->_listCommands = new ListCommands();
      }
      else {
	int i = Shell::TheShell->_level;
	Shell::TheShell->_whileCommand[i]->insertListCommands( 
		    Shell::TheShell->_listCommands);
	Shell::TheShell->_listCommands_temp[i - 1]->
		insertCommand(Shell::TheShell->_whileCommand[i]);
	Shell::TheShell->_listCommands = Shell::TheShell->_listCommands_temp[i - 1];
      }
    }
    ;


for_command:
    FOR WORD
    {
      Shell::TheShell->_level++;
      if(Shell::TheShell->_level == 1) {
	Shell::TheShell->_forCommand[0] = new ForCommand();
	Shell::TheShell->_forCommand[0]->_flevel = Shell::TheShell->_level;
	Shell::TheShell->_inFor = true;
          
	Shell::TheShell->_simpleCommand->insertArgument( $2 );
	Shell::TheShell->_forCommand[0]->insertItem( 
		    Shell::TheShell->_simpleCommand);
	Shell::TheShell->_simpleCommand = new SimpleCommand();
      }
      else {
	int i = Shell::TheShell->_level - 1;
	Shell::TheShell->_forCommand[i] = new ForCommand();
	Shell::TheShell->_listCommands_temp[i - 1] = Shell::TheShell->_listCommands;
	Shell::TheShell->_forCommand[i]->_flevel = Shell::TheShell->_level;
	Shell::TheShell->_listCommands = new ListCommands();

	Shell::TheShell->_simpleCommand->insertArgument( $2 );
	Shell::TheShell->_forCommand[i]->insertItem( 
		    Shell::TheShell->_simpleCommand);
	Shell::TheShell->_simpleCommand = new SimpleCommand();
      }
    }
    IN arg_list SEMI DO
    {
      if(Shell::TheShell->_level == 1) {
	Shell::TheShell->_forCommand[0]->insertValueList( 
		    Shell::TheShell->_simpleCommand);
	Shell::TheShell->_simpleCommand = new SimpleCommand();
      }
      else {
	int i = Shell::TheShell->_level - 1;
	Shell::TheShell->_forCommand[i]->insertValueList( 
		    Shell::TheShell->_simpleCommand);
	Shell::TheShell->_simpleCommand = new SimpleCommand();
      }
    }
    command_list DONE
    {
        Shell::TheShell->_level--;
	if(Shell::TheShell->_level == 0) {
	  Shell::TheShell->_forCommand[0]->insertListCommands( 
		    Shell::TheShell->_listCommands);
	  Shell::TheShell->_listCommands = new ListCommands();
	}
	else {
	  int i = Shell::TheShell->_level;
	  Shell::TheShell->_forCommand[i]->insertListCommands( 
		    Shell::TheShell->_listCommands);
	  Shell::TheShell->_listCommands_temp[i - 1]->
	    insertCommand(Shell::TheShell->_forCommand[i]);
	  Shell::TheShell->_listCommands = Shell::TheShell->_listCommands_temp[i - 1];
	}
    }
    ;

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}


char * buildNewPreStr(char * pStr, char * compo)
{
  char * npStr = (char *)malloc(2 * MAXFILENAME);
  if(pStr[0] == '\0') {
    // case1: examples/*, where pre is "", component is "examples"
    // then newPre is pre + component = examples
    
    // case2: /usr/local/* and the first time calling expandWildCard()
    // function, where pre is "", and component is also ""
    // then newPre is pre + / + component = /
    if(compo[0] != '\0') {
      sprintf(npStr, "%s%s", pStr, compo);
    }
    else {
      sprintf(npStr, "%s/%s", pStr, compo);
    }
  }
  else {
    // case 3: where pre is "/", component is "usr"
    // then newPre = pre + component = "/usr"

    // case 4: where pre is "/usr", component is "local"
    // then newPre = pre + / + component = "/usr/local"
    if(pStr[strlen(pStr) - 1] == '/') {
      sprintf(npStr, "%s%s", pStr, compo);
    }
    else {
      sprintf(npStr, "%s/%s", pStr, compo);
    }
  }
  return npStr;  
}


void convertRegex(char * a, char * r)
{
  // convert * to .*
  //         ? to .
  //         . to \.
  // also add ^ at the befinning and $ at the end
  // to match the begining and the end of the word.
  // allocate enough space for regular expression
  
  //match the beginning of the line
  *r = '^';
  r++; 
  while(*a)
    {
      if(*a == '*')
	{
	  *r = '.';
	  r++;
	  *r = '*';
	  r++;
	}
      else if(*a == '?')
	{
	  *r = '.';
	  r++;
	}
      else if(*a == '.')
	{
	  *r = '\\';
	  r++;
	  *r = '.';
	  r++;
	}
      else
	{
	  *r = *a;
	  r++;
	}
      a++;
    }
  //match end of the line and add null char
  *r='$';
  r++;
  *r=0;
}

void expandWildcardsIfNecessary(std::string * argument)
{
  // return if arg contain ${?}, which is environ variable expansion
  if(strstr(argument->c_str(), "${?}") != NULL) {
    Shell::TheShell->_simpleCommand->insertArgument(argument);
    return;
  }

  // 1. convert wildcard to regular expression
  char * arg = (char *)argument->c_str();
  char * reg = (char *)malloc(2*strlen(arg)+10);
  char * a = arg;
  char * r = reg;

  convertRegex(a, r);

  //2. compile regular expression.
  regex_t expbuf;
  int result = regcomp(&expbuf, reg, REG_EXTENDED|REG_NOSUB);
  if(result != 0)
    {
      perror("compile");
      return;
    }

  //3. list directory and add as arguments the entries
  //that match the regular expression
  DIR * dir = opendir(".");
  if(dir == NULL)
    {
      perror("opendir");
      return;
    }
  struct dirent * ent;
  std::vector<std::string> entries;
  while((ent = readdir(dir)) != NULL)
    {
      //check if name matches
      regmatch_t expmatch;     
      if (regexec(&expbuf, ent->d_name, 1, &expmatch, 0) == 0) 
	{
	  //add filename start with "." only if the wildcard
	  //has a "." at the beginning
	  
	  if(ent->d_name[0] == '.')
	    {
	      if(arg[0] == '.')
		{
		  entries.push_back(ent->d_name);
		}
	    }	  
	  else
	    {
	      entries.push_back(ent->d_name);
	    }
	}
    }
  closedir(dir);

  // check if there is no directory entry found,
  // echo the argument with wildcard unexpanded
  if(entries.size() == 0) {
    Shell::TheShell->_simpleCommand->insertArgument(argument);
    return;
  }
    
  
  //sort directory entries
  sort(entries.begin(), entries.end());

   //insert argument
  for(auto & entry : entries)
    {
      std::string *str = new std::string(entry);
      //Command::_currentSimpleCommand->insertArgument(str);
      Shell::TheShell->_simpleCommand->insertArgument(str);
    }
  
} // expandWildcardsIfNecessary


void expandWildcard(std::string * prefix, std::string * suffix, int & count)
{ 
  char * preStr = (char *)prefix->c_str();
  char * sufStr = (char *)suffix->c_str();
  
  // base case
  if(sufStr[0] == '\0') {
    // suffix is empty, put prefix into arguments
    Shell::TheShell->_simpleCommand->insertArgument(prefix);
    count++;
    return;    
  }

  // obtain the next comonent in the suffix
  // and advance suffix
  char * s = strchr(sufStr, '/');
  char component[MAXFILENAME] = "";
  if(s != NULL) {
    if(sufStr[0] != '/') {
      // copy up to the first '/'
      strncpy(component, sufStr, s - sufStr);
      component[strlen(component)] = '\0';
    }
      sufStr = s + 1;
      
  }
  else {
    // last part of path. Copy the whole thing
    strcpy(component, sufStr);
    component[strlen(component)] = '\0';
    sufStr = sufStr + strlen(sufStr);
  }

  // expand the component
  if(strchr(component, '*') == NULL
     && strchr(component, '/') == NULL) {
    // component does not have '*' or '/'

    char * newPreStr = buildNewPreStr(preStr, component);


    /*
    int size = 2 * MAXFILENAME;
    char newPreStr[size] = "";    
    if(preStr[strlen(preStr)-1] == '/') {
      sprintf(newPreStr, "%s%s", preStr, component);
    }
    else {
      sprintf(newPreStr, "%s/%s", preStr, component);
    }
    */
    //sprintf(newPreStr, "%s/%s", preStr, component);
    std::string * newPrefix = new std::string(newPreStr);
    std::string * newSuffix = new std::string(sufStr);
    expandWildcard(newPrefix, newSuffix, count);

    free(newPreStr);
    newPreStr = NULL;
    return;
  }

  // component has wildcards
  // 1. convert component to regular expression
  char * reg = (char *)malloc(2 * strlen(component) + 10);
  char * a = component;
  char * r = reg;

  convertRegex(a, r);

  // 2. compile regular expression.
  regex_t expbuf;
  int result = regcomp(&expbuf, reg, REG_EXTENDED|REG_NOSUB);
  if(result != 0)
    {
      perror("compile");
      return;
    } 

  // 3. list directory and add as arguments the entries
  //that match the regular expression
  char currdir[] = ".";
  char *dir;
  //if prefix is empty then list current directory
  if(preStr[0] == '\0')
     {
      dir = currdir;
    }
  else
    {
      dir = preStr;
    }
  DIR * d = opendir(dir);
  if(d == NULL)
    {
      //perror("opendir");
      return;
    }
  
  // Now we need to check if entries match
  struct dirent * ent;
  std::vector<std::string> entries;
  while((ent = readdir(d)) != NULL)
    {
      regmatch_t expmatch;
      //char newPrefix[MAXFILENAME] = "";
      if(regexec(&expbuf, ent->d_name, 1, &expmatch, 0) == 0)
	{
	  //entry matches
	  //add name of entry that matches to
	  //the prefix into the vector

	  if(ent->d_name[0] == '.') //not display hidden file
	    {
	      continue;
	    }

	  char * newPreStr = buildNewPreStr(preStr, ent->d_name);

	  /*
	  char newPreStr[MAXFILENAME] = "";
	  if(preStr[strlen(preStr)-1] == '/') {
	    sprintf(newPreStr, "%s%s", preStr, ent->d_name);
	  }
	  else {
	    sprintf(newPreStr, "%s/%s", preStr, ent->d_name);
	  }
	  */
	  entries.push_back(newPreStr);
	  free(newPreStr);
	  newPreStr = NULL;
	  
	} //if
      
    } //while

  closedir(d);

  // sort directory entries
  sort(entries.begin(), entries.end());
  // for each newPrefix, call expandWildcard recursively
  for(auto & entry : entries) {
    std::string * newPrefix = new std::string(entry);
    std::string * newSuffix = new std::string(sufStr);
    expandWildcard(newPrefix, newSuffix, count);
  } 

} // expandWildcard


#if 0
main()
{
  yyparse();
}
#endif
