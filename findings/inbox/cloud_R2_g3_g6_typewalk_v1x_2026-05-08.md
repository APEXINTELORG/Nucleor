# Cloud R2 — G-3 + G-6 Phase 3 type-walker (v1.x hardening)

**Date:** 2026-05-08
**Branch:** `claude/harden-cloud-agent-r2-03OaM` (harness mandate; user prompt named `claude/v1x-cloud-R2-g3-g6-typewalk` but the harness is the canonical push target)
**Base:** `origin/main @ 7ece32f` (post-Q4 G-11 ACK)
**Host:** Linux vm 6.18.5 x86_64 / clang Ubuntu-18.1.3
**Verify cadence:** `bash tools/verify.sh` (skip strict per brief)

## Mandate

Promote G-3 (heap aliasing through Vec<&T> / HashMap mutation) and G-6
(Sendable closure for HashMap / closure / tuple / enum) from Phase A
audit-pass-warning (build-summary textual count) to real Phase 3 per-fn
analysis in `check_expr`. Six new error codes registered immediately
after `INIT-G11-READ-BEFORE-INIT` in `is_error_code`.

## Codes registered (compiler/nucleor_s1_compiler.nr — `is_error_code`)

Grouped immediately after the existing `INIT-G11-READ-BEFORE-INIT`
registration, in two blocks:

- **G-3 heap-aliasing per-fn analysis:**
  - `ALIAS-G3-VEC-OF-REFS` — `vec_push` / `vec_insert` into a
    `Vec<&T>` binding installs a borrow into a Vec-of-references.
  - `ALIAS-G3-HASHMAP-REHASH` — `hashmap_insert` / `hashmap_remove` /
    `hashmap_clear` while a live shared borrow of the same map
    binding exists.
- **G-6 Sendable per-call-site classification at spawn boundaries
  (`async_spawn` / `thread_spawn` / `conc_spawn`):**
  - `SEND-G6-HASHMAP` — arg type contains `HashMap<` / `Cell<` /
    `RefCell<`.
  - `SEND-G6-CLOSURE-CAPTURE` — closure literal arg whose body
    captures at least one binding from the enclosing fn scope (bare
    parameter-only closures stay clean).
  - `SEND-G6-TUPLE` — arg type starts with `(` and contains a
    non-Sendable element.
  - `SEND-G6-ENUM` — arg type names an enum that has at least one
    variant payload type containing `HashMap<` / `Cell<` /
    `RefCell<`.

## Patch shape (`check_expr` kind-7 — CALL handler)

Two surgical insertions inside the kind-7 block:

1. **Spawn-family classifier (before per-arg loop):** detects
   `thread_spawn` / `async_spawn` / `conc_spawn` callee, walks args,
   and classifies each kind-3 ident arg by declared type shape
   (`Vec<&` strip / tuple-prefix / enum-table walk) plus closure
   literals (kind 42) routed through a recursive capture detector.

2. **G-3 heap-aliasing checks (inside per-arg kind-3 block):** at the
   first arg of `vec_push` / `vec_insert`, fire `ALIAS-G3-VEC-OF-REFS`
   when the binding's declared type contains `Vec<&`. At the first
   arg of `hashmap_insert` / `hashmap_remove` / `hashmap_clear`, fire
   `ALIAS-G3-HASHMAP-REHASH` when `own_has_shared_overlap` reports a
   live shared borrow on the binding.

Two new helpers added before `check_expr`:
- `g6_cparam_has(pool, cparams_lid, name)` — closure-param-list
  membership check (cparams items are name strings per
  `parse_primary` line ~2564).
- `g6_closure_walk_capture(pool, nid, cparams_lid, own)` — recursive
  walker over a closure body. Returns 1 on the first kind-3 ident
  whose name is (a) not in the closure's param list and (b)
  registered as a local binding in the enclosing fn's `own` env (via
  `own_get_type` returning non-empty). Conservative on opaque kinds
  (false-negative; bare-param-only closures stay silent).

The recursive capture-detector was the load-bearing fix for the one
existing-test regression — `tests/runtime/concurrency.nr:124` calls
`conc_spawn(|x| { return x * 2; }, 21)` with a closure that references
only its parameter and must not fire `SEND-G6-CLOSURE-CAPTURE`. With
the walker in place this test stays clean while
`tests/err/err_g6_closure_capture_spawn.nr` (closure body captures
`n` from the enclosing scope) fires correctly.

## Fixtures (10 total)

**Positive lock-in (must compile clean):**
- `tests/features/g3_owned_vec_indices_ok.nr` — `Vec<i64>` of indices
  (recommended adopter mitigation for `Vec<&T>`).
- `tests/features/g3_hashmap_no_live_borrow_ok.nr` — `hashmap_insert`
  with no live shared borrow.
- `tests/features/g6_spawn_primitive_ok.nr` — `async_spawn(worker, n)`
  with a Sendable i64 arg.

**Negative (must fire diagnostic):**
- `tests/err/err_g3_vec_of_refs_push.nr` — `ALIAS-G3-VEC-OF-REFS`
- `tests/err/err_g3_hashmap_rehash_while_borrowed.nr` — `ALIAS-G3-HASHMAP-REHASH`
- `tests/err/err_g6_hashmap_spawn.nr` — `SEND-G6-HASHMAP`
- `tests/err/err_g6_closure_capture_spawn.nr` — `SEND-G6-CLOSURE-CAPTURE`
- `tests/err/err_g6_tuple_with_hashmap_spawn.nr` — `SEND-G6-TUPLE`
- `tests/err/err_g6_enum_with_hashmap_payload_spawn.nr` — `SEND-G6-ENUM`

All ten fixtures verified locally against the patched compiler.

## Validation

`bash tools/verify.sh` post-patch: **PASS=1496 / SKIP=8 / FAIL=3** across
1507 steps.

The 3 fails are all integrator-handled per the brief and not within R2
ownership:

| Step | Reason |
|---|---|
| `compiler ABI tables synced` (step 2) | `tools/audit_dup_fns_report.csv` is stale; brief says **must NOT touch** (integrator regenerates). |
| `T1.7 bootstrap seed matches current compiler` (step 1504) | `bootstrap/nucleor_s1_seed.ll` is in the must-not-touch list; brief says **No seed regen** (integrator regenerates during fast-forward, same pattern as Q1/Q2/Q3/Q4 cherry-picks). |
| `T1.8 self-host compiler IR fixed point` (step 1505) | Same root cause as T1.7 — stage-2 IR != current seed because seed wasn't regenerated. |

**Self-host fixed-point on patched source:** stage-2 IR builds twice
to identical md5 `e21dfffe34c91988f21b096d94a0ea60` (target/s2.ll and
target/s2_round2.ll match byte-for-byte). The seed was last refreshed
at md5 `d9a57138f60db22dc9283d56c87060e9` (Q3+Q4 combined fixed-point,
per Cloud_Control1 entry). Integrator can refresh on cherry-pick.

**Regression check:** verify.sh PASS count moved from 1495 (pre-patch
baseline with my draft check that fired on `tests/runtime/concurrency.nr`)
to 1496 after the capture-detection refinement. No other existing test
regressed. The four pre-existing spawn-call test fixtures
(`err_rfc0035_*`, `err_race_*`, `rfc0007_queue_bench.nr`,
`rfc0007_queue_mpsc.nr`) all still produce the same diagnostics.

## Per-fn vs build-summary

The Phase A textual audit-pass at `compiler/nucleor_s1_compiler.nr`
lines 32509-32827 (`warning[ALIAS-G3]` + `warning[SEND-G6]` +
`warning[SEND-G6-CLOSURE]`) is intentionally retained — those are
build-summary visibility surfaces for adopters who want a count, while
the new per-call-site error codes fire at the actual problematic IR
expression. The two surfaces coexist; neither is reclassified.

## Files touched (within R2 ownership)

- `compiler/nucleor_s1_compiler.nr` — code registration block + 2
  helper fns (`g6_cparam_has`, `g6_closure_walk_capture`) + spawn
  classifier and G-3 checks inserted into kind-7 of `check_expr`.
- `tests/features/g3_owned_vec_indices_ok.nr` (new)
- `tests/features/g3_hashmap_no_live_borrow_ok.nr` (new)
- `tests/features/g6_spawn_primitive_ok.nr` (new)
- `tests/err/err_g3_vec_of_refs_push.nr` (new)
- `tests/err/err_g3_hashmap_rehash_while_borrowed.nr` (new)
- `tests/err/err_g6_hashmap_spawn.nr` (new)
- `tests/err/err_g6_closure_capture_spawn.nr` (new)
- `tests/err/err_g6_tuple_with_hashmap_spawn.nr` (new)
- `tests/err/err_g6_enum_with_hashmap_payload_spawn.nr` (new)
- `findings/inbox/cloud_R2_g3_g6_typewalk_v1x_2026-05-08.md` (this file)
- `Cloud_Control1.md` (R2 ACK entry)

Untouched per brief: `compiler/nucleor_tools_suite.nr`,
`compiler/shared_wave1.nr`, `bootstrap/nucleor_s1_seed.ll`,
`bin/nucleor.exe`, `tools/audit_dup_fns_report.csv`.

## Recommendation

Integrator fast-forward `claude/harden-cloud-agent-r2-03OaM` after
Windows revalidation. Same bootstrap pattern as Q1-Q4: Windows
re-bootstraps from new seed once integrator regenerates +
audit_dup_fns_report.csv refresh. Both per-host re-validations should
go GREEN once the integrator-owned regenerations land.
