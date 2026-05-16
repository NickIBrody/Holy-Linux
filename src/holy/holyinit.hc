extern "c" I32 mount(U8 *source, U8 *target, U8 *fstype, U64 flags, U8 *data);
extern "c" I32 reboot(I32 howto);
extern "c" U0 sync();
extern "c" I32 execv(U8 *path, U8 **argv);
extern "c" I32 setenv(U8 *name, U8 *value, I32 overwrite);

#define RB_POWER_OFF 0x4321FEDC

U0 PutS(U8 *s)
{
  write(1, s, StrLen(s));
}

U0 TryMount(U8 *source, U8 *target, U8 *fstype)
{
  if (mount(source, target, fstype, 0, NULL) != 0) {
    "holyinit: mount failed: %s on %s\n", fstype, target;
  }
}

I32 Main()
{
  U8 *argv[2];
  I32 pid;
  I32 status = 0;

  PutS("\nholy-linux booted\n");
  PutS("launching holysh\n\n");

  TryMount("none", "/proc", "proc");
  TryMount("none", "/sys", "sysfs");
  TryMount("none", "/dev", "devtmpfs");
  setenv("PATH", "/bin:/usr/bin", 1);

  argv[0] = "/bin/holysh";
  argv[1] = NULL;

  pid = fork();
  if (pid == 0) {
    execv("/bin/holysh", argv);
    PutS("holyinit: exec /bin/holysh failed\n");
    Exit(1);
  }
  if (pid < 0) {
    PutS("holyinit: fork failed\n");
  } else {
    waitpid(pid, &status, 0);
  }

  PutS("holyinit: holysh exited, powering off\n");
  sync();
  reboot(RB_POWER_OFF);
  return 1;
}
