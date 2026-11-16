#include "bf16.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint16_t bf16bits = (uint16_t) (f32bits >> 16);
    uint32_t exponent =
        (f32bits >> 23) & 0xffu;  // 確認指數，判斷是無限大還是 Nah

    if (exponent == 0xffu)
        return bf16bits;


    uint32_t lower_bits = (uint32_t) (f32bits & 0xFFFF);
    lower_bits += (0x7FFFu + (bf16bits & 1u));  // round to nearest even

    uint16_t round_bit = (lower_bits >> 16) & 1u;
    bf16bits += round_bit;

    return bf16bits;
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    // 正負號
    uint16_t sign_a = (a >> 15) & 1u;
    uint16_t sign_b = (b >> 15) & 1u;
    uint16_t sign_result = sign_a ^ sign_b;
    // 指數
    int exp_a = (a >> 7) & 0xFFu;
    int exp_b = (b >> 7) & 0xFFu;
    // 尾數
    uint16_t mantisa_a = (a & 0x7Fu);
    uint16_t mantisa_b = (b & 0x7Fu);


    uint16_t sign_bits = sign_result << 15;
    int zero_a = (a & 0x7fffu) == 0;  // 判斷低 15 位元是否全為 0
    int zero_b = (b & 0x7fffu) == 0;


    if (exp_a == 0xFFu) {
        if (mantisa_a != 0) {
            return a;  // NaN
        }
        if (zero_b) {
            return 0x7FC0u;  // NaN
        }
        return sign_bits | (0x7F80u);  // 正負無窮大
    }

    if (exp_b == 0xFFu) {
        if (mantisa_b != 0) {
            return b;  // NaN
        }
        if (zero_a) {
            return 0x7FC0u;  // NaN
        }
        return sign_bits | (0x7F80u);  // 正負無窮大
    }

    if (zero_a || zero_b) {  // 是0，乘甚麼都是0
        return sign_bits;
    }

    if (exp_a == 0) {
        exp_a = 1;
        while (mantisa_a < 0x80u) {
            mantisa_a <<= 1;
            --exp_a;
        }
    } else {
        mantisa_a |= 0x80u;  // 補回開頭的 1
    }
    if (exp_b == 0) {
        exp_b = 1;
        while (mantisa_b < 0x80u) {
            mantisa_b <<= 1;
            --exp_b;
        }
    } else {
        mantisa_b |= 0x80u;
    }


    uint32_t product_mantisa = mantisa_a * mantisa_b;
    int product_exp = exp_a + exp_b - 127;
    if (product_mantisa >= 0x8000u) {  // pro/2^14 >=2
        product_mantisa >>= 1;         // 右移一位
        product_exp += 1;              // 指數+1
    }
    uint16_t fraction = (product_mantisa >> 7) & 0x7fu;
    if (product_exp >= 0xFF) {
        return (sign_result << 15) | 0x7F80u;  // Infinity
    }
    if (product_exp <= -6) {
        return (sign_result << 15);  // 0
    }
    if (product_exp <= 0) {
        return sign_bits | (fraction >> (1 - product_exp));
    }

    return sign_bits | (product_exp << 7) | fraction;
}


uint16_t bf16_sqrt(uint16_t a)
{
    uint16_t exp = (a >> 7) & 0xFFu;
    uint16_t mantisa = a & 0x7Fu;
    if ((exp == 0xFFu) && (mantisa != 0)) {
        return a;  // NaN
    }
    if ((a & 0x7FFFu) == 0) {
        return 0;  // 0
    }
    if ((a & 0x8000u) != 0) {  // 判斷是否是負數
        return 0x7FC0u;        // NaN
    }
    if (exp == 0xFFu) {
        return a;  // Infinity
    }
    if (exp == 0) {
        return 0;
    }

    int e = exp - 127;            // 真實的指數
    uint32_t m = 128u + mantisa;  // 補回開頭的 1

    if (e % 2 != 0) {
        --e;
        m <<= 1;  // 乘以2
    }

    int result_exp = (e / 2) + 127;
    int low = 90, high = 256, best = 128;
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        uint32_t sq = (mid * mid) >> 7;
        if (sq <= m) {
            best = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }
    if (best >= 256) {
        best >>= 1;
        ++result_exp;
    }
    if (result_exp >= 0xFF) {
        return 0x7F80u;  // Infinity
    }
    if (result_exp <= 0) {
        return 0;
    }
    return (result_exp << 7) | (best & 0x7Fu);
}
