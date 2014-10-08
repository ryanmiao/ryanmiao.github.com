---
layout: post
title: "debugging qemu linux user mode clone syscall emulation"
date: 2014-08-12 16:23:55 +0800
comments: true
categories: 
---

When I look into QEMU linux-user mode, I want to run a multi-thread program.
This multi-thread program is extracted from qemu/tests/tcg/linux-test.c.

```
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <inttypes.h>
#include <pthread.h>
#include <sys/wait.h>
#include <sched.h>

int thread1_func(void *arg)
{
    int i;
    char buf[512];

    for(i=0;i<10;i++) {
        snprintf(buf, sizeof(buf), "thread1: %d %s\n", i, (char *)arg);
       write(1, buf, strlen(buf));
        usleep(100 * 1000);
    }
    return 0;
}

int thread2_func(void *arg)
{
    int i;
    char buf[512];
    for(i=0;i<10;i++) {
        snprintf(buf, sizeof(buf), "thread2: %d %s\n", i, (char *)arg);
        write(1, buf, strlen(buf));
        usleep(120 * 1000);
    }
    return 0;
}

#define STACK_SIZE 16384

void test_clone(void)
{
    uint8_t *stack1, *stack2;
    int pid1, pid2, status1, status2;

    stack1 = malloc(STACK_SIZE);
    pid1 = clone(thread1_func, stack1 + STACK_SIZE,
                 CLONE_VM | CLONE_FS | CLONE_FILES | SIGCHLD, "hello1");

    stack2 = malloc(STACK_SIZE);
    pid2 = clone(thread2_func, stack2 + STACK_SIZE,
                CLONE_VM | CLONE_FS | CLONE_FILES | SIGCHLD, "hello2");

    while (waitpid(pid1, &status1, 0) != pid1);
    while (waitpid(pid2, &status2, 0) != pid2);
    printf("status1=0x%x\n", status1);
    printf("status2=0x%x\n", status2);
    printf("End of clone test.\n");
}

int main(int argc, char **argv)
{
    test_clone();
    return 0;
}
```

But when it runs, I get segv:

```
$ ~/workspace/virt/qemu/x86_64-linux-user/qemu-x86_64 ./test-clone
qemu-x86_64: /home/ryan/workspace/virt/qemu/tcg/tcg.c:628: tcg_temp_free_internal: Assertion `idx >= s->nb_globals && idx < s->nb_temps' failed.
qemu: uncaught target signal 11 (Segmentation fault) - core dumped
Segmentation fault (core dumped)
```

It makes me frastrated, is it related to tcg?
Maybe, maybe not.

Debugging work is starting.

Firstly, I added '-strace' option to qemu-x86_64, this option will print
all syscall qemu emulated, and the return values:

```
$ ~/workspace/virt/qemu/x86_64-linux-user/qemu-x86_64 -strace ./test-clone
4459 uname(0x40007fffa0) = 0
4459 brk(NULL) = 0x00000000006aa000
4459 brk(0x00000000006ab180) = 0x00000000006ab180
4459 arch_prctl(4098,6989920,0,6973864,6973856,6973888) = 0
4459 brk(0x00000000006cc180) = 0x00000000006cc180
4459 brk(0x00000000006cd000) = 0x00000000006cd000
4459 clone(CLONE_VM|CLONE_FS|CLONE_FILES|0x11,child_stack=0x00000000006af860,parent_tidptr=0x00000000006a8068,tls=0x0000000000000001,child_tidptr=0x0000000000000001) = 4460
4459 read(1809,0x6af860,6979688) = -1 errno=14 (Bad address)
qemu-x86_64: /home/ryan/workspace/virt/qemu/tcg/tcg.c:628: tcg_temp_free_internal: Assertion `idx >= s->nb_globals && idx < s->nb_temps' failed.
qemu: uncaught target signal 11 (Segmentation fault) - core dumped
Segmentation fault (core dumped)
```

Note: the first column is TID, I added this print in qemu_log():

But it doesn't give us some clue. A deeper check should be applied: check TB
(TranslationBlock) execution sequence.

A small patch to singlestep should be applied:

```
diff --git a/cpu-exec.c b/cpu-exec.c
index 38e5f02..64b7289 100644
--- a/cpu-exec.c
+++ b/cpu-exec.c
@@ -622,8 +622,8 @@ int cpu_exec(CPUArchState *env)
                 }
                 /* see if we can patch the calling TB. When the TB
                    spans two pages, we cannot safely do a direct
-                   jump. */
-                if (next_tb != 0 && tb->page_addr[1] == -1) {
+                   jump. So as when singlestep is enabled. */
+                if (next_tb != 0 && tb->page_addr[1] == -1 && !singlestep) {
                     tb_add_jump((TranslationBlock *)(next_tb & ~TB_EXIT_MASK),
                                 next_tb & TB_EXIT_MASK, tb);
                 }

```

This small patch avoids TBs linked when singlestep is enabled.

After re-building qemu-x86_64, run:

```
~/workspace/virt/qemu/x86_64-linux-user/qemu-x86_64 -singlestep -d exec -strace ./test-clone
```

We can see that after clone executed, the child thread also executed a TB
(which tb->pc == 0x412de7):

```
[4592] Trace 0x7f535879d0d0 [00000000004092e3] _int_malloc
[4593] Trace 0x7f53587af860 [0000000000412de7] clone
[4592] Trace 0x7f535879d110 [00000000004092e7] _int_malloc
```

Let figure out what is it in 0x412de7. So objdump the test-clone:

```
0000000000412db0 <__clone>:
  412db0:       48 c7 c0 ea ff ff ff    mov    $0xffffffffffffffea,%rax
  412db7:       48 85 ff                test   %rdi,%rdi
  412dba:       0f 84 40 16 00 00       je     414400 <__syscall_error>
  412dc0:       48 85 f6                test   %rsi,%rsi
  412dc3:       0f 84 37 16 00 00       je     414400 <__syscall_error>
  412dc9:       48 83 ee 10             sub    $0x10,%rsi
  412dcd:       48 89 4e 08             mov    %rcx,0x8(%rsi)
  412dd1:       48 89 3e                mov    %rdi,(%rsi)
  412dd4:       48 89 d7                mov    %rdx,%rdi
  412dd7:       4c 89 c2                mov    %r8,%rdx
  412dda:       4d 89 c8                mov    %r9,%r8
  412ddd:       4c 8b 54 24 08          mov    0x8(%rsp),%r10
  412de2:       b8 38 00 00 00          mov    $0x38,%eax
  412de7:       0f 05                   syscall
  412de9:       48 85 c0                test   %rax,%rax
  412dec:       0f 8c 0e 16 00 00       jl     414400 <__syscall_error>
  412df2:       74 01                   je     412df5 <__clone+0x45>
  412df4:       c3                      retq
```

We could see the TB executed by child thread is syscall instruction,
here is the question why child thread also run clone syscall?

In linux-user/main.c:


``` c linux-user/main.c start:300
#ifndef TARGET_ABI32
        case EXCP_SYSCALL:
            /* linux syscall from syscall instruction */
            env->regs[R_EAX] = do_syscall(env,
                                          env->regs[R_EAX],
                                          env->regs[R_EDI],
                                          env->regs[R_ESI],
                                          env->regs[R_EDX],
                                          env->regs[10],
                                          env->regs[8],
                                          env->regs[9],
                                          0, 0);
            env->eip = env->exception_next_eip;
            break;
#endif
```

The env->eip is updated to env->exception_next_eip, it seems too late for clone
syscall, because clone_func() will use that env->eip to start a new cpu_loop().
This is the bug, and causes segv.

For fix it, we could update env->eip before do_syscall().
And for consistent with 'INT 0x80', I choose to add logic to do_interrupt():

```
diff --git a/target-i386/seg_helper.c b/target-i386/seg_helper.c
index 2d970d0..13eefba 100644
--- a/target-i386/seg_helper.c
+++ b/target-i386/seg_helper.c
@@ -1127,8 +1127,8 @@ static void do_interrupt_user(CPUX86State *env, int intno, int is_int,
 
     /* Since we emulate only user space, we cannot do more than
        exiting the emulation with the suitable exception and error
-       code */
-    if (is_int) {
+       code. So update EIP for INT 0x80 and EXCP_SYSCALL. */
+    if (is_int || intno == EXCP_SYSCALL) {
         env->eip = next_eip;
     }
 }
```

After applying this patch, clone syscall will work.
This patch is merged into upstream: commit 47575997.

[The end]
