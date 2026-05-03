# Parallel Agent Punchlist (post-v0.6.54, updated post-v0.6.61)

> Drafted 2026-05-03 by main agent. Split of the forward-roadmap
> items parked in finding promotions during the v0.6.48–v0.6.54
> closure stream. Probe inbox is at **0 unmatched** as of v0.6.54.
> The work below is what's left for the helper agent to grind on
> while the main agent handles new probe findings + integration.
>
> **Update post-v0.6.61:** main agent shipped v0.6.55–v0.6.61
> closing 8 of 11 rust-syntax-translation-fidelity audit rows
> (const-fn, unreachable!, break-with-value, raw-string, byte-
> string, for-tuple-destruct, UFCS, struct-destructure-in-let).
> Helper shipped RFC-0034 gap 2 (negative usize default) bundled
> in v0.6.56. Audit now has 1 remaining substantive row (char
> literal — type-system gap, not halt-class) plus 2 rows already
> addressed by sister findings.

## Operating constraints (ALL items below)

**Memory + compile budget — "as fast as physics allows":**

- cold compile time: target ≤ 3.5s, hard ceiling 5.93s (warn)
  / 6.5s (e-stop). v0.6.54 baseline: 3.08s.
- hot compile time: ≤ 1.74s. v0.6.54 baseline: 0.25s.
- peak memory: ≤ 770 MB self-host (1 GB e-stop). v0.6.54
  baseline: 316 MB.
- ANY perf regression > +50ms cold or +30 MB peak is a ship
  blocker — bisect with `tools/check_perf_regression.ps1` before
  promoting. The `feedback_perf_regression_pattern.md` user
  memory has the recipe.

**Cadence:** every closure of a punchlist item also runs the
3-sample perf ladder. Save the deltas to
`Desktop\Nucleor_PERF_AUDIT_<date>.md`. Same cadence as the
`feedback_nucleor_perf_audit_cadence.md` rule.

**Validation:** `bash tools/verify.sh` must pass green (783+ steps).
Round-2 fixed-point preserved on every ship. Drift gate clean.
Bootstrap seed refreshed when compiler source changes IR shape.

## Punchlist — Group A: Diagnostic + parse extensions (ship size: small-medium)

These are concrete fixes the helper can prep end-to-end on
`probe/exploration` for main-agent integration. Each is a 1-3
line check or small parse-extension.

### A1 — NUM-021 gap 1: u64 const overflow

`const B: u64 = 18446744073709551615 + 1;` silently compiles
(rc=0, value wraps). Sister to v0.6.50 gap 4 + v0.6.53 gap 3.
Forward-roadmap is u64-aware const-eval — currently
`const_i64_expr` only tracks i64 arithmetic.

**Fix shape:** add unsigned-aware const-eval pass that detects
u64 overflow at the const-decl / let-binding type-check site.
Fire NUM-021. Sister fix to the gap 1 entry of
`findings/promoted/2026-05-02-num-021-coverage-gaps-u64-imin-shift-divzero.md`.

**Risk:** medium. Const-eval substrate change. Use existing
`wrapping_add_u64` / `checked_add_u64` runtime helpers — no new
IR declares needed.

### A2 — u64 strict-arith runtime panics

`let x: u64 = u64::MAX; let y: u64 = x + 1;` silently wraps at
runtime (asymmetric with i64/i32/i16/i8 which already panic via
NUCLEOR_INT_STRICT_INTRIN=1). Sister to A1 at runtime.

**Fix shape:** add 3 runtime helpers
(`__nucleor_panic_add_u64`, `panic_sub_u64`, `panic_mul_u64`)
mirroring the existing i64 versions. Lower u64 binops through
them under NUCLEOR_INT_STRICT_INTRIN=1.

**⚠️ BOOTSTRAP-CYCLE-HOLE RISK CLASS:** new IR declares hit the
v0.6.48-attempt-1 hole. Use the v0.6.52 sidestep pattern (XOR
with sign-bit using existing helpers) where possible. If new
declares are unavoidable, validate the bootstrap chain manually:
build, install, rebuild from current source, confirm round-2
fixed-point, refresh seed, run verify.

### A3 — RFC-0034 gap 2: negative usize default

`fn f[N: usize = -1](x: i64) -> i64 { ... }` silently accepts
the negative default. Tracked in
`findings/promoted/2026-05-02-rfc0034-ct-param-first-pass-residual-edges.md`.

**Fix shape:** validate the default literal in
`skip_compile_time_param_default` — for unsigned CT-param types,
reject kind-5 unary-minus on a kind-1 literal. Small parse-time
check.

**Risk:** low.

### A4 — RFC-0034 gap 1: explicit CT-arg call SEGFAULT

`ct_inc[42](x)` SEGFAULTs at runtime (rc=139). Same finding as
A3.

**Fix shape:** detect the `identifier[expr](args)` shape in
`parse_postfix` when `identifier` resolves to a fn name, halt
with "explicit CT-arg call form not yet supported in RFC-0034
first-pass; omit the [N] and let the default erase."

**Risk:** medium. Touches parse_postfix.

### A5 — Type alias resolver

`type Name = i64; let x: Name = 5;` accepts at parse but the
alias never resolves at use sites — TYP-006 fires. Tracked in
`findings/promoted/2026-05-02-module-scope-decl-silent-noop-gaps-type-mod-union-use.md`.

**Fix shape:** wire alias resolution into `nr_type_to_llvm` and
`type_expr` at type-string lookup time. Walk the parse_type_alias_decl
results, build an alias map, substitute when used.

**Risk:** medium. New resolver substrate.

### A6 — Match-arm literal overflow

`match x { 9223372036854775808 => 1, _ => 0 }` silently dead-arm
because the lexer wraps the literal to i64::MIN at storage.
Tracked in
`findings/promoted/2026-05-01-match-arm-literal-exceeds-i64-silently-dead.md`.

**Fix shape:** lexer-level token flag for decimal literals in
(i64::MAX, u64::MAX]; parse_match_one_pattern checks the flag
and emits a clean diag.

**Risk:** medium. Lexer + parser tweaks.

### A7 — Tuple-struct decl + nested struct pattern (parse extensions)

Tuple-struct `struct P(T1, T2);` halt was shipped in v0.6.53
(clean diag pointing at named-field workaround). The actual
support — positional field synthesis (`__0`, `__1`) and `.0`/`.1`
access path — is still forward-roadmap. Same finding covers
nested struct patterns `match l { Line { a: Point { x }, b } =>
... }` (recurse into inner pattern).

**Fix shape:** extend `parse_struct_decl` to accept the paren-
form, synthesize positional field names; extend
`parse_match_struct_binding_block` to recurse via
`parse_match_one_pattern` for each field's binding.

**Risk:** medium-high. Parse + type-resolver work.

### A8 — Keyword silent-strip remaining cases

`unsafe fn` halt shipped in v0.6.53. Remaining sub-cases of
`findings/promoted/2026-05-01-keyword-silent-strip-audit.md`:

- `move` closure form (clang-link error `@move undefined`).
- `where T: NoSuchTrait` silently accepted (no trait-name validation).
- `'static` lifetime corner-case parse errors.

**Fix shape:** halt at parse for each form. Match the v0.6.53
unsafe-fn precedent. `move` needs lex-time detection + closure-
side capture lowering.

**Risk:** low to medium.

## Punchlist — Group B: Perf objectives ("as fast as physics allows")

These are perf-driven items. Run perf ladder before/after every
ship. Memory hard-cap is 770 MB.

### B1 — Per-call-site tprof guard wrap (deferred from v0.6.54)

Six tprof_mark sites in `type_expr` kind-7 still call
`tprof_mark` unconditionally; the helper does an internal
tprof_enabled check but the fn-call overhead is paid per kind-7
call. The slice patch wrapped each with
`if prof_on_v631 > 0 { tprof_mark(...); };`.

**Fix shape:** wrap each of the 6 unguarded `tprof_mark(tprof,
9, 10, call_start);` sites in `type_expr` kind-7 with the
`prof_on_v631 > 0` guard.

**Expected gain:** marginal (~50-100ms cold). Worth picking up
since the substrate is already there.

### B2 — Hotspot top-5 reductions

v0.6.54 hotspot ranking (re-measure after each ship):

| helper | calls (self-host) | notes |
|---|---|---|
| vec_get | ~118 M | already minimal hot path |
| str_eq | ~61 M | already first-byte-fail; consider intern hashing for known-static strings |
| vec_push | ~39 M | could inline grow path for small caps |
| str_concat | ~3.4 M | candidate for arena-backed bulk concat |
| str_substring | ~2.8 M | candidate for arena-backed substring |

**Forward-roadmap:** an internal-compile string arena (`str_arena_*`
helpers exist for adopters but the compiler doesn't route its own
str_concat/substring through them). Cross-cutting refactor.

**Risk:** medium-high. Sister to A5 alias resolver in invasiveness.

### B3 — vec_get_unchecked variant (compiler-internal)

Compiler emits `vec_get` even when bounds are statically known
(immediately after `vec_len` checks). A `vec_get_unchecked`
variant skipping the bounds check would reduce per-call cost on
the hot path. Cross-cutting compiler-side change (tag known-
in-bounds call sites).

**Expected gain:** could be substantial on vec_get's 118M calls.

**Risk:** medium-high.

### B4 — String constant pool dedup

Some str literals appear hundreds of times in the .ll output
(diagnostic strings, IR opcode strings). Pool dedup would shrink
the .ll and reduce link time.

**Fix shape:** at emit_str_constants, hash existing constants and
emit only unique ones; reuse the existing index for repeats.

**Risk:** low-medium. Emit-side only.

## Group C: Deeper v1 architecture (NOT for helper — flag for main agent)

These are too large for the helper's prep+propose workflow. They
need spec-level design + cross-team alignment. Listed for context
only; do NOT prep these.

- **Drop / RAII / move-semantics / closure-capture-flow** — v1
  borrow-checker workstream (`drop-trait-never-auto-called`,
  `move-semantics-not-enforced`, `vec-allocation-without-drop-leaks`,
  `str-concat-loop-rebind-leak`, closure-capture family).
- **Generic-T inference** (Box::new literal, iter map type-changing,
  generic trait bounds) — bidirectional type inference pass.
- **Length-tagged str ABI** — every `str_*` runtime helper rewritten;
  cross-cutting adopter break.
- **derive(PartialEq) / Hash** — auto-emit element-wise compare for
  Vec/struct/HashMap.
- **RFC-0008 phase 2** — `#[no_alloc]` / `#[no_panic]` call-graph
  propagation through ISR call edges.
- **HashMap<KeyT> key-type-aware** — hash/eq helper family per
  key-type-class. Sister to A2's bootstrap-cycle hole.
- **const-fn parse extension** — full const-eval substrate.

## Workflow (UNCHANGED from PROBE_MANDATE)

Same probe+prep flow as before. Push to
`origin/probe/exploration`, flag heartbeat as
`ready-for-integration`. Main agent integrates and assigns the
version. Don't push to main, don't tag.

When picking the next item, prefer:

1. Group A items with `Risk: low`.
2. Then Group B items that don't risk the bootstrap-cycle hole
   class.
3. Mix at least 1 Group A and 1 Group B per cycle so adopter-
   facing diags ship alongside perf.

## Heartbeat schema

Same `findings/heartbeat.json` shape as before. Add a field:

```json
{
  "current_punchlist_item": "A3",
  "perf_baseline": { "cold": 3.08, "hot": 0.25, "peak_mem": 316 },
  ...
}
```

Update before each push.

## Referenced findings (forward-roadmap detail per item)

All cited findings are in `findings/promoted/`. Read the full
status + adopter-migration sections before starting work — they
have the deferral rationale and workaround patterns.
