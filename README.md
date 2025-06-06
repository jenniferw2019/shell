# Shell Project

The goal of this project is to build a shell interpreter which combines behavior from common shells including bash and csh.

_**Part1: Parsing and Executing Commands**_

- To begin, write a scanner and parser for the shell using the open source versions of Lex and Yacc (Flex and Bison). The shell can support some complex grammar as following:  
	- cmd \[arg\]\* \[ | cmd \[arg\]\* \]\* \[ \[\> filename\] \[\< filename\] \[2\> filename\]  
\[ \>& filename\] \[\>\> filename\] \[\>\>& filename\] \]\* \[&\]  
	  
- Then, implement the execution of simple commands, IO redirection, piping, and allowing processes to run in the background.

_**Part2: More Features**_

- Implement signal handling, e.g. users can type ctrl-c to stop a running command or   clean up zombie child processes.

- Implement a special command “exit” which will exit the shell while not causing a new process to be created.

- Add support for quotes in the shell, i.e. it should be possible to pass arguments with spaces if they are surrounded by quotes.  
	- myshell\> ls "command.cc Makefile"  
command.cc Makefile not found

- Allow the escape character.
	- Any Any character can be part of an argument if it comes immediately after \\, including special characters such as quotation marks (“”) and an ampersand (&).

- Implement builtin function such as “printenv”, “setenv”, “unsetenv”, “source”, “cd”, etc.

- Implement subshells.
	- Let the user run a complex command that uses the output from one shell command as the input of another.

_**Part 3: Expansions, Wildcards and Supporting if/while/for**_

- Implement environment variable expansion and tilde expansion.

- Implement wildcarding so the shell can deal with wildcard characters (\* and ?) in file and directory names. Make it work for any absolute path.

- Support if/while/for in shell scripting. 
