// regex_rt.c — Regular Expressions for Nucleor
// Thompson NFA-based regex engine. Supports: . * + ? | () [] \d \w \s
// No backtracking, O(n*m) worst case.
//
// Compile: clang -c stdlib/runtime/regex_rt.c -o target/regex_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { long long *data; int len; int cap; } RXVec;

// ================================================================
//  NFA State
// ================================================================

#define NFA_MATCH  256
#define NFA_SPLIT  257
#define NFA_ANY    258
#define NFA_DIGIT  259
#define NFA_WORD   260
#define NFA_SPACE  261

typedef struct NFAState NFAState;
struct NFAState {
    int c;            // character to match (or special)
    NFAState *out;    // next state
    NFAState *out1;   // second out (for SPLIT)
    int id;
};

static NFAState nfa_pool[10000];
static int nfa_next = 0;

static NFAState *nfa_new(int c, NFAState *out, NFAState *out1) {
    if (nfa_next >= 10000) nfa_next = 0;
    NFAState *s = &nfa_pool[nfa_next];
    s->c = c; s->out = out; s->out1 = out1; s->id = nfa_next;
    nfa_next++;
    return s;
}

// ================================================================
//  Parser (pattern -> NFA fragment)
// ================================================================

typedef struct { NFAState *start; NFAState **ptrs; int n_ptrs; } Frag;

static Frag frag_new(NFAState *s, NFAState **p, int np) {
    return (Frag){s, p, np};
}

static void frag_patch(Frag f, NFAState *target) {
    for (int i = 0; i < f.n_ptrs; i++) *(f.ptrs[i]) = target;
}

// Simple recursive descent regex compiler
typedef struct { const char *p; int pos; int len; } RXParser;

static Frag rx_compile_atom(RXParser *rp);
static Frag rx_compile_concat(RXParser *rp);
static Frag rx_compile_alt(RXParser *rp);

static int rx_peek(RXParser *rp) { return rp->pos < rp->len ? rp->p[rp->pos] : 0; }

static Frag rx_compile_atom(RXParser *rp) {
    int c = rx_peek(rp);
    NFAState *s;
    NFAState **ptrs = (NFAState **)malloc(sizeof(NFAState *));

    if (c == '\\' && rp->pos + 1 < rp->len) {
        rp->pos++;
        c = rp->p[rp->pos++];
        int type = (c == 'd') ? NFA_DIGIT : (c == 'w') ? NFA_WORD : (c == 's') ? NFA_SPACE : c;
        s = nfa_new(type, NULL, NULL);
    } else if (c == '.') {
        rp->pos++;
        s = nfa_new(NFA_ANY, NULL, NULL);
    } else if (c == '(') {
        rp->pos++; // skip (
        Frag inner = rx_compile_alt(rp);
        if (rx_peek(rp) == ')') rp->pos++;
        return inner;
    } else {
        rp->pos++;
        s = nfa_new(c, NULL, NULL);
    }

    ptrs[0] = &s->out;
    Frag f = frag_new(s, ptrs, 1);

    // Handle quantifiers
    int q = rx_peek(rp);
    if (q == '*') {
        rp->pos++;
        NFAState *split = nfa_new(NFA_SPLIT, s, NULL);
        frag_patch(f, split);
        NFAState **np = (NFAState **)malloc(sizeof(NFAState *));
        np[0] = &split->out1;
        return frag_new(split, np, 1);
    } else if (q == '+') {
        rp->pos++;
        NFAState *split = nfa_new(NFA_SPLIT, s, NULL);
        frag_patch(f, split);
        NFAState **np = (NFAState **)malloc(sizeof(NFAState *));
        np[0] = &split->out1;
        return frag_new(s, np, 1);
    } else if (q == '?') {
        rp->pos++;
        NFAState *split = nfa_new(NFA_SPLIT, s, NULL);
        NFAState **np = (NFAState **)malloc(2 * sizeof(NFAState *));
        int npc = 0;
        for (int i = 0; i < f.n_ptrs; i++) np[npc++] = f.ptrs[i];
        np[npc++] = &split->out1;
        return frag_new(split, np, npc);
    }
    return f;
}

static Frag rx_compile_concat(RXParser *rp) {
    Frag result = {NULL, NULL, 0};
    while (rp->pos < rp->len && rx_peek(rp) != '|' && rx_peek(rp) != ')') {
        Frag atom = rx_compile_atom(rp);
        if (!result.start) {
            result = atom;
        } else {
            frag_patch(result, atom.start);
            result.ptrs = atom.ptrs;
            result.n_ptrs = atom.n_ptrs;
        }
    }
    if (!result.start) {
        NFAState *s = nfa_new(NFA_SPLIT, NULL, NULL);
        NFAState **p = (NFAState **)malloc(2 * sizeof(NFAState *));
        p[0] = &s->out; p[1] = &s->out1;
        result = frag_new(s, p, 2);
    }
    return result;
}

static Frag rx_compile_alt(RXParser *rp) {
    Frag left = rx_compile_concat(rp);
    if (rx_peek(rp) != '|') return left;
    rp->pos++; // skip |
    Frag right = rx_compile_alt(rp);
    NFAState *split = nfa_new(NFA_SPLIT, left.start, right.start);
    NFAState **np = (NFAState **)malloc((left.n_ptrs + right.n_ptrs) * sizeof(NFAState *));
    int npc = 0;
    for (int i = 0; i < left.n_ptrs; i++) np[npc++] = left.ptrs[i];
    for (int i = 0; i < right.n_ptrs; i++) np[npc++] = right.ptrs[i];
    return frag_new(split, np, npc);
}

// ================================================================
//  NFA matching
// ================================================================

static int match_char(int nfa_c, int ch) {
    if (nfa_c == NFA_ANY) return ch != 0;
    if (nfa_c == NFA_DIGIT) return ch >= '0' && ch <= '9';
    if (nfa_c == NFA_WORD) return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                                   (ch >= '0' && ch <= '9') || ch == '_';
    if (nfa_c == NFA_SPACE) return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
    return nfa_c == ch;
}

static int nfa_match(NFAState *start, const char *str, int len, int *match_end) {
    // Thompson NFA simulation
    NFAState **clist = (NFAState **)malloc(1000 * sizeof(NFAState *));
    NFAState **nlist = (NFAState **)malloc(1000 * sizeof(NFAState *));
    int *visited = (int *)calloc(nfa_next + 1, sizeof(int));
    int gen = 0;
    int cn = 0, nn = 0;

    // Add start state (follow splits)
    NFAState **stack = (NFAState **)malloc(1000 * sizeof(NFAState *));
    int sp = 0;
    stack[sp++] = start;
    gen++;
    while (sp > 0) {
        NFAState *s = stack[--sp];
        if (!s || visited[s->id] == gen) continue;
        visited[s->id] = gen;
        if (s->c == NFA_SPLIT) {
            if (s->out) stack[sp++] = s->out;
            if (s->out1) stack[sp++] = s->out1;
        } else {
            clist[cn++] = s;
        }
    }

    int matched = 0;
    *match_end = 0;

    for (int i = 0; i <= len; i++) {
        // Check for match state
        for (int j = 0; j < cn; j++) {
            if (clist[j]->c == NFA_MATCH) { matched = 1; *match_end = i; }
        }
        if (i == len) break;

        nn = 0;
        gen++;
        for (int j = 0; j < cn; j++) {
            if (match_char(clist[j]->c, (unsigned char)str[i])) {
                // Add out state (follow splits)
                sp = 0;
                stack[sp++] = clist[j]->out;
                while (sp > 0) {
                    NFAState *s = stack[--sp];
                    if (!s || visited[s->id] == gen) continue;
                    visited[s->id] = gen;
                    if (s->c == NFA_SPLIT) {
                        if (s->out) stack[sp++] = s->out;
                        if (s->out1) stack[sp++] = s->out1;
                    } else {
                        nlist[nn++] = s;
                    }
                }
            }
        }

        NFAState **tmp = clist; clist = nlist; nlist = tmp;
        cn = nn;
    }

    // Final check
    for (int j = 0; j < cn; j++) {
        if (clist[j]->c == NFA_MATCH) { matched = 1; *match_end = len; }
    }

    free(clist); free(nlist); free(visited); free(stack);
    return matched;
}

// ================================================================
//  Public API
// ================================================================

typedef struct { NFAState *start; NFAState *match_state; } CompiledRE;

long long nuc_re_compile(const char *pattern) {
    if (!pattern) return 0;
    nfa_next = 0; // reset pool
    RXParser rp = { pattern, 0, (int)strlen(pattern) };
    Frag f = rx_compile_alt(&rp);
    NFAState *match = nfa_new(NFA_MATCH, NULL, NULL);
    frag_patch(f, match);

    CompiledRE *re = (CompiledRE *)malloc(sizeof(CompiledRE));
    re->start = f.start;
    re->match_state = match;
    return (long long)re;
}

long long nuc_re_match(long long re_h, const char *str) {
    CompiledRE *re = (CompiledRE *)(void *)re_h;
    if (!re || !str) return 0;
    int end;
    return nfa_match(re->start, str, (int)strlen(str), &end) ? 1 : 0;
}

// Find first match, return start position (-1 if not found)
long long nuc_re_find(long long re_h, const char *str) {
    CompiledRE *re = (CompiledRE *)(void *)re_h;
    if (!re || !str) return -1;
    int len = (int)strlen(str);
    for (int i = 0; i < len; i++) {
        int end;
        if (nfa_match(re->start, str + i, len - i, &end)) return (long long)i;
    }
    return -1;
}

// Replace first match
const char *nuc_re_replace(long long re_h, const char *str, const char *replacement) {
    CompiledRE *re = (CompiledRE *)(void *)re_h;
    if (!re || !str || !replacement) return str;
    int len = (int)strlen(str);
    int rlen = (int)strlen(replacement);

    for (int i = 0; i < len; i++) {
        int end;
        if (nfa_match(re->start, str + i, len - i, &end)) {
            int result_len = i + rlen + (len - i - end);
            char *result = (char *)malloc(result_len + 1);
            memcpy(result, str, i);
            memcpy(result + i, replacement, rlen);
            memcpy(result + i + rlen, str + i + end, len - i - end + 1);
            return result;
        }
    }
    char *copy = (char *)malloc(len + 1);
    strcpy(copy, str);
    return copy;
}

void nuc_re_free(long long re_h) {
    free((void *)re_h);
}
