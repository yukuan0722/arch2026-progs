# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2

gcd_u32_asm:
    beq a0, zero, .Lreturn_b
    beq a1, zero, .Lreturn_a
    li t0, 0 # 共同的 2 公因數

.Lgcd_loop:
    andi t1, a0, 1
    beq t1, zero, .case3
    andi t2, a1, 1
    beq t2, zero, .case4



#.case1:
 #   srli a0, a0, 1
  #  srli a1, a1, 1
   # addi t0, t0, 1
    #j .Lgcd_loop


.case2:
    bltu a1, a0, .minusb #如果 a>b
    j .minusa 

.minusb:
    sub a0, a0, a1
    srli a0, a0, 1
    j .Lgcd_loop

.minusa: #唯一可能讓 b 變成 0 的地方
    sub a1, a1, a0
    beq a1, zero, .Lfinish # b = 0
    srli a1, a1, 1
    j .Lgcd_loop

.case3:
    srli a0, a0, 1
    andi t2, a1, 1
    bne t2, zero, .Lgcd_loop

.case1:
    srli a1, a1, 1            # b 也是偶數，接著右移 b
    addi t0, t0, 1            # 兩個數各除以 2，記下一個共同的 2
    j .Lgcd_loop


.case4:
    srli a1, a1, 1

    j .Lgcd_loop


.Lfinish:
    sll a0, a0, t0        # 補回共同的 2 因子
    .Lreturn_a:
    ret

.Lreturn_b:
    mv a0, a1
    ret

    .size   gcd_u32_asm, .-gcd_u32_asm
