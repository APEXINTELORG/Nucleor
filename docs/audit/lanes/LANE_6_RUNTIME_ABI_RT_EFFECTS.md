# Lane 6 — Runtime ABI + RT Enforcement + Effects Wiring

**Branch:** `fix/audit-lane-6-runtime-abi-rt-2026-05-08`
**Theme:** Tighten runtime ABI surface, make RT-attribute enforcement actually transitive, wire SI dimensional checks. The "advertised but not actually wired" cluster.

## In-scope findings

### Critical (3)
- **Layer 7 / A2-related** — Pulled into Lane 2 partially (NVec layout). What remains here: 10 confirmed real public symbols missing from manifest (proc_*, mutex_free, channel_close/_is_closed, vec_u8_extend_from_ptr, str_intern_stats accessor)
- **Layer 8 / F-NUM-002** — `unit_convert_f64` accepts cross-dimensional conversions silently (`Pa→m`, `J→Hz`, etc.). `dim_check_or_panic` exists but never called.
- **Layer 8 / F-NUM-003** — `bit_shift_left/right`, `bit_set/clear/test` invoke C UB on shift count ≥ 64 or < 0

### High (17)
- **Layer 7** — `nuc_alloc.h` OOM-panic build-recipe-dependent (only active in s1 link command)
- **Layer 7** — `__nucleor_str_substring` doesn't validate `end <= strlen(s)` per FFI G-9 trust contract; panic message overpromises "OOB"; `int n = (int)(end-start)` truncation for >2GB ranges
- **Layer 7** — `proc_capture_stdout` thread-safety (global status slot)
- **Layer 7** — `proc_run1` shell-injection (unescaped quotes)
- **Layer 7** — const-char* helpers mix string-literal sentinels with malloc'd buffers (no safe `str_free`)
- **Layer 7** — manifest discovery gaps (10 symbols)
- **Layer 7 / Medium** — `hashmap_remove` rehash recursion can fire grow that invalidates the cluster the loop is iterating
- **Layer 7 / Medium** — Manifest abi `(ptr)` rows vs C signatures `(long long handle)`
- **Layer 7 / Medium** — Class-default `effects=["alloc"]` applied to pure-read VectorOps
- **Layer 7 / Medium** — `proof_obligation="bounds_within_len"` on `vec_free` (wrong)
- **Layer 7 / Medium** — `__nucleor_str_intern_stats` packs `<<24` but comment says `<<32` (silent truncation at 16M)
- **Layer 5 / F-CONC-003** — `#[deadline = N]` is post-hoc compare, not HW-timer trap. RFC-0001 §3.2.4 promises mid-execution enforcement; v1.0 only detects.
- **Layer 5 / F-CONC-004** — RT-attribute substring scanner misses Vec::with_capacity, Box::new, array OOB v.get(i), fn-pointer call, helper-chain depth >8, FFI without #[ffi_no_*]
- **Layer 5 / F-CONC-005** — `#[atomic]` and `#[isr]` blocking-call detection single-hop; trivial wrapper `conc_lock` bypasses
- **Layer 4 (cross-cutting)** — Effects opt-in cliff: source with no `#[effect]` annotations silently disables G-9/G-10/G-5/G-7. **Coordinated with Lane 2 — Lane 2 owns the gate fix; Lane 6 owns wiring the framework into the runtime ABI manifest cleanly.**

## Source-of-truth findings docs
- `docs/audit/findings/audit_recon_pass1_runtime_abi_2026-05-08.md`
- `docs/audit/findings/audit_recon_pass1_concurrency_2026-05-08.md` (F-CONC-003/004/005)
- `docs/audit/findings/audit_recon_pass1_numeric_2026-05-08.md` (F-NUM-002, F-NUM-003)

## Strategy

### Runtime ABI hygiene
1. **Manifest gaps.** Add 10 missing rows. Audit the `effects=` and `proof_obligation=` columns for accuracy across the manifest.
2. **`vec_free` `proof_obligation`.** Remove `bounds_within_len` (wrong); replace with appropriate value (likely `none` or `frees`).
3. **VectorOps `effects=["alloc"]` class default.** Override on pure-read members (e.g., `vec_len`, `vec_get`, `vec_capacity`).
4. **`(ptr)` vs `(long long handle)`.** Pick one — likely `handle` since that's the actual ABI. Update manifest globally.
5. **str_intern_stats packing.** Fix the `<<24` to `<<32` (or add an explicit cap with diagnostic at 16M).
6. **`nuc_alloc.h` OOM-panic standalone.** Make the OOM-panic behavior the default of `__nucleor_alloc` itself, not dependent on `-include`. Adopters using `libnucleor_runtime.a` standalone should get the documented behavior.
7. **`str_substring` validation.** Add real `end <= strlen(s)` check; emit `STR-SUBSTR-OOB` for actual OOB. Fix the int truncation by using `size_t`.
8. **`proc_capture_stdout` thread-safety.** Replace global status slot with a per-call return struct OR a thread-local.
9. **`proc_run1` shell-injection.** Quote-escape all arguments; document the contract.
10. **Const-char* helpers.** Standardize: either always-malloc'd (with documented `str_free`) or always-borrowed (no free required). Pick a side and audit.
11. **`hashmap_remove` rehash safety.** Don't rehash inside the iteration loop; defer.

### RT-attribute enforcement
12. **Deadline mid-execution.** v1.0 ships post-hoc detection. Either: (a) implement a HW-timer / signal-based mid-execution trap, OR (b) downgrade RFC-0001 §3.2.4's promise to "best-effort post-hoc detection" and update README. **Recommend (b) for v1.0.x; (a) as v1.1 work.** Document the actual semantics clearly.
13. **RT scanner full coverage.** Replace substring scanner with a proper expression walk that catches `Vec::with_capacity`, `Box::new`, `v.get(i)` (which is OOB-trappable), fn-pointer calls (must be `#[no_alloc]`-attributed too), helper-chain depth (no fixed cap; transitive analysis), FFI calls (must have `#[ffi_no_*]` allow).
14. **Atomic/ISR transitive detection.** Replace single-hop check with a proper transitive call-graph walk. Mark functions that transitively call blocking ops; reject `#[atomic]`/`#[isr]` callers of those.

### SI dimensional analysis wiring
15. **`unit_convert_f64` dim check.** Wire `dim_check_or_panic` (or a non-panicking variant) into the conversion path. Cross-dimensional conversion → `UNIT-DIM-001: incompatible dimensions <Pa> → <m>`.

### Bit operations safety
16. **Shift count bounds.** Each of `bit_shift_left/right`, `bit_set/clear/test` checks `0 <= count < 64`. Out of range: either (a) emit a runtime panic, OR (b) return saturated value. (a) is more in keeping with the safety story.

## Test mandate

- For every fix, a positive `tests/rods/<topic>_legit.nr` and a negative `tests/err/<topic>_violates.nr`
- For RT scanner: each previously-missed shape (Vec::with_capacity etc.) has a test in `tests/err/rt_scanner_<shape>.nr`
- For deadline: a test that runs longer than the deadline and verifies the diagnostic fires (with documented post-hoc semantics)
- For SI: `tests/err/units_cross_dim.nr` exercises Pa→m and verifies UNIT-DIM-001 fires

## Verify policy

Run `bash tools/verify.sh` ONCE at end. Some changes touch the runtime ABI manifest — verify that helper-manifest-check still passes.

## Hard constraints

- Coordinate with Lane 2 on effects framework (Lane 2 owns gate logic, Lane 6 owns runtime-side wiring).
- Coordinate with Lane 5 on `direct_ffi` enforcement upgrade if scope overlaps.
- For deadline (item 12), pick option (b) for v1.0.x — full mid-execution trap is v1.1+.

## Output

- Branch + report `docs/audit/lanes/LANE_6_REPORT.md`.
