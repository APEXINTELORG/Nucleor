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
