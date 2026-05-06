// clifford_rt.c — Stabilizer Tableau Simulator for QEC Code Discovery
// Implements the Aaronson-Gottesman stabilizer formalism (CHP algorithm)
// for Clifford circuits on up to 20 qubits.
//
// Tableau layout: (2n) rows × (2n+1) columns of unsigned char (1 bit per byte)
//   Rows 0..n-1:     destabilizers
//   Rows n..2n-1:    stabilizers
//   Column 2j:       X bit for qubit j
//   Column 2j+1:     Z bit for qubit j
//   Column 2n:       phase bit (0 → +1, 1 → −1)
//
// Pauli encoding per qubit: (X=0,Z=0)→I, (X=1,Z=0)→X, (X=0,Z=1)→Z, (X=1,Z=1)→Y
//
// Compile: clang -c stdlib/runtime/clifford_rt.c -o target/clifford_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ---- FFI bitcast helpers ----
static double _mi2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _mf2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

// ---- Vec type (matches nucleor_llvm_rt.c, redeclared locally) ----
typedef struct { long long *data; int len; int cap; } NVec;

static NVec *nvec_new(void) {
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->data = (long long *)malloc(16 * sizeof(long long));
    v->len = 0;
    v->cap = 16;
    return v;
}

static void nvec_push(NVec *v, long long x) {
    if (!v) return;
    if (v->len >= v->cap) {
        v->cap *= 2;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
    }
    v->data[v->len++] = x;
}

static long long nvec_get(NVec *v, long long i) {
    if (!v || i < 0 || i >= v->len) return 0;
    return v->data[(int)i];
}

static int nvec_len(NVec *v) {
    if (!v) return 0;
    return v->len;
}

// ---- Constants ----
#define CLIFF_MAX_QUBITS 20
#define CLIFF_WEIGHT_ENUM_MAX_QUBITS 12

// ---- Stabilizer Tableau ----
typedef struct {
    int nq;                    // number of qubits
    // tableau: 2n rows × (2n+1) cols, stored row-major
    // tab[r][c] where r in [0, 2n), c in [0, 2n+1)
    // We allocate flat: tab[r * (2*nq+1) + c]
    unsigned char *tab;
    // Simple LCG state for measurement randomness
    unsigned long long rng;
} CliffordTableau;

// Tableau dimensions
static int tab_cols(CliffordTableau *t) { return 2 * t->nq + 1; }
static int tab_rows(CliffordTableau *t) { return 2 * t->nq; }

// Access helpers — X bit, Z bit, phase bit for row r, qubit q
static unsigned char *tab_xp(CliffordTableau *t, int r, int q) {
    return &t->tab[r * tab_cols(t) + 2 * q];
}
static unsigned char *tab_zp(CliffordTableau *t, int r, int q) {
    return &t->tab[r * tab_cols(t) + 2 * q + 1];
}
static unsigned char *tab_pp(CliffordTableau *t, int r) {
    return &t->tab[r * tab_cols(t) + 2 * t->nq];
}

#define TAB_X(t, r, q)  (*tab_xp((t), (r), (q)))
#define TAB_Z(t, r, q)  (*tab_zp((t), (r), (q)))
#define TAB_P(t, r)     (*tab_pp((t), (r)))

// ---- LCG random (xorshift64) ----
static unsigned long long cliff_rand(CliffordTableau *t) {
    unsigned long long x = t->rng;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    t->rng = x;
    return x;
}

// ---- Compute the phase product of two Pauli rows ----
// When multiplying two n-qubit Paulis P_a * P_b, the phase factor depends on
// the per-qubit Pauli products. This function computes the total phase exponent (mod 4)
// from the rowproduct rule in Aaronson-Gottesman.
// Returns the combined phase bit (0 or 1) for the product P_a * P_b.
static int rowmult_phase(CliffordTableau *t, int ra, int rb) {
    // Sum up phase contributions from each qubit.
    // For qubit q, the pair (xa,za) and (xb,zb) contribute a phase factor:
    //   I*P = P → 0
    //   X*X = I → 0, X*Z = iY → +1, X*Y = -iZ → -1
    //   Y*X = -iZ → -1, Y*Y = I → 0, Y*Z = iX → +1
    //   Z*X = -iY → -1, Z*Y = iX → +1, Z*Z = I → 0
    // We accumulate in units of i (so mod 4).
    int phase = 0;
    if (TAB_P(t, ra)) phase += 2;
    if (TAB_P(t, rb)) phase += 2;

    for (int q = 0; q < t->nq; q++) {
        int xa = TAB_X(t, ra, q), za = TAB_Z(t, ra, q);
        int xb = TAB_X(t, rb, q), zb = TAB_Z(t, rb, q);
        // Pauli type: 0=I, 1=X, 2=Z, 3=Y (using xa + 2*za encoding)
        int pa = xa + 2 * za;
        int pb = xb + 2 * zb;
        if (pa == 0 || pb == 0) continue; // I commutes trivially
        if (pa == pb) continue;            // same Pauli: phase contribution 0
        // Different non-identity Paulis: determine sign of i
        // X*Z → +i → +1, Z*X → -i → -1
        // X*Y → -i → -1, Y*X → +i → not actually, let's use the lookup
        // Exact lookup table for phase(pa, pb):
        //   (X=1, Z=2): X*Z = iY → +1
        //   (X=1, Y=3): X*Y = -iZ → -1
        //   (Z=2, X=1): Z*X = -iY → -1
        //   (Z=2, Y=3): Z*Y = iX → +1
        //   (Y=3, X=1): Y*X = iZ → +1  ... wait, Y*X = (iXZ)(X) = i X Z X = i(-X X Z) = -iZ → phase -1
        // Let me just use the standard formula:
        // phase += (pa == 1 && pb == 2) ? 1 : (pa == 2 && pb == 1) ? -1 :
        //          (pa == 1 && pb == 3) ? -1 : (pa == 3 && pb == 1) ? 1 :
        //          (pa == 2 && pb == 3) ? 1 : (pa == 3 && pb == 2) ? -1 : 0;
        // Cleaner: use the Levi-Civita-like rule for Pauli products
        // For distinct non-identity Paulis a,b: a*b = ±i*c where sign is +1 if (a,b,c) is cyclic (X,Y,Z)
        // Cyclic order: X(1) → Y(3) → Z(2) → X(1)
        // (1→3): +1, (3→2): +1, (2→1): +1
        // (1→2): -1, (2→3): -1, (3→1): -1
        if ((pa == 1 && pb == 3) || (pa == 3 && pb == 2) || (pa == 2 && pb == 1)) {
            phase += 1;
        } else {
            phase -= 1;
        }
    }
    // Reduce mod 4 and return 0 or 1
    phase = ((phase % 4) + 4) % 4;
    return (phase >= 2) ? 1 : 0;
}

// Multiply row rb into row ra: P_ra = P_ra * P_rb
// Updates the Pauli bits and phase of row ra.
static void rowmult(CliffordTableau *t, int ra, int rb) {
    int new_phase = rowmult_phase(t, ra, rb);
    TAB_P(t, ra) = (unsigned char)new_phase;
    for (int q = 0; q < t->nq; q++) {
        TAB_X(t, ra, q) ^= TAB_X(t, rb, q);
        TAB_Z(t, ra, q) ^= TAB_Z(t, rb, q);
    }
}

// ---- Tableau allocation ----
static CliffordTableau *cliff_alloc(int nq) {
    CliffordTableau *t = (CliffordTableau *)calloc(1, sizeof(CliffordTableau));
    t->nq = nq;
    int total = (2 * nq) * (2 * nq + 1);
    t->tab = (unsigned char *)calloc(total, 1);
    // Seed RNG with a nonzero value (address-derived for variety)
    t->rng = (unsigned long long)(size_t)t ^ 0xDEADBEEF12345678ULL;
    if (t->rng == 0) t->rng = 1;
    return t;
}

// Initialize to |00...0> state:
//   Destabilizer i: X_i   (row i, column 2i = 1)
//   Stabilizer i:   Z_i   (row n+i, column 2i+1 = 1)
//   All phases = 0
static void cliff_init_state(CliffordTableau *t) {
    int n = t->nq;
    int total = (2 * n) * (2 * n + 1);
    memset(t->tab, 0, total);
    for (int i = 0; i < n; i++) {
        TAB_X(t, i, i) = 1;           // destabilizer row i: X_i
        TAB_Z(t, n + i, i) = 1;       // stabilizer row n+i: Z_i
    }
}

// ===========================================================================
//  PUBLIC API — Tableau Management
// ===========================================================================

// Create n-qubit stabilizer state initialized to |00...0>
long long nuc_cliff_init(long long n_qubits) {
    int nq = (int)n_qubits;
    if (nq < 1) nq = 1;
    if (nq > CLIFF_MAX_QUBITS) nq = CLIFF_MAX_QUBITS;
    CliffordTableau *t = cliff_alloc(nq);
    cliff_init_state(t);
    return (long long)(size_t)t;
}

// Create n-qubit BLANK tableau for QEC code construction.
// All stabilizer and destabilizer rows are zero (no generators).
// Use add_stabilizer to build the code's stabilizer group incrementally.
// Clifford gates on an empty tableau are no-ops (all bits zero → unchanged).
long long nuc_cliff_init_code(long long n_qubits) {
    int nq = (int)n_qubits;
    if (nq < 1) nq = 1;
    if (nq > CLIFF_MAX_QUBITS) nq = CLIFF_MAX_QUBITS;
    CliffordTableau *t = cliff_alloc(nq);
    // cliff_alloc uses calloc → all bits already zero. No cliff_init_state call.
    return (long long)(size_t)t;
}

// Free tableau
void nuc_cliff_free(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    free(t->tab);
    free(t);
}

// Clone a tableau
long long nuc_cliff_clone(long long handle) {
    CliffordTableau *src = (CliffordTableau *)(size_t)handle;
    if (!src) return 0;
    CliffordTableau *dst = cliff_alloc(src->nq);
    int total = (2 * src->nq) * (2 * src->nq + 1);
    memcpy(dst->tab, src->tab, total);
    dst->rng = src->rng ^ 0x9E3779B97F4A7C15ULL; // vary the RNG for the clone
    return (long long)(size_t)dst;
}

// Get number of qubits
long long nuc_cliff_nq(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    return (long long)t->nq;
}

// ===========================================================================
//  PUBLIC API — Clifford Gates
// ===========================================================================
// All gate updates follow the Aaronson-Gottesman rules, applied to every row
// of the tableau (destabilizers + stabilizers).

// Hadamard on qubit q: swaps X_q ↔ Z_q for each row, flips phase if both were 1 (Y → −Y)
void nuc_cliff_h(long long handle, long long q_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    int q = (int)q_;
    if (q < 0 || q >= t->nq) return;
    int nrows = tab_rows(t);
    for (int r = 0; r < nrows; r++) {
        unsigned char x = TAB_X(t, r, q);
        unsigned char z = TAB_Z(t, r, q);
        // If both X and Z are set (Y), Hadamard gives −Y, so flip phase
        if (x && z) {
            TAB_P(t, r) ^= 1;
        }
        // Swap X ↔ Z
        TAB_X(t, r, q) = z;
        TAB_Z(t, r, q) = x;
    }
}

// Phase gate S on qubit q: X → Y (= iXZ), Z → Z
// For each row: if X_q=1, flip Z_q. Phase: r += x_q * z_q (before the flip)
// Actually the standard rule: S maps X→Y, Z→Z, Y→−X
// Tableau update for each row r:
//   phase ^= (X_q AND Z_q)   [because Y picks up a sign under S: S*Y*Sdg = -X]
//   Z_q ^= X_q               [X→XZ=iY means new Z_q = old Z_q XOR old X_q]
void nuc_cliff_s(long long handle, long long q_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    int q = (int)q_;
    if (q < 0 || q >= t->nq) return;
    int nrows = tab_rows(t);
    for (int r = 0; r < nrows; r++) {
        unsigned char x = TAB_X(t, r, q);
        unsigned char z = TAB_Z(t, r, q);
        TAB_P(t, r) ^= (x & z);
        TAB_Z(t, r, q) = z ^ x;
    }
}

// CNOT with control c, target t:
//   X_c → X_c X_t   (X on control propagates to target)
//   Z_t → Z_c Z_t   (Z on target propagates to control)
// Tableau update for each row r:
//   phase ^= x_c * z_t * (x_t XOR z_c XOR 1)  [from the commutation relation]
//   x_t ^= x_c
//   z_c ^= z_t
void nuc_cliff_cnot(long long handle, long long ctrl_, long long tgt_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    int c = (int)ctrl_, tg = (int)tgt_;
    if (c < 0 || c >= t->nq || tg < 0 || tg >= t->nq || c == tg) return;
    int nrows = tab_rows(t);
    for (int r = 0; r < nrows; r++) {
        unsigned char xc = TAB_X(t, r, c);
        unsigned char zc = TAB_Z(t, r, c);
        unsigned char xt = TAB_X(t, r, tg);
        unsigned char zt = TAB_Z(t, r, tg);
        // Phase update: phase ^= x_c * z_t * (x_t XOR z_c XOR 1)
        TAB_P(t, r) ^= (xc & zt & (xt ^ zc ^ 1));
        // Bit updates
        TAB_X(t, r, tg) = xt ^ xc;
        TAB_Z(t, r, c)  = zc ^ zt;
    }
}

// Pauli X on qubit q: X commutes, Z anticommutes
// For each row r: if Z_q = 1, flip phase (since X*Z = −Z*X)
void nuc_cliff_x(long long handle, long long q_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    int q = (int)q_;
    if (q < 0 || q >= t->nq) return;
    int nrows = tab_rows(t);
    for (int r = 0; r < nrows; r++) {
        if (TAB_Z(t, r, q)) TAB_P(t, r) ^= 1;
    }
}

// Pauli Z on qubit q: Z commutes, X anticommutes
// For each row r: if X_q = 1, flip phase
void nuc_cliff_z(long long handle, long long q_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    int q = (int)q_;
    if (q < 0 || q >= t->nq) return;
    int nrows = tab_rows(t);
    for (int r = 0; r < nrows; r++) {
        if (TAB_X(t, r, q)) TAB_P(t, r) ^= 1;
    }
}

// Pauli Y on qubit q: Y = iXZ, anticommutes with both X and Z
// For each row r: if X_q XOR Z_q = 1 (i.e., the row has X or Z but not both/neither on q), flip phase
void nuc_cliff_y(long long handle, long long q_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    int q = (int)q_;
    if (q < 0 || q >= t->nq) return;
    int nrows = tab_rows(t);
    for (int r = 0; r < nrows; r++) {
        // Y anticommutes with X and Z, commutes with Y and I
        // Anticommutation: (X_q=1,Z_q=0) or (X_q=0,Z_q=1), i.e. X_q XOR Z_q = 1
        if (TAB_X(t, r, q) ^ TAB_Z(t, r, q)) TAB_P(t, r) ^= 1;
    }
}

// ===========================================================================
//  PUBLIC API — Measurement
// ===========================================================================
// Measure qubit q in the computational basis (Z basis).
// Uses the Aaronson-Gottesman measurement algorithm:
//   1. Find if any stabilizer (row n+i) has X_q = 1 (non-deterministic case)
//   2. If yes: outcome is random ±1; update tableau to reflect measurement
//   3. If no: outcome is deterministic; compute from destabilizer/stabilizer product

long long nuc_cliff_measure(long long handle, long long q_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int q = (int)q_;
    if (q < 0 || q >= t->nq) return 0;
    int n = t->nq;

    // Step 1: Find a stabilizer row p (in range [n, 2n)) with X_q = 1
    int p = -1;
    for (int i = n; i < 2 * n; i++) {
        if (TAB_X(t, i, q)) { p = i; break; }
    }

    if (p >= 0) {
        // NON-DETERMINISTIC case: outcome is random
        // For all rows r != p where X_q = 1, multiply row p into row r
        // (to clear X_q in those rows while maintaining the group)
        for (int r = 0; r < 2 * n; r++) {
            if (r != p && TAB_X(t, r, q)) {
                rowmult(t, r, p);
            }
        }
        // Copy row p to its destabilizer partner (row p-n)
        int cols = tab_cols(t);
        memcpy(&t->tab[(p - n) * cols], &t->tab[p * cols], cols);

        // Set row p to be Z_q with random phase (the post-measurement stabilizer)
        memset(&t->tab[p * cols], 0, cols);
        TAB_Z(t, p, q) = 1;
        int outcome = (int)(cliff_rand(t) & 1);
        TAB_P(t, p) = (unsigned char)outcome;
        return (long long)outcome;
    } else {
        // DETERMINISTIC case: no stabilizer has X_q set
        // The outcome is determined by the destabilizers.
        // Create a temporary "scratch" row to accumulate the product.
        // We need to find which destabilizer rows i (0..n-1) have X_q = 1,
        // and multiply the corresponding stabilizer rows (n+i) together.
        int n2 = 2 * n;
        int cols = tab_cols(t);

        // We'll track the result in a temporary row. Start with identity (+I).
        unsigned char *scratch = (unsigned char *)calloc(cols, 1);

        // For each destabilizer row i with X_q = 1, XOR the stabilizer row (n+i) into scratch
        // and accumulate the phase correctly.
        // Actually for deterministic measurement the simpler approach:
        // compute the product of stabilizer rows n+i for all destabilizer rows i with X_q=1.
        // The phase of that product is the measurement outcome.

        // We use a direct accumulation with phase tracking:
        int result_phase = 0;
        // scratch_pauli stores the accumulated Pauli string
        unsigned char *scratch_x = (unsigned char *)calloc(n, 1);
        unsigned char *scratch_z = (unsigned char *)calloc(n, 1);

        for (int i = 0; i < n; i++) {
            if (!TAB_X(t, i, q)) continue;
            // Multiply stabilizer row n+i into scratch
            // Phase from product: use the standard rowmult phase calculation
            int phase_contrib = 0;
            if (result_phase) phase_contrib += 2;
            if (TAB_P(t, n + i)) phase_contrib += 2;
            for (int j = 0; j < n; j++) {
                int sa = scratch_x[j] + 2 * scratch_z[j];
                int sb = TAB_X(t, n + i, j) + 2 * TAB_Z(t, n + i, j);
                if (sa != 0 && sb != 0 && sa != sb) {
                    if ((sa == 1 && sb == 3) || (sa == 3 && sb == 2) || (sa == 2 && sb == 1))
                        phase_contrib += 1;
                    else
                        phase_contrib -= 1;
                }
            }
            phase_contrib = ((phase_contrib % 4) + 4) % 4;
            result_phase = (phase_contrib >= 2) ? 1 : 0;

            for (int j = 0; j < n; j++) {
                scratch_x[j] ^= TAB_X(t, n + i, j);
                scratch_z[j] ^= TAB_Z(t, n + i, j);
            }
        }

        free(scratch);
        free(scratch_x);
        free(scratch_z);
        return (long long)result_phase;
    }
}

// ===========================================================================
//  PUBLIC API — QEC Code Properties
// ===========================================================================

// Check if a Pauli error E anticommutes with at least one stabilizer.
// E is a Vec of 2n bits: [x0, z0, x1, z1, ..., x_{n-1}, z_{n-1}]
// Returns 1 if detectable (anticommutes with some stabilizer), 0 otherwise.
long long nuc_cliff_error_detectable(long long handle, long long error_vec_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    NVec *ev = (NVec *)(size_t)error_vec_;
    if (!t || !ev) return 0;
    int n = t->nq;
    if (nvec_len(ev) < 2 * n) return 0;

    // For each stabilizer row (n..2n-1), check if E anticommutes with it.
    // Two Paulis anticommute iff the symplectic inner product is 1:
    //   sum_q (ex_q * sz_q + ez_q * sx_q) mod 2 == 1
    for (int s = n; s < 2 * n; s++) {
        int inner = 0;
        for (int q = 0; q < n; q++) {
            int ex = (int)nvec_get(ev, 2 * q);
            int ez = (int)nvec_get(ev, 2 * q + 1);
            int sx = TAB_X(t, s, q);
            int sz = TAB_Z(t, s, q);
            inner ^= ((ex & sz) ^ (ez & sx));
        }
        if (inner) return 1; // anticommutes → detectable
    }
    return 0; // commutes with all stabilizers → undetectable
}

// Get number of stabilizer generators currently defined.
// A stabilizer row is "active" if it has any nonzero Pauli bits.
long long nuc_cliff_num_stabilizers(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int count = 0;
    for (int s = n; s < 2 * n; s++) {
        int nonzero = 0;
        for (int q = 0; q < n; q++) {
            if (TAB_X(t, s, q) || TAB_Z(t, s, q)) { nonzero = 1; break; }
        }
        if (nonzero) count++;
    }
    return (long long)count;
}

// Check if a Pauli string (as 2n-bit Vec) is in the stabilizer group.
// Uses Gaussian elimination on the stabilizer generators.
// Returns 1 if the Pauli is in the group, 0 if not.
// work_x, work_z, work_p are scratch arrays of size n (for the stabilizers + target).
static int pauli_in_stabilizer_group(CliffordTableau *t, int *ex, int *ez) {
    int n = t->nq;
    // Copy stabilizer generators into a work matrix for Gaussian elimination
    // We have up to n generators. Represent as rows of 2n bits + phase.
    int num_gen = 0;
    // gen[i][2*q] = X bit, gen[i][2*q+1] = Z bit
    unsigned char gen[CLIFF_MAX_QUBITS][2 * CLIFF_MAX_QUBITS + 1];
    memset(gen, 0, sizeof(gen));

    for (int s = n; s < 2 * n; s++) {
        int nonzero = 0;
        for (int q = 0; q < n; q++) {
            if (TAB_X(t, s, q) || TAB_Z(t, s, q)) nonzero = 1;
            gen[num_gen][2 * q]     = TAB_X(t, s, q);
            gen[num_gen][2 * q + 1] = TAB_Z(t, s, q);
        }
        gen[num_gen][2 * n] = TAB_P(t, s);
        if (nonzero) num_gen++;
    }

    // Target Pauli to reduce
    unsigned char target[2 * CLIFF_MAX_QUBITS + 1];
    memset(target, 0, sizeof(target));
    for (int q = 0; q < n; q++) {
        target[2 * q]     = (unsigned char)(ex[q] & 1);
        target[2 * q + 1] = (unsigned char)(ez[q] & 1);
    }
    target[2 * n] = 0; // assume + phase for now

    // Gaussian elimination over GF(2): try to reduce target to zero using generators
    int cols = 2 * n;
    int pivot_col[CLIFF_MAX_QUBITS]; // which column each generator pivots on
    memset(pivot_col, -1, sizeof(pivot_col));

    // Row echelon form on generators
    int cur_row = 0;
    for (int c = 0; c < cols && cur_row < num_gen; c++) {
        // Find a generator with bit c set
        int found = -1;
        for (int r = cur_row; r < num_gen; r++) {
            if (gen[r][c]) { found = r; break; }
        }
        if (found < 0) continue;
        // Swap to cur_row
        if (found != cur_row) {
            unsigned char tmp[2 * CLIFF_MAX_QUBITS + 1];
            memcpy(tmp, gen[cur_row], cols + 1);
            memcpy(gen[cur_row], gen[found], cols + 1);
            memcpy(gen[found], tmp, cols + 1);
        }
        pivot_col[cur_row] = c;
        // Eliminate this column from all other rows
        for (int r = 0; r < num_gen; r++) {
            if (r == cur_row) continue;
            if (gen[r][c]) {
                for (int j = 0; j <= cols; j++) gen[r][j] ^= gen[cur_row][j];
            }
        }
        cur_row++;
    }
    int rank = cur_row;

    // Now reduce target using the pivot rows
    for (int r = 0; r < rank; r++) {
        int c = pivot_col[r];
        if (c >= 0 && target[c]) {
            for (int j = 0; j <= cols; j++) target[j] ^= gen[r][j];
        }
    }

    // Check if target is now all zeros (ignoring phase)
    for (int c = 0; c < cols; c++) {
        if (target[c]) return 0; // not in the group
    }
    return 1; // in the group (possibly up to phase)
}

// Compute the Pauli weight (number of non-identity qubit positions)
static int pauli_weight(int n, int *ex, int *ez) {
    int w = 0;
    for (int q = 0; q < n; q++) {
        if (ex[q] || ez[q]) w++;
    }
    return w;
}

// Check if a Pauli given by (ex, ez) arrays commutes with ALL stabilizers
static int commutes_with_all_stabilizers(CliffordTableau *t, int *ex, int *ez) {
    int n = t->nq;
    for (int s = n; s < 2 * n; s++) {
        int inner = 0;
        for (int q = 0; q < n; q++) {
            int sx = TAB_X(t, s, q);
            int sz = TAB_Z(t, s, q);
            inner ^= ((ex[q] & sz) ^ (ez[q] & sx));
        }
        if (inner) return 0; // anticommutes
    }
    return 1;
}

// The exhaustive weight-enumerator helpers are intentionally bounded. They are
// for small-code validation fixtures and release evidence, not large-code search.
long long nuc_cliff_weight_enumerator_max_qubits(void) {
    return (long long)CLIFF_WEIGHT_ENUM_MAX_QUBITS;
}

static int collect_stabilizer_rows(CliffordTableau *t,
                                   unsigned char gen[CLIFF_MAX_QUBITS][2 * CLIFF_MAX_QUBITS]) {
    int n = t->nq;
    int num_gen = 0;
    memset(gen, 0, CLIFF_MAX_QUBITS * 2 * CLIFF_MAX_QUBITS);

    for (int s = n; s < 2 * n; s++) {
        int nonzero = 0;
        for (int q = 0; q < n; q++) {
            unsigned char x = TAB_X(t, s, q);
            unsigned char z = TAB_Z(t, s, q);
            if (x || z) nonzero = 1;
            gen[num_gen][2 * q] = x;
            gen[num_gen][2 * q + 1] = z;
        }
        if (nonzero) {
            num_gen++;
            if (num_gen >= CLIFF_MAX_QUBITS) break;
        }
    }

    return num_gen;
}

long long nuc_cliff_stabilizer_weight_count(long long handle, long long weight_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int target_weight = (int)weight_;
    if (target_weight < 0 || target_weight > n) return 0;
    if (n > CLIFF_WEIGHT_ENUM_MAX_QUBITS) return -1;

    unsigned char gen[CLIFF_MAX_QUBITS][2 * CLIFF_MAX_QUBITS];
    int num_gen = collect_stabilizer_rows(t, gen);
    if (num_gen >= 62) return -1;

    long long count = 0;
    long long total = 1LL << num_gen;
    int ex[CLIFF_MAX_QUBITS], ez[CLIFF_MAX_QUBITS];

    for (long long mask = 0; mask < total; mask++) {
        memset(ex, 0, n * sizeof(int));
        memset(ez, 0, n * sizeof(int));

        for (int g = 0; g < num_gen; g++) {
            if (((mask >> g) & 1LL) == 0) continue;
            for (int q = 0; q < n; q++) {
                ex[q] ^= gen[g][2 * q];
                ez[q] ^= gen[g][2 * q + 1];
            }
        }

        if (pauli_weight(n, ex, ez) == target_weight) count++;
    }

    return count;
}

long long nuc_cliff_logical_weight_count(long long handle, long long n_logical_, long long weight_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int n_logical = (int)n_logical_;
    int target_weight = (int)weight_;
    if (n_logical <= 0) return 0;
    if (target_weight < 0 || target_weight > n) return 0;
    if (n > CLIFF_WEIGHT_ENUM_MAX_QUBITS) return -1;

    int ex[CLIFF_MAX_QUBITS], ez[CLIFF_MAX_QUBITS];
    long long count = 0;

    if (target_weight == 0) return 0;

    int positions[CLIFF_MAX_QUBITS];
    for (int i = 0; i < target_weight; i++) positions[i] = i;

    while (1) {
        int assignments = 1;
        for (int i = 0; i < target_weight; i++) assignments *= 3;

        for (int mask = 0; mask < assignments; mask++) {
            memset(ex, 0, n * sizeof(int));
            memset(ez, 0, n * sizeof(int));
            int tmp = mask;
            for (int i = 0; i < target_weight; i++) {
                int pauli_type = (tmp % 3) + 1;
                tmp /= 3;
                int q = positions[i];
                if (pauli_type == 1) {
                    ex[q] = 1;
                } else if (pauli_type == 2) {
                    ez[q] = 1;
                } else {
                    ex[q] = 1;
                    ez[q] = 1;
                }
            }

            if (commutes_with_all_stabilizers(t, ex, ez) &&
                !pauli_in_stabilizer_group(t, ex, ez)) {
                count++;
            }
        }

        int i = target_weight - 1;
        while (i >= 0 && positions[i] == n - target_weight + i) i--;
        if (i < 0) break;
        positions[i]++;
        for (int j = i + 1; j < target_weight; j++) positions[j] = positions[j - 1] + 1;
    }

    return count;
}

// Compute code distance: minimum weight of a non-trivial logical operator.
// A logical operator commutes with all stabilizers but is NOT in the stabilizer group.
// For n_qubits <= 15, we enumerate by increasing weight.
//
// n_logical = number of logical qubits = n_physical - num_stabilizers
// If n_logical <= 0, there are no logical operators → distance is undefined → return 0.
long long nuc_cliff_distance(long long handle, long long n_logical_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int n_logical = (int)n_logical_;
    if (n_logical <= 0) return 0;
    if (n > 20) {
        // Too expensive to brute force for n>20. Return 0 to indicate unknown.
        return 0;
    }

    int ex[CLIFF_MAX_QUBITS], ez[CLIFF_MAX_QUBITS];

    // Enumerate all Pauli strings by weight, from 1 to n.
    // For each weight w, iterate over all combinations of w qubit positions,
    // and all 3^w Pauli assignments (X, Z, or Y on each active qubit).
    // Total for weight w: C(n,w) * 3^w.

    // Helper: iterate over all weight-w subsets using Gosper's hack
    for (int w = 1; w <= n; w++) {
        // If 3^w * C(n,w) is too large (>10M), skip (safety valve)
        // For n=15, w=5: C(15,5)*3^5 = 3003*243 = ~730K, still manageable
        // For n=15, w=8: C(15,8)*3^8 = 6435*6561 = ~42M, getting large but doable
        // We'll set a limit at w=10 for n=15 (C(15,10)*3^10 = 3003*59049 = ~177M — too much)
        // In practice, most interesting codes have distance <= 7 for n <= 15.
        double est = 1.0;
        {
            // Estimate C(n,w) * 3^w
            double cnw = 1.0;
            for (int i = 0; i < w; i++) cnw = cnw * (n - i) / (i + 1);
            for (int i = 0; i < w; i++) est *= 3.0;
            est *= cnw;
        }
        if (est > 50000000.0) return 0; // too expensive, bail

        // Iterate over all w-element subsets of {0, ..., n-1}
        // Use recursive approach for clarity with small n
        int positions[CLIFF_MAX_QUBITS];

        // Initialize first subset: {0, 1, ..., w-1}
        for (int i = 0; i < w; i++) positions[i] = i;

        while (1) {
            // For this subset of qubit positions, try all 3^w Pauli assignments
            // Pauli types: 1=X, 2=Z, 3=Y (skip 0=I since that's not active)
            int pw = 1;
            for (int i = 0; i < w; i++) pw *= 3;

            for (int mask = 0; mask < pw; mask++) {
                memset(ex, 0, n * sizeof(int));
                memset(ez, 0, n * sizeof(int));
                int tmp = mask;
                for (int i = 0; i < w; i++) {
                    int pauli_type = (tmp % 3) + 1; // 1=X, 2=Z, 3=Y
                    tmp /= 3;
                    int q = positions[i];
                    if (pauli_type == 1)      { ex[q] = 1; ez[q] = 0; } // X
                    else if (pauli_type == 2) { ex[q] = 0; ez[q] = 1; } // Z
                    else                      { ex[q] = 1; ez[q] = 1; } // Y
                }

                // Check: commutes with all stabilizers AND is NOT in the stabilizer group
                if (commutes_with_all_stabilizers(t, ex, ez)) {
                    if (!pauli_in_stabilizer_group(t, ex, ez)) {
                        return (long long)w; // found a logical op of weight w
                    }
                }
            }

            // Advance to next w-subset (lexicographic order)
            int i = w - 1;
            while (i >= 0 && positions[i] == n - w + i) i--;
            if (i < 0) break; // exhausted all subsets
            positions[i]++;
            for (int j = i + 1; j < w; j++) positions[j] = positions[j - 1] + 1;
        }
    }

    // If no non-trivial logical operator found at any weight, the code encodes 0 logical qubits
    // (all normalizer elements are in the stabilizer group). Shouldn't happen if n_logical > 0.
    return 0;
}

// Add a stabilizer generator (Pauli string as Vec of 2n bits).
// Finds the first unused stabilizer row and sets it.
// Returns 1 if added (independent), 0 if dependent on existing stabilizers.
long long nuc_cliff_add_stabilizer(long long handle, long long pauli_vec_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    NVec *pv = (NVec *)(size_t)pauli_vec_;
    if (!t || !pv) return 0;
    int n = t->nq;
    if (nvec_len(pv) < 2 * n) return 0;

    // Extract the Pauli into arrays
    int ex[CLIFF_MAX_QUBITS], ez[CLIFF_MAX_QUBITS];
    for (int q = 0; q < n; q++) {
        ex[q] = (int)(nvec_get(pv, 2 * q) & 1);
        ez[q] = (int)(nvec_get(pv, 2 * q + 1) & 1);
    }

    // Check if it's in the existing stabilizer group (dependent)
    if (pauli_in_stabilizer_group(t, ex, ez)) return 0;

    // Also must commute with all existing stabilizers (otherwise can't be added as a stabilizer)
    if (!commutes_with_all_stabilizers(t, ex, ez)) return 0;

    // Find an empty stabilizer row (one with all-zero Pauli bits)
    int target_row = -1;
    for (int s = n; s < 2 * n; s++) {
        int empty = 1;
        for (int q = 0; q < n; q++) {
            if (TAB_X(t, s, q) || TAB_Z(t, s, q)) { empty = 0; break; }
        }
        if (empty) { target_row = s; break; }
    }

    if (target_row < 0) {
        // No empty row. All n stabilizer slots are full.
        // The code already has n generators. Can't add more independent ones.
        return 0;
    }

    // Write the new stabilizer into the target row
    int cols = tab_cols(t);
    memset(&t->tab[target_row * cols], 0, cols);
    for (int q = 0; q < n; q++) {
        TAB_X(t, target_row, q) = (unsigned char)ex[q];
        TAB_Z(t, target_row, q) = (unsigned char)ez[q];
    }
    // Phase = 0 (+1) by default. The Vec could optionally have a phase bit
    // at position 2n, but per the spec the Vec is exactly 2n bits.
    if (nvec_len(pv) > 2 * n) {
        TAB_P(t, target_row) = (unsigned char)(nvec_get(pv, 2 * n) & 1);
    }

    // Also need to set the corresponding destabilizer row to maintain the tableau invariant.
    // The destabilizer for this new stabilizer should anticommute with it and commute with
    // all other stabilizers. For simplicity, find a single-qubit Pauli that anticommutes.
    int dest_row = target_row - n;
    memset(&t->tab[dest_row * cols], 0, cols);
    for (int q = 0; q < n; q++) {
        // Try X_q as destabilizer (anticommutes with Z_q or Y_q parts of the stabilizer)
        if (ez[q]) { // stabilizer has Z or Y on qubit q → X_q anticommutes
            TAB_X(t, dest_row, q) = 1;
            // Verify it anticommutes with the new stabilizer
            // and commutes with all other stabilizers
            int ok = 1;
            int inner_new = 0;
            for (int j = 0; j < n; j++) {
                inner_new ^= ((TAB_X(t, dest_row, j) & ez[j]) ^
                              (TAB_Z(t, dest_row, j) & ex[j]));
            }
            if (!inner_new) { TAB_X(t, dest_row, q) = 0; continue; }
            // Check commutation with other stabilizers
            for (int s = n; s < 2 * n; s++) {
                if (s == target_row) continue;
                int has_bits = 0;
                for (int j = 0; j < n; j++) {
                    if (TAB_X(t, s, j) || TAB_Z(t, s, j)) { has_bits = 1; break; }
                }
                if (!has_bits) continue;
                int inner = 0;
                for (int j = 0; j < n; j++) {
                    inner ^= ((TAB_X(t, dest_row, j) & TAB_Z(t, s, j)) ^
                              (TAB_Z(t, dest_row, j) & TAB_X(t, s, j)));
                }
                if (inner) { ok = 0; break; }
            }
            if (ok) break;
            TAB_X(t, dest_row, q) = 0;
        }
        if (ex[q]) { // stabilizer has X or Y on qubit q → Z_q anticommutes
            TAB_Z(t, dest_row, q) = 1;
            int ok = 1;
            int inner_new = 0;
            for (int j = 0; j < n; j++) {
                inner_new ^= ((TAB_X(t, dest_row, j) & ez[j]) ^
                              (TAB_Z(t, dest_row, j) & ex[j]));
            }
            if (!inner_new) { TAB_Z(t, dest_row, q) = 0; continue; }
            for (int s = n; s < 2 * n; s++) {
                if (s == target_row) continue;
                int has_bits = 0;
                for (int j = 0; j < n; j++) {
                    if (TAB_X(t, s, j) || TAB_Z(t, s, j)) { has_bits = 1; break; }
                }
                if (!has_bits) continue;
                int inner = 0;
                for (int j = 0; j < n; j++) {
                    inner ^= ((TAB_X(t, dest_row, j) & TAB_Z(t, s, j)) ^
                              (TAB_Z(t, dest_row, j) & TAB_X(t, s, j)));
                }
                if (inner) { ok = 0; break; }
            }
            if (ok) break;
            TAB_Z(t, dest_row, q) = 0;
        }
    }

    return 1;
}

// Reset to fresh n-qubit state |00...0> (all stabilizers = Z_i)
void nuc_cliff_reset(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return;
    cliff_init_state(t);
}

// Get stabilizer group as a flat Vec.
// Each stabilizer row has 2n+1 entries: [x0, z0, x1, z1, ..., x_{n-1}, z_{n-1}, phase]
// Only includes non-trivial (non-zero) stabilizer rows.
long long nuc_cliff_get_stabilizers(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    NVec *result = nvec_new();

    for (int s = n; s < 2 * n; s++) {
        int nonzero = 0;
        for (int q = 0; q < n; q++) {
            if (TAB_X(t, s, q) || TAB_Z(t, s, q)) { nonzero = 1; break; }
        }
        if (!nonzero) continue;
        for (int q = 0; q < n; q++) {
            nvec_push(result, (long long)TAB_X(t, s, q));
            nvec_push(result, (long long)TAB_Z(t, s, q));
        }
        nvec_push(result, (long long)TAB_P(t, s));
    }

    return (long long)(size_t)result;
}

// ===========================================================================
//  PUBLIC API — RL Helper Functions
// ===========================================================================

// Encode the current tableau state as a feature vector for the RL policy network.
// Returns a Vec of f64 features (bitcast to i64):
//   [0] n_qubits / 20.0               (normalized qubit count)
//   [1] n_stabilizers / n_qubits       (normalized stabilizer count)
//   [2] frac weight-1 stabilizers      (weight distribution)
//   [3] frac weight-2 stabilizers
//   [4] frac weight-3+ stabilizers
//   [5] X-type fraction                (X/Z balance)
//   [6] Z-type fraction
//   [7] commutativity score            (fraction of stab pairs that commute)
//   [8] code rate = n_logical / n      (code rate proxy)
//   [9] avg stabilizer weight / n      (density measure)
// Total: 10 features.
long long nuc_cliff_state_features(long long handle, long long n_logical_) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int n_logical = (int)n_logical_;
    NVec *result = nvec_new();

    // Count stabilizers and their properties
    int num_stab = 0;
    int weight_1 = 0, weight_2 = 0, weight_3plus = 0;
    int total_x_ops = 0, total_z_ops = 0; // count of X-type and Z-type Paulis
    double total_weight = 0.0;

    // Store stabilizer indices for commutativity check
    int stab_indices[CLIFF_MAX_QUBITS];

    for (int s = n; s < 2 * n; s++) {
        int nonzero = 0;
        int w = 0;
        int xcount = 0, zcount = 0;
        for (int q = 0; q < n; q++) {
            int xb = TAB_X(t, s, q);
            int zb = TAB_Z(t, s, q);
            if (xb || zb) {
                nonzero = 1;
                w++;
                if (xb && !zb) xcount++;      // pure X
                else if (!xb && zb) zcount++;  // pure Z
                // Y (both set) counts as both
                else { xcount++; zcount++; }
            }
        }
        if (!nonzero) continue;

        stab_indices[num_stab] = s;
        num_stab++;
        total_weight += w;
        total_x_ops += xcount;
        total_z_ops += zcount;
        if (w == 1) weight_1++;
        else if (w == 2) weight_2++;
        else weight_3plus++;
    }

    double ns = (num_stab > 0) ? (double)num_stab : 1.0;

    // Commutativity score: fraction of stabilizer pairs that commute
    // (All stabilizers in a valid code commute, but during RL construction
    //  we might have intermediate states where not all do.)
    int pairs = 0, commuting_pairs = 0;
    for (int i = 0; i < num_stab; i++) {
        for (int j = i + 1; j < num_stab; j++) {
            pairs++;
            int si = stab_indices[i], sj = stab_indices[j];
            int inner = 0;
            for (int q = 0; q < n; q++) {
                inner ^= ((TAB_X(t, si, q) & TAB_Z(t, sj, q)) ^
                          (TAB_Z(t, si, q) & TAB_X(t, sj, q)));
            }
            if (!inner) commuting_pairs++;
        }
    }
    double comm_score = (pairs > 0) ? (double)commuting_pairs / (double)pairs : 1.0;

    int total_pauli_ops = total_x_ops + total_z_ops;
    double x_frac = (total_pauli_ops > 0) ? (double)total_x_ops / total_pauli_ops : 0.5;
    double z_frac = (total_pauli_ops > 0) ? (double)total_z_ops / total_pauli_ops : 0.5;

    // Pack features
    nvec_push(result, _mf2i((double)n / 20.0));                              // [0]
    nvec_push(result, _mf2i((double)num_stab / (double)n));                  // [1]
    nvec_push(result, _mf2i((double)weight_1 / ns));                         // [2]
    nvec_push(result, _mf2i((double)weight_2 / ns));                         // [3]
    nvec_push(result, _mf2i((double)weight_3plus / ns));                     // [4]
    nvec_push(result, _mf2i(x_frac));                                        // [5]
    nvec_push(result, _mf2i(z_frac));                                        // [6]
    nvec_push(result, _mf2i(comm_score));                                    // [7]
    nvec_push(result, _mf2i((double)n_logical / (double)n));                 // [8]
    nvec_push(result, _mf2i(total_weight / (ns * (double)n)));               // [9]

    return (long long)(size_t)result;
}

// Apply a random Clifford gate for exploration.
//   gate_type 0: random Hadamard (H on a random qubit)
//   gate_type 1: random Phase (S on a random qubit)
//   gate_type 2: random CNOT (on two distinct random qubits)
void nuc_cliff_random_gate(long long handle, long long gate_type, long long seed) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t || t->nq < 1) return;
    int n = t->nq;

    // Mix in the provided seed
    unsigned long long rng = t->rng ^ (unsigned long long)seed;
    rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
    if (rng == 0) rng = 1;
    t->rng = rng;

    int type = (int)(gate_type % 3);
    if (type < 0) type += 3;

    if (type == 0) {
        // Random H
        int q = (int)(cliff_rand(t) % (unsigned long long)n);
        nuc_cliff_h(handle, (long long)q);
    } else if (type == 1) {
        // Random S
        int q = (int)(cliff_rand(t) % (unsigned long long)n);
        nuc_cliff_s(handle, (long long)q);
    } else {
        // Random CNOT
        if (n < 2) return; // need at least 2 qubits
        int c = (int)(cliff_rand(t) % (unsigned long long)n);
        int tg = (int)(cliff_rand(t) % (unsigned long long)(n - 1));
        if (tg >= c) tg++; // ensure tg != c
        nuc_cliff_cnot(handle, (long long)c, (long long)tg);
    }
}

// Count how many single-qubit Pauli errors are detectable by the current stabilizer code.
// Tests all 3n single-qubit errors (X_i, Z_i, Y_i for i=0..n-1).
// Returns count (max = 3n). Ratio count/3n gives Knill-Laflamme partial credit.
long long nuc_cliff_count_detectable_errors(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int count = 0;

    int ex[CLIFF_MAX_QUBITS], ez[CLIFF_MAX_QUBITS];

    for (int q = 0; q < n; q++) {
        // X error on qubit q
        memset(ex, 0, n * sizeof(int)); memset(ez, 0, n * sizeof(int));
        ex[q] = 1;
        // Check if anticommutes with at least one stabilizer
        for (int s = n; s < 2 * n; s++) {
            int nonzero = 0;
            for (int j = 0; j < n; j++) if (TAB_X(t, s, j) || TAB_Z(t, s, j)) { nonzero = 1; break; }
            if (!nonzero) continue;
            int inner = 0;
            for (int j = 0; j < n; j++) inner ^= ((ex[j] & TAB_Z(t, s, j)) ^ (ez[j] & TAB_X(t, s, j)));
            if (inner) { count++; break; }
        }
        // Z error on qubit q
        memset(ex, 0, n * sizeof(int)); memset(ez, 0, n * sizeof(int));
        ez[q] = 1;
        for (int s = n; s < 2 * n; s++) {
            int nonzero = 0;
            for (int j = 0; j < n; j++) if (TAB_X(t, s, j) || TAB_Z(t, s, j)) { nonzero = 1; break; }
            if (!nonzero) continue;
            int inner = 0;
            for (int j = 0; j < n; j++) inner ^= ((ex[j] & TAB_Z(t, s, j)) ^ (ez[j] & TAB_X(t, s, j)));
            if (inner) { count++; break; }
        }
        // Y error on qubit q
        memset(ex, 0, n * sizeof(int)); memset(ez, 0, n * sizeof(int));
        ex[q] = 1; ez[q] = 1;
        for (int s = n; s < 2 * n; s++) {
            int nonzero = 0;
            for (int j = 0; j < n; j++) if (TAB_X(t, s, j) || TAB_Z(t, s, j)) { nonzero = 1; break; }
            if (!nonzero) continue;
            int inner = 0;
            for (int j = 0; j < n; j++) inner ^= ((ex[j] & TAB_Z(t, s, j)) ^ (ez[j] & TAB_X(t, s, j)));
            if (inner) { count++; break; }
        }
    }
    return (long long)count;
}

// Compute best code distance achievable by removing one stabilizer generator.
// For each of the n generators, temporarily removes it (zeroes the row),
// computes nuc_cliff_distance(h, 1), and restores it.
// Returns the maximum distance found across all removals.
// This is how we evaluate [[n,1,d]] codes from an n-generator stabilizer state.
long long nuc_cliff_best_distance_k1(long long handle) {
    CliffordTableau *t = (CliffordTableau *)(size_t)handle;
    if (!t) return 0;
    int n = t->nq;
    int cols = tab_cols(t);
    int best_d = 0;

    unsigned char save_row[2 * CLIFF_MAX_QUBITS + 1];

    for (int s = n; s < 2 * n; s++) {
        // Check if this row is active (has any nonzero Pauli bits)
        int active = 0;
        for (int q = 0; q < n; q++) {
            if (TAB_X(t, s, q) || TAB_Z(t, s, q)) { active = 1; break; }
        }
        if (!active) continue;

        // Save the row, then zero it
        memcpy(save_row, &t->tab[s * cols], cols);
        memset(&t->tab[s * cols], 0, cols);

        // Compute distance with this generator removed (k=1)
        long long d = nuc_cliff_distance(handle, 1);
        if ((int)d > best_d) best_d = (int)d;

        // Restore the row
        memcpy(&t->tab[s * cols], save_row, cols);
    }

    return (long long)best_d;
}
