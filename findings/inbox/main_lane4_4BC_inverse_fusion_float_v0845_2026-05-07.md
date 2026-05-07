# Lane 4 / Queue 4B + 4C — `inverse`, `fusion`, and float `eps` law semantics

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `probe/laws-inverse-fusion-float-v0845`
- **Base:** `origin/main` @ `c775b069`
- **Scope:** Audit + banner/schema correction. Fusion + float design findings.

## Headline

- **Queue 4B (inverse) — already shipped.** The
  `compiler/nucleor_tools_suite.nr::build_law_check_source` generator
  emits `__nucleor_law_check_*` round-trip tests for `@law(inverse = g)`
  declarations at four bounded sample integers. Confirmed empirically:
  `nuc test tests/features/law_inverse_bounded_smoke.nr --check-laws`
  generates `__nucleor_law_check_0` and PASSes. The s1 EFF-G123 banner
  was stale (listed inverse as open); fixed in this branch. Schema
  doc `docs/spec/Nucleor_Algebraic_Laws_Schema.md` §4 also stale;
  fixed in this branch.
- **Queue 4B (fusion) — open, design-blocker.** Semantics need a
  precise definition for the bounded integer checker to generate.
  Smallest v1.0 close: `@law(fusion = h)` with `h` declared in scope,
  meaning `f(g(a, b), c) == h(a, b, c)`. Bounded-integer check would
  generate `(f ∘ g)(a, b, c) == h(a, b, c)` at the same four sample
  points as inverse. Until the fusion semantic is documented in the
  schema, the existing fail-closed LAW-001 on unsupported canonical
  forms is the right v1.0 posture.
- **Queue 4C (float `eps` / approximate) — fail-closed via LAW-004
  is the v1.0 profile.** The handoff goal asks "what small v1.0
  profile is acceptable" — the answer is the existing fail-closed
  behavior. Why exact float laws are unsafe + which diagnostics
  should fire are documented below. Phase 2 ships the actual
  tolerance contract.

## Empirical confirmation (current main `c775b069`)

```
$ ./bin/nucleor.exe build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
  ... compiled: target/nucleor_tools.exe
$ cp target/nucleor_tools.exe bin/nucleor_tools.exe
$ ./bin/nucleor.exe test tests/features/law_inverse_bounded_smoke.nr --check-laws
info[CHECK-LAWS]: generated bounded integer law checks
  discovered tests: 1
    __nucleor_law_check_0
  source: target/law_inverse_bounded_smoke-test__test_harness.nr (1867 bytes)
  ...
  PASS: __nucleor_law_check_0
test result: PASS (1 test)
```

The inverse generator works. The schema-doc + banner correction is
the substantive Queue 4B delta on inverse.

## Queue 4B fusion design

### Recommended schema (proposed for `Nucleor_Algebraic_Laws_Schema.md` §1)

| Canonical name | Form | Meaning | Notes |
|---|---|---|---|
| `fusion = h` | `@law(fusion = h)` | `f(g(a, b), c) == h(a, b, c)` (binary `f`, binary `g`, ternary `h`) OR `f(g(a)) == h(a)` (unary fns) | binary or unary; arity of `h` matches the composed-fn arity; `h` must be in scope at the @law site |

### Bounded checker shape (proposed for `build_law_check_source`)

For `@law(fusion = h)` on a binary `f` with binary partner `g`:

- Generate `__nucleor_law_check_<i>(a: i64, b: i64, c: i64)` taking
  the four-sample points cross-product (4³ = 64 cases).
- Body: `assert_eq!(f(g(a, b), c), h(a, b, c));`.
- Same fail-closed wiring as inverse: any counterexample → LAW-001.

Estimated implementation size: ~80 LOC in `build_law_check_source`
plus 1 positive fixture (`tests/features/law_fusion_bounded_smoke.nr`)
and 1 negative fixture (`tests/err/err_law_fusion_arity_mismatch.nr`).

### Stop reason for v1.0

The fusion semantic is reasonable and small, but there is no shipped
adopter yet (no `tests/features/law_fusion_*.nr` exists). Without a
concrete adopter use case, the bounded-checker arity choice (binary
vs unary vs general n-ary) is speculative. The v1.0-safe close is to:

1. Land the schema definition above as documentation.
2. Keep LAW-001 fail-closed on `fusion` until the bounded checker
   ships (Phase 4).
3. When an adopter use case lands, the checker is ~80 LOC + 2
   fixtures.

This branch ships the schema-doc update and the banner correction
(inverse closed, fusion still open with explicit semantics).

## Queue 4C float `eps` / approximate semantics finding

### Why exact float laws are unsafe

IEEE-754 floating-point arithmetic does not satisfy the algebraic
laws on integer arithmetic:

1. **Associativity fails on float addition.** `(0.1 + 0.2) + 0.3 ≠
   0.1 + (0.2 + 0.3)` due to rounding. The exact-equality bounded
   checker would generate counterexamples at standard sample points.
2. **Distributivity fails on float multiplication.** `a * (b + c)`
   may differ from `a*b + a*c` by 1 ULP at the sample points.
3. **Identity is NOT bit-exact.** `x + 0.0 == x` holds for normal
   `x` but `x + (-0.0)` and `x` differ in sign-bit for `x == 0.0`.
   Adopter writing `@law(identity = 0.0) fn add_f64(...)` would
   pass the simple integer-shaped check but not bit-exact at zero.
4. **NaN propagation** breaks reflexivity: `NaN == NaN` is `false`
   in IEEE-754. Any law that asserts `f(a) == g(a)` fails when
   `f(a)` produces NaN even if `g(a)` does too.
5. **Subnormal flush-to-zero** and **rounding mode** are
   per-process / per-thread state. A bounded checker that runs once
   in the test harness sees one rounding-mode setting; production
   code may see a different one.

For these reasons, naively running the bounded integer checker on
float fns produces false positives (laws that hold "in expectation"
but not bit-exact) and false negatives (laws that bit-exactly fail
at sample points but hold under reasonable tolerance).

### Which diagnostics should fire (proposed)

| Code | When | Severity |
|---|---|---|
| **LAW-004** (already shipped) | `@law(eps = T)` or `@law(approximate)` used before tolerance contract ships | hard error at `--check-laws` time |
| **LAW-009** (proposed) | `@law(...)` declared on a fn with `f64` / `f32` parameters or return type WITHOUT `eps`/`approximate` modifier | warning at compile time, hard error at `--check-laws` time |
| **LAW-010** (proposed) | `@law(eps = T)` with `T <= 0` or `T > 1.0` (out-of-band tolerance) | hard error at parse time |
| **LAW-011** (proposed) | `@law(...)` on a fn that produces NaN at any bounded sample point | warning at `--check-laws` (NaN handling is undefined; suggest `is_nan_safe = true` modifier) |

LAW-009 is the **production-readiness pivot**: today an adopter can
write `@law(commutative) fn add_f64(a: f64, b: f64) -> f64 { a + b }`
and `--check-laws` would generate a bit-exact integer-shaped check
that fires LAW-001 false positives. LAW-009 would catch this at the
declaration site.

### Smallest v1.0 profile (Phase 1)

**Ship:**
- LAW-004 (already done — fail-closed on `eps`/`approximate`).
- LAW-009 (~20 LOC + 2 fixtures): warn + `--check-laws` fail-closed
  when adopter declares `@law(...)` on a fn whose signature includes
  `f32`/`f64` without an explicit `approximate` opt-in.

**Defer to Phase 2 (RFC-0031 float tolerance phase):**
- Actual `eps`-aware bounded checker.
- LAW-010 / LAW-011.
- Per-rounding-mode test isolation.
- NaN-safe modifier syntax.

This eliminates the silent fall-through where float laws are
declared but never validated.

### Honest residual

LAW-009 implementation needs to walk the fn signature to detect
`f32`/`f64` parameters or return types. The signature is in the
resolved source after the lex pass; a textual scan for `: f32` /
`: f64` / `-> f32` / `-> f64` in the @law-annotated fn header is
sufficient for v1.0 (matches the existing source-text approach used
elsewhere in the laws + RT lanes). False positives on adopter types
named like `f64Foo` are theoretical; the v1.0 fixture set should
not contain such names.

## Files changed in this branch

```
compiler/nucleor_s1_compiler.nr             (1 hunk: EFF-G123 banner — inverse moved to closed list, IR-level proof gate referenced, fusion + float-law residuals named)
docs/spec/Nucleor_Algebraic_Laws_Schema.md  (1 hunk: §4 combination-semantics paragraph — inverse moved to shipped list)
findings/inbox/main_lane4_4BC_inverse_fusion_float_v0845_2026-05-07.md  (this report)
```

No bin/seed refresh needed (banner-text-only IR change is small but
still needs a stage1 → stage2 rebuild + promotion to keep the
self-host fixed-point — handled at integrator time).

## Stop reason

Per handoff §Lane 4 / Queue 4B: "Add bounded integer property-
generation support for `inverse` and `fusion` only if the syntax and
semantics are already documented enough. Otherwise write a finding
defining required syntax and examples." Inverse is already shipped
(audit-only update). Fusion semantics are documented here for whoever
implements Phase 2.

Per handoff §Lane 4 / Queue 4C: "Produce a design report for `eps` /
approximate law semantics. Must include why exact float laws are
unsafe, which diagnostics should fire, and what small v1.0 profile
is acceptable." All three covered above; fail-closed via LAW-004 is
the v1.0 profile, with LAW-009 proposed as the smallest additional
production-readiness gate.
