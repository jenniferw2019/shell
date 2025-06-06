
/*
 *
 * shell.l: lexical analyzer for shell
 */

%{

#include <cstring>
#include <sys/wait.h>
#include "y.tab.hh"
#include "Shell.hh"

#define MAX_BUFF 1024

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

char * replaceEnVar(char * varStr) {
  char * nStr = (char *)malloc(MAX_BUFF);
  strcpy(nStr, "");
  if(strchr(varStr, '$') != NULL) {
    char * find1 = strchr(varStr, '$');
    strncpy(nStr, varStr, find1 - varStr);
    find1++;
    char * find2 = strchr(find1, ' ');
    if(find2 != NULL) {
      int size = find2 - find1;
      char * temp = (char *)malloc(size + 1);
      strncpy(temp, find1, size);
      temp[size] = '\0';
      strcat(nStr, getenv(temp));
      strcat(nStr, find2);

      free(temp);
      temp = NULL;

    }
    else {
      strcat(nStr, getenv(find1));
    }
    nStr[strlen(nStr)] = '\0';
  }
  else {
    strcpy(nStr, varStr);
    nStr[strlen(nStr)] = '\0';
  }
  return nStr;
}

char * subShell(char * inStr) {
 /* subshell implement */
  
  
  //printf("the inStr is: %s\n", inStr);

  // replace $var with value of var
  char * reStr = replaceEnVar(inStr);

  //printf("the reStr is: %s\n", reStr);

  //save in/out
  int tmpin = dup(0);
  int tmpout = dup(1);

  // parent create two pipes
  int pin[2], pout[2];
  pipe(pin); pipe(pout);

  // parent writes to pin[1]
  write(pin[1], reStr, strlen(reStr));
  write(pin[1], "\n", strlen("\n"));
  write(pin[1], "exit\n", strlen("exit\n"));  
  close(pin[1]);

  free(reStr);
  reStr = NULL;
  //reStr[0] = '\0';

  // For child process: redirect input from pin[0],
  // and redirect output to pout[1]
  dup2(pin[0], 0);
  dup2(pout[1], 1);
  close(pin[0]);
  close(pout[1]);

  // parent creates child
  int ret;
  ret = fork();
  if(ret == 0) {
    // child process:
    char * ssArgs[2];
    ssArgs[0] = strdup("/proc/self/exe");
    ssArgs[1] = NULL;
    execvp(ssArgs[0], (char * const *)ssArgs);
    perror("subShell:execvp\n");
    exit(1);
  }
  else if(ret < 0) {
    perror("fork\n");
    exit(1);
  }

  //parent process:
  //restore in/out defaults
  dup2(tmpin, 0);
  dup2(tmpout, 1);
  close(tmpin);
  close(tmpout);

  waitpid(ret, NULL, 0);

  // parent read from pout[0] 
  int numRead = 0;
  char chRead;
  int bufRead = 0;
  int bufSize = MAX_BUFF;
  char * outStr = (char *)malloc(bufSize * sizeof(char));
 
  while(read(pout[0], &chRead, 1)) {
    if(numRead < bufSize) {
      outStr[numRead] = chRead;
      numRead++;
    }
    else {
      bufSize = bufSize * 2;
      outStr = (char *)realloc(outStr, bufSize * sizeof(char));
      outStr[numRead] = chRead;
      numRead++;
    }
  }

  close(pout[0]);
  outStr[numRead] = '\0';
  
  return outStr;
}


char * rmBackTick(char * str) {
  char * rmStr = (char *)malloc(strlen(str) + 1);  

  // remove ` ` and $( )
  char * tmpStr;
  if(str[0] == '`') {
    tmpStr = str + 1;
  }
  else if(str[0] == '$') {
    tmpStr = str + 2;
  }
  strcpy(rmStr, tmpStr);
  rmStr[strlen(rmStr) - 1] = '\0';

  return rmStr;
}

%}

%option noyywrap
%x SOURCE

%%

"#".*\n {
  /* Discard comments starting with # */
}

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

"2>" {
  return TWOGREAT;
}

">" {
  return GREAT;
}

"<" {
  return LESS;
}

"|" {
  return PIPE;
}

">>" {
  return GREATGREAT;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"&" {
  return AMPERSAND;
}

"[" {
  return LBRACKET;
}

"]" {
  return RBRACKET;
}

"if" {
  return IF;
}

"then" {
  return THEN;
}

"fi" {
  return FI;
}

"while" {
  return WHILE;
}

"do" {
  return DO;
}

"done" {
  return DONE;
}

"for" {
  return FOR;
}

"in" {
  return IN;
}

";" {
  return SEMI;
}

\"[^\n]*\" {
/* double quotes */
  //printf("enter double quotes, yytext is: %s\n", yytext);
  yytext[strlen(yytext)-1] = '\0';
  char * word = yytext + 1;
  yylval.cpp_string = new std::string(word);
  return WORD;
}

[^ \n]*\\[^\n]* {
  /* escaping */
  //printf("enter escape, yytext is: %s\n", yytext);
  char * word = (char *)malloc(strlen(yytext) + 1);
  int j = 0;
  for(int i = 0; i < strlen(yytext); i++) {
    if(yytext[i] != '\\') {
      word[j] = yytext[i];
      j++;
    }
    else {
      i = i + 1;
      word[j] = yytext[i];
      j++;
    }
  }
  yylval.cpp_string = new std::string(word);
  return WORD;
}




"source "[^ \t\n][^ \t\n]* {
/* source filename */
  //printf("enter source, filename is: %s\n", yytext);
  FILE * yyin = fopen(yytext + 7, "r");
  if(!yyin) {
    perror("fopen");  
    //BEGIN(INITIAL); // default start condition with input from console
  }
  else {
    yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE));
    //BEGIN(INITIAL); // default start condition with input from yyin
    Shell::TheShell->_enablePrompt = false;
    yyparse(); // parse the input from yyin

    yypop_buffer_state(); // back to normal state
    fclose(yyin);
    Shell::TheShell->clear();
    //Shell::TheShell->_enablePrompt = true;
    }
}

    

`[^\t\n][^\t\n]*`|\$\([^\t\n][^\t\n]*\) {
  /* subshell */
  //printf("enter subshell, yytext is: %s\n", yytext);
  if(Shell::TheShell->_inWhile == true) {
    yylval.cpp_string = new std::string(yytext);
    return WORD;
  }
  else {
     char * cmd = rmBackTick(yytext);

    // call subShell function to run cmd
    char * outBuf = subShell(cmd);

    // write back to lex in reverse order
    // Since the subshell ended with \nGood Bye!!\n\n,
    // there are total 13 chars need to skip
    //fprintf(stdout, "outBuf=%s\n", outBuf);
    for(int i = strlen(outBuf) - 13; i >= 0; i--) {
      if(outBuf[i]  == '\n') {
        outBuf[i] = ' ';
      }
      myunputc(outBuf[i]);
    }

    free(cmd);
    cmd = NULL;
    //free(outBuf);
    //outBuf = NULL;

  }

}




[^ &|>\t\n;][^ &|>\t\n;]*  {
  /* Assume that file names have only alpha chars */
  //printf("enter last rule, yytext is: %s\n", yytext);
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
