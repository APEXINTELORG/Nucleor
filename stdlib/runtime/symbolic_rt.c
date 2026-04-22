// symbolic_rt.c — Symbolic Math (Expression Trees) for Nucleor
// Build expressions, differentiate, simplify, evaluate, codegen.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/symbolic_rt.c -o target/symbolic_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _sy_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _sy_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Expression Node
// ================================================================

#define SYM_CONST  0
#define SYM_VAR    1
#define SYM_ADD    2
#define SYM_SUB    3
#define SYM_MUL    4
#define SYM_DIV    5
#define SYM_POW    6
#define SYM_SIN    7
#define SYM_COS    8
#define SYM_EXP    9
#define SYM_LOG   10
#define SYM_NEG   11
#define SYM_SQRT  12

typedef struct Expr Expr;
struct Expr {
    int op;
    double val;       // for CONST
    char var_name[32]; // for VAR
    Expr *left, *right;
};

static Expr *expr_new(int op) {
    Expr *e = (Expr *)calloc(1, sizeof(Expr));
    e->op = op;
    return e;
}

static Expr *expr_copy(Expr *e) {
    if (!e) return NULL;
    Expr *c = (Expr *)malloc(sizeof(Expr));
    *c = *e;
    c->left = expr_copy(e->left);
    c->right = expr_copy(e->right);
    return c;
}

// ================================================================
//  Construction
// ================================================================

long long nuc_sym_const(long long val_bits) {
    Expr *e = expr_new(SYM_CONST);
    e->val = _sy_i2f(val_bits);
    return (long long)e;
}

long long nuc_sym_var(const char *name) {
    Expr *e = expr_new(SYM_VAR);
    strncpy(e->var_name, name ? name : "x", 31);
    return (long long)e;
}

static long long sym_binop(int op, long long a, long long b) {
    Expr *e = expr_new(op);
    e->left = expr_copy((Expr *)(void *)a);
    e->right = expr_copy((Expr *)(void *)b);
    return (long long)e;
}

long long nuc_sym_add(long long a, long long b) { return sym_binop(SYM_ADD, a, b); }
long long nuc_sym_sub(long long a, long long b) { return sym_binop(SYM_SUB, a, b); }
long long nuc_sym_mul(long long a, long long b) { return sym_binop(SYM_MUL, a, b); }
long long nuc_sym_div(long long a, long long b) { return sym_binop(SYM_DIV, a, b); }
long long nuc_sym_pow(long long a, long long b) { return sym_binop(SYM_POW, a, b); }

static long long sym_unary(int op, long long a) {
    Expr *e = expr_new(op);
    e->left = expr_copy((Expr *)(void *)a);
    return (long long)e;
}

long long nuc_sym_sin(long long a) { return sym_unary(SYM_SIN, a); }
long long nuc_sym_cos(long long a) { return sym_unary(SYM_COS, a); }
long long nuc_sym_exp(long long a) { return sym_unary(SYM_EXP, a); }
long long nuc_sym_log(long long a) { return sym_unary(SYM_LOG, a); }
long long nuc_sym_neg(long long a) { return sym_unary(SYM_NEG, a); }
long long nuc_sym_sqrt(long long a) { return sym_unary(SYM_SQRT, a); }

// ================================================================
//  Symbolic Differentiation
// ================================================================

long long nuc_sym_diff(long long eh, const char *var) {
    Expr *e = (Expr *)(void *)eh;
    if (!e) return nuc_sym_const(_sy_f2i(0));

    switch (e->op) {
        case SYM_CONST: return nuc_sym_const(_sy_f2i(0));
        case SYM_VAR:
            return nuc_sym_const(_sy_f2i(strcmp(e->var_name, var) == 0 ? 1 : 0));
        case SYM_ADD:
            return nuc_sym_add(nuc_sym_diff((long long)e->left, var),
                               nuc_sym_diff((long long)e->right, var));
        case SYM_SUB:
            return nuc_sym_sub(nuc_sym_diff((long long)e->left, var),
                               nuc_sym_diff((long long)e->right, var));
        case SYM_MUL: {
            // Product rule: f'g + fg'
            long long fp = nuc_sym_diff((long long)e->left, var);
            long long gp = nuc_sym_diff((long long)e->right, var);
            return nuc_sym_add(nuc_sym_mul(fp, (long long)e->right),
                               nuc_sym_mul((long long)e->left, gp));
        }
        case SYM_DIV: {
            // Quotient rule: (f'g - fg') / g^2
            long long fp = nuc_sym_diff((long long)e->left, var);
            long long gp = nuc_sym_diff((long long)e->right, var);
            long long num = nuc_sym_sub(nuc_sym_mul(fp, (long long)e->right),
                                         nuc_sym_mul((long long)e->left, gp));
            long long den = nuc_sym_mul((long long)e->right, (long long)e->right);
            return nuc_sym_div(num, den);
        }
        case SYM_SIN: {
            // cos(f) * f'
            long long fp = nuc_sym_diff((long long)e->left, var);
            return nuc_sym_mul(nuc_sym_cos((long long)e->left), fp);
        }
        case SYM_COS: {
            // -sin(f) * f'
            long long fp = nuc_sym_diff((long long)e->left, var);
            return nuc_sym_neg(nuc_sym_mul(nuc_sym_sin((long long)e->left), fp));
        }
        case SYM_EXP: {
            // exp(f) * f'
            long long fp = nuc_sym_diff((long long)e->left, var);
            return nuc_sym_mul(nuc_sym_exp((long long)e->left), fp);
        }
        case SYM_LOG: {
            // f'/f
            long long fp = nuc_sym_diff((long long)e->left, var);
            return nuc_sym_div(fp, (long long)e->left);
        }
        case SYM_NEG:
            return nuc_sym_neg(nuc_sym_diff((long long)e->left, var));
        default:
            return nuc_sym_const(_sy_f2i(0));
    }
}

// ================================================================
//  Evaluate with variable bindings
//  bindings_h: flat Vec [name_ptr, val_bits, name_ptr, val_bits, ...]
// ================================================================

static double sym_eval(Expr *e, const char **names, double *vals, int nbindings) {
    if (!e) return 0;
    switch (e->op) {
        case SYM_CONST: return e->val;
        case SYM_VAR:
            for (int i = 0; i < nbindings; i++)
                if (strcmp(e->var_name, names[i]) == 0) return vals[i];
            return 0;
        case SYM_ADD: return sym_eval(e->left, names, vals, nbindings) + sym_eval(e->right, names, vals, nbindings);
        case SYM_SUB: return sym_eval(e->left, names, vals, nbindings) - sym_eval(e->right, names, vals, nbindings);
        case SYM_MUL: return sym_eval(e->left, names, vals, nbindings) * sym_eval(e->right, names, vals, nbindings);
        case SYM_DIV: { double d = sym_eval(e->right, names, vals, nbindings); return fabs(d) > 1e-30 ? sym_eval(e->left, names, vals, nbindings) / d : 0; }
        case SYM_POW: return pow(sym_eval(e->left, names, vals, nbindings), sym_eval(e->right, names, vals, nbindings));
        case SYM_SIN: return sin(sym_eval(e->left, names, vals, nbindings));
        case SYM_COS: return cos(sym_eval(e->left, names, vals, nbindings));
        case SYM_EXP: return exp(sym_eval(e->left, names, vals, nbindings));
        case SYM_LOG: return log(sym_eval(e->left, names, vals, nbindings));
        case SYM_NEG: return -sym_eval(e->left, names, vals, nbindings);
        case SYM_SQRT: return sqrt(sym_eval(e->left, names, vals, nbindings));
        default: return 0;
    }
}

long long nuc_sym_eval(long long eh, const char *var_name, long long val_bits) {
    Expr *e = (Expr *)(void *)eh;
    double val = _sy_i2f(val_bits);
    double result = sym_eval(e, &var_name, &val, 1);
    return _sy_f2i(result);
}

// ================================================================
//  To String
// ================================================================

static void sym_to_str(Expr *e, char *buf, int *pos, int cap) {
    if (!e || *pos >= cap - 16) return;
    #define SAPPEND(s) do { int sl = (int)strlen(s); if (*pos + sl < cap) { memcpy(buf + *pos, s, sl); *pos += sl; } } while(0)

    switch (e->op) {
        case SYM_CONST: { char tmp[32]; snprintf(tmp, 32, "%.6g", e->val); SAPPEND(tmp); break; }
        case SYM_VAR: SAPPEND(e->var_name); break;
        case SYM_ADD: SAPPEND("("); sym_to_str(e->left, buf, pos, cap); SAPPEND(" + "); sym_to_str(e->right, buf, pos, cap); SAPPEND(")"); break;
        case SYM_SUB: SAPPEND("("); sym_to_str(e->left, buf, pos, cap); SAPPEND(" - "); sym_to_str(e->right, buf, pos, cap); SAPPEND(")"); break;
        case SYM_MUL: SAPPEND("("); sym_to_str(e->left, buf, pos, cap); SAPPEND(" * "); sym_to_str(e->right, buf, pos, cap); SAPPEND(")"); break;
        case SYM_DIV: SAPPEND("("); sym_to_str(e->left, buf, pos, cap); SAPPEND(" / "); sym_to_str(e->right, buf, pos, cap); SAPPEND(")"); break;
        case SYM_POW: SAPPEND("pow("); sym_to_str(e->left, buf, pos, cap); SAPPEND(", "); sym_to_str(e->right, buf, pos, cap); SAPPEND(")"); break;
        case SYM_SIN: SAPPEND("sin("); sym_to_str(e->left, buf, pos, cap); SAPPEND(")"); break;
        case SYM_COS: SAPPEND("cos("); sym_to_str(e->left, buf, pos, cap); SAPPEND(")"); break;
        case SYM_EXP: SAPPEND("exp("); sym_to_str(e->left, buf, pos, cap); SAPPEND(")"); break;
        case SYM_LOG: SAPPEND("log("); sym_to_str(e->left, buf, pos, cap); SAPPEND(")"); break;
        case SYM_NEG: SAPPEND("(-"); sym_to_str(e->left, buf, pos, cap); SAPPEND(")"); break;
        case SYM_SQRT: SAPPEND("sqrt("); sym_to_str(e->left, buf, pos, cap); SAPPEND(")"); break;
    }
    #undef SAPPEND
}

const char *nuc_sym_to_str(long long eh) {
    Expr *e = (Expr *)(void *)eh;
    int cap = 4096, pos = 0;
    char *buf = (char *)malloc(cap);
    sym_to_str(e, buf, &pos, cap);
    buf[pos] = 0;
    return buf;
}

void nuc_sym_free(long long eh) {
    Expr *e = (Expr *)(void *)eh;
    if (!e) return;
    nuc_sym_free((long long)e->left);
    nuc_sym_free((long long)e->right);
    free(e);
}
