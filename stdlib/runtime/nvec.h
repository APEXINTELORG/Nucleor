/* nvec.h — canonical NVec layout for every Nucleor runtime TU.

   Audit finding A1 (Critical, 2026-05-08, Lane 2):
   Canonical NVec at `nucleor_llvm_rt.c:2358-2363` was
       typedef struct {
           long long *data;
           int len;
           int cap;
           long long inline_data[2];
       } NVec;          // 32 bytes, 16-byte aligned
   ~200 sister `*_rt.c` files (bioseq_rt.c, bm25_rt.c, control_rt.c,
   diff_sim_rt.c, ...) redeclared NVec WITHOUT `inline_data[2]`,
   producing a 24-byte allocation that the canonical
   `__nucleor_vec_push` / `__nucleor_vec_free` helpers later access
   past-end (reading `v->inline_data` and the comparison
   `v->data != v->inline_data`). Practical masking by malloc round-up
   and lucky heap garbage, but latent UB at the hottest single ABI
   type in the runtime.

   Fix: declare NVec exactly once here. Force-included alongside
   `nuc_alloc.h` by the s1 link command so all 200+ sister files
   see the canonical inline_data[2] layout. Sister files MUST NOT
   redeclare `typedef struct { ... } NVec;` — `tools/check_nvec_layout.sh`
   asserts this. A `_Static_assert` in the canonical TU pins
   `sizeof(NVec) == 32`. */

#ifndef NUC_NVEC_H
#define NUC_NVEC_H

/* Guard against accidental redeclaration in sister files that have
   not yet been migrated to use this header. The duplicate-typedef
   diagnostic from the C compiler will point reviewers here. */
#ifndef NUC_NVEC_DEFINED
#define NUC_NVEC_DEFINED

typedef struct {
    long long *data;
    int len;
    int cap;
    long long inline_data[2];
} NVec;

#endif /* NUC_NVEC_DEFINED */

#endif /* NUC_NVEC_H */
