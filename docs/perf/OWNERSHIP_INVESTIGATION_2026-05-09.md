# Ownership Phase Perf Investigation — 2026-05-09

**Worktree:** `C:\Users\JoeWe\Desktop\Nucleor_perf_ownership`
**Branch:** `perf/ownership-investigation-2026-05-09` (off `7e48e9db` audit-complete v1.1.0)

## Baseline (this Windows machine, cold, no-cache, --time-passes)

| Phase | Time | vs v1.0.0 baseline (Linux figures from CHANGELOG) |
|---|---|---|
| resolve_source | 47 ms | (was 141 ms; now better) |
| lex | 47 ms | (was 62 ms; now better) |
| parse | 93 ms | (n/a) |
| **ownership** | **1609 ms** | **1062 ms baseline → 1.5×** |
| type | 500 ms | (was 763 ms; now better) |
| lower | 157 ms | |
| opt | 62 ms | |
| emit | 141 ms | (was 191 ms; now better) |
| total IR emit | 2844 ms | |
| clang | 1187 ms | |
| **total native** | **4094 ms** | |

Ownership is the dominant non-clang phase. Closing it to baseline would put total native ~3500 ms — comfortable sub-4s.

## Hot path analysis

The four functions on the path:

```
sym_get(s, name)                     compiler/nucleor_s1_compiler.nr:10416
own_put_i(o, key, val)               compiler/nucleor_s1_compiler.nr:21254
own_get_i(o, key) / own_get_s(...)   compiler/nucleor_s1_compiler.nr:21318+
own_merge_state_key(o, a, b, key, va, vb)  compiler/nucleor_s1_compiler.nr:21779
own_merge_moved(o, a, b)             compiler/nucleor_s1_compiler.nr:21842
```

### Algorithm shape

`own_merge_moved(o, a, b)` runs at every if/else (and match-arm) join during ownership analysis. It does:

1. **Loop over `a`'s key/value pairs** (length nA pairs):
   - For each key: `sym_get(b, key)` — O(nB) backward linear scan when `nB < 64` (the size-gated warm-hashmap kicks in only above that threshold)
   - Then `own_merge_state_key(o, a, b, key, va, vb)` which calls `own_put_i(o, key, val)` — another O(nO) backward linear scan
2. **Loop over `b`'s key/value pairs** (length nB pairs):
   - For each key: `sym_get(a, bkey)` — O(nA) backward linear scan
   - Then more `own_put_i(o, ...)` — O(nO) per call

**Net per merge:** O((nA + nB) × (nA + nB + nO)) — quadratic in env size.

### Why ownership got slower in v1.1.0

The audit-pass-1 work expanded the per-variable state vocabulary:
- G-4 `__g4_freed_*` + `__g4_freed_by_*` keys
- G-4 `__g4_root_*` alias keys
- G-8 `__g8_cond_moved_*` keys
- G-11 `__init_*` + `__init_seen_*` keys
- Plus the original `__os_*` (ownership state) and `__ot_*` (ownership type)

So per Nucleor variable, the env now stores **~6-8 keys** instead of v1.0.0's ~2. Every merge iterates more keys; every key lookup does a longer linear scan. Quadratic blow-up.

### sym_get's size-gated warm hashmap

```nr
fn sym_get(s, name) {
    ...
    if n < 64 {
        // linear backward scan
    };
    // warm hashmap path: __nucleor_sym_aux_create + insert + lookup
}
```

Threshold 64 entries = 32 pairs. Most arm-local envs at merge time are below this — so they hit linear scan. The warm hashmap exists but is gated out for the typical merge case.

### Existing C-side aux machinery

Already shipped:
- `__nucleor_sym_aux_create(handle)` — get-or-build warm hashmap for a single sym handle
- `__nucleor_sym_aux_get(handle)` — return warm handle if `s` matches the currently-warm sym
- `__nucleor_sym_aux_built_at(handle)` / `_set_built_at` — incremental rebuild marker

The aux machinery only caches ONE warm sym at a time. At merge time, `sym_get(a, ...)` and `sym_get(b, ...)` thrash the warm cache because only one of them can be warm at a time.

## Optimization opportunities (ranked by impact-per-effort)

### Opt-1 — Pre-build a key-index hashmap for `b` once per merge call

**Cost change:** O((nA + nB) × nB) → O((nA + nB)) for the b-side lookups.

**Implementation:**
```nr
fn own_merge_moved(o, a, b) {
    // Pre-build a temporary hashmap of b's keys (or use the warm aux if b is large enough)
    let b_idx: i64 = __nucleor_hashmap_new();
    let mut bi: i64 = 0;
    while bi < vec_len(b) {
        __nucleor_hashmap_insert(b_idx, vec_get(b, bi), vec_get(b, bi + 1));
        bi = bi + 2;
    };
    // Loop a, look up b in O(1)
    let mut i: i64 = 0;
    while i < vec_len(a) {
        let key: str = vec_get(a, i);
        let vb: i64 = __nucleor_hashmap_get_or(b_idx, key, 0 - 1);  // sentinel for "not in b"
        own_merge_state_key(o, a, b, key, vec_get(a, i + 1), vb);
        i = i + 2;
    };
    // Same trick for the a-side iteration in the second loop
    ...
    __nucleor_hashmap_free(b_idx);
}
```

**Risk:** low. Algorithm-preserving. Adds two hashmap allocations per merge call. For very small envs the overhead may not pay off — guard with `if vec_len(b) > 8 { ... } else { existing path }`.

**Estimated payoff:** 2-5× speedup on merge per the algorithmic analysis. Could shave 600-1000 ms off ownership phase if merges dominate.

### Opt-2 — Lower sym_get warm-threshold from 64 to 16 (or 8)

**Cost change:** sym_get goes from linear O(N) to hashmap O(1) at lower env sizes.

**Implementation:** one-line change in sym_get.

**Risk:** medium. The 64 threshold was chosen to balance hashmap rebuild cost vs scan cost. Lowering may make small fns slower if they have few sym lookups. Should A/B measure.

**Estimated payoff:** modest unless combined with Opt-1. The thrash issue (only one sym cached) limits gains.

### Opt-3 — Multi-sym warm aux

**Cost change:** Currently `__nucleor_sym_aux_create(s)` reuses one global warm slot. At merge time, `sym_get(a, ...)` and `sym_get(b, ...)` ping-pong-evict each other. A K-way LRU cache (K=4 or K=8) keeps both `a` and `b` warm, letting both linear-scan thresholds be lowered.

**Implementation:** runtime change to `nucleor_llvm_rt.c` — promote the single-slot cache to an array indexed by sym handle hash. Adds ~30 lines of C.

**Risk:** medium. Change to runtime data structure. Bootstrap chain: needs declare propagated through emit_externs (not a new symbol — same `__nucleor_sym_aux_*` names — should bootstrap cleanly if signatures don't change).

**Estimated payoff:** 1.5-3× on sym_get-dominated paths.

### Opt-4 — Resurrect the abandoned `__nucleor_vec_find_str_pair_back` C helper

**Cost change:** `own_put_i`'s backward linear scan moves from .nr-source `while` loop with per-iteration `str_eq` to a single C call that does memcmp-style comparison at native speed.

**Implementation:** add ~20 lines to `nucleor_llvm_rt.c`:
```c
long long __nucleor_vec_find_str_pair_back(NVec *v, const char *key) {
    if (!v) return -1;
    long long n = v->len;
    long long i = n - 2;
    size_t klen = strlen(key);
    while (i >= 0) {
        const char *vk = (const char *)v->data[i];
        if (vk && strlen(vk) == klen && memcmp(vk, key, klen) == 0) return i;
        i -= 2;
    }
    return -1;
}
```

Then in `own_put_i`:
```nr
fn own_put_i(o, key, val) {
    let i: i64 = __nucleor_vec_find_str_pair_back(o, key);
    if i >= 0 {
        vec_set(o, i + 1, val);
        let h: i64 = __nucleor_sym_aux_get(o);
        if h > 0 { __nucleor_hashmap_insert(h, key, val); };
        return 0;
    };
    o.push(key);
    o.push(val);
    return 0;
}
```

**Risk:** medium-high. The v1.0.3 attempt was abandoned because the bootstrap seed didn't have the declare. Needs:
1. Add the helper to runtime.
2. Add the declare to emit_externs.
3. First bootstrap iteration produces seed without declare, but with call site → unlinkable.
4. Workaround: ship in two stages — first a stage-1 that adds emit_externs but doesn't yet call it; then a stage-2 that uses it once the seed is updated.

OR: use the same IR-patch-and-link technique I used to bootstrap the perf-fix branch (manually inject the declare into the stage-1 IR before clang link).

**Estimated payoff:** 2-3× on `own_put_i` calls (which fire 10s of thousands of times in compiler self-source).

### Opt-5 — Cache key-prefix string concats

`own_set_i(o, key, val)` calls `str_concat("__oi_", key)` per call. Per merge, hundreds of concats. Each allocates a fresh string.

**Implementation:** intern the prefix-key combination once per source compile. Or pass pre-prefixed keys through.

**Risk:** low. But also lower payoff than Opts 1-4.

**Estimated payoff:** small (< 100 ms). String allocator is already fast.

### Opt-6 — Merge into a single traversal (algorithm restructure)

The current code does loop-over-a then loop-over-b. With a pre-built b-index (Opt-1), the b-second-loop becomes a check for "keys in b not in a" — could be optimized further by tracking which b-keys were touched in the first loop and only iterating untouched in the second loop.

**Risk:** low if Opt-1 is in place.

**Estimated payoff:** marginal on top of Opt-1.

## Recommended sequence

1. **Opt-1 first** (lowest risk, highest expected payoff). Implement, measure ownership phase, record delta.
2. If Opt-1 alone gets ownership to ~1100 ms, ship it. Done.
3. If still over baseline, layer Opt-3 (multi-sym warm aux) — independent change.
4. Opt-4 (C helper) only if Opts 1+3 don't close the gap. The bootstrap-chain workaround is real but documented.
5. Opts 2/5/6 are cleanup; defer unless needed.

## What I haven't done in this investigation

- Actual profiling with finer-grained timings inside `own_merge_moved` (would need to add `__nucleor_now_ms()` calls and re-bootstrap). The algorithmic analysis is from reading code only.
- Counting exactly how many merges happen during a self-host compile. Could be added with a global counter increment in own_merge_moved.
- Measuring the warm-hashmap rebuild cost vs the linear-scan cost at threshold 64. Could be wrong about Opt-2.

These would tighten the estimates but not change the rank order. Opt-1 is the obvious first move.

## Experiment results (2026-05-09)

### Opt-1 attempt: pre-build hashmap of `b` per merge

Implemented exactly as proposed. Added a tiny-env guard (`< 16 entries each`) to skip the optimization for small merges where the hashmap setup cost would exceed the linear-scan savings.

**Result: REGRESSED.**

| Metric | Baseline | Opt-1 | Delta |
|---|---|---|---|
| ownership | 1594 ms | **2328 ms** | +734 ms (-46% slower) |
| type | 469 ms | 1000 ms | +531 ms |
| total IR | 2766 ms | 4625 ms | +1859 ms |
| total native | 4031 ms | 5843 ms | +1812 ms |

Hashmap allocation overhead per merge (~100µs × thousands of merge calls) exceeds the per-merge savings. The 16-entry threshold guard was insufficient — most env sizes at merge time fall in the 20-200 range where the linear scan is still faster than hashmap_with_capacity + N inserts + N lookups + free.

Cross-reference: the v0.4.3 design comment in `nucleor_llvm_rt.c:6280` documents that an earlier per-sym hashmap experiment (Phase B v0.3.237) was reverted in the same release for a 1.8× peak-memory regression. The single warm-cache slot was deliberate — to avoid exactly this allocation thrash.

### Opt-4 attempt: C helper `__nucleor_vec_find_str_pair_back`

Added the C runtime helper, registered name in `get_rt_name` + `is_runtime_extern`, added `emit_externs` declare. Did NOT yet replace any call sites — purely registration-side changes to validate the bootstrap chain works.

**Result: ALSO REGRESSED, before any call site change.**

| Metric | Baseline | Registration-only | Delta |
|---|---|---|---|
| ownership | 1594 ms | **2282 ms** | +688 ms |
| type | 469 ms | 984 ms | +515 ms |
| total IR | 2766 ms | 4594 ms | +1828 ms |

Source diff was 5 lines (1× declare in emit_externs, 1× get_rt_name entry, 1× is_runtime_extern entry, 1× is_vec_arg-at-idx-0 entry, 1× helper definition in C). 3 measurement runs each, very stable.

**Diagnosis:** adding ONE entry to the known-extern lookup tables (sequential `if str_eq(...)` chains) adds work × N where N = number of call-site lookups during compile. The compiler's own type/ownership phases iterate these lookups thousands of times. Each new entry adds ~N str_eq calls. The cumulative cost is non-trivial.

Plus: when a new extern is registered, the type-checker's per-call validation does additional work (likely arg-shape checking via `is_vec_arg`-style fns).

The v1.0.3 author's note ("a C-side `__nucleor_vec_find_str_pair_back` helper was prototyped but abandoned for v1.0.3") may have hit the same wall: the bootstrap chain works, but the registration side-cost erases the speedup before any call site is even modified.

### Updated rank: what should be tried next

1. **NOT Opt-1** — hashmap-per-merge does not pay off at typical env sizes; matches the v0.4.3 design comment.
2. **NOT naive Opt-4 either** — adding a new extern via the standard `get_rt_name` / `is_runtime_extern` chains pays a side-cost that exceeds the saved work in `own_put_i`.
3. **NOT Opt-3 either** — see Opt-3 result below.
4. **Investigate the registration side-cost.** Why does adding ONE entry to `get_rt_name` slow ownership/type by ~500 ms each? If the lookup tables can be converted from sequential `if str_eq` chains to a hashmap or trie keyed on name, that's a separate one-time win that benefits all future extern additions.
5. **Lex-time intern-and-deduplicate the state-key prefixes** (`__os_`, `__oi_`, `__g4_*`, `__g8_*`, `__init_*`). Currently every `own_set_i(o, key, val)` calls `str_concat("__oi_", key)` per call, allocating a fresh string. Prefix-interned keys would skip the alloc.

### Opt-3 attempt: K-way LRU warm-aux

Replaced the single-slot warm cache in `nucleor_llvm_rt.c` (`g_sym_warm_handle` / `g_sym_warm_aux` / `g_sym_warm_built_at`) with a 4-way LRU. API-compatible: same four `__nucleor_sym_aux_*` functions, just internal storage promoted to a 4-slot array with monotonic-tick LRU eviction. Pure C runtime change — no Nucleor source edits, no extern registration changes (so no side-cost).

**Result: REGRESSED.**

| Metric | Baseline | Opt-3 | Delta |
|---|---|---|---|
| ownership | 1579 ms | 2287 ms (avg of 3) | +708 ms |
| total IR | 2766 ms | 4573 ms | +1807 ms |
| total native | 4031 ms | 5807 ms | +1776 ms |

**Diagnosis:** the warm-aux isn't actually on the hot path. `sym_get`'s warm hashmap branch is gated by `n >= 64`, so for typical small ownership envs (the common case), the warm path is never taken — sym_get linear-scans regardless. The warm-aux call inside `own_put_i` (post-loop, side-effect to maintain cache consistency) fires thousands of times per ownership phase. K-way LRU costs 3-4× more per call than single-slot (4 handle compares + LRU tick update vs 1 handle compare). Multiplied by thousands of callers, the side-cost erases any unrealized benefit.

The single-slot design was deliberate: for the small-env common case where warm-aux isn't taken, single-slot minimizes the per-call check overhead.

### Three negative results — what's left

After Opt-1, Opt-3, and the registration-side test for Opt-4 all regressed, the structural problem becomes clearer:

The ownership phase's slowness is in the .nr-source linear backward scan loop in `own_put_i` doing `str_eq(vec_get(o, i), key)` per iteration. Optimizing it requires either:

(a) Making the per-iteration `str_eq` cheaper without changing the call surface — e.g., the strings are unique-interned (str_intern), so identical strings would have identical i64 pointer values; pointer comparison via `vec_get(o, i) == key` (no str_eq runtime call) might short-circuit most lookups. Worth investigating whether the keys passed in are always intern'd or whether some path passes a freshly-allocated str.

(b) A C helper that does the scan natively — but the standard registration path adds enough side-cost in the compiler's lookup tables (per Opt-4) that the helper's per-call savings get erased. Would need to either:
   - Optimize the lookup-table chains first (Opts-4 + 5 above) and THEN add a C helper.
   - OR find a way to add a C extern that bypasses `get_rt_name` / `is_runtime_extern` (e.g., direct `__nucleor_*` call from source via a special-case path).

(c) Reduce the FREQUENCY of own_put_i calls — not the per-call cost. Each `own_set_i / own_set_s / own_set / own_set_type` call can multiply through state-prefix concat. If state-prefix concat results were cached or interned per fn-body, fewer own_put_i calls would be needed.

(d) Out-of-scope architecturally: replace the flat-Vec ownership env with a different data structure (proper hashmap, indexed b-tree). Would require a substantial refactor of all `sym_get` / `own_put_i` / `own_get_i` / `own_merge_moved` callsites.

The branch state preserves all three failed experiments. Each negative result rules out a class of attempts and narrows the remaining design space.

---

## 2026-05-09 evening: WIN STACK

After the negative results above, the breakthrough came from running the
runtime profile counters (`NUCLEOR_PROFILE=1` + `NUCLEOR_PROFILE_CALLERS=1`)
which revealed:

- 300M `str_eq` calls + 280M `vec_get` calls per cold compile — quadratic
- ONE call site (`own_put_i`'s backward scan) accounted for **70% of both**

This made the diagnosis concrete: the per-iteration .nr->C FFI dispatch
(vec_get + str_eq, two roundtrips per loop iter) was the dominant cost.

### Win 1: hoist sym_get scan into C  (commit 570a297b)
Added `__nucleor_sym_linear_lookup(v, name)` runtime helper that does
the entire backward scan inline in C with pointer-eq fast-path before
strcmp. Used in sym_get's small-vec path and own_put_i.

### Win 2: collapse sym_get tail check  (commit 4eb87ffd)
The pre-fix `if n >= 2 && str_eq(...)` tail check was redundant — the
helper already scans backward from tail. Simplification + 1 less FFI/call.

### Win 3: full own_put_i in C  (commit bed4eb0d)
Pushed all of own_put_i's body into `__nucleor_own_put_i_full`: scan +
mutate-or-push + warm-aux sync. Pre-fix paid 3-5 FFI calls per put;
now one call.

**Profile delta after Wins 1-3:**
- vec_get  282M -> 64M  (-77%)
- str_eq   300M -> 83M  (-72%)
- TOTAL TRACKED 663M -> 227M (-66%)

### Win 4: precompiled rt.o cache  (commit 4083bf24)
Cache `nucleor_llvm_rt.c` -> .obj keyed on content hash. Saves the
~1.1s of clang recompiling the runtime on every link. First build
warms the cache; later builds skip straight to linking.

### Cumulative wins (cold compile, --release --no-cache)
| Metric | branch start (8cc0c38e) | now (4083bf24) | delta |
|---|---|---|---|
| ownership | 1422 ms | 1031 ms | **-28%** (matches v1.0.0 baseline 1062) |
| total IR | 2625 ms | 2294 ms | -13% |
| total native (--release) | ~8900 ms | ~7400 ms | -17% |
| **total native (default opt)** | n/a | **3156 ms** | **sub-4s** |

### The "sub-4s like v1.0.0" framing

v1.0.0's `--release` flag was a no-op — pre-v1.0.1 the link command
passed no `-O` flag at all, so clang defaulted to **-O0**. The "v1.0.0
4-second cold compile" was at -O0.

v1.0.1+ made `--release` semantically meaningful (-O3). That's the
correct semantic — release builds should be optimized — but the link
gets ~5x slower because clang -O3 of 13 MB IR takes ~5 sec.

After this branch's wins:
- Default opt cold compile: **3156 ms** (matches v1.0.0 territory)
- --release (-O3) cold compile: ~7400 ms (intrinsic clang -O3 cost)

The ownership-phase regression is fully closed. The -O3 cold link cost
is structural — closing it would require either smaller IR or splitting
the .ll into modules for parallel/incremental clang invocations.

