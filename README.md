# proot-build

A static [PRoot](https://proot-me.github.io/) for x86_64 and arm64, built from
[termux/proot](https://github.com/termux/proot) and published as
`ghcr.io/weftsh/proot`, so that Weft's own CI can fetch it from a registry its
runners already reach.

Weft runs its deploy gate — kaniko image builds, a Postgres and MinIO stack,
the production image and its smoke test — on Fargate tasks that have no
container runtime, under PRoot. Two syscalls decided which PRoot:

- **openat2** (Linux 5.6). GNU tar 1.35 creates every nested directory through
  `openat2(AT_FDCWD, "x/", O_PATH|O_DIRECTORY, RESOLVE_BENEATH)` and then
  `mkdirat(fd, "y")`. Upstream PRoot does not translate openat2, so it runs
  against the kernel's cwd rather than the tracee's and every second-level
  entry fails `Cannot mkdir: No such file or directory`. termux/proot rewrites
  openat2 to openat.
- **fchmodat2** (Linux 6.6). glibc 2.39 and tar 1.35 use it for
  `AT_SYMLINK_NOFOLLOW`. Upstream took it on 2026-09-15
  ([proot-me/proot#408](https://github.com/proot-me/proot/pull/408)); termux
  had not, so `fchmodat2.patch` re-applies that change to termux's tree and
  teaches the fake-root extension to treat it as fchmodat.

`PROOT_COMMIT` is the pin on termux/proot; the workflow builds both
architectures the way upstream builds its release (glibc, `-static`, no
Python extension, no 32-bit loader) and pushes one multi-platform image whose
only file is `/proot`. Bump the pin or the patch and run it; the tag is
`<PROOT_COMMIT>-fchmodat2`, and the image digest is what consumers pin.

PRoot is © STMicroelectronics and contributors, licensed GPL-2.0; this build
carries termux's patches and the one above.
