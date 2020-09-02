## 练习1：理解通过make生成执行文件的过程。（要求在报告中写出对下述问题的回答）
>问题1：操作系统镜像文件ucore.img是如何一步一步生成的？(需要比较详细地解释Makefile中每一条相关命令和命令参数的含义，以及说明命令导致的结果)

执行make v=后的结果（做了过滤处理）
```makefile
#编译kern
+ cc kern/init/init.c
+ cc kern/libs/stdio.c
+ cc kern/libs/readline.c
+ cc kern/debug/panic.c
+ cc kern/debug/kdebug.c
+ cc kern/debug/kmonitor.c
+ cc kern/driver/clock.c
+ cc kern/driver/console.c
+ cc kern/driver/picirq.c
+ cc kern/driver/intr.c
+ cc kern/trap/trap.c
+ cc kern/trap/vectors.S
+ cc kern/trap/trapentry.S
+ cc kern/mm/pmm.c
+ cc libs/string.c
+ cc libs/printfmt.c
+ ld bin/kernel     //这条指令进行连接

#编译bootblock与sign.c文件
+ cc boot/bootasm.S
+ cc boot/bootmain.c
 #编译后的sign.c用于执行，不用于链接，把boot文件变为有效的
+ cc tools/sign.c 
+ ld bin/bootblock

#sign文件处理bootblock，使其变为符合规范的硬盘主引导扇区
#这里bootblock从492byte变成512byte
'obj/bootblock.out' size: 492 bytes
build 512 bytes boot sector: 'bin/bootblock' success!


#这里把kernel和bootblock装载到img文件里面（dd命令）
#count=n选项是装载到第N块停止，一块默认位512字节
#if参数：输入 of：输出
#这里先把0填充进img文件
dd if=/dev/zero of=bin/ucore.img count=10000

# conv = notrunc 不截断输出文件。
# seek=blocks：从输出文件开头跳过blocks个块后再开始复制。
dd if=bin/bootblock of=bin/ucore.img conv=notrunc
dd if=bin/kernel of=bin/ucore.img seek=1 conv=notrunc

```

知道了编译过程，分析makefile中的指令吧。

这里首先第一步：生成ucore.img的命令：
```makefile
# 源代码第199到209行
# create ucore.img
UCOREIMG	:= $(call totarget,ucore.img)

$(UCOREIMG): $(kernel) $(bootblock) $(kernel_nopage)
	$(V)dd if=/dev/zero of=$@ count=10000
	$(V)dd if=$(bootblock) of=$@ conv=notrunc
	$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc

$(call create_target,ucore.img)

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
```
```makefile
这里逐行分析：
200行：UCOREIMG	:= $(call totarget,ucore.img)
    这里调用了totarget函数
    totarget没有在本文中定义，而是在第91行引入的function.mk中。
    17(mk)：totarget = $(addprefix $(BINDIR)$(SLASH),$(1))
    4:SLASH	:= /    
    85:BINDIR	:= bin
    清楚的看出来，totarget的目的是在ucore.img前加上bin/前缀


59：生成UCOREIMG所需要的依赖
60：V定义在第6行，方便调试打印。
64：(call create_target,ucore.img)
    这里这个函数看的不是太懂，应该是一个调用关系
```

执行生成kernel的代码：（140-153行）
```makefile
# create kernel target
kernel = $(call totarget,kernel)

$(kernel): tools/kernel.ld

$(kernel): $(KOBJS)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
	@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
	@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)

$(call create_target,kernel)

# -------------------------------------------------------------------
```
逐行分析：
```makefile
141：kernel = $(call totarget,kernel)  #加上bin前缀
143：$(kernel): tools/kernel.ld             #依赖文件，一个链接器
145：$(kernel): $(KOBJS)                        #这里用到KOBJS依赖
    138：KOBJS	= $(call read_packet,kernel libs)   #调用read_packet函数
    90(mk)：read_packet = $(foreach p,$(call packetname,$(1)),$($(p)))
    20(mk)：packetname = $(if $(1),$(addprefix $(OBJPREFIX),$(1)),$(OBJPREFIX))
    1(mk)：OBJPREFIX	:= __objs_
    仅仅读这里执行出来的结果是：OBJPREFIX=__objs_kernel __objs_kernel_lib
    但是根据136行：$(call add_files_cc,$(call listf_cc,$(KSRCDIR)),kernel,$(KCFLAGS))
    #这部分是根据.c文件生成.o文件，不看了
146:打印参数列表
147:链接生成目标文件
148:objdump工具反汇编
149:用objdump工具来解析kernel目标文件得到符号表。

```

生成bootblock代码：155-170
```makefile
# create bootblock
bootfiles = $(call listf_cc,boot)
$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))

bootblock = $(call totarget,bootblock)

$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
	@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
	@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
	@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)

$(call create_target,bootblock)

#----------------------------------------------------------------
```
这段代码类似生成kernel代码


sign.c生成代码：173-174
```makefile
# create 'sign' tools
$(call add_files_host,tools/sign.c,sign,sign)
$(call create_target_host,sign,sign)
# -------------------------------------------------------------------
```

>一个被系统认为是符合规范的硬盘主引导扇区的特征是什么？
```c
    22: char buf[512];
    23:memset(buf, 0, sizeof(buf));
    24:FILE *ifp = fopen(argv[1], "rb");
    25:int size = fread(buf, 1, st.st_size, ifp);
    先把buf填充0，然后在读入bootblock
    31:buf[510] = 0x55;
    32:buf[511] = 0xAA;
    最后两位置位0x55AA
```

答：需要满足：520byte，有效部分在最前面，最后面是0x55AA，中间都是0


## 总结：
这个makefile好难搞啊，各种依赖好复杂，本来想完全弄明白，现在感觉难度太大了，先就这样吧。
