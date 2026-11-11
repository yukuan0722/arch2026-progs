# rubik_solve_asm: shortest 2x2x2 cube solution using iterative deepening.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
# a0 = state, a1 = out, a2 = cap; result in a0
#
# RV32I only. No heap or recursion. Tests: tests/trubik.c.

    .text
    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    mv      t0, a0                     # 輸入字串的讀取位置
    la      t1, .Lsolved_state

.Lcompare:
    lbu     t2, 0(t0)
    lbu     t3, 0(t1)
    bne     t2, t3, .Ldifferent
    beq     t2, zero, .Lsolved

    addi    t0, t0, 1
    addi    t1, t1, 1
    j       .Lcompare

.Lsolved:
    beq     a2, zero, .Ltoo_small
    sb      zero, 0(a1)
    li      a0, 0
    ret

.Ltoo_small:
    li      a0, -2
    ret

.Ldifferent:
    mv      t0, a0                     # 從原始輸入的開頭重新讀
    li      t1, 14                     # 需要讀取 14 個字元

.Llength_loop:
    lbu     t2, 0(t0)
    beq     t2, zero, .Linvalid
    addi    t0, t0, 1
    addi    t1, t1, -1
    bne     t1, zero, .Llength_loop

    lbu     t2, 0(t0)                  # 第 15 個 byte 必須是 NUL
    bne     t2, zero, .Linvalid

    mv      t0, a0
    addi    t1, a0, 7                  # 第 8 個字元是方向資料的開頭
    li      t2, 0                      # 記錄已出現的角塊
    li      t3, 7
    li      t6, 1

.Lpermutation_loop:
    lbu     t4, 0(t0)
    addi    t4, t4, -49
    bgeu    t4, t3, .Linvalid

    sll     t5, t6, t4
    and     t4, t2, t5
    bne     t4, zero, .Linvalid
    or      t2, t2, t5

    addi    t0, t0, 1
    bne     t0, t1, .Lpermutation_loop

    addi    t1, a0, 14
    li      t2, 0                      # 方向值總和除以三的餘數
    li      t3, 3

.Lorientation_loop:
    lbu     t4, 0(t0)
    addi    t4, t4, -49
    bgeu    t4, t3, .Linvalid

    add     t2, t2, t4
    bltu    t2, t3, .Lorientation_next
    addi    t2, t2, -3

.Lorientation_next:
    addi    t0, t0, 1
    bne     t0, t1, .Lorientation_loop

    bne     t2, zero, .Linvalid
    beq     a2, zero, .Ltoo_small

    addi    t0, a0, 7
    addi    t1, a0, 13                 # 只用前六個方向計算編號
    li      a3, 0

.Lrank_orientation_loop:
    lbu     t2, 0(t0)
    addi    t2, t2, -49

    slli    t3, a3, 1
    add     a3, a3, t3
    add     a3, a3, t2                 # 編號 = 舊編號乘三 + 方向值

    addi    t0, t0, 1
    bne     t0, t1, .Lrank_orientation_loop

    mv      t0, a0
    addi    t1, a0, 7
    addi    a5, a0, 6
    la      t6, .Lpermutation_weights
    li      a4, 0                      # 排列編號

.Lrank_permutation_outer:
    lbu     t2, 0(t0)
    lhu     t3, 0(t6)
    addi    t4, t0, 1

.Lrank_permutation_inner:
    lbu     t5, 0(t4)
    bgeu    t5, t2, .Lrank_permutation_next
    add     a4, a4, t3

.Lrank_permutation_next:
    addi    t4, t4, 1
    bne     t4, t1, .Lrank_permutation_inner

    addi    t0, t0, 1
    addi    t6, t6, 2
    bne     t0, a5, .Lrank_permutation_outer

    # Save callee-saved registers. The frame holds the path and DFS state.
    # 0..47 saved registers, 48..51 root ranks, 56..66 path, 80..191 DFS.
    addi    sp, sp, -192
    sw      s0, 0(sp)
    sw      s1, 4(sp)
    sw      s2, 8(sp)
    sw      s3, 12(sp)
    sw      s4, 16(sp)
    sw      s5, 20(sp)
    sw      s6, 24(sp)
    sw      s7, 28(sp)
    sw      s8, 32(sp)
    sw      s9, 36(sp)
    sw      s10, 40(sp)
    sw      s11, 44(sp)

    sh      a4, 48(sp)
    sh      a3, 50(sp)
    addi    a0, sp, 80                 # Address of the root search frame.
    la      s0, rubik_permutation_next_asm
    la      s1, rubik_orientation_next_asm
    la      s2, rubik_permutation_pdb_asm
    la      s3, rubik_orientation_pdb_asm
    la      s4, rubik_near_goal_asm
    li      s5, 16380                  # Byte offset mask for 4096 words.
    li      s9, 255                    # End marker for a move list.
    la      s10, .Lafter_face
    li      s11, 4                    # Exact distance table radius.

    jal     t6, .Lnear_find
    bne     t0, zero, .Lroot_near

    li      s7, 5
    add     t0, s2, a4
    lbu     t0, 0(t0)
    bgeu    s7, t0, .Lroot_orientation_bound
    mv      s7, t0

.Lroot_orientation_bound:
    add     t0, s3, a3
    lbu     t0, 0(t0)
    bgeu    s7, t0, .Lstart_bound
    mv      s7, t0

.Lstart_bound:
    mv      s6, a0
    addi    s8, s7, -1                 # Remaining budget after the next move.
    lhu     a4, 48(sp)
    lhu     a3, 50(sp)
    la      a5, .Lall_moves

.Lset_transition_rows:
    slli    t2, a4, 4
    slli    t3, a4, 1
    add     t2, t2, t3
    add     a6, s0, t2                 # Nine halfwords per permutation.
    slli    t2, a3, 4
    slli    t3, a3, 1
    add     t2, t2, t3
    add     a7, s1, t2                 # Nine halfwords per orientation.

.Ltry_move:
    lbu     t0, 0(a5)
    beq     t0, s9, .Lbacktrack
    addi    a5, a5, 1
    andi    t1, t0, 31                 # Low bits are the move's byte offset.

    add     t2, a6, t1
    lhu     a4, 0(t2)
    add     t2, s2, a4
    lbu     t2, 0(t2)
    bltu    s8, t2, .Ltry_move

    add     t2, a7, t1
    lhu     a3, 0(t2)
    add     t2, s3, a3
    lbu     t2, 0(t2)
    bltu    s8, t2, .Ltry_move

    sb      t1, 12(s6)
    beq     s8, s11, .Lsearch_leaf

    sw      a6, 0(s6)
    sw      a7, 4(s6)
    sw      a5, 8(s6)
    addi    s6, s6, 16
    addi    s8, s8, -1
    srli    t0, t0, 5                  # High bits identify the move's face.
    slli    t0, t0, 3
    add     a5, s10, t0                # Exclude consecutive turns of that face.
    j       .Lset_transition_rows

.Lbacktrack:
    beq     s6, a0, .Lnext_bound
    addi    s6, s6, -16
    lw      a6, 0(s6)
    lw      a7, 4(s6)
    lw      a5, 8(s6)
    addi    s8, s8, 1
    j       .Ltry_move

.Lnext_bound:
    addi    s7, s7, 1
    li      t0, 11
    bltu    t0, s7, .Lsearch_failure
    j       .Lstart_bound

.Lsearch_leaf:
    jal     t6, .Lnear_find
    beq     t0, zero, .Ltry_move

    addi    a5, sp, 56
    mv      t2, a0
    addi    t3, s6, 16

.Lcopy_prefix:
    lbu     t4, 12(t2)
    sb      t4, 0(a5)
    addi    a5, a5, 1
    addi    t2, t2, 16
    bne     t2, t3, .Lcopy_prefix
    j       .Lappend_near

.Lroot_near:
    addi    a5, sp, 56

.Lappend_near:
    andi    t1, t0, 112                # Exact distance in bits 4 through 6.
    beq     t1, zero, .Lformat_solution
    andi    t2, t0, 15
    addi    t2, t2, -1                 # Move toward the solved state.
    slli    t2, t2, 1
    sb      t2, 0(a5)
    addi    a5, a5, 1

    slli    t3, a4, 4
    slli    t4, a4, 1
    add     t3, t3, t4
    add     t3, s0, t3
    add     t3, t3, t2
    lhu     a4, 0(t3)

    slli    t3, a3, 4
    slli    t4, a3, 1
    add     t3, t3, t4
    add     t3, s1, t3
    add     t3, t3, t2
    lhu     a3, 0(t3)

    jal     t6, .Lnear_find
    beq     t0, zero, .Lsearch_failure
    j       .Lappend_near

.Lformat_solution:
    addi    a6, sp, 56
    sub     a7, a5, a6                 # Number of moves.
    mv      t0, a6
    mv      t2, a7                     # Spaces between moves plus final NUL.
    la      t6, .Lmove_text

.Lmeasure_move:
    lbu     t1, 0(t0)
    add     t1, t6, t1
    lbu     t1, 1(t1)
    sltu    t1, zero, t1
    addi    t2, t2, 1
    add     t2, t2, t1
    addi    t0, t0, 1
    bne     t0, a5, .Lmeasure_move

    bltu    a2, t2, .Lsearch_too_small
    mv      t0, a1
    li      t5, 32

.Lformat_move:
    lbu     t1, 0(a6)
    add     t1, t6, t1
    lbu     t2, 0(t1)
    lbu     t3, 1(t1)
    sb      t2, 0(t0)
    addi    t0, t0, 1
    beq     t3, zero, .Lformat_separator
    sb      t3, 0(t0)
    addi    t0, t0, 1

.Lformat_separator:
    addi    a6, a6, 1
    beq     a6, a5, .Lformat_finish
    sb      t5, 0(t0)
    addi    t0, t0, 1
    j       .Lformat_move

.Lformat_finish:
    sb      zero, 0(t0)
    mv      a0, a7
    j       .Lrestore

.Lsearch_too_small:
    sb      zero, 0(a1)
    li      a0, -2
    j       .Lrestore

.Lsearch_failure:
    li      a0, -1

.Lrestore:
    lw      s0, 0(sp)
    lw      s1, 4(sp)
    lw      s2, 8(sp)
    lw      s3, 12(sp)
    lw      s4, 16(sp)
    lw      s5, 20(sp)
    lw      s6, 24(sp)
    lw      s7, 28(sp)
    lw      s8, 32(sp)
    lw      s9, 36(sp)
    lw      s10, 40(sp)
    lw      s11, 44(sp)
    addi    sp, sp, 192
    ret

    # Input: a4 permutation, a3 orientation. Output: t0 entry or zero.
    # The return address is in t6. Scratch registers: t1, t2, t3.
.Lnear_find:
    slli    t3, a4, 10
    or      t3, t3, a3
    srli    t1, t3, 9
    xor     t1, t1, t3
    slli    t1, t1, 2
    and     t1, t1, s5

.Lnear_probe:
    add     t2, s4, t1
    lw      t0, 0(t2)
    beq     t0, zero, .Lnear_return
    srli    t2, t0, 7
    beq     t2, t3, .Lnear_return
    addi    t1, t1, 4
    and     t1, t1, s5
    j       .Lnear_probe

.Lnear_return:
    jr      t6

.Linvalid:
    li      a0, -1
    ret

    .size   rubik_solve_asm, .-rubik_solve_asm

    .section .rodata
.Lsolved_state:
    .asciz  "12345671111111"

    .balign 2
.Lpermutation_weights:
    .2byte  720, 120, 24, 6, 2, 1

.Lall_moves:
    .byte   0, 2, 4, 38, 40, 42, 76, 78, 80, 255

.Lafter_face:
    .byte   38, 40, 42, 76, 78, 80, 255, 0
    .byte   0, 2, 4, 76, 78, 80, 255, 0
    .byte   0, 2, 4, 38, 40, 42, 255, 0

.Lmove_text:
    .asciz  "R"
    .ascii  "R2", "R'"
    .asciz  "B"
    .ascii  "B2", "B'"
    .asciz  "D"
    .ascii  "D2", "D'"
