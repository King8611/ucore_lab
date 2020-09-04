通过阅读bootmain.c，了解bootloader如何加载ELF文件。通过分析源代码和通过qemu来运行并调试bootloader&OS，
问题1：
>bootloader如何读取硬盘扇区的？

* 参考手册上说明这里用的是PIO方式读取磁盘的，但是网上查阅资料说这种方式CPU利用率比较低，现在都用的DMA方式。

这里我们跟着源码一步一步来：

第一步在main函数的第89行：
```c
   readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);
```
这里调用了一个函数，我们看一下这个函数（68行开始）：
```c
/*
    这段代码我看了好久才理解（不知道为啥，总感觉怪怪的）
    这里是把硬盘的offset读取count个字节到内存va处
    因为硬盘一次最少读取一个扇区，为了保证在原va与offset对其，va向前移动一下。（然后多读取一个扇区）
    这里可能会影响到其他数据，不够这段代码应该没有体现到。
*/
readseg(uintptr_t va, uint32_t count, uint32_t offset) {
    uintptr_t end_va = va + count;

    // round down to sector boundary
    va -= offset % SECTSIZE;

    // translate from bytes to sectors; kernel starts at sector 1
    uint32_t secno = (offset / SECTSIZE) + 1;

    // If this is too slow, we could read lots of sectors at a time.
    // We'd write more to memory than asked, but it doesn't matter --
    // we load in increasing order.
    for (; va < end_va; va += SECTSIZE, secno ++) {
        readsect((void *)va, secno);
    }
}
```
这里调用了readsect函数，我们来看一下这个函数（第44行）：
```c
static void readsect(void *dst, uint32_t secno) {
    // wait for disk to be ready
    waitdisk();

    outb(0x1F2, 1);                         // count = 1，读取扇区数量
    outb(0x1F3, secno & 0xFF);
    outb(0x1F4, (secno >> 8) & 0xFF);
    outb(0x1F5, (secno >> 16) & 0xFF);
    outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0);
    outb(0x1F7, 0x20);                      // cmd 0x20 - read sectors

    // wait for disk to be ready
    waitdisk();

    // read a sector
    insl(0x1F0, dst, SECTSIZE / 4);
}
```

这里调用了waitdisk函数，我们看一下这个函数，在37行；
```c
static void waitdisk(void) {
    while ((inb(0x1F7) & 0xC0) != 0x40)
        /* do nothing */;
}
```
往下调用了inb函数，这里就不看了。其实这里就很清楚了，类似与开启A20地址总线遇到的那个，这里要等磁盘空闲。

然后根据实验手册的 **硬盘访问概述**可以的到第49行到第53行给出的指令是告诉磁盘自己要读多少扇区。（0x1F6的第四位表示主从盘，高4-7不知道表示什么，也没查到），第47行0x20信号表示要读扇区信号。

发出这个命令后就可以进行读写磁盘了，我们看insl函数的展开：
```c
static inline void  insl(uint32_t port, void *addr, int cnt) {
    asm volatile (
            "cld;"
            "repne; insl;"
            : "=D" (addr), "=c" (cnt)
            : "d" (port), "0" (addr), "1" (cnt)
            : "memory", "cc");
}
```
这段内联汇编暂时跳过，以后有需要继续来填坑。

这里大概就到这了。


问题2：
>bootloader是如何加载ELF格式的OS？

先看代码
```c
    if (ELFHDR->e_magic != ELF_MAGIC) {
        goto bad;
    }

    struct proghdr *ph, *eph;

    // load each program segment (ignores ph flags)
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
    eph = ph + ELFHDR->e_phnum;
    for (; ph < eph; ph ++) {
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    }

    // call the entry point from the ELF header
    // note: does not return
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();

```

这里ph是数据表的起始位置，eph是数据表的结束位置，循环把数据装入内存。

((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();这段代码是找到内核入口，进行执行。