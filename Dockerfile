# Static PRoot from termux/proot, for x86_64 and arm64.
#
# termux/proot is upstream PRoot with patches, one of which is why this
# build exists: it translates openat2, rewriting it to openat, which
# upstream still does not — and GNU tar 1.35 creates every nested
# directory through openat2, so under upstream PRoot a `tar xzf` into a
# WORKDIR fails on every second-level entry. Built the way upstream
# builds its own release: glibc, `-static`, no Python extension. The
# result is one static executable with no dependencies, the shape a
# Fargate task and a laptop box can both run.
FROM ubuntu:24.04 AS build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git ca-certificates libtalloc-dev uthash-dev python3 file gawk \
    && rm -rf /var/lib/apt/lists/*
ARG PROOT_REPO=https://github.com/termux/proot.git
ARG PROOT_COMMIT
RUN git clone "$PROOT_REPO" /proot && cd /proot && git checkout --quiet "$PROOT_COMMIT" \
    && git log -1 --format='%H %cs %s'
# fchmodat2 (Linux 6.6): upstream took it on 2026-09-15 (proot-me/proot
# #408); termux has not. glibc 2.39 and GNU tar 1.35 use it for
# AT_SYMLINK_NOFOLLOW, so without it tar's final chmod of every
# directory it extracts runs untranslated and fails under fake root.
# The same change, re-applied to termux's tree, plus the fake-root
# extension treating it as fchmodat.
COPY fchmodat2.patch /fchmodat2.patch
RUN cd /proot && git apply --check /fchmodat2.patch && git apply /fchmodat2.patch
# `-static` on the link only; the loader is its own static, freestanding
# object the makefile builds first. HAS_LOADER_32BIT off on both
# architectures: it is the loader for 32-bit tracees (i386 under x86_64,
# arm under arm64), which needs a multilib compiler and which nothing
# built or run here is — every image on the fleet is 64-bit.
RUN cd /proot/src && LDFLAGS="-static" make proot GIT=false HAS_LOADER_32BIT= \
    && strip proot && file proot && ./proot --version
FROM scratch
COPY --from=build /proot/src/proot /proot
