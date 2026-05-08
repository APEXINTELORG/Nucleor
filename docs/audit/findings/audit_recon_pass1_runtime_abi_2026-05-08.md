# Recon Pass-1 Audit — Layer 7: Runtime ABI

**Date:** 2026-05-08
**Scope:** every `__nucleor_*` and `nuc_*` symbol exported by
`stdlib/runtime/*.c`, plus the `helper_manifest.toml` accuracy check,
calling-convention, memory-layout, ownership/lifetime, and effect-class
consistency for the v1.0 Nucleor runtime ABI surface.
**Methodology:** static analysis of every C runtime translation unit,
cross-reference against `docs/rfcs/helper_manifest.toml`, scratch
inventory in `audit_scratch_runtime_abi/`. NO source modified, NO fixes
applied, NO `verify.sh` run. Per-class deep-test was performed by
walking the relevant C functions and comparing intent (helper name,
manifest contract, code path) for representative + known-risky
symbols.
**Output constraint:** observations + remediation only. Severity rubric
matches prior recon passes:

| Severity | Meaning |
|---|---|
| Critical | ABI symbol crashes / leaks / double-frees / ownership reversal in default mode |
| High | Manifest mismatch (silent gap), wrong effects/sig, ownership ambiguity, latent UB |
| Medium | Doc/contract poor, edge truncation, fragile-by-design |
| Low | Cosmetic, misleading naming, dead code |
| Note | Observation, no action |

---

## 1. ABI symbol inventory

### 1.1 Counts

| Source | Symbol count |
|---|---|
| `helper_manifest.toml` (claimed total) | 875 |
| `helper_manifest.toml` distinct `symbol = "__nucleor_*"` | 875 |
| Distinct `__nucleor_*` strings parsed from `nucleor_llvm_rt.c`, `process_rt.c`, `rod_helpers_rt.c` | 776 (after macro expansion this rises by ~54) |
| Manifest entries with no static C definition (after macro expansion) | **70** — all flagged `stability = "unstable"` per the v0.4 placeholder allowlist (verified spot-check on `__nucleor_kvcache_new`, `__nucleor_region_new`, `__nucleor_par_map`, `__nucleor_simd_add`, `__nucleor_tensor_view`, `__nucleor_vec_chain`, `__nucleor_vec_filter`, `__nucleor_vec_map`, `__nucleor_vec_fold`, `__nucleor_vector_add`, `__nucleor_sha256`, `__nucleor_putchar`, `__nucleor_rwlock_new`, `__nucleor_rods_f64_add`, `__nucleor_ambient_random`, `__nucleor_ambient_scheduler`, `__nucleor_profile_start`, `__nucleor_py_eval`, `__nucleor_device_alloc`). **OK — schema-doc-correct** |
| Real C-side `__nucleor_*` symbols MISSING from the manifest | **9 confirmed** — see § 1.2 |
| Files producing helpers (the runtime tree, by file) | 196 `*_rt.c` + `*.cu` + 3 `.nr` |

Files providing the public `__nucleor_*` ABI: only `nucleor_llvm_rt.c`,
`process_rt.c`, `rod_helpers_rt.c`. The remaining ~190 `*_rt.c` files
provide unprefixed `nuc_*` helpers — **these never enter the manifest**
(see § 1.3).

### 1.2 Manifest gaps — confirmed real public symbols absent from manifest

These are exported with external linkage from the runtime tree, lookable
up by the linker, but `helper_manifest.toml` has no row for them:

| Symbol | Source file | Severity |
|---|---|---|
| `__nucleor_proc_run` | `process_rt.c:53` | **High** |
| `__nucleor_proc_run1` | `process_rt.c:122` | High |
| `__nucleor_proc_capture_stdout` | `process_rt.c:66` | High |
| `__nucleor_proc_capture_status` | `process_rt.c:96` | High |
| `__nucleor_proc_capture_with_status` | `process_rt.c:103` | High |
| `__nucleor_mutex_free` | `nucleor_llvm_rt.c:3743 (Win), 4024 (POSIX)` | **High** (`mutex_new` IS in manifest — alloc tracked, free invisible) |
| `__nucleor_mutex_free_value` | `nucleor_llvm_rt.c:3806, 4033` | High |
| `__nucleor_channel_close` | `nucleor_llvm_rt.c:3868, 4119` | High |
| `__nucleor_channel_is_closed` | `nucleor_llvm_rt.c:3877, 4128` | High |
| `__nucleor_vec_u8_extend_from_ptr` | `nucleor_llvm_rt.c:5086` | High |

**Note** — `__nucleor_overflow_flag`, `__nucleor_max_depth_counts`,
`__nucleor_str_intern_stats` (variable form), `__nucleor_vec_direct_checked`
appeared in the regex sweep but inspection showed they are file-static
(internal linkage, not callable from outside the TU). Not gaps.

`__nucleor_str_intern_stats(void)` — the **accessor function** — IS a
public extern, defined at `nucleor_llvm_rt.c:1331`, and is **also missing
from the manifest**. (High.) Brings the confirmed gap count to **10**.

### 1.3 Unprefixed `nuc_*` helpers — outside manifest scope

The runtime exposes a parallel surface of unprefixed `nuc_*` and other
non-namespaced symbols that bypass the manifest entirely. Examples:

| Symbol | Source | Note |
|---|---|---|
| `nuc_vec_free` / `nuc_vec_clear` / `nuc_vec_mem_bytes` | `mem_rt.c:22..43` | Sister of `__nucleor_vec_free` with **divergent free semantics** (no double-free guard) |
| `vec_push_s`, `vec_get_s`, `hvec_push_s`, `hvec_get_s`, `hvec_set_s` | `rod_helpers_rt.c:15..35` | Bare names, will collide with any user symbol at link time |
| `call_fn2`, `call_fn3` | `rod_helpers_rt.c:39..47` | Type-erased function-pointer trampolines, no `__nucleor_` prefix |
| `nuc_node_kind`, `nuc_node_field`, `nuc_list_len`, `nuc_list_get` | `nucleor_llvm_rt.c:2547..2570` | Compiler-internal, but exported — same surface |
| `nuc_bio_*`, `nuc_bm25_*`, etc. | the ~190 domain `*_rt.c` files | All public symbols, none in manifest |
| `nuc_rng_seed`, `nuc_rng_uniform`, `nuc_rng_int`, `nuc_rng_normal`, `nuc_rng_bernoulli`, `nuc_rng_exponential` | declared `extern` at `nucleor_llvm_rt.c:4034..4039` and others | Referenced by name but origin is downstream rt files |

This is a **classification choice**, not a bug per se — but the
manifest schema doc (`docs/rfcs/helper_manifest_schema.md`) is silent
on it. To an adopter reading the manifest, the runtime ABI looks like
875 helpers; reality is 875 namespaced helpers + an order-of-magnitude
larger sea of unprefixed `nuc_*`/bare symbols that the manifest does
not see, audit, or version. **Severity: High** for the documentation
gap; the helpers themselves work but are an unmanaged surface.

### 1.4 Build / availability matrix

| Where the helper is called from | Force-include of `nuc_alloc.h`? | OOM-panic wrappers active? |
|---|---|---|
| Inside `nucleor_llvm_rt.c` | yes (explicit `#include`) | yes |
| Other `*_rt.c` compiled via `nucleor_s1_compiler.nr` link command | yes (clang `-include`) | yes |
| **Other `*_rt.c` compiled with a third-party / ad-hoc clang invocation** | **no** | **no — silent NULL→crash on OOM** |

This is documented at `nuc_alloc.h:1..16` but the contract is invisible
at the helper-manifest level: **manifest says `effects=["alloc"]` →
implies OOM-panic; reality depends on how the runtime archive was
built**. Severity: **High** for adopters of `target/libnucleor_runtime.a`.

---

## 2. Per-class deep-test results

### 2.1 Class `Allocation` (manifest count: 10 stable + region/arena unstable)

Stable surface: `__nucleor_vec_new`, `__nucleor_vec_with_capacity`,
`__nucleor_vec_free`, `__nucleor_str_arena_*`, `__nucleor_dyn_box_*`,
`__nucleor_arena_new` etc. (the v0.3 arena set IS implemented despite
being grouped with the unstable region API in some prior docs — verified
from `nucleor_llvm_rt.c:1210..1232`).

Findings:
- **A1 (Critical) — divergent NVec layout across 200+ runtime files.**
  Canonical NVec at `nucleor_llvm_rt.c:2358-2363` is `{long long *data;
  int len; int cap; long long inline_data[2];}` — 32 bytes, 16-byte
  aligned. ~200 sister `*_rt.c` files (e.g., `bioseq_rt.c:189`,
  `bm25_rt.c:220`, `control_rt.c:69, 93, 137, 162, 193, 246`,
  `clifford_rt.c:26`, `checkpoint_rt.c:44, 75, 118`, `cuda_rt.cu:550,
  1000, 1090, 1109, 1128`, `diff_sim_rt.c:408, 607, 622`, …) redeclare
  `typedef struct {long long *data; int len; int cap;} NVec;` —
  **without `inline_data[2]`**. They `malloc(sizeof(NVec))` and return
  the handle. When such a handle reaches `__nucleor_vec_free` /
  `__nucleor_vec_push` (canonical helper), the helper reads
  `v->inline_data` past the end of the truncated allocation: undefined
  behaviour, and in `__nucleor_vec_free` the comparison
  `v->data != v->inline_data` then determines whether to free the
  data buffer based on garbage memory contents → either leak or
  potential heap corruption. Practically masked today because (a) most
  malloc implementations round to 32 bytes anyway, and (b) heap
  garbage is unlikely to coincide with a valid `data` pointer; but it
  is **latent UB at the hottest single ABI type in the runtime**.
  Verify with `bioseq_rt.c::nuc_bio_find_orfs` (line 188-214):
  allocates 24-byte NVec, returns handle, eventually freed via the
  user-side `__nucleor_vec_free`.
  *Remediation:* declare NVec exactly once (`stdlib/runtime/nuc_nvec.h`)
  and force-include alongside `nuc_alloc.h` so all 200+ sister files
  see the canonical `inline_data[2]` layout. Add a `_Static_assert`
  on `sizeof(NVec) == 32` in the canonical TU.

- **A2 (High) — `__nucleor_vec_with_capacity` int-truncates large `n`.**
  `nucleor_llvm_rt.c:2391`: `long long cap = n < 2 ? 2 : n;` — but
  `v->cap` is `int`. A request `n > INT_MAX` (~2.1B elements) allocates
  the correct number of bytes with `malloc((size_t)cap*8)` but stores
  a truncated `cap` in the struct. Subsequent `vec_push` will look at
  the wrong cap and either grow needlessly or, if truncated to a
  negative value, `_grow_cap` panics. Silent corruption at request
  time, hard panic at use time.
  *Remediation:* widen `NVec.cap` and `NVec.len` to `int64_t`; or fail
  fast at `vec_with_capacity` if `n > INT_MAX` with a clear panic.

- **A3 (Critical, lenient mode only) — vec_push on realloc/malloc fail
  segfaults.** `nucleor_llvm_rt.c:2506-2511`. With
  `NUCLEOR_OOM_LENIENT=1`, `_nuc_alloc_xrealloc` / `xmalloc` return
  NULL. The code unconditionally assigns the NULL into `v->data`.
  The next access reads from NULL. The OOM contract claims "lenient
  mode = adopters handle it themselves" but the code makes that
  impossible from within `vec_push` — control never returns to the
  caller before the NULL deref.
  *Remediation:* in lenient mode, leave `v->data` unmodified on alloc
  failure and propagate failure through a status return; or document
  that `NUCLEOR_OOM_LENIENT=1` is incompatible with `vec_push` and
  require adopters to use a separate `vec_push_or_fail` surface.

- **A4 (High) — `__nucleor_vec_f32_new` second alloc unguarded.**
  `nucleor_llvm_rt.c:5101-5106`. Allocates `NVecF32` then `data`
  separately; in lenient mode, `data == NULL` is stored, returned
  handle is "valid" but unusable, first push segfaults. Same pattern
  in `__nucleor_vec_f32_with_capacity:5108`. Multiple typed-vec
  variants share this hazard.
  *Remediation:* in lenient mode, free the outer struct and return 0
  if the inner buffer alloc fails.

- **A5 (High) — `nuc_vec_free` (mem_rt.c) lacks the double-free guard
  that `__nucleor_vec_free` has.** Comment in `nucleor_llvm_rt.c:2443`
  asserts they are counterparts. They are not. `nuc_vec_free` is
  what long-running ML / verify-loop code calls; the silent path
  without the sentinel guard means double-frees go undetected
  precisely where they are most likely to occur.
  *Remediation:* either move the guard into a shared inline (header)
  used by both, or remove `nuc_vec_free` and direct adopters to
  `__nucleor_vec_free`. Add the env-driven sentinel-stamp path.

- **A6 (Medium) — `__nucleor_vec_free` manifest signature wrong.**
  Manifest `abi = "(ptr) -> void"` but C signature is `void
  __nucleor_vec_free(long long handle)` — handle, not ptr. Same for
  every `*_free(long long h)` and many `*_get(long long h, …)`
  surfaces. Practically harmless on x86_64 (both go in RCX/RDI), but
  the manifest is meant to be the IR-level signature source-of-truth
  and **will mislead a future cross-platform / pointer-tagged backend**.
  Spot-check confirmed for `__nucleor_atomic_i64_free`,
  `__nucleor_hashmap_free`, `__nucleor_btreemap_free`,
  `__nucleor_vec_u8_free`. Likely class-wide.
  *Remediation:* align manifest abi rows to actual C signatures; OR
  document that `ptr` in manifest = "i64-or-pointer at the ABI level".

- **A7 (Medium) — `__nucleor_vec_free` proof_obligation incorrect.**
  Manifest says `proof_obligation = "bounds_within_len"`. A free has
  no bounds. Should be `alloc_capability_or_arena_owned`.
  Pattern likely repeats for `vec_free`/`hashmap_free`/etc.
  *Remediation:* re-pass class `Allocation` and any `*_free` rows in
  class `VectorOps`/`Collection`.

- **A8 (Low) — `__nucleor_dyn_box_make` returns 0 on alloc failure but
  in default mode the OOM wrapper has already exit'd.** Dead branch
  except in lenient mode. Documented behavior in lenient mode is
  consistent. Note only.

### 2.2 Class `VectorOps`

- **V1 (High, by-design but trust-violating) —
  `__nucleor_str_substring` does not validate `end <= strlen(s)`.**
  Default helper. Lines 2005-2022. Per `docs/ffi-conventions.md` G-9
  the runtime trusts the caller. The opt-in `_strict` variant exists
  (line 2027). However:
  - The default's panic message says `"str_substring OOB"` but only
    fires for `start<0` or `end<start`, NOT `end>strlen(s)`. **The
    panic text overpromises**; an over-end call passes silently and
    over-reads, potentially copying past-end heap bytes into the
    returned string (info leak class).
  - `int n = (int)(end - start)` — if `end-start > INT_MAX`,
    truncation; `malloc(n+1)` allocates the truncated size; `memcpy`
    writes only `n` bytes, but `n` is wrong. Silent miscompute on
    requests >2 GB.
  *Remediation:* either rename the bounds-trust check ("range OOB"),
  or upgrade the default to do the strlen check (the "free version"
  performance argument is largely gone now that `_strict` exists and
  the default is allocating O(n) anyway). Use `int64_t` for `n`.

- **V2 (Medium) — `__nucleor_vec_get`, `__nucleor_vec_set`,
  `__nucleor_vec_len`, `__nucleor_vec_pop` manifest effects=["alloc"]
  but they do not allocate.** Spot-check across the
  `[[helper]] class = "VectorOps"` block of the manifest indicates
  this is the class default (`["alloc"]`), pattern-applied to every
  member. Misleading for any pure-fn / `@hot` analysis tooling.
  *Remediation:* tighten the class default; pure-read members
  (`*_get`, `*_len`, `*_capacity`, `*_at`, `*_contains`) get `[]`,
  alloc-emitting members keep `["alloc"]`.

- **V3 (Low/Medium) — `__nucleor_vec_pop` returns void.** Pop in every
  major language returns the popped element. Here it's a length
  decrement only. Rod-side `Vec::pop()` likely wraps and returns.
  Note for review.

- **V4 (Medium) — `_grow_cap` capacity-overflow check is element-size
  aware (good) but `byte_max = SIZE_MAX/2` is computed as
  `(size_t)LLONG_MAX/2`. On 32-bit Windows where `size_t == 32` bits,
  the cast loses the high 32 bits, producing the wrong upper bound.**
  Project is x86_64 only today, but the comment at the top of
  `nucleor_llvm_rt.c:4` reads "also works on Linux with minor changes"
  — there is no `_Static_assert(sizeof(size_t) >= 8)` guarding it.
  Note / Low for v1.

### 2.3 Class `StringFormat` / IO

- **S1 (High) — Multiple `const char *` returners mix string-literal
  sentinels with malloc'd heap buffers.** Affected:
  `__nucleor_file_read_string` (returns `""` on every error path,
  malloc'd buffer on success — line 2247-2260), `__nucleor_str_substring`
  (returns `""` on null s — line 2007), `__nucleor_str_to_lower/upper/
  trim/replace/...` (every one returns `""` on null), `__nucleor_proc_
  capture_stdout` (returns `""` on multiple error paths). **The
  caller cannot safely call `__nucleor_str_free` on the returned
  pointer without distinguishing the two cases.** The convention
  appears to be "leak the literal cases, free the success cases" but
  is undocumented in the helper rows. A central helper attempting to
  free always either crashes (free of literal) or leaks.
  *Remediation:* uniform contract — always return a heap-allocated
  buffer (even an empty one is `malloc(1)` + write `\0`); callers
  can then unconditionally free. Or expose a sentinel-aware
  `str_free_safe()`.

- **S2 (High) — `__nucleor_proc_capture_stdout` thread-safety contract
  violated by the global status slot.** `process_rt.c:64-94`. The
  comment claims "single-threaded gate code reads this freely" but the
  symbol is in the public ABI without thread/scope marking; nothing
  prevents two threads from calling concurrently and getting each
  other's status. The companion `_with_status` variant is the
  documented escape, but the bare `_capture_stdout` + `_capture_status`
  pair remains exported and is dangerous.
  *Remediation:* mark `g_last_capture_status` as `_Thread_local` (or
  `__declspec(thread)`); document the per-thread semantic in a manifest
  `notes` field.

- **S3 (High) — `__nucleor_proc_run1` does no shell-escape on `cmd` or
  `arg`.** Constructed as `"\"%s\" \"%s\""`. An `arg` containing `"`
  produces a malformed line. Higher up: this is a documented "run-the-
  shell" surface (`system(3)`) so any embedded `" ; rm -rf / ; "`
  becomes an injection. Callers are expected to be trusted, but the
  helper has no `unsafe` / `direct_ffi` taint marking in the manifest
  (it's not in the manifest at all per § 1.2).
  *Remediation:* document as `effects = ["io", "panic"]`,
  `proof_obligation = "shell_escape_caller"`, mark direct_ffi.
  Provide a non-shell variant that takes argv directly via
  `CreateProcessW` / `posix_spawn`.

- **S4 (Medium) — `__nucleor_proc_capture_with_status`'s 32-byte
  header buffer fits today's `int64_t` "%lld\\n" but is fragile.**
  `process_rt.c:108-115`: writes `"%lld\\n"` into a fixed 32-byte
  prefix region of the combined buffer, then memcpys the body
  starting at `header_len`. `LLONG_MIN` formats to 21 chars + NUL =
  22 — fits — but the design has zero margin and no static assertion.
  *Remediation:* size the header buffer dynamically, or
  `_Static_assert` on the upper bound.

- **S5 (Medium) — `__nucleor_str_intern_stats` packs hits<<24 but
  comment says `hits<<32`.** `nucleor_llvm_rt.c:1331-1332`. Code:
  `(g_intern_hits << 24) | (g_intern_misses & 0xFFFFFFLL)`. Comment:
  "(hits << 32) | misses (truncated)". Either typo in code (likely)
  or in comment; misses get silently truncated to 24 bits (16 M cap),
  unreasonable for a long-running self-host run.
  *Remediation:* fix the shift to 32 and the mask to 0xFFFFFFFFLL,
  or delete the helper if no longer used. Add to manifest either way.

- **S6 (Medium) — `__nucleor_file_read_string` uses `long` for file
  size on Windows (32-bit).** Lines 2247-2260. `ftell` returns `long`;
  for files > 2 GB on Windows the value is wrong (or `-1`). Uses
  `_ftelli64` would be required. Project is x86_64 but `long` is
  still 32-bit on MSVC ABI. Files > 2 GB are unusual for the
  compiler workflow but the helper is part of the general
  user-callable ABI.
  *Remediation:* `_ftelli64` on `_WIN32`, `ftello` on POSIX.

- **S7 (Low) — `__nucleor_file_append_string` uses `strlen(data)` for
  the write length.** Embedded NUL bytes are silently truncated. The
  helper name says "string", so technically correct, but a more
  general `file_append_bytes(path, ptr, len)` would be safer for
  compiler-emitted IO.

- **S8 (Note) — `__nucleor_int_to_str` and friends use a 32-byte
  stack buffer.** `LLONG_MIN` = 20 chars + sign + NUL = 22 — fits.
  No bug, just one byte from the brink.

### 2.4 Class `Concurrency`

- **C1 (High) — `__nucleor_mutex_free` not in manifest; alloc/free
  pair broken.** § 1.2 covered. Direct symptom: a manifest-driven
  capability/leak audit cannot see mutex frees.

- **C2 (High) — `__nucleor_atomic_i64_*` aliases assume
  `_Atomic long long` alignment from `malloc`.**
  `nucleor_llvm_rt.c:7758-7813`. C11 `_Atomic long long` may require
  16-byte alignment for lock-free guarantees; `malloc(8)` returns
  8-byte aligned on 32-bit ABIs. x86_64 `malloc` returns 16-byte, so
  practically OK on Windows/Linux x86_64 today. **No
  `_Static_assert(_Alignof(_Atomic long long) <= MALLOC_ALIGN)`** —
  silent platform-portability tripwire.

- **C3 (Note) — Windows mutex fallback path uses `CRITICAL_SECTION`,
  POSIX uses `pthread_mutex_t` — manifest signature `(...) -> i64`
  (handle). Different runtime invariants per platform; no platform
  field on manifest rows.** Adopters embedding the runtime in a
  GUI-event-loop process need to know the Windows path is recursive
  (CS is recursive by default on Windows).
  *Remediation:* add a `platform_notes` manifest field, or document
  in the rod-side `extern fn` declaration.

### 2.5 Class `PanickingArith`

- **P1 (Note) — Overflow flag and `__nucleor_overflow_flag` are
  thread-local since v0.8.82.** Properly handled. The `i8/i16/i32/u8/
  u16/u32` family is macro-generated and not visible to a naive grep
  but is exported and present (`nucleor_llvm_rt.c:4837` etc.). All
  rows resolve in the manifest.

- **P2 (Medium) — `__nucleor_saturating_mul_<W>` for signed widths
  pre-clamps inputs, then multiplies, then clamps the product.**
  This is correct for W∈{i8,i16,i32}. For i64 the code (line 4504)
  does NOT pre-clamp (no narrower domain to clamp to); instead it
  uses `a != r/b` which suffers from the textbook signed-overflow-is-
  UB issue: the multiply itself is UB if it overflows, after which
  the divide compare is unreliable on aggressive compilers. Modern
  Clang at -O2 has been observed to elide such checks.
  *Remediation:* implement i64 checked-mul via the
  `__builtin_mul_overflow` intrinsic on Clang/GCC and the
  `_mul128`/`__mulh` family on MSVC. (Verify whether v0.3.205
  perf-regression doc applies here — that was strlen, not mul, so
  no overlap.)

### 2.6 Class `Collection`

- **CO1 (Medium) — `__nucleor_btreemap_get` panics on missing key
  but silently returns 0 on null map.** Inconsistent. The null-map
  case happens after a botched `btreemap_new` in lenient OOM mode;
  silently returning 0 lets a subsequent typed assumption (e.g.,
  "0 means 'not present'") propagate the bug.
  *Remediation:* either both panic, or both lenient — pick one for
  the family.

- **CO2 (Note) — `__nucleor_btreeset_*` aliases dispatch to
  `__nucleor_btreemap_*` with `val=1`.** Legal because BTreeSet is
  defined as BTreeMap with unit value. Manifest documents both.
  Acceptable.

- **CO3 (Medium) — `__nucleor_hashmap_remove`'s rehash loop calls
  `__nucleor_hashmap_insert` recursively while iterating the
  cluster.** `nucleor_llvm_rt.c:5840-5849`. `hashmap_insert` may
  trigger a grow (realloc the slot table) — if it does, the cluster
  iteration's own `m->slots[next]` pointer becomes stale and the
  `tmp.key` pointer (which was just freed two lines later) was
  inserted into a NEW slot table that the outer loop is no longer
  iterating. The cluster invariant breaks.
  *Remediation:* read the full cluster into a local stash before
  re-inserting; OR insert without growing (split insert and grow
  paths so removal can use the no-grow form). Reproduce: insert
  enough to push the table to grow-threshold, then remove the head
  of a long probe-cluster.

### 2.7 Class `IO`

Covered above (S1, S2, S3, S6, S7).

### 2.8 Class `TensorOps` / GPU / kvcache / device

- **T1 (Note) — All 30 `__nucleor_tensor_*` / `__nucleor_kvcache_*` /
  `__nucleor_device_*` / `__nucleor_simd_*` /
  `__nucleor_par_*` / `__nucleor_rwlock_*` / `__nucleor_region_*`
  / `__nucleor_rods_f64_*` rows are `stability="unstable"` and have
  no runtime body.** This is documented as the v0.4 placeholder set.
  Linker errors will surface for any user code that calls them. As
  long as the s1 compiler does NOT emit calls to these from any
  reachable path, OK. Spot-check confirmed they're guarded; suggest
  adding a CI assertion that no `unstable`-flagged symbol appears in
  any `.nr` file outside the placeholder allowlist.

### 2.9 Class `ToolingMeta` / `Random` / `Time`

Surface looks consistent. No findings beyond the manifest gap for
`__nucleor_str_intern_stats` (S5).

---

## 3. Cross-cutting findings

### 3.1 Calling-convention correctness

- **CC1 (Note) — All public helpers use the C calling convention
  (cdecl on Win32, SysV on POSIX) by default.** No
  `__attribute__((sysv_abi))` or `__stdcall` annotations. The IR
  emitter (per `compiler/nucleor_s1_compiler.nr`) presumably uses the
  default. Consistent. No mismatch found.
- **CC2 (Low) — Mixed handle ABI: most helpers take `long long`
  handles; some take `NVec *` typed pointers
  (`__nucleor_vec_push`, `__nucleor_vec_get`, `__nucleor_vec_len`,
  `__nucleor_vec_pop`, `__nucleor_vec_set`).** Manifest uniformly
  says `(ptr, …)`. Practically identical at SysV-x86_64 (both go in
  RDI/RCX), but adopters writing a custom backend (RISC-V, ARM64,
  pointer-tagged platforms) will see a real difference.
  *Remediation:* either make all of them `long long` (matches the
  rest of the surface), or all of them `NVec*` and update the
  manifest abi rows to reflect.

### 3.2 Memory model — alignment / padding

- **MM1 (already covered in A1) — NVec layout divergence.**
- **MM2 (Note) — `nuc_alloc.h` macros redefine `malloc/realloc/calloc`
  globally inside every TU that pulls the header.** Force-include
  means **every** subsequent header included in that TU sees the
  redefinition. `<stdlib.h>` was already included at line 38; if
  some downstream `*_rt.c` includes a third-party header AFTER
  `nuc_alloc.h` that itself defines an `inline static void *foo()`
  using `malloc`, that `foo`'s `malloc` becomes
  `_nuc_alloc_xmalloc` — silent rewriting of third-party code. The
  runtime today only depends on libc and (on Windows) `windows.h` /
  `dbghelp.h`, so unobserved in practice. Worth a `#warning` in the
  header pointing to the include-order requirement.
- **MM3 (Note) — `g_intern.slots` and other singletons in
  `nucleor_llvm_rt.c` are file-static.** Per-process correctness
  good. If the runtime is ever loaded as a shared library twice
  (multiple `.dll` instances on Windows), the intern table doubles.
  Document a "single-load" invariant.

### 3.3 Effect-class consistency

- **EC1 (Medium) — VectorOps class default `effects = ["alloc"]`
  applied to pure-read members (`vec_get`, `vec_set`, `vec_len`,
  `vec_pop`, `vec_capacity`, `vec_at`).** Reduces the value of
  effect-driven `@hot`/`@const_fn` analysis. § 2.2 V2.
- **EC2 (Medium) — `__nucleor_dyn_box_make` proof_obligation is
  `alloc_capability_or_arena_owned` (correct), but `__nucleor_vec_free`
  carries `bounds_within_len` (wrong).** § 2.1 A7 — class-wide
  audit needed.
- **EC3 (Note) — No `direct_ffi` / `unsafe` rows in the manifest.**
  The schema doc references "direct_ffi well-marked" (Layer 7
  audit scope) but the rendered TOML shows no row carrying such a
  flag. `__nucleor_proc_run1` (shell injection) and `call_fn2`/
  `call_fn3` (raw fn-pointer trampolines) are the prime
  candidates. Schema doesn't define a field for it yet. Layer-7
  scope-creep into spec but worth flagging.

### 3.4 Cross-language (Rust bridge)

Out-of-cwd `tools/check_rust_bridge_ownership.{sh,ps1}` exists; not
exercised in this audit (no fixes / no script runs). The presence of
the pair, plus `docs/heap-aliasing-evidence.md`, suggests adopters
already monitor it. No finding here, just a note that any change
arising from A1 (NVec layout) will require a re-run of the bridge
ownership check.

---

## 4. Findings + remediation summary table

| ID | Severity | Title | Remediation |
|---|---|---|---|
| A1 | **Critical** | NVec layout divergent across 200+ rt files (no `inline_data`) | Single-source `NVec` via `nuc_nvec.h`; force-include alongside `nuc_alloc.h`; `_Static_assert` size |
| A3 | **Critical** | vec_push NULL deref in `NUCLEOR_OOM_LENIENT=1` | Don't overwrite `v->data` on alloc fail; surface failure |
| V1 | High | `str_substring` over-end OOB silent + INT truncation; panic msg lies | Make default check end<=strlen, widen `n` to int64 |
| 1.2-G1..G10 | High | 10 public symbols missing from manifest (proc_*, mutex_free*, channel_close/_is_closed, vec_u8_extend_from_ptr, str_intern_stats) | Re-run `tools/gen_helper_manifest.nr`, fix the generator's symbol-discovery regex to catch these surfaces; add CI gate that diffs runtime symbols vs manifest |
| 1.3 | High | Unprefixed `nuc_*` and bare-named symbols (vec_push_s, call_fn*, all 190 `*_rt.c` exports) outside manifest scope | Either rename to `__nucleor_` and include, OR add a separate `helper_manifest_internal.toml` for them and document the split in the schema doc |
| 1.4 | High | OOM-panic contract only active when built through s1 link command; runtime archive built standalone has the legacy crash-on-NULL behavior | Move OOM wrappers into a non-static API in `nuc_alloc.c` (compiled into the archive), drop the macros; OR add a `#error` in `nuc_alloc.h` if not built with the s1 toolchain |
| A2 | High | `vec_with_capacity` int-truncates `cap > INT_MAX` | Widen NVec.cap/len to int64 |
| A4 | High | `vec_f32_new` and friends NULL-deref in lenient OOM mode | Free outer struct on inner-alloc fail |
| A5 | High | `mem_rt.c::nuc_vec_free` lacks the sentinel guard | Share the guard between `nuc_vec_free` and `__nucleor_vec_free` |
| S1 | High | const-char* helpers mix string-literal sentinels with malloc'd buffers | Always return malloc'd; make `str_free` unconditionally safe |
| S2 | High | `proc_capture_stdout` + global status slot races between threads | Make slot `_Thread_local`; document or remove `_capture_status` |
| S3 | High | `proc_run1` shell injection from un-escaped `arg` | Provide argv-based variant; document the hazard |
| C1 | High | `__nucleor_mutex_free` missing from manifest | Re-gen manifest; G1 root cause covers it |
| C2 | High | `_Atomic long long` alignment not statically asserted | Add `_Static_assert(_Alignof(_Atomic long long) <= 16)` |
| CO3 | Medium | `hashmap_remove`'s rehash recursion vs grow-during-rebuild | Rebuild without growing; or stash cluster keys/vals before reinsert |
| A6 | Medium | manifest abi rows say `(ptr)` but C is `(long long)` | Align manifest with C; or document equivalence |
| A7 | Medium | `vec_free` proof_obligation is `bounds_within_len` (wrong) | Set to `alloc_capability_or_arena_owned` for all `*_free` |
| V2 | Medium | VectorOps class default `effects=["alloc"]` applied to pure-read members | Per-helper effects override; tighten class default |
| V4 | Medium | `_grow_cap`'s `byte_max` cast assumes 64-bit `size_t` | Add 64-bit `size_t` static assert |
| S5 | Medium | `str_intern_stats` shift 24 vs comment 32 | Fix to 32 / 0xFFFFFFFFLL; add to manifest |
| S6 | Medium | `file_read_string` uses 32-bit `long` for size on Windows | `_ftelli64` / `ftello` |
| S4 | Medium | `proc_capture_with_status` 32-byte header has zero margin | `_Static_assert` on max int64 print width |
| P2 | Medium | `checked_mul_i64` relies on UB-multiply followed by div | Use `__builtin_mul_overflow` / `_mul128` |
| CO1 | Medium | `btreemap_get` inconsistent error policy (null-map silent vs missing-key panic) | Choose one |
| EC1/EC2/EC3 | Medium | Effects-class defaults too broad; proof_obligation wrong on `*_free`; no direct_ffi marker | Add `direct_ffi` field; per-helper effects refresh |
| CC2 | Low | Handle ABI mixed (`long long` vs `NVec*`) | Pick one |
| V3 | Low | `vec_pop` returns void (not the popped element) | Document or extend |
| S7 | Low | `file_append_string` truncates at NUL | Add `file_append_bytes` |
| MM2 | Low | `nuc_alloc.h` macro pollution into downstream headers | `#warning` on include order |
| C3 | Note | Win mutex is recursive, POSIX is not | Add manifest `platform_notes` |
| CC1 | Note | Calling convention default cdecl/SysV; consistent | None |
| MM3 | Note | Singletons assume single-load runtime | Document |
| T1 | Note | 30 unstable rows correctly tagged but no CI gate | Add CI assertion |
| P1 | Note | overflow flag is TLS now; correct | None |
| S8 | Note | int_to_str 32-byte buffer fits LLONG_MIN | None |

**Counts:** Critical 2, High 12, Medium 11, Low 4, Note 7.

---

## 5. What was NOT covered

- **Functional execution of every symbol from `.nr` test code.** Hard
  constraint: no `verify.sh`, no source modification. Static analysis
  only. A full functional sweep belongs in the next pass.
- **Adversarial injection** (invalid pointers / OOB indices /
  double-free attempts). Reasoned-about via code inspection; not
  empirically verified.
- **Cross-language Rust bridge.** Tooling exists
  (`tools/check_rust_bridge_ownership.{sh,ps1}`) — out of scope for
  static recon.
- **GPU paths (`taylor_gpu_rt.cu`, `cuda_rt.cu`).** Sampled for the
  NVec layout divergence (A1) only.
- **Performance / cache-line layout.** Out of scope.
- **The 17-class enumeration in `helper_manifest_schema.md` vs
  in-manifest classification of every row.** Sampled to confirm the
  taxonomy is internally consistent; full diff not produced.

---

## 6. Recommended next steps (no work performed)

1. **A1 first** — single-sourced NVec — closes the largest latent UB
   class with the smallest code change.
2. **G1..G10 + 1.3** — re-pass the helper-manifest generator until
   every public extern in `stdlib/runtime/*.c` is either rowed or
   intentionally excluded with an explicit `internal_only = true`
   field added to the schema. Wire `tools/check_compiler_drift.sh`
   into `verify.sh` so future drift is gated.
3. **1.4** — make the OOM-panic wrappers a real linkable surface so
   third-party adopters of the runtime archive get the contract too.
4. **A3, A4, A5** — close the lenient-OOM NULL-deref class; aligns
   the NUCLEOR_OOM_LENIENT contract with what the code actually does.
5. **S1, S2** — string-literal-vs-heap and thread-safety contract
   cleanup for the const-char* return surface.

---

*End of audit. No source files modified. Scratch in
`audit_scratch_runtime_abi/`. Inventory artefacts:
`runtime_symbols.txt` (776 lines), `manifest_symbols.txt` (875 lines),
`manifest_only.txt` / `manifest_only_real.txt` (orphan rows),
`runtime_only.txt` (regex artefacts + true gaps).*
