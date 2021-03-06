# 实现 first-fit 连续物理内存分配算法
>在实现first fit 内存分配算法的回收函数时，要考虑地址连续的空闲块之间的合并操作。提示:在建立空闲页块链表时，需要按照空闲页块起始地址来排序，形成一个有序的链表。可能会修改default_pmm.c中的default_init，default_init_memmap，default_alloc_pages， default_free_pages等相关函数。请仔细查看和理解default_pmm.c中的注释。

完成这个练习之前，应该首先学习一下ucore 内存管理流程，这个在实验指导书上有说明。

分析一下pmm_init函数：
```c
void
pmm_init(void) {
    // We've already enabled paging
    boot_cr3 = PADDR(boot_pgdir);

    //这个函数初始化pmm_manager，把里面的函数指针指向default_pmm.c里面的几个函数
    init_pmm_manager();

    //查找空闲内存，为其创建空闲分页列表
    page_init();

    //use pmm->check to verify the correctness of the alloc/free function in a pmm
    check_alloc_page();

    check_pgdir();

    static_assert(KERNBASE % PTSIZE == 0 && KERNTOP % PTSIZE == 0);

    // recursively insert boot_pgdir in itself
    // to form a virtual page table at virtual address VPT
    boot_pgdir[PDX(VPT)] = PADDR(boot_pgdir) | PTE_P | PTE_W;

    // map all physical memory to linear memory with base linear addr KERNBASE
    // linear_addr KERNBASE ~ KERNBASE + KMEMSIZE = phy_addr 0 ~ KMEMSIZE
    boot_map_segment(boot_pgdir, KERNBASE, KMEMSIZE, 0, PTE_W);

    // Since we are using bootloader's GDT,
    // we should reload gdt (second time, the last time) to get user segments and the TSS
    // map virtual_addr 0 ~ 4G = linear_addr 0 ~ 4G
    // then set kernel stack (ss:esp) in TSS, setup TSS in gdt, load TSS
    gdt_init();

    //now the basic virtual memory map(see memalyout.h) is established.
    //check the correctness of the basic virtual memory map.
    check_boot_pgdir();

    print_pgdir();

}

```

```c
// you should rewrite functions: `default_init`, `default_init_memmap`,
// `default_alloc_pages`, `default_free_pages`.


//  manage the free memory blocks using a list. The struct `free_area_t` is used
// for the management of free memory blocks.
//   * `list` is a simple doubly linked list implementation. You should know how to
//  * USE `list_init`, `list_add`(`list_add_after`), `list_add_before`, `list_del`,
//  * `list_next`, `list_prev`.

//  *  There's a tricky method that is to transform a general `list` struct to a
//  * special struct (such as struct `page`), using the following MACROs: `le2page`
//  * (in memlayout.h), (and in future labs: `le2vma` (in vmm.h), `le2proc` (in
//  * proc.h), etc).

```

从上面的大概描写我们知道，要实现这个方法就要重写这几个函数，然后要了解一下双向链表“list”。先看一下这里面的代码：
```c
struct list_entry {
    struct list_entry *prev, *next;
};

typedef struct list_entry list_entry_t;                     //双向循环链表

//__attribute__((always_inline))的意思是把这个函数进行强制内联。

//初始化一个节点
static inline void list_init(list_entry_t *elm) __attribute__((always_inline));

//把elm插入到listelm中，插入到第一个节点
static inline void list_add(list_entry_t *listelm, list_entry_t *elm) __attribute__((always_inline));


//把elm插入到listelm中，插入到第一个节点
static inline void list_add_before(list_entry_t *listelm, list_entry_t *elm) __attribute__((always_inline));


//把elm插入到listelm中，插入到尾节点
static inline void list_add_after(list_entry_t *listelm, list_entry_t *elm) __attribute__((always_inline));

//删除这个节点
static inline void list_del(list_entry_t *listelm) __attribute__((always_inline));

//删除这个节点后并初始化这个节点（改变头尾指针）
static inline void list_del_init(list_entry_t *listelm) __attribute__((always_inline));

//判断是否为空
static inline bool list_empty(list_entry_t *list) __attribute__((always_inline));

//返回这个节点的父节点
static inline list_entry_t *list_next(list_entry_t *listelm) __attribute__((always_inline));

//返回这个节点的子节点
static inline list_entry_t *list_prev(list_entry_t *listelm) __attribute__((always_inline));

```
以上便是list的基本用法了。


接下来需要分析一下内存初始化的步骤，先进入kern_init，找到这个函数：
```c
    pmm_init(); 
```
然后这个函数里面有重要的两步：
```c
init_pmm_manager();
page_init();
```
其中第一个函数是初始化全局内存管理器pmm_manager，是其函数指针指向default_pmm.c里面的几个函数。<br/>然后进入page_init函数，这个函数根据内存里面的空闲区域（空闲区域是在entry里面找的，找完后放到0x8000处）。根据空闲的内存块进行分页处理。（处理的过程中会调用default_init_memmap函数）。


根据以上内容先修改一下default_init_memmap函数：
```c
static void
default_init_memmap(struct Page *base, size_t n) {     //空闲块第一个页选项地址，n表示有n个空闲页
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(PageReserved(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    base->property = n;
    SetPageProperty(base);
    nr_free += n;
    list_add(&free_list, &(base->page_link));
}
```
其实上面这段代码已经实现了很多功能，只有最后一步list_add改成list_add_before就好了，因为添加的时候，地址要维持递增。

default_alloc_pages函数没什么要改的。

default_free_pages函数，最后面加个过程就好了，同样是为了维持地址递增。
