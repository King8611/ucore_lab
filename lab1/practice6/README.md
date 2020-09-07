# 完善中断初始化和处理
问题1:
>中断描述符表（也可简称为保护模式下的中断向量表）中一个表项占多少字节？其中哪几位代表中断处理代码的入口？

中断描述符表有8个字节，有以下定义：
```c
//kern/mm/mmu.h
/* Gate descriptors for interrupts and traps */
struct gatedesc {
    unsigned gd_off_15_0 : 16;        // low 16 bits of offset in segment
    unsigned gd_ss : 16;            // segment selector
    unsigned gd_args : 5;            // # args, 0 for interrupt/trap gates
    unsigned gd_rsv1 : 3;            // reserved(should be zero I guess)
    unsigned gd_type : 4;            // type(STS_{TG,IG32,TG32})
    unsigned gd_s : 1;                // must be 0 (system)
    unsigned gd_dpl : 2;            // descriptor(meaning new) privilege level
    unsigned gd_p : 1;                // Present
    unsigned gd_off_31_16 : 16;        // high bits of offset in segment
};
```
从中我们可以找到段选择子的位置和偏移量的位置（一共32位，是分开的），由此可以确定中断处理的入口。


问题2:
>请编程完善kern/trap/trap.c中对中断向量表进行初始化的函数idt_init。在idt_init函数中，依次对所有中断入口进行初始化。使用mmu.h中的SETGATE宏，填充idt数组内容。每个中断的入口由tools/vectors.
c生成，使用trap.c中声明的vectors数组即可。

先看一下vector.S:
```asm
__vectors:(1281行)
  .long vector0
  .long vector1
  ……
    .long vector255
```
```asm
vector0:
  pushl $0
  pushl $0
  jmp __alltraps
.globl vector1
vector1:
  pushl $0
  pushl $1
  jmp __alltraps
.globl vector2
……
vector255:
  pushl $0
  pushl $255
  jmp __alltraps
```
由此我们可以看出，__vectors是一个内存地址，__vector[i]代码偏移量，上面是对应地址执行的命令。



里面提到了一个很重要的东西：SETGATE宏
```c
#define SETGATE(gate, istrap, sel, off, dpl) {            \
    (gate).gd_off_15_0 = (uint32_t)(off) & 0xffff;        \
    (gate).gd_ss = (sel);                                \
    (gate).gd_args = 0;                                    \
    (gate).gd_rsv1 = 0;                                    \
    (gate).gd_type = (istrap) ? STS_TG32 : STS_IG32;    \
    (gate).gd_s = 0;                                    \
    (gate).gd_dpl = (dpl);                                \
    (gate).gd_p = 1;                                    \
    (gate).gd_off_31_16 = (uint32_t)(off) >> 16;        \
}
```
这个宏里面有四个参数：
* gate：中断描述符，
* istrap：是中断还是系统调用|区别在于eflag的if是否置位（期间是否允许中断）
* sel：表示段选择子
* off：偏移量（__vectors里面的内容）
* dpl：访问权限

我们的任务便是初始化中断描述符表，所以gate传入参数为idt，而istrap这个参数，答案中一直用的0，查了好久资料，讨论区里面有一点解释，看的晕乎乎的。sel段选择子为GD_KTEXT（8），至于为什么是这个数，其实这是因为gdt_init时候是这个数。off偏移量就是传入vector的内容。而dpl，除了T_SWITCH_TOK是DPL_USER其他都是DPL_KERNEL。
所以这段代码是这样的：
```
     extern __vectors[];
     for(int i=0;i<sizeof(idt)/sizeof(struct gatedesc);i++){
        SETGATE(idt[i],0,GD_KTEXT,__vectors[i],DPL_KERNEL);
    }
    SETGATE(idt[T_SWITCH_TOK],0,GD_KTEXT,__vectors[T_SWITCH_TOK],DPL_KERNEL);
```



问题3：
>请编程完善trap.c中的中断处理函数trap，在对时钟中断进行处理的部分填写trap函数中处理时钟中断的部分，使操作系统每遇到100次时钟中断后，调用print_ticks子程序，向屏幕上打印一行文字”100 ticks”。