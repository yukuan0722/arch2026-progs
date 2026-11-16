# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    srli t0, a0, 23 # 將指數移到最低位
    andi t0, t0, 0xff # 把 8 個 bits 的指數弄出來
    srli t1, a0, 16

    li t4, 0xff
    beq t0, t4, .re_bits

    slli a1, a0, 16 # 準備後面的 16 位 lower bits
    srli a1, a1, 16

    andi t2, t1, 1 # 看 16 bits 尾巴是奇數、偶數
    li t3, 0x7fff # 不能直接用 addi 範圍不夠
    add t2, t2, t3
    add a1, a1, t2

    srli t3, a1, 16 # 原來 16 位，加了之後最多 17 位不用再篩出來
    add t1, t1, t3

.re_bits:
    mv a0, t1
    ret

    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2


bf16_mul_asm:
    #正負號
    xor t0, a0, a1 # 正負號相乘
    li t1, 0x8000
    and t2, t0, t1 # 取出相乘後的正負號

    #指數 a
    srli t3, a0, 7
    andi t3, t3, 0xff

    #指數 b
    srli t4, a1, 7
    andi t4, t4, 0xff    

    #mantissa
    andi t5, a0, 0x7f
    andi t6, a1, 0x7f

    #判斷
    li t0, 0xff
    bne t3, t0, .fun1 # 如果 a 不是 0xff，就去檢查 b

    beq t5, zero, .fun2 # 判斷 mantissa a 是否為零
    ret 

.fun2: # a 是無限大，檢查 b 是否為正零或負零
    li t1, 0x7fff
    and t1, a1, t1
    bne t1, zero, .fun3
    li a0, 0x7fc0
    ret

.fun3:
    li t1, 0x7f80
    or a0, t2, t1 # 回傳帶符號的無限大
    ret

.fun1: # 換檢查 b
    bne t4, t0, .fun4
    beq t6, zero, .fun5 # 判斷 mantissa b 是否為零
    mv a0, a1
    ret

.fun5:
    li t1, 0x7fff
    and t1, a0, t1
    bne t1, zero, .fun6
    li a0, 0x7fc0
    ret

.fun6:
    li t1, 0x7f80
    or a0, t2, t1 # 回傳帶符號的無限大
    ret

.fun4:
    li t0, 0x7fff
    and t1, a0, t0
    bne t1, zero, .fun7
    mv a0, t2 # a 是零，回傳符號
    ret

.fun7:
# a 非零, 在檢查 b 是否為正零或負零
    and t1, a1, t0
    bne t1, zero, .fun8
    mv a0, t2 # b 是零，回傳符號
    ret

.fun8: # 檢查 a 是否為次正規數
    li t0, 0x80
    bne t3, zero, .fun15
    addi t3, t3, 1

.fun16: # 尾數未達 128 時，繼續左移並將指數減一
    slli t5, t5, 1
    addi t3, t3, -1
    sltu a2, t5, t0 # 1, t5 < t0
    bne a2, zero, .fun16

.fun15: # 補上 a 的隱藏位元，再檢查 b 的指數
    or t5, t5, t0
    bne t4, zero, .fun9 # 確認 exp_b == 0
    addi t4, t4, 1
    sltu a2, t6, t0
    beq a2, zero, .fun9

.fun10:
    slli t6, t6, 1
    addi t4, t4, -1
    sltu a2, t6, t0 # 尾數小於 128 時，a2 = 1
    bne a2, zero, .fun10

.fun9: # 補上 b 的隱藏位元，開始計算乘積
    or t6, t6, t0
    li t0, 0 # t0 累加尾數乘積

# 做乘法，利用直式乘法邏輯
.fun17: # b 的最低位為 1 時，累加目前的 a
    andi a2, t6, 1
    beq a2, zero, .fun18
    add t0, t0, t5

.fun18: # 移到 b 的下一位，同時讓 a 加倍
    srli t6, t6, 1
    slli t5, t5, 1
    bne t6, zero, .fun17

    add t1, t3, t4
    addi t1, t1, -127
    li a2, 0x8000
    sltu a2, t0, a2 # 乘積小於 0x8000 時，1
    bne a2, zero, .fun11
    srli t0, t0, 1
    addi t1, t1, 1 # 乘積右移一位，指數加一


.fun11:
    srli t0, t0, 7
    andi t0, t0, 0x7f # fraction

    li a2, 0xff
    slt a2, t1, a2
    bne a2, zero, .fun12

    li a2, 0x7f80
    or a0, t2, a2
    ret

.fun12: # 指數小於 -6，回傳帶符號的零
    li a2, -6
    slt a2, t1, a2 # 0, product_exp >= -6
    beq a2, zero, .fun13

    mv a0, t2
    ret

.fun13:
    slt a2, zero, t1 # 1, product_exp>0
    bne a2, zero, .fun14

    li a2, 1
    sub a2, a2, t1
    srl t0, t0, a2
    or a0, t2, t0
    ret

.fun14:
    slli t1, t1, 7
    or a0, t2, t1
    or a0, a0, t0
    ret

    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2

bf16_sqrt_asm:
    srli t0, a0, 7
    andi t0, t0, 0xff # exp

    andi t1, a0, 0x7f # mantissa

#如果 exp ==11111111 且 mantissa 不為 0
    li t3, 0xff
    bne t0, t3, .fun_1
    beq t1, zero, .fun_1
    ret # NaN，回傳原始 a


.fun_1:
    li t2, 0x7fff
    and t2, a0, t2
    bne t2, zero, .fun_2
    li a0, 0
    ret

.fun_2:
    li t2, 0x8000
    and t2, a0, t2
    beq t2, zero, .fun_3
    li a0, 0x7fc0
    ret

.fun_3:
    bne t0, t3, .fun_4
    ret

.fun_4:
    bne t0, zero, .fun_5
    li a0, 0
    ret

.fun_5:
    addi t2, t0, -127 # 真實的指數
    addi t1, t1, 128 # m, 補回開頭的 1

    andi t3, t2, 1
    beq t3, zero, .fun_6
    addi t2, t2, -1
    slli t1, t1, 1

.fun_6:
    srai t3, t2, 1
    addi t3, t3, 127 # result_exp
    li t4, 90 # low
    li t5, 256 # high
    li t6, 128 # best
    slt a1, t5, t4 # 0, high >= low
    bne a1, zero, .fun_12

.fun_7:
    add a1, t4, t5
    srli a1, a1, 1 # mid
    mv a3, a1
    mv a4, a1
    li a5, 0

# mid * mid
.fun_8:
    andi a2, a4, 1
    beq a2, zero, .fun_9
    add a5, a5, a3 # 最後就會是相乘的值

.fun_9:
    slli a3, a3, 1
    srli a4, a4, 1
    bne a4, zero, .fun_8

.fun_10:
    srli a5, a5, 7 # sq
    slt a6, t1, a5 # 0, t1 >= a5
    bne a6, zero, .fun_11
    mv t6, a1
    addi t4, a1, 1
    slt a1, t5, t4 # 0, high >= low
    beq a1, zero, .fun_7
    j .fun_12

.fun_11:
    addi t5, a1, -1
    slt a1, t5, t4 # 0, high >= low
    beq a1, zero, .fun_7

.fun_12:
    li t4, 256
    slt t5, t6, t4 # 0, t6 >= t4
    bne t5, zero, .fun_13
    srli t6, t6, 1  # 右移 best
    addi t3, t3, 1

.fun_13: # 指數溢位時回傳正無限大
    li t4, 0xff
    slt t5, t3, t4 # 0, t6 >= t4
    bne t5, zero, .fun_14
    li a0, 0x7f80
    ret

.fun_14:
    slt t5, zero, t3 # 0, x0 >= t6
    bne t5, zero, .fun_15
    li a0, 0
    ret

.fun_15:
    slli t3, t3, 7
    andi t6, t6, 0x7f
    or a0, t3, t6
    ret

    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
