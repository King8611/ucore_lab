void idt_init(void) {
     extern __vectors[];
     for(int i=0;i<sizeof(idt)/sizeof(struct gatedesc);i++){
        SETGATE(idt[i],0,GD_KTEXT,__vectors[i],DPL_KERNEL);
    }
    SETGATE(idt[T_SWITCH_TOK],0,GD_KTEXT,__vectors[T_SWITCH_TOK],DPL_KERNEL);
    lidt(&idt_pd);
}