coding：
>完成kdebug.c中函数print_stackframe的实现

输出结果
```
Special kernel symbols:
  entry  0x00100000 (phys)
  etext  0x0010329c (phys)
  edata  0x0010ea16 (phys)
  end    0x0010fd20 (phys)
Kernel executable memory footprint: 64KB
ebp:0x00007b28 eip:0x00100a63 args:0x00010094 0x00010094 0x00007b58 0x00100092 
    kern/debug/kdebug.c:306: print_stackframe+21
ebp:0x00007b38 eip:0x00100092 args:0x00000000 0x00000000 0x00000000 0x00007ba8 
    kern/init/init.c:48: grade_backtrace2+33
ebp:0x00007b58 eip:0x001000bc args:0x00000000 0x00007b80 0xffff0000 0x00007b84 
    kern/init/init.c:53: grade_backtrace1+38
ebp:0x00007b78 eip:0x001000db args:0x00000000 0xffff0000 0x00007ba4 0x00000029 
    kern/init/init.c:58: grade_backtrace0+23
ebp:0x00007b98 eip:0x00100101 args:0x00000000 0x00100000 0xffff0000 0x0000001d 
    kern/init/init.c:63: grade_backtrace+34
ebp:0x00007bb8 eip:0x00100055 args:0x001032bc 0x001032a0 0x0000130a 0x00000000 
    kern/init/init.c:28: kern_init+84
ebp:0x00007be8 eip:0x00007d72 args:0x00000000 0x00000000 0x00000000 0x00007c4f 
    <unknow>: -- 0x00007d71 --
ebp:0x00007bf8 eip:0x00007c4f args:0xc031fcfa 0xc08ed88e 0x64e4d08e 0xfa7502a8 
    <unknow>: -- 0x00007c4e --
++ setup timer interrupts
```

答案见priint_stackframe.c

问题1：
>请完成实验，看看输出是否与上述显示大致一致，并解释最后一行各个数值的含义。

函数调用图：
```
kern_init ->
    grade_backtrace ->
        grade_backtrace0(0, (int)kern_init, 0xffff0000) ->
                grade_backtrace1(0, 0xffff0000) ->
                    grade_backtrace2(0, (int)&0, 0xffff0000, (int)&(0xffff0000)) ->
                        mon_backtrace(0, NULL, NULL) ->
                            print_stackframe 
```

我们对上述代码进行调试(gdbinit内容)：
```
    file bin/kernel
    set architecture i8086
    target remote :1234
    b kern_init
    continue
```

然后成功进入kern_init，我们在grade_backtrace处设置断点，这时候查看一下每个参数的值：
```
    (gdb) p /x $ebp
    $1 = 0x7be8
    (gdb) p /x $eip
    $2 = 0x100006
    (gdb) x /8x $ebp
    0x7be8: 0x00007bf8      0x00007d72      0x00000000      0x00000000
    0x7bf8: 0x00000000      0x00007c4f      0xc031fcfa      0xc08ed88e
    //可以看出，这里的值和上面的其实是对应的，除了eip是不固定的

    然后在grade_backtrace0设置断点：

    (gdb) p /x $ebp
    $3 = 0x7bb8
    (gdb) p /x $eip
    $4 = 0x1000e4
    (gdb) x /8x $ebp
    0x7bb8: 0x00007be8      0x00100055      0x001032bc      0x001032a0
    0x7bc8: 0x0000130a      0x00000000      0x00000000      0x00000000

    对比发现，这里栈中的ebp指向的内容分别是：上一个ebp，上一个指令的下一个地址，参数。
```