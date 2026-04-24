# Compiler Memory Architecture Punchlist

**Goal:** s1 self-host compile uses < 500 MB peak RSS (originally 19 GB).
tools_suite < 1 GB peak RSS.
Architectural fix, not patches.

## Status as of v0.2.167 (2026-04-23 evening)

- **s1 self-host: 67 MB tracked / ~100 MB peak RSS** (was 19 GB → **283× reduction**)
- **Compile time: 5.2 s** (was 25 s → **5× speedup**)
- **Gate budget: 100 MB enforced** (3 ratchets so far: 400 → 250 → 100 MB)
- **Verify gate: 248/248 PASS** (was 245)

## Items shipped this session (14 ships)

- Ship 1 (v0.2.158): infrastructure + counters + format builtins + vec_free
- Ship 2 part 1 (v0.2.159): str_eq_at — 52× memory drop (9.7 GB → 185 MB)
- Ship 2 part 2 (v0.2.160): anti-pattern fully purged (13 cold-path conversions)
- Ship 5 (v0.2.161): 400 MB peak-allocation budget gate
- Polish (v0.2.162): SECURITY.md + README refresh
- Ship 6 (v0.2.163): env-snapshot UAF bisected; type-pass frees safe
- RFC-0029 (v0.2.164): str_intern builtin (identifier interner)
- RFC-0030 phase 1 (v0.2.165): string arena (5 builtins)
- RFC-0030 phase 2 (v0.2.166): SB initial cap 4096→256 (185→137 MB, -49 MB)
- RFC-0030 phase 3 (v0.2.167): Vec initial cap 16→4 (137→67 MB, -70 MB)
- Docs (v0.2.168): docs/memory-architecture.md case-study
- RFC-0030 phase 4 (v0.2.169): str_free builtin (foundation for explicit-free)
- Docs (v0.2.170): docs/release-notes-v0.2.x-memory.md summary
- Ship 7 (v0.2.171): tools-suite memory budget gate (was ungated; 111 MB baseline / 200 MB budget)

**Date started:** 2026-04-23
**Repo:** `C:\Users\JoeWe\Desktop\Nucleor_OSS`
**Baseline trace (before fixes):**
```
vec_new:         798K calls   119 MB
str_concat:      598K calls     4 MB
str_substring:   582M calls   9.5 GB  ← dominant leak
sb_new:           13K calls    60 MB
peak RSS:                       19 GB
```

## Bootstrap workflow for every compiler change

This is the s1 self-host bootstrap. Don't skip it.

```bash
cd /c/Users/JoeWe/Desktop/Nucleor_OSS
export PATH="/c/Program Files/LLVM/bin:$PATH"

# 1. Edit compiler/nucleor_s1_compiler.nr (and tools_suite if ABI changed)
# 2. Pass 1 — build with current bin/nucleor.exe (no calls to NEW builtins yet)
rm -rf .nuc_cache 2>/dev/null
bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_pNEW --no-cache
cp target/nucleor_pNEW.exe bin/nucleor.exe

# 3. Pass 2 — re-build with new binary, now WITH calls to new builtins
rm -rf .nuc_cache 2>/dev/null
bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_pNEW2 --no-cache
cp target/nucleor_pNEW2.exe bin/nucleor.exe

# 4. Verify byte-identical fixed point (iter 2 vs iter 3)
bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_pNEW3 --no-cache
diff -q target/nucleor_pNEW2.ll target/nucleor_pNEW3.ll  # must say identical

# 5. Trace
NUC_TRACE_ALLOC=1 bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o /tmp/trace --no-cache 2>&1 | grep TRACE -A 8

# 6. Run gate (only when changes are stable)
bash tools/verify.sh
```

## Items — ordered by leverage

### A. INSTRUMENT (do first; everything depends on this)
- [x] Allocation counters in nucleor_llvm_rt.c (vec_new, str_concat, str_substring, sb_new, misc_str)
- [ ] **A1. Per-site allocation tracking via stack-frame name** — instead of one global `g_str_substring_count`, key by caller fn name. Need a thread-local "current fn" in the runtime that the s1 sets via a builtin call at fn entry. Design: add `__nucleor_alloc_site_enter(const char*)` / `__nucleor_alloc_site_leave()`. Compiler emits these around hot fns we want to attribute to. Print top-10 sites at exit.

### B. ARCHITECTURAL — TypeId interner (the main fix)
- [ ] **B1. TypeId design.** Add a global type interner: `(string -> TypeId)` and `(TypeId -> string)`. TypeId is i64. Equal types share an ID. Lookup is O(string-length) once per unique type, then O(1) for all subsequent comparisons. Implementation: hash table keyed by string, returns interned ID. Backed by a single Vec<str>.
- [ ] **B2. Type interner runtime.** Add to nucleor_llvm_rt.c: `__nucleor_type_intern(const char *)` returns i64 ID. `__nucleor_type_str(i64)` returns string for diagnostics. Memory: bounded by # unique types (~hundreds for s1). Vs current: thousands of duplicate type strings allocated per call.
- [ ] **B3. Compiler builtin wiring.** Add `type_intern(s: str) -> i64` and `type_str(id: i64) -> str` to s1 + tools_suite ABI tables (4 sites each).
- [ ] **B4. Convert env storage from str to TypeId.** `own` and `env` Vecs currently store (name, type-string) pairs. Change to (name, TypeId) pairs. Every read/write of a type goes through intern/extract. ~50 call sites in s1.
- [ ] **B5. Convert types_compatible to TypeId.** Cache compatibility results: `(TypeId, TypeId) -> bool` table. Most pairs are seen many times during type-check.
- [ ] **B6. Convert type_base_name, taint_inner_type, type_is_unit, etc.** to operate on TypeId where possible. Some still need strings (e.g. for diagnostic emission); use `type_str(id)` then.

### C. STRING INTERNER (parallel work, smaller scope)
- [ ] **C1. Identifier interner runtime.** Same shape as TypeId but for identifiers (variable names, fn names, struct fields). `__nucleor_str_intern(const char *) -> ptr`. Returns canonical pointer.
- [ ] **C2. Use interner in lex.** When lex builds an identifier token, intern it. The token's `name` field becomes the interned pointer. All later string comparisons against keywords, fn names, etc. become pointer comparisons.

### D. PER-COMPILE ARENA (cleanup pass)
- [ ] **D1. Arena scoped to one compile.** At top of `compile_file_mode`, create a 64 MB arena. All transient strings (str_concat results, str_substring results in non-hot paths) allocate from the arena. Free arena at end of compile.
- [ ] **D2. Wire arena into str_concat / str_substring / int_to_str.** New runtime: `__nucleor_arena_str_concat(arena, a, b)`. Compiler uses arena variants in chosen paths. Existing global str_concat stays for backward-compat.

### E. INCREMENTAL WINS (lower leverage, can ship anytime)
- [x] vec_free builtin
- [x] env-snapshot frees in own_restore + own_merge_moved + 3 type-pass sites
- [x] non-allocating str_starts_with
- [x] type_base_name conversion to use new str_starts_with
- [x] is_tainted_type, taint_inner_type, type_is_unit conversions
- [x] strip_spaces fast path
- [ ] **E1. Audit all `str_eq(str_substring(..., 0, N), literal)` patterns and convert to str_starts_with.** Saves a substring + an allocation per call. Dozens of sites.
- [ ] **E2. Free format-result strings.** `format_*` builtins return malloc'd strings used once and discarded. Sites that print them and don't reuse: `print(format_i64(...))` should free after print. Add `print_owned` builtin that prints + frees.
- [ ] **E3. SB cleanup.** `sb_to_str` returns the data ptr but never frees it. Add explicit `str_free` call at consumer sites.

### F. BUDGETS + GATES (lock in the wins)
- [ ] **F1. Add a peak-RSS test to the gate.** Runs the s1 self-host with `NUC_TRACE_ALLOC=1`, asserts total tracked < 500 MB.
- [ ] **F2. Document the memory budget in CHANGELOG + spec.** "Compile of N KB source must use < N*M memory."

### G. SHIP / RELEASE
- [ ] **G1. Ship v0.2.158 with E items + A counters.** Commit + tag.
- [ ] **G2. Ship v0.2.159 with B + C (the big architectural fix).**
- [ ] **G3. Ship v0.2.160 with D arena.**
- [ ] **G4. Ship v0.2.161 with F gates.**

## Iteration log (append per ship)

### Ship 1 — v0.2.158 (E items + A counters + vec_free infrastructure)

**Shipped:**
- nucleor_llvm_rt.c: vec_new + str_concat + str_substring + sb counters
  (NUC_TRACE_ALLOC=1)
- nucleor_llvm_rt.c: __nucleor_vec_free + __nucleor_str_free (always-linked)
- s1: vec_free builtin (4 ABI sites)
- tools_suite: same (mirrors)
- s1: str_starts_with non-allocating
- s1: type_base_name uses str_starts_with for prefix probes
- s1: is_tainted_type / taint_inner_type / type_is_unit converted
- s1: strip_spaces fast path
- nucleor_llvm_rt.c: 3 new format builtins (format2_fi, format2_if, format3_fff)
- s1 + tools_suite: ABI for the 3 new format builtins
- tests/lang/format_mixed_combos.nr

**Reverted from initial Ship 1 attempt** (caused use-after-free crashes
in tests with match/enum/if-let):
- vec_free(snap) in own_restore
- vec_free(a) / vec_free(b) in own_merge_moved
- vec_free(then_env) / vec_free(else_env) / vec_free(arm_env) in
  type_check_stmts
The vec_free BUILTIN is shipped; the CALLS are not. Reason for the
crash: somewhere downstream of these snapshots, the type checker
captures string pointers that point INTO the snapshot Vec's storage.
Freeing the Vec drops the strings, then a later read crashes. Need
to identify the cross-reference (likely `tenv_get` or similar
returning interior strings) and either (a) clone strings into a
stable arena before storing in env, or (b) use refcounting. Tracked
as new item E4 below.

**Memory measurement (post-Ship 1):**
- Trace: still 9.7 GB tracked. Ship 1 was infrastructure +
  non-allocating-string-probes (small wins). The dominant
  582M str_substring leak is in `type_expr` + related; needs
  Ship 2 (TypeId interner) for the architectural drop.

### Items added during Ship 1

- [ ] **E4. Audit env interior-string lifetime.** When `own_snapshot`
  copies env entries (which are i64-encoded str ptrs), the string
  data is shared between original and snapshot. Freeing the snapshot
  doesn't free strings. Yet crashes happen — meaning some downstream
  reader reads BACK into the snapshot Vec's data array, not the
  strings. Identify the leak source (probably env_get returning
  positional ptr) and fix before re-enabling vec_free calls.

### Ship 2 — TBD (B: TypeId interner)
### Ship 3 — TBD (C: identifier interner)
### Ship 4 — TBD (D: per-compile arena)
### Ship 5 — TBD (F: gate budget enforcement)

### Ship 2 — TBD (B: TypeId interner)
### Ship 3 — TBD (C: identifier interner)
### Ship 4 — TBD (D: per-compile arena)
### Ship 5 — TBD (F: gate budget enforcement)
