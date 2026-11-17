# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li t0, 0

    beq a1, zero, .fun2
.fun1:
    and t1, a0, a1
    xor a0, a0, a1
    slli a1, t1, 1
    addi t0, t0, 1
    bne a1, zero, .fun1

.fun2:
    sw t0, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2

op2_asm:
    sub a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and t0, a0, a1
    xor t1, a0, a1
    srli t1, t1, 1
    add a0, t0, t1

    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2

q_mul_asm:
    xor  t0, a0, a1          # 最高位是乘積的符號
    bge  a0, zero, .fun3
    sub  a0, zero, a0

.fun3:                       # 取 b 的絕對值
    bge  a1, zero, .fun4
    sub  a1, zero, a1

.fun4:                       # a0 是被乘數低位，t2 是高位
    li   t2, 0
    li   t3, 0               # 乘積低位
    li   t4, 0               # 乘積高位
    bne  a1, zero, .fun5     # 第一輪直接讀最低位
    li   a0, 0
    ret

.fun6:                       # 還有下一輪，才把被乘數左移
    srli t5, a0, 31
    slli a0, a0, 1
    slli t2, t2, 1
    or   t2, t2, t5

.fun5:                       # 乘數最低位為 1 時累加
    andi t5, a1, 1
    beq  t5, zero, .fun9
    add  t3, t3, a0
    sltu t6, t3, a0
    add  t4, t4, t2
    add  t4, t4, t6

.fun9:                       # 移到乘數下一位，若已歸零就結束
    srli a1, a1, 1
    bne  a1, zero, .fun6

.fun7:                       # 依 t0 的符號位補回乘積正負
    bge  t0, zero, .fun8
    sltu t5, zero, t3
    sub  t3, zero, t3
    sub  t4, zero, t4
    sub  t4, t4, t5

.fun8:                       # 加捨入常數，再取右移 20 位後的低 32 位
    li   t5, 0x80000
    add  t3, t3, t5
    sltu t6, t3, t5
    add  t4, t4, t6
    srli t3, t3, 20
    slli t4, t4, 12
    or   a0, t3, t4
    ret

    .size q_mul_asm, .-q_mul_asm
