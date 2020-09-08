# 实现 first-fit 连续物理内存分配算法
>在实现first fit 内存分配算法的回收函数时，要考虑地址连续的空闲块之间的合并操作。提示:在建立空闲页块链表时，需要按照空闲页块起始地址来排序，形成一个有序的链表。可能会修改default_pmm.c中的default_init，default_init_memmap，default_alloc_pages， default_free_pages等相关函数。请仔细查看和理解default_pmm.c中的注释。

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


