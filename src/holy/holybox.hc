extern "c" I32 reboot(I32 howto);
extern "c" U0 sync();
extern "c" I32 uname(U0 *buf);
extern "c" U0 *getcwd(U8 *buf, U64 size);
extern "c" I32 mkdir(U8 *path, I32 mode);
extern "c" I32 unlink(U8 *path);
extern "c" I32 rmdir(U8 *path);
extern "c" I32 rename(U8 *old, U8 *new);
extern "c" I32 mount(U8 *source, U8 *target, U8 *fstype, U64 flags, U8 *data);
extern "c" I32 umount(U8 *target);
extern "c" U32 sleep(U32 seconds);
extern "c" I32 usleep(U32 usec);
extern "c" I32 tcgetattr(I32 fd, U0 *termios_p);
extern "c" I32 tcsetattr(I32 fd, I32 optional_actions, U0 *termios_p);
extern "c" I32 fcntl(I32 fd, I32 cmd, I64 arg=0);

#define RB_AUTOBOOT 0x01234567
#define RB_POWER_OFF 0x4321FEDC
#define HOLYBOX_VERSION "holybox 0.3.2"
#define O_WRONLY 1
#define O_CREAT 64
#define O_TRUNC 512
#define O_APPEND 1024
#define O_NONBLOCK 2048
#define F_GETFL 3
#define F_SETFL 4
#define TCSANOW 0
#define ICANON 2
#define ECHO 8
#define VTIME 5
#define VMIN 6

class UtsName
{
  U8 sysname[65];
  U8 nodename[65];
  U8 release[65];
  U8 version[65];
  U8 machine[65];
  U8 domainname[65];
};

class Termios
{
  U32 c_iflag;
  U32 c_oflag;
  U32 c_cflag;
  U32 c_lflag;
  U8 c_line;
  U8 c_cc[32];
  U32 c_ispeed;
  U32 c_ospeed;
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

Bool IsDirPath(U8 *path)
{
  cDIR *dir = opendir(path);
  if (dir == NULL) {
    return FALSE;
  }
  closedir(dir);
  return TRUE;
}

U8 *JoinPath(U8 *a, U8 *b)
{
  if (StrCmp(a, "/") == 0) {
    return MStrPrint("/%s", b);
  }
  return MStrPrint("%s/%s", a, b);
}

U8 *ReadSmallFile(U8 *path)
{
  I32 fd = open(path, O_RDONLY, 0);
  I64 n;
  U8 buf[256];
  U8 *out;

  if (fd < 0) {
    return NULL;
  }
  n = read(fd, buf, 255);
  close(fd);
  if (n < 0) {
    return NULL;
  }
  buf[n] = 0;
  out = StrNew(buf);
  return out;
}

U0 TrimNewline(U8 *s)
{
  while (s != NULL && s[0] && s[StrLen(s) - 1] == '\n') {
    s[StrLen(s) - 1] = 0;
  }
}

Bool IsNumeric(U8 *s)
{
  I64 i = 0;
  if (s == NULL || s[0] == 0) {
    return FALSE;
  }
  while (s[i]) {
    if (s[i] < '0' || s[i] > '9') {
      return FALSE;
    }
    i++;
  }
  return TRUE;
}

U8 GetProcState(U8 *status)
{
  I64 j = 0;
  if (status == NULL) {
    return '?';
  }
  while (status[j]) {
    if (status[j] == 'S' && status[j + 1] == 't' && status[j + 2] == 'a' && status[j + 3] == 't' && status[j + 4] == 'e') {
      while (status[j] && status[j] != '\t' && status[j] != ':') j++;
      while (status[j] == ':' || status[j] == '\t' || status[j] == ' ') j++;
      return status[j];
    }
    j++;
  }
  return '?';
}

U8 *FindStatusValue(U8 *status, U8 *key)
{
  I64 i = 0;
  I64 key_len = StrLen(key);

  if (status == NULL) {
    return NULL;
  }

  while (status[i]) {
    I64 j = 0;
    while (key[j] && status[i + j] == key[j]) {
      j++;
    }
    if (j == key_len && status[i + j] == ':') {
      i += j + 1;
      while (status[i] == ' ' || status[i] == '\t') i++;
      return status + i;
    }
    while (status[i] && status[i] != '\n') i++;
    if (status[i] == '\n') i++;
  }
  return NULL;
}

I32 CopyFile(U8 *src, U8 *dst)
{
  I32 in_fd = open(src, O_RDONLY, 0);
  I32 out_fd;
  U8 buf[4096];
  I64 n;

  if (in_fd < 0) {
    "cp: cannot open %s\n", src;
    return 1;
  }

  out_fd = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (out_fd < 0) {
    "cp: cannot create %s\n", dst;
    close(in_fd);
    return 1;
  }

  while ((n = read(in_fd, buf, 4096)) > 0) {
    if (write(out_fd, buf, n) != n) {
      "cp: write failed: %s\n", dst;
      close(in_fd);
      close(out_fd);
      return 1;
    }
  }

  close(in_fd);
  close(out_fd);
  return 0;
}

I32 RemovePath(U8 *path)
{
  if (IsDirPath(path)) {
    cDIR *dir = opendir(path);
    Dirent *ent;
    I32 rc = 0;

    if (dir == NULL) {
      "rm: cannot open %s\n", path;
      return 1;
    }

    while ((ent = readdir(dir)) != NULL) {
      U8 *child;
      if (IsDot(ent->name)) {
        continue;
      }
      child = JoinPath(path, ent->name);
      if (RemovePath(child) != 0) {
        rc = 1;
      }
    }
    closedir(dir);
    if (rmdir(path) != 0) {
      "rm: cannot remove dir %s\n", path;
      rc = 1;
    }
    return rc;
  }

  if (unlink(path) != 0) {
    "rm: cannot remove %s\n", path;
    return 1;
  }
  return 0;
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

I32 CmdPwd()
{
  U8 cwd[256];
  if (getcwd(cwd, 256) == NULL) {
    PutS("pwd failed\n");
    return 1;
  }
  "%s\n", cwd;
  return 0;
}

I32 CmdTouch(I32 argc, U8 **argv)
{
  I32 i;

  if (argc < 2) {
    PutS("usage: touch <file> [file...]\n");
    return 1;
  }

  for (i = 1; i < argc; i++) {
    I32 fd = open(argv[i], O_WRONLY | O_CREAT, 0644);
    if (fd < 0) {
      "touch: cannot create %s\n", argv[i];
      return 1;
    }
    close(fd);
  }
  return 0;
}

I32 CmdMkdir(I32 argc, U8 **argv)
{
  I32 i;

  if (argc < 2) {
    PutS("usage: mkdir <dir> [dir...]\n");
    return 1;
  }

  for (i = 1; i < argc; i++) {
    if (mkdir(argv[i], 0755) != 0) {
      "mkdir: cannot create %s\n", argv[i];
      return 1;
    }
  }
  return 0;
}

I32 CmdRm(I32 argc, U8 **argv)
{
  I32 i;
  I32 rc = 0;

  if (argc < 2) {
    PutS("usage: rm <path> [path...]\n");
    return 1;
  }

  for (i = 1; i < argc; i++) {
    if (RemovePath(argv[i]) != 0) {
      rc = 1;
    }
  }
  return rc;
}

I32 CmdMv(I32 argc, U8 **argv)
{
  if (argc != 3) {
    PutS("usage: mv <src> <dst>\n");
    return 1;
  }
  if (rename(argv[1], argv[2]) != 0) {
    "mv: cannot move %s -> %s\n", argv[1], argv[2];
    return 1;
  }
  return 0;
}

I32 CmdCp(I32 argc, U8 **argv)
{
  if (argc != 3) {
    PutS("usage: cp <src> <dst>\n");
    return 1;
  }
  return CopyFile(argv[1], argv[2]);
}

I32 CmdWrite(I32 argc, U8 **argv)
{
  I32 fd;
  I32 i;

  if (argc < 3) {
    PutS("usage: write <file> <text...>\n");
    return 1;
  }

  fd = open(argv[1], O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) {
    "write: cannot create %s\n", argv[1];
    return 1;
  }

  for (i = 2; i < argc; i++) {
    if (i > 2) {
      write(fd, " ", 1);
    }
    write(fd, argv[i], StrLen(argv[i]));
  }
  write(fd, "\n", 1);
  close(fd);
  return 0;
}

I32 CmdRead(I32 argc, U8 **argv)
{
  if (argc != 2) {
    PutS("usage: read <file>\n");
    return 1;
  }
  return CmdCat(argc, argv);
}

I32 PrintTree(U8 *path, I32 depth)
{
  cDIR *dir = opendir(path);
  Dirent *ent;
  I32 i;

  if (dir == NULL) {
    "htree: cannot open %s\n", path;
    return 1;
  }

  while ((ent = readdir(dir)) != NULL) {
    U8 *child;
    if (IsDot(ent->name)) {
      continue;
    }
    for (i = 0; i < depth; i++) {
      PutS("  ");
    }
    "%s\n", ent->name;
    child = JoinPath(path, ent->name);
    if (IsDirPath(child)) {
      PrintTree(child, depth + 1);
    }
  }
  closedir(dir);
  return 0;
}

I32 CmdHTree(I32 argc, U8 **argv)
{
  U8 *path = ".";
  if (argc >= 2) {
    path = argv[1];
  }
  "%s\n", path;
  return PrintTree(path, 1);
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

I32 CmdDmesg()
{
  I32 fd = open("/dev/kmsg", O_RDONLY, 0);
  U8 buf[4096];
  I64 n;

  if (fd < 0) {
    fd = open("/proc/kmsg", O_RDONLY, 0);
  }
  if (fd < 0) {
    PutS("dmesg: cannot open kernel log\n");
    return 1;
  }

  while ((n = read(fd, buf, 4096)) > 0) {
    write(1, buf, n);
  }
  close(fd);
  return 0;
}

I32 CmdPs()
{
  cDIR *dir = opendir("/proc");
  Dirent *ent;

  if (dir == NULL) {
    PutS("ps: cannot open /proc\n");
    return 1;
  }

  PutS("PID STATE CMD\n");
  while ((ent = readdir(dir)) != NULL) {
    U8 *status_path;
    U8 *name_path;
    U8 *status;
    U8 *name;
    if (IsDot(ent->name)) {
      continue;
    }
    if (!IsNumeric(ent->name)) {
      continue;
    }

    status_path = JoinPath(JoinPath("/proc", ent->name), "status");
    name_path = JoinPath(JoinPath("/proc", ent->name), "comm");
    status = ReadSmallFile(status_path);
    name = ReadSmallFile(name_path);
    if (name != NULL) {
      TrimNewline(name);
      "%s %c %s\n", ent->name, GetProcState(status), name;
    }
  }
  closedir(dir);
  return 0;
}

I32 CmdMount(I32 argc, U8 **argv)
{
  if (argc != 4) {
    PutS("usage: mount <source> <target> <fstype>\n");
    return 1;
  }
  if (mount(argv[1], argv[2], argv[3], 0, NULL) != 0) {
    "mount: failed: %s on %s (%s)\n", argv[1], argv[2], argv[3];
    return 1;
  }
  return 0;
}

I32 CmdUmount(I32 argc, U8 **argv)
{
  if (argc != 2) {
    PutS("usage: umount <target>\n");
    return 1;
  }
  if (umount(argv[1]) != 0) {
    "umount: failed: %s\n", argv[1];
    return 1;
  }
  return 0;
}

I32 CmdHed(I32 argc, U8 **argv)
{
  I32 fd;
  U8 line[256];
  I64 off = 0;
  U8 ch;
  I64 n;

  if (argc != 2) {
    PutS("usage: hed <file>\n");
    return 1;
  }

  fd = open(argv[1], O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) {
    "hed: cannot open %s\n", argv[1];
    return 1;
  }

  PutS("hed: enter lines, single '.' saves and exits\n");
  while (TRUE) {
    PutS(">> ");
    off = 0;
    while (off + 1 < 256) {
      n = read(0, &ch, 1);
      if (n <= 0) {
        close(fd);
        return 0;
      }
      if (ch == '\r') continue;
      if (ch == '\n') break;
      line[off++] = ch;
    }
    line[off] = 0;
    if (StrCmp(line, ".") == 0) {
      break;
    }
    write(fd, line, StrLen(line));
    write(fd, "\n", 1);
  }
  close(fd);
  return 0;
}

I32 CmdHolyFetch()
{
  UtsName uts;
  U8 *meminfo;
  U8 *cpuinfo;
  U8 *uptime;
  U8 cwd[256];
  U8 *memtotal;
  U8 *model;
  I32 proc_count = 0;
  cDIR *dir;
  Dirent *ent;

  if (uname(&uts) != 0) {
    PutS("holyfetch failed\n");
    return 1;
  }
  meminfo = ReadSmallFile("/proc/meminfo");
  cpuinfo = ReadSmallFile("/proc/cpuinfo");
  uptime = ReadSmallFile("/proc/uptime");
  if (getcwd(cwd, 256) == NULL) {
    cwd[0] = '/';
    cwd[1] = 0;
  }

  dir = opendir("/proc");
  if (dir != NULL) {
    while ((ent = readdir(dir)) != NULL) {
      if (IsNumeric(ent->name)) {
        proc_count++;
      }
    }
    closedir(dir);
  }

  memtotal = FindStatusValue(meminfo, "MemTotal");
  model = FindStatusValue(cpuinfo, "model name");

  PutS("      __  __      __         \n");
  PutS("     / / / /___  / /_  __    \n");
  PutS("    / /_/ / __ \\/ / / / /    \n");
  PutS("   / __  / /_/ / / /_/ /     \n");
  PutS("  /_/ /_/\\____/_/\\__, /      \n");
  PutS("                /____/ Linux \n");
  PutS("\n");
  "name    : Holy-Linux\n";
  "shell   : holysh\n";
  "kernel  : %s\n", uts.release;
  "arch    : %s\n", uts.machine;
  "host    : %s\n", uts.nodename;
  "cwd     : %s\n", cwd;
  "tasks   : %d\n", proc_count;
  if (uptime != NULL) {
    I64 i = 0;
    PutS("uptime  : ");
    while (uptime[i] && uptime[i] != ' ') {
      write(1, uptime + i, 1);
      i++;
    }
    PutS(" sec\n");
  }
  if (memtotal != NULL) {
    I64 i = 0;
    PutS("memory  : ");
    while (memtotal[i] && memtotal[i] != '\n') {
      write(1, memtotal + i, 1);
      i++;
    }
    write(1, "\n", 1);
  }
  if (model != NULL) {
    I64 i = 0;
    PutS("cpu     : ");
    while (model[i] && model[i] != '\n') {
      write(1, model + i, 1);
      i++;
    }
    write(1, "\n", 1);
  }
  return 0;
}

I32 RenderHolyTop()
{
  cDIR *dir = opendir("/proc");
  Dirent *ent;
  I32 shown = 0;
  I32 total = 0;
  I32 running = 0;
  I32 sleeping = 0;

  if (dir == NULL) {
    PutS("holytop: cannot open /proc\n");
    return 1;
  }

  PutS("holytop  pid/state/rss/command snapshot\n");
  PutS("---------------------------------------\n");
  PutS("PID    ST  RSS         CMD\n");

  while ((ent = readdir(dir)) != NULL) {
    U8 *status_path;
    U8 *name_path;
    U8 *status;
    U8 *name;
    U8 *rss;
    U8 state;

    if (IsDot(ent->name) || !IsNumeric(ent->name)) {
      continue;
    }
    total++;
    status_path = JoinPath(JoinPath("/proc", ent->name), "status");
    name_path = JoinPath(JoinPath("/proc", ent->name), "comm");
    status = ReadSmallFile(status_path);
    name = ReadSmallFile(name_path);
    state = GetProcState(status);
    if (state == 'R') running++;
    if (state == 'S') sleeping++;

    if (shown >= 12 || name == NULL) {
      continue;
    }

    rss = FindStatusValue(status, "VmRSS");
    TrimNewline(name);
    "%-6s %-3c ", ent->name, state;
    if (rss != NULL) {
      I64 i = 0;
      while (rss[i] && rss[i] != '\n') {
        write(1, rss + i, 1);
        i++;
      }
      PutS("\t");
    } else {
      PutS("-\t");
    }
    "%s\n", name;
    shown++;
  }
  closedir(dir);
  "\nsummary: total=%d running=%d sleeping=%d shown=%d\n", total, running, sleeping, shown;
  return 0;
}

I32 CmdHolyTop(I32 argc, U8 **argv)
{
  Bool once = FALSE;
  Termios old_term;
  Termios new_term;
  I32 old_flags;
  U8 ch;
  I32 i;
  I32 j;

  if (argc >= 2 && (StrCmp(argv[1], "--once") == 0 || StrCmp(argv[1], "once") == 0)) {
    once = TRUE;
  }

  if (once) {
    return RenderHolyTop();
  }

  if (tcgetattr(0, &old_term) != 0) {
    PutS("holytop: tcgetattr failed\n");
    return 1;
  }
  new_term.c_iflag = old_term.c_iflag;
  new_term.c_oflag = old_term.c_oflag;
  new_term.c_cflag = old_term.c_cflag;
  new_term.c_lflag = old_term.c_lflag;
  for (j = 0; j < 32; j++) {
    new_term.c_cc[j] = old_term.c_cc[j];
  }
  new_term.c_ispeed = old_term.c_ispeed;
  new_term.c_ospeed = old_term.c_ospeed;
  new_term.c_lflag &= ~(ICANON | ECHO);
  new_term.c_cc[VMIN] = 0;
  new_term.c_cc[VTIME] = 0;
  if (tcsetattr(0, TCSANOW, &new_term) != 0) {
    PutS("holytop: tcsetattr failed\n");
    return 1;
  }

  old_flags = fcntl(0, F_GETFL, 0);
  fcntl(0, F_SETFL, old_flags | O_NONBLOCK);

  while (TRUE) {
    CmdClear();
    RenderHolyTop();
    PutS("\nrefresh: 1s  exit: q\n");
    for (i = 0; i < 10; i++) {
      if (read(0, &ch, 1) > 0) {
        if (ch == 'q' || ch == 'Q') {
          tcsetattr(0, TCSANOW, &old_term);
          fcntl(0, F_SETFL, old_flags);
          return 0;
        }
      }
      usleep(100000);
    }
  }
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
  PutS("  hello pwd echo cat read write clear ls htree uname holyfetch\n");
  PutS("  touch mkdir rm mv cp ps holytop dmesg mount umount hed\n");
  PutS("  reboot poweroff\n");
  PutS("\n");
  PutS("notes:\n");
  PutS("  holytop       live refresh mode\n");
  PutS("  holytop --once one-shot snapshot\n");
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
  if (StrCmp(name, "pwd") == 0) return CmdPwd();
  if (StrCmp(name, "echo") == 0) return CmdEcho(argc, argv);
  if (StrCmp(name, "cat") == 0) return CmdCat(argc, argv);
  if (StrCmp(name, "read") == 0) return CmdRead(argc, argv);
  if (StrCmp(name, "write") == 0) return CmdWrite(argc, argv);
  if (StrCmp(name, "clear") == 0) return CmdClear();
  if (StrCmp(name, "ls") == 0) return CmdLs(argc, argv);
  if (StrCmp(name, "htree") == 0) return CmdHTree(argc, argv);
  if (StrCmp(name, "uname") == 0) return CmdUname();
  if (StrCmp(name, "holyfetch") == 0) return CmdHolyFetch();
  if (StrCmp(name, "touch") == 0) return CmdTouch(argc, argv);
  if (StrCmp(name, "mkdir") == 0) return CmdMkdir(argc, argv);
  if (StrCmp(name, "rm") == 0) return CmdRm(argc, argv);
  if (StrCmp(name, "mv") == 0) return CmdMv(argc, argv);
  if (StrCmp(name, "cp") == 0) return CmdCp(argc, argv);
  if (StrCmp(name, "ps") == 0) return CmdPs();
  if (StrCmp(name, "holytop") == 0) return CmdHolyTop(argc, argv);
  if (StrCmp(name, "dmesg") == 0) return CmdDmesg();
  if (StrCmp(name, "mount") == 0) return CmdMount(argc, argv);
  if (StrCmp(name, "umount") == 0) return CmdUmount(argc, argv);
  if (StrCmp(name, "hed") == 0) return CmdHed(argc, argv);
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
