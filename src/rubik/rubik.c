#include "rubik.h"
#define CUBIES 7

typedef struct {
    uint8_t p[CUBIES];
    uint8_t o[CUBIES];
} state_t;

#define MOVES 9
#include "pdb_tables.h"
#include "rank_transitions.h"
static const char *const move_names[MOVES] = {"R",  "R2", "R'", "B", "B2",
                                              "B'", "D",  "D2", "D'"};

static const uint8_t move_face[MOVES] = {0, 0, 0, 1, 1, 1, 2, 2, 2};
uint16_t rank_orientation(const state_t *s)
{
    uint16_t index = 0;
    for (int i = 0; i < CUBIES - 1; i++) {
        index = index * 3 + s->o[i];
    }
    return index;
}

uint16_t factorial(uint8_t n)
{
    if (n == 0 || n == 1) {
        return 1;
    } else if (n == 2) {
        return 2;
    } else if (n == 3) {
        return 6;
    } else if (n == 4) {
        return 24;
    } else if (n == 5) {
        return 120;
    } else if (n == 6) {
        return 720;
    } else if (n == 7) {
        return 5040;
    }
    return 0;
}

uint16_t rank_permutation(const state_t *s)
{
    uint16_t index = 0;
    for (int i = 0; i < CUBIES; i++) {
        int count = 0;
        for (int j = i + 1; j < CUBIES; j++) {
            if (s->p[j] < s->p[i]) {
                count++;
            }
        }
        uint16_t sum = 0;
        for (int j = 1; j <= count; j++) {
            sum += factorial(CUBIES - 1 - i);
        }
        index += sum;
    }
    return index;
}
int max(int a, int b)
{
    return (a > b) ? a : b;
}

uint16_t heuristic(const state_t *s)
{
    uint16_t orientation_index = rank_orientation(s);
    uint16_t permutation_index = rank_permutation(s);

    return max(orientation_pdb[orientation_index],
               permutation_pdb[permutation_index]);
}

uint16_t heuristic_ranked(uint16_t p_rank, uint16_t o_rank)
{
    return max(permutation_pdb[p_rank], orientation_pdb[o_rank]);
}
int search_round(const state_t *start,
                 uint16_t bound,
                 uint8_t path[11],
                 uint16_t *next_bound)
{
    uint16_t p_ranks[12];
    uint16_t o_ranks[12];
    uint8_t next_move[12];
    int depth = 0;

    p_ranks[0] = rank_permutation(start);
    o_ranks[0] = rank_orientation(start);
    next_move[0] = 0;
    *next_bound = UINT16_MAX;
    while (depth >= 0) {
        if (p_ranks[depth] == 0 && o_ranks[depth] == 0) {
            return depth;
        }

        if (next_move[depth] >= MOVES) {
            depth--;
            continue;
        }

        uint8_t move = next_move[depth];
        next_move[depth]++;

        if (depth > 0 && move_face[move] == move_face[path[depth - 1]]) {
            continue;
        }

        uint16_t child_p = permutation_next[move][p_ranks[depth]];
        uint16_t child_o = orientation_next[move][o_ranks[depth]];

        int child_depth = depth + 1;
        uint16_t f = child_depth + heuristic_ranked(child_p, child_o);

        if (f > bound) {
            if (f < *next_bound) {
                *next_bound = f;
            }
            continue;
        }

        p_ranks[child_depth] = child_p;
        o_ranks[child_depth] = child_o;
        path[depth] = move;
        next_move[child_depth] = 0;
        depth = child_depth;
    }
    return -1;
}

int ida_star(const state_t *start, uint8_t path[11])
{
    uint16_t bound = heuristic(start);
    uint16_t next_bound;
    while (bound <= 11) {
        int result = search_round(start, bound, path, &next_bound);
        if (result >= 0) {
            return result;
        }
        if (next_bound == UINT16_MAX) {
            return -1;
        }
        bound = next_bound;
    }
    return -1;
}



static int parse_target_state(const char *input, state_t *parsed)
{
    size_t length = 0;
    while (length < RUBIK_STATE_LEN && input[length] != '\0')
        ++length;

    if (length != RUBIK_STATE_LEN || input[length] != '\0')
        return 0;

    for (int i = 0; i < CUBIES; ++i) {
        char cubie = input[i];
        char orientation = input[i + CUBIES];

        if (cubie < '1' || cubie > '7' || orientation < '1' ||
            orientation > '3')
            return 0;

        parsed->p[i] = cubie - '1';
        parsed->o[i] = orientation - '1';
    }

    unsigned remainder = 0;
    for (int i = 0; i < CUBIES; ++i) {
        for (int j = i + 1; j < CUBIES; ++j) {
            if (parsed->p[i] == parsed->p[j])
                return 0;
        }

        remainder += parsed->o[i];
        if (remainder >= 3)
            remainder -= 3;
    }

    return remainder == 0;
}


/* Dummy: reports every state as invalid. Replace with the optimal solver. */
int rubik_solve(const char *state, char *out, size_t cap)
{
    enum { MAX_SOLUTION_MOVES = 11 };
    state_t parsed;
    uint8_t path[MAX_SOLUTION_MOVES];
    char solution[3 * MAX_SOLUTION_MOVES];

    if (!parse_target_state(state, &parsed))
        return -1;

    if (cap == 0)
        return -2;

    int length = ida_star(&parsed, path);
    if (length < 0 || length > MAX_SOLUTION_MOVES)
        return -1;

    size_t used = 0;
    for (int i = 0; i < length; ++i) {
        if (i > 0)
            solution[used++] = ' ';

        const char *move = move_names[path[i]];
        while (*move != '\0')
            solution[used++] = *move++;
    }

    solution[used] = '\0';

    if (used + 1 > cap) {
        out[0] = '\0';
        return -2;
    }

    for (size_t i = 0; i <= used; ++i)
        out[i] = solution[i];

    return length;
}
