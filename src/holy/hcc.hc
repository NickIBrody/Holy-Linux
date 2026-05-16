extern "c" I32 execv(U8 *path, U8 **argv);

I32 Main(I32 argc, U8 **argv)
{
  I32 i;
  U8 **new_argv = MAlloc(sizeof(U8 *) * (argc + 4));

  new_argv[0] = "/bin/hcc.bin";
  new_argv[1] = "--install-dir=/usr/local";
  new_argv[2] = "-clibs=--gcc-toolchain=/usr -B/usr/bin -B/usr/lib/gcc/x86_64-linux-gnu/14 -L/usr/lib/gcc/x86_64-linux-gnu/14 -L/usr/lib/x86_64-linux-gnu -L/lib/x86_64-linux-gnu";

  for (i = 1; i < argc; i++) {
    new_argv[i + 2] = argv[i];
  }
  new_argv[argc + 2] = NULL;

  execv("/bin/hcc.bin", new_argv);
  "hcc wrapper: failed to exec /bin/hcc.bin\n";
  return 1;
}
