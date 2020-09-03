1 #include <asm.h>asm.h头文件中包含了一些宏定义，用于定义gdt，gdt是保护模式使用的全局段描述符表，其中存储着段描述符。 2 3 # Start the CPU: switch to 32-bit protected mode, jump into C.
 4 # The BIOS loads this code from the first sector of the hard disk into
 5 # memory at physical address 0x7c00 and starts executing in real mode
 6 # with %cs=0 %ip=7c00.此段注释说明了要完成的目的：启动保护模式，转入C函数。这里正好说了一下bootasm.S文件的作用。计算机加电后，由BIOS将bootasm.S生成的可执行代码从硬盘的第一个扇区复制到内存中的物理地址0x7c00处,并开始执行。此时系统处于实模式。可用内存不多于1M。
 7 
 8 .set PROT_MODE_CSEG,        0x8                     # kernel code segment selector 9 .set PROT_MODE_DSEG,        0x10                    # kernel data segment selector这两个段选择子的作用其实是提供了gdt中代码段和数据段的索引，具体怎么用的下面用到的时候我们详细解释
10 .set CR0_PE_ON,             0x1                     # protected mode enable flag
这个变量也在下面用到的时候解释11 
12 # start address should be 0:7c00, in real mode, the beginning address of the running bootloader
13 .globl start14 start:
这两行代码相当于定义了C语言中的main函数，start就相当于main，BIOS调用程序时，从这里开始执行15 .code16                                             # Assemble for 16-bit mode因为以下代码是在实模式下执行，所以要告诉编译器使用16位模式编译。16     cli                                             # Disable interrupts
17     cld                                             # String operations increment关中断，设置字符串操作是递增方向。cld的作用是将direct flag标志位清零，it means that instructions that autoincrement the source index and destination index (like MOVS) will increase both of them。18 
19     # Set up the important data segment registers (DS, ES, SS).
20     xorw %ax, %ax                                   # Segment number zero
ax寄存器就是eax寄存器的低十六位，使用xorw清零ax，效果相当于movw $0, %ax。 但是好像xorw性能好一些，google了一下没有得到好答案21     movw %ax, %ds                                   # -> Data Segment
22     movw %ax, %es                                   # -> Extra Segment
23     movw %ax, %ss                                   # -> Stack Segment
24将段选择子清零 
25     # Enable A20:
26     #  For backwards compatibility with the earliest PCs, physical
27     #  address line 20 is tied low, so that addresses higher than
28     #  1MB wrap around to zero by default. This code undoes this.
准备工作就绪，下面开始动真格的了，激活A20地址位。先翻译注释：由于需要兼容早期pc，物理地址的第20位绑定为0，所以高于1MB的地址又回到了0x00000.好了，激活A20后，就可以访问所有4G内存了，就可以使用保护模式了。怎么激活呢，由于历史原因A20地址位由键盘控制器芯片8042管理。所以要给8042发命令激活A208042有两个IO端口：0x60和0x64， 激活流程位： 发送0xd1命令到0x64端口 --> 发送0xdf到0x60，done！29 seta20.1:30     inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
31     testb $0x2, %al
32     jnz seta20.1发送命令之前，要等待键盘输入缓冲区为空，这通过8042的状态寄存器的第2bit来观察，而状态寄存器的值可以读0x64端口得到。上面的指令的意思就是，如果状态寄存器的第2位为1，就跳到seta20.1符号处执行，知道第2位为0，代表缓冲区为空33 
34     movb $0xd1, %al                                 # 0xd1 -> port 0x64
35     outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port发送0xd1到0x64端口
36 
37 seta20.2:
38     inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
39     testb $0x2, %al
40     jnz seta20.2
41 
42     movb $0xdf, %al                                 # 0xdf -> port 0x60
43     outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1
44 到此，A20激活完成。
45     # Switch from real to protected mode, using a bootstrap GDT
46     # and segment translation that makes virtual addresses
47     # identical to physical addresses, so that the
48     # effective memory map does not change during the switch.
转入保护模式，这里需要指定一个临时的GDT，来翻译逻辑地址。这里使用的GDT通过gdtdesc段定义，它翻译得到的物理地址和虚拟地址相同，所以转换过程中内存映射不会改变49     lgdt gdtdesc载入gdt
50     movl %cr0, %eax
51     orl $CR0_PE_ON, %eax
52     movl %eax, %cr0打开保护模式标志位，相当于按下了保护模式的开关。cr0寄存器的第0位就是这个开关，通过CR0_PE_ON或cr0寄存器，将第0位置1
53 
54     # Jump to next instruction, but in 32-bit code segment.
55     # Switches processor into 32-bit mode.
56     ljmp $PROT_MODE_CSEG, $protcseg
57由于上面的代码已经打开了保护模式了，所以这里要使用逻辑地址，而不是之前实模式的地址了。这里用到了PROT_MODE_CSEG, 他的值是0x8。根据段选择子的格式定义，0x8就翻译成：　　　　　　　　INDEX　　　　　　　　 TI     CPL　　　　    0000 0000 0000 1      00      0INDEX代表GDT中的索引，TI代表使用GDTR中的GDT， CPL代表处于特权级。
PROT_MODE_CSEG选择子选择了GDT中的第1个段描述符。这里使用的gdt就是变量gdt，下面可以看到gdt的第1个段描述符的基地址是0x0000,所以经过映射后和转换前的内存映射的物理地址一样。
 
58 .code32                                             # Assemble for 32-bit mode
59 protcseg:
60     # Set up the protected-mode data segment registers
61     movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
62     movw %ax, %ds                                   # -> DS: Data Segment
63     movw %ax, %es                                   # -> ES: Extra Segment
64     movw %ax, %fs                                   # -> FS
65     movw %ax, %gs                                   # -> GS
66     movw %ax, %ss                                   # -> SS: Stack Segment
67 重新初始化各个段寄存器。
68     # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
69     movl $0x0, %ebp
70     movl $start, %esp
71     call bootmain栈顶设定在start处，也就是地址0x7c00处，call函数将返回地址入栈，将控制权交给bootmain
72 
73     # If bootmain returns (it shouldn't), loop.
74 spin:
75     jmp spin
76 
77 # Bootstrap GDT
78 .p2align 2                                          # force 4 byte alignment
79 gdt:
80     SEG_NULLASM                                     # null seg
81     SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
82     SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel
83 
84 gdtdesc:
85     .word 0x17                                      # sizeof(gdt) - 1
86     .long gdt                                       # address gdt