---
layout: post
title: "construct virtualization on RHEL6u5"
date: 2014-09-17 14:21:53 +0800
comments: true
categories: 
---

RHEL6u5 is stable distro for building a somewhat server. And if you also
like traditional SysV instead of systemD, this article give you a guide
to construct virtualization from source on RHEL6u5.

####Prerequisite

source code of gcc, kernel, qemu and libvirt

####1. Build tool chain

The reason why we use gcc is because RHEL6u5 has an old gcc, which couldn't
build latest kernel.

The tool chain we need are gcc and binutils, not including gdb.

From http://stackoverflow.com/questions/1726042/recipe-for-compiling-binutils-gcc-together
it said it works to build binutils under gcc simultanously.
But in recent gcc-4.9.0, it will meet a problem when build intl of binutils, like:
```
checking for x86_64-unknown-linux-gnu-gcc... /home/ryan/workspace/software/toolchain/gcc-build/./prev-gcc/xgcc -B/home/ryan/workspace/software/toolchain/gcc-build/./prev-gcc/ -B/home/ryan/workspace/software/gcc-4.9.0-inst/x86_64-unknown-linux-gnu/bin/ -B/home/ryan/workspace/software/gcc-4.9.0-inst/x86_64-unknown-linux-gnu/bin/ -B/home/ryan/workspace/software/gcc-4.9.0-inst/x86_64-unknown-linux-gnu/lib/ -isystem /home/ryan/workspace/software/gcc-4.9.0-inst/x86_64-unknown-linux-gnu/include -isystem /home/ryan/workspace/software/gcc-4.9.0-inst/x86_64-unknown-linux-gnu/sys-include -L/home/ryan/workspace/software/toolchain/gcc-build/./ld 
checking for C compiler default output file name... 
configure: error: in `/home/ryan/workspace/software/toolchain/gcc-build/intl':
configure: error: C compiler cannot create executables
See `config.log' for more details.
make[2]: *** [configure-stage2-intl] Error 77
make[2]: Leaving directory `/home/ryan/workspace/software/toolchain/gcc-build'
make[1]: *** [stage2-bubble] Error 2
make[1]: Leaving directory `/home/ryan/workspace/software/toolchain/gcc-build'
make: *** [all] Error 2
```
What causes it? That is building binutils with '--enable-shared', so two DSO
will be generated: libbfd-2.24.so and libopcodes.so,
but the paths of them are not added to LD_LIBRARY_PATH.
I searched them, the paths are:

/home/ryan/workspace/software/toolchain/gcc-build/prev-bfd/.libs/libbfd-2.24.so
/home/ryan/workspace/software/toolchain/gcc-build/prev-opcodes/.libs/libopcodes-2.24.so

so add those paths to LD_LIBRARY_PATH, then build.

But the paths seem temporary, and make me feel unloveable, so binutils should be built
as static(or --disable-shared).

Here is a thread from gcc mail list: https://gcc.gnu.org/ml/gcc/2013-03/msg00160.html

Before the build, comment '-Werror' of WARN_CFLAGS will be a good choice.

1. get the tar package from gnu

2. untar it

3. get some source packages
```
$ ./contrib/download_prerequisites

$ wget binutils-2.24.tar.gz
$ tar zxf binutils-2.24.tar.gz
$ ln -s binutils binutils-2.24/binutils

$ cd binutils-2.24
$ ./configure --enable-shared --disable-werror
$ make
```

TBD
