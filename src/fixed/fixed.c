#include "fixed.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;

    while (b != 0) {
        uint32_t carry = a & b;  // 算出進位
        a = a ^ b;               // 算出這一輪不含進位的和
        b = carry << 1;          // 把進位交給下一輪
        passes++;                // 記錄跑完一輪
    }

    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t term_lo = (uint32_t) a;
    uint32_t multiplier = (uint32_t) b;

    if (a < 0)
        term_lo = 0u - term_lo;
    if (b < 0)
        multiplier = 0u - multiplier;

    uint32_t term_hi = 0;
    uint32_t product_lo = 0;
    uint32_t product_hi = 0;

    while (multiplier != 0) {
        if ((multiplier & 1u) != 0) {
            product_lo += term_lo;
            product_hi += term_hi + (product_lo < term_lo);
        }

        term_hi = (term_hi << 1) | (term_lo >> 31);
        term_lo <<= 1;
        multiplier >>= 1;
    }

    if ((a < 0) != (b < 0)) {
        const uint32_t borrow = product_lo != 0;
        product_lo = 0u - product_lo;
        product_hi = 0u - product_hi - borrow;
    }

    const uint32_t rounding = UINT32_C(1) << (Q - 1);
    product_lo += rounding;
    product_hi += product_lo < rounding;

    return (int32_t) ((product_hi << (32 - Q)) | (product_lo >> Q));
}
