# actiond CAS I/O stall reproducer

A Bazel workspace that stalls the CAS disk of `linux-actiond serve-vm` on x86_64 in a few
minutes. It needs no toolchain: every action uses only bash builtins, so the stock runtime
image is sufficient.

## What it does

- 96 `ReproWrite` actions each write a unique 64 MiB file. The CAS then holds 6 GiB.
- 96 `ReproRead` actions each read 8 of those files.
- The guest has 2 GiB of memory, so the reads cannot stay in the page cache and go to the
  CAS disk from many vCPUs at once.

## Run

Start a worker with a new root:

```bash
linux-actiond serve-vm --listen=127.0.0.1:8980 --root=/tmp/actiond-repro --cpus=8 --memory-mib=2048
```

Run the build:

```bash
bazel build //:all_reads
```

## Result

With a stalled worker, Bazel stops and prints no error. These three conditions are then true:

- The CAS image under `--root` does not grow.
- The QEMU process uses almost no CPU time.
- The remaining `ReproRead` actions never complete.

A worker without the fault completes the build in a few minutes.

Delete the root directory and run `bazel clean` before each new run.
