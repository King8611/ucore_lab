void
print_stackframe(void) {
     /* LAB1 YOUR CODE : STEP 1 */
     /* (1) call read_ebp() to get the value of ebp. the type is (uint32_t);
      * (2) call read_eip() to get the value of eip. the type is (uint32_t);
      * (3) from 0 .. STACKFRAME_DEPTH
      *    (3.1) printf value of ebp, eip
      *    (3.2) (uint32_t)calling arguments [0..4] = the contents in address (uint32_t)ebp +2 [0..4]
      *    (3.3) cprintf("\n");
      *    (3.4) call print_debuginfo(eip-1) to print the C calling function name and line number, etc.
      *    (3.5) popup a calling stackframe
      *           NOTICE: the calling funciton's return addr eip  = ss:[ebp+4]
      *                   the calling funciton's ebp = ss:[ebp]
      */
     //获取eip,ebp的值（这里ebp选取指针方便后续操作）
    uint32_t *ebp=(uint32_t *)read_ebp();
    uint32_t eip=read_eip();
    for(int i=0;i<STACKFRAME_DEPTH&&ebp!=0;i++){
        cprintf("ebp:0x%08x eip:0x%08x args:",ebp,eip);
        for(int j=0;j<4;j++){
            cprintf("0x%08x ",ebp[2+j]);
        }
        cprintf("\n");
        print_debuginfo(eip - 1);
        eip=ebp[1];
         ebp=(uint32_t*)ebp[0];
    }
}