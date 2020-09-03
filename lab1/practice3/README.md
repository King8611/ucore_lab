# 分析bootloader进入保护模式的过程
BIOS将通过读取硬盘主引导扇区到内存，并转跳到对应内存中的位置执行bootloader。请分析bootloader是如何完成从实模式进入保护模式的。

提示：需要阅读小节“保护模式和分段机制”和lab1/boot/bootasm.S源码，了解如何从实模式切换到保护模式。

问题1：
>为何开启A20，以及如何开启A20

先回答第一个问题，为了兼容早起的版本，x86在开机的时候是实模式状态，寻址空间是1m。寄存器只有16位，为了模拟1m的寻址空间，用cs和ip来寻址(cs*16+ip)，但是cs和ip这样组合是有可能大于1m的，为了防止这种现象，在实模式下先关闭A20地址线，等到进入保护模式在开启。<br>
下面是开启A20地址线代码。
```
seta20.1:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.1

    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port

seta20.2:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.2

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1

```
看一下这段代码（昨天梦里都在看）：
```
seta20.1:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.1
```
参考手册附录中有说明，从64h读取Status Register，然后对应的第2(index为1)个bit如果位1的话，说明input register (60h/64h) 有数据。

这里用test指令和jnz指令对这一步进行判断，这里只有input register 里面没有数据才能进行下一个指令。

```
    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port
```
这一步是通过向0x64发送一个0xd1信号，然后就可以向0x60缓冲区写数据了。

然后通过讲p2的第2个bit置为1，开启A20地址线。


总结：先判断input register是否为空，空后向0x64写入0xd1。
然后再次判断，然后向0x60写入0xdf开启A20地址线。

问题2：
>如何初始化GDT表

问题3
>如何使能和进入保护模式






涉及汇编指令：
```asm
    cli:禁止中断 
    cld:清除方向标志，即将DF置‘0’。STD为设置方向标志，即将DF置‘1’。
    test:按位与运算
    in      I/O端口输入. ( 语法: IN   累加器,    {端口号│DX} )  
    out     I/O端口输出. ( 语法: OUT {端口号│DX},累加器 )输入输出端口由立即方式指定时,    其范围是 0-255; 由寄存器 DX 指定时,其范围是    0-65535.  

    jnz(jmp not zero):zf不为零则转移。
    zf位:零标志ZF用来反映运算结果是否为0。如果运算结果为0，则其值为1，否则其值为0。

    test:用来对两个数进行与运算，如果为1，则zf值位1。
    
```