#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <iostream>
#include <regex.h>
#include <unistd.h>
#include <pwd.h>

#include "SimpleCommand.hh"

#define MAX_WORD 1024
#define MAX_NAME 100

extern int exit_status;

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}

void SimpleCommand::insertArgument( std::string * argument ) {
  // environment variable expansion
  const char *pattern = "\\$\\{[^\\}]*\\}";
  const char *currStr = argument->c_str();  
  
  std::string * newStr = new std::string();
  
  char * temp; 

  regex_t re; 
  regmatch_t match;
  
  // Compile the regular expression
  int result = regcomp(&re, pattern, REG_EXTENDED);
  if (result != 0) {
    printf("bad regex\n");
    exit(1);
  }

  
  // Use a loop to find all occurrences of the pattern
  
   while (regexec(&re, currStr, 1, &match, 0) == 0) {
    
    int len = match.rm_eo - match.rm_so - 3;
    
    // Build new string that use value of var to replace ${var}
    // append substring before match
    newStr->append(currStr, match.rm_so);
    // append substring replace match
    if(currStr[match.rm_so + 2] == '$') { // ${$}
      temp = getenv("pidShell");
    }    
    else if(currStr[match.rm_so + 2] == '?') { // ${?}
      temp = getenv("exitStatus");
    }
    else if(currStr[match.rm_so + 2] == '!') { // ${!}
      temp = getenv("pidBackgd");
    }
    else if(currStr[match.rm_so + 2] == '_') { // ${_}
      temp = getenv("argLast");
    }
    else if(currStr[match.rm_so + 2] == '#') { // ${#}
      temp = getenv("numArg");
    }
    else if(currStr[match.rm_so + 2] >= '0'
	    && currStr[match.rm_so + 2] <= '9') { // ${n}
      char varStr[MAX_WORD];
      int varVal = currStr[match.rm_so + 2] - '0';
      sprintf(varStr, "Arg%d", varVal);
      temp = getenv(varStr);
    }
    else {
      char * mStr = (char *)(currStr + match.rm_so + 2);
      char rStr[MAX_WORD];
      strncpy(rStr, mStr, len);
      rStr[len] = '\0';
      temp = getenv(rStr);
    }
    
    // append substring replace match
    // it could be null eg ${?} when no previous command exit
    if(temp != NULL) {
      newStr->append(temp); // the match
    }
    
    // Move to the next part of the string for the next iteration
    currStr = currStr +  match.rm_eo;
  }

  // append substring after match
  newStr->append(currStr); // after match
  
  // Free the compiled regular expression
  regfree(&re);

  // implement tilde expansion and $var
  std::string * finalStr = new std::string();
  currStr = newStr->c_str();
  if(currStr[0] == '~') {
    currStr = currStr + 1;
    if(currStr[0] == '\0') { // case: ~
      finalStr->append(getenv("HOME"));
    }
    else if(currStr[0] == '/') { // case: ~/
      finalStr->append(getenv("HOME"));
      finalStr->append(currStr);
    }
    else {
      char usrName[MAX_NAME];
      const char * found = strchr(currStr, '/');
      if(found == NULL) { // case: ~someone
	strcpy(usrName, currStr);
	currStr = currStr + strlen(usrName);
      }
      else { // case: ~someone/dir
	int len = found - currStr;
	strncpy(usrName, currStr, len);
	usrName[len] = '\0';
	currStr = currStr + strlen(usrName);	
      }
      // retrieve usrName using getpwman()
      struct passwd *pw;
      pw = getpwnam(usrName);
      if(pw == NULL) {
	finalStr->append(newStr->c_str());
      }
      else {
	finalStr->append(pw->pw_dir);
	finalStr->append(currStr);
      }
    }
    _arguments.push_back(finalStr);
    
  }
  
  else {
    _arguments.push_back(newStr);
  }
  
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << *arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}

void SimpleCommand::clear() {
  for (auto & arg : _arguments) {
    delete arg;
  }
  _arguments.clear();
}
 
