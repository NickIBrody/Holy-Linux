extern "c" I32 reboot(I32 howto);
extern "c" U0 sync();
extern "c" I32 uname(U0 *buf);

#define RB_AUTOBOOT 0x01234567
#define RB_POWER_OFF 0x4321FEDC
#define HOLYBOX_VERSION "holybox 0.2.0"

class UtsName
{
  U8 sysname[65];
  U8 nodename[65];
  U8 release[65];
  U8 version[65];
  U8 machine[65];
  U8 domainname[65];
};

U0 PutS(U8 *s)
{
  write(1, s, StrLen(s));
}

U8 *BaseName(U8 *path)
{
  U8 *last = path;
  I64 i = 0;

  while (path[i]) {
    if (path[i] == '/') {
      last = path + i + 1;
    }
    i++;
  }
  return last;
}

Bool IsDot(U8 *name)
{
  return StrCmp(name, ".") == 0 || StrCmp(name, "..") == 0;
}

I32 CmdHello()
{
  PutS("hello from holybox\n");
  return 0;
}

I32 CmdEcho(I32 argc, U8 **argv)
{
  I32 i;
  for (i = 1; i < argc; i++) {
    if (i > 1) {
      write(1, " ", 1);
    }
    write(1, argv[i], StrLen(argv[i]));
  }
  write(1, "\n", 1);
  return 0;
}

I32 CmdCat(I32 argc, U8 **argv)
{
  I32 i;
  I32 rc = 0;

  if (argc < 2) {
    PutS("usage: cat <file> [file...]\n");
    return 1;
  }

  for (i = 1; i < argc; i++) {
    I32 fd = open(argv[i], O_RDONLY, 0);
    if (fd < 0) {
      "cat: cannot open %s\n", argv[i];
      rc = 1;
      continue;
    }

    U8 buf[4096];
    I64 n;
    while ((n = read(fd, buf, 4096)) > 0) {
      write(1, buf, n);
    }
    close(fd);
  }
  return rc;
}

I32 CmdClear()
{
  write(1, "\033[H\033[2J", 7);
  return 0;
}

I32 CmdLs(I32 argc, U8 **argv)
{
  U8 *path = ".";
  cDIR *dir;
  Dirent *ent;

  if (argc >= 2) {
    path = argv[1];
  }

  dir = opendir(path);
  if (dir == NULL) {
    "ls: cannot open %s\n", path;
    return 1;
  }

  while ((ent = readdir(dir)) != NULL) {
    if (IsDot(ent->name)) {
      continue;
    }
    "%s\n", ent->name;
  }

  closedir(dir);
  return 0;
}

I32 CmdUname()
{
  UtsName uts;
  if (uname(&uts) != 0) {
    PutS("uname failed\n");
    return 1;
  }
  "%s %s %s %s %s\n", uts.sysname, uts.nodename, uts.release, uts.version, uts.machine;
  return 0;
}

I32 CmdReboot(I32 howto)
{
  sync();
  reboot(howto);
  return 1;
}

I32 CmdHelp()
{
  PutS(HOLYBOX_VERSION "\n");
  PutS("usage:\n");
  PutS("  holybox <applet> [args...]\n");
  PutS("  <applet> [args...]\n");
  PutS("\n");
  PutS("applets:\n");
  PutS("  hello      print a HolyC greeting\n");
  PutS("  echo       print arguments\n");
  PutS("  cat        print file contents\n");
  PutS("  clear      clear the terminal\n");
  PutS("  ls         list a directory\n");
  PutS("  uname      print kernel/system info\n");
  PutS("  reboot     reboot the machine\n");
  PutS("  poweroff   power off the machine\n");
  PutS("\n");
  PutS("meta:\n");
  PutS("  --help     show this help\n");
  PutS("  --version  show holybox version\n");
  return 0;
}

I32 CmdVersion()
{
  PutS(HOLYBOX_VERSION "\n");
  return 0;
}

I32 Dispatch(U8 *name, I32 argc, U8 **argv)
{
  if (StrCmp(name, "holybox") == 0) {
    if (argc < 2) {
      return CmdHelp();
    }
    if (StrCmp(argv[1], "--help") == 0 || StrCmp(argv[1], "help") == 0) {
      return CmdHelp();
    }
    if (StrCmp(argv[1], "--version") == 0 || StrCmp(argv[1], "version") == 0) {
      return CmdVersion();
    }
    return Dispatch(argv[1], argc - 1, argv + 1);
  }
  if (StrCmp(name, "--help") == 0) return CmdHelp();
  if (StrCmp(name, "--version") == 0) return CmdVersion();
  if (StrCmp(name, "hello") == 0) return CmdHello();
  if (StrCmp(name, "echo") == 0) return CmdEcho(argc, argv);
  if (StrCmp(name, "cat") == 0) return CmdCat(argc, argv);
  if (StrCmp(name, "clear") == 0) return CmdClear();
  if (StrCmp(name, "ls") == 0) return CmdLs(argc, argv);
  if (StrCmp(name, "uname") == 0) return CmdUname();
  if (StrCmp(name, "reboot") == 0) return CmdReboot(RB_AUTOBOOT);
  if (StrCmp(name, "poweroff") == 0) return CmdReboot(RB_POWER_OFF);
  if (StrCmp(name, "help") == 0) return CmdHelp();
  if (StrCmp(name, "version") == 0) return CmdVersion();

  "holybox: unknown applet: %s\n", name;
  return 1;
}

I32 Main(I32 argc, U8 **argv)
{
  return Dispatch(BaseName(argv[0]), argc, argv);
}
