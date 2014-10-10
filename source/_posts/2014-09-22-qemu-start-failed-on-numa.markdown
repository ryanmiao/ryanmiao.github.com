---
layout: post
title: "qemu start failed on NUMA"
date: 2014-09-22 15:11:41 +0800
comments: true
categories: 
---

libvirt firstly creates cpuset, then creates qemu process, and sets
cpuset.cpus and cpuset.mems.

But qemu uses DMA_ZONE memory, which is only available on some particular
node of NUMA, when it is starting.

```
# cat /proc/zoneinfo | grep DMA
Node 0, zone      DMA
Node 0, zone    DMA32
```

