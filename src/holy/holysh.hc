extern "c" I32 execv(U8 *path, U8 **argv);
extern "c" U0 *getcwd(U8 *buf, U64 size);

#define HOLYSH_VERSION "holysh 0.3.0"

I64 ReadLine(U8 *line, I64 cap)
{
  I64 off = 0;
  U8 ch;
  I64 n;

  while (off + 1 < cap) {
    n = read(0, &ch, 1);
    if (n <= 0) {
      if (off == 0) {
        return n;
      }
      break;
    }
    if (ch == '\r') continue;
    if (ch == '\n') break;
    line[off++] = ch;
  }

  line[off] = 0;
  return off;
}

U0 PutS(U8 *s)
{
  write(1, s, StrLen(s));
}

I32 ShowVersion()
{
  PutS(HOLYSH_VERSION "\n");
  return 0;
}

I32 ShowHelp()
{
  PutS(HOLYSH_VERSION "\n");
  PutS("usage:\n");
  PutS("  holysh\n");
  PutS("  holysh --help\n");
  PutS("  holysh --version\n");
  PutS("\n");
  PutS("builtins:\n");
  PutS("  help       show shell help\n");
  PutS("  cd <dir>   change directory\n");
  PutS("  pwd        print current directory\n");
  PutS("  exit       leave the shell\n");
  PutS("\n");
  PutS("holybox applets:\n");
  PutS("  hello pwd echo cat read write clear ls htree uname holyfetch\n");
  PutS("  touch mkdir rm mv cp ps holytop dmesg mount umount hed reboot poweroff\n");
  PutS("\n");
  PutS("notes:\n");
  PutS("  tokenization is whitespace-based\n");
  PutS("  quoting, pipes, redirects, and job control are not implemented\n");
  return 0;
}

I32 Tokenize(U8 *line, U8 **argv, I32 max_args)
{
  I32 argc = 0;
  U8 *p = line;

  while (*p && argc + 1 < max_args) {
    while (*p == ' ' || *p == '\t') {
      p++;
    }
    if (*p == 0) {
      break;
    }
    argv[argc++] = p;
    while (*p && *p != ' ' && *p != '\t') {
      p++;
    }
    if (*p == 0) {
      break;
    }
    *p = 0;
    p++;
  }

  argv[argc] = NULL;
  return argc;
}

I32 RunCommand(I32 argc, U8 **argv)
{
  I32 pid;
  I32 status = 0;
  U8 *path = NULL;
  Bool has_slash = FALSE;
  I64 i = 0;

  if (argc == 0) {
    return 0;
  }

  if (StrCmp(argv[0], "cd") == 0) {
    if (argc < 2) {
      PutS("usage: cd <dir>\n");
      return 1;
    }
    if (Cd(argv[1]) != 0) {
      "cd: cannot enter %s\n", argv[1];
      return 1;
    }
    return 0;
  }

  if (StrCmp(argv[0], "pwd") == 0) {
    U8 cwd[256];
    if (getcwd(cwd, 256) == NULL) {
      PutS("pwd failed\n");
      return 1;
    }
    "%s\n", cwd;
    return 0;
  }

  if (StrCmp(argv[0], "help") == 0) {
    return ShowHelp();
  }

  if (StrCmp(argv[0], "version") == 0) {
    return ShowVersion();
  }

  pid = fork();
  if (pid < 0) {
    PutS("holysh: fork failed\n");
    return 1;
  }

  if (pid == 0) {
    while (argv[0][i]) {
      if (argv[0][i] == '/') {
        has_slash = TRUE;
        break;
      }
      i++;
    }
    if (has_slash) {
      path = argv[0];
    } else {
      path = MStrPrint("/bin/%s", argv[0]);
    }
    execv(path, argv);
    "holysh: command not found: %s\n", argv[0];
    Exit(127);
  }

  waitpid(pid, &status, 0);
  return status;
}

I32 Main(I32 argc, U8 **argv)
{
  U8 line[256];
  U8 *cmd_argv[32];
  U8 *cmdline = NULL;
  I64 n;
  I32 cmd_argc;

  if (argc >= 2) {
    if (StrCmp(argv[1], "-c") == 0 && argc >= 3) {
      if (StrCmp(argv[2], "--") == 0 && argc >= 4) {
        cmdline = StrNew(argv[3]);
      } else {
        cmdline = StrNew(argv[2]);
      }
      cmd_argc = Tokenize(cmdline, cmd_argv, 32);
      return RunCommand(cmd_argc, cmd_argv);
    }
    if (StrCmp(argv[1], "--help") == 0 || StrCmp(argv[1], "help") == 0) {
      return ShowHelp();
    }
    if (StrCmp(argv[1], "--version") == 0 || StrCmp(argv[1], "version") == 0) {
      return ShowVersion();
    }
  }

  PutS(HOLYSH_VERSION "\n");
  PutS("holysh ready\n");
  while (TRUE) {
    PutS("holy> ");
    n = ReadLine(line, 256);
    if (n <= 0) {
      PutS("\n");
      break;
    }

    cmd_argc = Tokenize(line, cmd_argv, 32);
    if (cmd_argc == 0) {
      continue;
    }
    if (StrCmp(cmd_argv[0], "exit") == 0) {
      break;
    }

    RunCommand(cmd_argc, cmd_argv);
  }
  return 0;
}
