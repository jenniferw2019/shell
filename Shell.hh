#ifndef shell_hh
#define shell_hh

#include "ListCommands.hh"
#include "PipeCommand.hh"
#include "IfCommand.hh"
#include "WhileCommand.hh"
#include "ForCommand.hh"

#include <vector>

#define MAX_LOOP 10

class Shell {

public:
  int _level; // Only outer level executes.
  bool _enablePrompt;
  ListCommands * _listCommands;
  ListCommands * _listCommands_temp[MAX_LOOP];
  SimpleCommand *_simpleCommand;
  PipeCommand * _pipeCommand;
  IfCommand * _ifCommand;
  WhileCommand * _whileCommand[MAX_LOOP];
  ForCommand * _forCommand[MAX_LOOP];
  Command * _currentCommand;
  static Shell * TheShell;

  std::vector<int> _bgPid;
  bool _inWhile;
  bool _inFor;
  int _numArg;

  Shell();
  void execute();
  void print();
  void clear();
  void prompt();

};

#endif
