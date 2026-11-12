#include "gcd.h"

/* Dummy: returns 0 for every input. Replace with the binary GCD. */
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    uint32_t common_twos = 0;
    if (a == 0)
        return b;
    if (b == 0)
        return a;
    while (b != 0) {
        const uint32_t t = b & 1u;
        const uint32_t k = a & 1u;
        if ((t == 0) && (k == 0)) {
            a = a >> 1;
            b = b >> 1;
            common_twos++;
        } else if ((t == 0) && (k == 1)) {
            b = b >> 1;
        } else if ((t == 1) && (k == 0)) {
            a = a >> 1;
        } else {
            if (a > b) {
                a = (a - b) >> 1;
            } else {
                b = (b - a) >> 1;
            }
        }
    }
    return a << common_twos;
}
