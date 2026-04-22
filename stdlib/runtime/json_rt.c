// json_rt.c — JSON Parser and Generator for Nucleor
// Recursive descent parser, tree-based DOM, handles objects/arrays/strings/numbers/bools/null.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/json_rt.c -o target/json_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _js_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _js_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  JSON Node Types
// ================================================================

#define JSON_NULL    0
#define JSON_BOOL    1
#define JSON_INT     2
#define JSON_FLOAT   3
#define JSON_STRING  4
#define JSON_ARRAY   5
#define JSON_OBJECT  6

typedef struct JNode JNode;
struct JNode {
    int type;
    // Value storage
    long long int_val;
    double float_val;
    char *str_val;
    int bool_val;
    // Array / Object children
    JNode **children;
    char **keys;       // only for objects
    int n_children;
    int cap_children;
};

static JNode *jnode_new(int type) {
    JNode *n = (JNode *)calloc(1, sizeof(JNode));
    n->type = type;
    return n;
}

static void jnode_add_child(JNode *parent, const char *key, JNode *child) {
    if (parent->n_children >= parent->cap_children) {
        parent->cap_children = parent->cap_children * 2 + 8;
        parent->children = (JNode **)realloc(parent->children, parent->cap_children * sizeof(JNode *));
        if (parent->type == JSON_OBJECT)
            parent->keys = (char **)realloc(parent->keys, parent->cap_children * sizeof(char *));
    }
    parent->children[parent->n_children] = child;
    if (parent->type == JSON_OBJECT && key) {
        parent->keys[parent->n_children] = (char *)malloc(strlen(key) + 1);
        strcpy(parent->keys[parent->n_children], key);
    }
    parent->n_children++;
}

// ================================================================
//  Parser
// ================================================================

typedef struct { const char *s; int pos; int len; } JParser;

static void jp_skip_ws(JParser *p) {
    while (p->pos < p->len) {
        char c = p->s[p->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') p->pos++;
        else break;
    }
}

static char jp_peek(JParser *p) {
    jp_skip_ws(p);
    return (p->pos < p->len) ? p->s[p->pos] : 0;
}

static char jp_next(JParser *p) {
    jp_skip_ws(p);
    return (p->pos < p->len) ? p->s[p->pos++] : 0;
}

static int jp_match(JParser *p, const char *lit) {
    jp_skip_ws(p);
    int n = (int)strlen(lit);
    if (p->pos + n > p->len) return 0;
    if (memcmp(p->s + p->pos, lit, n) == 0) { p->pos += n; return 1; }
    return 0;
}

static JNode *jp_parse_value(JParser *p);

static char *jp_parse_string_raw(JParser *p) {
    if (jp_next(p) != '"') return NULL;
    int start = p->pos;
    while (p->pos < p->len && p->s[p->pos] != '"') {
        if (p->s[p->pos] == '\\') p->pos++; // skip escaped char
        p->pos++;
    }
    int end = p->pos;
    p->pos++; // skip closing quote
    int len = end - start;
    char *s = (char *)malloc(len + 1);
    // Process escape sequences
    int j = 0;
    for (int i = start; i < end; i++) {
        if (p->s[i] == '\\' && i + 1 < end) {
            i++;
            switch (p->s[i]) {
                case 'n': s[j++] = '\n'; break;
                case 't': s[j++] = '\t'; break;
                case 'r': s[j++] = '\r'; break;
                case '"': s[j++] = '"'; break;
                case '\\': s[j++] = '\\'; break;
                case '/': s[j++] = '/'; break;
                default: s[j++] = p->s[i]; break;
            }
        } else {
            s[j++] = p->s[i];
        }
    }
    s[j] = 0;
    return s;
}

static JNode *jp_parse_string(JParser *p) {
    char *s = jp_parse_string_raw(p);
    if (!s) return jnode_new(JSON_NULL);
    JNode *n = jnode_new(JSON_STRING);
    n->str_val = s;
    return n;
}

static JNode *jp_parse_number(JParser *p) {
    jp_skip_ws(p);
    int start = p->pos;
    int is_float = 0;
    if (p->s[p->pos] == '-') p->pos++;
    while (p->pos < p->len && p->s[p->pos] >= '0' && p->s[p->pos] <= '9') p->pos++;
    if (p->pos < p->len && p->s[p->pos] == '.') { is_float = 1; p->pos++; }
    while (p->pos < p->len && p->s[p->pos] >= '0' && p->s[p->pos] <= '9') p->pos++;
    if (p->pos < p->len && (p->s[p->pos] == 'e' || p->s[p->pos] == 'E')) {
        is_float = 1; p->pos++;
        if (p->pos < p->len && (p->s[p->pos] == '+' || p->s[p->pos] == '-')) p->pos++;
        while (p->pos < p->len && p->s[p->pos] >= '0' && p->s[p->pos] <= '9') p->pos++;
    }
    char *tmp = (char *)malloc(p->pos - start + 1);
    memcpy(tmp, p->s + start, p->pos - start);
    tmp[p->pos - start] = 0;

    JNode *n;
    if (is_float) {
        n = jnode_new(JSON_FLOAT);
        n->float_val = atof(tmp);
    } else {
        n = jnode_new(JSON_INT);
        n->int_val = atoll(tmp);
        n->float_val = (double)n->int_val;
    }
    free(tmp);
    return n;
}

static JNode *jp_parse_array(JParser *p) {
    jp_next(p); // skip '['
    JNode *arr = jnode_new(JSON_ARRAY);
    if (jp_peek(p) == ']') { jp_next(p); return arr; }
    while (1) {
        JNode *val = jp_parse_value(p);
        jnode_add_child(arr, NULL, val);
        char c = jp_peek(p);
        if (c == ',') { jp_next(p); continue; }
        if (c == ']') { jp_next(p); break; }
        break; // malformed
    }
    return arr;
}

static JNode *jp_parse_object(JParser *p) {
    jp_next(p); // skip '{'
    JNode *obj = jnode_new(JSON_OBJECT);
    if (jp_peek(p) == '}') { jp_next(p); return obj; }
    while (1) {
        char *key = jp_parse_string_raw(p);
        jp_skip_ws(p);
        if (p->pos < p->len && p->s[p->pos] == ':') p->pos++;
        JNode *val = jp_parse_value(p);
        jnode_add_child(obj, key, val);
        free(key);
        char c = jp_peek(p);
        if (c == ',') { jp_next(p); continue; }
        if (c == '}') { jp_next(p); break; }
        break;
    }
    return obj;
}

static JNode *jp_parse_value(JParser *p) {
    char c = jp_peek(p);
    if (c == '"') return jp_parse_string(p);
    if (c == '{') return jp_parse_object(p);
    if (c == '[') return jp_parse_array(p);
    if (c == 't') { jp_match(p, "true"); JNode *n = jnode_new(JSON_BOOL); n->bool_val = 1; return n; }
    if (c == 'f') { jp_match(p, "false"); JNode *n = jnode_new(JSON_BOOL); n->bool_val = 0; return n; }
    if (c == 'n') { jp_match(p, "null"); return jnode_new(JSON_NULL); }
    if (c == '-' || (c >= '0' && c <= '9')) return jp_parse_number(p);
    return jnode_new(JSON_NULL);
}

// ================================================================
//  Public API
// ================================================================

long long nuc_json_parse(const char *str) {
    if (!str) return 0;
    JParser p = { str, 0, (int)strlen(str) };
    JNode *root = jp_parse_value(&p);
    return (long long)root;
}

long long nuc_json_type(long long h) {
    JNode *n = (JNode *)(void *)h;
    return n ? (long long)n->type : 0;
}

long long nuc_json_get_int(long long h, const char *key) {
    JNode *n = (JNode *)(void *)h;
    if (!n || n->type != JSON_OBJECT) return 0;
    for (int i = 0; i < n->n_children; i++) {
        if (n->keys[i] && strcmp(n->keys[i], key) == 0) {
            JNode *c = n->children[i];
            if (c->type == JSON_INT || c->type == JSON_FLOAT) return c->int_val;
            return 0;
        }
    }
    return 0;
}

long long nuc_json_get_float(long long h, const char *key) {
    JNode *n = (JNode *)(void *)h;
    if (!n || n->type != JSON_OBJECT) return _js_f2i(0.0);
    for (int i = 0; i < n->n_children; i++) {
        if (n->keys[i] && strcmp(n->keys[i], key) == 0) {
            JNode *c = n->children[i];
            return _js_f2i(c->float_val);
        }
    }
    return _js_f2i(0.0);
}

const char *nuc_json_get_str(long long h, const char *key) {
    JNode *n = (JNode *)(void *)h;
    if (!n || n->type != JSON_OBJECT) return "";
    for (int i = 0; i < n->n_children; i++) {
        if (n->keys[i] && strcmp(n->keys[i], key) == 0) {
            JNode *c = n->children[i];
            return c->str_val ? c->str_val : "";
        }
    }
    return "";
}

long long nuc_json_get_bool(long long h, const char *key) {
    JNode *n = (JNode *)(void *)h;
    if (!n || n->type != JSON_OBJECT) return 0;
    for (int i = 0; i < n->n_children; i++) {
        if (n->keys[i] && strcmp(n->keys[i], key) == 0) {
            return n->children[i]->bool_val ? 1 : 0;
        }
    }
    return 0;
}

long long nuc_json_get_array(long long h, const char *key) {
    JNode *n = (JNode *)(void *)h;
    if (!n || n->type != JSON_OBJECT) return 0;
    for (int i = 0; i < n->n_children; i++) {
        if (n->keys[i] && strcmp(n->keys[i], key) == 0) {
            return (long long)n->children[i];
        }
    }
    return 0;
}

long long nuc_json_get_object(long long h, const char *key) {
    return nuc_json_get_array(h, key);
}

long long nuc_json_array_len(long long h) {
    JNode *n = (JNode *)(void *)h;
    if (!n) return 0;
    return (long long)n->n_children;
}

long long nuc_json_array_get(long long h, long long idx) {
    JNode *n = (JNode *)(void *)h;
    if (!n || (int)idx < 0 || (int)idx >= n->n_children) return 0;
    return (long long)n->children[(int)idx];
}

// Get value from a leaf node (works on any node type)
long long nuc_json_as_int(long long h) {
    JNode *n = (JNode *)(void *)h;
    if (!n) return 0;
    if (n->type == JSON_INT) return n->int_val;
    if (n->type == JSON_FLOAT) return (long long)n->float_val;
    if (n->type == JSON_BOOL) return n->bool_val;
    return 0;
}

long long nuc_json_as_float(long long h) {
    JNode *n = (JNode *)(void *)h;
    if (!n) return _js_f2i(0.0);
    return _js_f2i(n->float_val);
}

const char *nuc_json_as_str(long long h) {
    JNode *n = (JNode *)(void *)h;
    if (!n || !n->str_val) return "";
    return n->str_val;
}

// ================================================================
//  Builder API
// ================================================================

long long nuc_json_new_object(void) { return (long long)jnode_new(JSON_OBJECT); }
long long nuc_json_new_array(void) { return (long long)jnode_new(JSON_ARRAY); }

void nuc_json_set_str(long long h, const char *key, const char *val) {
    JNode *obj = (JNode *)(void *)h;
    if (!obj || obj->type != JSON_OBJECT) return;
    JNode *v = jnode_new(JSON_STRING);
    v->str_val = (char *)malloc(strlen(val) + 1);
    strcpy(v->str_val, val);
    jnode_add_child(obj, key, v);
}

void nuc_json_set_int(long long h, const char *key, long long val) {
    JNode *obj = (JNode *)(void *)h;
    if (!obj || obj->type != JSON_OBJECT) return;
    JNode *v = jnode_new(JSON_INT);
    v->int_val = val;
    v->float_val = (double)val;
    jnode_add_child(obj, key, v);
}

void nuc_json_set_float(long long h, const char *key, long long val_bits) {
    JNode *obj = (JNode *)(void *)h;
    if (!obj || obj->type != JSON_OBJECT) return;
    JNode *v = jnode_new(JSON_FLOAT);
    v->float_val = _js_i2f(val_bits);
    jnode_add_child(obj, key, v);
}

void nuc_json_set_bool(long long h, const char *key, long long val) {
    JNode *obj = (JNode *)(void *)h;
    if (!obj || obj->type != JSON_OBJECT) return;
    JNode *v = jnode_new(JSON_BOOL);
    v->bool_val = val ? 1 : 0;
    jnode_add_child(obj, key, v);
}

void nuc_json_push(long long h, long long child_h) {
    JNode *arr = (JNode *)(void *)h;
    JNode *child = (JNode *)(void *)child_h;
    if (!arr || arr->type != JSON_ARRAY || !child) return;
    jnode_add_child(arr, NULL, child);
}

void nuc_json_push_int(long long h, long long val) {
    JNode *arr = (JNode *)(void *)h;
    if (!arr || arr->type != JSON_ARRAY) return;
    JNode *v = jnode_new(JSON_INT);
    v->int_val = val; v->float_val = (double)val;
    jnode_add_child(arr, NULL, v);
}

void nuc_json_push_float(long long h, long long val_bits) {
    JNode *arr = (JNode *)(void *)h;
    if (!arr || arr->type != JSON_ARRAY) return;
    JNode *v = jnode_new(JSON_FLOAT);
    v->float_val = _js_i2f(val_bits);
    jnode_add_child(arr, NULL, v);
}

void nuc_json_push_str(long long h, const char *val) {
    JNode *arr = (JNode *)(void *)h;
    if (!arr || arr->type != JSON_ARRAY) return;
    JNode *v = jnode_new(JSON_STRING);
    v->str_val = (char *)malloc(strlen(val) + 1);
    strcpy(v->str_val, val);
    jnode_add_child(arr, NULL, v);
}

// ================================================================
//  Serialization
// ================================================================

static void json_to_str_impl(JNode *n, char **buf, int *len, int *cap) {
    if (!n) return;
    #define JS_ENSURE(need) do { while (*len + (need) >= *cap) { *cap *= 2; *buf = (char*)realloc(*buf, *cap); } } while(0)
    #define JS_APPEND(s) do { int sl = (int)strlen(s); JS_ENSURE(sl+1); memcpy(*buf + *len, s, sl); *len += sl; } while(0)

    switch (n->type) {
        case JSON_NULL: JS_APPEND("null"); break;
        case JSON_BOOL: JS_APPEND(n->bool_val ? "true" : "false"); break;
        case JSON_INT: {
            char tmp[32]; snprintf(tmp, 32, "%lld", n->int_val);
            JS_APPEND(tmp);
            break;
        }
        case JSON_FLOAT: {
            char tmp[64]; snprintf(tmp, 64, "%.6f", n->float_val);
            JS_APPEND(tmp);
            break;
        }
        case JSON_STRING: {
            JS_ENSURE(2); (*buf)[(*len)++] = '"';
            if (n->str_val) {
                for (const char *s = n->str_val; *s; s++) {
                    JS_ENSURE(2);
                    if (*s == '"' || *s == '\\') (*buf)[(*len)++] = '\\';
                    if (*s == '\n') { JS_APPEND("\\n"); continue; }
                    if (*s == '\t') { JS_APPEND("\\t"); continue; }
                    (*buf)[(*len)++] = *s;
                }
            }
            JS_ENSURE(2); (*buf)[(*len)++] = '"';
            break;
        }
        case JSON_ARRAY: {
            JS_ENSURE(2); (*buf)[(*len)++] = '[';
            for (int i = 0; i < n->n_children; i++) {
                if (i > 0) { JS_ENSURE(2); (*buf)[(*len)++] = ','; }
                json_to_str_impl(n->children[i], buf, len, cap);
            }
            JS_ENSURE(2); (*buf)[(*len)++] = ']';
            break;
        }
        case JSON_OBJECT: {
            JS_ENSURE(2); (*buf)[(*len)++] = '{';
            for (int i = 0; i < n->n_children; i++) {
                if (i > 0) { JS_ENSURE(2); (*buf)[(*len)++] = ','; }
                JS_ENSURE(2); (*buf)[(*len)++] = '"';
                if (n->keys[i]) JS_APPEND(n->keys[i]);
                JS_ENSURE(3); (*buf)[(*len)++] = '"'; (*buf)[(*len)++] = ':';
                json_to_str_impl(n->children[i], buf, len, cap);
            }
            JS_ENSURE(2); (*buf)[(*len)++] = '}';
            break;
        }
    }
    #undef JS_ENSURE
    #undef JS_APPEND
}

const char *nuc_json_to_str(long long h) {
    JNode *n = (JNode *)(void *)h;
    if (!n) return "null";
    int cap = 4096, len = 0;
    char *buf = (char *)malloc(cap);
    json_to_str_impl(n, &buf, &len, &cap);
    buf[len] = 0;
    return buf;
}

// ================================================================
//  Cleanup
// ================================================================

void nuc_json_free(long long h) {
    JNode *n = (JNode *)(void *)h;
    if (!n) return;
    for (int i = 0; i < n->n_children; i++) {
        nuc_json_free((long long)n->children[i]);
        if (n->keys && n->keys[i]) free(n->keys[i]);
    }
    free(n->children);
    free(n->keys);
    free(n->str_val);
    free(n);
}
