/* qsim_graph_rt.c — RFC-0061 Tier 3 Phase A: process-local
 * union-find for entanglement tracking + gate-influence DAG. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

#define NUC_QSIM_MAX_QUBITS 1024
#define NUC_QSIM_MAX_GATES 4096

static atomic_flag _nuc_qsim_graph_lock_flag = ATOMIC_FLAG_INIT;

static void _nuc_qsim_graph_lock(void) {
    while (atomic_flag_test_and_set_explicit(&_nuc_qsim_graph_lock_flag, memory_order_acquire)) {
        /* spin: qsim_graph critical sections are tiny fixed-size table updates */
    }
}

static void _nuc_qsim_graph_unlock(void) {
    atomic_flag_clear_explicit(&_nuc_qsim_graph_lock_flag, memory_order_release);
}

/* ---- Union-find over qubits ---- */

static int _nuc_qsim_parent[NUC_QSIM_MAX_QUBITS];
static int _nuc_qsim_size[NUC_QSIM_MAX_QUBITS];
static int _nuc_qsim_active[NUC_QSIM_MAX_QUBITS];
static int _nuc_qsim_init_done = 0;

static void _nuc_qsim_init(void) {
    if (_nuc_qsim_init_done) return;
    for (int i = 0; i < NUC_QSIM_MAX_QUBITS; i++) {
        _nuc_qsim_parent[i] = i;
        _nuc_qsim_size[i] = 1;
        _nuc_qsim_active[i] = 0;
    }
    _nuc_qsim_init_done = 1;
}

static int _nuc_qsim_find(int q) {
    if (q < 0 || q >= NUC_QSIM_MAX_QUBITS) return -1;
    int r = q;
    while (_nuc_qsim_parent[r] != r) r = _nuc_qsim_parent[r];
    /* path compression */
    int x = q;
    while (_nuc_qsim_parent[x] != r) {
        int nx = _nuc_qsim_parent[x];
        _nuc_qsim_parent[x] = r;
        x = nx;
    }
    return r;
}

long long nuc_qsim_entangle_register(long long q1, long long q2) {
    long long ret = -1;
    _nuc_qsim_graph_lock();
    _nuc_qsim_init();
    if (q1 < 0 || q1 >= NUC_QSIM_MAX_QUBITS) goto done;
    if (q2 < 0 || q2 >= NUC_QSIM_MAX_QUBITS) goto done;
    _nuc_qsim_active[q1] = 1;
    _nuc_qsim_active[q2] = 1;
    int r1 = _nuc_qsim_find((int)q1);
    int r2 = _nuc_qsim_find((int)q2);
    if (r1 == r2) { ret = 0; goto done; }
    /* union by size */
    if (_nuc_qsim_size[r1] < _nuc_qsim_size[r2]) { int t = r1; r1 = r2; r2 = t; }
    _nuc_qsim_parent[r2] = r1;
    _nuc_qsim_size[r1] += _nuc_qsim_size[r2];
    ret = 1;
done:
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_entangle_root(long long q) {
    _nuc_qsim_graph_lock();
    _nuc_qsim_init();
    int r = _nuc_qsim_find((int)q);
    _nuc_qsim_graph_unlock();
    return (long long)r;
}

long long nuc_qsim_entangle_same(long long q1, long long q2) {
    long long ret = 0;
    _nuc_qsim_graph_lock();
    _nuc_qsim_init();
    int r1 = _nuc_qsim_find((int)q1);
    int r2 = _nuc_qsim_find((int)q2);
    if (r1 < 0 || r2 < 0) goto done;
    if (r1 != r2) goto done;
    /* Both qubits must be active (registered) for "same" to mean
     * "in the same entanglement component"; isolated qubits are
     * trivially their own root but are not entangled with anyone. */
    if (!_nuc_qsim_active[q1]) goto done;
    if (!_nuc_qsim_active[q2]) goto done;
    ret = 1;
done:
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_entangle_size(long long q) {
    long long ret = 0;
    _nuc_qsim_graph_lock();
    _nuc_qsim_init();
    int r = _nuc_qsim_find((int)q);
    if (r < 0) goto done;
    if (!_nuc_qsim_active[q]) goto done;
    ret = (long long)_nuc_qsim_size[r];
done:
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_entangle_count(void) {
    _nuc_qsim_graph_lock();
    _nuc_qsim_init();
    int count = 0;
    for (int i = 0; i < NUC_QSIM_MAX_QUBITS; i++) {
        if (_nuc_qsim_active[i] && _nuc_qsim_parent[i] == i) count++;
    }
    _nuc_qsim_graph_unlock();
    return (long long)count;
}

long long nuc_qsim_entangle_clear(void) {
    _nuc_qsim_graph_lock();
    for (int i = 0; i < NUC_QSIM_MAX_QUBITS; i++) {
        _nuc_qsim_parent[i] = i;
        _nuc_qsim_size[i] = 1;
        _nuc_qsim_active[i] = 0;
    }
    _nuc_qsim_init_done = 1;
    _nuc_qsim_graph_unlock();
    return 0;
}

/* ---- Gate-influence DAG ---- */

typedef struct {
    char *name;
    long long q1;
    long long q2;
    long long parent_a;   /* prior gate that touched q1 (or -1) */
    long long parent_b;   /* prior gate that touched q2 (or -1) */
    int in_use;
} NucQsimGate;

static NucQsimGate _nuc_qsim_gates[NUC_QSIM_MAX_GATES];
static int _nuc_qsim_gate_count = 0;
/* last-gate-on-qubit table: index by qubit id, value = gate id or -1 */
static long long _nuc_qsim_last_gate[NUC_QSIM_MAX_QUBITS];
static int _nuc_qsim_last_gate_init = 0;

static void _nuc_qsim_last_gate_initialize(void) {
    if (_nuc_qsim_last_gate_init) return;
    for (int i = 0; i < NUC_QSIM_MAX_QUBITS; i++) _nuc_qsim_last_gate[i] = -1;
    _nuc_qsim_last_gate_init = 1;
}

static char *_nuc_qsim_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

long long nuc_qsim_gate_record(long long name_p, long long q1, long long q2) {
    long long ret = -1;
    _nuc_qsim_graph_lock();
    _nuc_qsim_last_gate_initialize();
    if (_nuc_qsim_gate_count >= NUC_QSIM_MAX_GATES) goto done;
    if (q1 < -1 || q1 >= NUC_QSIM_MAX_QUBITS) goto done;
    if (q2 < -1 || q2 >= NUC_QSIM_MAX_QUBITS) goto done;
    NucQsimGate *g = &_nuc_qsim_gates[_nuc_qsim_gate_count];
    g->name = _nuc_qsim_strdup((const char *)name_p);
    g->q1 = q1;
    g->q2 = q2;
    g->parent_a = (q1 >= 0) ? _nuc_qsim_last_gate[q1] : -1;
    g->parent_b = (q2 >= 0) ? _nuc_qsim_last_gate[q2] : -1;
    g->in_use = 1;
    long long id = (long long)_nuc_qsim_gate_count;
    if (q1 >= 0) _nuc_qsim_last_gate[q1] = id;
    if (q2 >= 0) _nuc_qsim_last_gate[q2] = id;
    _nuc_qsim_gate_count++;
    ret = id;
done:
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_gate_count(void) {
    _nuc_qsim_graph_lock();
    long long ret = (long long)_nuc_qsim_gate_count;
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_gate_dag_parent_count(long long gate_id) {
    long long c = 0;
    _nuc_qsim_graph_lock();
    if (gate_id < 0 || gate_id >= _nuc_qsim_gate_count) goto done;
    NucQsimGate *g = &_nuc_qsim_gates[gate_id];
    if (g->parent_a >= 0) c++;
    if (g->parent_b >= 0 && g->parent_b != g->parent_a) c++;
done:
    _nuc_qsim_graph_unlock();
    return c;
}

long long nuc_qsim_gate_dag_parent_at(long long gate_id, long long idx) {
    long long ret = -1;
    _nuc_qsim_graph_lock();
    if (gate_id < 0 || gate_id >= _nuc_qsim_gate_count) goto done;
    NucQsimGate *g = &_nuc_qsim_gates[gate_id];
    if (idx == 0) {
        if (g->parent_a >= 0) { ret = g->parent_a; goto done; }
        ret = g->parent_b;
        goto done;
    }
    if (idx == 1) {
        if (g->parent_a >= 0 && g->parent_b >= 0 && g->parent_b != g->parent_a) ret = g->parent_b;
    }
done:
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_gate_dag_depends_on(long long child, long long parent) {
    long long ret = 0;
    _nuc_qsim_graph_lock();
    if (child < 0 || child >= _nuc_qsim_gate_count) goto done;
    if (parent < 0 || parent >= _nuc_qsim_gate_count) goto done;
    if (child <= parent) goto done;
    /* BFS from child through parent_a / parent_b. */
    long long stack[NUC_QSIM_MAX_GATES];
    int top = 0;
    stack[top++] = child;
    while (top > 0) {
        long long cur = stack[--top];
        if (cur == parent) { ret = 1; goto done; }
        if (cur < 0 || cur >= _nuc_qsim_gate_count) continue;
        NucQsimGate *g = &_nuc_qsim_gates[cur];
        if (g->parent_a >= 0 && top < NUC_QSIM_MAX_GATES) stack[top++] = g->parent_a;
        if (g->parent_b >= 0 && top < NUC_QSIM_MAX_GATES) stack[top++] = g->parent_b;
    }
done:
    _nuc_qsim_graph_unlock();
    return ret;
}

long long nuc_qsim_gate_clear(void) {
    _nuc_qsim_graph_lock();
    for (int i = 0; i < _nuc_qsim_gate_count; i++) {
        free(_nuc_qsim_gates[i].name);
        memset(&_nuc_qsim_gates[i], 0, sizeof(NucQsimGate));
    }
    _nuc_qsim_gate_count = 0;
    for (int i = 0; i < NUC_QSIM_MAX_QUBITS; i++) _nuc_qsim_last_gate[i] = -1;
    _nuc_qsim_last_gate_init = 1;
    _nuc_qsim_graph_unlock();
    return 0;
}
