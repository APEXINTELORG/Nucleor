# Cloud Agent — Nucleor v1.x Hardening R4 Brief

**Issued:** 2026-05-08
**Issuer:** main integrator (Windows)
**Base:** `origin/main` post-R1+R2+R3 integration (pull main before starting; integrator confirms via `Cloud_Control1.md` ACK entry that all three predecessor units landed)
**Companion to:** `CLOUD_AGENT_V1X_HARDENING_BRIEF_2026-05-08.md` (the parent v1.x hardening brief). This file is R4-specific.
**Dependency:** `docs/rfcs/RFC-0062-effects-extension.md` (R3's effects framework — read this first; R4 extends the leaf-effect table and adds FFI specializations on top of R3's checker)

---

## Why R4 was sequenced after R3

R3 shipped the `#[effect(...)]` / `#[allow_effect(E)]` machinery with vocabulary `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`. R4 was held back so it could:

1. **Extend R3's leaf-effect table** for FFI surfaces — every extern fn call → `direct_ffi`; extern fn returning raw ptr → `may_return_null`; `unsafe { }` block → new `unsafe` token.
2. **Specialize the diagnostic** when the unhandled effect is FFI-related — instead of generic `EFFECT-G10-UNDECLARED`, fire `FFI-G9-MISSING-ALLOW-DIRECT-FFI` / `FFI-G5-NULL-DEREF` / `UNSAFE-G7-MISSING-ALLOW`. Specialized = better adopter message + the actual sound check (G-5 needs real deref-after-extern-call dataflow, not just a declaration scan).
3. **Promote** the Phase A audit-pass-warning trio (`warning[FFI-NULL]`, `warning[FFI-DIRECT]`, `warning[UNSAFE-G7]`) to per-fn hard errors.

R4 closes the last 3 RFC-0062 audit-pass items at hard-error severity.

---

## Hard rules (non-negotiable)

- **No time estimates anywhere.** No hours/days/weeks/months in any commit message, doc, handoff, or report.
- **Honesty:** if a check fails or a verify regresses, say what failed and why. Don't simulate output.
- **Batch validation:** all edits, then ONE `bash tools/verify.sh` cycle. Skip strict (integrator runs strict on cherry-pick).
- **No seed regen, no bin regen, no audit_dup_fns_report.csv regen.** Integrator handles those on cherry-pick to avoid cascade conflicts.
- **Structural fixes only.** No `#[manual_drop]` band-aids on adopter code.
- **Don't touch other R-units' files** (file ownership below).
- **Don't revert today's parser annotations** (validated NOT redundant under default-flip).

---

## File ownership

**You may touch:**
- `compiler/nucleor_s1_compiler.nr` — extend g10_* leaf-effect table; add G-5 deref dataflow; add G-9 + G-7 specialized diagnostics; register your codes in `is_error_code`
- `tests/features/g5_*.nr`, `tests/err/err_g5_*.nr` (positive + negative)
- `tests/features/g7_*.nr`, `tests/err/err_g7_*.nr` (positive + negative)
- `tests/features/g9_*.nr`, `tests/err/err_g9_*.nr` (positive + negative)
- `findings/inbox/cloud_R4_g5_g7_g9_v0846_2026-05-08.md`
- Possibly: rod wrappers under `stdlib/rods/*.nr` — see "FFI surface retrofit" below; ONLY if your ship-strategy is path (a). If you go path (b), don't touch stdlib.

**You must NOT touch:**
- `compiler/nucleor_tools_suite.nr` (R1 owns)
- `compiler/nucleor_rfc0063_shared_wave1.nr` (Q5 owns)
- `compiler/nucleor_rfc0063_shared_wave2.nr` (R1 owns)
- `bootstrap/nucleor_s1_seed.ll` (integrator regenerates)
- `bin/nucleor.exe` (integrator regenerates)
- `tools/audit_dup_fns_report.csv` (integrator regenerates)
- `docs/rfcs/RFC-0062-effects-extension.md` (R3 owns; if you need to extend it, file an addendum: `docs/rfcs/RFC-0062-effects-r4-ffi-extensions.md`)

---

## Diagnostic codes (registration in `is_error_code`)

Register IMMEDIATELY AFTER R3's `EFFECT-G10-WRONG-ROW`. Group under one R4 comment header.

```
// RFC-0062 G-5 + G-7 + G-9 Phase 4 — FFI surface specializations
// over R3's effect framework. These three codes supersede the generic
// EFFECT-G10-UNDECLARED when the unhandled effect is direct_ffi /
// may_return_null / unsafe — better adopter message + (for G-5) the
// actual sound deref-after-extern-call dataflow check.
if str_eq(code, "FFI-G5-NULL-DEREF") == 1 { return 1; };
if str_eq(code, "FFI-G9-MISSING-ALLOW-DIRECT-FFI") == 1 { return 1; };
if str_eq(code, "UNSAFE-G7-MISSING-ALLOW") == 1 { return 1; };
```

---

## Leaf-effect table extensions

Find R3's `g10_leaf_effects_for_call` (or whatever name R3 used — read R3's helpers above `enforce_g10_effects`). Extend its dispatch:

```
// existing: vec_free / hashmap_free / str_free → frees

// R4 additions:

// Any extern fn call site → produces `direct_ffi` effect.
// Look up the callee in the extern-fn registry (already maintained by
// the existing extern-fn parser). Return effect_set with direct_ffi
// added if the callee is extern.

// Any extern fn whose return type is *const T / *mut T (for any T) →
// produces `may_return_null` effect ALSO.
// (The two effects compose; both fire on `let p = fopen_or_null(...);`.)
```

Add `unsafe` to the effect vocabulary in the parser (alongside `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`). This is a NEW token — R3 didn't ship it because it's R4-scoped.

```
// In the parser's effect-name validator (R3's g10_is_known_effect or similar):
//   accept "unsafe" alongside the existing 4 names.

// In the leaf-effect table:
//   any `unsafe { }` block in fn body → produces `unsafe` effect.
```

---

## Per-effect specialization (the actual R4 work)

R3's `enforce_g10_effects` already fires `EFFECT-G10-UNDECLARED` when a fn body produces an effect E that isn't declared and isn't allow-silenced. R4 adds a pre-check:

```
// Before firing generic EFFECT-G10-UNDECLARED, check if the unhandled
// effect is one of {direct_ffi, may_return_null, unsafe}. If so, fire
// the specialized code instead:
//   direct_ffi → FFI-G9-MISSING-ALLOW-DIRECT-FFI
//   unsafe    → UNSAFE-G7-MISSING-ALLOW
//   may_return_null → does NOT fire as missing-allow; instead, deref-
//     after-call dataflow (below) fires FFI-G5-NULL-DEREF only when
//     adopter actually dereferences the raw ptr without a guard.
//
// Specialized error message includes: name of the extern fn called
// (for direct_ffi), name of the extern fn returning raw ptr (for
// may_return_null), and the location of the unsafe block (for unsafe).
```

### G-5 deref dataflow (the only non-trivial check)

`FFI-G5-NULL-DEREF` is NOT a declaration check — it's actual dataflow. This is the per-fn analysis that promotes the audit-pass-warning to a real check.

```
// In check_expr, when you see a let-binding whose initializer is a
// call to an extern fn returning *const T / *mut T, mark the binding
// as "originated from may_return_null" on the own env (parallel flag,
// e.g. own_set_i_raw(own, str_concat("__g5_maynull_", vname), 1)).
//
// When you see a deref of that binding (kind = unary *), check whether
// the binding is currently dominated by a `ptr_is_null(<vname>) == 0`
// check on the same path. If not → FFI-G5-NULL-DEREF.
//
// The "dominated by ptr_is_null guard" check uses the same control-
// flow primitives as G-11's definite-assignment (`__init_<vname>`):
// when an `if ptr_is_null(<vname>) == 0 { ... }` branch is entered,
// set a `__g5_guarded_<vname>` flag in that scope; clear it on scope
// exit. Q4's own_merge_moved already handles the merge semantics for
// __init_ keys — extend it (or add a parallel handler) for __g5_
// guarded_ keys: the post-join state is "guarded" iff both arms set
// the guard.
//
// Adopter ergonomics: the message names the extern fn that returned
// the raw ptr and tells the adopter to add a `ptr_is_null(<vname>) {
// panic(...) } else { /* deref OK */ }` guard.
```

---

## FFI surface retrofit — pick path (a) or path (b)

G-9 promotion to error WILL fail every existing fn that calls an extern fn unless those fns get `#[effect(direct_ffi)]` or `#[allow_effect(direct_ffi)]` declared. Two paths:

**Path (a) — preferred when feasible:** retrofit the rod-wrapper FFI surface. For every Nucleor wrapper fn that calls an extern fn (e.g. wrappers in `stdlib/rods/rust_bridge/`, `stdlib/rods/python.nr`, `stdlib/rods/io.nr`, etc.), add `#[effect(direct_ffi)]` (the wrapper TRANSITIVELY produces direct_ffi as a real effect — this is correct) OR `#[allow_effect(direct_ffi)]` (the wrapper is auditably-safe and silences the diagnostic — this requires per-wrapper review).

This actually exercises R3's framework on real OSS code. Survey the FFI surface FIRST: count extern fn call sites by wrapper, and decide per-wrapper whether `effect` or `allow_effect`. Document the disposition per wrapper in your finding doc.

**Path (b) — fallback:** ship R4 with G-9 + G-5 at WARNING level (not error) instead of hard-error. This loses the "Phase 4 hard error" promotion for G-9 but unblocks the rest of R4 if path (a) becomes a multi-batch retrofit.

If you start path (a) and it grows past your batch envelope, switch to path (b) and document the residual in `findings/inbox/cloud_R4_*.md`. Don't fake soundness by silencing the check.

G-7 (unsafe blocks) is unaffected by this dilemma because the OSS compiler self-host source contains zero unsafe blocks. Promotion to hard error costs nothing on the OSS surface — adopters who introduce unsafe must add `#[allow_effect(unsafe)]` or `#[effect(unsafe)]`.

---

## Verify cadence

1. Per-edit: none — edit the whole batch.
2. End of batch: `bash tools/verify.sh` (standard, no strict). New fixtures must pass. Existing fixtures must not regress.
3. If you went path (a): the OSS rod fixtures + examples will exercise the retrofitted wrappers — verify that `bash tools/verify.sh` still GREEN with the new effect declarations on every wrapper.
4. Skip: `bash tools/verify_strict.sh`, `tools/check_self_host_md5.sh`, `tools/audit_dup_fns.nr` regen, seed/bin refresh — all integrator-side.

---

## Coordination

- **Branches:** push to harness-pinned branch name (the harness will assign one — note the rename in your Cloud_Control1 entry, R2/R3 had this same situation).
- **Sync file:** `Cloud_Control1.md` (root of repo, append-only). Post your final entry under a `## R4` header with branch SHA + standard verify totals + chosen path (a) or (b) + per-wrapper disposition table if path (a).
- **Findings:** drop iteration report in `findings/inbox/cloud_R4_g5_g7_g9_v0846_2026-05-08.md`. If you went path (a), include the per-wrapper disposition table.

---

## Done definition

- 3 specialized FFI codes registered (FFI-G5-NULL-DEREF, FFI-G9-MISSING-ALLOW-DIRECT-FFI, UNSAFE-G7-MISSING-ALLOW).
- G-10 vocabulary extended with `unsafe` token.
- G-10 leaf-effect table extended for direct_ffi + may_return_null + unsafe.
- G-5 deref-after-extern-call dataflow check working (parallel `__g5_maynull_<vname>` + `__g5_guarded_<vname>` flags + own_merge_moved extension or parallel handler).
- 6+ fixtures (positive + negative for each of G-5, G-7, G-9).
- `bash tools/verify.sh` GREEN — including any retrofitted rod wrappers if path (a).
- Path-(a)-or-(b) disposition documented in finding doc.
- Cloud_Control1 ACK entry posted.

After R4 lands + I integrate: ALL RFC-0062 hard-error gaps closed (G-1 through G-11 except residuals explicitly deferred per plan). v1.0.0 cut criteria met. CHANGELOG promote → version bump → tag.
