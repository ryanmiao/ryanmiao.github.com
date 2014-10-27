---
layout: post
title: "construct virtualization on RHEL6u5"
date: 2014-10-27 14:21:53 +0800
comments: true
categories: 
---

RHEL6u5 is stable distro for building a somewhat server. And if you also
like traditional SysV instead of systemD, this articles give you a guide
to construct virtualization from source on RHEL6u5.

####Prerequisite

source code of kernel, qemu, libvirt, libiscsi, libnfs and libusb.

libiscsi: 1.11.0-9-g20b4f9a
libnfs:   libnfs-1.9.4-6-gea283cd
libusb:   v1.0.19

qemu:     v2.1.0-1124-gb1d28ec
kernel:   v3.18-rc1-221-gc3351df
libvirt:  v1.2.9-110-ga27021a

####1. Build kernel

```
# make bzImage
# make modules
# make modules_install
# make install
```

####2. Build qemu

#####2.1 Build libiscsi, libusb and libnfs respectively

```
# git clone https://github.com/sahlberg/libiscsi.git
# autogen
# make
# sudo make install

# git clone https://github.com/libusb/libusb.git
# autogen
# make
# sudo make install

# git clone https://github.com/sahlberg/libnfs.git
# bootstrap
# make
# sudo make install
```

You have to set PKG_CONFIG_PATH to '/usr/local/lib/pkgconfig'
to continue configure.

#####2.2 Generate qemu

```
# git clone https://github.com/qemu/qemu.git

# ./configure --target-list=x86_64-softmmu --enable-debug-tcg --enable-debug --disable-strip --enable-vnc --enable-vnc-tls --enable-kvm --enable-uuid --enable-attr --enable-vhost-net --enable-spice --enable-libiscsi --enable-libnfs --enable-libusb --enable-guest-agent --enable-glusterfs
```

####3. Build libvirt

```
# autogen --system
# make
# make install
```


####4. Troubleshoot

#####4.1 qemu: could not load PC BIOS 'bios-256k.bin'
Answer: don't specify prefix when configuring qemu, use default prefix instead.

#####4.2 cannot execute binary /usr/libexec/qemu-kvm: Permission denied
Answer: if SELinux is enabled, it may be caused by SELinux.

```
# chcon system_u:object_r:qemu_exec_t:s0 /usr/local/bin/qemu-system-x86_64
```

[The end]
