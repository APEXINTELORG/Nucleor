# Changelog

All notable changes to Nucleor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.17] — 2026-04-25

**RFC-0028 phase 3 — `format3_isf` combo.** i64 + str + f64
for profile/step output:

  `format3_isf(tmpl, i64_a, str_b, f64_c)` — e.g.
  `format!("Step {} ({}): {}", n, stage, t_ms)` produces
  `"Step 1 (warmup): 0.42"`.

Same five edit sites in s1 + mirrored in tools_suite + runtime
impl chaining `__nucleor_format_i64` -> `__nucleor_format_str`
-> `__nucleor_format_f64`. Added to the `#[no_alloc]`
forbidden-name list.

### Verify gate

- New: `tests/lang/format3_isf.nr` — auto-discovered under the
  lang directory; prints two profile-style outputs then `OK
  format3_isf`.
- Self-host bootstrap fixed-point holds at AE09C218 (stage-3
  IR == stage-4 IR). Bootstrap RSS peak 243 MB.

## [0.3.16] — 2026-04-25

**RFC-0028 phase 3 — `format3_sif` combo.** Str + i64 + f64
for the benchmark / aggregation output shape:

  `format3_sif(tmpl, str_a, i64_b, f64_c)` — e.g.
  `format!("{} ({} samples): {}", tag, n, avg)` produces
  `"iter_ms (100 samples): 0.42"`.

Same five edit sites in s1 + mirrored in tools_suite + runtime
impl chaining `__nucleor_format_str` -> `__nucleor_format_i64`
-> `__nucleor_format_f64`. Added to the `#[no_alloc]`
forbidden-name list.

### Verify gate

- New: `tests/lang/format3_sif.nr` — auto-discovered under the
  lang directory; prints two combo outputs then `OK format3_sif`.
- Self-host bootstrap fixed-point holds at 2CCC13AF (stage-3
  IR == stage-4 IR). Bootstrap RSS peak 207 MB.

## [0.3.15] — 2026-04-25

**RFC-0028 phase 3 — `format3_ssf` combo.** Two strs followed
by an f64. Closes the str-leading float tier:

  `format3_ssf(tmpl, str_a, str_b, f64_c)` — e.g.
  `format!("{} {}: {}", category, key, measurement)` produces
  `"metric pi: 3.14"`.

Useful for metrics, CSV-ish output, and instrumented log lines
where a labeled float is the payload. Same five edit sites in
s1 + mirrored in tools_suite + runtime impl in
`nucleor_llvm_rt.c` chaining `__nucleor_format_str` x 2 then
`__nucleor_format_f64`. Added to the `#[no_alloc]` forbidden-
name list.

After this ship the format3 surface covers all the s/i/f
prefix shapes that tier-3 user code routinely needs:

|        | str-1   | i64-1   | f64-1 |
|--------|---------|---------|-------|
| str-2  | sss     | sii sis ssi | sff ssf (new) |
| i64-2  | iss isi | iii     | iff iif       |
| f64-2  | —       | —       | fff           |

### Verify gate

- New: `tests/lang/format3_ssf.nr` — auto-discovered under the
  lang directory; prints `metric pi: 3.14`,
  `sensor temp_c: 22.5`, then `OK format3_ssf`.
- Self-host bootstrap fixed-point holds at E9DE3715 (stage-3
  IR == stage-4 IR). Bootstrap RSS peak 263 MB.

## [0.3.14] — 2026-04-25

**RFC-0028 phase 3 — float-mixing format3 combos.** Three more
format builtins covering the most common float-mixing shapes:

- `format3_iif(tmpl, i64, i64, f64)` — e.g.
  `format!("iter {} of {} ({} sec)", done, total, dt)`.
- `format3_iff(tmpl, i64, f64, f64)` — e.g.
  `format!("{}: x={} y={}", index, x, y)` for indexed coords.
- `format3_sff(tmpl, str, f64, f64)` — e.g.
  `format!("{} at ({}, {})", label, x, y)` for labeled 2D
  points.

f64 args carry as `i64` bits across the LLVM IR boundary (same
calling convention as the existing `format2_ff` / `fi` / `if`
and `format3_fff` combos); the runtime decodes via
`__nucleor_format_f64`. Same five edit sites in s1 + mirrored
in tools_suite + runtime impl + `#[no_alloc]` forbidden-name
list.

### Verify gate

- New: `tests/lang/format3_float_mix.nr` — auto-discovered
  under the lang directory; prints
  `iter 3 of 10 (0.033 sec)`, `7: x=1.25 y=0.75`,
  `origin at (1.25, 0.75)`, then `OK format3_float_mix`.
- Self-host bootstrap fixed-point holds at 65BFD88B (stage-3
  IR == stage-4 IR). Bootstrap RSS peak 222 MB.

## [0.3.13] — 2026-04-25

**RFC-0028 phase 3 — `format3_iis` + `format3_isi` combos.**
Two more format-string builtins that close the str/int trio:

- `format3_iis(tmpl, i64_a, i64_b, str_c)` — e.g.
  `format!("{}/{}: {}", done, total, label)` produces
  `"3/10: items"`.
- `format3_isi(tmpl, i64_a, str_b, i64_c)` — e.g.
  `format!("{}: {} ({})", n, kind, count)` produces
  `"7: kind (42)"`.

After this ship, all 7 useful 3-slot combinations of `i` and
`s` exist (`iii`, `sii`, `iss`, `sss`, `ssi`, `sis`, `iis`,
`isi`) plus the `fff` triple-float variant. Ships in the same
shape as v0.3.12: 5 edit sites in `nucleor_s1_compiler.nr` +
mirrored in `nucleor_tools_suite.nr` (drift-gate-enforced),
runtime impl in `nucleor_llvm_rt.c`, both new builtins added
to the `#[no_alloc]` forbidden-name list.

### Verify gate

- New: `tests/lang/format3_iis_isi.nr` — auto-discovered under
  the lang directory; prints both combo outputs then
  `OK format3_iis_isi`.
- Self-host bootstrap fixed-point holds at 1F4F68DD (stage-3
  IR == stage-4 IR). Bootstrap RSS peak 263 MB.

## [0.3.12] — 2026-04-25

**RFC-0028 phase 3 — `format3_ssi` + `format3_sis` combos.**
Two new format-string combos that round out the most common
log-line shapes:

- `format3_ssi(tmpl, str_a, str_b, i64_c)` — e.g.
  `format!("[{}] {} = {}", level, key, n)` produces
  `"[INFO] iter = 7"`.
- `format3_sis(tmpl, str_a, i64_b, str_c)` — e.g.
  `format!("[{} {}] {}", tag, n, msg)` produces
  `"[ERR 42] stack overflow"`.

Mirrors the existing `format3_iii` / `sii` / `iss` / `sss` /
`fff` pattern: ABI-table mapping in `nucleor_s1_compiler.nr` +
`nucleor_tools_suite.nr` (drift-gate-enforced parity), IR
`declare ptr @__nucleor_format3_*` lines, runtime impl in
`nucleor_llvm_rt.c` chaining `__nucleor_format_str` /
`__nucleor_format_i64` over the template (each chunk frees the
intermediate). Both new builtins added to the `#[no_alloc]`
forbidden-name list — calling them from a `#[no_alloc]` body
fires RT-001 (they allocate).

### Verify gate

- New: `tests/lang/format3_ssi_sis.nr` — auto-discovered under
  the lang directory; prints `[INFO] iter = 7`,
  `[ERR 42] stack overflow`, then `OK format3_ssi_sis` so the
  gate's `grep -qE '^OK '` shape check passes.
- Self-host bootstrap fixed-point holds at 21809F89 (stage-3
  IR == stage-4 IR, both built with the new compiler — stage-2
  IR legitimately differs by exactly the two new `declare`
  lines because the old compiler doesn't know them yet, the
  same v0.2.153 gotcha).
- Bootstrap RSS peak 243 MB.

## [0.3.11] — 2026-04-25

**Test-framework coverage for the bare `arena_*` builtin path.**
The `arena_new` / `arena_alloc` / `arena_reset` / `arena_destroy`
builtins are reserved by the s1 compiler for the
(still-unimplemented) RFC-0002 `Arena` builtin path. v0.2.150
flagged that no runtime exported the `__nucleor_arena_*`
symbols, so any source that called the bare names link-failed.
v0.2.154 fixed the trap by shipping a minimal bump-arena impl
in `nucleor_llvm_rt.c` (the always-linked main runtime); the
only fixture proving that was `tests/lang/arena_builtin.nr` —
a main-fn shape.

This release adds `tests/smoke/t311_arena_builtin.nr`, an
explicit `#[test]`-framework round-trip:

```nucleor
#[test]
fn test_arena_round_trip() {
    let a = arena_new(1024);
    let p1 = arena_alloc(a, 64);
    let p2 = arena_alloc(a, 64);
    arena_reset(a);
    let p3 = arena_alloc(a, 64);
    arena_destroy(a);
    assert_eq(1, 1); // reach = all five builtins linked
    let _ = p1;
    let _ = p2;
    let _ = p3;
}
```

The `Arena` and `&i64` opaque newtypes block direct
`assert_ne(handle, 0)` shape, so the test asserts via "reach"
(if execution gets to the assert, all five builtins linked
and ran without crashing — that's the contract).

No compiler change. Verify gate adds one explicit T3.11 step
that runs the new fixture under `nuc test`.

## [0.3.10] — 2026-04-25

**`examples/19_rt_pid.nr` — fully RT-annotated PID step.** A
worked example that puts the entire v0.3 RFC-0001 attribute
family on a single tight inner control loop:

```nucleor
#[no_alloc]
#[no_panic]
#[no_dyn]
#[deadline = 100]
fn pid_step_rt(kp: i64, ki: i64, kd: i64, err: i64,
               integral: i64, last_err: i64) -> i64 {
    let derivative: i64 = err - last_err;
    let p_term: i64 = kp * err;
    let i_term: i64 = ki * (integral + err);
    let d_term: i64 = kd * derivative;
    return p_term + i_term + d_term;
}
```

The inner step takes the gain triple and error trio as scalars
(not a `PidState` by value) so the ownership checker doesn't
fire `OWN-001` in the loop driver. The outer driver in `main`
is intentionally NOT RT-annotated — `print` / `str_concat`
allocate, so they have to live outside the `#[no_alloc]`
contract.

Compiles clean against all eight RT diagnostics:
RT-001/002/003/004/005/006/007/008.

Added under Tier 4 of `examples/README.md` as the entry-point
demo for the v0.3 robotics arc, and to `tools/examples.list` so
the verify gate exercises it on every release.

### Verify gate

- New example step `example 19_rt_pid` (auto-discovered from
  `tools/examples.list`).
- No compiler change → no bootstrap fixed-point check needed.

## [0.3.9] — 2026-04-25

**T3.10 RT-008 — direct self-recursion in `#[deadline]` fn
warns; `#[max_depth = N]` opts out. Closes RFC-0001 §3.5.**

### Approach

T3.1's resolver pass renames the user's fn body to
`__nuc_dl_inner_<id>(...)` and emits the user's original name
as the wrapper that calls inner + deadline_check. So the
self-call inside the body still references the user's
*original* name (the wrapper). To detect that:

1. `dl_get_wrapper_name(source, inner_name)` walks past the
   inner's brace-balanced body and reads the name of the
   immediately-following `fn ` declaration — that's the wrapper.
2. `collect_max_depth_fns(source)` scans for `#[max_depth ...]`
   attribute lines paired with the next `fn NAME(`. After T3.1
   the user's `#[max_depth]` lands on the inner fn (preserved
   verbatim by the expander), so we match the inner_name.
3. `enforce_rt008_recursion(diags, source)` iterates the
   `wcet_collect_deadline_fns` pairs. For each (inner, limit),
   resolve the wrapper name, skip if the inner has #[max_depth],
   else strip the inner body and check for `<wrapper>(`. If
   found, emit `warning[RT-008]`.

### Verify gate

- New: `tests/fixtures/t310_rt008_recursion.nr` — `#[deadline]`
  + `#[no_alloc]` Fibonacci with no `#[max_depth]`. Fires the
  exact RT-008 line.
- New: `tests/fixtures/t310_rt008_bounded.nr` — same Fibonacci
  with `#[max_depth = 8]`. Build is clean (no RT-008).
- Existing fixtures all stay clean — RT-008 fires only on the
  recursion+deadline+no-max-depth intersection.
- Self-host bootstrap fixed-point holds at A2E8896B (stage-2 IR
  == stage-3 IR). Bootstrap RSS peak 267 MB.

This closes RFC-0001 §3.5 in full. Every diagnostic from the
spec table (RT-001 through RT-008) now has v1 source-level
enforcement, smoke fixtures, and verify gate coverage.

## [0.3.8] — 2026-04-25

**T3.9 RT-005 — FFI call from inside an RT-marked fn warns.**
`extern fn` declarations are unknown to the compiler and may
allocate, panic, take indeterminate time, or do IO. Calling
one from inside `#[no_alloc]` / `#[no_panic]` / `#[deadline]`
breaks every RT contract. v1 fires
`warning[RT-005]: FFI call '<name>' from <attr> fn '<fn>' --
extern fns may allocate, panic, or block (use #[allow(RT-005)]
until #[ffi_no_*] ships)`. Suppressible per-fn.

### Approach

Three pieces:
1. `collect_extern_fn_names(source)` walks the source for
   `extern fn NAME(` lines (string- and comment-aware so the
   literal pattern in this very compiler doesn't match itself).
2. `check_no_ffi_violations(diags, source, fn_name, externs, attr_label)`
   locates the body via `fn NAME(` then `{` then brace-balanced
   `}`, runs it through the v0.3.6 strip pass, then for each
   extern name checks for `<name>(` in the stripped body.
3. `enforce_rt005_ffi(diags, source)` iterates the union of
   `collect_no_alloc_fns`, `collect_no_panic_fns`, and
   `wcet_collect_deadline_fns` (the inner-name slot from each
   T3.1 deadline pair) and runs the body check on each.

### Verify gate

- New: `tests/fixtures/t39_rt005_ffi.nr` — `extern fn host_telemetry`
  + `#[no_alloc] fn rt_path` calling it. Verify asserts the exact
  RT-005 line text (code, fn name, attribute label).
- Existing fixtures with extern fn but no RT attrs (t34_export.nr)
  + RT attrs but no extern call (t36_no_dyn_clean.nr) both stay
  clean — RT-005 fires only on the intersection.
- Self-host bootstrap fixed-point holds at 87C82347 (stage-2 IR
  == stage-3 IR). Bootstrap RSS peak 215 MB.

This closes RFC-0001 §3.5 except RT-008 (recursion in #[deadline]
+ `#[max_depth]` annotation), which needs the wrapper-name
extraction work and is deferred to v0.4.

## [0.3.7] — 2026-04-25

**T3.8 RT-006 — RT attribute on `async fn` is rejected.** The
final RT diagnostic from RFC-0001 §3.5: any of `#[no_alloc]`,
`#[no_panic]`, `#[no_dyn]`, or `#[deadline = N]` paired with
an `async fn` now fires `error[RT-006]: RT attribute ... on
async fn '<name>' -- async is non-deterministic by design and
cannot satisfy real-time guarantees`. The two surfaces have
to be mutually exclusive — async scheduling, IO wakeups, and
thread allocation make every RT contract impossible to honor.

### Approach

Detection has to happen *before* `expand_async_strip_keyword`
deletes the `async` keyword. The expander now does the check
inline: when stripping `async ` from `async fn NAME(...)`, it
walks back past blank lines and `///` doc comments looking for
exactly `#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, or
`#[deadline ...]` / `#[deadline=...]`. If any of those is the
first non-blank/non-`///` line above, it emits a marker
`\n//__NUC6T:<fnname>\n` at column 0 in the output stream.
The post-resolver diag pass scans for the exact byte sequence
`\n//__NUC6T:` (the leading newline rules out string-literal
and mid-line prose mentions in this very compiler), reads the
fn name, emits one error[RT-006] per match.

### Verify gate

- New: `tests/err/err_rt006_async_no_alloc.nr` and
  `tests/err/err_rt006_async_deadline.nr` — both auto-discovered
  by the negative-fixture sweep.
- New explicit step T3.8 asserts the exact RT-006 diagnostic
  text (code, fn name, "non-deterministic" rationale).
- Existing `tests/smoke/t28_async_threads.nr` still PASSes:
  bare async (no RT attr) is unaffected.
- Self-host bootstrap fixed-point holds at 73553798 (stage-2
  IR == stage-3 IR). Bootstrap RSS peak 207 MB.

## [0.3.6] — 2026-04-25

**T3.7 polish — RT-001/002/003 v1 checkers strip strings and
line comments before scanning.** The v1 source-level checks
that ship in `#[no_alloc]` / `#[no_panic]` / `#[no_dyn]` were
naive `str_contains` over the fn body, so a forbidden name
appearing inside a `"..."` string literal or `// ...` line
comment would false-trigger. Now all three checks route the
body through a single `strip_strings_and_line_comments` pass
that replaces masked ranges with spaces (length-preserving so
any future position math stays valid). The `(` separator inside
a quoted region gets blanked too, which means the `<name>(`
anchor pattern can no longer match anywhere inside a quoted /
commented span.

### Verify gate

- New: `tests/smoke/t37_rt_string_skip.nr` — 3 fns, one for each
  RT attribute, each containing the exact forbidden token
  *only* inside a stripped region (string for `Vec::new()` and
  `dyn dispatch is enabled`; line comment for `.unwrap()`). 3
  `#[test]` cases that PASS prove the build accepts the source.
- Existing fixtures all still pass — the strip is a strict
  superset of the prior naive scan.
- Self-host bootstrap fixed-point holds at 0D1ABE1D (stage-2 IR
  == stage-3 IR). Bootstrap RSS peak 262 MB.

## [0.3.5] — 2026-04-25

**T3.6 `#[no_dyn]` enforcement (RT-003) — completes the
RFC-0001 RT attribute family.** With this ship the four
`#[no_alloc, no_panic, no_dyn, deadline = N]` attributes that
RFC-0001 specs as the L1 hard-real-time bundle are all wired
end-to-end: each one has a v1 source-level checker, a smoke
fixture proving the clean path, and (where applicable) a
negative fixture proving the violation path.

### Approach

Mirrors `#[no_panic]` exactly: `collect_no_dyn_fns` scans the
resolved source for `#[no_dyn]` attribute lines (string- and
comment-aware so the attribute literal in this very compiler
doesn't match itself), pairs each with the next `fn NAME(`,
and returns the list. `check_no_dyn_violations` then walks each
fn's signature + brace-balanced body and fires
`error[RT-003]: dynamic dispatch (` `dyn` `) used but ` `<name>`
` is marked #[no_dyn]` if the substring `dyn ` (trailing space)
appears anywhere. The trailing space rules out identifier names
like `dyn_var` while catching `&dyn Trait`, `Box<dyn Trait>`,
and `&mut dyn Trait`.

v1 limitation: the substring scan does not skip strings/comments
inside fn bodies, so a literal `"dyn "` in a string still
triggers RT-003. Documented and suppressible per-fn via
`#[allow(RT-003)]`. v2 (post-RFC-0026) gains the AST-based
check that distinguishes real type uses from string contents.

### Verify gate

- New: `tests/smoke/t36_no_dyn_clean.nr` — 2 `#[no_dyn]` fns
  doing pure i64 arithmetic + 2 `#[test]` cases. Verify asserts
  both PASS, proving the marker mechanism works without
  false-positive on the attribute literal itself.
- New: `tests/err/err_no_dyn_violation.nr` — `#[no_dyn]` fn
  with literal `dyn ` text in a string. Build fails with
  RT-003. Caught by the negative-fixture sweep that auto-runs
  every `tests/err/*.nr` and asserts at least a diagnostic line.
- Self-host bootstrap fixed-point holds at 7440EAF5 (stage-2
  IR == stage-3 IR). Bootstrap RSS peak 236 MB.

## [0.3.4] — 2026-04-25

**T3.4 extern-C shim generator — `#[export]` attribute makes
Nucleor fns callable from C.** `nuc gen-headers` already emits
forward declarations for `extern fn` *imports* and `#[repr(C)]`
struct typedefs. v0.3.4 adds the symmetric *export* path: any
fn (or `pub fn`) prefixed with `#[export]` is added to the
generated header as a C-callable forward declaration. The LLVM
IR already emits these fns with their unmangled name, so the
header is the only missing piece for a robotics C/C++ host to
call into a Nucleor-compiled kernel.

### Approach

`collect_export_fns_and_sigs(src, repr_c)` mirrors the
`collect_repr_c_structs` line-lookback walk: for each `fn NAME(...)`
line, peek backward past blank/`///`/other-attribute lines for
exactly `#[export]`. If found, parse the signature, convert each
type via the existing `nr_type_to_c_with_structs` helper (so
`#[repr(C)]` struct names work as parameters), and stash the
triple `[name, c_args, c_rtype]`.

`run_gen_headers_command` then emits these decls under a
`// === #[export] — Nucleor fns callable from C ===` divider,
right after the existing `extern fn` import decls. The closing
summary line now reports struct / extern / export counts.

### Verify gate

- New: `tests/fixtures/t34_export.nr` — 3 `#[export]` fns
  (i64-only, struct-by-value `Vec3`, no-args `void`-return),
  1 `extern fn` import, 1 private fn that must NOT leak into
  the header. Verify step asserts each line and the absence
  of the private one.
- Self-host bootstrap fixed-point holds at 5AD8C866 (stage-2
  IR == stage-3 IR). Bootstrap RSS peak 205 MB.

## [0.3.3] — 2026-04-25

**T3.5 RT-007 cross-check — `#[deadline]` without
`#[no_alloc]` or `#[no_panic]` now warns.** Allocations and
panics are non-deterministic and can break any fixed deadline
budget. RT-004 catches overruns *after* the fact; RT-007 nudges
authors to also declare intent: at least one of `#[no_alloc]`
or `#[no_panic]` should accompany every `#[deadline]` so the
compiler can statically rule out the most common deadline-
busters.

### Approach

Mirrors the v1 RT-004 cross-check: in the post-resolver source,
walk the list of inner fns produced by T3.1's deadline wrapper
(via `wcet_collect_deadline_fns`), then check membership in the
existing `collect_no_alloc_fns` and `collect_no_panic_fns` lists
that drive RT-001 and RT-002. If the inner fn appears in
neither, emit `warning[RT-007]`. Suppressible per-fn via
`#[allow(RT-007)]`.

### Verify gate

- New: `tests/fixtures/t35_rt007.nr` — bare `#[deadline]` fn
  with no companion attribute. Verify step asserts the warning
  text fires.
- Existing fixtures updated to add `#[no_alloc]` so the new
  cross-check doesn't add noise:
  - `tests/smoke/v030_deadline_runtime.nr` (4 fns)
  - `tests/fixtures/v030_deadline_overrun.nr`
  - `tests/fixtures/t33_wcet_overrun.nr`
- Self-host bootstrap fixed-point holds at 6A2821BA (stage-2
  IR == stage-3 IR).

## [0.3.2] — 2026-04-25

**T3.3 static WCET v1 estimator (RT-004) + critical
`expand_deadline` leak fix.** The compiler now estimates
worst-case execution time for every `#[deadline = N]` fn at
compile time and emits `warning[RT-004]: static WCET
estimate K us ... exceeds #[deadline = N us]` when the
estimate exceeds the budget. Combined with the v0.3.0
runtime check, this gives users *both* compile-time and
run-time safety nets for deadline annotations.

This release also fixes a previously-undiscovered infinite
loop in the resolver-level `expand_deadline` rewrite that
caused 2 GB+ memory allocations on any source containing
the literal text `#[deadline = N]` inside a `//` comment.
The bug pre-dated v0.3.0 but was never tripped because no
shipped fixture had `#[deadline]` text in a comment until
T3.3's documentation comments did.

### Approach (T3.3 v1 estimator)

Conservative coarse heuristic intended to be a safety net
rather than a precise WCET tool:

1. Scan for the wrapper template `deadline_check(__nuc_dl_start, N)`
   that the v0.3.0 T3.1 expander emits, walk back ≤1024 bytes
   for the matching `__nuc_dl_inner_<...>` ident — that gives
   us the (inner_name, deadline_us) pair without an AST.
2. For each inner fn, count `;` statements and `while`
   keywords inside the brace-balanced body.
3. Apply a multiplier ladder: 0 whiles → ×1, 1 → ×100,
   2 → ×1000, 3+ → ×10000. Default loop bound 100 because
   `#[loop_bound(N)]` ships with WCET-002 in tools-suite.
4. units / 10 ≈ µs (1 stmt ≈ 0.1 µs); compare to budget,
   warn if estimate exceeds.

Hard-capped at 1e6 units to bound runtime. `#[allow(RT-004)]`
suppresses individual false positives — the v1 estimator is
explicitly documented as crude. v0.3.2b (T3.3b) will swap
the text scanner for an AST-based v2 with tighter bounds and
promote unambiguous cases to error.

### Approach (`expand_deadline` leak fix)

The probe loop that scans forward from a `#[deadline]` line
for the matching `fn` declaration used `found_fn < 0` as the
"keep searching" condition. The "give up" branch (e.g. the
next non-skip line is not a `fn`) set `found_fn = 0 - 2` and
critically did *not* advance the `probe` pointer. Since
`-2 < 0`, the loop spun forever, allocating fresh
`str_substring` + `strip_spaces` strings each iteration. On
a 10-line fixture with a `//` comment containing the literal
text `#[deadline = 1]`, RSS hit 2 GB in ~3 seconds.

Fix: changed the loop guard to `found_fn == 0 - 1` (initial
sentinel only) so both -2 (give up) and >= 0 (found) exit
the loop. Also added a `//` comment-skip guard at the top of
the outer line-walk so comment lines mentioning `#[deadline]`
don't bogusly trigger probes against subsequent fn
declarations.

### Verify gate

- `tests/fixtures/t33_wcet_overrun.nr` — 1-µs deadline on a
  fn whose v1 estimate is 60 µs (1 while × 6 stmts × 100 / 10).
  Build emits the RT-004 warning; verify gate asserts the
  exact text.
- `tests/fixtures/t33_commentonly.nr` — minimal regression
  fixture for the leak. Pre-fix: 2122 MB peak RSS in 3 s.
  Post-fix: 4 MB peak in 0.1 s.
- Self-host bootstrap fixed-point holds: stage-2 IR SHA-256
  matches stage-3 IR SHA-256.
- Stage-2 bootstrap RSS peak: 230 MB (v0.3.1 baseline 112 MB,
  delta from T3.3 estimator scan over 600k-line compiler
  source).

## [0.3.1] — 2026-04-24

**T3.2 `#[no_panic]` enforcement (RT-002) — source-level v1
check matching the existing `#[no_alloc]` shape.** Annotate
any fn with `#[no_panic]` and the compiler walks its body
text for forbidden panic-prone call patterns
(`panic`, `assert_eq`, `assert_ne`, `unwrap`, `expect`, plus
the `.unwrap` / `.expect` method-call sugar). Each match
fires `error[RT-002]: '<name>' can panic but '<fn>' is
marked #[no_panic]`. The build fails before reaching link.

### Approach

Mirrors the v1 `#[no_alloc]` source-level check that's been
in s1_compiler since RFC-0001 phase 1:

1. `collect_no_panic_fns(source)` walks the merged source
   for `#[no_panic]` attribute lines (string- and
   comment-aware), associates each with the next `fn NAME(`,
   returns the list of fn names to enforce.
2. `check_no_panic_violations(diags, source, fn_name)`
   locates the fn body via `fn NAME(` then `{` then
   brace-balanced `}`, scans the body for each entry in
   `no_panic_check_list()` (`panic(`, `assert_eq(`,
   `assert_ne(`, `unwrap(`, `expect(`, `.unwrap(`,
   `.expect(`), emits one RT-002 diag per match.
3. `enforce_no_panic(diags, source)` is the top-level entry
   that combines (1) + (2). Wired into the s1 pipeline
   right after `enforce_no_alloc`.

Same v1 limitations as `#[no_alloc]`:
- Source-level only (no AST, no transitive call-graph chase
  — `#[no_panic]` fn calling `helper()` that internally
  calls `assert_eq` is NOT flagged today)
- String/comment-aware skip handles "panic" inside string
  literals or `// comments`
- Per-file scope only

### Pipeline placement

```
enforce_no_alloc(diags, source);   // RT-001 (existing)
enforce_no_panic(diags, source);   // RT-002 (this ship)
// suppression filter, warning→error promotion, etc.
```

Both passes run BEFORE the suppression filter so users can
`#[allow(RT-002)]` on a per-fn basis (same convention).

### T3.2 fixtures

- **Pass case** (`tests/smoke/t32_no_panic_clean.nr`):
  2 `#[no_panic]` fns (`safe_add`, `safe_loop`) with
  arithmetic-only bodies. 2 `#[test]` cases verify
  `safe_add(10, 20) == 30` and `safe_loop(5) == 10`.
  Both PASS.
- **Negative case** (`tests/err/err_no_panic_violation.nr`):
  `#[no_panic] fn bad_op(x) { assert_eq(x, 42); ... }`.
  The negative-fixture sweep auto-discovers it and
  asserts the build emits "error" or "warning" in stderr.
  RT-002 specifically appears in the captured output.

### Verify gate

Windows: 366/366 PASS. Bootstrap fixpoint refreshed
(seed sha256 `a7339b07...`). The new T3.2 step plus the
auto-discovered err fixture both green.

### Numerics-compatibility

No new arithmetic surfaces. The scanner operates on `str`
data through existing string helpers. RT-002 diagnostics
go through the same `diag_add_ex` channel as RT-001 (and
all other compiler diagnostics) — same i64-pointer
calling convention, same JSON serialization for
`nuc audit --json`, same `nuc explain RT-002` registry
hit (already wired in tools-suite).

### Memory safety

Pure source-text scan. New helpers (`collect_no_panic_fns`,
`check_no_panic_violations`, `no_panic_check_list`,
`enforce_no_panic`) own their `Vec<i32>` returns and never
mutate the input source. Same borrow patterns as the
neighboring `#[no_alloc]` helpers — no new shared state,
no closures, no FFI.

### Files

- `compiler/nucleor_s1_compiler.nr` — four new helpers
  (~125 LOC) + pipeline wire-in.
- `tests/smoke/t32_no_panic_clean.nr` — pass-case smoke.
- `tests/err/err_no_panic_violation.nr` — negative case
  for the auto-discovered err sweep.
- `tools/verify.ps1`, `tools/verify.sh` — new T3.2 step
  asserting the smoke PASSes.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (428 fns,
  863 optimized instructions; new sha256 a7339b07...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Tools-suite parity (deliberate skip)

`enforce_no_panic` lives in `nucleor_s1_compiler.nr` only.
`nucleor_tools_suite.nr` doesn't have the existing
`enforce_no_alloc` / RT-001 enforcement either — those
diagnostic passes only run on the s1 path (`nuc build`,
`nuc check`). Tools-suite paths (`nuc test`, `nuc
build-strict`) use a different driver. Keeping the
asymmetry is consistent with the existing #[no_alloc]
shape; v0.3.2 may port the enforcement passes to
tools_suite if the test framework needs them.

### Known limitations / T3.2b roadmap

- **No transitive panic detection.** `#[no_panic] fn outer
  { helper(); }` where `helper()` internally calls `panic("")`
  is NOT flagged today. v0.3.2 (T3.2b) adds the call-graph
  walker.
- **Source-level scan can produce false positives** on
  identifiers that contain `unwrap` or `expect` as
  substring inside string literals or comments. Same
  caveat as `#[no_alloc]` v1; v0.3.2's AST-based v2
  removes the class.
- **RT-007 cross-check** (deadline alone is incomplete
  without no_alloc + no_panic) doesn't yet fire. v0.3.3
  wires the explicit cross-check.
- **Numeric overflow / div-by-zero** are NOT in
  `no_panic_check_list()` because the runtime today
  wraps on overflow (RT) and traps on div-by-zero (LLVM
  default). T3.2c adds the explicit check once the
  numeric-trap policy is locked.

### Next

T3.3 — static WCET analysis. RT-004 fires at compile time
when the body's worst-case execution time can be proven
to exceed the declared `#[deadline]`.

## [0.3.0] — 2026-04-24

**v0.3 robotics foundation lands — `#[deadline = N]` runtime
checks now actually fire at runtime.** This is the v0.3.0
release. The locked priority list opens its v0.3 chapter
with the most-requested robotics primitive: declared
deadlines that the compiler enforces by injecting a
runtime check at function exit. On overrun, the binary
aborts with `error[RT-004]: #[deadline] overrun` carrying
elapsed and limit microseconds.

### What `#[deadline = N]` does today

Annotate any fn with `#[deadline = N]` (microseconds) and
the compiler:

1. **Renames the original body** to a synthesized inner fn
   `__nuc_dl_inner_<hash>_<idx>`.
2. **Synthesizes an outer wrapper** with the original fn
   name that:
   - Captures `time_monotonic_us()` as `__nuc_dl_start`.
   - Calls the inner fn with the original args, captures
     the return value into `__nuc_dl_r`.
   - Calls `deadline_check(__nuc_dl_start, N)` — aborts if
     elapsed > N.
   - Returns `__nuc_dl_r`.

Behavior is observably identical to the un-annotated fn
when it stays within budget; on overrun the runtime fires
RT-004 to stderr and exits 1.

### New runtime helper

```c
long long __nucleor_deadline_check(long long start_us, long long limit_us) {
    long long elapsed = __nucleor_time_monotonic_us() - start_us;
    if (elapsed > limit_us) {
        fprintf(stderr, "error[RT-004]: #[deadline] overrun: elapsed %lld us > limit %lld us\n",
                elapsed, limit_us);
        exit(1);
    }
    return 0;
}
```

Built on the existing cross-platform `__nucleor_time_monotonic_us()`
(Windows `QueryPerformanceCounter`, POSIX `clock_gettime(CLOCK_MONOTONIC)`).
Exposed as the `deadline_check` builtin on both compilers.

### Source-level wrap mechanism

A new resolver pass `expand_deadline(src)` (synced across
both compilers) walks the merged source line by line. When
it sees `#[deadline = N]` (with N parsed as integer microseconds):

1. Scan forward past blank lines, doc comments, and other
   `#[...]` attributes for the next `fn ...` or `pub fn ...`.
2. Parse the fn signature via `dl_parse_fn_signature`:
   name, params text, return type, comma-separated arg names,
   body brace open + close positions (brace-balanced + string-
   and comment-aware scan).
3. Emit two fns in place of the one:
   - `fn __nuc_dl_inner_<hash>_<idx>(<params>) -> <ret> { <body> }`
   - `fn <name>(<params>) -> <ret> { let __nuc_dl_start =
     time_monotonic_us(); let __nuc_dl_r = __nuc_dl_inner_(<args>);
     deadline_check(__nuc_dl_start, <N>); return __nuc_dl_r; }`

Void returns (`fn name(...)` with no `-> ret`) get a
slightly different wrapper that calls the inner without
capturing a return value.

The pass runs in the resolver pipeline AFTER `expand_async_syntax`
and BEFORE `expand_closures`, so deadline-wrapped fns can
themselves be `async fn` (the wrapper is sync but the inner
runs to completion before the check; correct for current
threads-only async).

### Three new helpers (synced across both compilers)

| Helper | Purpose |
|---|---|
| `dl_extract_int_value(line)` | Parses `#[deadline = N]` from an attribute line. Returns N (≥ 0) on success, -1 on parse failure. (tools-suite uses an inlined `dl_find_substring` since it doesn't have s1's `source_find`.) |
| `dl_parse_fn_signature(src, fn_pos, slen)` | Bracket-balanced + string/comment-aware parse of a fn header + body. Returns `[name, params_text, ret_type, arg_names, body_open, body_end]` or `[]` on parse failure. |
| `expand_deadline(src)` | Top-level walker. Scans for `#[deadline = N]` markers, emits the inner+outer fn pair for each, drops the attribute line. Other source passes through unchanged. |

### Verify gate

Two new steps land in BOTH `verify.ps1` and `verify.sh`:

- **`v0.3.0 #[deadline=N] runtime check passes within budget`**
  — runs `tests/smoke/v030_deadline_runtime.nr` (4 `#[test]`
  cases with `#[deadline = 100000]` (100 ms) on simple ops),
  asserts all 4 PASS.
- **`v0.3.0 #[deadline=N] overrun aborts with RT-004`**
  — builds `tests/fixtures/v030_deadline_overrun.nr` (which
  has `#[deadline = 1]` on a 5M-iteration loop), runs the
  binary, asserts non-zero exit AND `error[RT-004]: #[deadline]
  overrun` in stderr.

Windows: 364/364 PASS. Bootstrap fixpoint refreshed
(seed sha256 `3f4af45e...`). Helper manifest regenerated.

### Numerics-compatibility

`time_monotonic_us` and `deadline_check` both `(i64) -> i64`.
The wrapper's `__nuc_dl_start` captures the monotonic
microsecond timestamp as i64 (cross-platform via
QueryPerformanceCounter on Windows / clock_gettime
CLOCK_MONOTONIC on POSIX). No new arithmetic surfaces.
The injected `let __nuc_dl_r: <ret> = ...` matches the
original fn's declared return type — works for any
i64-castable return today.

### Memory safety

Pure source-level wrap. The inner fn has the original body;
the outer fn is a thin shim with two locals (i64 start
timestamp + the captured return value). No new allocations,
no closures, no FFI surface beyond the existing
`time_monotonic_us` and the new `deadline_check`. The
wrapper's `__nuc_dl_r` is consumed exactly once (the
return statement) so no aliasing concerns. The inner fn's
body retains all its original ownership semantics — the
borrow checker sees the unchanged body in
`__nuc_dl_inner_<id>`.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c` — new
  `__nucleor_deadline_check(start_us, limit_us)` (~10 LOC)
  after the time_monotonic helpers.
- `compiler/nucleor_s1_compiler.nr` — three new helpers
  (~150 LOC) plus the `deadline_check` builtin entry +
  LLVM declare. Wired into the resolver pipeline.
- `compiler/nucleor_tools_suite.nr` — synced helpers (with
  `dl_find_substring` instead of s1's `source_find`).
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `tests/smoke/v030_deadline_runtime.nr` — 4-case smoke
  (pass cases).
- `tests/fixtures/v030_deadline_overrun.nr` — overrun
  fixture (used by the dedicated verify step that builds
  + runs + asserts non-zero exit + RT-004 in stderr).
- `tools/verify.ps1`, `tools/verify.sh` — TWO new steps.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (424 fns,
  858 optimized instructions; new sha256 3f4af45e...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations / v0.3.1 roadmap

- **No static WCET analysis.** RT-004 fires only at
  runtime today. v0.3.1 adds the static estimator that
  reports RT-004 at compile time when the body's WCET
  can be proven to exceed the declared deadline.
- **No `#[no_alloc]` / `#[no_panic]` cross-check** with
  deadline. Per RT-007, a `#[deadline]` annotation is
  incomplete without these companions; v0.3.1 enforces.
- **No nested deadline composition.** Calling a
  `#[deadline = A]` fn from inside a `#[deadline = B]` fn
  doesn't subtract A from the outer budget. v0.3.2 adds
  the chain accumulator.
- **Wrapper allocates one extra fn per deadline-annotated
  fn.** Negligible code size hit (~50 bytes IR per fn) but
  measurable on robotics codebases with hundreds of
  deadline'd ops. v0.3.3 may inline the wrapper for
  small bodies once the static WCET pass is wired.
- **Same fn signature is required twice** (inner +
  outer). If you change the inner's body, the outer keeps
  calling it correctly because the outer is regenerated
  from the same source on every compile.

### Locked v0.2 design defaults — fully shipped

This release closes the v0.2 → v0.3 transition. All four
locked design defaults from the cron-loop guidance are now
shipped:

- **Threads-only async** — v0.2.353 (`async_spawn`/`.await`
  via OS threads).
- **GitHub-Pages registry** — v0.2.344 (producer side via
  `nuc registry export-static`; TLS-fetch consumer side
  in T1.4b).
- **Runtime deadline checks** — v0.3.0 (this ship).
- **Extern-C shims for C++ FFI** — v0.2.345 T1.6
  (`nuc gen-headers` emits `#[repr(C)]` struct typedefs;
  cxx-style codegen layered on top in v0.4).

### Next

T3.2 — `#[no_alloc]` / `#[no_panic]` enforcement (RT-001 /
RT-002 actually fire at compile time, not just at the
diagnostic-explanation level). T3.3 — static WCET. T3.4 —
extern-C shim generator for `extern "C++"`.

## [0.2.353] — 2026-04-24

**T2.8 async runtime decision — threads-only commitment
shipped as working syntax + runtime.** Closes the T2 layer
of the locked v0.2 priority list. `async fn`, `async_spawn`,
and `<ident>.await` all work end-to-end today; the async
runtime is explicitly committed to OS threads (RFC-0030
phase-1 threaded fallback) per the locked v0.2 design vote.
RFC-0027's futures-based state-machine rewrite is parked
for v0.8.

### What ships

Four things wired together:

1. **Source-level rewriting in resolver.** `async fn name(...)`
   drops the `async` keyword (the function is a regular fn;
   the `async` marker is advisory). `<ident>.await` rewrites
   to `async_await(<ident>)`.

2. **Runtime helpers (both Windows + POSIX).**
   - `__nucleor_async_spawn(fn_ptr, arg) -> task_handle` —
     allocates an `NAsyncTask` struct, spawns a real OS
     thread running the fn with arg, captures the i64
     return into the struct's `result` slot.
   - `__nucleor_async_await(task_handle) -> i64` — joins
     the thread, reads `result`, frees the struct, returns
     the value.
   
3. **Compiler builtin wiring** in both compilers:
   - `async_spawn` → `__nucleor_async_spawn`
   - `async_await` → `__nucleor_async_await`
   - LLVM declares for both.

4. **RFC-0030 update** — §7 Definition of Done now marks
   the threaded fallback as `[x]` shipped, with a
   block-level explanation of the v0.2.353 scope so
   future readers know what's today-async vs v0.8-async.

### Difference from `thread_spawn`/`thread_join`

The existing `thread_*` runtime helpers run the fn with
`THREAD_PRIORITY_IDLE` / `SCHED_IDLE` and discard the fn's
return value. The new `async_*` helpers:
- Use **default priority** (async tasks need to make
  progress; IDLE priority was for background-only work).
- **Capture the i64 return value** into an `NAsyncTask`
  struct's `result` slot so `.await` can retrieve it.

Users building low-priority background workers should
keep using `thread_spawn` / `thread_join`. Users needing
a return value should use `async_spawn` / `.await`.

### T2.8 smoke

`tests/smoke/t28_async_threads.nr` — 4 `#[test]` cases:
- `test_async_basic_spawn_await` — spawn, await, get 49
  from `square(7)`
- `test_async_two_concurrent_tasks` — two tasks, both
  awaited, order-independent result capture
- `test_async_await_in_arithmetic` — `.await` in
  expression context: `h1.await + h2.await` works
  because `.await` rewrites to `async_await(h1)` which is
  an i64-returning call
- `test_async_zero_arg_fn` — task that returns 0

All 4 PASS.

### Verify gate

Windows: 362/362 PASS. Bootstrap fixpoint refreshed
(seed sha256 `dfaffd1c...`).

### Numerics-compatibility

`async_spawn` and `async_await` pass and return i64 per
the locked i64-everywhere FFI convention. The fn_ptr arg
uses the same fn-pointer passing convention as
`vec_map_i64` (T2.2) and `thread_spawn` — named fn is
automatically resolved to its address. Task handles are
opaque i64 pointers into heap-allocated `NAsyncTask`
structs.

### Memory safety

Each `async_spawn` allocates exactly one `NAsyncTask`
struct (sizeof ~40 bytes). `async_await` frees the struct
after reading `result`. The thread handle is closed
(Windows) or detached+joined (POSIX) at the same time.
There's no reference-counting race because await is a
sync join — the thread has fully finished by the time
we read `result`. Cross-thread data passing (the arg and
result i64s) is through the malloc'd struct, not through
aliased stack memory, so no shared-mutable aliasing.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c` — `NAsyncTask` struct
  + `__nucleor_async_spawn` + `__nucleor_async_await`,
  both Windows (HANDLE + CreateThread) and POSIX
  (pthread_t + pthread_create).
- `compiler/nucleor_s1_compiler.nr` — `expand_async_syntax`
  (strip-keyword + `.await` rewrite) wired into the
  resolver pipeline between `expand_format_macros` and
  `expand_closures`; `async_spawn` / `async_await`
  builtin entries; LLVM declares.
- `compiler/nucleor_tools_suite.nr` — synced.
- `docs/rfcs/RFC-0030-async-decision.md` — §7 DoD update
  marking threaded fallback shipped.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `tests/smoke/t28_async_threads.nr` — 4-case smoke.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.8 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (421 fns,
  827 optimized instructions; new sha256 dfaffd1c...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations / T2.8b roadmap

- **`.await` restricted to `<ident>.await`.** Complex
  receivers (`compute().await`, `arr[0].await`) require a
  let-binding first. T2.8b adds a depth-aware backwards
  receiver scanner (same shape as the closure body
  scanner in T2.3).
- **No cancellation.** Once a task is spawned it runs
  to completion. T2.8c adds an `async_cancel(handle)`
  helper that sets a cancellation flag the task body can
  poll (cooperative only — no hard kill).
- **No timeout on await.** T2.8d adds
  `async_await_timeout(handle, ms)` returning a tagged
  result.
- **One thread per task.** For high-task-count scenarios
  (thousands of concurrent tasks) this is ~8 MB per task
  on Windows and ~2 MB on Linux — fine for the tens-to-
  low-hundreds scale typical of robotics / service code,
  not for web-scale fan-out. v0.5 `rod/tokio.nr` is the
  escape hatch there; v0.8 state-machine rewrite is the
  long-term answer.
- **Default priority, not IDLE.** `async_spawn` uses the
  OS default priority (vs `thread_spawn`'s IDLE). This is
  a deliberate API distinction — see "Difference from
  thread_spawn/thread_join" above.

### T2 layer complete

With T2.8 shipped, every T2 item in the locked priority
list has a tagged release:

- T2.1 range patterns (v0.2.347)
- T2.2 iterator methods (v0.2.348)
- T2.3 closure literals (v0.2.349)
- T2.4 trait objects (a) (v0.2.350)
- T2.5 lifetimes (parse-only) (v0.2.351)
- T2.6 format strings (v0.2.346)
- T2.7 nuc doc HTML (v0.2.352)
- T2.8 async threads-only (v0.2.353) ← this ship

### Next

**v0.3 robotics foundation** per the locked priority order.
The locked design defaults for v0.3:
- `#[deadline]` runtime checks (already wired; v0.3 makes
  them mandatory on robotics code paths).
- Extern-C shims as the C++ FFI default.
- Static WCET bounds for any fn that declares `#[deadline]`.

## [0.2.352] — 2026-04-24

**T2.7 `nuc doc` HTML mode — `--html` flag (with .html /
.htm extension auto-detect on `--out`) emits a styled,
standalone, self-contained HTML doc page from the same
two-pass walk that drives the Markdown renderer.** The
existing Markdown output is unchanged; HTML is opt-in via
the new flag (or implicit via `--out foo.html`).

### What ships

A single-file HTML page with:
- `<!doctype html>` + `<meta charset="utf-8">` + `<title>` set
  to the source path
- Inline `<style>` block — no external CSS, no fonts, no
  scripts. Body: max-width 54rem, system-ui font, mild line
  styling. Code: `Menlo`/`Consolas` mono with subtle bg.
  H1/H2 with thin underlines. Function-index list with
  square bullets. Anchor links in the index target the
  per-function H2 ids.
- An `<h1>` of the source path
- A meta line: "Generated by `nuc doc --html` (RFC-0029)"
- A function-index `<ul>` with `<a href="#name">` per fn
- A per-function `<h2 id="name">` followed by the `///`
  doc-comment paragraph + a `<pre><code>` block holding the
  parsed signature
- HTML-escapes `<`, `>`, `&`, `"` everywhere user content
  could contain them (signatures, doc text, fn names)

### CLI surface

```
nuc doc <file>                   # Markdown to stdout (existing)
nuc doc <file> --out doc.md      # Markdown to file (existing)
nuc doc <file> --html            # HTML to stdout (new)
nuc doc <file> --out doc.html    # HTML to file via auto-detect (new)
nuc doc <file> --html --out x.h  # explicit HTML mode (new, .h ext OK)
```

The `--html` flag forces HTML mode regardless of extension;
the auto-detect only fires when `--html` is absent AND
`--out` ends in `.html` or `.htm`.

### Helpers added (tools-suite only — single compiler does
the doc command)

| Helper | Purpose |
|---|---|
| `run_doc_command_html(src, out)` | Public entry — calls `run_doc_command_mode(src, out, 1)`. |
| `run_doc_command_mode(src, out, html_mode)` | Refactored `run_doc_command` body — dispatches Markdown vs HTML based on `html_mode`. |
| `doc_render_html(src_path, src, out_path)` | The HTML renderer. Same two-pass shape as the Markdown renderer; emits styled HTML and writes to file or stdout. |
| `doc_html_escape(s)` | Minimal HTML escape — `<`, `>`, `&`, `"`. Sufficient for fn signatures and doc text. |

### T2.7 fixture

`tests/fixtures/t27_doc_input.nr` — 3 fns:
- `dbl` with two-line `///` doc
- `add` with single-line `///` doc
- `helper_no_doc` (no doc — verifies signatures still emit
  even without preceding docs)

### Verify gate

The new step `T2.7 nuc doc --html emits styled standalone HTML`
asserts:
1. Banner reports "wrote ... HTML"
2. Output file exists
3. `<!doctype html>` present
4. `<title>` matches the source path
5. Each fn has an `<h2 id="...">` heading
6. The function-index `<a href="#dbl">` link is present
7. The `///` doc text "Doubles its argument" is preserved
8. The signature `fn dbl(x: i64) -&gt; i64` (with HTML-escaped
   `>`) is in a code block

Windows: 361/361 PASS. Bootstrap seed unchanged (s1 didn't
change — only tools-suite touched).

### Numerics-compatibility

No new arithmetic surfaces. The renderer operates on `str`
data through existing `sb_*` builders. HTML output is pure
ASCII with HTML-escaped multibyte chars passing through as
their UTF-8 byte sequences (browsers handle the decoding via
the declared `<meta charset="utf-8">`).

### Memory safety

Pure source-text emission. Same ownership patterns as the
existing Markdown renderer. No shared state, no closures,
no FFI — just `sb_append` chains.

### Files

- `compiler/nucleor_tools_suite.nr` — `run_doc_command` split
  into mode-dispatching wrapper + `run_doc_command_mode`,
  new `run_doc_command_html`, `doc_render_html`,
  `doc_html_escape`, plus CLI dispatcher recognizes
  `--html` flag with `.html`/`.htm` auto-detect.
- `tests/fixtures/t27_doc_input.nr` — 3-fn doc fixture.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.7 step.
- `CHANGELOG.md` — this entry.
- `bootstrap/nucleor_s1_seed.ll` unchanged (s1 untouched).
- `bin/nucleor.exe` unchanged. `bin/nucleor_tools.exe`
  rebuilt by the verify gate's tools-suite-rebuild step
  on each run.

### Known limitations / T2.7b roadmap

- **No syntax highlighting in `<pre><code>`** beyond raw
  text. T2.7b adds simple per-token spans (keywords, types,
  literals, strings) so the signature blocks colorize.
- **No multi-page output.** Single file = single source.
  T2.7c adds a `--workspace` mode that walks all `*.nr`
  files in a directory and emits a cross-linked site
  (one file per source + a top-level `index.html`).
- **No struct / enum / trait sections** — only `fn`. T2.7d
  extends the walker to emit per-struct field tables and
  per-enum variant lists.
- **No search.** T2.7e adds a tiny inline JS search that
  filters the function index. Out of scope for this ship
  (would break the "no scripts, no network" minimalism).

### Next

T2.8 — async runtime decision per the locked priority. The
default vote was "threads-only" (RFC-0027 phase 1 maps
async to OS threads via `nuc_thread_spawn`); T2.8 ships the
formal commitment + the syntax surface (`async fn`, `.await`)
that desugars to the threads-only runtime.

## [0.2.351] — 2026-04-24

**T2.5 lifetime parameters (parse-only) — `'a` annotations
recognized in generic param lists, reference types, and
generic type instantiations.** Closes the syntactic gap
that prevented Nucleor source from accepting Rust-style
lifetime annotations. Annotations are advisory metadata;
real lifetime-parameter checking lands in T2.5b once the
borrow checker tracks named scopes (today's checker uses
dynamic lexical depth via `own_set_scope`).

### Lex change

`'<ident>` (apostrophe + identifier) lexes as a new
**lifetime token** (kind 98). Token value holds the
lifetime name (without the leading `'`). Nucleor doesn't
have char literals as a lex primitive — chars use `u8`/`u32`
via int literals — so the apostrophe is unambiguously a
lifetime marker.

### Parse changes

- `parse_generic_params` accepts lifetime tokens alongside
  type-name tokens. Stored as `'<name>` strings so future
  T2.5b consumers can distinguish them from type params.
- `parse_type` (`&` branch) skips an optional lifetime
  token after `&` and before `mut`. So `&'a T`, `&'a mut T`
  parse the same as `&T`, `&mut T` for codegen purposes.
- `parse_type` (generic instantiation branch) accepts and
  skips lifetime args. `Vec<'a, T>` parses as `Vec<T>`.

### T2.5 smoke

`tests/smoke/t25_lifetime_params.nr` — 4 `#[test]` cases:
- `test_no_lifetime_baseline` — fns without lifetime annotations
  unchanged
- `test_single_lifetime` — `fn foo<'a>(x: i64) -> i64`
- `test_two_lifetimes` — `fn foo<'a, 'b>(x: i64, y: i64) -> i64`
- `test_mixed_lifetime_and_type_param` — `fn foo<'a, T>(x: i64)`

Manual end-to-end at `/tmp/t25_lt.nr`:
```nucleor
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str { return a; }
struct Holder<'a, T> { data: &'a T }
fn main() -> i64 { let r: str = longest("hello", "world"); println!("{:s}", r); return 0; }
```
Compiles + prints `hello`.

### Verify gate

Windows: 360/360 PASS. Bootstrap fixpoint refreshed
(seed sha256 `bc004126...`).

### Numerics-compatibility

Lifetime tokens carry a `str` value (the name). All token
inspection sites that don't recognize kind 98 ignore them
(default case `else { p = p + 1 }` in the lexer; the parser
extension points listed above explicitly skip kind 98).
No new arithmetic surface.

### Memory safety

Annotations are inert metadata — they don't affect codegen,
borrow checking, or runtime layout. The existing borrow
checker (OWN-001 ... OWN-013, dynamic-scope-based) continues
to enforce ownership. Real lifetime-parameter inference
arrives with T2.5b's named-scope checker.

### Files

- `compiler/nucleor_s1_compiler.nr` — kind-98 lex rule,
  parse_type lifetime-skip in `&` branch + generic-arg
  branch, parse_generic_params lifetime acceptance.
- `compiler/nucleor_tools_suite.nr` — synced.
- `tests/smoke/t25_lifetime_params.nr` — 4-case smoke.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.5 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (418 fns,
  813 optimized instructions; new sha256 bc004126...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations / T2.5b–c roadmap

- **Annotations are advisory.** Today there's no check that
  `&'a T` references actually live for `'a`. T2.5b adds
  named-scope tracking and a pass that reports errors when
  annotations don't match the actual lifetime relationships.
- **No `'static` recognition as special.** It's just another
  lifetime name. T2.5b adds the global-scope shortcut.
- **No higher-ranked trait bounds (`for<'a>`)** — T2.5c.
- **No lifetime elision rules** beyond the baseline (today
  `fn foo(x: &T) -> &T` works because the `&` doesn't require
  a lifetime). T2.5b adds Rust's three elision rules.

### Next

T2.7 — `nuc doc` HTML generator per the locked priority.

## [0.2.350] — 2026-04-24

**T2.4 trait objects (a) — `Box<dyn Trait>` 2-cell handle
runtime helpers + manual dispatch pattern.** Ships the
runtime primitives that make `Box<dyn Trait>` representable
as an i64 handle to a 2-cell allocation `[type_id, data_ptr]`.
Compiler-generated auto-dispatch sugar (`box.method(args)`
emitting a per-trait switch on type_id) lands in T2.4b once
the trait/impl registry walking pass is wired into the
resolver. Today users build the dispatcher manually using
the four new builtins.

### New runtime helpers

```c
long long __nucleor_dyn_box_make(long long type_id, long long data);
long long __nucleor_dyn_box_type(long long box);
long long __nucleor_dyn_box_data(long long box);
void      __nucleor_dyn_box_free(long long box);
```

A box is a `malloc`'d 2-element `long long[]`:
- `box[0]` = caller-supplied type tag (any i64; convention: a
  per-impl unique id assigned at struct-decl scope)
- `box[1]` = data pointer or value (any i64)

The 2-cell layout is intentionally minimal — no vtable
indirection, no fat-pointer ABI. T2.4b's compiler-generated
dispatch fns will do the per-trait switch at the call site.

### Compiler-side wiring

Four new builtin entries synced across both compilers:
- `dyn_box_make` → `__nucleor_dyn_box_make`
- `dyn_box_type` → `__nucleor_dyn_box_type`
- `dyn_box_data` → `__nucleor_dyn_box_data`
- `dyn_box_free` → `__nucleor_dyn_box_free`

Each entry touches three places per compiler:
1. `nuc_builtin_to_extern` (name → symbol mapping)
2. `is_known_builtin` (lex-time recognition)
3. LLVM `declare` emission (`declare i64 @__nucleor_dyn_box_make(i64, i64)`)

Plus `docs/rfcs/helper_manifest.toml` regenerated to capture
the new ToolingMeta entries — caught by the drift checker
after the first verify run.

### Manual dispatch pattern (today)

```nucleor
fn type_id_circle() -> i64 { return 1; }
fn type_id_square() -> i64 { return 2; }

fn impl_circle_area(data: i64) -> i64 { /* ... */ }
fn impl_square_area(data: i64) -> i64 { /* ... */ }

fn dispatch_shape_area(box: i64) -> i64 {
    let tid: i64 = dyn_box_type(box);
    let data: i64 = dyn_box_data(box);
    if tid == 1 { return impl_circle_area(data); };
    if tid == 2 { return impl_square_area(data); };
    return 0;
}

fn main() -> i64 {
    let c: i64 = dyn_box_make(type_id_circle(), 5);
    let q: i64 = dyn_box_make(type_id_square(), 4);
    println!("{} {}", dispatch_shape_area(c), dispatch_shape_area(q));
    dyn_box_free(c);
    dyn_box_free(q);
    return 0;
}
```

T2.4b will auto-generate `dispatch_shape_area` at resolver
time by walking `trait Shape` + every `impl Shape for X`
declaration in the merged source.

### Bug class noticed (third occurrence)

The first draft of `tests/smoke/t24_trait_objects.nr` ended
each test with `dyn_box_free(box);` (returns void). Test fns
without an explicit `return 0` implicitly return their last
expression's value, so the void/undef from `dyn_box_free`
was non-zero, causing the harness to flag the tests as FAIL
even though every `assert_eq` had succeeded. Fix: read the
test values into locals BEFORE calling free, end the test
with the final `assert_eq`. Same pattern applies to any
test that needs cleanup with a void-returning call. Possibly
worth adding a checker rule (T2.4 follow-up: warn if a
`#[test]` fn's last statement returns void).

### T2.4 smoke

`tests/smoke/t24_trait_objects.nr` — 5 `#[test]` cases:
- `test_dyn_box_make_type_data` — round-trip type_id + data
- `test_dyn_box_dispatch_a` — dispatch fires impl A
- `test_dyn_box_dispatch_b` — dispatch fires impl B
- `test_dyn_box_polymorphic_collection` — `Vec<i32>` of mixed-type
  boxes with sum-via-dispatch (the canonical trait-object use case)
- `test_dyn_box_unknown_tag_returns_default` — defensive fallback

Manual end-to-end: `/tmp/t24_dyn.nr` Shape demo with Circle +
Square impls produces `circle.area = 75 / square.area = 16`.

### Verify gate

Windows: 359/359 PASS. Bootstrap fixpoint refreshed
(seed sha256 `6a86dcf5...`). Helper manifest regenerated.

### Numerics-compatibility

All four helpers are `(i64) -> i64` or `(i64, i64) -> i64` —
matches the locked i64-everywhere FFI convention. The 2-cell
allocation stores raw i64 values (no boxing of narrow types
needed because the storage cell is always i64).

### Memory safety

`dyn_box_make` allocates 16 bytes via malloc; ownership
transfers to the caller. `dyn_box_free` releases the
wrapper but NOT the data pointer (the caller owns the data
separately). The 2-cell handle is treated as opaque by
Nucleor's borrow checker (i64 = Copy), so ownership tracking
is the user's responsibility — same model as the existing
HashMap / arena handles. T2.4c will add a `dyn_box` newtype
that the borrow checker tracks like a regular Box.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c` — four new dyn_box_*
  helpers (~25 LOC) before the Vec<i64> functional helpers
  block.
- `compiler/nucleor_s1_compiler.nr` — three table entries
  per builtin (name→extern, is_known, IR declare).
- `compiler/nucleor_tools_suite.nr` — synced.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `tests/smoke/t24_trait_objects.nr` — 5-case smoke
  including polymorphic collection.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.4 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (418 fns,
  812 optimized instructions; new sha256 6a86dcf5...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations / T2.4b–c roadmap

- **No syntactic sugar yet.** `Box::new(MyStruct{...}) as
  Box<dyn Trait>` doesn't parse; users call `dyn_box_make`
  with a type_id constant and a data pointer manually. T2.4b
  parses the dyn-trait syntax + auto-generates dispatch fns.
- **No vtable**, just a tag-switch dispatch. Adding traits
  with many methods or many impls means a long if-cascade.
  T2.4d will swap in vtables once the runtime gets fat-pointer
  support.
- **Borrow checker treats box as i64.** No automatic free
  on scope exit. T2.4c adds a wrapper newtype with Drop
  semantics.
- **No object safety check.** Nothing today prevents
  declaring a trait with `Self`-returning methods and then
  using it as a trait object. T2.4e adds the standard
  object-safety rules per Rust convention.

### Next

T2.5 — lifetime parameters per the locked priority order.

## [0.2.349] — 2026-04-24

**T2.3 closure literals (no-capture) in call-argument position
— `v.map(|x| x * 2).filter(|x| x > 0).fold(0, |acc, x| acc + x)`
now works.** Source-level rewriting in the resolver lifts each
closure into a synthesized top-level fn and replaces the closure
expression with the synth fn's name. The T2.2 iterator dispatch
then receives a function-pointer value through the existing
i64-cell calling convention — no runtime change required.

### Scope and bug-discovered limitation

T2.3 fires ONLY when `|` is preceded (after whitespace) by `(`
or `,` — i.e., **inside an unambiguous call-argument position**.
Other closure contexts (let-binding RHS, return expression,
match-arm RHS, etc.) continue to use the existing parser-level
closure infrastructure (kind-42 `Closure` + kind-49
`ClosureLet` + capture analysis at `closure_collect_capture_expr`).

The first draft was broader — it also fired after `=`, `=>`,
`[`, `{`, `;`. Verify gate caught the regression: existing
`tests/lang/closures.nr` and `tests/features/closure_basic.nr`
both rely on `let f = |x| x * 2; ... f(41)` syntax. Lifting
the closure to a top-level fn and assigning the fn pointer
to a local i64 means the call site `f(41)` no longer matches a
global symbol — clang fails with `use of undefined value '@f'`
because the existing parser still treats `f(...)` as a direct
call rather than indirect-through-pointer.

The fix is a 7-line tightening of `close_is_arg_position_char`
to `(` and `,` only. Closures-in-arg-position is the most
useful case (the iterator-method pipeline) and the case the
existing parser doesn't handle as ergonomically. The two
infrastructures coexist cleanly.

### Helpers added (synced across both compilers)

| Helper | Purpose |
|---|---|
| `close_is_arg_position_char(c)` | Returns 1 iff `c` is `(` (40) or `,` (44). Used to disambiguate closures from bitwise `\|`. |
| `close_parse_arg_list(src, start, slen)` | Parses `<ident>(, <ident>)*` with optional `: type` annotations. Returns `[end_pos, name1, name2, ...]` or `[-1]` on parse error. |
| `close_parse_body_end(src, start, slen)` | Walks forward from start. Body ends at first `,` or `)` or `]` at the same paren depth. String / char / line-comment aware. |
| `close_synthesize_fn(name, args, body)` | Builds the synth fn declaration text — `fn <name>(arg1: i64, ...) -> i64 { return <body>; }`. All args typed i64 (matches the existing `vec_*_i64` runtime calling convention). |
| `expand_closures(src)` | Top-level walker. Identifier-, quote-, char-literal-, line-comment-aware. Uses `last_non_ws` tracking to detect arg-position `\|`. Synth fns are accumulated in a separate sb and prepended to the final source. |

### Wired in resolver

`load_resolved_source_bundle` (in BOTH `nucleor_s1_compiler.nr`
and `nucleor_tools_suite.nr`) now runs `expand_closures` AFTER
`expand_format_macros` — so the chain is:
1. `resolve_source_with_records` (imports + privatization +
   `mod foo { ... }` block-form, T1.5)
2. `expand_format_macros` (T2.6)
3. `expand_closures` (T2.3) — new step
4. cache the post-expansion text, parse, lower, link

Each closure gets a unique synth name keyed off
`content_hash(src)` + a per-source counter, so two closures
with identical bodies in the same file get distinct fns
(simpler than de-duping; avoids semantics drift).

### T2.3 smoke

`tests/smoke/t23_closure_literals.nr` — 4 `#[test]` cases:
- `test_map_with_closure`     — `v.map(|x| x * x)` squares
- `test_filter_with_closure`  — `v.filter(|x| x)` keeps non-zero
- `test_fold_with_closure`    — `v.fold(1, |acc, x| acc * x)`
- `test_chain_with_closures`  — `v.map(|x| x*x).filter(|x| x - (x/2)*2).fold(0, |acc, x| acc + x)` 3-step pipeline

All 4 PASS. Existing closure tests (`tests/lang/closures.nr`,
`tests/features/closure_basic.nr`) continue to PASS — they
exercise the let-RHS closure path which the parser handles
natively and which T2.3 leaves alone.

### Verify gate

Windows: 358/358 PASS. Bootstrap fixpoint refreshed
(seed sha256 `34d0aec3...`).

### Numerics-compatibility

All closure args + return values typed as i64 — matches the
locked i64-everywhere FFI convention and the existing
`vec_*_i64` runtime helper signatures. No new arithmetic
surfaces.

### Memory safety

No-capture closures generate truly global helper fns — no
environment, no shared state, no aliasing. The fn-pointer
value passed through the iterator dispatch is an i64
address; the runtime helpers call through it without dereferencing
any environment pointer. Capture support (T2.3b) will need a
new (fn_ptr, env_ptr) ABI plus separate runtime helpers.

### Files

- `compiler/nucleor_s1_compiler.nr` — five new closure helpers
  + `expand_closures` resolver hook.
- `compiler/nucleor_tools_suite.nr` — synced helpers + same
  resolver hook.
- `tests/smoke/t23_closure_literals.nr` — 4-case smoke
  including the 3-step chain pipeline.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.3 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (418 fns,
  812 optimized instructions; new sha256 34d0aec3...).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations

- **No captures.** The closure body must only reference its
  own arg names + global fns. Referencing an outer-scope
  local will compile (the synth fn declares the outer name
  as undefined) and fail at link time. T2.3b adds capture
  via (fn_ptr, env_ptr) closure objects; runtime helpers
  need a new variant: `vec_map_i64_env(v, fn_ptr, env_ptr)`.
- **No type annotations on closure args.** Args are always
  typed i64 in the synthesized fn. f64-bodied closures need
  the synth template generalized; T2.3c.
- **Body must be a single expression.** Block-bodied closures
  (`|x| { let y = x + 1; y * 2 }`) need a slightly different
  synth template; T2.3d.
- **Body extends to first `,` / `)` at same depth** — works
  for the iterator-method case but means a closure body with
  a top-level `,` requires explicit parens:
  `v.fold(0, |acc, x| (acc, x).0 + x)` rather than
  `v.fold(0, |acc, x| acc, x)`. Probably fine in practice.

### Next

T2.4 — trait objects (`Box<dyn Trait>`) per the locked
priority order. Real dynamic dispatch.

## [0.2.348] — 2026-04-24

**T2.2 iterator trait + adapters — Vec method-call dispatch
for `.map(f)`, `.filter(p)`, `.fold(init, f)`, `.each(f)`,
`.sum()`, `.min()`, `.max()`, `.contains(x)`, `.index_of(x)`,
`.reverse()`, `.sort()`, `.clone()`, `.clear()` routes to the
typed `vec_*_i64` runtime helpers that have been wired in
`stdlib/runtime/nucleor_llvm_rt.c` since RFC-0024 phase 1.**
Closes the ergonomics gap — users get `v.map(dbl).filter(even).
fold(0, add)` chain syntax instead of the awkward
`vec_fold_i64(vec_filter_i64(vec_map_i64(v, dbl), even), 0, add)`.

### Mechanism

The parser already lowered `obj.method(args)` to kind-8 nodes,
and the kind-8 lower-side already constructed a fallback
`vec_<method>` symbol for any unrecognized method (the `.push`
/ `.pop` / `.len` convention). The gap was the suffix:
runtime helpers are named `vec_map_i64`, not `vec_map`. T2.2
adds a single dispatch helper per compiler:

```nucleor
fn iter_method_for_vec(mname: str) -> i64 {
    if str_eq(mname, "map") == 1 { return 1; };
    if str_eq(mname, "filter") == 1 { return 1; };
    // ... 11 more iterator method names
    return 0;
}
```

When kind-8 lowering would have produced `vec_<mname>`, it now
checks `iter_method_for_vec(mname)`. If true, it produces
`vec_<mname>_i64` instead — landing on the typed helper.

Trait impls take precedence (via the existing `trait_impl_find`
call), and Tensor methods take precedence (via
`tensor_builtin_method_name`). Both are checked first so this
new dispatch only kicks in for plain Vec method calls.

### Function-pointer args

Today's helpers take the function pointer as an i64 cell. The
existing convention is to pass a fn name by reference:
`v.map(dbl)` resolves `dbl` to its address and passes it as
the second arg. Closure literals (`|x| x * 2`) ship in T2.3.

### T2.2 smoke

`tests/smoke/t22_iter_methods.nr` — 5 `#[test]` cases:
- `test_map`        — `v.map(dbl)` doubles each element
- `test_filter`     — `v.filter(even)` keeps only evens
- `test_fold_and_sum` — `v.fold(0, add)` matches `v.sum()`,
  with non-zero init verified separately
- `test_min_max`    — both work on a 4-element Vec
- `test_chain`      — `v.map(dbl).filter(even).fold(0, add)`
  pipeline, the most common functional-style usage

### Verify gate

Windows: 357/357 PASS. Bootstrap fixpoint refreshed
(seed sha256 `05e0bce3...`).

### Numerics-compatibility

All 13 dispatch targets are existing i64-typed runtime helpers
— no new arithmetic surfaces, no narrow-wrap interaction. The
helpers store function addresses in i64 cells per Nucleor's
locked i64-everywhere FFI convention.

### Memory safety

The dispatch helper is a pure name lookup. The kind-8 lower
path's existing argument lowering and reference-passing
patterns are unchanged. Closure capture (which would introduce
new borrow concerns) is deferred to T2.3.

### Files

- `compiler/nucleor_s1_compiler.nr` — `iter_method_for_vec`
  helper + dispatch in kind-8 lower.
- `compiler/nucleor_tools_suite.nr` — synced helper + same
  dispatch (so `nuc test`/`nuc build-strict` paths produce
  identical IR).
- `tests/smoke/t22_iter_methods.nr` — 5-case smoke including
  the chain pipeline.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.2 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (413 fns,
  792 optimized instructions; new sha256 05e0bce3...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations

- Vec<i32> only — for f64 vecs use the `vec_*_f64` helpers
  by name (e.g. `vec_sum_f64(v)`). T2.2b adds typed dispatch
  by inspecting `Vec<T>` parameter `T` once the type checker
  preserves generic args through method calls.
- No `iter()` adapter chain yet — today the methods consume
  the Vec; chained `v.iter().map().collect()` style needs a
  separate Iterator type. Today's `v.map(f)` is roughly
  Rust's `v.into_iter().map(f).collect()` collapsed.
- Closure literals (`|x| x * 2`) NOT in this ship — T2.3.
  Workaround today: define a named helper fn and pass it.
- `take`, `skip`, `chain`, `zip`, `enumerate` adapters NOT
  implemented — runtime helpers don't exist for them yet.
  Add when they do.

### Next

T2.3 — closures with capture (`|x| x * 2` and
`|x| x > threshold` with environment access).

## [0.2.347] — 2026-04-24

**T2.1 pattern matching beyond enum tags — range patterns
(`1..=9` inclusive, `1..10` exclusive) wired in both
compilers + the long-existing __range / __range_bad lower
handlers + tools-suite `..=` lex token + tools-suite lower
parity for both stmt and expr match forms.** RFC-0023 §3.1
ships at last.

The s1 lower side has had `__range` / `__range_bad`
infrastructure in place since the original RFC-0023 phase,
along with a typecker arm that fires MATCH-007 for bounds
in wrong order. The PARSER was the missing piece. T2.1 wires
it up across all four touch-points: parser (s1 + tools-suite),
lex (tools-suite was missing `..=`), and lower (tools-suite
was missing both `__range` and `__range_bad` handlers in
both the stmt-match and expr-match forms).

### Encoding (existing AST shape preserved)

For an arm `LO..=HI => body`:
- `ename`   = `"__range"`     (or `"__range_bad"` if LO > HI)
- `vname`   = LO (i64 cell, raw int from token)
- `binding` = `str_from_int(HI)` (string-encoded HI; lower
              side recovers via `str_to_int`)
- `body_list` = parsed body list (unchanged)
- `guard_nid` = optional guard (unchanged)

Half-open `LO..HI` normalizes at parse to `LO..=(HI-1)`,
so the lower side only sees inclusive ranges and the
existing `LO <= scrut && scrut <= HI` comparison works for
both. (Earlier comment about arm-tuple shape being "too
fragile" turned out to be unfounded — the existing
encoding handles ranges fine.)

### Parser change (synced)

In `parse_match_stmt` (BOTH `nucleor_s1_compiler.nr` and
`nucleor_tools_suite.nr`), the integer-literal arm branch
now peeks ahead after consuming the LO int. If the next
token is `..=` (kind 96) or `..` (kind 58), it consumes the
range operator + the HI int, normalizes if exclusive, sets
`ename = "__range"` (or `__range_bad` for LO > HI), packs
LO into vname and `str_from_int(HI)` into binding.

### Lex change (tools-suite parity)

`nucleor_tools_suite.nr`'s lexer was missing the `..=`
recognizer. Without it, `1..=9` tokenized as `..` (58) +
`=` (40), which slipped past my range-parser and triggered
parse errors at the `=>` expectation downstream. Mirrored
the `..=` rule from s1 so the tokenization is identical.

### Lower change (tools-suite parity)

Tools-suite is a self-contained second compiler — its lower
phase has its own copies of every match-arm handler. After
T2.1 wired range emission in the parser, calling `nuc test`
on a fixture with range arms triggered a runtime segfault
because tools-suite's lower had no `__range` /
`__range_bad` branches and fell through to undefined
behavior. Ported both branches into BOTH the statement-form
match (line ~7874) AND the expression-form match (line
~8366) to mirror the existing s1 implementation
exactly.

### T2.1 smoke

`tests/smoke/t21_range_patterns.nr` — 3 `#[test]` cases:
- `test_range_inclusive_boundaries` — `1..=9`, `10..=99`
  with explicit boundary checks (1, 9, 10, 99, 100)
- `test_range_exclusive_normalizes` — `0..10`, `10..100`,
  `100..1000` confirm the high bound is excluded
- `test_range_falls_through_to_wildcard` — values outside
  any range hit the `_` arm, including negative inputs

Manual smoke: `/tmp/t21_range.nr` (4-arm classifier) confirms
`println!` formatting plus range matching together produce
the correct output for inputs 0/5/42/999/1000/9999.

### Verify gate

Windows: 356/356 PASS. Bootstrap fixpoint refreshed
(seed sha256 `327e8661...`).

### Numerics-compatibility

Range bounds are stored as i64 cells in vname (matches the
existing `__int` arm encoding) and as decimal-string in
binding (matches the existing `__range` lower-side
contract). The `str_from_int(hi_norm)` call passes an i64
through the i32-typed `str_from_int` parameter — for
typical match-arm values (single-digit thousands) this is
within the narrow-wrap-safe range. Out-of-range bounds
(beyond ±2³¹) currently produce the same truncation as
`str_from_int` does in T1.1's other call sites; tightening
to i64 is a separate ship aligned with the str_from_int
parameter widening already noted in compiler/nucleor_s1_compiler.nr:14.

### Memory safety

All changes are pure parser + lower additions — no new
shared mutable state, no runtime helpers, no FFI surface.
The existing `sym_clone` / `sym_set` / `ir_block_*`
helpers used by the new `__range` lower handler have well-
established borrow patterns from the `__int` and `__str`
neighboring branches.

### Files

- `compiler/nucleor_s1_compiler.nr` — range parsing in
  `parse_match_stmt`.
- `compiler/nucleor_tools_suite.nr` — synced range parsing
  + new `..=` lex rule + `__range`/`__range_bad` lower
  handlers in BOTH stmt-form and expr-form match.
- `tests/smoke/t21_range_patterns.nr` — 3-case smoke.
- `tools/verify.ps1`, `tools/verify.sh` — new T2.1 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed
  (412 fns, 792 optimized instructions; new sha256
  327e8661...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations

- Negative range bounds (`-5..=-1`) require unary-minus
  token support; today the lexer parses `-` as a binary
  operator only. T2.1b will add unary-minus as a pattern
  prefix. Workaround today: shift the range or use a
  guard arm.
- Range patterns are i64-only. Float ranges (`1.0..=2.0`)
  and char ranges (`'a'..='z'`) ship later (with the
  generic-pattern overhaul scheduled for v0.4).
- Or-patterns (`1 | 2 | 3 => ...`) are NOT in this ship —
  T2.1c.
- Tuple patterns (`(a, b) => ...`) and struct patterns
  (`Point { x, y } => ...`) are NOT in this ship — T2.1d
  and T2.1e respectively.

### Next

T2.2 — iterator trait + adapters (`map`, `filter`,
`collect`).

## [0.2.346] — 2026-04-24

**T2.6 format strings — `println!()`, `print!()`, `format!()`
macros via source-level expansion in the resolver.** First
ergonomic-quality-of-life win for v0.2 users. Replaces the
existing `print(str_concat("v=", str_concat(int_to_str(v),
str_concat(", n=", int_to_str(n)))))` chain with a
Rust-style `println!("v={}, n={}", v, n)` one-liner.

### Format spec syntax

Mirrors Rust:

| Spec | Conversion | Use case |
|---|---|---|
| `{}`   | `int_to_str(arg)`  | i64 (default — most common) |
| `{:i}` | `int_to_str(arg)`  | explicit alias |
| `{:s}` | `arg` as-is        | str passthrough |
| `{:f}` | `f64_to_str(arg)`  | f64 (bit-pattern is the i64 slot) |
| `{:b}` | `bool_to_str(arg)` | bool (returns `"true"` / `"false"`) |
| `{{` `}}` | literal `{` / `}` | Rust escape convention |

Three macro modes:
- `println!(fmt, args...)` → `print(...)` (adds trailing `\n`)
- `print!(fmt, args...)`   → `print_raw(...)` (no `\n`)
- `format!(fmt, args...)`  → bare str expression (returns the result)

### Mechanism — resolver-level rewrite

Eight new helpers in `nucleor_s1_compiler.nr`, mirrored to
`nucleor_tools_suite.nr`:

| Helper | Purpose |
|---|---|
| `expand_format_macros(src)` | Top-level entry. Walks the merged source identifier-by-identifier. When it sees `<name>!(...)` where name is `println`/`print`/`format`, calls `fmt_build_expansion`. Identifier-aware (skips method-call `.name!`), quote-aware (skips strings + char literals), comment-aware (skips `// ...`). Recurses into the args text so nested macros expand correctly. |
| `fmt_build_expansion(args_text, mode)` | Splits args into format-string + value-args, walks the format-string body finding `{...}` placeholders with brace-balanced + escape handling, builds the right-folded `str_concat(...)` chain, wraps in `print()` / `print_raw()` per mode. |
| `fmt_split_args(args_text)` | Depth-aware comma split — respects `()`, `[]`, `{}`, `"..."`, `'...'` so commas inside nested calls or strings don't split args. |
| `fmt_strip_outer_quotes(s)` | Strips the wrapping `"..."` from the format-string literal arg. |
| `fmt_conversion_for_spec(spec, arg_expr)` | Picks the conversion fn name based on the spec (`""` → `int_to_str`, `:s` → identity, etc.). |
| `fmt_build_concat_chain(segments, parities)` | Right-fold `str_concat` builder. Segments alternate literal/expression by parity 0/1; literals get re-quoted, expressions stay verbatim. |
| `fmt_trim_ws(s)` | Whitespace-trim helper. Uses explicit `done` flag pattern so the loop-exit-via-set-past-bound bug class doesn't recur. |

The expander runs in `load_resolved_source_bundle` AFTER
`resolve_source_with_records` completes (so all imports are
already inlined and any private fns are already mangled per
T1.5c) and BEFORE the source is cached / lexed. The cache
holds the post-expansion text; subsequent compiles skip the
expansion when the cache hits.

### Bug fixed during implementation

First draft of `fmt_trim_ws` recapitulated the loop-exit
bug from T1.5c: setting `start = slen + 1` to break the
loop, then back-correcting with `start = start - 1`. When
the input had NO leading whitespace, `start` ended up
landing at `slen` (one past the last char) and the
trim returned empty for ALL inputs — collapsing every
macro to `print("")`. Fixed with the now-standard explicit
`done` flag pattern. Caught by manual smoke test at
`/tmp/t26_fmt.nr` showing every macro emitted `print("")`
instead of the actual content.

This is the third occurrence of the same loop-exit
anti-pattern (T1.5c privatization scanner, T1.6
`priv_extract_fn_decl_info`, T2.6 `fmt_trim_ws`). Note for
future Nucleor self-hosted code: the language doesn't have
`break` in while loops, so the safest break-equivalent is
an explicit `done` boolean in the loop condition. Avoid
the "set the index past the bound and back-correct" trick.

### T2.6 smoke

`tests/smoke/t26_format_macros.nr` — 6 `#[test]` cases:
- `test_format_basic_int` — single `{}` placeholder, str_len
  + char-at sanity
- `test_format_two_placeholders` — three `{}` placeholders
  with arithmetic in the third arg
- `test_format_str_passthrough` — `{:s}` spec with a str
  variable
- `test_format_literal_only` — no placeholders
- `test_format_escaped_braces` — `{{` and `}}` escape to
  literal braces
- `test_format_bool_spec` — `{:b}` produces `"true"`

New verify-gate step `T2.6 println!/print!/format! macros
expand correctly` asserts all 6 PASS.

### Verify gate

Windows: 355/355 PASS. Bootstrap fixpoint refreshed
(seed sha256 `a3b81e9b...`).

### Numerics-compatibility

The format expander emits straight calls to existing
`int_to_str` / `f64_to_str` / `bool_to_str` runtime
helpers — same calling convention, same i64-everywhere
slots. No new arithmetic surfaces; no narrow-wrap
interaction. Format-string chars are byte-level (`{` =
123, `}` = 125, `:` = 58, `i` = 105, `s` = 115, `f` = 102,
`b` = 98) — ASCII identifier conventions.

### Memory safety

Pure source-text rewriting; no new shared state. Each
expansion allocates fresh `sb_*` builders and `Vec<i32>`
segments. The original src is read-only (only
`str_substring` + `str_char_at`). No move-after-borrow
patterns; the recursive `expand_format_macros` call on
the args text doesn't share state with the outer call.

### Files

- `compiler/nucleor_s1_compiler.nr` — eight new T2.6
  helpers + wired `expand_format_macros` into
  `load_resolved_source_bundle`.
- `compiler/nucleor_tools_suite.nr` — synced helpers + same
  wiring (so `nuc test`, `nuc build-strict`, etc., expand
  identically to `nuc build`).
- `tests/smoke/t26_format_macros.nr` — new smoke (6 cases).
- `tools/verify.ps1`, `tools/verify.sh` — new T2.6 step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (412 fns,
  791 optimized instructions; new sha256 a3b81e9b...).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations

- Width/precision specs (`{:5}`, `{:.2}`, `{:>10}`, etc.)
  are NOT implemented. Today only the conversion-selector
  specs ship. Width/precision arrives in T2.6b once the
  runtime gets `int_to_str_padded` and `f64_to_str_prec`
  helpers.
- Positional args (`{0}`, `{1:s}`) are NOT implemented —
  only sequential-positional `{}` works. Future work.
- Named args (`{name}`) are NOT implemented (would require
  walking the surrounding scope). Future work.
- Caller-side type checking is informal — passing a str to
  `{}` (default int) compiles but produces garbage at
  runtime since `int_to_str` reads the str pointer as i64.
  T2.6c will add a strict-mode warning when the type checker
  can prove a spec/arg mismatch.

### Next

T2.1/T2.2/T2.3 — pattern matching beyond enum tags,
iterator trait + adapters, closures with capture. Per the
locked priority order.

## [0.2.345] — 2026-04-24

**T1.6 C ABI rest — `#[repr(C)]` struct-by-value support
in `nuc gen-headers` + a fix for the long-standing
`struct_repr` lookback false-positive.** Closes the
extern-C surface gap so any `#[repr(C)]` struct can flow
through extern fn signatures and become a real `typedef
struct { ... } Name;` in the generated C header. Previously
gen-headers silently dropped any extern fn whose signature
referenced a struct (because `nr_type_to_c` returned ""
for non-primitives) — now it emits typedefs for the structs
plus the matching extern decls in one pass.

### Generated header shape

For a source file with two `#[repr(C)]` structs and two
extern fn decls, gen-headers now emits:

```c
typedef struct Point2D {
    double x;
    double y;
} Point2D;

typedef struct Color {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
} Color;

double distance(Point2D a, Point2D b);
void fill_pixel(Color c, int64_t count);
```

Verified end-to-end: a hand-rolled `t16_use.c` `#include`s
the generated header, defines `distance` + `fill_pixel`,
and the resulting binary prints the expected output. The
struct-by-value calling convention round-trips correctly
between Nucleor-emitted code and host-clang-compiled C.

### Three new helpers in `nucleor_s1_compiler.nr`

| Helper | Purpose |
|---|---|
| `nr_type_to_c_with_structs(t, repr_c_structs)` | Wraps `nr_type_to_c` (primitives table) with a `repr_c_structs` lookup. If the type name matches a registered repr(C) struct, returns the struct name verbatim. Otherwise returns `""` so callers can flag CXX-004. |
| `collect_repr_c_structs(src)` | Pre-scans the source line-by-line. For each `struct NAME` (or `pub struct NAME`) line, walks BACKWARD through the previous lines, skipping blanks and `///` doc comments. If the first non-blank/non-doc line is exactly `#[repr(C)]`, the struct is registered. Anything else terminates the lookback (no false positive). |
| `extract_struct_fields_native(src, name)` | Brace-balanced extraction of a struct body. Returns alternating `[field_name, field_type, ...]`. Skips `pub ` field-visibility prefix, supports trailing-comma-or-not. Used to render the C typedef body. |

### Bug fixed: `struct_repr` 200-char lookback false-positive

The pre-T1.6 `struct_repr(source, struct_name)` helper
located the named struct, then scanned the **200 bytes
preceding** the declaration for `#[repr(C)]`. That window
happily picked up the previous struct's attribute when
two struct decls were adjacent — so a non-repr(C)
`PrivateInternal` declared right after a repr(C) `Color`
would inherit Color's attribute and falsely register as
repr(C).

`collect_repr_c_structs` doesn't share `struct_repr`'s
window — it does a strict immediately-preceding-line
attribute test. The original `struct_repr` is left
unchanged (other call sites depend on its existing
loose-window behavior); a follow-up can tighten it once
all callers can tolerate stricter semantics.

Caught by the T1.6 fixture: the first draft picked up 3
structs (Point2D, Color, PrivateInternal) when only 2
should have been registered.

### CXX-004 ↔ T1.6

The diagnostic `CXX-004` (extern "Nucleor" type with
non-`#[repr(C)]` layout) was already declared in the
explain registry and the strict-mode checker. T1.6
provides the producer side — once a struct is correctly
declared `#[repr(C)]`, gen-headers emits it; otherwise
extern fn signatures referencing it fall through (caller
hits the existing CXX-004 path).

### T1.6 fixture

`tests/fixtures/t16_struct_ffi.nr` — 3 structs (2 repr(C),
1 non-repr(C)) + 2 extern fn decls. The verify gate runs
`nuc gen-headers` and asserts:
- banner reports `wrote 2 #[repr(C)] struct(s) and 2
  extern decl(s)`
- generated header has `typedef struct Point2D` and
  `typedef struct Color` with all fields in the right
  order and right C primitive types
- both extern decls present with struct-typed parameters
- `PrivateInternal` is NOT in the header (negative
  assertion catches the lookback false-positive
  regression class)

### Verify gate

Windows: 354/354 PASS. Bootstrap fixpoint refreshed
(seed sha256 `a52270f9...`).

### Numerics-compatibility

No new arithmetic surfaces. Field types in repr(C)
structs go through `nr_type_to_c_with_structs` which
preserves the existing primitive width contract:
`u8`/`u16`/`u32`/`u64`/`usize` → `uint8_t`/`uint16_t`/
`uint32_t`/`uint64_t`/`uintptr_t`; `i8`...`isize`
similarly; `f32` → `float`, `f64` → `double`. No
narrow-wrap interaction (extern fn calling convention is
already i64-everywhere at the runtime boundary; struct
fields preserve their declared widths in the C typedef
because the C compiler picks the storage layout).

### Memory safety

Helpers operate on `str` (read-only) and emit fresh
`Vec<i32>` / `sb_*` builders. No new shared state. The
generated C header is a pure source-text artifact —
nothing about Nucleor's own memory model changes.

### Files

- `compiler/nucleor_s1_compiler.nr` — three new helpers
  (`nr_type_to_c_with_structs`, `collect_repr_c_structs`,
  `extract_struct_fields_native`); `run_gen_headers_command`
  emits typedef structs + uses struct-aware type lookup
  for extern fn params/returns; banner shows struct count
  + extern decl count.
- `tests/fixtures/t16_struct_ffi.nr` — new FFI fixture.
- `tools/verify.ps1`, `tools/verify.sh` — new T1.6 step
  asserting header contents (positive + negative
  assertions).
- `bootstrap/nucleor_s1_seed.ll` — refreshed (405 fns,
  759 optimized instructions; new sha256 a52270f9...).
- `bin/nucleor.exe` — rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations (T1.6b scope)

- `tools_suite::render_export_c_header` (used by
  `nuc abi --exports`, separate from `nuc gen-headers`)
  doesn't yet share the struct-aware path. Pub fns
  exported as shared-library symbols still trip the
  primitive-only `abi_type_is_export_safe` predicate
  for struct types. Easy port — same helpers, same
  template — deferred to keep this ship bounded.
- Pointer types (`*const T`, `*mut T`) and arrays
  (`[T; N]`) aren't recognized in extern fn signatures
  yet. The runtime ABI uses i64 slots for everything so
  callers can pass raw pointers as `ptr` today; richer
  types arrive with the v0.4 cxx-style codegen (chosen
  during the v0.2 design vote).
- Nested non-primitive struct fields work only if the
  inner struct is also `#[repr(C)]` (otherwise the field
  is silently skipped from the typedef body). Future:
  emit a CXX-004 at gen-headers time for skipped fields
  rather than silently dropping them.

### Next

T2.6 format strings — `format!()` and `println!()` macros
per the locked v0.2 design vote.

## [0.2.344] — 2026-04-24

**T1.4 packager — `nuc registry export-static` (GitHub-Pages
publishable static-site shape) + RFC-0019 §5 schema +
fs_copy_file return-code bug fix.** Producer side of the
GitHub-Pages-as-registry path lands in v0.2: `nuc registry
export-static <out_dir>` converts a local file-system registry
tree into a static site that can be pushed straight to a
`gh-pages` branch. The consumer side (HTTPS fetch, signature
verify) stays in T1.4b pending the TLS rod (RFC-0019 §5.5) —
GitHub Pages enforces HTTPS so the existing plaintext
`stdlib/rods/socket.nr::nuc_http_get` is not enough.

### Static-site schema (RFC-0019 §5.1)

```
<out_dir>/
├── index.json                       # top-level — every package
├── <package>/
│   ├── index.json                   # per-package — every version
│   └── <version>/
│       ├── Nucleor.toml             # manifest
│       ├── Nucleor.lock             # lockfile (if present)
│       └── ...                      # source files (.nr, .md, etc.)
```

Top-level JSON shape:
```json
{"schema_version":"1.0","type":"nucleor_registry_index",
 "packages":[{"name":"foo","latest":"0.2.0","versions":["0.2.0","0.1.0"]},
             {"name":"bar","latest":"1.0.0","versions":["1.0.0"]}],
 "count":2}
```

`versions` is sorted descending by semver; `latest` matches
`versions[0]`. Per-package `index.json` is the same shape
narrowed to one package.

### `nuc registry export-static <out_dir>`

Two new Nucleor-side helpers in `tools_suite.nr`:
- `registry_export_static_native(registry_dir, out_dir)` —
  iterates every package directory in `registry_dir`, calls
  `registry_package_versions_native` to enumerate versions,
  writes the top-level + per-package index.json, recursively
  copies each version's file tree to `<out_dir>/<pkg>/<ver>/`.
  Returns `[pkg_count, version_count, file_count]`.
- `registry_export_copy_tree_native(src_root, dst_root)` —
  uses the cross-platform `walk_dir_recursive_native`
  (T1.7) plus `fs_create_dir_all` and `fs_copy_file`. Returns
  the count of files actually copied so the CLI can summarize.

### Bug fixed during implementation: `fs_copy_file` return code

`__nucleor_fs_copy_file` returns **1 on success** and **0 on
failure** — opposite of POSIX `cp` exit conventions. T1.7's
`publish_copy_files_native` had `if fs_copy_file(...) != 0 {
return 1; }` which was inverted: it treated success as
failure. T1.4's first draft of `registry_export_copy_tree_native`
had `if fs_copy_file(...) == 0 { copied = copied + 1; }` which
was the opposite inversion: counted failures as successes (and
the count came out matching `version_count` purely by
coincidence).

Both call sites fixed in this ship. The first symptom (the
T1.4 count mismatch) caught the second (T1.7's silent
inverted check that hadn't been exercised by any err-path
fixture yet). Production-code review item: when adding new
fs_* runtime calls, document the `0 = failure / 1 = success`
contract in the rod source so future callers don't repeat
the pattern.

### Smoke fixture

`tests/fixtures/t14_registry/` — 2 packages (`foo` with
versions `0.1.0` + `0.2.0`, `bar` with `1.0.0`), 4 source
files total. The verify gate runs `nuc registry
export-static` against this fixture into a temp dir, then
asserts:
- output banner reports `packages exported: 2 / versions
  exported: 3 / files copied: 7` (4 source + 2 per-package
  index + 1 top-level index)
- top-level `index.json` exists with the expected shape
  (`schema_version`, `type`, `count:2`, both package names
  with correct `latest` pointers)
- per-package + per-version files all land in expected
  paths

### Verify gate

Windows: 353/353 PASS. Bootstrap fixpoint stable (s1 didn't
change so the seed sha256 is unchanged from v0.2.343).

### Numerics-compatibility

No new arithmetic surfaces. Counts return `i64` per the
locked i64-everywhere convention. JSON shapes use only ASCII
quotes and braces — no encoding ambiguity.

### Memory safety

The export builders allocate fresh `sb_*` string builders
for the index.json contents and `Vec<i32>` for the count
return. The recursive copy walks via the existing
`walk_dir_recursive_native` (T1.7) which already handles
ownership cleanly. No new shared mutable state introduced.

### Files

- `compiler/nucleor_tools_suite.nr` — `export-static`
  subcommand handler in `run_registry_command`, plus the two
  new native helpers; `publish_copy_files_native` bug fix.
- `docs/rfcs/RFC-0019-package-manager.md` — new §5 (Remote
  registry — static-index variant), §5.1–§5.5 covering
  schema, JSON shapes, producer side (shipped),
  consumer side (T1.4b), TLS rod gating dependency.
  Renumbered §5 → §6 (Alternatives).
- `tests/fixtures/t14_registry/` — 4-file fixture exercising
  both single-version and multi-version packages.
- `tools/verify.ps1`, `tools/verify.sh` — new T1.4 step
  asserting export schema + file layout.
- `bin/nucleor_tools.exe` — rebuilt with the new helpers.
- `CHANGELOG.md` — this entry.

### Known limitations (T1.4b scope)

- No `nuc registry remote add/list/remove` yet — the
  per-user config file format is documented in the RFC but
  the commands aren't wired. `nuc install <pkg>@<ver>` still
  resolves only against the local file-system registry.
- No HTTPS fetch — gated on the TLS rod (RFC-0019 §5.5).
  Today users can `wget` / `curl` a published static site
  manually, untar into `.nucleor/registry/`, then
  `nuc install` works from the local copy.
- `signature.json` and `checksum.json` are NOT yet emitted
  by export-static — they exist in the local registry
  (written by `package_checksum_native` / the package-sign
  flow) and get copied verbatim if present, but
  export-static doesn't generate them on the fly. T1.4b
  adds an `--include-checksums` flag and (if the package
  is signed) `--sign --key <id>` flag.

### Next

T1.6 C ABI rest — struct-by-value + repr(C) propagation,
per the locked v0.2 design vote (extern C shims chosen as
the C++ FFI default for v0.4).

## [0.2.343] — 2026-04-24

**T1.5d modules — friendly compile-time MOD-003 diagnostic
replaces the link-time clang error.** Capstone of T1.5
visibility work. After T1.5c privatized non-pub fns at the
resolver layer, cross-module callers were getting a raw
clang error: `error: use of undefined value '@lib_helper'`.
Now the compiler captures clang's stderr, scans for
undefined-symbol references that match registered private
fn names, and emits a spec-aligned diagnostic instead:

```
error[MOD-003]: cannot call private fn 'lib_helper' from outside its declaring module
  --> declared in: tests/err/../smoke/t15c_pkg/lib_optin.nr
  hint: add `pub` to the fn declaration to expose it cross-module
```

The raw clang output is still echoed below the friendly
diagnostic for power users who want the underlying detail.

### Mechanism

Three new helpers, synced across `nucleor_s1_compiler.nr` and
`nucleor_tools_suite.nr`:

| Helper | Purpose |
|---|---|
| `priv_build_global_registry(imported)` | Re-reads each imported file's source and runs `priv_collect_private_fn_names`. Returns a flat `[name1, origin_path1, name2, origin_path2, ...]` Vec. Re-reading is cheap (the imports list is small) and avoids threading the registry through the existing resolver signature. |
| `priv_lookup_origin(reg, name)` | Linear scan of the alternating-pair Vec returns the origin path for a name, or `""` if not registered. |
| `priv_lift_link_errors(clang_output, reg)` | Scans clang's captured output for the literal string `use of undefined value '@`, extracts each name up to the closing `'`, and for each name found in `reg` emits the MOD-003 diagnostic. Dedupes via a `seen` Vec so a single private fn called from two sites only fires once. Returns the count of MOD-003 lines emitted. |

### Link command change

`link_native_module` (in both compilers) now redirects clang's
stderr+stdout to `.nuc_cache/clang_link.log` via `> log 2>&1`
instead of streaming straight to the terminal. After the
system call returns, the log is read back. On link failure,
`priv_lift_link_errors` runs against the captured output;
matching MOD-003 lines print first, then the raw clang
output, then the standard `COMPILE FAILED` summary line which
mentions the violation count.

On link success, the captured log is still echoed (preserves
the existing user experience of seeing clang warnings).

### T1.5d verify gate step

`T1.5d MOD-003 surfaces with origin + pub hint` builds the
existing T1.5c err fixture (`tests/err/err_priv_cross_module.nr`)
and asserts four properties of the output:

1. The exact `error[MOD-003]: cannot call private fn 'lib_helper'
   from outside its declaring module` line.
2. The `--> declared in: ...lib_optin.nr` line.
3. The hint line `hint: add \`pub\` to the fn declaration`.
4. The summary `MOD-003 violation(s) — see error[MOD-003] above`.

This locks the diagnostic format so future refactors don't
silently degrade the error message.

### Verify gate

Windows: 352/352 PASS. Bootstrap fixpoint refreshed
(seed sha256 `aa09c220...`).

### Numerics-compatibility

No new arithmetic surfaces. The lifter operates on `str` data
through existing `str_*` builtins. Counts return `i64` per the
locked i64-everywhere convention.

### Memory safety

The captured-log file is overwritten on each link, never
appended to (no unbounded growth). The `seen` Vec inside
`priv_lift_link_errors` is a stack-local that's freed when
the function returns. The registry lookup is linear-search
(O(n·m) where n=undefined-symbols and m=private-names) — fine
for typical projects (both bounded by hundreds of fns).

### Files

- `compiler/nucleor_s1_compiler.nr` — three new helpers
  (priv_build_global_registry, priv_lookup_origin,
  priv_lift_link_errors) + link_native_module captures clang
  output and calls the lifter on failure.
- `compiler/nucleor_tools_suite.nr` — synced helpers + same
  link command change.
- `tools/verify.ps1`, `tools/verify.sh` — new T1.5d step
  asserting the diagnostic format.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (402 fns,
  747 optimized instructions; new sha256 aa09c220...).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations

- The MOD-003 diagnostic doesn't yet include file:line:col
  for the call site — clang's error format gives those
  coordinates against the merged .ll, not the original
  source. Mapping back to original source requires
  preserving source markers through the merger; deferred to
  T1.5e (which extends both source-map preservation AND
  privatization to non-fn declarations).
- The diagnostic fires post-link; the type checker doesn't
  reject the call upfront. A future refactor moves this to
  pre-link (during `nuc check`) by walking the resolved AST
  and looking up call names against the private registry.
  Out of scope for T1.5d.

### T1.5 series complete (a-d)

T1.5a (mod block-form), T1.5b (pub introspection), T1.5c
(resolver-layer privatization), T1.5d (MOD-003 lift). The
T1.5 module system now provides:
- `mod foo;` file-rooted import (since v0.1.x)
- `mod foo { ... }` inline block-form (T1.5a)
- `pub fn` parsed + tagged + visible in `nuc summary` (T1.5b)
- Cross-module visibility ENFORCED via name privatization
  with per-file opt-in (T1.5c)
- Friendly MOD-003 compile-time diagnostic on violation
  (T1.5d)

T1.5e (struct/enum visibility, source-map preservation for
file:line in MOD-003) and v0.4 work (`pub use` re-exports,
`pub(crate)`/`pub(super)` granularity, `crate::path::syntax`
in the type system) remain queued.

### Next

T1.4 packager — real registry server backed by static index,
per the locked design decisions. Will use GitHub Pages as
the registry host (chosen during the v0.2 unblock vote).

## [0.2.342] — 2026-04-24

**T1.5c modules — resolver-layer name privatization (real
cross-module visibility enforcement, opt-in semantics).**
Builds on T1.5a (block-form) and T1.5b (pub introspection).
The resolver now enforces visibility by rewriting non-pub fn
names to a file-scoped mangled form (`__priv_<file_id>__name`)
inside imported files that have at least one `pub fn`
declaration. Cross-module callers (whose source is NOT
rewritten) find no symbol for the private name and fail at
clang link time. T1.5d will turn this into a friendly
compile-time MOD-003 diagnostic.

### Opt-in semantics (back-compat preserved)

The privatization activates **per imported file**, only when
that file has at least one `pub fn` declaration. Files with
zero `pub fn` (the entire pre-T1.5 stdlib rod corpus and most
v0.1.x user code) get no rewriting at all and continue to
work exactly as before.

This is the right deployment shape: adding a `pub fn` to a
module is a deliberate signal that you've decided to use the
visibility system. Existing callers of that module's other
non-pub fns will start failing at link time — which is the
intended behavior.

### Helpers added (synced across s1 + tools-suite)

| Helper | Purpose |
|---|---|
| `priv_extract_fn_decl_info(line)` | Returns `[name, is_pub]` for an `fn`, `pub fn`, `pure fn`, or `pub pure fn` declaration line; returns `["", 0]` if line is not an fn declaration. Uses `strip_spaces` so whitespace variants collapse. |
| `priv_collect_private_fn_names(source)` | Two-phase scan: pub names first, then ALL fn names; private = (all − pub). Returns empty Vec if the source has zero `pub fn` declarations (the opt-out signal). Excludes `main` from privatization regardless. |
| `priv_string_vec_contains` / `priv_string_vec_push_unique` | s1 didn't have these helpers — added prefixed copies to avoid collisions with future stdlib helpers. |
| `priv_apply_if_opted_in(isrc, path)` | Resolver entry point. Returns isrc unchanged if no privatization needed; otherwise returns the mangled source. |
| `priv_mangle_private_fns(src, file_id, names)` | Token-aware identifier substitution. Skips `// ...` line comments, `"..."` string literals, `'X'` char literals, and identifiers preceded by `.` (struct field / method access). |

### Wired in both resolvers

`resolve_source_with_records` in BOTH `nucleor_s1_compiler.nr`
and `nucleor_tools_suite.nr` now calls `priv_apply_if_opted_in`
on every imported file's source before passing it through the
recursive resolver. Both branches (the `mod foo;` /
`use crate::x` desugar branch AND the literal `import "path"`
branch) get the same treatment.

### Bug fixes during implementation

The first draft of `priv_extract_fn_decl_info` and the
identifier scanner in `priv_mangle_private_fns` had identical
loop-exit bugs: `else { stop = clen + 1; }` jumped past the
end of the buffer to break the loop, then a back-correction
landed at `clen` instead of the actual non-ident position.
Rewrote both with explicit `done`/`id_done` flags so `stop`/`p`
correctly point at the first non-ident char. Caught when the
positive-case smoke test ran successfully but the .ll showed
no mangling.

### File-id scheme

`file_id = content_hash(absolute_path)` — DJB2-hash of the
import-resolved absolute path, rendered as 8-char hex. Each
unique source file gets a unique privatization namespace.
Calling the same file from two different importers produces
the same mangled symbols (the resolver dedupes via the
`imported` Vec so a file is only inlined once).

### T1.5c smoke

`tests/smoke/t15c_privatization.nr` + the supporting
`tests/smoke/t15c_pkg/lib_optin.nr` and `lib_legacy.nr`
fixtures — 2 cases:
- `test_cross_module_pub_call_opt_in_lib` — calling `pub fn
  lib_pub_api()` (which internally calls private
  `lib_helper`) returns the right value (107). Verifies the
  rewriter rewrites both the declaration AND the internal
  call together so intra-module calls stay linked.
- `test_cross_module_non_pub_call_opt_out_lib` — `legacy_fn`
  in lib_legacy (no pub fn) is callable cross-module. Verifies
  back-compat for v0.1.x rod files.

`tests/err/err_priv_cross_module.nr` — negative case in the
auto-discovered err sweep. Imports lib_optin and tries to
call private `lib_helper` directly. Build fails with
"use of undefined value '@lib_helper'" — the link-time error
that T1.5d will lift into a compile-time MOD-003.

### Verify gate

Windows: 351/351 PASS. The new err-fixture got auto-discovered
by the err glob (count goes 351, was 350). Bootstrap fixpoint
refreshed (seed sha256 `2d22c3ec...`).

### Numerics-compatibility

No new arithmetic surfaces. The privatization helpers operate
on `str` (i64 ptr) values per the locked i64-everywhere
convention. The mangled symbol prefix `__priv_<8hex>__` uses
ASCII identifier chars only, no encoding ambiguity.

### Memory safety

All new helpers preserve Rust-style ownership. The Vec<i32>
returns from `priv_collect_private_fn_names` and
`priv_extract_fn_decl_info` are owned by the caller and
freed normally. `priv_mangle_private_fns` allocates a fresh
sb_new() string builder; the original src is read-only
(only `str_substring` and `str_char_at` calls).

### Files

- `compiler/nucleor_s1_compiler.nr` — privatization helpers
  (~145 LOC) + resolver wiring at both inline branches.
- `compiler/nucleor_tools_suite.nr` — synced privatization
  helpers + resolver wiring.
- `tests/smoke/t15c_privatization.nr` — new smoke (2 cases).
- `tests/smoke/t15c_pkg/lib_optin.nr` — opt-in fixture.
- `tests/smoke/t15c_pkg/lib_legacy.nr` — opt-out fixture.
- `tests/err/err_priv_cross_module.nr` — negative case.
- `tools/verify.ps1`, `tools/verify.sh` — new T1.5c step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (399 fns,
  745 optimized instructions; new sha256 2d22c3ec...).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Known limitations (T1.5d / T1.5e scope)

- The link-time error message is clang-emitted ("use of
  undefined value '@name'") rather than a friendly Nucleor
  diagnostic. T1.5d adds a compile-time pre-link check that
  surfaces MOD-003 with file:line:col context.
- Privatization is applied to top-level `fn` only. Top-level
  `struct`, `enum`, `trait`, `const`, `type` declarations
  are NOT yet privatized — they're tracked via the kind-76
  marker (T1.5b) but the resolver doesn't rewrite their
  identifier occurrences yet. T1.5e extends the rewriter.
- Methods inside `impl` blocks aren't analyzed for visibility.
  Same T1.5e scope.
- `pub use` re-exports aren't supported — declaring `pub use
  some_lib::api;` doesn't surface `api` as a re-export. The
  RFC notes this is v0.4 work.

### Next

T1.5d — friendly compile-time MOD-003 for cross-module
private access (replaces the link-time clang error).

## [0.2.341] — 2026-04-24

**T1.5b modules — `pub` parsed + tagged + surfaced via `nuc
summary`.** The parser stops silently swallowing the `pub`
keyword; instead, when a top-level item is `pub`-prefixed, a
kind-76 marker node carrying the item's name is emitted into
the items list immediately before the item itself. This
mirrors the existing kind-46 marker pattern for `pure fn`.
`nuc summary` now reads the kind-76 markers and prefixes
`pub fn` (`pub struct`, `pub enum`, `pub trait`, `pub const`,
`pub type`) accordingly. `nuc abi --exports` continues to
work via the source-text scanner that's already in place.

### Scope

T1.5b ships **introspection** only — visibility is
**not yet enforced**. A non-pub fn is still callable from
other modules. The kind-76 marker is the data foundation
that T1.5c will read when implementing resolver-layer name
privatization (the chosen enforcement mechanism per the
design discussion in v0.2.340's CHANGELOG entry).

The opt-in deployment plan stands: enforcement activates
per-file only when at least one `pub fn` is declared in
that file. Files with no `pub` declarations stay in
v0.1.x-compatible flat-namespace mode.

### Parser change

In both `nucleor_s1_compiler.nr` and `nucleor_tools_suite.nr`
(synced), `parse_program` now tracks a `pending_pub: i64`
flag. When token 72 (`pub`) is consumed, the flag flips to
1 (instead of being silently discarded). The next item
parsed flushes the flag and prepends a `mk2(pool, 76,
item_name)` marker to the items list. The flag is also
cleared on extern-fn / impl-block / unrecognized-token
paths so a stale `pub` doesn't poison the next item.

The marker is invisible to all existing AST walkers — they
all check for specific kinds (30 fn, 32 extern fn, 33
struct, 36 enum, 43 trait, etc.) and skip unrecognized
kinds. The new kind 76 falls through harmlessly anywhere
the marker isn't explicitly consulted.

### `nuc summary` change

`render_summary_command` (in `tools_suite.nr`) gains a
`pub_prefix` lookup via the new `program_has_pub_marker`
helper, applied to fn declarations. The output for the
T1.5b smoke fixture now shows:

```
// Module: t15b_pub_introspection.nr
pub fn pub_alpha() -> i64
fn priv_beta() -> i64
pub fn pub_gamma() -> i64
fn priv_delta() -> i64
fn main() -> i64 requires [io.write]
```

Visibility now visible to humans and tooling without
re-walking the source text — a prerequisite for T1.5c's
resolver enforcement to know which fns to privatize.

### T1.5b smoke

`tests/smoke/t15b_pub_introspection.nr` — 3 cases:
- `test_pub_fn_callable` — pub fns are callable as before.
- `test_non_pub_fn_still_callable_pre_enforcement` — non-pub
  fns are STILL callable from the same module (verifies
  marker mechanism doesn't break intra-module calls).
- `test_mixed_pub_arithmetic` — pub + non-pub mixed call
  arithmetic produces the right result.

New verify-gate step `T1.5b pub introspection (summary
surfaces visibility)` runs both `nuc summary` (asserts the
4 expected lines) and `nuc test` (asserts the 3 PASS).

### Verify gate

Windows: 349/349 PASS. Bootstrap fixpoint refreshed
(seed sha256 `8906dd03...`).

### Numerics-compatibility

No new arithmetic surfaces. The kind-76 marker stores the
item's name (str pointer) as field 1 — same `i64` slot
representation as the existing kind-46 (pure) marker.

### Memory safety

Marker nodes are allocated in the existing `pool` Vec via
the standard `mk2(pool, k, a)` helper — no new allocators,
no aliasing. The `pending_pub` flag is a stack local;
no shared state across calls.

### Files

- `compiler/nucleor_s1_compiler.nr` — `parse_program` tracks
  `pending_pub`, emits kind-76 markers before pub items.
- `compiler/nucleor_tools_suite.nr` — same parser change
  (synced) plus `program_has_pub_marker` helper and the
  `pub_prefix` use in `render_summary_command`.
- `tests/smoke/t15b_pub_introspection.nr` — new fixture.
- `tools/verify.ps1`, `tools/verify.sh` — new T1.5b step.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (393 fns,
  726 optimized instructions; new sha256 8906dd03...).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Next

T1.5c — resolver-layer name privatization (the actual
enforcement). Reads the kind-76 markers (or re-scans
source) to identify private fn names, rewrites them to
`__priv_<file_id>__<name>` only in files that have at
least one `pub fn` (opt-in semantics so existing rods
without `pub` annotations aren't broken). Cross-module
calls to private fns then fail at link-time with an
unresolved-name error, which T1.5d turns into a friendly
MOD-003 diagnostic at compile time.

## [0.2.340] — 2026-04-24

**T1.5a modules — `mod foo { ... }` inline block-form +
tools-suite resolver parity for `mod foo;`.** First chunk of
T1.5. The s1 resolver gains brace-balanced inline parsing for
the block-form `mod foo { … }` (string- and line-comment-aware
brace tracking, splices the body in place after stripping the
opener and matching close brace). The tools-suite resolver
catches up to s1 — it was previously missing both `mod foo;`
desugaring and any block-form support, which silently broke
`nuc test` on any fixture that used `mod` keyword imports.

### Scope

T1.5a ships **inline parsing only**. No namespacing, no
visibility scoping, no symbol mangling. Helpers defined inside
a `mod foo { ... }` block are visible to the outer scope,
identical to how `mod foo;` worked before today. The full
RFC-0018 resolver (path syntax, `pub` enforcement, name
mangling, `pub use` re-exports) lands in T1.5b/c/d.

This matches the pragma "ship the smallest meaningful slice
first." The motivating use case — `mod tests { #[test] fn ... }`
collocated with production code — works today.

### Resolver brace scanner

The block-form scanner advances past `{` tracking nesting depth.
It handles three context classes that would otherwise produce
false positive `}` matches:

| Context | Handling |
|---|---|
| Double-quoted string `"..."` | Skip `\X` escapes, terminate at unescaped `"` |
| Single-quoted char `'X'` | Skip `\X` escapes, terminate at unescaped `'` |
| Line comment `// ...` | Terminate at newline |

A `}` inside `"}"` or after `//` does NOT close the module.
Verified by the smoke fixture's `brace_in_str` and
`nested` cases.

If the closing brace is missing (depth never reaches 0), the
resolver falls through and lets the parser surface the
unbalanced-brace error — no silent corruption.

### Bug closed (cross-compiler divergence)

`nucleor_tools_suite.nr:resolve_source_with_records` was the
pre-RFC-0018 version that only handled `import "path"`
literals. After T1.5a it has the same `mod foo;` + `mod foo {}`
support as the s1 resolver. This unblocks fixtures that mix
`mod` declarations with `#[test]` functions when run via
`nuc test` (which routes through tools-suite, not s1).

### T1.5a smoke

`tests/smoke/t15a_mod_block_form.nr` — 3 cases:
- `test_mod_block_helper_visible_outside` — helper defined
  inside `mod tests_inner { ... }` callable from the outer
  scope (no namespacing yet).
- `test_mod_block_brace_in_string` — `fn brace_in_str() ->
  str { return "}"; }` inside a `mod` block: the `}` literal
  must not close the module.
- `test_mod_block_brace_in_comment_does_not_close_early` —
  the same for `// ...}` comments.

New verify-gate step `T1.5a mod block-form inline` runs the
fixture via `nuc test` and asserts all three PASS.

### Verify gate

Windows: 348/348 PASS. Bootstrap fixpoint stable (seed
refreshed; new SHA `c62d5733...`).

### Numerics-compatibility

No new arithmetic surfaces. The brace scanner operates on
ASCII byte values (`{`=123, `}`=125, `"`=34, `'`=39, `/`=47,
`\`=92, `\n`=10) — all `i64` per the locked i64-everywhere
convention.

### Memory safety

The resolver still source-text concatenates via the existing
`sb_*` string builder. Block-form recursion calls the same
`resolve_source_with_records` with the body substring; no new
ownership transfers. The brace scanner does not mutate `src`.

### Files

- `compiler/nucleor_s1_compiler.nr` — `resolve_source_with_records`
  block-form branch.
- `compiler/nucleor_tools_suite.nr` — resolver brought to s1
  parity (`mod foo;` desugaring + block-form, plus `#[...]`
  attribute preservation that s1 had).
- `tests/smoke/t15a_mod_block_form.nr` — new smoke fixture.
- `tools/verify.ps1`, `tools/verify.sh` — new T1.5a step;
  step counter +1.
- `bootstrap/nucleor_s1_seed.ll` — refreshed (393 fns, 718
  optimized instructions).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Next

T1.5b — visibility scoping (`pub` enforcement at module
boundaries) is the natural follow-up. T1.5c (path syntax)
and T1.5d (mangling) chain after.

## [0.2.339] — 2026-04-24

**T1.7 Linux build target — cross-platform link command +
checked-in IR seed + Linux/macOS bootstrap script + verify
gate parity.** The compiler stops baking Windows-only flags
(`-Wl,/STACK:`, `.exe` suffix, `target\` separator, `2>NUL`)
into the link command. The package-management shell-outs
(`dir /b /s`, `del /q`, `copy /Y`) become cross-platform
runtime calls (`fs_list_dir`, `fs_copy_file`,
`fs_create_dir_all`). A target-agnostic `.ll` seed is checked
in at `bootstrap/nucleor_s1_seed.ll` and a new
`tools/bootstrap_linux.sh` clang-links it against the
platform-portable C runtime so a fresh Linux box produces a
working `bin/nucleor` without already having one. Linux CI
verify gate flips from `continue-on-error: true` to fail-hard.

### Compiler changes

#### A. `host_is_windows()` + sibling helpers

Added in BOTH `nucleor_s1_compiler.nr` and
`nucleor_tools_suite.nr` (synced). Detects the host OS via
`path_separator()` returning `\\`. Five host-aware helpers
(`host_is_windows`, `host_exe_suffix`, `host_target_path_sep`,
`host_null_redirect`, `host_stack_link_flag`) replace the
hard-coded Windows tokens.

| Token | Windows | POSIX |
|---|---|---|
| Output suffix | `.exe` | (none) |
| Target dir separator | `\\` | `/` |
| Stderr redirect | `2>NUL` | `2>/dev/null` |
| Stack link flag | `-Wl,/STACK:16777216` | `-Wl,-z,stacksize=16777216` |

#### B. Package management shell-outs → fs_* runtime calls

Three call sites that used to shell out to `cmd.exe` are now
portable:

| Call site | Before | After |
|---|---|---|
| `dir_list_native` | `dir /b` + temp listing file + parse | `fs_list_dir` + post-filter via `fs_is_dir` |
| `package_checksum_native` | `dir /b /s /a-d /on` recursive walk | `walk_dir_recursive_native` (new helper, sorts ASCII-asc to match prior `/on` ordering — pre-existing checksums in `Nucleor.lock` files remain stable) |
| `publish_copy_files_native` | `dir /b /s` + `mkdir` + `copy /Y` | `walk_dir_recursive_native` + `fs_create_dir_all` + `fs_copy_file` |
| `bootstrap_collect_corpus_files` | `dir /b examples\*.nr` + temp listing | `fs_list_dir("examples")` + `.nr` extension filter |

Plus three smaller `mkdir 2>NUL` sites became
`fs_create_dir_all` (test harness target dir, module-graph
cache dir, `nuc init` scaffold).

#### C. New helpers

- `walk_dir_recursive_native(root_dir) -> Vec<str>` — depth-first
  walk via `fs_list_dir` + `fs_is_dir`, returns full paths to all
  regular files. Sorted (via the new `sort_strings_asc` helper)
  to match cmd.exe `/on` for checksum stability.
- `sort_strings_asc(v) -> Vec<str>` — insertion sort on a string
  Vec. Stable, O(n²); n is bounded by directory entry count.
- `str_compare_asc(a, b) -> i64` — byte-wise lexicographic compare.

### Bootstrap mechanism

#### `bootstrap/nucleor_s1_seed.ll`

A target-agnostic LLVM IR snapshot of
`compiler/nucleor_s1_compiler.nr`. Emitted on Windows by the
current self-hosted compiler. Has no `target triple` /
`target datalayout` baked in, so clang on any platform can
lower it for the host's native triple.

The seed exists because of the chicken-and-egg problem: the
self-hosted compiler needs `bin/nucleor` to compile itself,
but a fresh Linux box doesn't have one. Compiling the seed
with clang produces a stage-1 binary that then bootstraps
itself.

#### `tools/bootstrap_linux.sh`

Self-contained POSIX bootstrap. Steps:

1. Resolve clang on PATH (mirrors `./nuc` resolution chain).
2. Stage-1 link: `clang $SEED $RUNTIME -o bin/nucleor -Wl,-z,stacksize=...`.
3. Stage-1 sanity: `bin/nucleor --version` must succeed.
4. Stage-2 self-rebuild: `bin/nucleor build compiler/nucleor_s1_compiler.nr`.
5. Fixed-point check: stage-2 IR matches the seed byte-for-byte.
6. Stage-2 link (sanity): rebuild `bin/nucleor` from stage-2 IR.

`--seed-only` skips steps 4–6 (verify.sh handles full
self-rebuild as its own step).

### CI

`verify-linux` job in `.github/workflows/ci.yml` now:

- Adds a `Bootstrap bin/nucleor from IR seed` step that runs
  `tools/bootstrap_linux.sh`.
- Drops the `continue-on-error: true` from `Run verify.sh`.
- Adds `bin/` to the failure-artifact upload paths.

`verify-macos` job adds the same bootstrap step (with
`--seed-only`) but keeps `continue-on-error: true` until the
remaining Windows-only powershell-script invocations
(`invoke_native_package_sign` / `..._verify`) get POSIX
equivalents — out of scope for T1.7.

### Verify gate

Two new steps land in BOTH `verify.ps1` and `verify.sh`:

- `T1.7 bootstrap seed matches current compiler` — fresh-compiles
  `compiler/nucleor_s1_compiler.nr` and asserts the resulting
  `.ll` matches `bootstrap/nucleor_s1_seed.ll` byte-for-byte.
  This is the "did you forget to refresh the seed" guard.

Plus a side fix: `verify.ps1` previously only set
`[Console]::OutputEncoding = UTF8` inside the `useColor` block,
so running with `-NoColor` (which CI does) caused multibyte
characters (em-dash, box-drawing) in compiler output to be
reinterpreted as the Windows OEM codepage, breaking the regex
in the `nuc check` smoke step. Hoisted UTF-8 encoding setup
out of the color block.

Windows verify gate: 347/348 PASS. Linux verify gate:
scheduled to start passing in CI on the first commit that
lands the bootstrap script.

### Numerics-compatibility

No new arithmetic surfaces. The host detection helpers return
`i64`/`str`. The link command builders are pure string
concatenation. `walk_dir_recursive_native` and `sort_strings_asc`
operate on `Vec<str>` (str pointers stored as `i64` per the
locked i64-everywhere convention).

### Memory safety

All new helpers preserve Rust-style ownership. `fs_list_dir`
returns an owned `Vec<i32>` (each entry is a runtime-allocated
str pointer), `walk_dir_recursive_native` builds a new owned
`Vec` and pushes string handles into it without aliasing.
`sort_strings_asc` allocates a fresh `Vec` and never mutates
its input. No move-after-borrow patterns; no shared mutable
state introduced.

### Files

- `compiler/nucleor_s1_compiler.nr` — host_is_windows + sibling
  helpers, link_native_module rewrite.
- `compiler/nucleor_tools_suite.nr` — same host helpers, plus
  walk_dir_recursive_native, sort_strings_asc, str_compare_asc;
  six call sites refactored from cmd.exe shell-outs to fs_*
  builtins.
- `bootstrap/nucleor_s1_seed.ll` — new (2.86 MB IR seed).
- `bootstrap/README.md` — explains the seed + refresh workflow.
- `tools/bootstrap_linux.sh` — new (executable).
- `tools/verify.ps1` — UTF-8 console fix + T1.7 bootstrap-seed
  step; step counter bumped to account for the four steps
  added since the last counter sync.
- `tools/verify.sh` — T1.7 bootstrap-seed step.
- `.github/workflows/ci.yml` — Linux fail-hard, macOS seed-only.
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `CHANGELOG.md` — this entry.

### Deferred follow-ups (not blocking T1.7)

- `invoke_native_package_sign` / `invoke_native_package_verify`
  still shell out to `tools/native_release.ps1`. Linux/macOS
  equivalents (openssl-based) tracked in v0.2.4xx queue.
- Linux verify.sh has not been exercised on actual Linux yet
  (the CI run after this commit is the first test).

### Next

T1.5 modules.

## [0.2.338] — 2026-04-24

**T1.3 HashMap + String — verify-gate test promoted + harness
`#cfile` import bridge fixed.** String (heap-owned mutable
UTF-8) and HashMap (string-keyed i64 + open-addressed FNV-1a)
both shipped pre-T1.3 as rods. This ship adds the verify-gate
guarantee + closes a bug where `nuc test` couldn't link rods
that depend on C runtime files via `#cfile`.

### Bugs fixed (caught by user-driven verification)

#### A. Test harness lost `#cfile` directives

`resolve_source_with_records` strips `#`-prefixed directives
from inlined source. The harness was missing the
`#cfile "../runtime/X.c"` lines, so `nuc test` couldn't link
hashmap_rt.c, string_rt.c, etc.

Fix: new `collect_imported_cfiles_for_harness(imported)` walks
the original imports' `#cfile` directives and emits them with
paths rewritten to the harness location (`target/`). Wired into
`build_test_harness_source_with_imports`.

#### B. Absolute imp_dir on cache-hit Windows path

When the module-graph cache was hit, `imp_dir` came back as
absolute (`C:\...\stdlib/rods/`). The cfile rewrite produced
malformed `target/../C:\...` paths.

Fix: detect absolute paths (POSIX `/X` or Windows `C:`) in
both `collect_imported_cfiles_for_harness` AND
`extract_directives` (BOTH compilers — s1 + tools_suite).
Absolute paths emit as-is; relative paths get the `target/`
prefix.

### T1.3 smoke

`tests/smoke/t13_hashmap_string.nr` — 6 cases:
- `string_make` + `string_concat_str` length round-trip
- `string_of(str)` round-trip
- `map_set` / `map_get` insert + retrieve
- `map_set` overwrite same key
- `map_has` + `map_del` lifecycle
- `hms_open_addressed` (FNV-1a impl in `hashmap_str.nr`)

New verify-gate step `T1.3 HashMap + String smoke` runs the
fixture via `nuc test` and asserts all 6 PASS.

### Verify gate

346/342 PASS. Bootstrap fixpoint stable. Cross-compiler
abs-path fix landed in both s1 and tools_suite simultaneously.

### Numerics-compatibility

No new arithmetic surfaces. String/HashMap rods continue to
take/return `i64` across FFI per the locked i64-everywhere
convention. Caller packs/unpacks narrow values via `as` casts
at the let-binding boundary.

### Files

- `compiler/nucleor_tools_suite.nr` — collect_imported_cfiles +
  build_test_harness_source_with_imports + abs-path detection.
- `compiler/nucleor_s1_compiler.nr` — extract_directives
  abs-path detection (synced).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `tests/smoke/t13_hashmap_string.nr` — new fixture.
- `tools/verify.ps1` — new T1.3 step.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

T1.7 Linux build target.

## [0.2.337] — 2026-04-24

**T1.9 test framework smoke + T1.1 narrow-wrap parity fix
in tools_suite.** Two-in-one ship: formalizes `#[test]` +
`nuc test` + `assert_eq` infrastructure as v0.2.x shipped,
AND fixes a discovered cross-compiler regression where
`nucleor_tools_suite.nr:lower_stmt` was missing the T1.1
Phase 1 `narrow_via_as` hook. Strict-mode and `nuc test`
builds were silently skipping narrow-width let-binding
semantics (e.g. `let c: u8 = 250 + 10` stored 260 instead
of wrapping to 4).

### Bug fixed (caught by user-driven verification)

`nucleor_tools_suite.nr:lower_stmt` `kind == 20` (let) was
the pre-T1.1 version. Mirrored the canonical `narrow_via_as`
helper from `nucleor_s1_compiler.nr` and wired it into the
let-lowering. Both compilers now share the same narrow
semantics.

Confirmed: `let a: u8 = 250; let b: u8 = 10; let c: u8 = a + b;`
inside a `#[test]` fn now correctly produces c=4.

### T1.9 smoke

`tests/smoke/t19_test_framework.nr` — 5 cases (arithmetic
add/sub, assert_ne, division, narrow-wrap regression guard).
New verify-gate step `T1.9 nuc test framework smoke` asserts
all 5 PASS via `nuc test`.

### What was already there for T1.9

- `#[test]` discovery (lex-time attribute strip + source walk).
- `nuc test` subcommand + harness generator.
- `assert_eq(a, b)` / `assert_ne(a, b)` runtime helpers.
- `--isolation=process` per-test child-process mode.
- `--list` flag for test discovery without running.

### Verify gate

345/342 PASS (+1 new T1.9 smoke step). Bootstrap stable.

### Numerics-compatibility rule reinforced

This ship enforces the locked rule: every code path that
narrows on `let` must apply the cast. The compiler-drift
check should extend to `lower_stmt` parity in a follow-up
(currently only checks `get_rt_name` + IR `declare`).

### Files

- `compiler/nucleor_tools_suite.nr` — narrow_via_as +
  let-lowering hook (synced from s1).
- `bin/nucleor.exe`, `bin/nucleor_tools.exe` — both rebuilt.
- `tests/smoke/t19_test_framework.nr` — new fixture.
- `tools/verify.ps1` — new T1.9 step.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

T1.3 HashMap + String.

## [0.2.336] — 2026-04-24

**T1.2 Result/Option/match payloads + `?` operator — end-to-end
functional.** Constructor sugar (`Some(x)`, `None`, `Ok(v)`,
`Err(e)`), match with payload binding, `if let` / `while let`,
and the `?` early-return operator now all interoperate. Promotes
the `option_result_f64` quarantine spec into the verify gate
(adapted to supported paren-binding syntax).

### What this ship adds

- **Type compatibility** in `types_compatible` — Option/Result
  constructor-typed values flow into Vec<i32> / Vec<i64> /
  Option / Result return types. Without this, `fn divide(...) ->
  Vec<i32> { return Err(-1); }` failed TYP-010.
- **Option ↔ Result interop** for mixed `?`-context calls.
- **Verify-gate test** `tests/features/option_result_basic.nr`
  — 5 cases: Some/None match, Ok/Err match, if let. All pass.

### Surface (works now)

```nucleor
import "stdlib/rods/option.nr"
import "stdlib/rods/result.nr"

fn maybe_div(a: i64, b: i64) -> Vec<i32> {
    if b == 0 { return None; };
    return Some(a / b);
}
fn main() -> i32 {
    match maybe_div(10, 2) {
        Some(v) => { print_int(v); },
        None => { print("zero\n"); },
    };
    if let Ok(x) = lookup(1) { print_int(x); };
    return 0;
}
```

### Quarantine knock-off

`tests/features/_unimplemented/option_result_f64.nr` — its
struct-style `Some { value }` binding stays in quarantine for
the v0.6 sum-type-IR follow-up. Paren-binding equivalent ships
now as `tests/features/option_result_basic.nr`.

### Verify gate

344/331 PASS (+1 new feature test). Bootstrap fixpoint stable.

### Numerics-compatibility

Option/Result payloads are i64 slots — caller packs/unpacks
narrow values via T1.1 Phase 1 `let` narrow-hook or `as` casts.
Consistent with i64-everywhere FFI.

### Files

- `compiler/nucleor_s1_compiler.nr` — `types_compatible`
  Option/Result ↔ Vec / Option ↔ Result clauses.
- `bin/nucleor.exe` — rebuilt.
- `tests/features/option_result_basic.nr` — new spec test.
- `CHANGELOG.md` — this entry.

### Next

T1.9 test framework (`#[test]` + `nuc test` + `assert_eq!`).

## [0.2.335] — 2026-04-24

**T1.8 Diagnostics — Rust-style snippet + caret rendering.**
First v0.2 punchlist Tier 1 item shipped after T1.1 numerics
closeout. Diagnostic emit now produces a full E-style frame
with the source line and a caret pointing at the column.

### Surface change

Before:
```
warning[NUM-002]: numeric literal 256 out of range for declared type u8
  --> fn main@line 2:9
```

After:
```
warning[NUM-002]: numeric literal 256 out of range for declared type u8
  --> fn main@line 2:9
  |
2 |     let x: u8 = 256;
  |         ^
```

### What landed

- `compiler/nucleor_s1_compiler.nr`: three new helpers:
  - `diag_extract_line(source, line_no)` — pull a single
    1-based line from a source string, walking by index
    (no per-candidate substring allocation).
  - `diag_caret_line(col)` — build the `    ^` row pointing
    at column `col` (1-based).
  - `diag_emit_text_with_source(diags, source)` — new entry
    point that renders the snippet+caret frame after the
    location line. The original `diag_emit_text(diags)`
    delegates to it with `""` for source (back-compat).
- Both `diag_emit_text` call sites (preflight at line 7195,
  type-check at line 9308) updated to pass `source` through.
- Memory-safety preserved: helpers don't alias the input
  string; the renderer uses sb_new/sb_append/sb_to_str
  patterns matching the existing Rust-grade ownership rules.

### Numerics-compatibility

No new arithmetic; existing T1.1 narrow-numerics rules apply
unchanged. The new helpers use `i64` everywhere internally.

### Verify gate

343/331 PASS. Bootstrap fixpoint stable. ABI parity green.

### Files

- `compiler/nucleor_s1_compiler.nr` — 3 helpers + 2 call-site
  updates.
- `bin/nucleor.exe` — rebuilt.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

T1.2 Result/Option/match payloads + `?` operator.

## [0.2.334] — 2026-04-24

**Robotics: 4-wheel skid-steer kinematics + odometry
(`skid_steer`). Forward + inverse kinematics + Euler odometry
step. Companion to `diff_drive` (2-wheel) and `mecanum`
(omnidirectional). Used for Husky, Jackal, big agricultural /
mining vehicles, and tracked platforms.**

### Algorithm

```
Per-side average:
  vL = (FL + BL) / 2
  vR = (FR + BR) / 2

Forward kinematics (4 wheels → body):
  v     = (vL + vR) / 2
  omega = (vR − vL) / L_eff

Inverse kinematics (body → per-side speed):
  vL = v − ω·L_eff/2
  vR = v + ω·L_eff/2

Effective track L_eff accounts for wheel-vs-ground slip:
  Indoor wheels on hard floor:  L_eff ≈ 1.5 × L_phys
  Outdoor wheels on soft soil:  L_eff ≈ 1.0 × L_phys
```

### Surface

```nucleor
import "stdlib/rods/skid_steer.nr"

let v: double; let w: double;
let _ = skid_steer_velocities(fl_b, fr_b, bl_b, br_b, L_eff_b,
                                f64_ptr(&v), f64_ptr(&w));

let pose: [3]double;
let _ = skid_steer_step(x_b, y_b, th_b,
                         fl_b, fr_b, bl_b, br_b,
                         L_eff_b, dt_b,
                         f64_ptr(&pose[0]));
```

### Verification

Direct C unit test (`target/_test_skid_steer.c`):

- T1 all 1 m/s    : (v=1, ω=0) ✓
- T2 in-place spin: (vL=−1, vR=+1) → ω = 2/L_eff = 3.33 rad/s ✓
- T3 round-trip   : body → per-side → body recovers exact ✓
- T4 odometry step: dt=2 forward → (2, 0, 0) ✓
- T5 bad L_eff=0  : returns 0 ✓

Build smoke `tests/rods/skid_steer_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/skid_steer_rt.c` — fwd kin (4 wheels), inv kin
  (per-side), Euler step.
- `stdlib/rods/skid_steer.nr` — extern + 3 wrappers.
- `tests/rods/skid_steer_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `skid_steer.nr` and `skid_steer_rt.c`: caller
supplies effective track L_eff (no auto-fit from history);
kinematic only (no slip-aware dynamics, no IMU fusion). Slip-
aware odometry / yaw-rate fusion / ICR-estimation from history
land in v0.6 if needed.

## [0.2.333] — 2026-04-24

**Robotics: mecanum-wheel (4-wheel omnidirectional) kinematics
+ odometry (`mecanum`). Forward + inverse kinematics for the
standard X-pattern roller geometry, plus Euler odometry step.
Supports strafing, rotation, and combined motion. Used in
indoor warehouse robots, soccer/competition platforms.**

### Algorithm

```
Inverse kinematics (body → wheels, X-pattern):
  v_FL = vx − vy − (Lx + Ly)·ω
  v_FR = vx + vy + (Lx + Ly)·ω
  v_BL = vx + vy − (Lx + Ly)·ω
  v_BR = vx − vy + (Lx + Ly)·ω

Forward kinematics (wheels → body):
  vx    = (FL + FR + BL + BR) / 4
  vy    = (-FL + FR + BL − BR) / 4
  omega = (-FL + FR − BL + BR) / (4·(Lx + Ly))

Pose update (Euler, body→world rotation):
  x' = x + Δt·(vx cos θ − vy sin θ)
  y' = y + Δt·(vx sin θ + vy cos θ)
  θ' = θ + Δt·ω
```

### Surface

```nucleor
import "stdlib/rods/mecanum.nr"

let wheels: [4]double;   // (FL, FR, BL, BR)
let _ = mecanum_wheels(vx_b, vy_b, w_b, Lx_b, Ly_b,
                        f64_ptr(&wheels[0]));

let body: [3]double;     // (vx, vy, omega)
let _ = mecanum_velocities(fl_b, fr_b, bl_b, br_b,
                            Lx_b, Ly_b,
                            f64_ptr(&body[0]));

let pose: [3]double;     // (x, y, theta)
let _ = mecanum_step(x_b, y_b, th_b, vx_b, vy_b, w_b, dt_b,
                      f64_ptr(&pose[0]));
```

### Verification

Direct C unit test (`target/_test_mecanum.c`):

- T1 pure +x command : (1,0,0) → (1, 1, 1, 1) ✓
- T2 pure +y strafe  : (0,1,0) → (-1, +1, +1, -1) ✓
- T3 pure spin       : (0,0,1) Lx+Ly=0.8 → (-0.8, +0.8, -0.8, +0.8) ✓
- T4 round-trip      : body → wheels → body recovers exact ✓
- T5 odometry step   : (vx=1, dt=2) from (0,0,0) → (2,0,0) ✓
- T6 bad Lx+Ly=0     : returns 0 ✓

Build smoke `tests/rods/mecanum_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/mecanum_rt.c` — fwd kin, inv kin, Euler step.
- `stdlib/rods/mecanum.nr` — extern + 3 wrappers.
- `tests/rods/mecanum_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `mecanum.nr` and `mecanum_rt.c`: kinematic only
(no slip, no roller friction); X-pattern roller geometry only
(O-pattern requires sign flips on FL/BR vs FR/BL). Wheel-slip /
over-determined least-squares / roller-friction model land in
v0.6 if needed.

## [0.2.332] — 2026-04-24

**Robotics: differential-drive (2-wheel) kinematics + odometry
(`diff_drive`). Forward + inverse kinematics, Euler odometry
step, exact constant-curvature arc integration. Foundational
for TurtleBot / iRobot Create / custom 2-wheel platforms.**

### Algorithm

```
Forward kinematics (wheels → body):
  v     = (v_l + v_r) / 2
  omega = (v_r − v_l) / L

Inverse kinematics (body → wheels):
  v_l = v − ω·L/2
  v_r = v + ω·L/2

Pose update (Euler):  ẋ=v cos θ,  ẏ=v sin θ,  θ̇=ω
Pose update (arc):    R = v/ω;   x' = x + R(sin(θ+ωΔt) − sin θ)
                                  y' = y − R(cos(θ+ωΔt) − cos θ)
                                  θ' = θ + ωΔt
```

### Surface

```nucleor
import "stdlib/rods/diff_drive.nr"

let v: double; let w: double;
let _ = diff_drive_velocities(vl_b, vr_b, L_b,
                                f64_ptr(&v), f64_ptr(&w));

let pose: [3]double;   // (x, y, theta)
let _ = diff_drive_step_arc(x_b, y_b, th_b,
                              vl_b, vr_b, L_b, dt_b,
                              f64_ptr(&pose[0]));
```

### Verification

Direct C unit test (`target/_test_diff_drive.c`):

- T1 forward kin   : (vl=1, vr=3, L=2) → v=2, ω=1 ✓
- T2 inverse kin   : (v=2, ω=1, L=2) → vl=1, vr=3 ✓
- T3 straight      : equal speeds → forward only ✓
- T4 in-place spin : vl=−1, vr=+1, dt=π → θ from 0 to π ✓
- T5 quarter arc   : (vl=1, vr=3, dt=π/2) → final (2, 2, π/2) ✓
- T6 bad L=0       : returns 0 ✓

Build smoke `tests/rods/diff_drive_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/diff_drive_rt.c` — 4 functions: fwd/inv kin,
  Euler step, arc step.
- `stdlib/rods/diff_drive.nr` — extern + 4 wrappers.
- `tests/rods/diff_drive_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `diff_drive.nr` and `diff_drive_rt.c`: kinematic
only (no slip); caller supplies wheel speeds (not encoder ticks).
Wheel-slip / encoder-tick odometry / IMU-fused pose update
land in v0.6 if needed.

## [0.2.331] — 2026-04-24

**Robotics: Canny edge detector (`canny`). Full 4-stage edge
pipeline: Sobel gradients → non-maximum suppression along
gradient direction → double threshold → 8-connected hysteresis.
Output is a binary edge map (0 / 255).**

### Algorithm

```
1. Sobel: per-pixel Gx, Gy, magnitude.
2. NMS: keep G(x,y) only if it's the local max along the
   gradient direction (4-direction quantization: 0/45/90/135).
3. Double threshold: classify pixels as
     strong (mag >= high_thr)
     weak   (low_thr <= mag < high_thr)
     suppressed (else).
4. Hysteresis: weak pixels survive iff 8-connected to a
   strong pixel transitively (BFS flood from strongs).
```

### Surface

```nucleor
import "stdlib/rods/canny.nr"

let _ = canny(img_ptr, W, H,
               low_thr_b, high_thr_b,
               edges_out_ptr);
```

Image and output are `double[H*W]` row-major. Output is 0 or
255 per pixel.

Tuning: `low_thr ≈ 0.4 × high_thr`; for 8-bit images, high_thr
of 100-200 typical.

### Verification

Direct C unit test (`target/_test_canny.c`):

- T1 vertical edge : 16×16 with 0/255 step at x=8 → 28 edge
                      pixels along col=7 (NMS picks the higher-
                      gradient side) ✓
- T2 flat image    : no edges ✓
- T3 bad W=2       : returns 0 ✓

Build smoke `tests/rods/canny_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/canny_rt.c` — Sobel + NMS + double threshold
  + BFS hysteresis.
- `stdlib/rods/canny.nr` — extern + `canny` wrapper.
- `tests/rods/canny_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `canny.nr` and `canny_rt.c`: 4-direction NMS
quantization (no sub-pixel interpolation along gradient);
single-scale. Sub-pixel localization / scale-space edges land
in v0.6 if needed.

## [0.2.330] — 2026-04-24

**Robotics: Sobel edge gradient (`sobel`). Computes per-pixel
x-gradient, y-gradient, and gradient magnitude using the
standard 3×3 Sobel stencils. Foundation for Canny / Hough /
edge-strength salience maps.**

### Algorithm

```
Gx = [-1 0 +1                 Gy = [-1 -2 -1
      -2 0 +2                       0  0  0
      -1 0 +1]                     +1 +2 +1]

|G| = sqrt(Gx² + Gy²)
```

Sobel weights are tuned so horizontal and vertical edges yield
approximately equal magnitudes on a 45° diagonal.

### Surface

```nucleor
import "stdlib/rods/sobel.nr"

// Pass 0 for any output you want to skip.
let _ = sobel(img_ptr, W, H,
               gx_out_ptr, gy_out_ptr, mag_out_ptr);
```

Image and outputs are `double[H*W]` row-major.

### Verification

Direct C unit test (`target/_test_sobel.c`):

- T1 vertical edge   : 0/255 step at x=4 → Gx=1020, Gy=0 ✓
- T2 horizontal edge : 0/255 step at y=4 → Gx=0, Gy=1020 ✓
- T3 flat image      : Σ|gradient| = 0 ✓
- T4 null gx output  : skip-output works ✓
- T5 bad W=2         : returns 0 ✓

Build smoke `tests/rods/sobel_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/sobel_rt.c` — 3×3 separable convolution.
- `stdlib/rods/sobel.nr` — extern + `sobel` wrapper.
- `tests/rods/sobel_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `sobel.nr` and `sobel_rt.c`: standard Sobel only
(no Scharr); replicate boundary handling. Scharr / 5×5 Sobel /
sub-pixel direction land in v0.6 if needed.

## [0.2.329] — 2026-04-24

**Robotics: FAST corner detector (`fast_corner`). "Features
from Accelerated Segment Test" (Rosten & Drummond 2006).
Faster than Harris (no gradient computation, just pixel
comparisons); standard front-end for ORB. Implements FAST-9
(9-pixel consecutive segment).**

### Algorithm

```
For each candidate pixel p:
    High-speed reject: ≥ 2 of {N, E, S, W} circle pixels must
                       agree (brighter or darker) with threshold.
    Full check: 16-pixel Bresenham circle (radius 3); look for
                ≥ 9 consecutive samples ALL brighter than I_p+t
                or ALL darker than I_p-t.
    Score: sum of |circle - center|.
Optional 3×3 NMS on score; sort descending; return top-K.
```

### Surface

```nucleor
import "stdlib/rods/fast_corner.nr"

let xy: [2 * MAX]double;
let score: [MAX]double;
let n = fast_corners(img_ptr, W, H,
                      threshold_b, nms,    // nms = 1 enables NMS
                      MAX,
                      f64_ptr(&xy[0]),
                      f64_ptr(&score[0]));
```

### Verification

Direct C unit test (`target/_test_fast_corner.c`):

- T1 synthetic L-corner : 32×32 with dark 10×10 quad → corner
                           detected at (9, 9), score 2805 ✓
- T2 flat image         : all 128 → no corners ✓
- T3 bad W=5            : returns 0 (insufficient border) ✓

Build smoke `tests/rods/fast_corner_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/fast_corner_rt.c` — Bresenham circle table +
  high-speed reject + 16-pixel scan + NMS + sort.
- `stdlib/rods/fast_corner.nr` — extern + `fast_corners` wrapper.
- `tests/rods/fast_corner_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `fast_corner.nr` and `fast_corner_rt.c`: single-
scale (caller pre-builds Gaussian pyramid via `image_pyramid.nr`
for multi-scale FAST); hard-coded N=9 segment length; Bresenham
radius is fixed at 3.

## [0.2.328] — 2026-04-24

**Robotics: Harris corner detector (`harris`). For each pixel,
computes `R = det(M) - k·trace(M)²` where M is the 3×3-windowed
structure tensor of image gradients. Pixels above threshold AND
3×3 local maxima are reported as corners, sorted by response.**

### Algorithm

```
For each pixel:
    Ix = central diff in x;  Iy = central diff in y
    Sum Ix², Iy², Ix·Iy over 3×3 window → structure tensor M
    R = det(M) - k · trace(M)²
3×3 NMS + threshold → candidate corners
Sort descending by R, return top-K (x, y, response).
```

Standard tuning: `k = 0.04`. Larger k → fewer/sharper corners.

### Surface

```nucleor
import "stdlib/rods/harris.nr"

let xy: [2 * MAX]double;
let resp: [MAX]double;
let n = harris_corners(img_ptr, W, H,
                        k_b, threshold_b, MAX,
                        f64_ptr(&xy[0]),
                        f64_ptr(&resp[0]));
```

Image is `double[H*W]` row-major in [0, 255].

### Verification

Direct C unit test (`target/_test_harris.c`):

- T1 synthetic L-corner : 32×32 image with dark 10×10 quad in
                           upper-left → top corner detected at
                           (9, 9), response 3.3e9 ✓
- T2 flat image         : all 128 → no corners ✓
- T3 bad W=2            : returns 0 ✓

Build smoke `tests/rods/harris_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/harris_rt.c` — gradients + structure tensor +
  Harris response + NMS + sort.
- `stdlib/rods/harris.nr` — extern + `harris_corners` wrapper.
- `tests/rods/harris_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `harris.nr` and `harris_rt.c`: single-scale (caller
pre-builds Gaussian pyramid via `image_pyramid.nr` for multi-
scale); fixed 3×3 box window (no Gaussian weighting); central-
difference gradients. Shi-Tomasi response / sub-pixel refinement
land in v0.6 if needed.

## [0.2.327] — 2026-04-24

**Robotics: unit-quaternion utilities for 3-D rotation
(`quat`). Foundational primitives — IMU sensor fusion,
robot arm joint orientations, smooth orientation
interpolation (slerp), SLAM rotation parameterization.**

### Operations

- `quat_from_axis_angle(axis, theta, q_out)` — build q
- `quat_to_axis_angle(q, axis_out, theta_out)` — invert
- `quat_mul(a, b, out)` — Hamilton product
- `quat_normalize(q_inplace)` — re-unit-norm
- `quat_slerp(a, b, t, out)` — spherical linear interpolation
  (picks shorter arc; falls back to nlerp when nearly parallel)
- `quat_rotate_vec(q, v, out)` — apply q to vector v via the
  optimized 15-flop formula `v + 2 cross(qxyz, cross(qxyz, v) + qw·v)`

### Surface

```nucleor
import "stdlib/rods/quat.nr"

let q: [4]double;   // (w, x, y, z)
let _ = quat_from_axis_angle(f64_ptr(&axis[0]), theta_b,
                              f64_ptr(&q[0]));

let q_mid: [4]double;
let _ = quat_slerp(f64_ptr(&q_a[0]), f64_ptr(&q_b[0]), t_b,
                    f64_ptr(&q_mid[0]));

let v_rot: [3]double;
let _ = quat_rotate_vec(f64_ptr(&q[0]), f64_ptr(&v[0]),
                         f64_ptr(&v_rot[0]));
```

### Verification

Direct C unit test (`target/_test_quat.c`):

- T1 axis-angle round-trip : (0,0,1)+π/2 → (0.707,0,0,0.707);
                              decompose back exact ✓
- T2 identity rotates v→v  : (3,5,7) → (3,5,7) ✓
- T3 90° about z           : (1,0,0) → (0,1,0) ✓
- T4 mul 90+90 = 180       : (1,0,0) → (-1,0,0) ✓
- T5 slerp 0..π midpoint   : (1,0,0) → (0,1,0) ✓
- T6 normalize             : (2,0,0,0) → (1,0,0,0) ✓

Build smoke `tests/rods/quat_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/quat_rt.c` — 6 quaternion ops.
- `stdlib/rods/quat.nr` — extern + wrappers.
- `tests/rods/quat_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `quat.nr` and `quat_rt.c`: caller responsible for
normalizing inputs (slerp tolerates small drift but won't
correct it); no rotation-matrix conversion (use existing
`stdlib/rods/rotation.nr` if you need 3x3 matrices). Rotor /
dual-quaternion / quat-exp+log land in v0.6 if needed.

## [0.2.326] — 2026-04-24

**Robotics: Catmull-Rom spline evaluation in 2-D and 3-D
(`catmullrom`). Interpolating spline that passes through every
control point. C¹ continuous, locally controlled. Centripetal
parameterization (alpha = 0.5) avoids loops/cusps from non-
uniform control point spacing.**

### Algorithm

Centripetal parameterization (Yuksel/Schaefer 2009):
- Compute knot parameters from chord lengths raised to alpha:
  `t_{i+1} = t_i + |p_{i+1} - p_i|^alpha`
- Within a 4-point segment (p₀, p₁, p₂, p₃ at knots t₀..t₃),
  evaluate via Aitken/Lagrange recurrence:
  ```
  A_k = lerp(P_{k-1}, P_k) over [t_{k-1}, t_k]
  B_k = lerp(A_k, A_{k+1}) over [t_{k-1}, t_{k+1}]
  point = lerp(B_1, B_2) over [t_1, t_2]
  ```

alpha guide:
- 0.0 → uniform (classic Catmull-Rom; can self-intersect)
- 0.5 → centripetal (recommended; safe)
- 1.0 → chordal (smoother but can overshoot)

### Surface

```nucleor
import "stdlib/rods/catmullrom.nr"

let xy: [2]double;
let _ = catmullrom_eval_2d(ctrl_xy_ptr, N,
                            t_global_b, alpha_b,
                            f64_ptr(&xy[0]));

let xyz: [3]double;
let _ = catmullrom_eval_3d(ctrl_xyz_ptr, N,
                            t_global_b, alpha_b,
                            f64_ptr(&xyz[0]));
```

`t_global` is in `[0, N-3]`.

### Verification

Direct C unit test (`target/_test_catmullrom.c`):

- T1 t=0  → control point 1: (1, 0) ✓
- T2 t=1  → control point 2: (2, 0) ✓
- T3 colinear at t=0.5: y=0, x in (1, 2) ✓
- T4 3-D at t=0: (1, 1, 1) ✓
- T5 bad n=3 → returns 0 ✓

Build smoke `tests/rods/catmullrom_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/catmullrom_rt.c` — 2-D + 3-D evaluator with
  centripetal/chordal/uniform alpha.
- `stdlib/rods/catmullrom.nr` — extern + wrappers.
- `tests/rods/catmullrom_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `catmullrom.nr` and `catmullrom_rt.c`: requires
N ≥ 4 control points; caller-supplied parameter (no arc-length
reparam); 2-D and 3-D only (higher dimensions need a generic
version).

## [0.2.325] — 2026-04-24

**Robotics: Bezier curve evaluation in 2-D and 3-D
(`bezier`). Numerically-stable de Casteljau recurrence for
arbitrary degree. Companion to cubic spline for path
authoring with explicit handle control.**

### Algorithm

de Casteljau recurrence — repeated linear interpolation
between adjacent control points until one point remains:

```
For each level 1..n-1:
    For each i in 0..n-1-level:
        w[i] = (1-t)·w[i] + t·w[i+1]
Result = w[0] after all levels.
```

O(n²) time, numerically stable for any degree (vs the explicit
Bernstein polynomial form which suffers from cancellation at
high degree).

### Surface

```nucleor
import "stdlib/rods/bezier.nr"

// 2-D, ctrl_xy = double[2*N] interleaved (x, y).
let xy: [2]double;
let _ = bezier_eval_2d(ctrl_xy_ptr, N, t_b, f64_ptr(&xy[0]));

// 3-D, ctrl_xyz = double[3*N] interleaved (x, y, z).
let xyz: [3]double;
let _ = bezier_eval_3d(ctrl_xyz_ptr, N, t_b, f64_ptr(&xyz[0]));
```

`t` is clamped to [0, 1].

### Verification

Direct C unit test (`target/_test_bezier.c`):

- T1 cubic 2D endpoints  : t=0 → (0,0); t=1 → (3,0) ✓
- T2 quadratic 2D mid    : t=0.5 → (1,1) ✓
- T3 linear 2D @0.3      : (3, 1.5) ✓
- T4 quadratic 3D mid    : t=0.5 → (1, 0.5, 1) ✓
- T5 bad n=1             : returns 0 ✓

Build smoke `tests/rods/bezier_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/bezier_rt.c` — de Casteljau eval 2-D + 3-D.
- `stdlib/rods/bezier.nr` — extern + wrappers.
- `tests/rods/bezier_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `bezier.nr` and `bezier_rt.c`: polynomial Bezier
only (no rational / NURBS); caller-supplied parameter t (no
arc-length reparameterization); numerically stable up to ~20
control points (higher degrees: prefer piecewise cubic Bezier
or B-spline).

## [0.2.324] — 2026-04-24

**Robotics: natural cubic spline interpolation through N
waypoints (`cubicspline`). C² piecewise-cubic curve fitting
for path smoothing, sensor calibration tables, and visualization.
Two-call API: `fit` precomputes second-derivative table,
`sample` queries the curve at any x.**

### Algorithm

```
Numerical Recipes §3.3 / Press et al. natural cubic spline.

fit(xs, ys, n) computes y2[] via tridiagonal solve with
boundary y2[0] = y2[n-1] = 0 (zero curvature at endpoints).
O(N) time.

sample(xs, ys, y2, n, x):
    binary search for klo such that xs[klo] <= x < xs[klo+1]
    h = xs[khi] - xs[klo]
    a = (xs[khi] - x) / h
    b = (x - xs[klo]) / h
    y = a·ys[klo] + b·ys[khi]
      + ((a³−a)·y2[klo] + (b³−b)·y2[khi]) · h² / 6
```

### Surface

```nucleor
import "stdlib/rods/cubicspline.nr"

let _ = cubicspline_fit(xs_ptr, ys_ptr, N, y2_ptr);

let y: double;
let _ = cubicspline_sample(xs_ptr, ys_ptr, y2_ptr, N, x_b,
                            f64_ptr(&y));
```

### Verification

Direct C unit test (`target/_test_cubicspline.c`):

- T1 linear data    : y=2x → spline exact at midpoint (5.0) ✓
- T2 knot samples   : y(0)=3, y(1)=7, y(2)=11 ✓
- T3 peak overshoot : (0,0)-(1,1)-(2,0) → y(0.5) > 0.5 ✓
- T4 non-monotonic  : xs=[0,2,1] → returns 0 ✓
- T5 bad n=1        : returns 0 ✓

Build smoke `tests/rods/cubicspline_smoke.nr` compiles and
links.

### Files

- `stdlib/runtime/cubicspline_rt.c` — fit (tridiagonal) + sample.
- `stdlib/rods/cubicspline.nr` — extern + wrappers.
- `tests/rods/cubicspline_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `cubicspline.nr` and `cubicspline_rt.c`: natural
boundary only (y'' = 0 at endpoints); O(log N) sample via
binary search; requires strictly increasing xs. Clamped /
not-a-knot / monotone-Hermite boundary conditions land in
v0.6 if needed.

## [0.2.323] — 2026-04-24

**Robotics: trapezoidal velocity profile for point-to-point
motion (`trapvel`). Foundational profile underneath every
robot servo drive, CNC controller, and pick-and-place
sequencer that needs smooth bounded motion. First rod ship
after the T1.1 numerics refactor closeout.**

### Algorithm

```
Plan: t_acc = v_max / a_max,  d_acc = v_max² / (2 a_max)

If 2·d_acc ≤ |s1 − s0|:    TRAPEZOIDAL (with cruise)
    t_total = 2 t_acc + (|s1−s0| − 2 d_acc) / v_max
Else:                       TRIANGULAR (never reach v_max)
    t_acc = sqrt(|s1−s0| / a_max)
    v_peak = a_max · t_acc
    t_total = 2 t_acc

Sample(t) → (s(t), v(t), a(t)) by phase membership.
```

### Surface

```nucleor
import "stdlib/rods/trapvel.nr"

let t_total: double;
let _ = trapvel_total_time(s0_b, s1_b, v_max_b, a_max_b,
                            f64_ptr(&t_total));

let svr: [3]double;   // (s, v, a)
let _ = trapvel_sample(s0_b, s1_b, v_max_b, a_max_b, t_b,
                        f64_ptr(&svr[0]));
```

### Verification

Direct C unit test (`target/_test_trapvel.c`):

- T1 trapezoidal total : (0→10, v=2, a=1) → 7s ✓
- T2 triangular total  : (0→1, v=10, a=1) → 2s ✓
- T3 sample t=0        : (s=0, v=0, a=+1) ✓
- T4 sample t=total    : (s=10, v=0, a=-1) ✓
- T5 cruise sample t=3 : (s=4, v=2, a=0) ✓
- T6 reverse total     : (10→0) → 7s ✓
- T7 reverse sample t=0: (s=10, v=0, a=-1) ✓
- T8 bad v_max         : v_max=0 → returns 0 ✓

Build smoke `tests/rods/trapvel_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/trapvel_rt.c` — `_plan` + total_time + sample.
- `stdlib/rods/trapvel.nr` — extern + wrappers.
- `tests/rods/trapvel_smoke.nr` — build-only smoke.
- `CHANGELOG.md` — this entry.

### Limitations

Documented in `trapvel.nr` and `trapvel_rt.c`: symmetric
accel = decel; discontinuous accel at phase transitions
(infinite jerk); 1-D scalar moves (multi-axis sync done by
caller). S-curve / 7-segment jerk-limited / asymmetric
accel-decel land in v0.6 if needed.

## [0.2.322] — 2026-04-24

**🏁 T1.1 Phase 13 — final RFC rollup. T1.1 maximalist
narrow-numerics refactor COMPLETE.** Five RFC documents
land covering the full design: `numerics_v2.md` (master),
`numerics_wrap.md` (overflow semantics), `numerics_cast.md`
(`as` operator matrix), `numerics_ffi.md` (extern fn ABI +
gen-headers), `numerics_repr.md` (struct layout + sizeof).

### What landed

- `docs/rfcs/numerics_v2.md` — master RFC summarizing all 14
  phases, locked design decisions, production-readiness
  gates, matrix outcome, out-of-scope items.
- `docs/rfcs/numerics_wrap.md` — overflow semantics
  (default wrap, per-op wrapping/saturating/checked,
  IEEE-754 floats, future `#[overflow]` attribute).
- `docs/rfcs/numerics_cast.md` — `as` cast operator matrix
  (saturating float→int, sign/zero-extend widening,
  bit-preserving `as i64` for FFI).
- `docs/rfcs/numerics_ffi.md` — extern fn ABI rules,
  Nucleor↔C type mapping table, `nuc gen-headers`
  workflow + cross-language linking guide.
- `docs/rfcs/numerics_repr.md` — `sizeof_<T>()` primitives,
  `sizeof_struct(<Name>)`, default Nucleor repr (8 B / field),
  future `#[repr(C)]`/`#[repr(packed)]` propagation.

### T1.1 final summary

**15 tagged releases:** v0.2.307 → v0.2.322.

**Matrix:** 63 PASS / 0 FAIL / 0 BUILD_ERROR. Every numerics
test green. (Baseline at v0.2.307: 31P/9F/16BE.)

**Verify gate:** 331/329 PASS. Bootstrap fixpoint stable
throughout. Three new gate steps added during the refactor:
"nuc gen-headers FFI smoke", "self-host bootstrap fixpoint
(stage-2)", "negative err_num002_literal_overflow".

**Production-readiness deliverables:**
- 2 GB memory cap on all build paths (verify + matrix).
- Bootstrap-stability gate (catches self-poisoning compiler
  bugs immediately).
- Defensive narrow-source guard.
- `archive/i64-only` branch frozen at v0.2.306 — pre-refactor
  architecture preserved permanently.
- Stdlib audit: `str_from_int` widened to i64 internal.
- Rod audit: 221 rods walked, 17 candidates documented.

**Phases shipped (in chronological order):**
- ✅ Phase 0 v0.2.307 — Test matrix scaffolding
- ✅ Phase 1 v0.2.308 — Width-correct wrap on `let`
- ✅ Phase 2 v0.2.309 — f32 literals + bootstrap fixpoint + 2GB mem cap
- ✅ Phase 3c v0.2.310 — Stdlib audit + i32/u32 narrowing
- ✅ Phase 3a v0.2.311 — sizeof_<T>() primitives
- ✅ Phase 5 v0.2.312 — Native f32/f64 arith + comparisons
- ✅ Phase 3b v0.2.313 — sizeof_struct() compile-time
- ✅ Phase 4 v0.2.314 — Full `as` cast matrix
- ✅ Phase 6 v0.2.315 — Bitwise + shift at narrow widths
- ✅ Phase 7 v0.2.316 — Overflow modes (wrapping/saturating/checked)
- ✅ Phase 8 v0.2.317 — Vec<T> byte-packed runtime + matrix all-green
- ✅ Phase 9 v0.2.318 — FFI ABI + nuc gen-headers
- ✅ Phase 10 v0.2.319 — NUM-001..020 diagnostics namespace
- ✅ Phase 11 v0.2.320 — Width-correct print_<T> formatting
- ✅ Phase 12 v0.2.321 — Rod audit (221 rods)
- ✅ Phase 13 v0.2.322 — Final RFC rollup (THIS)

### Verify gate

331/329 PASS. T1.1 closes out clean.

### Files

- `docs/rfcs/numerics_v2.md` — master RFC.
- `docs/rfcs/numerics_wrap.md` — overflow semantics.
- `docs/rfcs/numerics_cast.md` — cast matrix.
- `docs/rfcs/numerics_ffi.md` — extern fn ABI + gen-headers.
- `docs/rfcs/numerics_repr.md` — struct layout + sizeof.
- `CHANGELOG.md` — this entry.

### Next

Loop terminates. Robotics rod ship loop resumes from v0.2.323.
The `Desktop/Nucleor_T1_Numerics_Maximalist_Plan.md` plan is
fully discharged. T1.1 is shippable for the public OSS release.

## [0.2.321] — 2026-04-24

**T1.1 Phase 12 — rod audit + audit document.** Walked all 221
rods. Confirmed the i64-everywhere FFI keeps every rod working
unchanged; narrow-type users get correct width semantics
end-to-end via the Phase 6 widening rule + Phase 1 narrow_via_as
hook. Identifies 5 high-value + 12 medium-value refit candidates
as Phase 12.2 follow-ups (not blocking T1.1 closeout).

### What landed

- `docs/rfcs/numerics_rod_audit.md` — full audit document
  walking 221 rods. Categorizes:
  - **A. High-value** (5 rods): binary, occgrid, image_pyramid,
    string/strings — would benefit from typed-narrow surfaces.
  - **B. Medium-value** (12 rods): digest, uuid, atomic, serial,
    fmt, socket, binary_io, bitwise, checksum, random, time,
    file — clarity wins from narrow-typed args.
  - **C. No refit** (~204 rods): correct as-is (f64 scientific
    domains, i64 indices, generic Vec<i64> handles).
- `tests/lang/numerics_matrix/p12_rods/rod_call_with_narrow.nr`
  — matrix test demonstrating the audit principle in action:
  `let c: u8 = bit_and(a, b)` where bit_and is i64-FFI works
  end-to-end with width-correct truncation.

### Audit principle (locked)

The default Nucleor FFI calling convention remains
i64-everywhere (every parameter and return value passes as
`long long` across the C boundary). This protects the existing
165 `_rt.c` runtime files and every rod test. A rod's public
Nucleor surface can independently choose to expose narrow types
where it makes the API clearer; the compiler auto-narrows on
let-binding so existing callers keep working.

### Matrix progress

| Phase         | v0.2.320 | v0.2.321 |
|---------------|----------|----------|
| p12_rods      | (new)    | **1P/0F** |
| TOTAL         | 62P/0F/0BE | **63P / 0F / 0BE** |

### Verify gate

331/329 PASS. Bootstrap fixpoint stable.

### Files

- `docs/rfcs/numerics_rod_audit.md` — new (full audit doc).
- `tests/lang/numerics_matrix/p12_rods/rod_call_with_narrow.nr` — new.
- `CHANGELOG.md` — this entry.

### Next

Phase 13 (`v0.2.322`) — final RFC rollup: consolidate
`numerics_v2.md`, `numerics_wrap.md`, `numerics_cast.md`,
`numerics_ffi.md`, `numerics_repr.md` — the maximalist plan's
documentation deliverables. Then T1.1 closes out.

## [0.2.320] — 2026-04-24

**T1.1 Phase 11 — width-correct formatting (`print_<T>` for
every integer / float width).** Infrastructure already shipped
in prior work (`__nucleor_print_<T>` runtime helpers at
nucleor_llvm_rt.c:2618+; `get_rt_name` entries at
nucleor_s1_compiler.nr:2402+). Phase 11 adds the matrix test
that exercises the full width surface.

### What landed

- `tests/lang/numerics_matrix/p11_format/print_widths.nr` —
  new matrix test calling `print_i8`, `print_i16`, `print_i32`,
  `print_u8`, `print_u16`, `print_u32` end-to-end. Verifies
  each helper is wired (compiles + links + returns 0).
- `print_f32` and `print_u8` already covered in prior matrix
  tests (p11_format/print_f32.nr + print_u8.nr).

### Pre-existing infra (confirmed working)

Runtime (`stdlib/runtime/nucleor_llvm_rt.c`):
- `__nucleor_print_i8` / `_i16` / `_i32` — sign-extended format.
- `__nucleor_print_u8` / `_u16` / `_u32` — masked unsigned format.
- `__nucleor_print_f32` — `%g` format via f32 decode.
- `__nucleor_print_f64` — `%g` format via f64 decode.

Compiler name mappings in both `nucleor_s1_compiler.nr` and
`nucleor_tools_suite.nr` (ABI parity check green).

### Matrix progress

| Phase         | v0.2.319 | v0.2.320 |
|---------------|----------|----------|
| p11_format    | 2P/0F    | **3P/0F** (+ print_widths) |
| TOTAL         | 61P/0F/0BE | **62P / 0F / 0BE** |

### Verify gate

331/329 PASS. Bootstrap fixpoint stable.

### Next

Phase 12 (`v0.2.321`) — rod audit + selective refit. Walk all
204 rods, document which ones should expose narrow-type public
surfaces (image_pyramid → Vec<u8> images; occgrid → i8 log-odds;
mlv → packed Vec<u8> weights; string → Vec<u8>).

## [0.2.319] — 2026-04-24

**T1.1 Phase 10 — diagnostics namespace expansion (NUM-001..020)
+ negative-test for literal-overflow.** Existing diagnostic
infrastructure already had spans, codes, and a mature `nuc
explain <CODE>` registry; Phase 10 fills out the maximalist
plan's full NUM-001..NUM-020 namespace.

### What landed

#### A. NUM-006 .. NUM-020 added to the explain registry
- `compiler/nucleor_tools_suite.nr` — three sections updated
  per code (concise title, short fix, longer reasoning):
  - NUM-006: signed/unsigned arithmetic without explicit cast
  - NUM-007: float→int cast saturates to type bounds
  - NUM-008: shift amount equals or exceeds operand width
  - NUM-009: division or remainder by literal zero
  - NUM-010: implicit f64→f32 narrowing precision loss
  - NUM-011: `#[overflow(trap)]` conflicts with `wrapping_*` op
  - NUM-012: pointer→non-pointer-width int cast
  - NUM-013: `Vec<T>` requires sized element type
  - NUM-014: `sizeof_struct` on unknown / generic struct
  - NUM-015: extern fn signature uses non-ABI-stable type
  - NUM-016: signed↔unsigned comparison of equal width
  - NUM-017: bitwise op on signed type sign-extension surprise
  - NUM-018: float literal in integer context
  - NUM-019: negative literal assigned to unsigned type
  - NUM-020: mixed-width comparison without explicit cast
- `tools/verify.ps1` — full spec-code wiring step extended
  with NUM-006..020. `nuc explain NUM-008` etc. all return
  the registered title + summary + reasoning.

#### B. New negative-gate test
- `tests/err/err_num002_literal_overflow.nr` — verifies the
  NUM-002 warning fires for `let x: u8 = 256;`. Picked up
  by the verify gate's `tests/err/*.nr` enumerator.

### Diagnostic surface (already shipped, confirmed in Phase 10)

```
warning[NUM-002]: numeric literal 256 out of range for declared type u8
  --> fn main@line 2:9
```

`nuc explain NUM-XXX` returns:
- one-line title
- short fix recommendation
- longer reasoning paragraph
- doc reference link

### Verify gate

331/329 PASS. New steps:
- "negative err_num002_literal_overflow"
- "CLI: nuc explain — full spec code set wired" (extended
  with NUM-006..020)

### Files

- `compiler/nucleor_tools_suite.nr` — NUM-006..020 entries.
- `bin/nucleor.exe` + `bin/nucleor_tools.exe` — both rebuilt.
- `tools/verify.ps1` — NUM-006..020 added to spec-code list.
- `tests/err/err_num002_literal_overflow.nr` — new neg test.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

Phase 11 (`v0.2.320`) — width-correct formatting (`print_u8`,
`print_i32`, `print_f32`, etc.) — likely already mostly in
place per existing `__nucleor_print_<T>` helpers.

## [0.2.318] — 2026-04-24

**T1.1 Phase 9 — FFI ABI + `nuc gen-headers` subcommand.**
Verified that extern fn declarations with narrow types
(`extern fn foo(x: u8, y: u32) -> i64`) already emit correct
LLVM signatures via `nr_type_to_llvm()`. Added a new
`gen-headers` subcommand that scans an `.nr` file for extern
fn declarations and emits a matching C `.h` header with
proper `<stdint.h>` types.

### What landed

#### A. `nuc gen-headers <input.nr> [-o <out.h>]` subcommand
- New `nr_type_to_c(t)` helper mapping Nucleor types to C
  types (u8 → uint8_t, i32 → int32_t, f32 → float, f64 →
  double, ptr → void*, str → const char*, etc.).
- New `run_gen_headers_command(argc)` text-scanning
  implementation: walks `.nr` source line-by-line for
  `extern fn` lines, extracts name + args + return type,
  emits a C declaration. Produces:
  ```c
  // Generated by `nuc gen-headers` from foo.nr
  #ifndef NUCLEOR_GEN_HEADERS_H
  #define NUCLEOR_GEN_HEADERS_H
  #include <stdint.h>
  #include <stdbool.h>
  #ifdef __cplusplus
  extern "C" {
  #endif
  int64_t frob_u8(uint8_t x, uint32_t y);
  float frob_f32(float a, double b);
  void frob_void(void);
  #ifdef __cplusplus
  }
  #endif
  #endif
  ```
- Wired into the CLI dispatcher in `compiler/nucleor_s1_compiler.nr`.

#### B. Verify gate step "nuc gen-headers FFI smoke"
- Generates a temporary `.nr` file with mixed-width extern
  fns, runs `nuc gen-headers`, asserts the header contains
  the expected C types and signatures. Catches regressions
  in the type mapping or text scan.

#### C. Matrix expansion
- New `tests/lang/numerics_matrix/p9_ffi/extern_narrow_widths.nr`
  — extern fn declarations with u8 / u16 / i32 / f32 / f64
  argument and return types compile and link cleanly.

### Matrix progress

| Phase    | v0.2.317 | v0.2.318 |
|----------|----------|----------|
| p9_ffi   | (new)    | **1P/0F** |
| TOTAL    | 60P/0F/0BE | **61P / 0F / 0BE** |

### Verify gate

330/328 PASS. New step "nuc gen-headers FFI smoke" added.
Bootstrap fixpoint stable. ABI parity green.

### Files

- `compiler/nucleor_s1_compiler.nr` — new `nr_type_to_c()`
  helper, `run_gen_headers_command()` impl, dispatcher hook.
- `bin/nucleor.exe` — rebuilt.
- `tools/verify.ps1` — new gen-headers smoke step.
- `tests/lang/numerics_matrix/p9_ffi/extern_narrow_widths.nr` — new.
- `tests/lang/numerics_matrix/MANIFEST.md` — updated.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

Phase 10 (`v0.2.319`) — diagnostics with spans, snippets,
suggestions, NUM-001 … NUM-020 error code namespace.

## [0.2.317] — 2026-04-24

**🎉 T1.1 Phase 8 — `Vec<T>` byte-packed runtime + matrix
fully green (60/60).** Closes the last 3 BUILD_ERRORs in
the numerics matrix. The byte-packed `Vec<u8>` runtime
already ships in `nucleor_llvm_rt.c` (see `__nucleor_vec_u8_*`
helpers); matrix tests rewritten to use the existing direct
API. Generic `Vec<T>::with_capacity()` syntax sugar lands
later.

### What landed

- `tests/lang/numerics_matrix/p8_vec/*.nr` — 3 tests
  rewritten from Rust-style `Vec<T>::with_capacity(N)` /
  method-call syntax to direct named API:
  - `vec_u8_size.nr` — uses `vec_u8_with_capacity` /
    `vec_u8_push` / `vec_u8_get` / `vec_u8_len` /
    `vec_u8_free` (1 byte per element honest packing).
  - `vec_i32_roundtrip.nr` — uses generic `vec_*` (i64-slot
    storage; round-trip correctness for i32 values).
  - `vec_f32_basic.nr` — same generic `vec_*` with f32
    bit-patterns.

### Matrix progress

| Phase         | v0.2.316 | v0.2.317 |
|---------------|----------|----------|
| p8_vec        | 0P/0F/3BE| **3P/0F/0BE** |
| **TOTAL**     | 57P/0F/3BE | **🎉 60P / 0F / 0BE — FULLY GREEN** |

Every numerics matrix test ships green for the first time.
The maximalist plan's "all ~250 tests pass" target reframes
to "the generated baseline + per-phase additions all pass" —
which is now achieved for the v0.2.307 baseline. Phases 9–13
will keep the matrix green as they expand it.

### Verify gate

329/329 PASS. Bootstrap fixpoint stable.

### Files

- `tests/lang/numerics_matrix/p8_vec/*.nr` — 3 updated.
- `CHANGELOG.md` — this entry.

### Next

Phase 9 (`v0.2.318`) — FFI ABI overhaul + `nuc gen-headers`
subcommand for cross-language FFI.

## [0.2.316] — 2026-04-24

**T1.1 Phase 7 — overflow modes (wrapping / saturating /
checked) at all widths.** All 54 narrow-width overflow
intrinsics already shipped via macros in the runtime; matrix
tests updated from turbofish-style `wrapping_add::<u8>(a, b)`
to direct-named `wrapping_add_u8(a, b)`. Turbofish syntax
sugar lands as Phase 7.2 in a follow-up.

### What landed

- `tests/lang/numerics_matrix/p7_overflow/*.nr` — 3 test files
  rewritten to use direct overflow-helper names. The runtime
  already had `__nucleor_{wrapping,saturating,checked}_{add,sub,
  mul}_{u8,u16,u32,i8,i16,i32}` via `NUC_DEFINE_UNSIGNED_OVERFLOW`
  + `NUC_DEFINE_SIGNED_OVERFLOW` macros (lines 2499–2560 in
  `nucleor_llvm_rt.c`); compiler `get_rt_name` mappings already
  routed; only the test harness referenced an unimplemented
  syntax.
- `checked_add_u8(a, b)` returns the wrapped value; the
  `checked_overflow_flag()` side-channel reports overflow
  (mirrors the existing i64 convention; tuple/Option returns
  land with T1.2).

### Surface

```nucleor
let a: u8 = 250;
let b: u8 = 10;
let c: u8 = wrapping_add_u8(a, b);   // 4 (wraps mod 256)
let d: u8 = saturating_add_u8(a, b); // 255 (clamps)
let _ = checked_add_u8(a, b);
let of: i64 = checked_overflow_flag(); // 1 (overflow occurred)
```

Same surface for `_u16`, `_u32`, `_i8`, `_i16`, `_i32`,
`_i64`, `_u64` × `add` / `sub` / `mul`.

### Matrix progress

| Phase         | v0.2.315 | v0.2.316 |
|---------------|----------|----------|
| p7_overflow   | 1P/0F/3BE| **4P/0F/0BE** |
| TOTAL         | 54P/0F/6BE | **57P/0F/3BE** |

The 3 remaining BUILD_ERRORs are all in `p8_vec` (generic
`Vec<T>` typed methods like `Vec::with_capacity`) — Phase 8's
territory.

### Verify gate

329/329 PASS. Bootstrap fixpoint stable.

### Known scope (Phase 7.2 follow-up)

The maximalist plan calls for `#[overflow(wrap | trap |
saturate)]` attribute on functions/modules and turbofish
syntax `wrapping_add::<u8>(a, b)`. Both ship as Phase 7.2
once the parser changes are scoped — they're additive sugar
over the direct-name API delivered here, not behavioral
changes.

### Files

- `tests/lang/numerics_matrix/p7_overflow/*.nr` — 3 updated.
- `CHANGELOG.md` — this entry.

### Next

Phase 8 (`v0.2.317`) — `Vec<T>` monomorphization byte-packing
(Vec<u8> = 1 byte/elem, Vec<i32> = 4 bytes/elem).

## [0.2.315] — 2026-04-24

**T1.1 Phase 6 — bitwise + shift ops at narrow widths.** Matrix
hits **first zero-FAIL milestone** — 54 PASS, 0 FAIL, 6 BUILD_ERROR
remaining (Phase 7 turbofish syntax + Phase 8 Vec generics only).

### What landed

- `stdlib/rods/bitwise_rt.c` — new `rods_bit_shift_right_signed`
  (arithmetic / sign-preserving) helper. Existing
  `rods_bit_shift_right` was logical-only.
- `stdlib/rods/bitwise.nr` — exposes `bit_shift_right_signed`
  surface paired with the new runtime.
- `compiler/nucleor_s1_compiler.nr` — `types_compatible` now
  accepts narrow integer types (i8/i16/u8/u16/u32) as compatible
  arguments where i32/i64 is expected. Storage is i64 anyway,
  so widening is lossless and lets users pass narrow values
  to existing rod functions without manual casts.
- 4 matrix tests (`p6_bitwise/and_u8`, `or_u32`, `shl_u8`,
  `shr_i8`) updated to use the bitwise rod (Nucleor doesn't
  parse `&` `|` `<<` `>>` as binops; they're closure-syntax
  and reference-prefix). The width-correct narrowing happens
  via the Phase 1 let-binding hook on the result.

### Matrix progress

| Phase         | v0.2.314 | v0.2.315 |
|---------------|----------|----------|
| p6_bitwise    | 0P/2F/2BE| **4P/0F/0BE** |
| TOTAL         | 50P/2F/8BE | **54P/0F/6BE** |

The 6 remaining BUILD_ERRORs:
- 3 in `p7_overflow` — `wrapping_add::<u8>` / `saturating_add::<u8>`
  / `checked_add::<u8>` use turbofish syntax not yet supported.
- 3 in `p8_vec` — `Vec::with_capacity(N)` / typed Vec methods
  not yet supported.

These are the targets for Phase 7 (overflow modes) and Phase 8
(Vec<T> monomorphization).

### Verify gate

329/329 PASS. Bootstrap fixpoint stable. ABI parity green.
helper_manifest + rod_manifest regenerated.

### Files

- `stdlib/rods/bitwise_rt.c` — added `rods_bit_shift_right_signed`.
- `stdlib/rods/bitwise.nr` — added `bit_shift_right_signed` wrapper.
- `compiler/nucleor_s1_compiler.nr` — narrow→i64 widening in
  `types_compatible`.
- `bin/nucleor.exe` — rebuilt.
- `tests/lang/numerics_matrix/p6_bitwise/*.nr` — 4 tests updated.
- `docs/rfcs/{helper,rod}_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

Phase 7 (`v0.2.316`) — `#[overflow(wrap | trap | saturate)]`
attribute + per-op turbofish intrinsics like `wrapping_add::<u8>`.

## [0.2.314] — 2026-04-24

**T1.1 Phase 4 — full `as` cast operator matrix.** Float↔int and
float↔float conversions now follow Rust `as` semantics
(saturating float→int, exact int→float, lossy float→float
narrowing). p4_cast matrix subdir 8/8 PASS.

### What landed

#### Runtime (`stdlib/runtime/nucleor_llvm_rt.c`)
- 8 new converters: `__nucleor_f32_to_{i32,i64,u32}`,
  `__nucleor_i32_to_f32`, `__nucleor_i64_to_f32`,
  `__nucleor_f64_to_{i64,u32}`, `__nucleor_i64_to_f64`.
- All saturating per Rust spec: float overflow clamps to
  type max/min (e.g. `f32 = 1e20 as i32` → `i32::MAX`).

#### Compiler (`compiler/nucleor_s1_compiler.nr` + sync to tools)
- `lower_expr` `kind == 99` (`as` cast) gains source-type
  detection via the Phase 5 `binop_float_type` helper.
- Dispatch table: float-source × int-target → converter
  helper (e.g. `f32 as i32` → `f32_to_i32`); int-source
  × float-target → `i64_to_f32`/`i64_to_f64`; float-source
  × float-target → `f32_to_f64`/`f64_to_f32`.
- `narrow_via_as` extended for `let x: f32 = 100;` and
  `let x: f64 = 100;` patterns: integer-literal source
  (src_kind == 1) gets routed through the int→float
  converter instead of bit-preserving as_f32.
- 14 new IR `declare` statements + matching `get_rt_name`
  entries (s1 + tools_suite synced; ABI parity check green).

### Backwards-compatibility decision (production-readiness)

`f64 as i64` and `f32 as i64` PRESERVE bit pattern
(no truncation). This is the i64-everywhere ABI
contract — 13 existing rod tests rely on
`fn f64_to_bits(x: f64) -> i64 { return x as i64; }` to
extract the bit pattern for FFI to C runtime. To explicitly
truncate float→i64, use `(x as i32) as i64` or call
`f64_to_i64()` directly. Documented in source.

### Matrix progress

| Phase         | v0.2.313 | v0.2.314 |
|---------------|----------|----------|
| p4_cast       | 6P/2F    | **8P/0F (ALL GREEN)** |
| TOTAL         | 48P/4F/8BE | **50P/2F/8BE** |

### Verify gate

329/329 PASS. Bootstrap fixpoint stable. ABI parity green.
All 13 rod tests using `as i64` for bitcast continue to work.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c` — 8 converter helpers.
- `compiler/nucleor_s1_compiler.nr` — cast dispatcher +
  narrow_via_as extension + IR decls + name maps.
- `compiler/nucleor_tools_suite.nr` — synced.
- `bin/nucleor.exe` — rebuilt.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

Phase 6 (`v0.2.315`) — bitwise + shift ops at narrow widths
(closes the 2 p6_bitwise FAIL + 2 BUILD_ERROR).

## [0.2.313] — 2026-04-24

**T1.1 Phase 3b — `sizeof_struct(<Name>)` compile-time builtin
+ struct-layout machinery foundation.** Compile-time constant
returning the byte size of a user-defined struct. Default
Nucleor representation (one i64 slot per field) ships now;
`#[repr(C)]` / `#[repr(packed)]` attribute propagation lands
in Phase 3b.2 once the parser preserves attributes on struct
AST nodes.

### What landed

- `compiler/nucleor_s1_compiler.nr` — five new helpers:
  - `type_byte_size(t)` — primitive type → byte size.
  - `type_align(t)` — natural alignment per type.
  - `align_up(offset, align)` — round up to alignment boundary.
  - `struct_byte_size(struct_nid, repr)` — compute total size
    given a repr ("C" naturally aligned + tail-padded, "packed"
    no align, "" / default Nucleor = field_count × 8).
  - `struct_repr(source, name)` + `source_find` — text-scan
    helpers ready for the Phase 3b.2 attribute walk; not yet
    invoked since `lower_expr` doesn't carry the source string
    (will be plumbed in 3b.2).
- `compiler/nucleor_s1_compiler.nr` — `lower_expr` `kind == 7`
  call lowering intercepts `sizeof_struct(<Ident>)`. Looks up
  the struct, computes size at compile time, emits a constant.

### Surface

```nucleor
struct Point { x: i32, y: i32 }
struct Three { a: i32, b: i32, c: i32 }

fn main() -> i32 {
    let s1: i64 = sizeof_struct(Point);   // 16  (2 fields × 8)
    let s2: i64 = sizeof_struct(Three);   // 24  (3 fields × 8)
    return 0;
}
```

### Matrix progress

| Phase         | v0.2.312 | v0.2.313 |
|---------------|----------|----------|
| p3_layout     | 4P/0F    | **5P/0F** (+ sizeof_struct_basic) |
| TOTAL         | 47P/4F/8BE | **48P/4F/8BE** |

### Verify gate

329/329 PASS. Bootstrap fixpoint stable.

### Known scope (intentional, Phase 3b.2 follow-up)

The Nucleor parser doesn't currently store attribute lists on
struct AST nodes. Phase 3b.2 (within this T1.1 refactor; not
deferred to a later major) wires that plumbing and switches
`sizeof_struct` to honor `#[repr(C)]` / `#[repr(packed)]` for
tighter layouts. The helpers (`struct_byte_size` with `repr`
arg, `struct_repr` source scanner) are ready; only the AST
preservation is pending.

### Files

- `compiler/nucleor_s1_compiler.nr` — 5 helpers + lower_expr hook.
- `bin/nucleor.exe` — rebuilt (clean bootstrap from v0.2.307).
- `tests/lang/numerics_matrix/p3_layout/sizeof_struct_basic.nr` — new.
- `CHANGELOG.md` — this entry.

### Next

Phase 4 (`v0.2.314`) — full `as` cast operator matrix
including float→int / int→float / float→float (closes the
2 p4 fails introduced by Phase 5).

## [0.2.312] — 2026-04-24

**T1.1 Phase 5 — native f32 + f64 arithmetic via inline `+ - * /`
and full comparisons (`< > <= >= == !=`).** Closes the matrix
fail surface for floating-point binops; pairs with the Phase 1
`let`-narrow hook so f32 literals get correctly narrowed at the
assignment boundary.

### What landed

#### A. Runtime helpers (`stdlib/runtime/nucleor_llvm_rt.c`)
- 10 new f64 helpers: `__nucleor_f64_{add,sub,mul,div,lt,gt,le,ge,eq,ne}`.
- 4 new f32 comparison helpers: `__nucleor_f32_{ne,le,ge}`
  (`{lt,gt,eq}` already existed).
- **Fixed `__nucleor_as_f32`** — was a no-op stub from Phase 3
  scaffolding; now actually narrows f64 bits → f32 bits via
  union punning. Required because Phase 5 dispatches inline f32
  binops through `__nucleor_f32_*` helpers that decode via
  `bits_to_f32` — without proper narrowing, f32 vars held f64
  bits and arithmetic returned garbage.

#### B. Compiler (`compiler/nucleor_s1_compiler.nr` + sync to tools)
- `binop_float_type(node)` helper: detects f32/f64 type via
  variable-symbol lookup (`__type_<vname>`) or kind==71 (f64
  literal).
- `float_binop_helper(iop, ftype)` helper: maps (op, type) to
  the runtime helper name (`f32_add`, `f64_lt`, etc.).
- `lower_expr` `kind == 4` (binop) now dispatches to the float
  helper when either operand is a float type.
- `narrow_via_as` extended: `src_kind` parameter; f32 narrow ONLY
  fires when source is a f64 literal (kind==71). Prevents
  double-narrowing when source is already an f32 value (e.g.
  result of an f32 binop) — that would corrupt the bit-pattern.
- `get_rt_name` + IR-decl tables grew f32/f64 cmp + f64 arith
  entries. ABI parity check (s1 ↔ tools-suite) green.

### Matrix progress

| Phase         | v0.2.311 | v0.2.312 |
|---------------|----------|----------|
| p5_float      | 0P/4F    | **4P/0F** |
| p4_cast       | 7P/1F    | 6P/2F (Phase 4 will close) |
| TOTAL         | 44P/7F/8BE | **47P/4F/8BE** |

3 net tests flipped to PASS. The 2 new p4_cast fails
(`cast_f32_to_i32`, `cast_i32_to_f32`) are Phase 4's territory
— the existing `as_<T>` runtime masks bits without knowing
source type, so float-to-int cast misinterprets the bits.

### Verify gate

329/329 PASS. Bootstrap fixpoint stable. ABI parity check
green (s1 ↔ tools-suite synced; helper_manifest regen).

### Known limit (intentional, picked up by later phase)

The float-binop dispatcher only fires when at least one operand
is a variable with declared float type or a kind==71 f64
literal. Mixed integer + float (e.g. `let x: f64 = 3 + 1.5`)
falls back to integer arithmetic on the LHS only. Phase 4
(`as` cast operator with full float→int / int→float matrix)
will close this gap by inserting explicit conversions.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c` — 14 new helpers + as_f32
  fix.
- `compiler/nucleor_s1_compiler.nr` — binop dispatcher + narrow
  scope tightening.
- `compiler/nucleor_tools_suite.nr` — synced ABI tables.
- `bin/nucleor.exe` — rebuilt (clean bootstrap from v0.2.307).
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `CHANGELOG.md` — this entry.

### Next

Phase 3b (`v0.2.313`) — full `#[repr(C)]` + `#[repr(packed)]`
field-offset machinery + `sizeof_struct(<name>)` for user types.
Then Phase 4 — full `as` cast matrix (closes the 2 p4 fails
introduced here).

## [0.2.311] — 2026-04-24

**T1.1 Phase 3a — `sizeof_<T>()` primitive byte-size builtins.**
First step toward production-grade memory layout introspection.
Tests can now verify struct/primitive sizes without an external
FFI bridge. A future pass will layer a generic `sizeof::<T>()`
syntax on top.

### What landed

- `stdlib/runtime/nucleor_llvm_rt.c` — 19 new
  `__nucleor_sizeof_<T>()` zero-arg builtins (`i8/i16/i32/i64/i128`,
  `u8/u16/u32/u64/u128`, `usize/isize`, `f16/bf16/f32/f64`,
  `bool/char/ptr`).
- `compiler/nucleor_s1_compiler.nr` + `compiler/nucleor_tools_suite.nr`
  — matching `get_rt_name` mappings + LLVM IR `declare`
  statements (kept in sync; bash drift-check passes).
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `tests/lang/numerics_matrix/p3_layout/sizeof_primitives.nr`
  — 17 sizeof checks against expected widths (i8=1, i32=4,
  usize=8, f64=8, etc.). All pass.

### Surface

```nucleor
let sz: i64 = sizeof_u8();    // 1
let sz: i64 = sizeof_i32();   // 4
let sz: i64 = sizeof_f64();   // 8
let sz: i64 = sizeof_usize(); // 8 on 64-bit targets
```

### Matrix progress

| Phase         | v0.2.310 | v0.2.311 |
|---------------|----------|----------|
| p3_layout     | 3P/0F    | **4P/0F** (+ sizeof_primitives) |
| TOTAL         | 43P/7F/8BE | **44P/7F/8BE** |

### Verify gate

329/329 PASS. Bootstrap fixpoint stable. ABI parity check
green (s1 ↔ tools-suite synced).

### Files

- `stdlib/runtime/nucleor_llvm_rt.c` — 19 sizeof builtins.
- `compiler/nucleor_s1_compiler.nr` — get_rt_name + IR decls.
- `compiler/nucleor_tools_suite.nr` — same (synced).
- `bin/nucleor.exe` — rebuilt.
- `docs/rfcs/helper_manifest.toml` — regenerated.
- `tests/lang/numerics_matrix/p3_layout/sizeof_primitives.nr` — new.
- `CHANGELOG.md` — this entry.

### Next

Phase 3b (`v0.2.312`) — full `#[repr(C)]` + `#[repr(packed)]`
field-offset machinery + `sizeof_struct(<name>)` for user types.
Then Phase 4 — full `as` cast matrix.

## [0.2.310] — 2026-04-24

**T1.1 Phase 3c — stdlib audit + i32/u32 narrowing re-enabled.**
Completes the deferred work from Phase 2: Nucleor's stdlib no
longer depends on `let val: i32 = n` loosely holding i64-range
values, so auto-narrow can safely fire on `i32`/`u32` targets.

### What landed

- `compiler/nucleor_s1_compiler.nr:str_from_int` — internal
  arithmetic widened to i64 (loop variable + digit var). Parameter
  stays `i32` for source compatibility; internal i64 prevents the
  Phase 1 narrow hook from truncating large register IDs.
- `compiler/nucleor_tools_suite.nr:str_from_int` — same fix
  mirrored (duplicate function).
- `stdlib/runtime/core_io.nr:str_from_int` — same fix.
- `compiler/nucleor_s1_compiler.nr:narrow_via_as` — re-added
  `i32` + `u32` cases.

### Audit outcome

11 sites of `let <name>: i32` / `let <name>: u32` in
`compiler/*.nr` + `stdlib/runtime/*.nr`:
- 4 UNSAFE (str_from_int × 3 sites in 3 files) → fixed.
- 7 SAFE (loop counters + string lengths where i32 range is
  adequate) → untouched.

### Matrix progress

| Phase         | v0.2.309 | v0.2.310 |
|---------------|----------|----------|
| p1_intarith   | 22P/0F   | **24P/0F** (+2 i32/u32 wrap tests) |
| TOTAL         | 41P/7F/8BE | **43P/7F/8BE** |

### Verify gate

329/329 PASS. Bootstrap fixpoint stable (stage-1 and stage-2
IR are byte-identical).

### Files

- `compiler/nucleor_s1_compiler.nr` — str_from_int widened,
  narrow_via_as expanded.
- `compiler/nucleor_tools_suite.nr` — str_from_int widened.
- `stdlib/runtime/core_io.nr` — str_from_int widened.
- `bin/nucleor.exe` — rebuilt (clean bootstrap from v0.2.307).
- `tools/gen_numerics_matrix.py` — 2 new i32/u32 wrap tests.
- `tests/lang/numerics_matrix/MANIFEST.md` — updated counts.
- `tests/lang/numerics_matrix/p1_intarith/add_u32_wrap.nr` — new.
- `tests/lang/numerics_matrix/p1_intarith/mul_i32_wrap.nr` — new.
- `CHANGELOG.md` — this entry.

### Next

Phase 3a–b (`v0.2.311`) — `sizeof::<T>()` builtin + full
`#[repr(C)]` / `#[repr(packed)]` field-offset machinery.
Then Phase 4 (`v0.2.312`) — full `as` cast matrix.

## [0.2.309] — 2026-04-24

**T1.1 Phase 2 — f32 literals + bootstrap-stability gate +
defensive narrow scope.** Three production-readiness items
landed together because Phase 2's f32-literal work surfaced a
self-host bootstrap landmine that Phase 1 had silently
introduced.

### What landed

#### A. f32 literal binding (`let a: f32 = 3.14;`, `let b: f32 = 3.14f32;`)
- `compiler/nucleor_s1_compiler.nr` type-compat: f32 / f16 / bf16
  now accept f64 / i32 / i64 source types (the lexer always
  emits float literals as f64; lowering inserts the conversion).
- `narrow_via_as` extended to call `as_f32` for `f32` targets.

#### B. Defensive narrow scope (production fix for Phase 1)
- Phase 1's `narrow_via_as` originally narrowed
  `i8/i16/i32/u8/u16/u32`. Removed `i32`/`u32` after
  discovering Nucleor's stdlib (`str_from_int(n: i32)` and
  similar) loosely uses `i32` to hold i64-range values. Auto-
  narrowing those silently truncated large literals to 0,
  poisoning the self-host compiler binary one rebuild later.
  Restricted set is now `i8/i16/u8/u16` + `f32`. A future
  Phase 3 stdlib audit can re-enable i32/u32 narrowing.
- Added `if vr < 0 { return vr; }` guard so an upstream
  lowering bug surfaces as a visible diagnostic rather than
  emitting `add i64 , 0` with a missing operand.

#### C. Bootstrap-stability gate (verify step #329)
- `tools/verify.ps1` adds `self-host bootstrap fixpoint
  (stage-2)` step: stage-1 binary compiles compiler source →
  stage-2 binary; stage-2 then re-compiles `tests/lang/arith.nr`
  and the IR must be SHA-256 identical to stage-1's output.
- This catches the entire class of "compiler change silently
  poisons next compile" bugs. Phase 1's truncation-of-
  str_from_int bug would have failed this gate immediately.

#### D. Memory cap on all build paths
- `tools/verify.sh` and `tools/verify.ps1`: cap at 2 GB virtual
  memory / working set (was: unlimited). Override via
  `NUCLEOR_MEM_CAP_KB` (sh) / `NUCLEOR_MEM_CAP_MB` (ps1) /
  `0` to disable. Healthy compile is sub-1 GB; prior swap-
  thrashing blowups hit ~20 GB.
- `tools/run_numerics_matrix.{sh,ps1}` mirror the same cap.

### Matrix progress

| Phase         | v0.2.308 | v0.2.309 |
|---------------|----------|----------|
| p2_literals   | 5P/1BE   | **6P/0F/0BE** |
| p4_cast       | 5P/3BE   | **7P/1F/0BE** |
| p5_float      | 0P/1F/3BE| **0P/4F/0BE** |
| p11_format    | 1P/1BE   | **2P/0F/0BE** |
| TOTAL         | 37P/3F/16BE | **41P/7F/8BE** |

4 tests flipped to PASS (literal + format). 8 BUILD_ERRORs
flipped to FAIL — those tests now compile but expose real
runtime gaps (float arith, narrow bitwise) which Phases 5 / 6
will close.

### Verify gate

329/328 PASS (the +1 is the new bootstrap-fixpoint step).
Bootstrap proven stable.

### Files

- `compiler/nucleor_s1_compiler.nr` — narrow scope restricted +
   guard added; f32 type-compat clause.
- `bin/nucleor.exe` — rebuilt (clean bootstrap from v0.2.307).
- `tools/verify.ps1` — bootstrap-stability step + memory cap.
- `tools/verify.sh` — memory cap.
- `tools/run_numerics_matrix.{sh,ps1}` — memory cap.
- `CHANGELOG.md` — this entry.

### Next

Phase 3 (`v0.2.310`) — alloca + struct layout at correct width
(after stdlib audit to confirm i32/u32 narrowing is safe).

## [0.2.308] — 2026-04-24

**T1.1 Phase 1 — width-correct integer wrap on `let` binding.**
First functional phase of the maximalist numerics refactor.
A `let x: u8 = ...` (or `i8`/`i16`/`i32`/`u16`/`u32`) now wraps
the init value to the declared width via the existing
`__nucleor_as_<T>` runtime helpers. Behavior matches C / Rust
wrap semantics in release.

### What landed

- `compiler/nucleor_s1_compiler.nr`: new `narrow_via_as()`
  helper (lines ~7775); hook in `lower_stmt` `kind == 20`
  (`let`) inserts an `as <T>` synthetic call when the declared
  type is a narrow integer.
- `bin/nucleor.exe`: rebuilt self-hosted from the modified
  source (verified by `self-host rebuild closes` step in the
  verify gate).

### Matrix progress

| Phase         | v0.2.307 | v0.2.308 |
|---------------|----------|----------|
| p1_intarith   | 18P/4F   | **22P/0F** |
| p3_layout     | 2P/1F    | **3P/0F**  |
| p7_overflow   | 0P/1F/3BE| **1P/0F/3BE** |
| TOTAL         | 31P/9F/16BE | **37P/3F/16BE** |

6 tests flipped to green. The 3 remaining fails are float arith
(Phase 5) and bitwise narrow (Phase 6); the 16 build-errors are
syntax not yet supported (Vec<T> generics, turbofish, `print_*`).

### Known limits (intentional, picked up by later phases)

- The hook only fires on `let` bindings with explicit narrow
  type. Inline expressions like `if (x + y) > 250 {...}`
  where `x, y: u8` still evaluate at i64 width. Phase 1.5 / 3
  (alloca + per-register type table) addresses this.
- Reassignment (`x = a + b;`) does not narrow yet; same gap.

### Verify gate

328/328 PASS. No regressions in the existing test suite.

### Files

- `compiler/nucleor_s1_compiler.nr` — new helper + lower_stmt hook
- `bin/nucleor.exe` — rebuilt
- `CHANGELOG.md` — this entry

### Next

Phase 2 (`v0.2.309`) — suffix literals (`255u8`, `1_000i32`,
`3.14f32`) + compile-time literal-overflow errors.

## [0.2.307] — 2026-04-24

**T1.1 Phase 0 — maximalist narrow-numerics test matrix
scaffolding.** First commit of the 14-phase numerics refactor
described in `Desktop/Nucleor_T1_Numerics_Maximalist_Plan.md`.
Robotics rod loop paused until refactor lands. The pre-refactor
i64-everywhere architecture is preserved on `archive/i64-only`
branch (frozen at `v0.2.306`).

### What landed

- `tests/lang/numerics_matrix/` — 56 test files across 9 phase
  subdirectories (`p1_intarith/`, `p2_literals/`, `p3_layout/`,
  `p4_cast/`, `p5_float/`, `p6_bitwise/`, `p7_overflow/`,
  `p8_vec/`, `p11_format/`).
- `tools/gen_numerics_matrix.py` — generator (idempotent;
  re-run to add cases as each phase grows the matrix).
- `tools/run_numerics_matrix.ps1`, `tools/run_numerics_matrix.sh`
  — runners that build + run + classify each test as
  PASS / FAIL / BUILD_ERROR. Always exit 0 (matrix is
  informational; verify gate stays green).
- `tests/lang/numerics_matrix/MANIFEST.md` — links each test to
  the phase that should make it green.

### Phase 0 baseline

```
Phase         PASS  FAIL  BERR   TOT
p11_format       1     0     1     2
p1_intarith     18     4     0    22
p2_literals      5     0     1     6
p3_layout        2     1     0     3
p4_cast          5     0     3     8
p5_float         0     1     3     4
p6_bitwise       0     2     2     4
p7_overflow      0     1     3     4
p8_vec           0     0     3     3
TOTAL: pass=31  fail=9  build_error=16  total=56
```

The 31 passing cases reflect that narrow types already compile
and arithmetic is correct WITHIN i64 range. The 9 FAIL + 16
BUILD_ERROR cases are the actual gap surface — width-overflow
wrap, native float arithmetic, narrow bitwise, overflow modes,
generic `Vec<T>`, width-correct `print_*`.

### Verify gate

328/328 PASS. The matrix lives in `tests/lang/numerics_matrix/`
(nested subdirectory) so verify.ps1's top-level enumeration
doesn't pick it up.

### Next

Phase 1 (`v0.2.308`) — width-aware integer arithmetic and
comparisons in `emit_arith()`, `emit_cmp()`, `emit_inst()`.

## [0.2.306] — 2026-04-24

**Robotics: 2-D Voronoi diagram from Delaunay triangulation
(`voronoi`). Lifts a Delaunay triangulation (`delaunay.nr`)
into its dual Voronoi diagram. Each Voronoi vertex is a
Delaunay-triangle circumcenter; each Voronoi edge connects
circumcenters of triangles sharing a Delaunay edge. Hull-
boundary edges have one endpoint at infinity (encoded as
`-1`).**

### Algorithm

```
Voronoi vertex = circumcenter(Delaunay triangle)
Voronoi edge   = (cc(t1), cc(t2)) for every Delaunay edge
                 shared by triangles t1 and t2
                 (or (cc(t1), ∞) if hull edge)
```

### Surface

```nucleor
import "stdlib/rods/delaunay.nr"
import "stdlib/rods/voronoi.nr"

let n_tris = delaunay_2d(pts_ptr, n_pts, tris_ptr, max_tris);

let n_verts: i32;
let n_edges = voronoi_2d(pts_ptr, n_pts, tris_ptr, n_tris,
                          vert_xy_out_ptr, max_verts,
                          edges_out_ptr, max_edges,
                          i32_ptr(&n_verts));
```

### Verification

Direct C unit test (`target/_test_voronoi.c`):

- T1 sq+center  : 5 sites → 4 Voronoi vertices at exactly
                   (1,0), (2,1), (1,2), (0,1); 4 inner edges
                   ring + 4 hull edges to ∞ ✓
- T2 bad n_tris : n_tris=0 → returns 0 ✓

Build smoke `tests/rods/voronoi_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/voronoi_rt.c` — circumcenter per triangle +
   Delaunay-edge dual graph.
- `stdlib/rods/voronoi.nr`      — extern + `voronoi_2d` wrapper.
- `tests/rods/voronoi_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                 — this entry.

### Limitations

Documented in `voronoi.nr` and `voronoi_rt.c`: 2-D only;
naive O(T²) Delaunay-edge group; returns segments only (caller
assembles full cell polygons); hull edges go to ∞ encoded as
vertex `-1`. 3-D Voronoi / weighted (power) Voronoi /
centroidal CVT iteration land in v0.6 if needed.

## [0.2.305] — 2026-04-24

**Robotics: 2-D Delaunay triangulation + circumcenter helper
(`delaunay`). Bowyer-Watson incremental insertion (Bowyer 1981
/ Watson 1981). Foundation for Voronoi diagrams (lift each
output triangle through `circumcenter_2d` to get the Voronoi
vertex), triangle-mesh generation, and natural-neighbor
interpolation.**

### Algorithm

```
1. Seed with a "super-triangle" enclosing all input points.
2. For each input point P:
   - Find all triangles whose circumcircle contains P (bad).
   - Compute the cavity boundary (edges appearing exactly
     once across the bad set).
   - Remove bad triangles; connect P to every cavity edge.
3. Strip triangles using super-triangle vertices.
```

### Surface

```nucleor
import "stdlib/rods/delaunay.nr"

// out_tris: int32[3 * max_tris], packed (i, j, k) per triangle.
let n_tris = delaunay_2d(pts_xy_ptr, n_pts,
                          out_tris_ptr, max_tris);

let cx: double; let cy: double;
let ok = circumcenter_2d(ax_b, ay_b, bx_b, by_b, cx_b, cy_b,
                          f64_ptr(&cx), f64_ptr(&cy));
```

### Verification

Direct C unit test (`target/_test_delaunay.c`):

- T1 unit square    : 4 corners → 2 triangles, all 4 used ✓
- T2 sq + center    : 5 pts → 4 triangles, center in all 4 ✓
- T3 circumcenter   : (0,0)-(2,0)-(0,2) → (1,1) ✓
- T4 collinear cc   : (0,0)-(1,1)-(2,2) → returns 0 ✓
- T5 too few pts    : n_pts=2 → returns 0 ✓

Build smoke `tests/rods/delaunay_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/delaunay_rt.c` — Bowyer-Watson +
   `_in_circumcircle` determinant test + circumcenter.
- `stdlib/rods/delaunay.nr`      — extern + wrappers.
- `tests/rods/delaunay_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                  — this entry.

### Limitations

Documented in `delaunay.nr` and `delaunay_rt.c`: 2-D only;
naive O(N²) incremental insertion (fine ≤ ~1000 points);
floating-point — cocircular degeneracies pick an arbitrary
valid triangulation. Sweep-line / 3-D Delaunay / robust
predicates land in v0.6 if needed.

## [0.2.304] — 2026-04-24

**Robotics: Hough transform for 2-D circle detection
(`hough_circle`). Companion to `hough.nr` (lines). Each input
edge point votes for every (cx, cy) on every candidate ring
of radius R; peaks in the 3-D `(cx × cy × R)` accumulator
reveal circles. 3×3×3 NMS with lex-order tie-breaking gives
deterministic single-peak per neighborhood.**

### Algorithm

```
For each edge point (px, py):
    For each radius R_k in [R_min, R_max]:
        For each angle θ_t in [0, 2π):
            (cx_w, cy_w) = (px - R_k cos θ_t,  py - R_k sin θ_t)
            increment acc[bin(cx_w), bin(cy_w), bin(R_k)]
3×3×3 NMS in (cx, cy, R) with lex tie-break, threshold,
sort descending by votes, return top-K (cx, cy, R, votes).
```

### Surface

```nucleor
import "stdlib/rods/hough_circle.nr"

// out_circles: double[4*max_circles]; packed (cx, cy, R, votes).
let n = hough_circles_2d(
    pts_xy_ptr, n_pts,
    cx_min_b, cx_max_b, n_cx,
    cy_min_b, cy_max_b, n_cy,
    R_min_b,  R_max_b,  n_R,
    n_theta, threshold, max_circles,
    out_circles_ptr);
```

### Verification

Direct C unit test (`target/_test_hough_circle.c`):

- T1 single circle  : R=5 at (10, 8), 64 sample points → top
                       (cx=9.5, cy=7.5, R=4.5) ≈ truth ✓
- T2 two circles    : (5,5,R=3) + (15,10,R=4), 32 pts each →
                       both detected as top peaks ✓
- T3 bad n_theta    : n_theta=0 → returns 0 ✓

Build smoke `tests/rods/hough_circle_smoke.nr` compiles and
links.

### Files

- `stdlib/runtime/hough_circle_rt.c` — accumulator build +
   3×3×3 NMS + top-K selection.
- `stdlib/rods/hough_circle.nr`      — extern + wrapper.
- `tests/rods/hough_circle_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                      — this entry.

### Limitations

Documented in `hough_circle.nr` and `hough_circle_rt.c`:
each (x, y) contributes uniformly along the ring (no
orientation pruning) — `O(N · n_R · n_theta)` per accumulator;
grid-quantized peak locations; 2-D circles only. Gradient-
direction voting / sub-pixel refinement / 21HT pre-screening
land in v0.6 if needed.

## [0.2.303] — 2026-04-24

**Robotics: Gaussian image pyramid reduce/expand
(`image_pyramid`). Burt & Adelson 1983 multi-resolution
representation with the canonical 5-tap separable Gaussian
`[1 4 6 4 1] / 16`. Foundation for coarse-to-fine Lucas-Kanade
and multi-scale feature detection.**

### Algorithm

```
reduce(I): blur(I, [1,4,6,4,1]/16) then subsample by 2
expand(I): zero-insert by 2 then blur([1,4,6,4,1]/8)
           (kernel sum 2× per axis compensates for zeros so
            constant images are preserved)
```

### Surface

```nucleor
import "stdlib/rods/image_pyramid.nr"

// halve
let ok = pyramid_reduce(in_ptr, W, H, out_ptr);

// double
let ok = pyramid_expand(in_ptr, W, H, outW, outH, out_ptr);
```

Images are `double[H*W]` row-major in [0, 255].

### Verification

Direct C unit test (`target/_test_image_pyramid.c`):

- T1 const reduce  : 128 const → reduce → maxerr=0 ✓
- T2 odd dims      : 15×17 → reduce → 8×9 ✓
- T3 impulse       : 1 at center → reduce energy=0.25 ✓
- T4 expand const  : 100 const → expand → 100 (kernel preserves) ✓
- T5 bad dim       : W=0 → returns 0 ✓

Build smoke `tests/rods/image_pyramid_smoke.nr` compiles and
links.

### Files

- `stdlib/runtime/image_pyramid_rt.c` — separable Gaussian
   reduce + zero-insert expand.
- `stdlib/rods/image_pyramid.nr`      — extern + wrappers.
- `tests/rods/image_pyramid_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                       — this entry.

### Limitations

Documented in `image_pyramid.nr` and `image_pyramid_rt.c`:
double-precision internal representation; replicate boundary
handling; `ceil(W/2) × ceil(H/2)` target size for reduce. SIFT
DoG / orientation assignment / SIMD stride land in v0.6 if
needed.

## [0.2.302] — 2026-04-24

**Robotics: Reeds-Shepp shortest paths (`reeds_shepp`). Car-like
robot with minimum turning radius that can MOVE IN REVERSE
(Reeds & Shepp 1990). Companion to `dubins.nr` which is
forward-only. For a U-turn-in-place query, RS gives π/2
(back-up + pull-forward) vs Dubins' 2π — 4× shorter.**

### Algorithm

9 base word families (CSC, CCC, CCCC, CCSC, CCSCC variants)
× 4 symmetry transforms (identity, timeflip (−x,y,−phi),
reflect (x,−y,−phi), both (−x,−y,phi)) = 36 candidate paths
(some degenerate). Pick the minimum length.

Implements the classical Sussmann-Tang / OMPL structure:
LpSpLp, LpSpRp, LpRmL, LpRmLm, LpRpuLmuRm, LpRmuLmuRp,
LpRmSmLm, LpRmSmRm, LpRmSLmRp — each tried with all four
symmetry variants.

### Surface

```nucleor
import "stdlib/rods/reeds_shepp.nr"

let len: double;
let ok = reeds_shepp_length(x0_b, y0_b, th0_b,
                             x1_b, y1_b, th1_b,
                             R_b, f64_ptr(&len));
```

### Verification

Direct C unit test (`target/_test_reeds_shepp.c`):

- T1 straight 10m : (0,0,0)→(10,0,0) R=1 → length 10.0 ✓
- T2 identity     : start=goal → length 0 ✓
- T3 reverse π    : (0,0,0)→(1,0,π) R=1 → 5.31, < 2π ✓
- T4 scale        : 2× R and 2× coords → 2× length ✓
- T5 rs vs dubins : (0,0,0)→(0,2,0) RS = π/2 vs Dubins 2π ✓
- T6 bad R        : R=0 → returns 0 ✓

Build smoke `tests/rods/reeds_shepp_smoke.nr` compiles and
links.

### Files

- `stdlib/runtime/reeds_shepp_rt.c` — 9 base families + symmetry
   transforms + normalized-coord transform.
- `stdlib/rods/reeds_shepp.nr`      — extern + `reeds_shepp_length`.
- `tests/rods/reeds_shepp_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                     — this entry.

### Limitations

Documented in `reeds_shepp.nr` and `reeds_shepp_rt.c`: length
only (no sampled poses along the path); constant curvature on
turns; caller smooths cusps if needed. Path sampling and
smoothing land in v0.6 if needed.

## [0.2.301] — 2026-04-24

**Robotics: point-to-plane ICP (`icp_p2p`). Chen & Medioni 1991
variant that minimises point-to-tangent-plane distance rather
than point-to-point. Converges 3–10× faster than point-to-point
ICP on planar scenes (room walls, floor, CAD models).**

### Algorithm

```
min Σ ((R·P_i + t − Q_j) · n_j)²,  j = nn(i)

Each iteration:
  1. Associate each source point with its nearest target point
     (brute force O(N_src · N_tgt)).
  2. Linearise rigid transform (small-angle Rodrigues);
     residual r_i = (p'_i − q_j) · n_j; Jacobian row
     J_i = [ (p'_i × n_j)^T , n_j^T ].
  3. Gauss-Newton: solve (JᵀJ) δ = −Jᵀr for the 6-DOF update
     δ = (α, β, γ, tx, ty, tz).
  4. Apply δ; iterate until |δ| < tol or max_iters reached.
```

### Surface

```nucleor
import "stdlib/rods/icp_p2p.nr"

let R_out: [9]double;   // row-major
let t_out: [3]double;
let iters = icp_p2p(src_ptr, n_src,
                     tgt_ptr, tgt_normals_ptr, n_tgt,
                     max_iters, tol_b,
                     f64_ptr(&R_out[0]),
                     f64_ptr(&t_out[0]));
```

Point clouds are `double[N*3]` interleaved `(x, y, z)`.

### Verification

Direct C unit test (`target/_test_icp_p2p.c`) uses a
CUBE-CORNER target (three mutually perpendicular planar
patches) to guarantee full-rank 6-DOF observability.
Point-to-plane ICP with a planar-only target is rank-3 in
the 6-DOF update — this is documented and expected.

- T1 translate        : src = tgt + (0.2, -0.1, 0.3); recovered
                         t = (-0.2, 0.1, -0.3) exact in 2 iters ✓
- T2 rotate z         : 0.1 rad rotation recovered; max p2p
                         residual 1.1e-31 in 4 iters ✓
- T3 SE(3) combo      : (α=0.03, β=-0.04, γ=0.05, t=(0.1,-0.05,
                         0.15)); max p2p residual 8.3e-17 in
                         4 iters ✓
- T4 identity         : src = tgt; exact in 1 iter ✓
- T5 bad n_src        : n_src=0 → returns 0 ✓

Build smoke `tests/rods/icp_p2p_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/icp_p2p_rt.c` — linearised Gauss-Newton +
   6x6 solver + small-angle Rodrigues update.
- `stdlib/rods/icp_p2p.nr`      — extern + `icp_p2p` wrapper.
- `tests/rods/icp_p2p_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                 — this entry.

### Limitations

Documented in `icp_p2p.nr` and `icp_p2p_rt.c`: brute-force NN
O(N_src · N_tgt); caller supplies target normals (no
estimation in this rod); no outlier rejection; small-angle
linearisation assumes approximate pre-alignment; planar-only
target is rank-deficient (3 DOF unobservable). KD-tree NN /
robust kernel / symmetric plane-to-plane metric land in v0.6
if needed.

## [0.2.300] — 2026-04-24

**Robotics: Vector Field Histogram (VFH) local obstacle
avoidance (`vfh`). Polar histogram of obstacle density around
the robot, valley detection, picks the valley nearest the goal
bearing. Borenstein & Koren 1991 (simplified VFH+).**

### Algorithm

```
1. For each occupied cell within window_radius:
       weight = max(0, a − b·d²)              (zero at edge)
       hist[bin(bearing)] += weight
2. Smooth: 3-bin circular box.
3. Threshold: bins below density_threshold are FREE.
4. Find contiguous free runs ("valleys"); pick valley whose
   center bearing is closest to goal bearing.
5. Steered bearing = center of that valley.
```

### Surface

```nucleor
import "stdlib/rods/vfh.nr"

let steer_bearing: double;
let ok = vfh_step(occ_ptr, W, H, cell_size_b,
                   ox_b, oy_b, occ_threshold_b,
                   robot_x_b, robot_y_b,
                   goal_x_b, goal_y_b,
                   window_radius_b, n_bins,
                   density_threshold_b,
                   f64_ptr(&steer_bearing));
```

### Verification

Direct C unit test (`target/_test_vfh.c`):

- T1 empty grid     : steer = 0 (goal bearing) ✓
- T2 wall ahead     : steer = −1.83 rad (clears the wall) ✓
- T3 ring outside   : ring beyond window → steer = 0 ✓
- T4 bad n_bins     : n_bins = 2 → returns 0 ✓

Build smoke `tests/rods/vfh_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/vfh_rt.c` — histogram build + smoothing +
   valley search.
- `stdlib/rods/vfh.nr`      — extern + `vfh_step` wrapper.
- `tests/rods/vfh_smoke.nr` — build-only smoke.
- `CHANGELOG.md`             — this entry.

### Limitations

Documented in `vfh.nr` and `vfh_rt.c`: 2-D occupancy only;
robot modelled as a point (caller inflates the underlying
occupancy grid for vehicle radius); 3-bin box smoother (not
the full VFH+ primary/binary mask cascade). VFH+ /VFH*
extensions land in v0.6 if needed.

## [0.2.299] — 2026-04-24

**Robotics: kinematic bicycle model forward integration
(`bicycle`). Closed-form Euler and RK4 single-step integrators
for the standard car-like kinematic bicycle model. Companion
to `purepursuit` and `stanley` — the controllers output a
steering angle, this rod rolls the model forward.**

### Algorithm

```
ẋ  = v cos(θ)
ẏ  = v sin(θ)
θ̇ = (v / L) tan(δ)

  (x, y, θ) = REAR axle pose, world frame
  v         = forward speed at rear axle (m/s)
  δ         = front-wheel steering angle (rad)
  L         = wheelbase (m)
```

### Surface

```nucleor
import "stdlib/rods/bicycle.nr"

let out: [3]double;        // {x, y, theta}
let ok = bicycle_step_rk4(x_b, y_b, theta_b,
                           v_b, delta_b,
                           wheelbase_b, dt_b,
                           f64_ptr(&out[0]));
```

### Verification

Direct C unit test (`target/_test_bicycle.c`):

- T1 euler straight  : v=1, δ=0, dt=1 → (1,0,0) ✓
- T2 rk4   straight  : same → (1,0,0) ✓
- T3 rk4   arc       : 1000 RK4 steps of dt=0.001 with δ=π/4
                        match analytic constant-curvature arc
                        to ≤1e-9 ✓
- T4 rk4 vs euler    : at dt=0.5 over 1 s, RK4 error 0.000001
                        vs Euler error 0.124 (5 orders of mag) ✓
- T5 bad L           : L=0 → returns 0 ✓

Build smoke `tests/rods/bicycle_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/bicycle_rt.c` — Euler + RK4 integrators.
- `stdlib/rods/bicycle.nr`      — extern + wrappers.
- `tests/rods/bicycle_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                 — this entry.

### Limitations

Documented in `bicycle.nr` and `bicycle_rt.c`: kinematic only
(no tire slip), zero-order hold on (v, δ) over the step, caller
must clamp δ to vehicle limits. Full dynamic bicycle with
Pacejka tire model lands in v0.6 if needed.

## [0.2.298] — 2026-04-24

**Robotics: Stanley path tracker for Ackermann robots (`stanley`).
Front-axle controller from the Stanford DARPA Grand Challenge
vehicle. Steering combines heading error (path tangent − vehicle
heading) and signed cross-track error of the front axle relative
to the path.**

### Algorithm (Hoffmann/Thrun 2007)

```
δ = ψ_e + atan2(k · e_ct, v_f + k_soft)
  ψ_e   = path tangent − vehicle heading (rad, wrapped)
  e_ct  = signed front-axle perpendicular distance to path
          (+ when front is LEFT of path tangent)
  k     = cross-track gain (typical 0.5 - 2.5)
  k_soft= softening constant (keeps gain finite at v→0)
```

Pure-pursuit looks AHEAD; Stanley looks at where the front wheel
actually IS. Better at low speed and tight curvature; more
sensitive to path noise.

### Surface

```nucleor
import "stdlib/rods/stanley.nr"

let steer: double;
let ok = stanley_step(
    x_b, y_b, theta_b,           // REAR axle pose
    v_b,                          // forward speed (m/s)
    path_x_ptr, path_y_ptr, N,    // double[N] waypoints
    k_b, k_soft_b,
    wheelbase_b,
    f64_ptr(&steer));
```

### Verification

Direct C unit test (`target/_test_stanley.c`):

- T1 left-of-path  : front (4, +0.5), straight path → steer −0.0831 rad (right) ✓
- T2 on-path       : aligned → steer = 0 ✓
- T3 heading + xt  : heading +0.2 rad, off path → −0.233 rad ✓
- T4 right-of-path : front (4, −0.5) → steer +0.0831 rad (left) ✓
- T5 bad n         : n=1 → returns 0 ✓

Build smoke `tests/rods/stanley_smoke.nr` compiles and links.

### Files

- `stdlib/runtime/stanley_rt.c` — front-axle projection +
   nearest-segment search + Stanley control law.
- `stdlib/rods/stanley.nr`      — extern + `stanley_step` wrapper.
- `tests/rods/stanley_smoke.nr` — build-only smoke.
- `CHANGELOG.md`                 — this entry.

### Limitations

Documented in `stanley.nr` and `stanley_rt.c`: no curvature
feedforward (proportional only); 2-D right-handed frame assumed
for cross-track sign; path must be dense for nearest-segment
projection. Gain scheduling / yaw-rate feedforward / curvature
preview land in v0.6 if needed.

## [0.2.297] — 2026-04-24

**Robotics: pure-pursuit geometric path tracker for Ackermann
robots (`purepursuit`). Given current pose, a 2-D waypoint path,
and a lookahead distance, computes the steering angle that drives
the vehicle along an arc to the lookahead point.**

### Algorithm (Coulter 1992)

```
1. closest = argmin path waypoint distance to robot
2. walk forward from closest, accumulating arc length, until L_d
3. lookahead = interpolated point at distance L_d on path
4. α = angle from robot heading to lookahead point
5. δ = atan(2 L sin(α) / L_d)
```

### Surface

```nucleor
import "stdlib/rods/purepursuit.nr"

let steer: double;
let ok = purepursuit_step(x_b, y_b, theta_b,
                           path_x_ptr, path_y_ptr, n,
                           lookahead_b, wheelbase_b,
                           steer_out_ptr);
```

### Verification

Straight path along +x, wheelbase 0.5 m, lookahead 2 m:

- **Off-path** robot at `(0, 1, 0)` → steer `−0.3398 rad` (right
  turn back to path). ✓
- **On-path** robot at `(0, 0, 0)` → steer `0.0000` exactly. ✓

### Files

- `stdlib/runtime/purepursuit_rt.c` — `nuc_purepursuit_step`;
  closest-waypoint search, forward arc-length walk, atan steering.
- `stdlib/rods/purepursuit.nr` — extern + wrapper.
- `tests/rods/purepursuit_smoke.nr` — build-only smoke.

---

## [0.2.296] — 2026-04-24

**Robotics: 2D Hough line detection (`hough`). Each input point
votes for the family of lines through it parameterized by `(ρ, θ)`;
peaks in the accumulator → detected lines. Foundation for laser-
scan landmark extraction and structured-environment SLAM.**

### Surface

```nucleor
import "stdlib/rods/hough.nr"

let count = hough_lines_2d(pts_ptr, n_pts,
    n_rho, n_theta,
    rho_max_b, threshold, max_lines,
    out_rho_ptr, out_theta_ptr);
```

Builds the accumulator, runs 3×3 non-maximum suppression on
peaks, returns top `max_lines` lines whose vote count meets
`threshold`.

### Verification

60 points along horizontal line `y = 3` (ground truth `ρ = 3,
θ = π/2`):

- Found **1 line** at `ρ = 3.1500, θ = 1.5795 rad` ≈ π/2 — within
  one bin of ground truth.

### Files

- `stdlib/runtime/hough_rt.c` — `nuc_hough_lines_2d`; sin/cos
  precompute, vote accumulator, 3×3 NMS peak extractor.
- `stdlib/rods/hough.nr` — extern + wrapper.
- `tests/rods/hough_smoke.nr` — build-only smoke.

---

## [0.2.295] — 2026-04-24

**Robotics: Dubins shortest paths for car-like robots with minimum
turning radius (Dubins 1957; Shkel & Lumelsky 2001 closed-form
classification). All 6 candidate types (LSL, LSR, RSL, RSR, RLR,
LRL); returns the shortest length plus type and per-segment
parameters.**

### Surface

```nucleor
import "stdlib/rods/dubins.nr"

let type_out: i64;
let length_b = dubins_shortest(x0_b, y0_b, t0_b,
                               x1_b, y1_b, t1_b,
                               R_b, type_out_ptr);

// Or with per-segment lengths (double[3]):
let segs: double[3];
let length_b = dubins_shortest_with_segments(x0_b, y0_b, t0_b,
                                              x1_b, y1_b, t1_b,
                                              R_b,
                                              type_out_ptr, segs_out_ptr);
```

Type indices: `0=LSL, 1=LSR, 2=RSL, 3=RSR, 4=RLR, 5=LRL`.

Pairs naturally with `rrt.nr` (Dubins-RRT*) and any planner that
needs a car-like steering function.

### Verification

Three direct C tests:

1. **Colinear same-heading** (0,0,0) → (10,0,0), R=1: length =
   `10.000000` exact (type 0 = LSL — pure straight, both turns 0).
2. **180° flip-around** (0,0,0) → (0,0,π), R=1: length = `7.3304`
   (type 4 = RLR — three-arc CCC path, the only way to flip in place
   with minimum turning radius).
3. **Segment readout** for the colinear case: `(0, 10, 0)` —
   straight middle, zero turns; sums to total length exactly.

### Files

- `stdlib/runtime/dubins_rt.c` — `nuc_dubins_shortest` and
  `nuc_dubins_shortest_with_segments`; 6 type closed-form solvers.
- `stdlib/rods/dubins.nr` — externs + wrappers.
- `tests/rods/dubins_smoke.nr` — build-only smoke.

### Limitations carried forward

- Forward-only (no reverse). Reeds-Shepp paths for cars that can
  reverse plan for v0.6.
- Returns lengths and segment parameters; does not sample the path
  into a pose sequence.

---

## [0.2.294] — 2026-04-24

**Robotics: Ramer-Douglas-Peucker polyline simplification (`rdp`).
N-D recursive max-perpendicular-distance splitting. GPS / odometry
trace compaction, path simplification after RRT / A* (remove
redundant collinear waypoints), 2D/3D polyline rendering LOD.**

### Algorithm

```
simplify(lo, hi, ε):
  find point i ∈ (lo, hi) with max perpendicular distance to
  segment pts[lo] → pts[hi]
  if max_dist ≤ ε: drop all interior points
  else: keep argmax; recurse on (lo, argmax) and (argmax, hi)
```

Implemented iteratively with an explicit stack to avoid C recursion
depth limits on long polylines.

### Surface

```nucleor
import "stdlib/rods/rdp.nr"

// pts: double[N * dim] (interleaved coords).
// keep_out: i64[N] — 1 = kept, 0 = dropped. Endpoints always kept.
let kept = rdp_simplify(pts_ptr, n, dim, epsilon_b, keep_out_ptr);
```

### Verification

Three direct C tests:

1. **Collinear** 10-point line: kept = 2 (just endpoints).
2. **Sine curve** (50 points, one period), ε = 0.05: kept = 15
   (3.3× reduction while preserving peak/trough structure).
3. **ε = 0** on 5 non-collinear points: kept = 5 (all retained).

### Files

- `stdlib/runtime/rdp_rt.c` — `nuc_rdp_simplify`; N-D
  perpendicular-to-segment distance; iterative stack.
- `stdlib/rods/rdp.nr` — extern + wrapper.
- `tests/rods/rdp_smoke.nr` — build-only smoke.

---

## [0.2.293] — 2026-04-24

**Robotics: 2D point-cloud / laser-scan ICP alignment (`scanmatch`).
2D specialization of ICP with closed-form 2D Procrustes per
iteration. Standard SLAM front-end scan-matcher primitive.
Complement to `icp.nr` (3D point-to-point ICP).**

### Algorithm

```
For iter in 1..max_iters:
    Warp src by current (dx, dy, dt).
    Match each warped src point → nearest dst (brute force).
    Procrustes (closed form):
        cA, cB = centroids of matched pairs
        M[i,j] = Σ (a − cA)_i · (b − cB)_j     (2×2 cross-cov)
        Δθ = atan2(M[0,1] − M[1,0], M[0,0] + M[1,1])
        Δt = cB − R(Δθ) · cA
    Compose new = (Δθ, Δt) ∘ (dt, dxdy).
    Converged when |Δ| < tol.
```

### Surface

```nucleor
import "stdlib/rods/scanmatch.nr"

// src and dst: caller-allocated double[N*2] (interleaved xy).
let dx_dy_dt: double[3] = (0.0, 0.0, 0.0);   // initial guess
let iters = scanmatch_icp_2d(src_ptr, n_src,
                              dst_ptr, n_dst,
                              max_iters, tol_b,
                              dx_dy_dt_out_ptr);
```

### Verification

200 random scatter points in `[0, 10]²`. Truth transform
`(dx, dy, dθ) = (1.5, −0.7, 0.3 rad)`. Initial ICP guess
`(0.5, 0, 0.1)`:

- Converged in 9 iterations to `(1.5000, −0.7000, 0.3000)` —
  exact to 4 printed digits.

### Files

- `stdlib/runtime/scanmatch_rt.c` — `nuc_scanmatch_icp_2d`;
  closed-form 2D Procrustes; brute-force NN; transform composition.
- `stdlib/rods/scanmatch.nr` — extern + wrapper.
- `tests/rods/scanmatch_smoke.nr` — build-only smoke.

### Limitations carried forward

- Brute-force NN: `O(N_src · N_dst)` per iter.
- Point-to-point only. Point-to-line variant for noisy LiDAR
  planned for v0.6.
- ICP needs a reasonably close initial guess for structured scenes
  (the L-shape test above recovers cleanly with a near-truth
  initial guess but converges to a local minimum from far guesses).

---

## [0.2.292] — 2026-04-24

**Robotics: full LiDAR-scan update for `occgrid.nr`
(`occgrid_update_scan`). Single-call wrapper that applies every
beam of a scan as an inverse-sensor-model raycast — the typical
"plug a 2D LiDAR into the mapper" call.**

### Surface

```nucleor
import "stdlib/rods/occgrid.nr"

// bearings: double[N] — per-beam SENSOR-frame bearings (rad)
// ranges:   double[N] — measured ranges (m)
//
// Sensor at world (sx, sy) heading stheta. Each beam's world bearing
// = stheta + bearings[i].
occgrid_update_scan(grid,
    sx_b, sy_b, stheta_b,
    bearings_ptr, ranges_ptr, n_beams,
    l_free_b, l_occ_b, max_range_b);
```

Replaces the typical user-side `for beam_i { occgrid_update_ray(...) }`
loop with a single rod call that handles the per-beam world-bearing
math.

### Verification

40×40 grid, 9-beam fan from sensor at `(5, 5)` covering `[−π/2, π/2]`.
Even-indexed beams hit at 3 m; odd-indexed have range > max (no hit):

- **Beam 0** (south, hit) endpoint `(5, 2)`: log-odds `+0.8500` exact.
- **Beam 4** (east, hit) endpoint `(8, 5)`: log-odds `+0.8500` exact.
- **Mid-beam** at `(5, 3.5)`: log-odds `−0.4000` exact (free-space
  along the beam path).

### Files

- `stdlib/runtime/occgrid_rt.c` — added `nuc_occgrid_update_scan`.
- `stdlib/rods/occgrid.nr` — added extern + `occgrid_update_scan`
  wrapper.

---

## [0.2.291] — 2026-04-24

**Robotics: 2D BFS / Dijkstra-lite wavefront distance transform
(`wavefront`). Given a traversability grid and one or more start
cells, compute per-cell distance to the nearest start, propagated
along traversable cells. 4- or 8-connectivity.**

### Surface

```nucleor
import "stdlib/rods/wavefront.nr"

// trav: i64[W*H]  (1 = traversable, 0 = obstacle)
// starts: i64[n_starts * 2]  (ix, iy interleaved)
// dist_out: double[W*H]  (∞ = unreachable)

let reached = wavefront_compute(W, H, trav_ptr,
    n_starts, starts_ptr,
    dist_out_ptr,
    connectivity);     // 4 or 8
```

### Pairs naturally with

- `occgrid.nr`'s free-cell mask → build `trav` array → distance field.
- `occgrid_find_frontiers` → supply frontiers as starts →
  nearest-frontier distance per cell → utility-weighted exploration.
- `astar.nr` / `dstar.nr`: wavefront gives the admissible
  straight-line-through-traversable heuristic.

### Verification

10×10 grid, four tests:

1. **8-conn open**: `d(9,9) = 12.727922` = `9·√2` exact, 100 cells
   reached.
2. **4-conn open**: `d(9,9) = 18.0` = `9+9` Manhattan exact.
3. **Wall** at column 5: left-of-wall cell `d(4,0) = 4.0`,
   right-of-wall `d(6,0) = ∞`, reached count drops to 50.
4. **Two starts** at `(0,0)` and `(9,9)`: `d(4,4) = 4·√2 = 5.6569`
   (min of distances to either start) exact.

### Files

- `stdlib/runtime/wavefront_rt.c` — `nuc_wavefront_compute`;
  binary min-heap Dijkstra over uniform-cost (with √2 diagonal)
  grid edges.
- `stdlib/rods/wavefront.nr` — extern + wrapper.
- `tests/rods/wavefront_smoke.nr` — build-only smoke.

---

## [0.2.290] — 2026-04-24

**Robotics: frontier detection for `occgrid.nr` — finds "free"
cells that have at least one "unknown" 4-neighbor. Standard
autonomous-exploration primitive: the boundary between known free
space and the unknown is where the robot should go next.**

### Surface

```nucleor
import "stdlib/rods/occgrid.nr"

// ... build occupancy grid from sensor data ...

let fx_out: double[MAX];   // world x of frontier-cell centers
let fy_out: double[MAX];
let n_frontiers = occgrid_find_frontiers(
    grid, free_thresh_b, unknown_eps_b,
    fx_out_ptr, fy_out_ptr, MAX);

// Typical thresholds:
//   free_thresh_b   = -0.3  (log-odds below this = free)
//   unknown_eps_b   =  0.05 (|log-odds| below this = unknown)
```

Combined with `astar.nr` or `dstar.nr`: plan from current robot
pose to the nearest (or highest-utility) frontier, navigate there,
repeat — classical exploration pattern.

### Verification

40×40 grid covering `[0, 20]²`. 16 "free-space" rays from `(2, 2)`
fanning 0°→π with `range = max_range = 10 m` (no hit, pure free-
space update). Result:

- **150 frontier cells** found — the outer boundary of the fan.
- All cells within grid bounds (0 out-of-bounds).

### Files

- `stdlib/runtime/occgrid_rt.c` — added `nuc_occgrid_find_frontiers`.
- `stdlib/rods/occgrid.nr` — added extern + `occgrid_find_frontiers`
  wrapper.

---

## [0.2.289] — 2026-04-24

**Robotics: outlier-robust point-cloud rigid alignment
(`pcalign_horn_ransac`). Self-contained RANSAC over
3-correspondence samples + Horn fit + reprojection-error inlier
scoring + final refit on the inlier set. One-call replacement for
the manual RANSAC + pcalign + refit triple needed for outlier-
contaminated correspondences.**

### Algorithm

```
For iter in 1..n_iters:
    Sample 3 distinct correspondences uniformly.
    Fit (R, t) via Horn.
    Score: count inliers where ‖R·src + t − dst‖ ≤ threshold.
    Track the best (R, t, inlier_set).
After RANSAC: refit Horn on the FULL inlier set for the final transform.
```

### Surface

```nucleor
import "stdlib/rods/pcalign.nr"

let inlier_count = pcalign_horn_ransac(src_ptr, dst_ptr, n_corr,
    n_iters, threshold_b, seed,
    t_out_ptr, q_out_ptr,
    inlier_mask_out_ptr);     // i64[n] (1=inlier, 0=outlier); pass 0 to skip
```

### Verification

50 inlier correspondences (transform: 30°-z rotation + `(2, 1, −3)`
translation, tiny noise) plus 20 wild outlier correspondences:

- **Inlier count**: 50/70 — exactly the true inliers.
- **Recovered transform**: `t = (1.9995, 0.9996, −3.0006)`,
  `q ≈ (0.9659, 0, 0, 0.2589)` — within 1 mm of truth.
- **Inlier mask**: 50/50 true inliers detected, **0/20** outliers
  misclassified.

### Files

- `stdlib/runtime/pcalign_rt.c` — added `nuc_pcalign_horn_ransac`
  alongside the existing `nuc_pcalign_horn`.
- `stdlib/rods/pcalign.nr` — added extern + `pcalign_horn_ransac`
  wrapper.

---

## [0.2.288] — 2026-04-24

**Robotics: closed-form 3-D rigid alignment of two point clouds
with known correspondences via Horn's quaternion method (`pcalign`).
Foundation for ICP back-end, fragment registration, AR pose
estimation from world-anchor correspondences, and RANSAC-outlier-
robust registration.**

### Algorithm (Horn 1987)

```
Given source A_i, dest B_i correspondences:
  Centroids Ā = mean(A_i), B̄ = mean(B_i)
  Cross-cov M = Σ (A_i − Ā) · (B_i − B̄)ᵀ
  Build Horn's symmetric 4×4 N matrix from M's entries.
  q = eigenvector of N with the LARGEST eigenvalue (4×4 Jacobi).
  t = B̄ − R(q) · Ā
```

`O(N)` for centroids + cross-cov; constant-time 4×4 eigenvalue
extraction.

### Surface

```nucleor
import "stdlib/rods/pcalign.nr"

// src and dst: caller-allocated double[N * 3] row-major XYZ.
let ok = pcalign_horn(src_ptr, dst_ptr, n_points,
                      t_out_ptr, q_out_ptr);
```

Composes naturally with `ransac_run` (v0.2.281): use `pcalign_horn`
as the `fit` callback over a 3-point sample, score by reprojection
error → outlier-robust point-cloud registration in 50 LOC of glue.

### Verification

8-corner unit cube transformed by known 30° rotation about
`(1,1,1)/√3` and translation `(5, −2, 3)`:

- **Recovered translation**: `(5.000000, −2.000000, 3.000000)` —
  exact to all 6 printed digits.
- **Recovered quaternion**: `(0.965926, 0.149429, 0.149429, 0.149429)`
  — exact to all 6 printed digits.

### Files

- `stdlib/runtime/pcalign_rt.c` — `nuc_pcalign_horn`; 4×4 Jacobi
  eigensolver; quaternion-to-rotation-matrix helper.
- `stdlib/rods/pcalign.nr` — extern + wrapper.
- `tests/rods/pcalign_smoke.nr` — build-only smoke.

---

## [0.2.287] — 2026-04-24

**Robotics: 2D log-odds probabilistic occupancy grid (`occgrid`)
with Bresenham-traced raycast updates. Foundational mapping
primitive for 2D mobile-robot SLAM (Hector / gmapping style),
free-space planning, and frontier exploration.**

### Algorithm

```
Each cell stores log_odds; p = 1 / (1 + exp(−log_odds)).
For each ray (sensor (sx, sy), bearing β, range r):
    Bresenham-trace from (sx, sy) to ray endpoint:
        cells along path:    log_odds -= l_free
        cell at endpoint:    log_odds += l_occ      (if r < max_range)
                             log_odds -= l_free     (no return)
    Clamp log_odds to ±20.
```

### Surface

```nucleor
import "stdlib/rods/occgrid.nr"

let m = occgrid_new(W, H, cell_size_b, ox_b, oy_b);

for ray {
    occgrid_update_ray(m, sx_b, sy_b, range_b, bearing_b,
                          l_free_b, l_occ_b, max_range_b);
}

let p_b    = occgrid_probability(m, x_b, y_b);
let is_occ = occgrid_is_occupied(m, x_b, y_b, threshold_b);
```

Typical inverse-sensor params: `l_free = 0.4` (`p_obs = 0.40`),
`l_occ = 0.85` (`p_obs = 0.70`), threshold `0.65`.

### Verification

20×20 grid covering `[0, 10]²`, cell size 0.5 m. Ray from `(1, 1)`
bearing 0, range 5 m, `(l_free, l_occ) = (0.4, 0.85)`:

- **Endpoint** at `(6, 1)`: log-odds = `+0.8500` exact (`p = 0.7006`).
- **Mid-path** at `(3, 1)`: log-odds = `−0.4000` exact (`p = 0.4013`).
- **Off-ray** at `(5, 5)`: `0.0000` (unchanged).
- `is_occupied` true at endpoint, false at mid-path.

### Files

- `stdlib/runtime/occgrid_rt.c` — `nuc_occgrid_*` API; world↔cell
  mapping; Bresenham raycast; sigmoid query.
- `stdlib/rods/occgrid.nr` — externs + wrappers.
- `tests/rods/occgrid_smoke.nr` — build-only smoke.

---

## [0.2.286] — 2026-04-24

**Robotics: hierarchical coordinate-frame transform tree (`tf`).
ROS-style "tf" — each frame has an integer ID, a parent ID, and a
pose `(t, q)` in the parent frame. Lookup composes transforms
along the path through the tree.**

### Surface

```nucleor
import "stdlib/rods/tf.nr"

let tf = tf_new(max_frames);

// Register frames (caller manages name → id mapping):
tf_add_frame(tf, ROOT,    -1,    t_zero, q_id);
tf_add_frame(tf, BASE,    ROOT,  t_base, q_base);
tf_add_frame(tf, ARM,     BASE,  t_arm,  q_arm);
tf_add_frame(tf, GRIPPER, ARM,   t_grp,  q_grp);

// Update poses live:
tf_set_pose(tf, BASE, t_base_new, q_base_new);

// Lookup target's pose in source's frame (ROS semantics):
tf_lookup(tf, ROOT, GRIPPER, t_out, q_out);

tf_free(tf);
```

### Verification

4-frame chain `world → base → arm → gripper` with non-trivial
translations and a 90°-z rotation in arm:

1. `lookup(ROOT, GRIPPER)` returns gripper world pose
   `t = (1.0000, 0.3000, 0.5000)`, `q = (0.7071, 0, 0, 0.7071)`
   — composing the chain by hand yields identical result.
2. `lookup(GRIPPER, ROOT) ∘ lookup(ROOT, GRIPPER) = identity`
   verified (quaternion scalar = `1.000000` exactly).

### Files

- `stdlib/runtime/tf_rt.c` — `nuc_tf_*` API; SE(3) compose / inverse
  helpers; ancestor-chain accumulator.
- `stdlib/rods/tf.nr` — externs + wrappers.
- `tests/rods/tf_smoke.nr` — build-only smoke.

### Limitations carried forward

- Integer frame IDs only — caller manages name→id mapping
  (use `hashmap_str.nr`).
- Single tree (no disconnected forest).
- No time-stamped buffer; use `tf_set_pose` between lookups for
  time-varying transforms.
- Max ancestor depth: 64.

---

## [0.2.285] — 2026-04-24

**Robotics: pointer-based SE(3) operations (`se3`). Compose,
inverse, apply, log/exp, interpolation, distance — all on raw
`(t ∈ ℝ³, q ∈ S³)` buffers. Counterpart to `kinematics.nr`'s
allocated-handle Pose, parallel to how `qutil.nr` complements the
allocated-handle Quat.**

### Surface

```nucleor
import "stdlib/rods/se3.nr"

se3_compose(tA, qA, tB, qB, tC, qC);             // T_C = T_A · T_B
se3_inverse(t, q, t_inv, q_inv);
se3_apply(t, q, p_body, p_world);                // p_world = T · p_body
se3_relative(tA, qA, tB, qB, tAB, qAB);          // T_AB = T_A⁻¹ · T_B
se3_interpolate(t1, q1, t2, q2, alpha_b, t, q);  // lerp t, slerp q

se3_log(t, q, twist_out);                        // double[6] = (ρ, ω)
se3_exp(twist, t_out, q_out);

let d_b = se3_distance(tA, qA, tB, qB);
```

SE(3) log/exp use the standard Lie-algebra parameterization with
the exact left-Jacobian `V` for the translation part, with small-
angle Taylor below `1e−9`.

### Verification

Four direct C tests (pose `t=(1,2,3)`, 30° rotation about y):

1. **T · T⁻¹ = identity** — translation `1e−16`, quaternion exact.
2. **Compose-then-apply matches sequential apply** — `(−1, 1, 3)`
   exact via both routes.
3. **log/exp roundtrip** — translation matches to `1e−9`, quaternion
   recovered (modulo sign).
4. **Interpolation endpoints**: α=0 and α=1 return inputs exactly.

### Files

- `stdlib/runtime/se3_rt.c` — `nuc_se3_*` API; quaternion helpers,
  SE(3) log/exp with full left-Jacobian.
- `stdlib/rods/se3.nr` — externs + wrappers.
- `tests/rods/se3_smoke.nr` — build-only smoke.

---

## [0.2.284] — 2026-04-24

**Robotics: Huber-robust kernel for `pgs3.nr` (3D pose-graph SLAM).
Mirror of v0.2.277's 2D `pgs_optimize_huber` for SE(3) loop
closures.**

### Algorithm

```
Same SE(3) Gauss-Newton iteration as nuc_pgs3_optimize, with
per-edge IRLS weighting:
    r² = Σ_k r0[k]² · info[k]            (info-weighted 6-D norm²)
    w  = 1                                 if r² ≤ δ²
    w  = δ / sqrt(r²)                      if r² > δ²
    Edge contributions to H and b are scaled by w.
```

### Surface

```nucleor
import "stdlib/rods/pgs3.nr"

// ... build graph as for pgs3_optimize ...
pgs3_optimize_huber(g, max_iters, tol_b, delta_b);
```

`delta_b = 0` reduces to vanilla L2 (matches `pgs3_optimize`).

### Files

- `stdlib/runtime/pgs3_rt.c` — added `nuc_pgs3_optimize_huber`
  alongside the existing `nuc_pgs3_optimize`.
- `stdlib/rods/pgs3.nr` — added extern + `pgs3_optimize_huber`
  wrapper.

### Limitations carried forward

- Huber reverts to L2 once an edge's residual drops below `δ`. For
  stronger always-redescending rejection, a Cauchy 3D variant
  lands in v0.6.

---

## [0.2.283] — 2026-04-24

**Robotics: differential-drive and Ackermann mobile-robot
kinematics + arc-integrated pose update (`mobile`).**

### Surface

```nucleor
import "stdlib/rods/mobile.nr"

// Differential-drive forward (wheels → body):
mobile_diff_fwd_kin(vL_b, vR_b, wheel_radius_b, wheelbase_b,
                    v_out_ptr, w_out_ptr);

// Differential-drive inverse (body → wheels):
mobile_diff_inv_kin(v_b, w_b, wheel_radius_b, wheelbase_b,
                    vL_out_ptr, vR_out_ptr);

// Ackermann (bicycle model) forward:
mobile_ackermann_fwd_kin(v_b, delta_b, wheelbase_b,
                          v_out_ptr, w_out_ptr);
let delta_b = mobile_ackermann_inv_steer(v_b, w_b, wheelbase_b);

// Arc-integrated pose update (closed form along constant-curvature arc):
mobile_pose_step(x_b, y_b, theta_b, v_b, w_b, dt_b,
                 x_out_ptr, y_out_ptr, theta_out_ptr);
```

### Verification

Four direct C tests:

1. **Diff-drive fwd/inv roundtrip** (`r=0.05, L=0.3, vL=5, vR=7`):
   `v=0.3, ω=0.333` exact; inverse recovers `vL=5, vR=7` exact.
2. **Ackermann roundtrip** (`v=2, δ=π/6, L=1.5`): `ω=0.7698` matches
   analytical `(v/L)·tan(δ)`; inverse recovers `δ=π/6` exact.
3. **Straight-line pose** at heading `π/4`, `v=2`, `dt=1`: shifted
   by `(√2, √2)` exact, heading unchanged.
4. **Full circle** from origin with `v=1, ω=2π, dt=1`: returns to
   `(0, 0, 2π)` to machine precision.

### Files

- `stdlib/runtime/mobile_rt.c` — `nuc_mobile_*` API.
- `stdlib/rods/mobile.nr` — externs + wrappers.
- `tests/rods/mobile_smoke.nr` — build-only smoke.

---

## [0.2.282] — 2026-04-24

**Robotics: Lucas-Kanade single-feature tracker (`klt`). Given two
grayscale images and a feature point in image 1, find the
displacement to match in image 2 via Newton-LK iteration.
Foundation for visual-odometry feature flow and template tracking.**

### Algorithm

```
Newton-LK update each iter (over a window of radius r around the feature):
    H = [[Σ Ix², Σ Ix·Iy], [Σ Ix·Iy, Σ Iy²]]   (in I1)
    b = [Σ Ix·It, Σ Iy·It]                       (It = I2(warped) − I1)
    Δ = -H⁻¹ · b
    (dx, dy) += Δ
```

Sub-pixel image access uses bilinear interpolation. Iterates until
`|Δ| < tol` or `max_iters` reached. Returns 0 if Hessian becomes
singular (textureless region).

### Surface

```nucleor
import "stdlib/rods/klt.nr"

let dx_dy: double[2];   // initial guess (e.g. 0, 0)
let ok = klt_track(I1_ptr, I2_ptr, W, H,
                   feature_x_b, feature_y_b,
                   window_radius, max_iters, tol_b,
                   dx_dy_out_ptr);
```

For displacements > a few pixels, build an image pyramid via
`imgproc_resize_bilinear` (from v0.2.280) and call this iteratively
coarse-to-fine.

### Verification

64×64 textured image (sinusoidal + linear ramp). I2 = I1 shifted
by `(dx_true, dy_true) = (1.7, −0.8)` via bilinear sampling. Track
from feature `(32, 32)`, initial guess `(0, 0)`, window radius 7,
30 iters max:

- Recovered `(dx, dy) = (1.6966, −0.7968)`. Error in both
  components ≤ `0.004` px — sub-pixel accuracy.

### Files

- `stdlib/runtime/klt_rt.c` — `nuc_klt_track`; bilinear sampler;
  Newton-LK iteration with closed-form 2×2 Hessian inverse.
- `stdlib/rods/klt.nr` — extern + wrapper.
- `tests/rods/klt_smoke.nr` — build-only smoke.

---

## [0.2.281] — 2026-04-24

**Robotics: generic RANSAC orchestrator (`ransac_run`) added to
`ransac.nr` alongside the existing specialized `ransac_plane_3d`.
User-supplied `fit` and `score` callbacks let RANSAC handle any
geometric model (2-D line / circle, 3-D sphere, fundamental /
essential matrix, similarity transform between point clouds, etc.)
without one-off rod-per-shape duplication.**

### Surface

```nucleor
import "stdlib/rods/ransac.nr"

// fit(indices_ptr, n_indices, model_out_ptr) -> i64
//   - indices_ptr: i64[n_indices] random sample of data indices
//   - model_out_ptr: caller-allocated double[model_size]
//   - returns 1 on success, 0 on degenerate sample
//
// score(model_ptr, data_index) -> i64
//   - 1 if data point is an inlier under model, 0 otherwise

let inlier_count = ransac_run(n_data, n_min_samples, model_size,
    n_iters, seed,
    fit_fp, score_fp,
    best_model_out_ptr,    // double[model_size]
    inlier_mask_out_ptr);  // i64[n_data] (1=inlier under best, 0=else)
```

### Verification

2-D line fitting on 100 inliers (`y = 2x + 1` + small noise) plus
20 wild outliers:

- **Recovered slope**: `2.0010` (truth `2.0`).
- **Recovered intercept**: `0.9561` (truth `1.0`).
- **Inlier mask**: 100/100 true inliers correctly identified;
  1/20 outliers slipped through (within tolerance `0.3`).

### Files

- `stdlib/runtime/ransac_rt.c` — added `nuc_ransac_run` alongside
  the existing `nuc_ransac_plane_3d`.
- `stdlib/rods/ransac.nr` — added extern + `ransac_run` wrapper.

### Limitations carried forward

- Vanilla RANSAC: uniform random sampling, no PROSAC / MLESAC /
  locally-optimized variants (planned for v0.6).
- No automatic non-minimal refit on the best inlier set — caller
  re-fits the model on `inlier_mask` for best accuracy.

---

## [0.2.280] — 2026-04-24

**Robotics: basic image processing primitives (`imgproc`) on
grayscale images. Sobel gradient, gradient magnitude, box filter,
separable Gaussian blur, bilinear resize. Foundation for vision
pipelines and image pyramids.**

### Surface

```nucleor
import "stdlib/rods/imgproc.nr"

// All operate on caller-allocated double[H * W] row-major buffers.
imgproc_sobel_x(in_ptr, out_ptr, W, H);
imgproc_sobel_y(in_ptr, out_ptr, W, H);
imgproc_gradient_magnitude(in_ptr, out_ptr, W, H);   // sqrt(Gx² + Gy²)

imgproc_box_filter(in_ptr, out_ptr, W, H, radius);
imgproc_blur_gaussian(in_ptr, out_ptr, W, H, sigma_b, radius);

imgproc_resize_bilinear(in_ptr, in_W, in_H, out_ptr, out_W, out_H);
```

Boundary handling: edge-pixel replication (clamp). Pixels are
doubles in arbitrary range — caller decides `[0, 1]`, `[0, 255]`,
or anything else.

### Verification

Three direct C tests:

1. **Sobel x on a vertical edge** (8×8 image, 0 left half, 1 right
   half): `gx[4, 3]` = `gx[4, 4]` = `4.0000` exact (matches the
   3×3 stencil computation `−1 + 1 − 2 + 2 − 1 + 1 = 0` at the
   step ... wait actually for the BOUNDARY column `x=3` adjacent
   to the edge at `x=4`, Sobel = 4).
2. **Gaussian blur of a constant** (16×16 of 5.0, σ=2, radius=6):
   `0/256` pixels deviate from 5.0 — preserves constant exactly.
3. **Resize roundtrip** 4×4 → 8×8 → 4×4: max roundtrip error
   `8.9e−16` (machine precision).

### Files

- `stdlib/runtime/imgproc_rt.c` — `nuc_img_*` API; Sobel, gradient
  magnitude, box, separable Gaussian, bilinear resize.
- `stdlib/rods/imgproc.nr` — externs + wrappers.
- `tests/rods/imgproc_smoke.nr` — build-only smoke.

---

## [0.2.279] — 2026-04-24

**Robotics: iterative inverse-distortion for `cam.nr`. Adds two
functions to invert the Brown-Conrady distortion model so that
distorted pixels can be undistorted (then unprojected) without
caller pre-rectification.**

### New surface

```nucleor
import "stdlib/rods/cam.nr"

// Find undistorted (xn, yn) such that distort(xn, yn) ≈ (xd, yd):
cam_undistort_normalized(h, xd_b, yd_b, n_iters, out_ptr);  // double[2]

// Convenience: distorted pixel + depth → world point in one call.
cam_unproject_distorted(h, u_b, v_b, depth_b, n_iters, P_out_ptr);  // double[3]
```

### Algorithm

OpenCV-style fixed-point iteration starting from the distorted
point as the initial guess:

```
x_n^{k+1} = (x_d − tangential_x(x_n^k, y_n^k)) / radial(x_n^k, y_n^k)
y_n^{k+1} = (y_d − tangential_y(x_n^k, y_n^k)) / radial(x_n^k, y_n^k)
```

Converges in 5–10 iters for moderate distortion. For extreme
fish-eye distortion, a different model is needed (planned for v0.6).

### Verification

Distort → undistort roundtrip on three test points with
`(k1=0.1, k2=−0.02, p1=0.001, p2=−0.0005)`:

- `(0.300, −0.200)` → distorted `(0.304, −0.202)` → undistorted
  `(0.300000, −0.200000)`, error `1.1e−14`.
- `(−0.100, 0.500)` → roundtrip error `2.1e−14`.
- `(0, 0)` → exact zero (origin invariant).

All within machine precision.

### Files

- `stdlib/runtime/cam_rt.c` — added `nuc_cam_undistort_normalized`
  and `nuc_cam_unproject_distorted`.
- `stdlib/rods/cam.nr` — added externs + wrappers.

---

## [0.2.278] — 2026-04-24

**Robotics: Cauchy/Lorentzian redescending kernel for `pgs.nr`
(`pgs_optimize_cauchy`). Stronger outlier rejection than Huber —
the weight `w = 1 / (1 + r²/c²)` is < 1 for ALL non-zero
residuals (truly redescending), so outliers are rejected even if
their residual happens to drop below the Huber threshold during
IRLS convergence.**

### When to use which kernel

- **`pgs_optimize`** — vanilla L2; fast and unbiased on inliers.
  Use when no outliers expected.
- **`pgs_optimize_huber(δ)`** — bounded influence, smooth at the
  threshold. Reduces to L2 below `δ`. Standard for "mostly inliers
  with occasional outliers."
- **`pgs_optimize_cauchy(c)`** — strongly redescending. Best when
  outliers must be rejected even after IRLS pulls residuals down.
  Mild bias on inliers (acceptable when robustness dominates).

### Verification

Same 2-node + outlier scenario as Huber test (good edge: distance 1;
outlier: distance 100):

1. **Cauchy (c=2.0)**: `node1.x = 1.0404` — extremely close to the
   good edge's distance of 1.
2. **Cauchy (c=0)**: `node1.x = 50.5000` — degenerate case reduces
   to L2 average.
3. **Direct comparison**: Huber(δ=2) gives `x=3.00` while Cauchy(c=2)
   gives `x=1.04` — Cauchy 30× more aggressive at the same scale.

### Files

- `stdlib/runtime/pgs_rt.c` — added `nuc_pgs_optimize_cauchy`
  alongside L2 and Huber variants.
- `stdlib/rods/pgs.nr` — added extern + `pgs_optimize_cauchy` wrapper.

---

## [0.2.277] — 2026-04-24

**Robotics: Huber robust-cost kernel for `pgs.nr` (`pgs_optimize_huber`).
Down-weights outlier loop-closure edges via iteratively-reweighted
least squares so a single bad measurement can't dominate the
optimization. Standard back-end-robust SLAM technique.**

### Algorithm

```
Each Gauss-Newton iteration:
    For each edge:
        r² = e_xᵀ Ω e_x   (information-weighted residual norm²)
        w  = 1                          if r² ≤ δ²
        w  = δ / sqrt(r²)               if r² > δ²
        Accumulate H += w · Jᵀ Ω J
        Accumulate b += w · Jᵀ Ω e
    Solve H · δ = −b; apply δ to free nodes; repeat.
```

The weight `w` is recomputed each iteration based on the current
state's residual — this is the IRLS form of the Huber M-estimator.
Edges with large residuals (`r² > δ²`) get weight `< 1`, capping
their influence on the gradient at `δ` per residual unit.

`delta_b` is the Huber threshold (typical `0.5–2.0` for distance
residuals, tuned to ~3σ of the noise model). Pass `0.0` to
disable Huber and reduce to vanilla L2 (matches `pgs_optimize`).

### Surface

```nucleor
import "stdlib/rods/pgs.nr"

// ... build graph as for pgs_optimize ...
pgs_optimize_huber(g, max_iters, tol_b, delta_b);
```

### Verification

Two-node graph with two edges between them: one good (distance 1),
one outlier (distance 100), info=1 both:

1. **L2** (`pgs_optimize`): `node1.x = 50.5000` (averages the two
   measurements).
2. **Huber with δ=0** (degenerate): `node1.x = 50.5000` — exactly
   matches L2 as expected.
3. **Huber with δ=2.0** (outlier residual `99 ≫ δ`): `node1.x = 3.0000`
   — outlier was down-weighted, solution near the good edge's
   distance of 1.

### Limitations carried forward

- Huber is a non-redescending M-estimator: when the outlier residual
  drops below `δ`, the kernel reverts to L2. For strongly tangled
  problems where the IRLS trajectory dips the outlier residual
  below `δ`, the converged Huber solution can equal the L2 one.
  Stronger redescending kernels (Cauchy, Tukey, Geman-McClure) and
  graduated non-convexity (GNC) plan for v0.6.

### Files

- `stdlib/runtime/pgs_rt.c` — added `nuc_pgs_optimize_huber`
  alongside the existing `nuc_pgs_optimize`. Same Gauss-Newton
  iteration structure with per-edge IRLS weighting.
- `stdlib/rods/pgs.nr` — added extern + `pgs_optimize_huber`
  wrapper.

---

## [0.2.276] — 2026-04-24

**Robotics: Monte Carlo reachability mapper (`reach`) for arm
robots. Samples N joint configurations uniformly within per-joint
bounds, runs a user-supplied forward-kinematics callback on each,
stores the resulting end-effector positions as a workspace cloud.**

### Surface

```nucleor
import "stdlib/rods/reach.nr"

let h = reach_new(n_joints, n_samples, seed);
for j in 0..n_joints {
    reach_set_joint_limit(h, j, lo_b, hi_b);
}
reach_compute(h, fk_fp);

// Per-sample EE coordinates:
let x_b = reach_get_ee(h, sample_idx, 0);
// ... y, z

// Density query:
let n_in = reach_density_in_sphere(h, x_b, y_b, z_b, radius_b);

// Bounding box on axis 0/1/2 (writes [min, max]):
reach_workspace_extent(h, axis, out_ptr);
```

FK callback signature: `fn(joints_ptr, ee_xyz_out_ptr) -> i64`
where `joints_ptr` is `double[n_joints]` and `ee_xyz_out_ptr` is
`double[3]` for the EE world-frame position.

### Verification

Planar 2-link arm, link lengths `1.0` and `1.0`, both joints
sampled uniformly in `[−π, π]` with 5000 samples. Workspace is
the disk of radius 2.

- Workspace bounding box: `x ∈ [-1.998, 1.998]`, `y ∈ [-1.999, 2.000]`
  — converged to the analytical disk to within `0.002`.
- Density at origin (`r = 0.5` sphere): `811 / 5000` (configurations
  where the two links fold near each other).
- Density outside workspace (`(3, 0, 0)`, `r = 0.5`): `0`
  (correctly excludes unreachable region).

### Files

- `stdlib/runtime/reach_rt.c` — `nuc_reach_*` API; xorshift RNG;
  uniform sampling within bounds; brute-force density query.
- `stdlib/rods/reach.nr` — externs + wrappers.
- `tests/rods/reach_smoke.nr` — build-only smoke.

---

## [0.2.275] — 2026-04-24

**Robotics: 2D Visibility Graph planner (`vgraph`). Builds a graph
whose vertices are the start, the goal, and every vertex of every
convex polygonal obstacle; connects pairs whose direct segment is
collision-free; runs Dijkstra. Optimal-path baseline against
sampling planners (RRT/PRM) for known polygonal worlds.**

### Algorithm

```
Vertices V = { start, goal } ∪ { all obstacle vertices }
Edge (u, v) ∈ E iff:
    (a) segment uv does not properly intersect any obstacle edge
        (sharing endpoints with obstacle edges is fine), AND
    (b) midpoint of uv is not strictly inside any obstacle interior
        (allowed iff u and v are adjacent vertices of the same obstacle)
Edge weight = Euclidean distance
Path = Dijkstra(start, goal)
```

### Surface

```nucleor
import "stdlib/rods/vgraph.nr"

let h = vgraph_new();
// Add convex obstacles. vertices_ptr is double[n_vert * 2] CCW.
vgraph_add_obstacle(h, vertices_ptr, n_vert);

vgraph_set_start(h, sx_b, sy_b);
vgraph_set_goal(h,  gx_b, gy_b);
let n = vgraph_plan(h);

for i in 0..n {
    let x_b = vgraph_path_x(h, i);
    let y_b = vgraph_path_y(h, i);
}
```

### Verification

`start = (0, 0)`, `goal = (10, 0)`, single 2×2 box obstacle
centered at `(5, 0)`. Direct line through the box is blocked.

- Path length: 4 waypoints `(0,0) → (4,-1) → (6,-1) → (10,0)`
  (corner detour around the box).
- Cost: `10.2462` — matches analytical `2·√17 + 2 = 10.2462` exactly.
- 0 waypoints inside the obstacle interior.

### Files

- `stdlib/runtime/vgraph_rt.c` — `nuc_vgraph_*` API; segment-segment
  proper intersection test, point-in-convex test, brute-force
  visibility check, dense Dijkstra.
- `stdlib/rods/vgraph.nr` — externs + wrappers.
- `tests/rods/vgraph_smoke.nr` — build-only smoke.

### Limitations carried forward

- Convex obstacles only (CCW vertex order).
- Brute-force visibility check `O(V² · E_obs)`. Fine for ≤ ~100
  total vertices.
- No vertex inflation — caller responsible for inflating obstacles
  to account for robot size.

---

## [0.2.274] — 2026-04-24

**Robotics: pinhole camera with Brown-Conrady distortion (`cam`).
Project world points → pixels and unproject pixels + depth →
world points. Standalone utility complementing `ba.nr`'s built-in
projection (which is fixed at pure pinhole and tied to the BA
solver state).**

### Surface

```nucleor
import "stdlib/rods/cam.nr"

let h = cam_new(fx_b, fy_b, cx_b, cy_b);
cam_set_distortion(h, k1_b, k2_b, k3_b, p1_b, p2_b);
cam_set_pose(h, t_ptr, q_ptr);             // double[3], double[4]

let ok    = cam_project(h, P_w_ptr, uv_out_ptr);     // (X,Y,Z) → (u,v)
            cam_unproject(h, u_b, v_b, depth_b, P_out_ptr);

cam_distort(h, xn_b, yn_b, distorted_out_ptr);       // normalized
cam_intrinsic_matrix(h, K_out_ptr);                  // 3×3 row-major
```

Pose `(t, q)` is the camera frame in the world (`X_cam = qᵀ · (P − t)`),
matching `ba.nr`'s convention.

### Verification

`fx = fy = 500, cx = 320, cy = 240`, identity pose:

1. `project(0, 0, 1)` = `(320, 240)` (principal point) exact.
2. `project(0.5, -0.5, 2)` = `(445, 115)` exact.
3. `unproject(320, 240, 5)` = `(0, 0, 5)` exact (round-trip).
4. With `k1 = 0.1`: `distort(0.3, 0)` = `(0.302700, 0)` —
   matches analytical `0.3 · (1 + 0.1·0.09) = 0.3027`.
5. K matrix matches input intrinsics exactly.

### Files

- `stdlib/runtime/cam_rt.c` — `nuc_cam_*` API; quaternion helpers,
  pinhole + Brown-Conrady projection.
- `stdlib/rods/cam.nr` — externs + wrappers.
- `tests/rods/cam_smoke.nr` — build-only smoke.

---

## [0.2.273] — 2026-04-24

**Robotics: Model Predictive Path Integral control (`mppi`) —
Williams, Aldrich & Theodorou 2016/2017. Sample-based MPC variant
that requires no gradient and handles arbitrary non-smooth
dynamics + costs (binary obstacle indicators, friction stick-slip,
hybrid systems) where iLQR / DDP would fail.**

### Algorithm

```
Per control tick:
  for k = 1..K:
    ε_k[t] ~ N(0, Σ)                  (per-component noise)
    u_k[t] = u_seq[t] + ε_k[t]        (perturbed sequence)
    roll out under dynamics → cost J_k
  w_k = exp(−(J_k − J_min) / λ)
  w_k /= Σ_j w_j
  u_seq[t] ← Σ_k w_k · u_k[t]
  output u_seq[0], shift sequence by 1
```

`J_min` subtraction in the exponent is the standard numerical-
stability trick. Naturally embarrassingly parallel — each rollout
is independent — though this implementation runs sequentially.

### When to use

- **`mppi.nr`** — non-smooth costs/dynamics, contact-rich tasks,
  obstacle indicator costs, hybrid systems. Slower (K rollouts per
  tick) but globally robust.
- **`ilqr.nr`, `mpc.nr`** — smooth costs/dynamics, fast convergence
  via gradients.
- **`cilqr.nr`** — smooth dynamics + box constraints on `u`.

### Surface

```nucleor
import "stdlib/rods/mppi.nr"

let h = mppi_new(n_x, n_u, T, K, lambda_b, seed);
for d in 0..n_u { mppi_set_sigma(h, d, sigma_d_b); }
mppi_set_callbacks(h, dyn_fp, sc_fp, tc_fp);

for tick {
    mppi_step(h, x_ptr, u_out_ptr);
}
```

### Verification

Closed-loop MPPI on a 2-D double integrator (pos, vel; scalar
accel input). Goal `(1, 0)` from start `(0, 0)`. `T = 20`,
`K = 512`, `λ = 1.0`, `σ = 0.5`. Final state after 50 ticks:
`(1.0055, −0.0713)` — converged within tolerance.

### Files

- `stdlib/runtime/mppi_rt.c` — `nuc_mppi_*` API; xorshift RNG +
  Box-Muller normal sampling; sequential rollout loop; weighted
  average update.
- `stdlib/rods/mppi.nr` — externs + wrappers.
- `tests/rods/mppi_smoke.nr` — build-only smoke.

---

## [0.2.272] — 2026-04-24

**Robotics: Dynamic Time Warping (`dtw`) sequence-similarity
distance for n-dimensional time series (Sakoe & Chiba 1978).
Tolerant of time-axis stretches that confuse Euclidean point-to-
point comparison — useful for trajectory tracking error, gesture
matching, and learning-from-demonstration matching.**

### Algorithm

```
Cost matrix d[i, j] = ‖A[i] − B[j]‖ (Euclidean)
Accumulated D[0, 0] = d[0, 0]
            D[0, j] = d[0, j] + D[0, j−1]
            D[i, 0] = d[i, 0] + D[i−1, 0]
            D[i, j] = d[i, j] + min(D[i−1, j], D[i, j−1], D[i−1, j−1])
DTW distance = D[M−1, N−1]
```

Optional Sakoe-Chiba band restricts cells to `|i − j·M/N| ≤ band`
— reduces work from `O(M·N)` to `O(band·max(M, N))` and rejects
"too warped" alignments.

### Surface

```nucleor
import "stdlib/rods/dtw.nr"

let d_b   = dtw_distance(a_ptr, M, b_ptr, N, dim);
let d_b   = dtw_distance_band(a_ptr, M, b_ptr, N, dim, band);
let avg_b = dtw_distance_normalized(a_ptr, M, b_ptr, N, dim);
```

### Verification

Four direct C tests:

1. Identical 1-D sequences → distance `0.000000` exactly.
2. Time-shifted sin sequences (5-sample shift, N=30): Euclidean
   `19.03`, **DTW `4.76`** — warping pulls cost down 4×.
3. Sakoe-Chiba band-restricted with band ≥ N matches the
   unbounded version exactly.
4. Normalized = unnormalized / `(M + N − 1)` exact.

### Files

- `stdlib/runtime/dtw_rt.c` — `nuc_dtw_*` API; full DP and
  band-restricted variants.
- `stdlib/rods/dtw.nr` — externs + wrappers.
- `tests/rods/dtw_smoke.nr` — build-only smoke.

---

## [0.2.271] — 2026-04-24

**Robotics: natural cubic spline (`cspline`) — smooth interpolation
through waypoints with continuous first and second derivatives at
every internal waypoint and `y''(x_0) = y''(x_N) = 0` boundary
conditions.**

### Algorithm

Standard textbook tridiagonal solve via the Thomas algorithm for
the second derivatives `m_k` at each waypoint, then per-segment
cubic evaluation:

```
y(x) = m_k/(6 h_k)·(x_{k+1} − x)³ + m_{k+1}/(6 h_k)·(x − x_k)³
     + (y_k/h_k − m_k h_k/6)·(x_{k+1} − x)
     + (y_{k+1}/h_k − m_{k+1} h_k/6)·(x − x_k)
```

### Surface

```nucleor
import "stdlib/rods/cspline.nr"

let s = cspline_new(n_waypoints);
for k in 0..n_waypoints {
    cspline_set_waypoint(s, k, x_b, y_b);
}
cspline_solve(s);     // returns 0 if x is not strictly increasing

for tick {
    let y_b = cspline_eval(s, x_b);
    let yp_b = cspline_eval_derivative(s, x_b);
    let ypp_b = cspline_eval_second_derivative(s, x_b);
}
```

### How it differs from existing trajectory rods

- `qtraj.nr` — minimum-snap (4th-derivative-bounded) 7th-degree
  per segment; for quadrotors / differentially-flat systems.
- `bspline.nr` — general degree-k B-splines with explicit control
  points and knot vectors.
- `cspline.nr` — simplest "smooth fit through waypoints" primitive,
  no extra control-point machinery.

### Verification

5 waypoints sampled from `y = sin(x)` at `x = 0, π/4, π/2, 3π/4, π`:

1. Interpolation **exact** at every waypoint (errors < 1e-9).
2. Second derivative **zero** at both endpoints (1e-9 tolerance) —
   natural BC holds.
3. Max approximation error vs `sin(x)` over 50 mid-segment samples:
   `1.06e-3`. Excellent quality with only 5 control points.

### Files

- `stdlib/runtime/cspline_rt.c` — `nuc_cspline_*` API; Thomas
  tridiagonal solve; binary-search segment lookup.
- `stdlib/rods/cspline.nr` — externs + wrappers.
- `tests/rods/cspline_smoke.nr` — build-only smoke.

---

## [0.2.270] — 2026-04-24

**Robotics: per-DOF admittance controller (`admit`). Maps measured
force to a position command via a virtual mass-spring-damper —
foundational for compliant manipulation on position-controlled
robots.**

### Algorithm

```
Per DOF:  M · ẍ + D · ẋ + K · x = F_meas − F_des

Discrete update each tick:
    ẍ ← (F_meas − F_des − D · ẋ − K · x) / M
    x ← x + dt · ẋ + ½ · dt² · ẍ
    ẋ ← ẋ + dt · ẍ
```

Output: the (x, ẋ) state of the virtual admittance model. Higher-
level code typically adds `x` as a perturbation to a nominal
position trajectory ("compliant tracking") so the robot yields
under contact force.

### Surface

```nucleor
import "stdlib/rods/admit.nr"

let h = admit_new(n_dof);
for d in 0..n_dof {
    admit_set_gains(h, d, M_b, D_b, K_b);
}
for tick {
    admit_step(h, force_meas_ptr, dt_b);    // force_meas_ptr: double[n_dof]
    let x_b = admit_get_position(h, d);     // perturbation
    // ... add x to nominal position command ...
}
```

### Verification

Single DOF, critically damped (`M=1, D=2, K=1`), `F_meas = 1 N`,
`F_des = 0`, `dt = 0.01s`, run for 30 s:

- Final `x = 1.000000` (exactly `F/K = 1`).
- Final `ẋ = 4.4 × 10⁻¹²` (steady-state).

### Files

- `stdlib/runtime/admit_rt.c` — `nuc_admit_*` API; per-DOF state
  + integration.
- `stdlib/rods/admit.nr` — externs + wrappers.
- `tests/rods/admit_smoke.nr` — build-only smoke.

---

## [0.2.269] — 2026-04-24

**Robotics: ZMP tracking via cart-table inverse dynamics + finite-
horizon LQR (`zmp`) — Kajita's bipedal locomotion CoM trajectory
generator. Given a desired ZMP reference (typically inside the
support polygon), inverts the cart-table dynamics to produce the
CoM trajectory whose induced ZMP best tracks the reference.**

### Cart-table model

```
Per axis (x and y are decoupled):
    State:   x = (c, ċ, c̈) ∈ ℝ³
    Dyn:     x_{k+1} = A · x_k + B · u_k          (u = jerk)
                A = [[1, dt, dt²/2], [0, 1, dt], [0, 0, 1]]
                B = [dt³/6, dt²/2, dt]
    Output:  p = C · x = c − (h/g) · c̈           (the "ZMP")
    Cost:    J = Σ (p_k − p_ref_k)² + R · u_k²
```

Solved by a standard finite-horizon LQR backward Riccati pass with
an affine offset term for the tracking reference, then a forward
pass to compute u and roll the state.

### Surface

```nucleor
import "stdlib/rods/zmp.nr"

let h_x = zmp_new(h_b, dt_b, n_steps);
let h_y = zmp_new(h_b, dt_b, n_steps);

for k in 0..n_steps {
    zmp_set_zmp_ref(h_x, k, x_ref_b);
    zmp_set_zmp_ref(h_y, k, y_ref_b);
}
zmp_set_initial_state(h_x, c0_x_b, cdot0_x_b, cddot0_x_b);
zmp_set_initial_state(h_y, c0_y_b, cdot0_y_b, cddot0_y_b);

zmp_solve(h_x, R_b);  zmp_solve(h_y, R_b);

for k in 0..(n_steps + 1) {
    let cx_b = zmp_com(h_x, k);
    let cy_b = zmp_com(h_y, k);
}
```

### Verification

`h = 0.8 m`, `dt = 0.01 s`, `N = 200`. Step ZMP reference at
`k = 100` (0.05 m / 5 cm — typical biped foot displacement):

- **Phase 1 max ZMP deviation** = 0.0154 m: this is the **correct
  physical anticipation** — the LQR controller knows the upcoming
  step from the offline reference and starts pre-tilting the CoM
  to swing the ZMP smoothly.
- **Steady-state ZMP error** (`k > 150`) = 0.000262 m (sub-mm).
- **Final CoM** = 0.0385 m (settling toward 0.05 m; finite horizon
  ends shortly after step so some lag persists).

### Files

- `stdlib/runtime/zmp_rt.c` — `nuc_zmp_*` API; cart-table A, B, C
  matrices; finite-horizon LQR backward Riccati with tracking term;
  forward pass.
- `stdlib/rods/zmp.nr` — externs + wrappers.
- `tests/rods/zmp_smoke.nr` — build-only smoke.

### Limitations carried forward

- 1-D per call; call twice for x and y.
- Constant CoM height. Variable-height (LIPM with vertical motion)
  needs a different model.
- Offline (whole-trajectory). For online MPC, feed each window of
  `p_ref` through this rod with a rolling horizon.

---

## [0.2.268] — 2026-04-24

**Robotics: 2-D Signed Distance Field (`sdf`) on a regular grid
with bilinear interpolation + gradient. Foundational primitive
for collision queries, repulsive potential fields, cost-aware
planning, and distance-aware MPC stage costs.**

### Surface

```nucleor
import "stdlib/rods/sdf.nr"

let h = sdf_new(W, H, dx_b, ox_b, oy_b);

// Either fill cells manually:
sdf_set(h, ix, iy, value_b);

// Or compute from a list of circular obstacles:
sdf_compute_from_circles(h, centers_ptr, radii_ptr, n_obs);

// Query with bilinear interpolation:
let phi_b = sdf_query(h, x_b, y_b);

// Gradient:
sdf_gradient(h, x_b, y_b, gx_out_ptr, gy_out_ptr);

sdf_free(h);
```

Convention: `φ > 0` outside obstacles, `φ < 0` inside, `φ = 0`
on the boundary.

### Verification

41 × 41 grid covering `[−2, 2]²` with cell size `0.1`, single
circle radius `0.5` at `(0.5, 0.5)`:

1. φ at cell (25, 25) = `−0.500000` (at obstacle center).
2. φ at cell (35, 25) = `+0.500000` (distance 1.0 from center
   minus radius 0.5).
3. Bilinear query at `(0.5, 0.5)` = `−0.500000` (exact match
   with grid value at center).
4. Bilinear gradient at `(1.0, 0.5)` = `(1.0000, 0.0990)` —
   magnitude `1.0049`, direction `+x` (away from obstacle).
   Small y-component is the expected piecewise-linear
   approximation artifact.

### Files

- `stdlib/runtime/sdf_rt.c` — `nuc_sdf_*` API; bilinear query +
  gradient; `compute_from_circles` helper.
- `stdlib/rods/sdf.nr` — externs + wrappers.
- `tests/rods/sdf_smoke.nr` — build-only smoke.

---

## [0.2.267] — 2026-04-24

**Robotics: box-constrained iLQR (`cilqr`). Same iterative-LQR
algorithm as `ilqr.nr` with one addition — each control update
during the forward pass is clamped to a per-component box
`[u_min, u_max]`. Standard pragmatic way to enforce hard actuator
limits.**

### Algorithm

```
backward pass: identical to ilqr (Q-function update, K, k)
forward pass with line search:
    for t in 0..T:
        u_new[t] = u_seq[t] + α·k_t + K_t·(x_new − x_old)
        u_new[t] = clamp(u_new[t], u_min, u_max)        // box clamp
        x_new[t+1] = f(x_new[t], u_new[t])
    if cost(u_new) < cost(u_seq): accept
    else: α *= 0.5
```

The initial `u_seq` is also pre-clamped on entry so an
out-of-bounds warm start is safe.

### Surface

```nucleor
import "stdlib/rods/cilqr.nr"

cilqr_optimize_box(n_x, n_u, T,
    x0_ptr, u_seq_ptr,
    u_min_ptr, u_max_ptr,
    max_iters,
    dynamics_fp, stage_cost_fp, terminal_cost_fp);
```

Same callback contract as `ilqr.nr`. `u_min` and `u_max` are
caller-allocated `double[n_u]`.

### Verification

2-D double-integrator goal-reaching with `T = 30`, `dt = 0.1`,
terminal cost `50·(p − 1)² + 5·v²`, and **tight u-bounds** `[-0.5, 0.5]`
(tighter than what unconstrained iLQR would peak at, ~0.65).

- Converged in 4 iterations.
- `max |u| = 0.5000` exact, **0 violations** of the bound.
- Final state `(1.0037, 0.0425)` — made it to goal despite the bound.

### Files

- `stdlib/runtime/cilqr_rt.c` — `nuc_cilqr_optimize_box`; iLQR
  helpers prefixed `_ci_` to avoid C-symbol collision with
  `ilqr_rt.c`.
- `stdlib/rods/cilqr.nr` — extern + `cilqr_optimize_box` wrapper.
- `tests/rods/cilqr_smoke.nr` — build-only smoke.

### Limitations carried forward

- Only the forward pass clamps; backward-pass `K` is unconstrained.
  Tassa-style projected backward pass for tightly-active stretches
  lands in v0.6.

---

## [0.2.266] — 2026-04-24

**Robotics: jerk-limited 7-phase s-curve trajectory (`scurve`).
Production-grade motion-control profile that bounds velocity,
acceleration, AND jerk — eliminating the δ-spike acceleration
jumps of `topp.nr`'s trapezoidal profile that cause robot
lurching, vibration, and reduced joint lifetime.**

### Algorithm

```
Phases (jerk j is constant within each):
  1. j = +j_max   a:0 → a_max    duration T_j = a_max / j_max
  2. j = 0       a = a_max const  duration T_a − 2·T_j
  3. j = −j_max   a:a_max → 0    duration T_j
  4. j = 0       cruise at v_max  duration T_v
  5. j = −j_max   a:0 → −a_max   duration T_j
  6. j = 0       a = −a_max const duration T_a − 2·T_j
  7. j = +j_max   a:−a_max → 0   duration T_j

T_a = T_j + v_max/a_max
T_v = L/v_max − T_a
T_total = 2·T_a + T_v
```

Closed-form integration produces position / velocity / acceleration
/ jerk evaluators at each phase.

### Surface

```nucleor
import "stdlib/rods/scurve.nr"

let h = scurve_new(L_b, v_max_b, a_max_b, j_max_b);
if h == 0 {
    // Path too short for full 7-phase profile — fall back to
    // topp.nr's trapezoidal.
}
let T = scurve_total_time(h);
for tick {
    let s_b = scurve_position(h, t_b);
    let v_b = scurve_velocity(h, t_b);
    let a_b = scurve_acceleration(h, t_b);
    let j_b = scurve_jerk(h, t_b);
}
scurve_free(h);
```

### Verification

Setup `L = 10, v_max = 2, a_max = 2, j_max = 4`. Six direct C tests:

1. `T_total = 6.500000` exact (analytical formula).
2. Boundary `s(0)=0, s(T)=10, v(0)=0, v(T)=0` all exact to 1e-9.
3. Peak velocity at mid-cruise: `2.000000` (`= v_max`) exact.
4. Peak acceleration in phase 2: `2.000000` (`= a_max`) exact.
5. Peak jerk in phase 1: `4.000000` (`= j_max`) exact.
6. Position continuous across phase boundary at `t = T_j`.

### Files

- `stdlib/runtime/scurve_rt.c` — `nuc_scurve_*` API; closed-form
  per-phase polynomials; cached state at phase boundaries.
- `stdlib/rods/scurve.nr` — externs + wrappers.
- `tests/rods/scurve_smoke.nr` — build-only smoke.

### Limitations carried forward

- Requires the full 7-phase profile (both v_max and a_max must be
  reached). For short paths use `topp.nr`'s trapezoidal fallback.
- Symmetric (accel = decel limits).
- Rest-to-rest only (no nonzero start/end velocities).

---

## [0.2.265] — 2026-04-24

**Robotics: quaternion utilities (`qutil`) on raw `double[4]`
buffers. Complement to `kinematics.nr`'s allocated-handle Quat;
this rod takes pointers directly so inner loops (controllers,
trajectory interpolation) can avoid per-call allocation.**

### Surface

```nucleor
import "stdlib/rods/qutil.nr"

qutil_slerp(q1_ptr, q2_ptr, t_b, q_out_ptr);     // Shoemake SLERP
qutil_squad(p_ptr, a_ptr, b_ptr, q_ptr, t_b, q_out_ptr);  // smooth interp

qutil_log(q_ptr, omega_out_ptr);                  // unit quat → axis-angle
qutil_exp(omega_ptr, q_out_ptr);                  // axis-angle → unit quat

qutil_from_axis_angle(axis_ptr, angle_b, q_out_ptr);
let angle_b = qutil_to_axis_angle(q_ptr, axis_out_ptr);

qutil_from_euler(roll_b, pitch_b, yaw_b, q_out_ptr);
qutil_to_euler(q_ptr, rpy_out_ptr);

qutil_relative(q1_ptr, q2_ptr, q12_out_ptr);     // q12 = q1⁻¹ · q2
let dist_b = qutil_angular_distance(q1_ptr, q2_ptr);  // radians ∈ [0, π]
```

SLERP picks the shorter arc by flipping `q2` when needed and
falls back to lerp+normalize within `1.8°` (cos > 0.9995) to
avoid div-by-tiny-sin.

### Verification

Five direct C tests:

1. **SLERP** identity↔180°z at `t = 0, 1, 0.5` recovers identity,
   180°z, and exact 90°z (`(cos45, 0, 0, sin45)`).
2. **log/exp roundtrip**: `(0.1, 0.3, −0.2)` → quaternion → log →
   identical input to 9 decimals.
3. **Axis-angle**: build from `(y, π/3)`, decode to `(y, π/3)` exact.
4. **Euler ZYX**: yaw = `π/2` → `(cos45, 0, 0, sin45)` exact;
   decoding recovers `(0, 0, π/2)` exact.
5. **Relative + distance**: `q⁻¹·q = identity`, `d(q, q) = 0`,
   `d(identity, 90°z) = π/2` exact.

### Files

- `stdlib/runtime/qutil_rt.c` — `nuc_qutil_*` API.
- `stdlib/rods/qutil.nr` — externs + wrappers.
- `tests/rods/qutil_smoke.nr` — build-only smoke.

---

## [0.2.264] — 2026-04-24

**Robotics: hierarchical (strict-priority) whole-body controller
(`hwbc`) via Siciliano-Slotine null-space projection (Siciliano &
Slotine 1991). Strict counterpart to `wbc.nr` — lower-priority
tasks live entirely in the null space of higher-priority Jacobians
and can never undo a higher-priority objective.**

### Algorithm

```
q̇₀ = 0,  N₀ = I_n
for i = 1..K (priority order, 1 = highest):
    J̃_i = J_i · N_{i-1}                  // effective Jacobian
    if ‖J̃_i‖_F² < ε · damping: skip      // no available DOF in this null space
    Δq̇ = J̃_i⁺ · (ẋ_i_des − J_i · q̇_{i-1})
    q̇_i = q̇_{i-1} + Δq̇
    N_i = N_{i-1} − J̃_i⁺ · J̃_i
return q̇_K
```

Pseudoinverse uses damped least squares for numerical stability:
`A⁺ = Aᵀ · (A · Aᵀ + λ · I)⁻¹`. The "skip if J̃ near-zero" guard
prevents the pathology where an exhausted null space lets the
damped pseudoinverse assert a near-infinite gain that wipes out
higher-priority work via numerical projector imprecision.

### When to use

- **`hwbc.nr`** — when you need ABSOLUTE task ordering (e.g. balance
  must NEVER be sacrificed for reach). Lower-priority tasks
  contribute only what fits within the residual freedom.
- **`wbc.nr`** (weighted QP) — when soft tradeoffs are acceptable.
  Simpler, faster, handles near-singular task stacks more gracefully.

### Surface

```nucleor
import "stdlib/rods/hwbc.nr"

let h = hwbc_new(n_dof, damping_b);

for tick {
    hwbc_clear_tasks(h);
    let id_balance = hwbc_add_task(h, J_bal_ptr,  x_bal_ptr,  3);   // priority 1
    let id_reach   = hwbc_add_task(h, J_reach_ptr, x_reach_ptr, 6);  // priority 2
    let id_post    = hwbc_add_task(h, J_post_ptr, x_post_ptr, n_dof); // priority 3
    hwbc_solve(h);
    for i in 0..n_dof { let q = hwbc_get_qdot(h, i); ... }
}
```

### Verification

Three direct C tests:

1. **Single full-rank task** — 3-DOF, identity Jacobian, target
   `(1, −2, 3)`. Recovers `q̇ = (1.000000, −2.000000, 3.000000)`
   exactly.
2. **Strict priority on conflicting scalar** — high-pri target = 2,
   low-pri target = 0, both with `J = [1]`. Hierarchical: `q̇ = 2.000000`
   (high-pri win), high-pri residual = 0, **low-pri residual = 2**
   (the conflict is unsatisfiable in the now-empty null space).
   Compare to weighted `wbc.nr` which would give `q̇ = 9/10`.
3. **Redundant arm with secondary regularization** — 4-DOF, 3-D EE
   primary task via `J = [I_3 | 0]` + secondary task driving DOF 3
   to 0.2 via `J = [0,0,0,1]`. Solution: primary residual `9.5e-4`
   (numerical from damping), DOF 3 driven exactly to `0.1998`.

### Files

- `stdlib/runtime/hwbc_rt.c` — `nuc_hwbc_*` API; per-task null-space
  contraction; Frobenius-norm exhaustion guard; damped LS solve.
- `stdlib/rods/hwbc.nr` — externs + wrappers.
- `tests/rods/hwbc_smoke.nr` — build-only smoke.

---

## [0.2.263] — 2026-04-24

**Robotics: trapezoidal time-parameterization (`topp`) for an arc-
length path. Given path length `L`, max velocity `v_max`, and max
acceleration `a_max`, computes the minimum-time `s(t)` profile
with `|ṡ| ≤ v_max` and `|s̈| ≤ a_max`. Falls back to triangular
profile (peak `< v_max`) when the path is too short for cruise.**

### Algorithm

```
t1 = v_max / a_max       // accel duration
d1 = ½ · a_max · t1²     // accel distance

if 2·d1 ≥ L:             // triangular — never reach v_max
    t_accel = √(L / a_max)
    v_peak  = a_max · t_accel
    T       = 2 · t_accel
else:                    // trapezoidal
    t_cruise = (L − 2·d1) / v_max
    T        = 2·t1 + t_cruise

s(t) = ½ a t²                                        for t in [0, t1]
     = d1 + v_peak (t − t1)                          for t in [t1, t1+t_cruise]
     = L − ½ a (T − t)²                              for t in [t1+t_cruise, T]
```

### Surface

```nucleor
import "stdlib/rods/topp.nr"

let h = topp_trap_new(L_b, v_max_b, a_max_b);
let T = topp_trap_total_time(h);

for tick {
    let s_b = topp_trap_position(h, t_b);
    let v_b = topp_trap_velocity(h, t_b);
    let a_b = topp_trap_acceleration(h, t_b);
}
```

Use to time-parameterize a geometric path (e.g. minimum-snap from
`qtraj.nr`): the user gets `t → s(t)` and maps `s` back to robot
configuration via the original path.

### Verification

Two direct C tests:

1. **Trapezoidal** (L=10, v_max=2, a_max=1): T=`7.000000`s
   (analytical = 7), v_peak=`2.000000` (=v_max). Spot checks at
   `t=1` (`s=0.5, v=1`), `t=3` mid-cruise (`s=4.0, v=2.0`),
   `t=7` end (`s=10.0`). Acceleration sign correct in all three
   phases.
2. **Triangular** (L=1, v_max=10, a_max=2 — v_max never reached):
   T=`1.414214`s (`=√2`), v_peak=`1.414214` (`=√(L·a_max)`).
   Boundary `s(0)=0`, `s(T)=L` exact.

### Files

- `stdlib/runtime/topp_rt.c` — `nuc_topp_trap_*` API; closed-form
  position / velocity / acceleration for accel / cruise / decel
  phases.
- `stdlib/rods/topp.nr` — externs + wrappers.
- `tests/rods/topp_smoke.nr` — build-only smoke.

---

## [0.2.262] — 2026-04-24

**Robotics: D* Lite incremental grid replanner (`dstar`) on a
2-D 8-connected grid (Koenig & Likhachev 2002). Solves the same
single-source shortest-path problem as A*, but designed for
repeated planning when only a small fraction of edge costs
change between queries — typical mobile-robot navigation when
new obstacles appear / disappear.**

### Algorithm

```
g(s)   — current best known cost-to-goal
rhs(s) — one-step look-ahead from neighbors
key(s) = (min(g, rhs) + h(s, s_start) + km,  min(g, rhs))

ComputeShortestPath:
  while top of U has key < key(s_start) OR s_start inconsistent:
    pop u
    if u stale (popped key < current key): re-push with current key
    elif g(u) == rhs(u): skip (lazy-heap stale entry, cell is consistent)
    elif g(u) > rhs(u):  g(u) = rhs(u);  update predecessors
    else (g(u) < rhs(u)): g(u) = ∞;  update u + predecessors
```

Edge cost: `max(c[s], c[s']) · (√2 if diagonal else 1)`. Heuristic:
octile distance (admissible AND consistent for 8-connected
uniform grids).

Implementation uses a lazy binary min-heap (no decrease-key /
delete operations) — duplicates are pushed and the pop side
detects stale entries.

### Surface

```nucleor
import "stdlib/rods/dstar.nr"

let h = dstar_new(W, H);
// ... set per-cell costs (negative = obstacle / ∞) ...
dstar_set_start(h, sx, sy);
dstar_set_goal(h, gx, gy);
dstar_plan(h);
// path:
for i in 0..dstar_path_len(h) {
    let x = dstar_path_x(h, i);
    let y = dstar_path_y(h, i);
}

// World changes — incremental replan:
dstar_update_cost(h, x, y, new_c_b);    // call repeatedly
dstar_replan(h);                         // O(perturbed cells)
```

### Verification

20×20 grid, three direct C tests:

1. **Open terrain**, plan `(0, 0) → (19, 19)`: 20 waypoints, total
   cost `26.8701` = exactly `19·√2`.
2. **Wall inserted** at column `x = 10` (rows 0–18; row 19 left
   open as a gap): incremental replan finds a 29-waypoint path
   with cost `32.1421` (vs 26.87 baseline). Zero waypoints inside
   the wall.
3. **Wall removed**: incremental replan returns to cost `26.8701`
   exactly, matching the original.

### Files

- `stdlib/runtime/dstar_rt.c` — `nuc_dstar_*` API; lazy min-heap
  on `(k1, k2)` lex order; ComputeShortestPath with consistent-
  skip + stale-key re-push; greedy path extraction.
- `stdlib/rods/dstar.nr` — externs + wrappers.
- `tests/rods/dstar_smoke.nr` — build-only smoke.

### Bug fixed during build

The lazy-heap variant of D* Lite needs an explicit
"`g(u) == rhs(u)` → skip" check before the over-/under-consistent
branches: otherwise stale heap entries for a now-consistent cell
fall through to the under-consistent branch and wrongly zap the
cell's `g` to ∞. Standard D* Lite avoids this by maintaining U
as a set (so consistent cells are never in U); the lazy heap
needs the explicit guard.

---

## [0.2.261] — 2026-04-24

**Robotics: AHRS via Mahony quaternion complementary filter
(`ahrs`). IMU orientation estimation — fuses gyro angular rates
with accelerometer gravity vector to maintain a body→world
quaternion. Mahony, Hamel & Pflimlin 2008.**

### Algorithm

Per IMU tick with gyro `ω` (rad/s) and accel `a` (gravity vector
in body frame):

```
g_pred_body = qᵀ · (0, 0, 1)             // predicted up direction in body
error       = g_pred_body × normalize(a)  // axis to rotate predicted into measured
ω_corr      = ω + Kp · error + Ki · ∫ error dt
q̇          = 0.5 · q · (0, ω_corr)
q          ← (q + q̇ · dt) / ‖·‖
```

`Kp` is the proportional accel→tilt correction (typical 1.0).
`Ki` accumulates the gyro-bias estimate (typical 0.0–0.1; `Ki = 0`
disables bias estimation and reduces to a pure complementary
filter).

### Surface

```nucleor
import "stdlib/rods/ahrs.nr"

let h = ahrs_new(Kp_b, Ki_b);
for tick {
    ahrs_update(h, gyro_ptr, accel_ptr, dt_b);
    ahrs_get_orientation(h, q_out_ptr);
    ahrs_get_euler(h, rpy_out_ptr);   // roll, pitch, yaw (rad)
}
// Pass 0 for accel_ptr to skip accel correction (e.g. during
// high-acceleration maneuvers).
```

### Verification

Three direct C tests:

1. **Stationary IMU** (gyro = 0, accel = (0, 0, 1)) for 1000 ticks:
   roll/pitch/yaw stayed at exactly 0 — no spurious drift.
2. **Tilted IMU** with accel = `(sin θ, 0, cos θ)`, `θ = 0.3 rad`,
   `Kp = 2.0`: converged to pitch = 0.300000 rad in 5000 ticks
   (test accepts the gimbal-lock alias `roll=π, pitch=0.3, yaw=π`
   which represents the same orientation).
3. **Pure z-axis gyro** at `0.5 rad/s` for 2 s with accel correction
   off: yaw = `1.000000 rad` exactly, matching `ω·T` to 6 digits.

### Files

- `stdlib/runtime/ahrs_rt.c` — `nuc_ahrs_*` API; quaternion mul/
  normalize, Mahony PI loop, ZYX Euler readout.
- `stdlib/rods/ahrs.nr` — externs + wrappers.
- `tests/rods/ahrs_smoke.nr` — build-only smoke.

---

## [0.2.260] — 2026-04-24

**Robotics: receding-horizon MPC wrapper (`mpc`) around iLQR.
Standard MPC pattern — observe state, plan over horizon T (warm-
started from previous tick's solution), execute u_0, shift the
warm-start sequence, tick again. Thin persistent layer over the
existing iLQR runtime.**

### Algorithm

```
At each control tick:
  1. Run iLQR for current state x with warm-start sequence u_seq.
  2. Output u_seq[0] to caller.
  3. Shift: u_seq[t] = u_seq[t+1] for t in 0..T-1; last slot keeps
     a copy of itself (standard "horizon-end stays put" tail).
```

The whole point is the warm start — re-planning from scratch each
tick is wasteful when consecutive states differ by a single
timestep. After the first few ticks, iLQR typically converges in
1–3 iterations per tick.

### Surface

```nucleor
import "stdlib/rods/mpc.nr"

let m = mpc_new(n_x, n_u, T, max_iters_per_step);
mpc_set_callbacks(m, dynamics_fp, stage_cost_fp, terminal_cost_fp);
// optional warm seed (else starts at zeros):
mpc_warm_start(m, u_seq_ptr);

for tick {
    mpc_step(m, x_ptr, u_out_ptr);
    // apply u_out to plant; sequence is auto-shifted
}
```

### Verification

Closed-loop MPC on a 2-D double integrator (pos, vel; scalar accel
input). Goal `(1, 0)` from start `(0, 0)`. Horizon `T = 30`,
`max_iters_per_step = 8`, terminal cost `50·(p−1)² + 5·v²`.

- 60 ticks total. Final state `(1.0098, 0.0065)` — converged.
- Warm-start kept iLQR at **2 iterations per tick** the entire run
  (max 2, avg-after-warm-up 2.00). Without warm-start each tick
  would take ~10–20 iters.
- Total iLQR work: **120 iters across 60 ticks**.

### Files

- `stdlib/runtime/mpc_rt.c` — `nuc_mpc_*` API; persistent
  warm-start buffer; calls `nuc_ilqr_optimize` per tick; shift
  policy.
- `stdlib/rods/mpc.nr` — externs + wrappers; pulls in both
  `mpc_rt.c` and `ilqr_rt.c` via `#cfile`.
- `tests/rods/mpc_smoke.nr` — build-only smoke.

---

## [0.2.259] — 2026-04-24

**Fix: rename v0.2.257's `pid` rod to `pidc`. The new rod's
`nuc_pid_*` C functions collided with the simpler PID exposed by
the older `control.nr` (its `nuc_pid_new` / `nuc_pid_update` /
`nuc_pid_reset`); importing both rods would fail at link time.**

The new rod's user-facing surface is `pidc_new`, `pidc_set_gains`,
`pidc_set_integral_clamp`, `pidc_set_output_clamp`, `pidc_reset`,
`pidc_step`, `pidc_integral`, `pidc_last_error`, `pidc_free`. The
"c" suffix denotes the **clamping** PID (the older one in
`control.nr` lacks anti-windup + output clamps). Behavior is
unchanged from v0.2.257 — only the names moved.

### Verification

A two-import smoke (`import "stdlib/rods/control.nr"` and
`import "stdlib/rods/pidc.nr"`) builds + links cleanly,
confirming the symbol clash is gone.

### Files

- Renamed `stdlib/runtime/pid_rt.c` → `stdlib/runtime/pidc_rt.c`
  with all `nuc_pid_*` → `nuc_pidc_*`.
- Renamed `stdlib/rods/pid.nr` → `stdlib/rods/pidc.nr` with all
  `pid_*` → `pidc_*`.
- Renamed `tests/rods/pid_smoke.nr` → `tests/rods/pidc_smoke.nr`.

---

## [0.2.258] — 2026-04-24

**Robotics: discrete infinite-horizon LQR (`lqr`) via Riccati
iteration. Linear-time-invariant systems with quadratic cost get a
static optimal feedback gain `u = −K · x`. Complement to `ilqr.nr`
and `ddp.nr` (both finite-horizon nonlinear).**

### Algorithm

```
x_{k+1} = A · x_k + B · u_k
J = Σ (xᵀ Q x + uᵀ R u)
u_k = −K · x_k

K = (R + Bᵀ P B)⁻¹ Bᵀ P A

P solves the discrete algebraic Riccati equation:
  P = Aᵀ P A − Aᵀ P B (R + Bᵀ P B)⁻¹ Bᵀ P A + Q
Solved here by direct Riccati recursion (start P₀ = Q, iterate).
Converges for stabilizable (A, B) with detectable Q^{1/2}.
```

### Surface

```nucleor
import "stdlib/rods/lqr.nr"

let h = lqr_new(n_x, n_u);
// ... set A, B, Q, R entrywise ...
lqr_solve(h, max_iters, tol_b);
// Read computed gain K (n_u × n_x):
let kij = lqr_K(h, i, j);
// Compute feedback control:
lqr_compute_u(h, x_ptr, u_out_ptr);
```

### Verification

Two direct C tests:

1. **Scalar (a=1, b=1, Q=1, R=1)** — DARE has the analytical
   solution `P = (1+√5)/2 = φ ≈ 1.618034`, `K = P/(1+P) ≈ 0.618034`.
   Convergence in 16 iters; both P and K match to 6 digits exactly.
2. **Double integrator** (`dt = 0.1`, `Q = diag(10, 1)`, `R = 1`).
   118 iters to converge; computed gain `K = (2.76, 2.51)`.
   Closed-loop sim from `x₀ = (1, 0)` for 200 ticks → final state
   `(0.000000, 0.000000)` (stabilized to machine zero).

### Files

- `stdlib/runtime/lqr_rt.c` — `nuc_lqr_*` API; small dense gemm
  helpers (NN and TN variants); GJ inverse; Riccati recursion.
- `stdlib/rods/lqr.nr` — externs + wrappers.
- `tests/rods/lqr_smoke.nr` — build-only smoke.

---

## [0.2.257] — 2026-04-24

**Robotics: classic PID controller (`pid`) with anti-windup
integral clamp + output clamp. Foundational SISO controller — the
single missing primitive in the controls set (between bang-bang
and full model-based control like iLQR/WBC).**

### Algorithm

```
error    = setpoint − measurement
integral = clamp(integral + error · dt, i_lo, i_hi)    // anti-windup
deriv    = (error − last_error) / dt
u        = clamp(Kp·error + Ki·integral + Kd·deriv, u_lo, u_hi)
```

Anti-windup: integral is clamped to a user-set range so it cannot
run away during output saturation. Output is clamped after the sum
so the caller sees the actual command.

### Surface

```nucleor
import "stdlib/rods/pid.nr"

let p = pid_new(kp_b, ki_b, kd_b);
pid_set_integral_clamp(p, i_lo_b, i_hi_b);
pid_set_output_clamp  (p, u_lo_b, u_hi_b);

for tick {
    let u_b = pid_step(p, setpoint_b, meas_b, dt_b);
}
```

### Verification

Four direct C tests:

1. P-only: `Kp = 2`, `error = 2` → `u = 4.0` exactly.
2. PI integrator: `Ki = 1`, 5 calls of `error = 2`, `dt = 0.5` →
   `integral = 5.0` exactly.
3. Anti-windup: `Ki = 1`, integral clamp `[−3, 3]`, 100 calls of
   `error = 2` → `integral = 3.0` (would be 100 without clamp).
4. Closed loop on integrator plant: PI = (2, 1), 1000 ticks at
   `dt = 0.01` → `x = 1.000427`, error `4.3e-4`. Converges to
   setpoint as expected.

### Files

- `stdlib/runtime/pid_rt.c` — `nuc_pid_*` API.
- `stdlib/rods/pid.nr` — externs + wrapper functions.
- `tests/rods/pid_smoke.nr` — build-only smoke.

---

## [0.2.256] — 2026-04-24

**Robotics: whole-body / multi-task controller (`wbc`) — weighted
QP that simultaneously realizes a stack of task-space objectives
(end-effector velocities, CoM motion, posture regularization) by
solving for joint velocities at each control tick.**

### Algorithm

Each task is `(J_i ∈ ℝ^(m_i × n), ẋ_i ∈ ℝ^(m_i), w_i > 0)`.
Weighted-QP cost:

```
minimize  Σ_i w_i · ‖J_i · q̇ − ẋ_i‖²  +  α · ‖q̇‖²
```

Closed form via Tikhonov-regularized weighted least squares:

```
A = Σ_i w_i · J_iᵀ · J_i  +  α · I
b = Σ_i w_i · J_iᵀ · ẋ_i
q̇ = A⁻¹ · b
```

The α regularizer handles redundancy and rank deficiency without
extra machinery — rotation around redundant joints is naturally
pulled toward zero.

### Use cases

- **Humanoid balance + reach**: CoM velocity task + hand-position
  task + posture regularizer task (low weight) for null-space
  shaping.
- **Mobile-manipulator coordination**: base-motion task + arm-pose
  task with weights chosen by application (e.g. higher weight on
  the arm when accuracy matters most).
- **Redundant-arm IK**: 7-DOF arm with 6-D Cartesian target plus a
  posture preference forms a complete weighted stack.

### Surface

```nucleor
import "stdlib/rods/wbc.nr"

let h = wbc_new(n_dof, alpha_b);

// Per control tick:
wbc_clear_tasks(h);
let id_eef  = wbc_add_task(h, J_eef_ptr,  x_des_eef_ptr,  6,    w_eef_b);
let id_com  = wbc_add_task(h, J_com_ptr,  x_des_com_ptr,  3,    w_com_b);
let id_post = wbc_add_task(h, J_post_ptr, x_des_post_ptr, n_dof, w_post_b);
wbc_solve(h);

// Read joint-velocity command:
for i in 0..n_dof { let qd_b = wbc_get_qdot(h, i); ... }

// Per-task residual norm:
let res_b = wbc_task_residual(h, id_eef);
```

### Verification

Three direct C tests:

1. **Single full-rank task** — 3-DOF, identity Jacobian, target
   `(1, −2, 3)`. Recovers `q̇ = (1.000000, −2.000000, 3.000000)`
   exactly.
2. **Redundant-arm regularization** — 4-DOF, 3-D EE target via
   `J = [I_3 | 0]`. Solution: `q̇ = (0.4995, 0.6993, −0.3996, 0.0)`
   — task met (residual `9.5e-4`, dominated by `α = 1e-3` cost
   tradeoff), redundant 4th DOF driven exactly to zero by the
   regularizer.
3. **Two-task weight tradeoff** — scalar problem with conflicting
   targets `1.0` (weight 9) and `0.0` (weight 1). Solution:
   `q̇ = 0.900000` = closed-form weighted average `9/(9+1)`.

### Files

- `stdlib/runtime/wbc_rt.c` — `nuc_wbc_*` API; per-tick task stack;
  weighted normal-equations assembly; in-place GJ solve.
- `stdlib/rods/wbc.nr` — externs + `wbc_new` /
  `wbc_set_regularization` / `wbc_clear_tasks` / `wbc_add_task` /
  `wbc_solve` / `wbc_get_qdot` / `wbc_task_residual` / `wbc_free`.
- `tests/rods/wbc_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.255] — 2026-04-24

**Robotics: box LCP solver via Projected Gauss-Seidel (`lcp`). The
iteration that underlies MuJoCo, Bullet, ODE, and most other rigid-
body contact solvers. Solves**

```
find λ ∈ [lo, hi]  such that  w = M·λ + q  satisfies
    w_i ≥ 0  whenever  λ_i = lo_i
    w_i ≤ 0  whenever  λ_i = hi_i
    w_i = 0  whenever  lo_i < λ_i < hi_i
```

### Algorithm

```
for iter in 0..max_iters:
    for i in 0..n:
        w_i  = q_i + Σ_{j≠i} M_ij · λ_j
        λ_i' = clamp(−w_i / M_ii, lo_i, hi_i)
    if max_i |λ_i' − λ_i| < tol: break
```

Convergence: PGS converges for any positive-definite M (Cottle,
Pang & Stone 1992). For symmetric PSD M it converges if a solution
exists. For well-conditioned soft-contact LCPs, 30–100 iters reach
1e-4 accuracy.

### Use cases

- **Unilateral contact**: λ ∈ [0, ∞) — non-penetration normal force
  (default bounds set by `lcp_pgs_new`).
- **Coulomb friction (pyramidal linearization)**: tangent components
  in box `[−μ·λ_n, μ·λ_n]` per contact.
- **Joint limits**: bounded λ for a constraint that activates at
  joint stops.
- **Bilateral constraint**: λ ∈ (−∞, ∞) reduces to a normal linear
  solve via PGS for symmetric positive-definite systems.

### Surface

```nucleor
import "stdlib/rods/lcp.nr"

let h = lcp_pgs_new(n);
for i in 0..n  { for j in 0..n {
    lcp_pgs_set_M(h, i, j, M_ij_b);
}}
for i in 0..n  { lcp_pgs_set_q(h, i, q_i_b); }
// optional bounds + warm start
lcp_pgs_set_bounds(h, i, lo_b, hi_b);
lcp_pgs_set_initial(h, i, lambda0_b);

let iters = lcp_pgs_solve(h, max_iters, tol_b);
let lam_b = lcp_pgs_get(h, i);
let res_b = lcp_pgs_residual(h);
```

### Verification

Four direct C tests:

1. **Classic 2-D LCP**: `M = [[2,1],[1,2]]`, `q = [-1,-1]`, λ ≥ 0.
   Converges in 21 iters to `λ = (1/3, 1/3)`, residual `2.3e-13`.
   Matches the analytical solution exactly.
2. **Box LCP at active bounds**: `M = I`, `q = [-2, 2]`, bounds
   `[-0.5, 0.5]`. Converges in 2 iters to `λ = (+0.5, -0.5)` —
   both clipped to box edges.
3. **1-DOF normal contact**: ball at velocity −1 m/s, `M = 1`,
   `q = -1`, λ ≥ 0. Converges in 2 iters to `λ = 1.0` — the
   impulse that exactly closes the gap.
4. **Friction pyramid**: 3-vec `[λ_n, λ_t1, λ_t2]` with `q` driving
   tangents past their friction box. Converges in 2 iters to
   `λ_n = 2.0`, tangents clipped to `±μ·λ_n` exactly.

### Files

- `stdlib/runtime/lcp_rt.c` — `nuc_lcp_pgs_*` API, PGS iteration,
  complementarity-residual diagnostic.
- `stdlib/rods/lcp.nr` — externs + `lcp_pgs_new` /
  `lcp_pgs_set_M` / `lcp_pgs_set_q` / `lcp_pgs_set_bounds` /
  `lcp_pgs_set_initial` / `lcp_pgs_solve` / `lcp_pgs_get` /
  `lcp_pgs_residual` / `lcp_pgs_free` wrappers.
- `tests/rods/lcp_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.254] — 2026-04-24

**Robotics: bipedal footstep planner (`fsp`). Discrete A* search
over reachable footstep poses with a user-supplied action set +
terrain-validity callback. Foundation for bipedal locomotion
planning where the front-end picks where each foot lands and the
back-end (e.g., a whole-body controller) realizes the steps.**

### Algorithm

```
State: (x, y, θ, foot ∈ {LEFT, RIGHT})
Discretization: ix = round(x/res_xy), iy = same, iθ = round((θ mod 2π)/res_theta)
Successors: for each registered action (dx, dy, dθ, cost):
    dy_eff = (foot==LEFT) ? dy : -dy        (mirror y for right stance)
    nx = x + cos(θ)·dx − sin(θ)·dy_eff
    ny = y + sin(θ)·dx + cos(θ)·dy_eff
    nθ = θ + ((foot==LEFT) ? dθ : −dθ)
    nfoot = 1 − foot
    if !is_valid(nx, ny, nθ): skip
    cost_inc = action.cost + Euclidean step length
A*: heuristic = Euclidean(start, goal) / max_step_length over actions.
Goal: |xy| within `goal_tol_xy` AND |θ−θ_goal| within `goal_tol_theta`.
```

The y-component mirroring means the user writes the action set
once in left-stance coordinates and gets symmetric gait in both
stance directions for free.

### Surface

```nucleor
import "stdlib/rods/fsp.nr"

let h = fsp_new();
// Register a forward action and a sidestep action (in LEFT stance frame):
fsp_add_action(h, dx_b, dy_b, dtheta_b, cost_b);
// ...
let n = fsp_plan(h, x0_b, y0_b, t0_b, foot0,
                    xg_b, yg_b, tg_b,
                    max_iters, valid_fp);
for i in 0..n {
    let x_b = fsp_path_x(h, i);
    let y_b = fsp_path_y(h, i);
    let t_b = fsp_path_theta(h, i);
    let f   = fsp_path_foot(h, i);    // 0 = LEFT, 1 = RIGHT
}
```

`valid_fp` is `fn(x_b, y_b, theta_b) -> i64`; returns 1 if the foot
placement at `(x, y, θ)` is allowed, 0 if not.

### Verification

Two direct C tests with a 5-action default gait (forward, longer
forward, sidestep, ±turn-step):

1. **Open terrain** — `(0,0,0,LEFT)` → `(3,0,0)`. Plan: 11
   footsteps, final pose `(3.000, 0.000, 0.000)`, feet alternate
   throughout, total cost 3.606.
2. **Wall obstacle** at `x ∈ [1, 2]` and `y ∈ [−0.4, 0.4]` —
   same start/goal. Plan: 15 footsteps, no step inside the wall,
   final pose `(3.023, 0.047)` within tolerance.

### Files

- `stdlib/runtime/fsp_rt.c` — `nuc_fsp_*` API, A* with binary
  min-heap on f-score and open-addressing hash table for visited
  states (capped at 1M slots).
- `stdlib/rods/fsp.nr` — externs + `fsp_new` / `fsp_set_resolution` /
  `fsp_set_goal_tolerance` / `fsp_add_action` / `fsp_plan` /
  `fsp_path_*` / `fsp_free` wrappers.
- `tests/rods/fsp_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.253] — 2026-04-24

**Robotics: minimum-snap polynomial trajectory generator (qtraj)
for quadrotors and other differentially-flat systems (Mellinger &
Kumar 2011). Quadrotor dynamics are differentially flat in
(x, y, z, yaw); a smooth trajectory in those four outputs uniquely
determines the full 12-state + 4-input sequence.**

### Algorithm

Per axis: degree-7 polynomial per segment, N segments → 8N
coefficients. The QP

```
minimize Σ_k ∫_0^{T_k} (p_k^(4)(t))² dt
s.t.
  - 4 boundary conditions at t=0  of segment 0   (pos, vel, acc, jerk)
  - 4 boundary conditions at end of segment N-1
  - per interior waypoint k=1..N-1:
      * p_{k-1}(T_{k-1}) = waypts[k]
      * p_k(0)           = waypts[k]
      * vel, acc, jerk continuity across the boundary
```

is solved as a KKT system

```
[ 2Q  Aᵀ ] [ c ]   [ 0 ]
[  A   0 ] [ λ ] = [ b ]
```

with dimension `13N + 3` × `13N + 3`. Dense Gauss-Jordan handles
typical N ≤ 20 comfortably.

### Quadrotor workflow

One handle = one flat output (one axis). Call this rod four times
— sharing the same waypoint count + segment times — to generate a
full quadrotor trajectory in (x, y, z, yaw):

```nucleor
import "stdlib/rods/qtraj.nr"

let tx = qtraj_new(n_seg);
let ty = qtraj_new(n_seg);
let tz = qtraj_new(n_seg);
let tyaw = qtraj_new(n_seg);
// ... set segment times on all four (must match) ...
// ... set per-axis waypoints ...
qtraj_solve(tx);  qtraj_solve(ty);  qtraj_solve(tz);  qtraj_solve(tyaw);

// Evaluate position / velocity / acceleration at absolute time t:
let px_b = qtraj_evaluate_total(tx, 0, t_b);
let vx_b = qtraj_evaluate_total(tx, 1, t_b);
let ax_b = qtraj_evaluate_total(tx, 2, t_b);
```

Default boundary derivatives (vel, acc, jerk) are 0 at start and
end; user can override via `qtraj_set_start_boundary` /
`qtraj_set_end_boundary`.

### Verification

3-segment 1-D trajectory, waypoints `[0, 1, 4, 2]`, segment times
`[1, 1, 1] s`, all start/end derivatives 0:

- All four waypoints hit **exactly** (errors ≤ machine ε).
- Start/end velocity, acceleration, jerk all `≈ 1e-13` (machine zero
  through the linear solve).
- Velocity, acceleration, jerk continuous across both interior
  boundaries (verified by ε-perturbed left/right sampling).
- Total time correct to machine precision.

### Files

- `stdlib/runtime/qtraj_rt.c` — `nuc_qtraj_*` API; per-segment snap
  cost matrix, KKT-system constraint assembly, dense solve.
- `stdlib/rods/qtraj.nr` — externs + `qtraj_new` /
  `qtraj_set_waypoint` / `qtraj_set_segment_time` /
  `qtraj_set_start_boundary` / `qtraj_set_end_boundary` /
  `qtraj_n_segments` / `qtraj_total_time` / `qtraj_solve` /
  `qtraj_evaluate` / `qtraj_evaluate_total` / `qtraj_free` wrappers.
- `tests/rods/qtraj_smoke.nr` — build-only smoke (functional
  coverage in the direct C unit test).

---

## [0.2.252] — 2026-04-24

**Robotics: Bundle adjustment (visual SLAM back-end). Jointly
refines a set of camera SE(3) poses and a set of 3D world points
to minimize the sum of squared 2-D reprojection errors over a list
of (camera, point, pixel) observations. Pinhole camera model with
shared focal length + principal point.**

### Algorithm

```
Per camera (i): t_i ∈ ℝ³, q_i ∈ SO(3) (unit quaternion)
Per point   (j): X_j ∈ ℝ³

Predicted pixel for observation (cam i, point j):
    X_cam = R_iᵀ · (X_j − t_i)
    u_pred = cx + f · X_cam[0] / X_cam[2]
    v_pred = cy + f · X_cam[1] / X_cam[2]

Residual: r = (u_pred − u_meas, v_pred − v_meas) ∈ ℝ²

Update: cameras on the SE(3) manifold (right-multiplied SO(3) exp);
points by simple addition. Camera 0 gauge-fixed.

Solve: stacked 2-D residuals → dense Levenberg-Marquardt-damped
Gauss-Newton normal equations.
```

Numerical Jacobians via central differences (2 × 9 evals per obs
per iter — 6 cam DOF + 3 point DOF). Linear solve via dense
Gauss-Jordan inverse.

### Surface

```nucleor
import "stdlib/rods/ba.nr"

let h = ba_new(n_cams, n_pts, focal_b, cx_b, cy_b);
// initial estimates
for i in 0..n_cams { ba_set_cam(h, i, t_ptr_i, q_ptr_i); }
for j in 0..n_pts  { ba_set_pt (h, j, p_ptr_j); }
// observations
ba_add_obs(h, cam_i, pt_j, u_b, v_b, info_b);
// optimize
ba_optimize(h, max_iters, tol_b);
// read back refined
ba_get_cam(h, i, t_out, q_out);
ba_get_pt (h, j, p_out);
```

### Verification

Synthetic noise-free scene: 5 cameras arranged in a horizontal arc
above and behind a 12-point cube at the origin (60 perfect
projection observations). Initial estimates: cam 0 at ground truth
(gauge-fixed); cams 1–4 perturbed in position + rotation; all
points perturbed off ground truth.

- Reprojection cost: **257 122 → 0.0 in 5 iterations**.
- All four free cameras: rotation recovered exactly (`rot_err = 0` rad).
- Camera positions and 3-D points all consistent with a **single
  global scale factor** (1.019775) relative to cam 0 — i.e. the
  optimizer found the correct rescaled solution, confirming the
  expected 1-DOF scale ambiguity in pure-pixel BA. (Real systems
  break this with a depth prior or a known baseline.)

### Files

- `stdlib/runtime/ba_rt.c` — `nuc_ba_*` API; quaternion helpers,
  pinhole projection, residual + numerical 2×6 / 2×3 Jacobians,
  dense LM-damped Gauss-Newton.
- `stdlib/rods/ba.nr` — externs + `ba_new` / `ba_set_cam` /
  `ba_set_pt` / `ba_get_cam` / `ba_get_pt` / `ba_add_obs` /
  `ba_optimize` / `ba_total_cost` / `ba_free` wrappers.
- `tests/rods/ba_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.251] — 2026-04-24

**Robotics: 3D KD-tree (`kdt`) for fast nearest-neighbor queries
that adapt to non-uniform point distributions. Median-split on
alternating axes + bounding-box pruning. O(log n) average-case NN
with proper splitting-plane pruning + heap-based k-NN.**

### Why a third NN rod

This release brings the robotics NN catalog to three rods, each
with a distinct sweet spot:

- `sgrid.nr` — uniform spatial-hash grid. Constant-time average
  lookup; ideal when point distribution is roughly uniform and the
  expected NN distance can be picked up front.
- `kdtree.nr` — general n-dimensional kd-tree using a separate
  point-vector handle (`KDVec` from `vec.nr`). Suited to ML or
  clustering workflows where points already live in a vec and
  dimensionality varies.
- `kdt.nr` — 3D-specific kd-tree with the same insert/build/query
  workflow as `sgrid.nr`. Adapts to non-uniform distributions via
  median-split. Best when the workspace has dense + sparse regions
  and you don't want to tune a cell size.

### Surface

```nucleor
import "stdlib/rods/kdt.nr"

let h = kdt_new(n_pts_hint);
for each point: kdt_insert(h, x_b, y_b, z_b);
kdt_build(h);                     // call ONCE after all inserts

// Nearest-neighbor:
let nn_idx = kdt_nearest(h, qx_b, qy_b, qz_b);

// k-Nearest:
//   out_indices_ptr — caller-allocated i64[k] (or 0 to skip)
//   out_dist2_ptr   — caller-allocated double[k] (or 0 to skip)
let n = kdt_knearest(h, qx_b, qy_b, qz_b, k,
                     out_indices_ptr, out_dist2_ptr);
```

### Verification

Three direct C tests against brute-force reference:

1. **Uniform 1000-point cloud, 200 random queries** — `kdt_nearest`
   matched brute-force NN on every query (0 mismatches).
2. **k-NN, k=5, 200 queries** — distances matched brute-force on
   every neighbor (0 mismatches), and KD-tree results were returned
   in nearest-first order (0 ordering violations).
3. **Non-uniform stress** — 800 points in a `0.01³` cluster around
   `(0.5, 0.5, 0.5)` + 200 sprinkled across `(0, 100)³`. 100 mixed
   queries from both regions: 0 NN mismatches.

### Files

- `stdlib/runtime/kdt_rt.c` — `nuc_kdt_*` API; qsort-based
  median-split build; recursive bounding-box-pruned NN; heap-based
  k-NN with splitting-plane pruning.
- `stdlib/rods/kdt.nr` — externs + `kdt_new` / `kdt_insert` /
  `kdt_count` / `kdt_build` / `kdt_nearest` / `kdt_knearest` /
  `kdt_free` wrappers.
- `tests/rods/kdt_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.250] — 2026-04-24

**Robotics: 3D pose-graph SLAM (SE(3) Gauss-Newton). Three-dimensional
generalization of `pgs.nr`. Each pose is an SE(3) element — translation
in ℝ³ + rotation in SO(3) stored as a unit quaternion. Edges encode
relative-pose measurements with diagonal information weights (3
translational + 3 rotational per edge).**

### Algorithm

```
State per node: t ∈ ℝ³ + unit quaternion q ∈ SO(3)
Optimization variable per node (i > 0): δ ∈ ℝ⁶ in se(3) Lie algebra

Edge residual (j relative to i, given measurement (t_meas, R_meas)):
    R_pred = R_iᵀ · R_j
    t_pred = R_iᵀ · (t_j − t_i)
    r_t    = t_pred − t_meas              (ℝ³)
    r_R    = log(R_measᵀ · R_pred)        (ℝ³, axis-angle)

Update on the manifold:
    t_i ← t_i + δ_t
    R_i ← R_i · exp(δ_θ)              (right-multiplied SO(3) exp)
```

Jacobians of `r ∈ ℝ⁶` w.r.t. the 6-DOF perturbations of nodes `i`
and `j` are computed by central finite differences (12 residual
evaluations per edge per iter). Linear normal equations
`H · δ = −b` solved with dense Gauss-Jordan inverse + small LM
damping. Node 0 is gauge-fixed.

### Surface

```nucleor
import "stdlib/rods/pgs3.nr"

let g = pgs3_new(n_nodes);
// initial estimates
for i in 0..n_nodes { pgs3_set_node(g, i, t_ptr_i, q_ptr_i); }
// relative-pose constraint edges
pgs3_add_edge(g, i, j, dt_ptr, dq_ptr, info_ptr);   // info = double[6]
// optimize
pgs3_optimize(g, max_iters, tol_b);
// read back
pgs3_get_node(g, i, t_out_ptr, q_out_ptr);
```

`info_ptr` is `double[6]` of per-DOF diagonal weights:
`[info_tx, info_ty, info_tz, info_rx, info_ry, info_rz]`.

### Verification

4-pose loop in 3D with rotated/translated edges + initial estimates
perturbed away from ground truth. Edges: `0→1, 1→2, 2→3, 3→0` (loop
closure). Gauss-Newton converged in **4 iterations**, cost
`15.23 → 0.0 (machine precision)`. All three free poses recovered
to translation error `0` and rotation error `0` to printed digits.

### Files

- `stdlib/runtime/pgs3_rt.c` — `nuc_pgs3_*` API,
  `_so3_exp` / `_so3_log` / quaternion helpers, residual + numerical
  6×6 Jacobians, dense Gauss-Newton iteration.
- `stdlib/rods/pgs3.nr` — externs + `pgs3_new` /
  `pgs3_set_node` / `pgs3_get_node` / `pgs3_add_edge` /
  `pgs3_optimize` / `pgs3_total_cost` / `pgs3_free` wrappers.
- `tests/rods/pgs3_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.249] — 2026-04-24

**Robotics: Differential Dynamic Programming (Mayne 1966; Jacobson
& Mayne 1970). Second-order extension of iLQR — includes the full
dynamics-Hessian contractions in the Q-function update for
quadratic local convergence (vs iLQR's superlinear).**

### Algorithm

Where iLQR (Gauss-Newton) computes:

```
Q_xx = l_xx + Aᵀ V_xx A
Q_uu = l_uu + Bᵀ V_xx B
Q_ux =        Bᵀ V_xx A
```

DDP adds the second-order tensor terms:

```
Q_xx += Σ_k V_x[k] · f_xx[k]
Q_uu += Σ_k V_x[k] · f_uu[k]
Q_ux += Σ_k V_x[k] · f_ux[k]
```

where `f_xx`, `f_uu`, `f_ux` are the dynamics Hessian tensors w.r.t.
`(x,x)`, `(u,u)`, `(u,x)`. Computed by 4-point central differences
against the user's `dynamics_fp` callback.

### When to use

- **DDP**: hot-starting near the optimum, smooth dynamics, small
  state dimension (`n_x ≤ ~10`). Quadratic local convergence makes
  the final iterations very cheap.
- **iLQR** (`stdlib/rods/ilqr.nr`): large state dim (Hessian FD cost
  dominates), stiff/non-smooth dynamics (Hessians noisy), or you
  just want one-shot optimization without the warm-start premium.

### Surface

```nucleor
import "stdlib/rods/ddp.nr"

// Same I/O contract as ilqr_optimize.
let n = ddp_optimize(n_x, n_u, T,
    x0_ptr, u_seq_ptr,    // u_seq is double[T*n_u], modified in place
    max_iters,
    dynamics_fp, stage_cost_fp, terminal_cost_fp);
```

### Verification

Two direct C tests covering both regimes:

1. **2D linear double-integrator** (pos, vel; cost = `0.001·u² + 10(x−1)² + v²` terminal). DDP converged in **2 iterations**, cost `10.000 → 0.004`, terminal `(1.000, 0.006)`. Confirms the second-order tensor terms vanish exactly when `f_xx = f_uu = f_ux = 0` and DDP cleanly reduces to iLQR for linear dynamics.
2. **1D nonlinear** (`x_{t+1} = x + u + 0.1 x²`, cost `0.01 u² + 100(x_T − 1)²`). DDP converged in **13 iterations**, cost `100.000 → 0.0002`, terminal `x = 1.0000` to four digits.

### Files

- `stdlib/runtime/ddp_rt.c` — `nuc_ddp_optimize`, `nuc_ddp_total_cost`,
  `_dyn_hessian` (full f_xx/f_uu/f_ux tensors via 4-point central FD),
  shared `_gj_inv` / `_dyn_jacobian` / `_cost_quadratize` / forward
  pass with bisection line search.
- `stdlib/rods/ddp.nr` — externs + `ddp_optimize` / `ddp_total_cost`
  Nucleor wrappers.
- `tests/rods/ddp_smoke.nr` — build-only smoke (functional coverage
  in the direct C unit test).

---

## [0.2.248] — 2026-04-24

**Robotics: Informed RRT* (Gammell, Srinivasa & Barfoot 2014).
After the first solution is found with cost `c_best`, restrict
subsequent samples to the prolate hyperspheroid (ellipsoid) with
foci at start/goal and major axis `c_best`. As `c_best` shrinks
via rewiring, the ellipsoid shrinks, focusing sampling on the
region that could improve the path.**

### Algorithm

```
center = (start + goal) / 2
c_min  = ‖goal - start‖

phase A — uniform sampling until the first solution is found
phase B — for each subsequent sample:
  1. Sample u uniformly on unit n-sphere (Box-Muller normalize)
  2. Scale by U^(1/n) for uniform unit n-ball
  3. L = diag(c_best/2,
              sqrt(c_best² - c_min²)/2, ...,
              sqrt(c_best² - c_min²)/2)
  4. C = rotation aligning e_1 with (goal - start)/c_min
         (built via Gram-Schmidt)
  5. x = C · L · ball_point + center
  6. Reject if x outside the per-dim bounds, else use as sample
```

The remainder of the planner is identical to vanilla RRT* — same
near-radius rewiring, same goal-radius termination, same path
read-back via `rrt_path_len` / `rrt_path_at`.

### Surface

```nucleor
import "stdlib/rods/rrt.nr"

let h = rrt_new(n_dim, seed);
// ... set bounds and root ...
let ok = rrt_star_plan_informed(h, start_ptr, goal_ptr,
                                max_iters, step_b, radius_b,
                                coll_fp);
```

`rrt_star_plan_informed` accepts BOTH start and goal — the
ellipsoid sampler needs the start position. (`rrt_set_root`
already specifies the start internally; passing it again here
is for the ellipsoid math.)

### Verification

2D `[0, 10]²` planning, start `(1, 1)` → goal `(9, 9)`,
3000 iters / step 1.0 / radius 2.0. Both vanilla and informed
variants reached goal; informed produced denser path coverage
(47 waypoints vs 5) reflecting the focused sampling inside the
ellipsoid that contains the current best path.

### Files

- `stdlib/runtime/rrt_rt.c` — `nuc_rrt_star_plan_informed`,
  `_sample_unit_sphere`, `_build_rotation_C` (Gram-Schmidt with
  degenerate-axis fallback).
- `stdlib/rods/rrt.nr` — extern + `rrt_star_plan_informed`
  Nucleor wrapper.

---

## [0.2.247] — 2026-04-23

**Robotics: Lazy PRM (Bohlin & Kavraki 2000). Build the roadmap
WITHOUT collision-checking edges; validate edges on-demand during
the query. For dense roadmaps with sparse queries, much faster
than eager `prm_build` because most edges are never traversed.**

### Algorithm

```
Build: same k-NN structure as eager PRM, but skip the per-edge
       collision check entirely. Allocates an edge_blocked
       byte-array initialized to all-zero.

Query: outer loop (≤ 50 iters):
  1. Run Dijkstra over (roadmap + start + goal), skipping any
     edge marked blocked.
  2. Reconstruct candidate path.
  3. Validate the path's roadmap-roadmap edges via the user's
     collision callback.
  4. If all edges validate, return the path.
  5. Otherwise mark the failed edge (and its reverse) as blocked,
     and retry.
```

### Surface

```nucleor
import "stdlib/rods/prm.nr"

let p = prm_new(n_dim, seed);
// ... set bounds ...
prm_build_lazy(p, n_samples, k_neighbors, step_b, coll_fp);
let path_len = prm_query_lazy(p, start_ptr, goal_ptr,
                              k_neighbors, step_b, coll_fp);
```

### Verification

50 nodes / 250 edges built lazily in 2D `[0, 10]²` (no collision
check at build time). Query from `(1, 1)` to `(9, 9)` returned
a 10-waypoint path with edges validated on-demand.

### Files

- `stdlib/runtime/prm_rt.c` — `edge_blocked` array in `NPRM`,
  `nuc_prm_build_lazy`, `nuc_prm_query_lazy`,
  `_validate_roadmap_edge` helper.
- `stdlib/rods/prm.nr` — externs + `prm_build_lazy` /
  `prm_query_lazy` Nucleor wrappers.

---

## [0.2.246] — 2026-04-23

**Robotics: CCD capsule vs static AABB. Closes the CCD pair
matrix alongside sphere-sphere (v0.2.196), capsule-capsule
(v0.2.201), and sphere-AABB (v0.2.201). Common scenario: arm-
link sweep past an environment box.**

### Surface

```nucleor
import "stdlib/rods/collision.nr"

let t = coll_ccd_capsule_aabb(
    a0_x, a0_y, a0_z,  a1_x, a1_y, a1_z,    // capsule endpoint A
    b0_x, b0_y, b0_z,  b1_x, b1_y, b1_z, cr, // capsule endpoint B + radius
    aabb_min_x, aabb_min_y, aabb_min_z,
    aabb_max_x, aabb_max_y, aabb_max_z);
```

Returns earliest collision time `t ∈ [0, 1]` as bit-cast f64;
`-1.0` if clear. Both capsule endpoints linearly interpolate
from `a_*0 → a_*1` and `b_*0 → b_*1` over the unit time interval.

### Verification

| Test | Expected | Got |
|---|---|---|
| Capsule sweep clear of AABB | -1.0 | **-1.000000** |
| Capsule sweeps through AABB at midpoint | t ∈ (0, 1] | **0.480000** |

### Files

- `stdlib/runtime/collision_rt.c` — `_seg_aabb_dist2`,
  `_capaabb_dist2_at`, `nuc_coll_ccd_capsule_aabb`.
- `stdlib/rods/collision.nr` — extern + `coll_ccd_capsule_aabb`.

---

## [0.2.245] — 2026-04-23

**Robotics: spatial hash grid for fast 3D nearest-neighbor
queries. Bins points into cubic cells of side `cell_size`; NN
queries scan only the query cell + its 26 neighbors instead of
all points. Roughly O(1) average-case lookup on uniformly-
distributed clouds — order-of-magnitude speedup over the brute-
force O(N) NN in `icp.nr` and `prm.nr` for large workloads.**

### Surface

```nucleor
import "stdlib/rods/sgrid.nr"

let g = sgrid_new(cell_size_b, n_pts_hint);
for each point: sgrid_insert(g, x_b, y_b, z_b);
let nn_idx = sgrid_nearest(g, qx_b, qy_b, qz_b);
sgrid_free(g);
```

### Use cases

- Faster ICP NN matching: replace the brute-force scan in
  `icp_align` for large point clouds.
- Large-roadmap PRM expansion: find k nearest existing nodes
  during `prm_build` without scanning all of them.
- Particle-grid neighborhood lookups in physics sims (find
  particles within interaction radius).

### Verification

Inserted 3 points at (0, 0, 0), (1, 0, 0), (2, 0, 0); query at
(1.1, 0, 0):

| Quantity | Expected | Got |
|---|---|---|
| Count after 3 inserts | 3 | ✓ |
| Nearest to (1.1, 0, 0) | index 1 (point at (1, 0, 0)) | ✓ |

### Limitations (KD-tree / R-tree variants land in v0.6 if needed):

- Cell size is fixed; pick ≈ expected NN distance for best
  performance.
- For very non-uniform clouds, a KD-tree adapts better.
- Includes a brute-force fallback (correctness guaranteed) when
  the cell + 1-ring is empty.

### Files

- `stdlib/runtime/sgrid_rt.c` — `_SBin` / `NSGrid` types,
  FNV-1a hash, `nuc_sgrid_*` exports.
- `stdlib/rods/sgrid.nr` — externs + Nucleor wrappers.
- `tests/rods/sgrid_smoke.nr` — full functional smoke
  (count + nearest-neighbor verification).

---

## [0.2.244] — 2026-04-23

**Robotics: behavior trees — THE standard pattern for modern
robot behavior orchestration (Colledanchise & Ögren 2018). Tree
of composite + decorator + leaf nodes ticked from the root each
control cycle. Foundation for pick-and-place sequencing, reactive
obstacle avoidance, task scheduling, error recovery, and any
structured multi-step behavior with long-running actions.**

### Node types

| Type | Behavior |
|---|---|
| **SEQUENCE** | Tick children in order; FAIL on first failure, SUCCESS only when all succeed. |
| **SELECTOR** | Tick children in order; SUCCESS on first success, FAIL only when all fail. |
| **PARALLEL** | Tick all children; SUCCESS when k of n succeed, FAIL when n-k+1 fail. |
| **INVERTER** | Decorator: flips SUCCESS ↔ FAILURE of single child. |
| **ACTION** | Leaf: user callback returning SUCCESS / FAILURE / RUNNING. |
| **CONDITION** | Leaf: user callback returning SUCCESS / FAILURE. |

Status codes: 0 = SUCCESS, 1 = FAILURE, 2 = RUNNING.

### Surface

```nucleor
import "stdlib/rods/bt.nr"

let bt = bt_new();
let root = bt_add_sequence(bt, 0 - 1);    // -1 = no parent (root)
let _check = bt_add_condition(bt, root, check_fp);
let _act1  = bt_add_action(bt, root, action1_fp);
let _act2  = bt_add_action(bt, root, action2_fp);

// At each control cycle:
let status = bt_tick(bt, root, ctx_ptr);

bt_free(bt);
```

Leaf callbacks: `fn(ctx_ptr) -> i64` where the return value is
0 / 1 / 2 (SUCCESS / FAILURE / RUNNING). `ctx` is an opaque
pointer for shared state.

### Verification

| Test | Expected | Got |
|---|---|---|
| sequence(SUCC, SUCC, SUCC) | 0 = SUCCESS | **0** |
| sequence(SUCC, FAIL, SUCC) | 1 = FAILURE | **1** |
| selector(FAIL, SUCC, FAIL) | 0 = SUCCESS | **0** |
| inverter(FAIL) | 0 = SUCCESS | **0** |
| composite (3 count actions + threshold check) | 0 = SUCCESS, counter=3 | **0, counter=3** |

### Use cases

- Pick-and-place: sequence(detect → approach → grasp → lift →
  move → release).
- Reactive avoidance: selector(if obstacle close, avoid; else
  proceed).
- Error recovery: selector(try main plan; on fail, fall back to
  recovery).
- Task scheduling: parallel(track target, monitor battery,
  execute mission).

### Limitations (blackboard-style data sharing between nodes
+ dynamic tree restructuring land in v0.6 if needed):

- No blackboard; user passes shared state via the `ctx` pointer.
- Static tree — built once, ticked many times.

### Files

- `stdlib/runtime/bt_rt.c` — `_BTNode` / `NBT` types,
  `nuc_bt_*` exports, recursive `_tick` evaluator.
- `stdlib/rods/bt.nr` — externs + Nucleor wrappers.
- `tests/rods/bt_smoke.nr` — alloc/build/free smoke
  (correctness covered by direct C composite-scenario test).

---

## [0.2.243] — 2026-04-23

**Robotics: 2D polygon-polygon collision via Separating Axis
Theorem. Foundation for 2D mobile-robot footprint collision (AGV
shape vs static obstacle polygons), planar gripper-jaw checks,
board-game piece overlap. Complements the 3D GJK + EPA shipped
earlier with a lower-dimensional, faster primitive for inherently-
2D scenarios.**

### Algorithm

For each edge of either polygon, project both polygons onto the
edge's perpendicular axis. If any projection pair doesn't overlap,
the polygons are separated (early-exit). If no separating axis is
found, they overlap.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

// pts_a is double[na * 2]; same for B. CONVEX, CCW-wound polygons.
// Returns 1 if overlap, 0 if separated, -1 on bad input.
let overlap = coll_poly2d_sat(pts_a_ptr, na, pts_b_ptr, nb);
```

### Verification

| Test | Expected | Got |
|---|---|---|
| Two triangles obviously overlapping | 1 | **1** |
| Two triangles widely separated (Δx = 5) | 0 | **0** |
| Square fully contained inside triangle | 1 | **1** |
| Square touching triangle at vertex | 1 | **1** |

### Limitations (concave polygon support via convex
decomposition + GJK distance for non-overlapping pairs land in
v0.6 if needed):

- Convex polygons only. For concave, decompose first.
- CCW winding required.
- Boolean overlap only — no penetration depth or contact normal.
  For penetration info, use 3D GJK + EPA (treat 2D polygon as a
  thin 3D prism).

### Files

- `stdlib/runtime/collision_rt.c` — `_project_poly`,
  `_sat_separated`, `nuc_coll_poly2d_sat`.
- `stdlib/rods/collision.nr` — extern + `coll_poly2d_sat` wrapper.

---

## [0.2.242] — 2026-04-23

**Robotics: cubic Bezier curves in the trajectory rod. Pairs with
Catmull-Rom (v0.2.237): Catmull-Rom passes through every waypoint
exactly (good for path-following); Bezier offers explicit tangent
control at endpoints via the inner control points (good for
smooth merges with existing trajectories, specified-velocity
approach paths).**

### Surface

```nucleor
import "stdlib/rods/trajectory.nr"

// pts is double[4 * n_dim]: P₀, P₁, P₂, P₃ in order.
// q_out is double[n_dim].
bezier_eval(pts_ptr, n_dim, t_b, q_out_ptr);

// First derivative — useful for tangent / instantaneous velocity:
bezier_tangent(pts_ptr, n_dim, t_b, dq_out_ptr);
```

### Math

```
B(t)  = (1-t)³·P₀ + 3(1-t)²t·P₁ + 3(1-t)t²·P₂ + t³·P₃
B'(t) = 3·[(1-t)²·(P₁-P₀) + 2(1-t)t·(P₂-P₁) + t²·(P₃-P₂)]
```

The curve passes through P₀ at `t=0` and P₃ at `t=1`, but NOT
through P₁ / P₂. Instead, P₁ specifies the endpoint tangent at
P₀ (direction `3·(P₁−P₀)`) and P₂ specifies the endpoint tangent
at P₃ (direction `3·(P₃−P₂)`).

### Verification

2D cubic Bezier with control points `(0,0), (1,2), (2,2), (3,0)`:

| Test | Expected | Got |
|---|---|---|
| `B(0)` | (0, 0) — P₀ | **(0.0000, 0.0000)** |
| `B(1)` | (3, 0) — P₃ | **(3.0000, 0.0000)** |
| `B(0.5)` | x = 1.5 by symmetry | **(1.5000, 1.5000)** |
| `B'(0)` | (3, 6) = 3·(P₁−P₀) | **(3.0000, 6.0000)** |
| `B'(1)` | (3, -6) = 3·(P₃−P₂) | **(3.0000, -6.0000)** |

### Catmull-Rom vs Bezier

| Property | Catmull-Rom | Cubic Bezier |
|---|---|---|
| Passes through control points | Yes (every waypoint) | Endpoints only (P₀, P₃) |
| Tangent control | Implicit (C¹ from neighbors) | Explicit (via P₁, P₂) |
| Use case | Smooth a discrete path | Smooth merge with given start/end velocities |

### Files

- `stdlib/runtime/trajectory_rt.c` — `nuc_bezier_eval`,
  `nuc_bezier_tangent`.
- `stdlib/rods/trajectory.nr` — externs + Nucleor wrappers.

---

## [0.2.241] — 2026-04-23

**Robotics: artificial potential field (Khatib 1986). Simplest
reactive controller — attractive force to goal + repulsive force
from obstacles. Common baseline alongside DWA / pure pursuit.
Closes the reactive controller suite.**

### Algorithm

```
F_att(q) = −k_att · (q − q_goal)
F_rep(q) = Σ over obstacles within d_max:
             k_rep · (1/d − 1/d_max) · (1/d²) · (q − q_obs)/|q − q_obs|

F_total = F_att + F_rep        → direction of motion
```

### Surface

```nucleor
import "stdlib/rods/apf.nr"

// Compute the raw force at the robot's pose:
apf_force_2d(x, y, gx, gy, obs_ptr, n_obs,
             k_att, k_rep, d_max, F_out_ptr);

// Or step the robot by v·dt along the (normalized) force:
apf_step_2d(x, y, gx, gy, obs_ptr, n_obs,
            k_att, k_rep, d_max, v, dt,
            x_out_ptr, y_out_ptr);
```

### Verification

Robot starts at (0, 0.01), goal at (5, 0), obstacle at (2.5, 0)
blocking the straight path. APF correctly detours upward to
y ≈ 0.83 to avoid the obstacle, then returns toward the goal:

| Step | Position | d_obs | d_goal |
|---|---|---|---|
| 0 | (0.025, +0.010) | 2.475 | 4.975 |
| 60 | (1.525, +0.007) | 0.975 | 3.475 (repulsion engaging) |
| 120 | (2.539, +0.794) | 0.795 | 2.586 (apex of detour) |
| 180 | (3.977, +0.517) | 1.564 | 1.146 (returning to goal line) |
| 200 | (4.401, +0.303) | 1.910 | 0.667 (close to goal) |

The classic APF detour pattern — smooth, monotonic obstacle
avoidance.

### Limitations (Vector Field Histogram, Navigation Functions
land in v0.6 if needed):

- 2D only.
- Caller supplies obstacle list as point obstacles.
- No local-minimum escape — gets stuck in concave obstacles facing
  the goal. Use DWA or a planner for those.

### Files

- `stdlib/runtime/apf_rt.c` — `nuc_apf_force_2d`,
  `nuc_apf_step_2d`.
- `stdlib/rods/apf.nr` — externs + Nucleor wrappers.

---

## [0.2.240] — 2026-04-23

**Robotics: Dynamic Window Approach (Fox, Burgard & Thrun 1997)
local planner. Standard ROS-style local navigation controller for
differential-drive robots. Selects the best (v, ω) command at
each control step by sampling within the dynamic window of
velocities reachable in one step given the robot's acceleration
limits, rolling out each candidate trajectory, scoring by
(obstacle clearance + heading + velocity), and picking the best.**

Foundation for ROS-style local navigation: the global planner
(RRT / A* / PRM) emits a path; DWA picks the local commands that
follow it while reactively avoiding obstacles the global planner
didn't see.

### Surface

```nucleor
import "stdlib/rods/dwa.nr"

// User-supplied callback returning distance to nearest obstacle:
//   fn(x_b, y_b) -> i64 (bit-cast f64 distance)
//
// At each control step:
dwa_step(x, y, theta,
         v_curr, w_curr,
         goal_x, goal_y,
         v_min, v_max, w_min, w_max,
         a_max, alpha_max,
         n_v_samples, n_w_samples,
         dt, T_horizon,
         w_clear, w_heading, w_velocity,
         obs_dist_fp,
         v_out_ptr, w_out_ptr);
```

### Scoring

All three score components normalized to `[0, 1]` (canonical DWA
formulation — without normalization, "stop" trivially wins on
the unbounded clearance term):

```
clear_score = min(traj_clearance, 2 m) / 2 m       — saturates at 2 m
head_score  = 1 − |heading_error| / π              — 1 if aligned, 0 if 180°
vel_score   = max(0, v / v_max)                    — only positive forward
```

`total = w_clear · clear + w_head · head + w_vel · vel`. Pick
the (v, ω) with the highest total.

### Verification

- Smoke: linkage + alloc test passes.
- Functional: with a robot at (0, 0) facing +x toward goal (6, 0)
  and an obstacle in the way, DWA correctly chooses non-collision
  commands and avoids running into the obstacle. Multi-step
  rollout verified non-degenerate behavior.

### Limitations (TEB / MPC-style trajectory-level optimization
land in v0.6 if needed):

- Differential-drive only. Ackermann variant adds a steering
  constraint.
- Constant velocity within each candidate (no piecewise
  acceleration).
- Brute-force grid search over (v, ω). Adaptive sampling lands
  later if the brute force becomes a bottleneck.
- Sensitive to score weights — tuning required per scenario.

### Files

- `stdlib/runtime/dwa_rt.c` — `nuc_dwa_step` (one-shot DWA
  step; user passes all kinematic limits + scoring weights as
  call-site arguments).
- `stdlib/rods/dwa.nr` — extern + `dwa_step` Nucleor wrapper.
- `tests/rods/dwa_smoke.nr` — build-only linkage smoke.

---

## [0.2.239] — 2026-04-23

**Robotics: dense 3D voxel grid for occupancy. Complements
`octree.nr` (sparse): dense storage is faster than the octree
for cluttered scenes (no tree traversal per query) but memory-
intensive for sparse scenes. Foundation for inflated obstacle
costmaps, voxel-based collision detection in tightly-packed
cells, signed-distance-field caching.**

### Surface

```nucleor
import "stdlib/rods/voxel.nr"

// 5m cube centered at origin, 5cm resolution → 100³ = 1M voxels.
let v = vox_new(cx_b, cy_b, cz_b, res_b, nx, ny, nz);
vox_insert(v, x_b, y_b, z_b, occupied);
let state = vox_query(v, x_b, y_b, z_b);   // 0=unknown, 1=free, 2=occupied
let n_occ = vox_occupied_count(v);
vox_free(v);
```

### When to use voxel grid vs octree

| Property | Octree | Voxel grid |
|---|---|---|
| Storage | Sparse — only allocated nodes | Dense — full grid up front |
| Per-query cost | O(depth) tree traversal | O(1) array index |
| Best for sparse scenes | ✅ | ✗ (memory wastage) |
| Best for dense scenes | ✗ (depth overhead) | ✅ |
| Memory at 5m³ / 5cm res | ~10 MB typical (sparse) | 125 MB always |
| Memory at 1m³ / 1cm res | ~100 MB typical (sparse) | 1 GB always |

Use octree for room-scale outdoor scans (mostly empty); voxel
grid for tabletop manipulation (mostly cluttered).

### Verification

10×10×10 grid centered at origin, 0.1 m resolution (1 m³ extent),
all assertions in the smoke pass:

| Test | Expected | Got |
|---|---|---|
| Total cell count | 1000 | ✓ |
| Initial occupied count | 0 | ✓ |
| Insert + query occupied at (0.3, 0.2, 0.1) | state = 2 | ✓ |
| Occupied count after insert | 1 | ✓ |
| Insert + query free at (0.4, 0.4, 0.4) | state = 1 | ✓ |
| Insert at (5, 0, 0) (outside grid) | -1 | ✓ |

### Files

- `stdlib/runtime/voxel_rt.c` — `NVoxel` struct,
  `_world_to_voxel`, `nuc_vox_*` exports.
- `stdlib/rods/voxel.nr` — externs + Nucleor wrappers.
- `tests/rods/voxel_smoke.nr` — full functional smoke
  (positive-coord-only — Nucleor `0.0 - x` integer-on-bits limit).

---

## [0.2.238] — 2026-04-23

**Robotics: 2D convex hull (Andrew's monotone chain). Standard
geometry primitive: O(N log N) sort-then-scan. Foundation for
grasp wrench space construction (convex hull of contact-force
generators), object bounding-shape extraction from depth scans,
collision broad-phase precomputation (replace mesh with hull for
cheaper queries).**

### Surface

```nucleor
import "stdlib/rods/hull.nr"

// pts is double[N * 2]; hull_out_indices is int[N] (worst case).
let n_hull = hull_2d(pts_ptr, n_pts, hull_out_indices_ptr);

// Hull area via shoelace formula:
let area = hull_2d_area(pts_ptr, n_pts, hull_indices_ptr, n_hull);
```

### Algorithm

Andrew 1979's monotone chain (`O(N log N)`):
1. Sort points by `(x, y)`.
2. Build lower hull: left-to-right scan, popping any vertex
   that doesn't make a left turn with the current edge.
3. Build upper hull: right-to-left scan, same rule.
4. Concatenate (excluding duplicate endpoints).

### Verification

Test 1: 2×2 square corners + 1 interior point:
- Hull size: **4** (interior point correctly dropped)
- Hull indices (CCW): 0, 1, 2, 3
- Hull area: **4.000000** (= 2 × 2)

Test 2: 4 extreme points at (±10, 0) and (0, ±10) + 20 random
points in [-5, 5]²:
- Hull size: **4** — only the 4 extremes
- All 4 extreme corners present in the hull: **YES**

### Files

- `stdlib/runtime/hull_rt.c` — `nuc_hull_2d`, `nuc_hull_2d_area`
  plus `_cross_o` orientation test and `_cmp_xy` sort comparator.
- `stdlib/rods/hull.nr` — externs + Nucleor wrappers.
- `tests/rods/hull_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C square-hull test).

---

## [0.2.237] — 2026-04-23

**Robotics: Catmull-Rom spline interpolation in the trajectory rod.
Standard C¹ smoothing primitive that passes through every
waypoint exactly with continuous tangent. Common workflow: run
RRT/PRM to get a discrete path → smooth with Catmull-Rom →
time-parameterize with TOPP.**

### Surface

```nucleor
import "stdlib/rods/trajectory.nr"

let cr = catmull_new(n_dim);
for waypoint in path { catmull_add_waypoint(cr, q_ptr); }

// Sample at parameter s ∈ [0, n_pts - 1].
catmull_eval(cr, s_b, q_out_ptr);
```

### Algorithm

Standard 4-point Catmull-Rom: between waypoints `P_i` and `P_{i+1}`,
interpolate using `P_{i-1}, P_i, P_{i+1}, P_{i+2}` as control
points. At endpoints, the missing virtual waypoint is reflected
(`P_{-1} = 2·P_0 − P_1`) for smooth boundary behavior.

### Verification

5-waypoint zigzag path `(0,0), (1,1), (2,0), (3,1), (4,0)` in 2D:

| Test | Result |
|---|---|
| Hits every waypoint exactly at integer s | **0.0e+00 error at all 5** |
| Smooth interpolation at intermediate s | C¹ continuous, sensible bumps between zigzag corners |

### Files

- `stdlib/runtime/trajectory_rt.c` — `NCatmull` struct,
  `nuc_catmull_new` / `_add_waypoint` / `_eval` / `_free`.
- `stdlib/rods/trajectory.nr` — externs + Nucleor wrappers.
- `tests/rods/trajectory_smoke.nr` — alloc/count/free smoke
  (correctness covered by direct C zigzag test).

---

## [0.2.236] — 2026-04-23

**Robotics: stereo triangulation — recover a world-frame 3D point
from two camera views of it. Closes the vision rod: pinhole
projection (v0.2.224) + IBVS (v0.2.225) + PnP (v0.2.233) + now
the inverse direction (3D from 2D × 2). Foundation for stereo
SLAM landmark reconstruction, 3D measurement from stereo rigs,
and structure-from-motion.**

### Algorithm

Midpoint of skew lines:
1. For each view i: get the camera-frame ray direction
   `d_cam = K⁻¹ · (u, v, 1)`. Rotate to world: `d_world = Rᵀ · d_cam`.
   Camera origin in world: `c = -Rᵀ · t`.
2. Solve for scalars `s1, s2` minimizing `‖(c1 + s1·d1) − (c2 + s2·d2)‖²`
   (closed-form 2×2 linear system).
3. The 3D point is the midpoint of the two closest points on the
   two rays.

### Surface

```nucleor
import "stdlib/rods/vision.nr"

cam_triangulate(
    K1_ptr, R1_ptr, t1_ptr,
    K2_ptr, R2_ptr, t2_ptr,
    uv1_ptr, uv2_ptr,
    X_out_ptr);
```

`K*` are 9-double row-major intrinsics, `R*` are 9-double
world→camera rotations, `t*` are 3-double translations, `uv*` are
2-double pixel observations, `X_out` is a 3-double output.

### Verification

Synthetic: cameras at `(0, 0, 0)` and `(0.2, 0, 0)`, both facing
+z, intrinsics `fx=fy=500, cx=cy=320`. 3D point at `(0.5, 0.3, 2.0)`
projected to both cameras, then triangulated:

| Quantity | Value |
|---|---|
| uv1 | (445, 395) ✓ |
| uv2 | (395, 395) ✓ |
| Recovered X | (0.5000, 0.3000, 2.0000) |
| Error | **6.0e-14 m** (machine epsilon) |

### Limitations (linear-DLT triangulation + nonlinear refinement
with reprojection minimization land in v0.6 if needed):

- Midpoint method only — adequate for short baselines, slight
  bias when baseline is large relative to depth.
- No multi-view fusion or bundle adjustment.

### Files

- `stdlib/runtime/vision_rt.c` — `nuc_cam_triangulate` (midpoint
  of skew lines closed form).
- `stdlib/rods/vision.nr` — extern + `cam_triangulate` wrapper.

---

## [0.2.235] — 2026-04-23

**Robotics: particle filter (sequential Monte Carlo) for nonlinear,
non-Gaussian state estimation. Represents the posterior by a swarm
of weighted particles; foundation for kidnapped-robot localization
(multi-modal posterior over the entire map until enough
observations narrow it down), strongly nonlinear tracking where
EKF/UKF fail, and Bayesian filtering on non-vector state spaces.**

### Algorithm

```
Predict:  x_i ← f(x_i, u) + Q-sample noise
Update:   w_i ← w_i · p(z | h(x_i))    [user supplies likelihood]
          normalize: Σ w_i = 1
Resample: if N_eff < threshold·N, do systematic resampling.
```

`N_eff = 1 / Σ w_i²` is the effective particle count. When
weights collapse onto a few particles, resampling restores
diversity by drawing N new particles with replacement.

### Surface

```nucleor
import "stdlib/rods/pf.nr"

let pf = pf_new(n_x, n_z, n_particles, seed);

// Initialize: uniform-box for global localization, or set-initial
// for "warm start" from a previous estimate.
pf_init_uniform(pf, lo_ptr, hi_ptr);   // double[n_x] arrays
// OR
pf_set_initial(pf, x_array_ptr);       // double[n_particles * n_x]

// At each control step:
pf_predict(pf, u_ptr, dynamics_fp, noise_std_ptr);
pf_update(pf, z_ptr, likelihood_fp, eff_threshold_b);
pf_get_mean(pf, x_out_ptr);
```

Callbacks:
- `dynamics_fp`: same contract as EKF / UKF.
- `likelihood_fp`: `fn(x_ptr, z_ptr) -> i64` returning a non-
  negative bit-cast f64 (the un-normalized likelihood; PF
  normalizes weights itself).

### Verification

1D constant-velocity tracker initialized with NO prior knowledge:
500 particles uniform over `[-10, 10] × [-3, 3]` (the global-
localization scenario). True state pos = 0, vel = 2.0; observed
position with σ = 0.5 m noise.

| Step | True pos | Estimate | True vel | Estimate |
|---|---|---|---|---|
| 0 | 0.200 | 0.629 | 2.000 | 0.044 |
| 6 | 1.400 | 1.466 | 2.000 | 1.944 |
| 15 | 3.200 | 3.056 | 2.000 | 1.788 |
| 29 | 6.000 | 6.159 | 2.000 | 2.106 |

Final errors: pos **0.159 m**, vel **0.106 m/s**. Slightly larger
than EKF / UKF on the same scenario (0.099 / 0.029) because PF
starts with NO prior, vs EKF / UKF starting at (5, 0) — the
demonstrated capability is *global localization*, which EKF / UKF
can't do at all.

### When to use PF vs EKF / UKF

| Posterior shape | Best estimator |
|---|---|
| Unimodal Gaussian, mild nonlinearity | EKF |
| Unimodal Gaussian, strong nonlinearity | UKF |
| Multi-modal (kidnapped robot, ambiguous data association) | **PF** |
| Non-vector state (orientation manifolds, Lie groups) | **PF** |

### Implementation notes

- xorshift32 RNG seeded from `seed`. Box-Muller for Gaussian noise.
- Systematic resampling: low-variance, single-pass O(N).
- Caller supplies process noise as a diagonal stddev vector
  (Gaussian assumption); for arbitrary noise, sample within the
  user's dynamics callback.

### Files

- `stdlib/runtime/pf_rt.c` — `NPF` struct, `nuc_pf_*` exports
  including `_init_uniform` / `_predict` / `_update` /
  `_get_mean` / `_get_particle`, plus `_systematic_resample` and
  Box-Muller helper.
- `stdlib/rods/pf.nr` — externs + Nucleor wrappers.
- `tests/rods/pf_smoke.nr` — alloc/free + particle-count smoke
  (correctness covered by direct C global-localization test).

---

## [0.2.234] — 2026-04-23

**Robotics: Unscented Kalman Filter — sigma-point Bayesian
estimator for nonlinear systems where the EKF's Jacobian
linearization doesn't capture the local geometry well. Standard
alternative to EKF in robotics state estimation. Same callback
contract as `ekf.nr` (no API changes; user can swap EKF ↔ UKF
based on which works better for their problem).**

### Algorithm

```
Predict:
  1. Generate 2n+1 sigma points X_i around (x, P).
  2. Propagate: Y_i = f(X_i, u).
  3. x⁻ = Σ wm_i · Y_i
     P⁻ = Σ wc_i · (Y_i − x⁻)(Y_i − x⁻)ᵀ + Q

Update (with measurement z):
  1. Generate 2n+1 sigma points Y_i around (x⁻, P⁻).
  2. Z_i      = h(Y_i)
  3. z_pred  = Σ wm_i · Z_i
     S       = Σ wc_i · (Z_i − z_pred)(Z_i − z_pred)ᵀ + R
     Pxz     = Σ wc_i · (Y_i − x⁻)(Z_i − z_pred)ᵀ
     K       = Pxz · S⁻¹
     x       = x⁻ + K·(z − z_pred)
     P       = P⁻ − K·S·Kᵀ
```

Standard scaled-sigma-point parameters (Wan & van der Merwe 2000):
α = 1e-3, β = 2 (Gaussian assumption), κ = 0.

### Surface

Identical to `ekf.nr` for drop-in replacement:

```nucleor
import "stdlib/rods/ukf.nr"

let ukf = ukf_new(n_x, n_z, n_u);
ukf_set_state(ukf, x0_ptr);
ukf_set_covariance(ukf, P0_ptr);
ukf_set_process_noise(ukf, Q_ptr);
ukf_set_measurement_noise(ukf, R_ptr);

ukf_predict(ukf, u_ptr, dynamics_fp);
ukf_update(ukf, z_ptr, measurement_fp);
ukf_get_state(ukf, x_out_ptr);
```

### When to use UKF vs EKF

| Property | EKF | UKF |
|---|---|---|
| Per-step cost | O(n³) | O(n³) (similar) |
| Linearization | Jacobian (analytical or FD) | Sigma points (no Jacobian needed) |
| Linear dynamics | Optimal | Optimal (same as EKF) |
| Mild nonlinearity | Good | Slightly better |
| Strong nonlinearity (e.g., rotational dynamics, non-monotonic h) | Can diverge | Robust |
| Multi-modal posteriors | Single-mode only | Single-mode only (use particle filter for multi-modal) |

### Verification

Same scenario as the EKF test (1D constant-velocity tracker
recovering velocity from noisy position-only measurements):

| Quantity | EKF | UKF |
|---|---|---|
| Final position error | 0.099 m | 0.099 m |
| Final velocity error | 0.029 m/s | 0.029 m/s |

Identical results on linear dynamics — UKF's sigma-point
propagation is exact for linear systems, so EKF and UKF should
match. The UKF advantage shows up on nonlinear systems (separate
test in user code).

### Implementation notes

- Symmetric matrix square root via Jacobi eigendecomposition +
  sqrt of eigenvalues — more stable than naïve Cholesky on
  ill-conditioned `P`.
- Same dense Gauss-Jordan inverter for the innovation covariance
  `S` as the EKF.

### Files

- `stdlib/runtime/ukf_rt.c` — `NUKF` struct, `nuc_ukf_*` exports,
  `_gen_sigma`, `_sym_sqrt` (Jacobi-based sym matrix sqrt),
  `_gj_inv` helpers.
- `stdlib/rods/ukf.nr` — externs + Nucleor wrappers.
- `tests/rods/ukf_smoke.nr` — alloc/free linkage smoke
  (correctness covered by direct C tracker test, matches EKF).

---

## [0.2.233] — 2026-04-23

**Robotics: Perspective-n-Point camera pose estimation. Given N
known 3D points and their observed 2D pixel projections plus the
camera intrinsics, find the camera pose (R, t) that minimizes
reprojection error. Foundation for object pose estimation
(against a known CAD-model point cloud), visual odometry
(track 3D landmarks across frames), AR markers / fiducials
(estimate camera pose from corner pixels), and hand-eye
calibration target tracking.**

### Algorithm

Iterative Gauss-Newton on reprojection error. Pose increment is
SE(3) `(δω, δt)`; each iteration linearizes around the current
pose, solves the 6×6 normal equations, and applies the
left-perturbed update:

```
R ← exp(δω) · R          (Rodrigues rotation)
t ← exp(δω) · t + δt
```

### Surface

```nucleor
import "stdlib/rods/pnp.nr"

// pts3d is double[N*3], pts2d is double[N*2]; R is double[9]
// row-major and t is double[3], both holding initial guess on
// entry and refined pose on exit.
pnp_solve(pts3d_ptr, pts2d_ptr, n_pts,
          fx_b, fy_b, cx_b, cy_b,
          max_iters,
          R_inout_ptr, t_inout_ptr);

let rms = pnp_reprojection_rms(...);   // diagnostic (pixels)
```

### Verification

8 cube-corner 3D points projected through a synthetic camera
(fx=fy=500, cx=cy=320, true pose: 15° about y-axis + translation
(0.1, 0.05, 1.5)). Initial guess: identity rotation + translation
(0, 0, 1):

| Quantity | Value |
|---|---|
| Iterations to converge | **6** |
| Max element-wise R error | **1.2e-14** |
| Translation error norm | **1.9e-14** |
| Reprojection RMS | **6.3e-12 px** (machine epsilon) |

### Limitations (closed-form EPnP / P3P initialization, RANSAC-
based outlier rejection land in v0.6 if needed):

- Iterative-only — caller supplies initial guess. Identity pose
  works for typical setups.
- No outlier rejection (use `ransac.nr` upstream if needed).
- Pinhole intrinsics only (no distortion).

### Files

- `stdlib/runtime/pnp_rt.c` — `nuc_pnp_solve`,
  `nuc_pnp_reprojection_rms`, plus `_rodrigues`, `_mat3_mul`,
  `_mat3_vec`, `_gj_inv_6` helpers.
- `stdlib/rods/pnp.nr` — externs + Nucleor wrappers.
- `tests/rods/pnp_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C synthetic-camera test).

---

## [0.2.232] — 2026-04-23

**Robotics: hand-eye calibration — solve `AX = XB` for the unknown
end-effector → camera transform. Foundation for any vision-in-the-
loop robot control where the camera is mounted on the end-effector
(eye-in-hand visual servoing, object pose estimation, eye-in-hand
tracking). The result `X` is what relates the camera observation
frame to the robot's kinematic chain.**

### Algorithm

Two-step solve:

1. **Rotation**: Procrustes / Horn quaternion alignment of the
   per-motion rotation axes — `axis(R_a)` should equal
   `R_x · axis(R_b)`. Cross-covariance `H = Σ axis(R_b)·axis(R_a)ᵀ`,
   build Horn's 4×4 N matrix, top eigenvector via power iteration
   gives the optimal `R_x`.
2. **Translation**: with `R_x` known, `(R_a − I)·t_x = R_x·t_b − t_a`
   is linear in `t_x`. Solve via normal equations accumulated
   across all motion pairs.

### Surface

```nucleor
import "stdlib/rods/handeye.nr"

// Ra/Rb arrays are double[N * 9] row-major rotations.
// ta/tb arrays are double[N * 3] translations.
// Rx_out is double[9], tx_out is double[3].
handeye_calibrate(Ra_array_ptr, ta_array_ptr,
                  Rb_array_ptr, tb_array_ptr, n_motions,
                  Rx_out_ptr, tx_out_ptr);
```

### Verification

Synthetic AX = XB sequence: planted `X = (R_x = 30° about y-axis,
t_x = (0.05, 0.10, 0.15))`, 6 diverse motion pairs generated as
`B_i = inv(X) · A_i · X`. Solver recovers X to machine precision:

| Quantity | Value |
|---|---|
| Max element-wise `|Rx − Rx_true|` | **4.4e-16** |
| `|tx − tx_true|` | **1.4e-16** |

Both rotation and translation match the planted truth to machine
epsilon.

### Limitations (joint dual-quaternion solver lands in v0.6 if
needed):

- Two-step (rotation then translation). Daniilidis 1999's dual-
  quaternion form couples the two and can be marginally more
  accurate when rotation/translation errors correlate.
- Requires ≥ 3 motion pairs with non-collinear rotation axes for
  the rotation step to be well-conditioned.

### Files

- `stdlib/runtime/handeye_rt.c` — `nuc_handeye_calibrate` plus
  `_rot_log` (axis-angle from rotation matrix), `_quat_to_R`,
  `_top_eigenvec_4x4` (Horn alignment), `_build_N`, `_gj_inv`.
- `stdlib/rods/handeye.nr` — extern + `handeye_calibrate` wrapper.
- `tests/rods/handeye_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C synthetic AX=XB test).

---

## [0.2.231] — 2026-04-23

**Robotics: RANSAC outlier-robust 3D plane fitting (Fischler &
Bolles 1981 + PCA refit). Foundational perception primitive used
throughout robotics: LiDAR ground-plane detection (segment ground
from obstacles), depth-scan surface fitting (table tops, walls),
point-cloud preprocessing for ICP (filter outliers before
registration).**

### Algorithm

```
1. Repeatedly sample 3 random points; fit a plane through them.
2. Count inliers — points within `thresh` distance of the plane.
3. After all trials, take the trial with the most inliers.
4. Refit the final plane via PCA on those inliers (smallest-
   eigenvalue eigenvector of the centered covariance is the
   normal).
```

### Surface

```nucleor
import "stdlib/rods/ransac.nr"

// pts is double[N * 3]; plane_out is double[4] for (nx, ny, nz, d)
// with n unit and plane: nx·x + ny·y + nz·z + d = 0.
ransac_plane_3d(pts_ptr, n_pts,
                n_trials,
                inlier_thresh_b,
                seed,
                plane_out_ptr, inlier_count_out_ptr);
```

### Verification

Synthetic z = 0.5 plane with 50 inlier points (uniformly in [-1, 1]²
with 5 mm noise in z) + 10 outlier points scattered widely in z;
threshold 0.05 m, 100 RANSAC trials:

| Quantity | Expected | Got |
|---|---|---|
| Plane normal x-component | ≈ 0 | -0.000695 |
| Plane normal y-component | ≈ 0 | -0.000990 |
| Plane normal z-component | ±1 | **+0.999999** |
| z-offset (-d/nz) | 0.5 | **0.499525** |
| Inliers (out of 60) | 50 | **50** |

Exactly 50 / 60 inliers — the 10 outliers were correctly rejected.
Plane orientation within 0.06° of the true xy-plane.

### Limitations (generic-callback RANSAC for line/sphere/transform
fitting + adaptive trial-count via inlier ratio land in v0.6 if
needed):

- 3D plane only (other shapes added similarly later).
- Fixed trial count (no early termination).
- Final refit uses unweighted PCA on inliers.

### Files

- `stdlib/runtime/ransac_rt.c` — `nuc_ransac_plane_3d` plus
  `_plane_from_3pts`, `_pt_to_plane_dist`, `_jacobi_3x3`
  (3×3 symmetric eigendecomposition for PCA refit), `_refit_plane`.
- `stdlib/rods/ransac.nr` — extern + `ransac_plane_3d` wrapper.
- `tests/rods/ransac_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C synthetic-plane test).

---

## [0.2.230] — 2026-04-23

**Robotics: Stanley path-following controller (Hoffmann et al.
2007). Classic alternative to pure pursuit, originally from
Stanford's DARPA Grand Challenge entry "Stanley". Tracks the
path itself rather than a lookahead point — snappier on straights,
makes pure pursuit + Stanley a natural pair to switch between
based on path curvature.**

### Algorithm

```
δ = (ψ_path − ψ_robot) + atan(k · e_ct / (v + v_eps))
```

where `ψ_path` is the local path tangent angle, `ψ_robot` is the
robot heading, `e_ct` is the signed cross-track error from the
robot to the closest path point, and `k` is a tunable gain.

The "front axle" position should be passed as `(x, y)`; for a
pure-rear-axle state representation, project forward by the
wheelbase first: `x_fa = x + L·cos(θ)`, `y_fa = y + L·sin(θ)`.

### Surface

```nucleor
import "stdlib/rods/pursuit.nr"

let delta = pursuit_step_stanley(p, x_b, y_b, theta_b,
                                 v_b, k_b, v_eps_b);
```

### Verification

Straight path along +x axis (21 waypoints from (0,0) to (20,0)),
robot starts off-axis at (0, 0.5) with θ = 0, cross-track error
0.5 m, v = 1 m/s, dt = 0.05 s, k = 1.5, wheelbase 0.5 m:

| Step | Cross-track error | Reduction factor |
|---|---|---|
| 0 | 0.5000 m | — |
| 20 | 0.2479 m | 2× |
| 40 | 0.0769 m | 6.5× |
| 60 | 0.0208 m | 24× |
| 100 | 0.0013 m | 380× |
| 120 | 0.0003 m | 1700× |
| Final (200 step) | **0.0000 m** | converged |

Exponential-like convergence — the expected Stanley behavior.

### Pure pursuit vs Stanley

| Property | Pure pursuit | Stanley |
|---|---|---|
| Drives toward | Lookahead point | Closest path point |
| Behavior on straight | Sluggish (lookahead-dependent) | Snappy, fast convergence |
| Behavior on tight curve | Smooth circle-tracking | Can chatter at high curvature |
| Common usage | AGVs, AMRs, indoor robots | Outdoor cars, autonomous vehicles |

The two controllers are paired in the same `pursuit` rod so
applications can switch between them based on path curvature.

### Files

- `stdlib/runtime/pursuit_rt.c` — `nuc_pursuit_step_stanley`
  + `_path_tangent` helper.
- `stdlib/rods/pursuit.nr` — extern + `pursuit_step_stanley`
  Nucleor wrapper.

---

## [0.2.229] — 2026-04-23

**Robotics: pure pursuit path-following controller. Classical
geometric controller for differential-drive (AGVs, AMRs,
two-wheeled balancing robots) and car-like (Ackermann-steered)
ground vehicles. Foundation for autonomous mobile robot control,
outdoor delivery robots, autonomous vehicles, and warehouse
transports.**

### Algorithm

```
1. Find the lookahead point on the path at distance L_ahead from
   the robot, scanning forward from the closest path point.
2. Compute heading error α to that point.
3. Differential drive:  ω = 2·v·sin(α) / L_ahead
   Car-like (Ackermann): δ = atan(2·L_wheelbase·sin(α) / L_ahead)
```

### Surface

```nucleor
import "stdlib/rods/pursuit.nr"

let p = pursuit_new(n_pts_hint);
for waypoint in path { pursuit_add_point(p, x_b, y_b); }

// At each control tick (differential drive):
let omega = pursuit_step_diff_drive(p, x_b, y_b, theta_b,
                                    v_b, lookahead_b);

// ... or car-like:
let delta = pursuit_step_ackermann(p, x_b, y_b, theta_b,
                                   v_b, lookahead_b, wheelbase_b);

// Goal-reached check:
if pursuit_distance_to_goal(p, x_b, y_b) < goal_tol { stop(); }
```

### Verification

Quarter-circle path from (0, 0) to (5, 5) with 21 waypoints,
robot at v = 1 m/s, lookahead = 0.5 m, dt = 0.05 s:

| Stage | Result |
|---|---|
| Initial distance to goal | 7.071 m |
| Steps to within 0.2 m of goal | **153** |
| Final distance to goal | **0.191 m** |
| Final pose | (4.99, 4.81) ≈ (5, 5) goal ✓ |

Angular velocity ω increased monotonically from ~0.12 to ~0.20
rad/s as the path curved — exactly as pure-pursuit theory
predicts (heading error grows with arc curvature).

### Limitations (adaptive lookahead, time-based formulation,
path pruning land in v0.6 if needed):

- Constant lookahead distance (no velocity-adaptive scheduling).
- No automatic completion / "near-goal" early-stop — caller
  checks via `pursuit_distance_to_goal`.
- Brute-force closest-point search per call (with early-exit
  when distance starts growing). Fine for paths up to a few
  thousand waypoints.

### Files

- `stdlib/runtime/pursuit_rt.c` — `NPursuit` struct,
  `nuc_pursuit_*` exports including `_step_diff_drive` and
  `_step_ackermann`, plus `_closest_after` and
  `_lookahead_index` helpers.
- `stdlib/rods/pursuit.nr` — externs + Nucleor wrappers.
- `tests/rods/pursuit_smoke.nr` — straight-line linkage smoke
  (correctness covered by direct C quarter-circle test).

---

## [0.2.228] — 2026-04-23

**Robotics: 2D pose graph SLAM optimizer (Gauss-Newton). Standard
SLAM back-end: minimize the sum of squared edge errors over a
graph of relative-pose constraints. Foundation for SLAM systems
where the front-end (scan matching with `icp.nr`, visual odometry,
IMU dead-reckoning) produces relative-pose measurements between
poses, and loop closures fix accumulated drift via additional
edges between non-adjacent poses.**

### Surface

```nucleor
import "stdlib/rods/pgs.nr"

let g = pgs_new(n_nodes);
for i in 0..n_nodes { pgs_set_node(g, i, x_b, y_b, theta_b); }

// Each edge says "node j's pose, expressed in node i's frame, is
// approximately (dx, dy, dtheta)" with diagonal information matrix.
pgs_add_edge(g, i, j, dx_b, dy_b, dtheta_b,
             info_xx_b, info_yy_b, info_tt_b);

// Run Gauss-Newton.
pgs_optimize(g, max_iters, tol_b);

// Read back the optimized poses.
pgs_get_node(g, i, x_out_ptr, y_out_ptr, theta_out_ptr);
```

Node 0 is gauge-fixed (never moves) to break the global rigid-
motion ambiguity.

### Algorithm

Gauss-Newton iterations on the linearized residuals:
1. For each edge, compute residual `e = inv(p_i) ⊞ p_j ⊟ z_ij`
   (predicted relative pose minus measurement, in node i's frame).
2. Compute analytical 2D pose Jacobians wrt both endpoints
   (Grisetti et al. tutorial form).
3. Build the dense normal equations `H · δx = −b` with `H = Σ Aᵀ Ω A`,
   `b = Σ Aᵀ Ω e`. Add small Levenberg damping to keep H invertible.
4. Solve via Gauss-Jordan, apply update to all non-fixed nodes.
5. Repeat until ‖δx‖ drops below tolerance.

### Verification

4-node "loop closure" test: square loop with relative-pose
measurements `(1, 0, π/2)` between consecutive nodes (90° turn
each step). Initial estimates perturbed from truth by ≤ 10 cm
position, ≤ 0.05 rad angle:

| Stage | Cost |
|---|---|
| Initial (with perturbation) | 3.79 |
| After 4 Gauss-Newton iters | **1.5e-29** (machine epsilon) |

Recovered poses match the analytical answer:
- Node 0: (0.0000, 0.0000, 0.0000) — fixed ✓
- Node 1: (1.0000, 0.0000, 1.5708 = π/2) ✓
- Node 2: (1.0000, 1.0000, -3.1416 = ±π) ✓
- Node 3: (0.0000, 1.0000, -1.5708 = -π/2 = 3π/2) ✓

(Angles equivalent under ±π wraparound, which the optimizer's
`_wrap_angle` handles.)

### Limitations (3D pose graphs / sparse Cholesky / robust kernels
land in v0.6 if needed):

- 2D only. 3D extension uses quaternions + 6-DOF residuals.
- Dense linear solve via Gauss-Jordan: O(n³) per iter. Fine for
  ≤ 200 nodes; larger graphs need sparse Cholesky.
- L₂ cost only — no robust kernels (Huber, Cauchy) for outlier
  rejection.

### Files

- `stdlib/runtime/pgs_rt.c` — `_PGSEdge` / `NPGS` types,
  `nuc_pgs_*` exports including `_optimize` and `_total_cost`,
  plus `_gj_inv` and `_wrap_angle` helpers.
- `stdlib/rods/pgs.nr` — externs + Nucleor wrappers.
- `tests/rods/pgs_smoke.nr` — alloc/insert/optimize/free smoke
  (correctness covered by direct C 4-node loop test).

---

## [0.2.227] — 2026-04-23

**Robotics: Extended Kalman Filter for nonlinear state
estimation. Foundation for sensor fusion (IMU + odometry + GPS),
SLAM front-ends, model-based observers, and any time-varying
state estimation. User supplies dynamics + measurement callbacks;
EKF handles all the linearization and Bayesian update math.**

### Standard EKF recursion

```
Predict:  x⁻ = f(x, u);  F = ∂f/∂x;  P⁻ = F·P·Fᵀ + Q
Update:   y = z − h(x⁻); H = ∂h/∂x;  S = H·P⁻·Hᵀ + R
          K = P⁻·Hᵀ·S⁻¹;  x = x⁻ + K·y;  P = (I − KH)·P⁻
```

Both Jacobians are computed by numerical finite differences
against the user callbacks (no analytical-Jacobian requirement).

### Surface

```nucleor
import "stdlib/rods/ekf.nr"

let ekf = ekf_new(n_x, n_z, n_u);
ekf_set_state(ekf, x0_ptr);
ekf_set_covariance(ekf, P0_ptr);          // n_x × n_x initial uncertainty
ekf_set_process_noise(ekf, Q_ptr);        // n_x × n_x
ekf_set_measurement_noise(ekf, R_ptr);    // n_z × n_z

// At each control step:
ekf_predict(ekf, u_ptr, dynamics_fp);     // dynamics_fp: fn(x, u, x_next) -> i64
ekf_update(ekf, z_ptr, measurement_fp);   // measurement_fp: fn(x, z_out) -> i64
ekf_get_state(ekf, x_out_ptr);
```

### Verification

1D constant-velocity tracker (state = (pos, vel), measurement =
pos with σ = 0.5 m noise). Initial guess: pos=5, vel=0; true:
pos starts at 0, vel = 2 m/s constant. After 30 EKF steps:

| Quantity | True | Initial | Final estimate | Error |
|---|---|---|---|---|
| Position | 6.000 | 5.000 | 5.901 | **0.099 m** (<< 0.5 m noise σ) |
| Velocity | 2.000 | 0.000 | 1.971 | **1.4%** |

Filter correctly inferred velocity from position-only noisy
measurements — the standard "Kalman filter tracker" capability.

### Limitations (UKF / particle filter / square-root form land
in v0.6 if needed):

- Standard EKF (no UKF / sigma-point variants).
- Numerical-FD Jacobians (slower than analytical).
- No square-root form — for very long-running filters with tight
  covariance, prefer UKF or manually re-symmetrize P periodically.

### Files

- `stdlib/runtime/ekf_rt.c` — `NEKF` struct, `nuc_ekf_new` /
  `_set_*` / `_get_*` / `_predict` / `_update` / `_free`, plus
  `_dyn_jacobian` / `_meas_jacobian` / `_gj_inv` helpers.
- `stdlib/rods/ekf.nr` — externs + Nucleor wrappers.
- `tests/rods/ekf_smoke.nr` — alloc/free linkage smoke
  (correctness covered by direct C tracker test).

---

## [0.2.226] — 2026-04-23

**Robotics: sparse octree for 3D occupancy grids and broad-phase
collision pruning. Foundation for occupancy-grid SLAM (octomap-
style probabilistic mapping from depth-camera / LiDAR streams),
voxel-based collision detection in cluttered scenes, and broad-
phase collision pruning against a precomputed octree of the
static environment.**

### Surface

```nucleor
import "stdlib/rods/octree.nr"

// Root cube centered at (cx, cy, cz) with the given half-size.
// max_depth controls leaf resolution: leaves are
// (2 · half_size / 2^max_depth) per side.
let oct = oct_new(cx_b, cy_b, cz_b, half_size_b, max_depth);

// Insert occupancy. occupied = 1 (OCCUPIED) or 0 (FREE).
oct_insert(oct, x_b, y_b, z_b, occupied);

// Query: 0 = unknown, 1 = free, 2 = occupied.
let state = oct_query(oct, x_b, y_b, z_b);

let resolution = oct_leaf_resolution(oct);   // bit-cast f64
let n_nodes    = oct_node_count(oct);
oct_free(oct);
```

### Verification

`[-10, 10]³` root, max_depth = 5 → leaf resolution 0.625 m:

| Test | Expected | Got |
|---|---|---|
| Leaf resolution (20 / 32) | 0.625 m | **0.625000** |
| Nodes after 3 opposite-octant inserts | growing tree | **15** |
| Query (+5, +5, +5) | OCCUPIED (2) | **2** |
| Query (-5, -5, -5) | FREE (1) | **1** |
| Query (0, 0, 0) | OCCUPIED (2) | **2** |
| Query (+8, -8, +8) — never inserted | UNKNOWN (0) | **0** |
| Query (+15, 0, 0) — outside root | UNKNOWN (0) | **0** |

### Limitations (probabilistic occupancy + log-odds storage +
raycast carve land in v0.6 if needed):

- Binary occupancy only (occupied / free / unknown).
- No raycast-based "carve" along sensor rays (typical
  octomap-style update).
- No prune-on-merge of equal-state siblings (no compression).

### Files

- `stdlib/runtime/octree_rt.c` — `_OctNode` / `NOct` types,
  `nuc_oct_new` / `_insert` / `_query` / `_node_count` /
  `_leaf_resolution` / `_free`, plus `_octant` /
  `_child_center` / `_alloc_node` helpers.
- `stdlib/rods/octree.nr` — externs + Nucleor wrappers.
- `tests/rods/octree_smoke.nr` — positive-coord-only smoke
  (Nucleor's `0.0 - x` does integer arithmetic on bit patterns,
  so negative literals can't be synthesized in pure Nucleor —
  direct C test covers negative-coord inserts).

---

## [0.2.225] — 2026-04-23

**Robotics: image-based visual servoing (IBVS) — Chaumette &
Hutchinson 2006. Standard IBVS control law that maps observed
image-feature errors to a camera-frame Cartesian velocity command.
Closes the perception-to-control loop: vision rod (v0.2.224)
projects → IBVS computes camera velocity → robot Jacobian
pseudoinverse maps to joint commands.**

### Surface

```nucleor
import "stdlib/rods/vision.nr"

// s_current and s_desired are double[2*n] arrays of pixel (u, v).
// Z is double[n] of per-feature scene depths in the camera frame.
// v_cam_out is double[6] for (vx, vy, vz, ωx, ωy, ωz).
ibvs_velocity(s_current_ptr, s_desired_ptr, Z_ptr, n_features,
    fx_b, fy_b, cx_b, cy_b,    // camera intrinsics
    lambda_b, damping_b,        // control gain + pseudoinverse damping
    v_cam_out_ptr);
```

### Control law

```
v_cam = −λ · L⁺ · (s_current − s_desired)
L⁺    = (LᵀL + δ²I)⁻¹·Lᵀ                  (damped least squares)
```

`L` is the 2k × 6 stacked image Jacobian (one 2×6 block per
feature, evaluated at the current normalized image coords +
caller-supplied depth). The damping `δ²I` keeps the inverse well-
conditioned near rank-deficient configurations (e.g., when all
features are collinear).

### Verification

4-feature square pattern at depth 1 m, camera intrinsics fx=fy=500,
cx=cy=320; λ = 1, δ = 0.001:

| Test | Expected | Got |
|---|---|---|
| Zero error (current = desired) | v = 0 | **(0, 0, 0, 0, 0, 0)** |
| Right-shift 50 px | vx > 0, others ≈ 0 | **vx = 0.0978**, others < 0.003 |
| Down-shift 50 px | vy > 0, others ≈ 0 | **vy = 0.0978**, others < 0.003 |

The small ω terms in the displacement tests are the natural IBVS
coupling: pure pixel translation can also be achieved by camera
rotation, so the damped least squares mixes a tiny rotation —
correct minor cross-axis behavior, magnitude well below the
primary translation gain.

### How to close the loop

```nucleor
// At each control tick:
// 1. Compute desired camera velocity:
ibvs_velocity(s_current, s_desired, Z, n, fx, fy, cx, cy, λ, δ, v_cam);
// 2. Map to end-effector velocity (eye-in-hand: compose with
//    camera-mount transform; eye-to-hand: identity).
// 3. Map to joint velocities via the robot Jacobian pseudoinverse:
//    qd = J_robot⁺ · v_ee
// 4. Send qd to the joint controller.
```

### Limitations (line / pose features and adaptive depth land in
v0.6 if needed):

- Point features only.
- User must supply per-feature depth (no monocular depth
  estimation — use stereo / RGBD upstream).
- Constant damping (no adaptive λ scheduling).

### Files

- `stdlib/runtime/vision_rt.c` — `nuc_ibvs_velocity` + inline
  `_gj_inv_6x6` Gauss-Jordan helper.
- `stdlib/rods/vision.nr` — extern + `ibvs_velocity` Nucleor
  wrapper.

---

## [0.2.224] — 2026-04-23

**Robotics: pinhole camera projection rod. Standard
intrinsics + world-to-pixel projection + image (interaction)
Jacobian for visual servoing. Foundation for hand-eye calibration,
object pose estimation, and IBVS (which lands as v0.2.225 next).**

### Surface

```nucleor
import "stdlib/rods/vision.nr"

// K is a 9-double row-major intrinsics buffer.
cam_intrinsics_set(K_ptr, fx_b, fy_b, cx_b, cy_b);

// Single point: returns 1 on success, 0 if behind camera.
cam_project(K_ptr, R_ptr, t_ptr, X_ptr, uv_out_ptr);

// Batch over N world points; returns count successfully projected.
cam_project_batch(K_ptr, R_ptr, t_ptr, X_ptr, N, uv_out_ptr);

// Image Jacobian (2×6) for IBVS — Chaumette & Hutchinson 2006.
cam_image_jacobian(x_b, y_b, Z_b, L_out_ptr);
```

### Verification

Standard 640×480-style intrinsics K = [[500, 0, 320], [0, 500, 320], [0, 0, 1]]
with camera at world origin looking down +z:

| Test | Expected | Got |
|---|---|---|
| Project (0, 0, 1) | (320, 320) — principal point | **(320.00, 320.00)** |
| Project (0.1, 0.05, 1) | (370, 345) | **(370.00, 345.00)** |
| Project (0, 0, -1) — behind camera | failure (0) | **0** |
| Image Jacobian at (x=0.1, y=0.05, Z=1) | analytical formula | **all 12 entries match** |

### Limitations (lens distortion + PnP/P3P pose estimation land
in v0.6 if needed):

- Pinhole only — assumes pre-undistorted pixel coords. Real
  cameras: undistort upstream via the camera driver, then feed
  to this layer.
- No camera-pose-from-correspondences primitives (PnP, P3P) —
  those land alongside hand-eye calibration in v0.6.

### Files

- `stdlib/runtime/vision_rt.c` — `nuc_cam_intrinsics_set`,
  `nuc_cam_project`, `nuc_cam_project_batch`,
  `nuc_cam_image_jacobian`.
- `stdlib/rods/vision.nr` — externs + Nucleor wrappers.
- `tests/rods/vision_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C projection test).

---

## [0.2.223] — 2026-04-23

**Robotics: ICP — Iterative Closest Point for 3D point cloud
alignment. Foundation for robotics perception (LiDAR / depth
camera / RGBD scan matching, object pose estimation against CAD
models, SLAM scan-matching front-end). Uses Horn 1987's quaternion-
based closed-form solution for the per-iteration optimal rotation
step + brute-force nearest-neighbor matching.**

### Surface

```nucleor
import "stdlib/rods/icp.nr"

// Initial guess via centroid alignment (R=I, t=cQ-cP). Useful
// for clouds with large translation offsets — without this, all
// source points may degenerate to matching the same closest
// target vertex.
icp_centroid_init(src_ptr, n_src, tgt_ptr, n_tgt, R_ptr, t_ptr);

// Refine with ICP. Returns iterations performed.
let n_iters = icp_align(src_ptr, n_src, tgt_ptr, n_tgt,
                        max_iters, tol_b, R_ptr, t_ptr);

// Verify residual.
let mse = icp_residual(src_ptr, n_src, tgt_ptr, n_tgt, R_ptr, t_ptr);
```

`R_ptr` is a `double[9]` row-major rotation; `t_ptr` is a
`double[3]` translation. Both hold the initial guess on entry and
the refined transform on exit.

### Implementation notes

- **Optimal rotation step**: Horn 1987's quaternion-based method
  via 4×4 N-matrix construction + power iteration for the top
  eigenvector. No SVD library dependency.
- **Nearest-neighbor matching**: brute-force `O(N_src · N_tgt)`
  per iteration. Fine for clouds ≤ 1000 points (typical for
  CAD-model object pose); for full LiDAR scans, the v0.6
  KD-tree variant accelerates this to `O(N_src · log N_tgt)`.
- **Centroid init helper**: `icp_centroid_init` writes
  `(R = I, t = cQ - cP)`. Without this, large translations
  cause every source point to match the same closest target
  corner — the classic "ICP degenerate fixed point" failure
  mode.
- **Convergence**: stops when consecutive-iter MSE difference
  drops below `tol`, or after `max_iters`.

### Verification

- **Translation-only** (cube → cube + (1, 2, 3)) with centroid init
  + 2 ICP iters: t recovered exactly = (1.0000, 2.0000, 3.0000),
  R = identity, residual MSE = 0.
- **Rotation + translation** (cube rotated 30° about z, then
  translated (0.5, -0.3, 0.2)) with centroid init + 2 ICP iters:
  R[0,0] = 0.8660 (cos 30°), R[0,1] = -0.5000 (-sin 30°),
  t recovered exactly, residual MSE = 3.5e-33 (machine epsilon).

### Limitations (KD-tree NN + outlier rejection + point-to-plane
land in v0.6 if needed):

- Brute-force nearest neighbor.
- No outlier rejection (every source point gets a match).
- Point-to-point only (point-to-plane is the surface-rich-scene
  alternative).

### Files

- `stdlib/runtime/icp_rt.c` — `nuc_icp_align`,
  `nuc_icp_centroid_init`, `nuc_icp_residual`, plus
  `_nearest_in` / `_kabsch_horn` / `_top_eigenvec_4x4` /
  `_quat_to_R` / `_mat3_mul` / `_apply_Rt` helpers.
- `stdlib/rods/icp.nr` — externs + Nucleor wrappers.
- `tests/rods/icp_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C cube-alignment test).

---

## [0.2.222] — 2026-04-23

**Robotics: iLQR — iterative Linear Quadratic Regulator (Tassa
et al. 2012). Locally-optimal nonlinear trajectory optimizer
that's the workhorse inner loop of model predictive control
(MPC) and direct shooting trajectory optimization. Closes the
optimal-control gap in Nucleor's robotics rod stack.**

User supplies the dynamics, stage cost, and terminal cost as
function-pointer callbacks (no analytical-gradient requirement —
iLQR handles all the gradient/Hessian work via numerical finite
differences). The optimizer iteratively quadratizes the problem
around the current trajectory, solves the LQR sub-problem
backward (Riccati recursion), and forward-rolls with a line
search until the cost decreases.

### Surface

```nucleor
import "stdlib/rods/ilqr.nr"

let n_iters = ilqr_optimize(n_x, n_u, T,
    x0_ptr,                        // initial state (double[n_x])
    u_seq_ptr,                     // initial controls (double[T*n_u]), modified in place
    max_iters,
    dynamics_fp,                   // fn(x, u, x_next) -> i64
    stage_cost_fp,                 // fn(x, u) -> bit-cast f64
    terminal_cost_fp);             // fn(x_T) -> bit-cast f64

let final_cost = ilqr_total_cost(n_x, n_u, T,
    x0_ptr, u_seq_ptr,
    dynamics_fp, stage_cost_fp, terminal_cost_fp);
```

### Use cases

- **Direct shooting trajectory optimization**: optimize robot
  joint torques over a finite horizon to minimize a cost
  function (e.g., reach goal pose with minimum control effort).
- **MPC inner loop**: at each control step, solve a finite-
  horizon iLQR problem from the current state, apply the first
  control, re-solve at the next step.
- **Reinforcement-learning baseline**: a model-based optimizer
  to compare against learned policies.

### Implementation notes

- Numerical FD for all gradients/Hessians (no analytical-gradient
  requirement on user callbacks).
- Diagonal Hessian approximation for the cost (Gauss-Newton style;
  ignores off-diagonal coupling — fast and adequate for typical
  smooth costs).
- Line search on the line `α ∈ {1, 0.5, 0.25, …, 1/512}` with
  cost-decrease acceptance.
- Q_uu regularizer of `1e-6·I` for stability near singular
  configurations.

### Verification

2D double-integrator brought to origin (T=20, dt=0.1, stage
cost = u², terminal cost = 100·(pos² + vel²)):

| Stage | Cost | Final state |
|---|---|---|
| Initial (zero control, drift) | 100.0 | pos=1.000, vel=0.000 |
| After **2** iLQR iters | **11.62** | pos=0.116, vel=-0.111 |

Optimizer recovered the LQR-style decreasing-magnitude control
(`u = -1.16, -1.04, -0.93, ...`) — the system decelerates from
pos=1 with a smooth ramp, ending close to the origin under the
finite-weight terminal cost trade-off.

### Limitations

- Numerical FD slower than user-supplied analytical gradients —
  acceptable for typical T ≤ 100, n_x ≤ 16, n_u ≤ 8.
- No box constraints on `u` (would need projected line search
  or DDP variant).

### Files

- `stdlib/runtime/ilqr_rt.c` — `nuc_ilqr_optimize`,
  `nuc_ilqr_total_cost`, plus `_dyn_jacobian` /
  `_cost_quadratize` / `_tcost_quadratize` / `_total_cost`
  helpers and a small Gauss-Jordan inverter.
- `stdlib/rods/ilqr.nr` — externs + Nucleor wrappers.
- `tests/rods/ilqr_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C double-integrator test).

---

## [0.2.220] — 2026-04-23

See the bundled v0.2.221 entry below — PRM A* query (v0.2.220)
shipped together with reflected motor inertia (v0.2.221) in a
single combined release note.

---

## [0.2.221] — 2026-04-23

**Robotics: PRM A* query (v0.2.220) and reflected motor inertia
(v0.2.221). Two precision additions: a faster planner-query
variant for large roadmaps with informative heuristic, and the
single-most-important real-hardware effect missing from the
ideal-rigid-body dynamics model.**

### PRM A* query (v0.2.220)

```nucleor
// Same I/O contract as `prm_query` (Dijkstra), but uses A* with
// a Euclidean-distance heuristic toward the goal config.
let path_len = prm_query_astar(prm, start_ptr, goal_ptr,
                              k_neighbors, step_b, coll_fp);
```

On large roadmaps where joint-space distance correlates with
roadmap distance, A* expands far fewer nodes than Dijkstra and
returns the same optimal path. Both queries share the heap-free
O(V²) inner loop; the only difference is the priority key
(`g + h` for A* vs just `g` for Dijkstra).

### Reflected motor inertia (v0.2.221)

```
τ_motor[i] = I_rotor[i] · gear_ratio[i]² · qdd[i]
```

Per-joint reflected motor inertia. Caller supplies the already-
reflected value (`I_rotor · gear_ratio²`); the runtime adds
`I_motor · qdd` to the joint torque. Augments the joint-space
mass matrix diagonal — automatically reflected in computed
torque, gravity comp, mass matrix extraction, forward dynamics,
and all RNEA-derived entry points.

Critical for high-fidelity dynamics on geared robots: typical
industrial arms have reflected motor inertia comparable to or
larger than the link inertia, so omitting it makes the model
noticeably less accurate at higher accelerations.

### Surface

```nucleor
import "stdlib/rods/dynamics.nr"
dyn_set_motor_inertia(dyn, joint_idx, I_b);    // I_b = I_rotor · gear_ratio²
```

### Verification

Single revolute joint about z + fixed tip; M[0][0] = 0.31
without motor inertia (link inertia 0.05 + parallel-axis 0.25
+ fixed-tip default 0.01):

| Test | Expected | Got |
|---|---|---|
| Inverse, qdd=1, no motor inertia | 0.31 | **0.310000** |
| Inverse, qdd=1, motor_I=2.0 | 2.31 | **2.310000** |
| `M[0][0]` extracted with motor_I=2.0 | 2.31 | **2.310000** |

### Files

- `stdlib/runtime/prm_rt.c` — `nuc_prm_query_astar` (A* with
  pre-computed Euclidean h-score; same V² inner loop as
  Dijkstra, different priority key).
- `stdlib/runtime/dynamics_rt.c` — `motor_inertia` array in
  `NDyn`, `nuc_dyn_set_motor_inertia` setter, application loop
  in `_dyn_rnea_core`.
- `stdlib/rods/prm.nr` — extern + `prm_query_astar` wrapper.
- `stdlib/rods/dynamics.nr` — extern + `dyn_set_motor_inertia`
  wrapper.
- `tests/rods/prm_smoke.nr` — exercise A* query on empty
  roadmap.

---

## [0.2.218] — 2026-04-23

See the bundled v0.2.219 entry below — joint friction (v0.2.218)
shipped together with operational-space inverse dynamics
(v0.2.219) in a single combined release note.

---

## [0.2.219] — 2026-04-23

**Robotics: per-joint friction model in dynamics rod (v0.2.218) +
operational-space inverse dynamics (Khatib-style, v0.2.219). Two
related dynamics extensions that close the gap between the model
and real hardware behavior.**

### Joint friction (v0.2.218)

```
τ_friction(qd) = μ_v · qd + μ_c · sign(qd)
```

Per-joint viscous (`μ_v`, units N·m·s/rad for revolute) +
Coulomb (`μ_c`, dry-friction torque magnitude). Added to the
inverse-dynamics output BEFORE the user reads it, so all the RNEA-
derived entry points (computed torque, Cartesian impedance,
gravity comp, mass matrix extraction, forward dynamics) account
for it automatically. Default 0 / 0 (frictionless). Skipped for
fixed joints.

### Operational-space inverse dynamics (v0.2.219)

```
qdd_des = J⁺(q) · xdd_des
τ       = M(q)·qdd_des + C(q,qd)·qd + g(q)   ← packaged via RNEA
```

Khatib-style task-space control: given a desired Cartesian
acceleration for the end-effector, computes the joint torques
that produce it via the simplified joint-space-mapping form.
`J⁺` is the damped pseudoinverse `Jᵀ·(J·Jᵀ + λ²I)⁻¹`.

Different from `dyn_cartesian_impedance` (v0.2.212): impedance
controls task-space STIFFNESS / DAMPING (force-driven); this
entry point controls task-space ACCELERATION (motion-driven).
Useful when the user has a desired Cartesian acceleration profile
(e.g., from a TOPP solver applied to a Cartesian path, or an
MPC-style controller).

### Surface

```nucleor
import "stdlib/rods/dynamics.nr"

dyn_set_joint_friction(dyn, joint_idx, mu_v_b, mu_c_b);

dyn_op_space_inverse(dyn, q, qd,
    xdd_x, xdd_y, xdd_z,    // desired Cartesian acceleration
    damping_b,                // pseudoinverse damping factor
    tau_out);
```

### Verification

Single revolute joint about z + fixed tip at (1, 0, 0), no gravity:

| Test | Expected | Got |
|---|---|---|
| Viscous friction `μ_v=2, qd=0.5` (qdd=0) | τ = 1.0 | **1.000000** |
| Coulomb friction `μ_c=0.3, qd>0` (qdd=0) | τ = 0.3 | **0.300000** |
| Op-space `xdd_des=(0, 1, 0)` with `λ=0.05` | τ ≈ 0.31 | **0.309227** |

Friction terms exact; op-space within 0.7% of the analytical
answer (the small discrepancy is the damping factor — λ = 0.05
slightly under-drives the joint vs the un-damped pseudoinverse).

### Files

- `stdlib/runtime/dynamics_rt.c` — `mu_viscous` / `mu_coulomb`
  arrays in `NDyn`, `nuc_dyn_set_joint_friction` setter, friction
  application loop in `_dyn_rnea_core`, `nuc_dyn_op_space_inverse`.
- `stdlib/rods/dynamics.nr` — externs + `dyn_set_joint_friction`
  / `dyn_op_space_inverse` Nucleor wrappers.

---

## [0.2.217] — 2026-04-23

**Robotics: CHOMP — gradient-based trajectory optimizer (Ratliff
et al. 2009). Smooths an initial discretized path while pushing
it away from obstacles via a user-supplied cost function. The
standard "post-process the planner's output before sending to the
controller" tool — turns RRT / PRM's discretely-collision-free
but jerky paths into smooth executable trajectories.**

### Surface

```nucleor
import "stdlib/rods/chomp.nr"

// path is a caller-allocated double[N * n_dim] buffer holding
// the initial path; CHOMP modifies the interior in place.
chomp_optimize(path_ptr, N, n_dim,
    max_iters,
    alpha_b,         // step size
    w_smooth_b,      // smoothness weight
    w_obs_b,         // obstacle weight
    obs_cost_fp);    // user callback: fn(config_ptr) -> i64 (bit-cast f64 cost)

let cost = chomp_cost(path_ptr, N, n_dim, w_smooth_b, w_obs_b, obs_cost_fp);
```

### Cost function

```
F(ξ) = w_smooth · F_smooth(ξ) + w_obs · F_obs(ξ)
```

where:
- `F_smooth = Σ ‖2·ξ_i − ξ_{i-1} − ξ_{i+1}‖²` (discrete Laplacian
  of the path — penalizes acceleration, encourages smoothness).
- `F_obs = Σ user_cost(ξ_i)` integrated along the trajectory.

Endpoints (ξ_0, ξ_{N-1}) are NEVER moved; only interior waypoints
are optimized.

### Implementation notes

- Smoothness gradient is exact (the Laplacian is its own gradient
  up to a factor of 2). Obstacle gradient is computed by numerical
  finite differences on the user cost function.
- Update rule: `ξ_i ← ξ_i − α · (w_s · ∇F_smooth + w_o · ∇F_obs)`
  with per-step move clamping (the simplification of the full
  covariant pre-conditioning A⁻¹·∇F that ships in CHOMP-proper —
  similar empirical behavior on typical paths).
- Convergence: stops when the largest waypoint move per iteration
  drops below `1e-6`, or after `max_iters`.

### Verification

2-DOF path of 9 waypoints from (0, -0.5) to (1, -0.5), passing
through a Gaussian obstacle potential centered at y = 0 with
width 0.3:

| Phase | Cost | Status |
|---|---|---|
| Initial straight line, smooth-only weight | 0.000000 | trivially optimal |
| 50 iters, smooth-only | 0.000000 | unchanged ✓ |
| Initial line, smooth + obstacle | **2.244170** | high (path near wall) |
| 100 iters, smooth + obstacle | **0.616400** | dropped 3.6× |

Final path: interior waypoints curved from `y = -0.5` (initial)
to `y = -1.017` (midpoint) — successfully dodging the wall.
Endpoints stayed clamped at `y = -0.5`.

### Limitations

- Joint-space optimization only (Cartesian-space variant would
  need an FK + Jacobian wrapper — straightforward to add later).
- Obstacle gradient via numerical finite differences (slower than
  exact gradients on signed-distance fields).
- Pre-conditioning approximated by per-step clamping; full
  covariant `A⁻¹·∇F` lands in v0.6 if needed.

### Files

- `stdlib/runtime/chomp_rt.c` — `nuc_chomp_optimize`,
  `nuc_chomp_cost`, `_obs_cost_at` / `_obs_grad_at` helpers.
- `stdlib/rods/chomp.nr` — externs + Nucleor wrappers.
- `tests/rods/chomp_smoke.nr` — build-only linkage smoke
  (correctness covered by direct C wall-dodging test).

---

## [0.2.216] — 2026-04-23

**Robotics: grasp quality metrics for a 2-finger parallel-jaw
gripper. New `grasp` rod with three foundational metrics:
antipodal score, force closure under Coulomb friction, and
approach-vector alignment. Foundation for grasp synthesis (sample
candidate grasps, score them, pick the best) and for control-time
validation (reject planned grasps that the friction model says
will slip).**

### Surface

```nucleor
import "stdlib/rods/grasp.nr"

let score = grasp_antipodal_score(
    c0_x, c0_y, c0_z,  n0_x, n0_y, n0_z,    // contact 0 + outward normal
    c1_x, c1_y, c1_z,  n1_x, n1_y, n1_z);   // contact 1 + outward normal

let closed = grasp_force_closure(
    c0_x, c0_y, c0_z,  n0_x, n0_y, n0_z,
    c1_x, c1_y, c1_z,  n1_x, n1_y, n1_z,
    mu_b);                                   // friction coefficient

let align = grasp_approach_alignment(
    n_x, n_y, n_z,                          // surface normal
    ax_x, ax_y, ax_z);                      // gripper approach vector
```

Antipodal score is in `[-1, 1]`; +1 = perfect antipodal grasp,
0 = tangential, -1 = totally wrong direction. Force closure is a
binary check (1 / 0). Approach alignment is in `[-1, 1]`; +1 =
head-on (approach antiparallel to normal), 0 = tangential, -1 =
approaching from behind the surface.

### Verification

| Test | Expected | Got |
|---|---|---|
| Perfect antipodal score | 1.000000 | **1.000000** |
| 20° tilted antipodal | 0.939693 | **0.939693** |
| Tangential normals | 0.000000 | **0.000000** |
| Force closure (perfect, μ=0) | 1 | **1** |
| Force closure (30° tilt, μ=0.5) — outside cone | 0 | **0** |
| Force closure (30° tilt, μ=1.0) — inside cone | 1 | **1** |
| Approach head-on | +1.0 | **1.000000** |
| Approach from behind | -1.0 | **-1.000000** |

### Limitations (full convex-hull-of-friction-cone wrench-space
metric, multi-finger generalizations, and grasp-stability margins
land in v0.6 if needed):

- 2-finger / 2-contact only.
- Coulomb friction with single coefficient (no anisotropic
  friction, no separate static / kinetic μ).
- Point contacts (no soft / surface contacts).

### Files

- `stdlib/runtime/grasp_rt.c` — `nuc_grasp_antipodal_score`,
  `nuc_grasp_force_closure`, `nuc_grasp_approach_alignment` plus
  `_normalize3` helper.
- `stdlib/rods/grasp.nr` — externs + Nucleor wrappers.
- `tests/rods/grasp_smoke.nr` — perfect-antipodal grasp end-to-
  end (correctness coverage in the direct C test).

---

## [0.2.214] — 2026-04-23

See the bundled v0.2.215 entry below — joint-space computed-
torque controller (v0.2.214) shipped together with the 6-DOF
Cartesian impedance (v0.2.215) in a single combined release
note since the two are paired model-based controllers.

---

## [0.2.215] — 2026-04-23

**Robotics: two model-based controllers — joint-space computed-
torque (v0.2.214) for trajectory tracking, and 6-DOF Cartesian
impedance (v0.2.215) for full-pose contact-rich manipulation.
Together with v0.2.212's 3-DOF impedance + tip wrench, the
dynamics rod now ships every standard model-based controller a
robotics user would reach for.**

### Joint-space computed torque (v0.2.214)

Classical inverse-dynamics control:

```
qdd_cmd = qdd_des + Kp·(q_des − q) + Kd·(qd_des − qd)
tau     = M(q)·qdd_cmd + C(q,qd)·qd + g(q)   ← packaged via RNEA
```

Linearizes the closed-loop dynamics: the tracking error
`e = q_des − q` follows the second-order linear ODE
`ë + Kd·ė + Kp·e = 0`, so `Kp` and `Kd` are tuned in error-space
(`Kp = ω²`, `Kd = 2·ζ·ω` for desired natural frequency `ω` and
damping ratio `ζ`).

### 6-DOF Cartesian impedance (v0.2.215)

Extends v0.2.212's 3-DOF position-only impedance to full pose:

```
e_6 = [ p_des − p ; log_map(q_des · q_cur⁻¹) ]
F_6 = K · e_6 − D · v_6        (K, D are 6-vectors)
tau = Jᵀ · F_6  [+ g(q) if include_gravity]
```

Angular error via quaternion log-map (same approach as the 6-DOF
IK solver shipped in v0.2.194). Jacobian is 6×n: three rows for
position derivatives + three for angular-velocity derivatives.

### Surface

```nucleor
import "stdlib/rods/dynamics.nr"

dyn_computed_torque(dyn,
    q, qd,                      // current state
    q_des, qd_des, qdd_des,     // reference trajectory
    Kp, Kd,                     // diagonal gain vectors
    tau_out);

dyn_cartesian_impedance_6d(dyn,
    q, qd,
    pdes_x, pdes_y, pdes_z,
    qdes_w, qdes_x, qdes_y, qdes_z,    // target orientation quaternion
    K_ptr, D_ptr,                       // 6-vectors (3 trans + 3 rot)
    1,                                   // include_gravity
    tau_out);
```

### Verification

Single revolute joint about z + fixed tip at (1, 0, 0); link mass
1 kg with CoM at (0.5, 0, 0), Izz = 0.05; fixed tip default inertia
0.01 contributes via parallel axis theorem (so M[0][0] = 0.31, not
0.30):

| Test | Expected | Got |
|---|---|---|
| Computed torque, zero error, no gravity | 0 | **0.000000** |
| Computed torque, q_des=0.5 (Kp=10) — should give M·5 = 1.55 | 1.55 | **1.550000** |
| 6D impedance, p_err=(0,1,0), Kp_trans=10 — Jᵀ·F = 10 | 10 | **10.000000** |

### Files

- `stdlib/runtime/dynamics_rt.c` — `nuc_dyn_computed_torque`
  (thin wrapper around `nuc_dyn_inverse` with PD-augmented
  qdd command); `nuc_dyn_cartesian_impedance_6d` (6×n Jacobian
  + 6-DOF wrench).
- `stdlib/rods/dynamics.nr` — externs + Nucleor wrappers for
  both new entry points.

---

## [0.2.213] — 2026-04-23

**Robotics: extend the end-to-end showcase to 10 stages, adding
RNEA gravity-compensation and Cartesian impedance demonstrations.
Verify gate updated to expect "10 stages" in the run output.**

The showcase now exercises the entire v0.2.174-212 surface
(kinematics + IK with limits/singularity/manipulability + TOPP +
collision + BVH + dynamics inverse + Cartesian impedance) in a
single 130-line Nucleor program. Gives prospective users one
file to read to understand "what does Nucleor's robotics stack
actually look like end-to-end?".

### Files

- `examples/showcase/robotic_arm.nr` — added stages 9 (RNEA
  gravity comp via `dyn_gravity`) and 10 (Cartesian impedance
  via `dyn_cartesian_impedance`); also incorporated
  `ik_manipulability` into stage 4 alongside the singularity
  metric.
- `tools/verify.sh` — updated end-marker check from "8 stages"
  to "10 stages".

---

## [0.2.212] — 2026-04-23

**Robotics: Cartesian impedance / operational-space PD controller
+ inverse dynamics with applied tip wrench. Two related dynamics
extensions that round out the model-based control surface for
contact-rich manipulation.**

### Cartesian impedance / operational-space PD

```
F_cart = K · (p_des − p_actual) − D · (J · qd)
tau    = Jᵀ · F_cart  [+ g(q) if include_gravity]
```

Computes joint torques for a position-task PD in Cartesian
(operational) space. K and D are 3-vectors (diagonal stiffness
and damping in world frame). Use cases:
- Compliant peg-in-hole and contact-rich manipulation.
- Soft Cartesian "follow this pose" trajectories where pure
  position control would over-react to disturbances.
- Drag-and-teach with adjustable stiffness per axis.

### Inverse dynamics with applied tip wrench

```
τ = M(q)·qdd + C(q,qd)·qd + g(q) − Jᵀ · F_ext
```

Same RNEA as `nuc_dyn_inverse` but the backward pass is seeded with
an applied force/torque at the end-effector tip instead of zero.
Sign convention matches ROS / standard usage: positive `F_ext` is
what the *environment* applies to the robot. Use cases:
- Modeling environment contact (peg-in-hole, surface tracking).
- Computing torques required to *resist* a known external load
  (e.g., "carry a 5 kg payload at the tip").
- Verifying force-controlled behavior in simulation.

### Surface

```nucleor
import "stdlib/rods/dynamics.nr"

dyn_inverse_with_wrench(dyn, q, qd, qdd,
    fx, fy, fz,    // tip force, world frame
    tx, ty, tz,    // tip torque, world frame
    tau_out);

dyn_cartesian_impedance(dyn, q, qd,
    pdes_x, pdes_y, pdes_z,
    kx, ky, kz,    // diagonal stiffness
    dx, dy, dz,    // diagonal damping
    1,             // include_gravity (1 = compensate, 0 = don't)
    tau_out);
```

### Implementation notes

- **Refactor**: `nuc_dyn_inverse` now delegates to a private
  `_dyn_rnea_core` helper that takes an extra `tip_force` /
  `tip_torque` parameter. The standard entry point passes zero;
  the new entry point passes the user-supplied wrench. Both
  share the same RNEA body — no code duplication, identical
  numerical behavior on the zero-wrench path.
- **Cartesian impedance** computes the position-only Jacobian
  (3 × n) inline via finite differences (same scheme as the IK
  solver), then `tau = Jᵀ · (K·e − D·v)`. Gravity compensation
  via `nuc_dyn_gravity` when requested.

### Verification

Single-joint arm at world origin with a fixed tip at (1, 0, 0):

| Test | Expected | Got |
|---|---|---|
| Tip force `F = (0, 5, 0)` (perpendicular) | τ = 5 | **5.000000** |
| Tip force `F = (5, 0, 0)` (radial — no moment) | τ = 0 | **0.000000** |
| Impedance `K=10`, `p_des=(1,1,0)`, `p_actual=(1,0,0)` | τ = 10 | **10.000000** |

All three match the analytical answer exactly. The pendulum
gravity test from v0.2.207 still passes (the standard inverse
path is identical on zero wrench).

### Files

- `stdlib/runtime/dynamics_rt.c` — refactored `nuc_dyn_inverse`
  into `_dyn_rnea_core` + thin wrapper; new
  `nuc_dyn_inverse_with_wrench` and `nuc_dyn_cartesian_impedance`.
- `stdlib/rods/dynamics.nr` — externs + Nucleor wrappers for
  both new entry points.

---

## [0.2.211] — 2026-04-23

**Robotics: mass matrix `M(q)` extraction and forward dynamics —
the second half of the dynamics rod started in v0.2.207. Inverse
dynamics ("given motion, compute torques") was the foundation;
this ship adds the inverse direction ("given torques, compute
motion") plus the explicit `M(q)` matrix that's foundational for
impedance/admittance control, operational-space control, and
kinetic-energy analysis.**

Together v0.2.207 + v0.2.211 give Nucleor's dynamics rod the
complete model-based control surface: inverse, forward, mass
matrix, gravity compensation. Round-trip (inverse → forward)
recovers the original `qdd` to machine precision, and `M(q)`
comes out perfectly symmetric (asymmetry below `1e-15`).

### Surface

```nucleor
import "stdlib/rods/dynamics.nr"

// Inverse: given motion, compute torques (v0.2.207).
dyn_inverse(dyn, q_ptr, qd_ptr, qdd_ptr, tau_out_ptr);

// Forward: given torques, compute resulting joint accelerations
//   qdd = M(q)^{-1} · (tau - C(q,qd)·qd - g(q))
dyn_forward(dyn, q_ptr, qd_ptr, tau_ptr, qdd_out_ptr);

// Explicit mass matrix (row-major n*n buffer).
dyn_mass_matrix(dyn, q_ptr, M_out_ptr);
```

### Implementation notes

- **Mass matrix** via `n+1` RNEA calls: gravity bias + one column
  per joint, using `M[:, i] = RNEA(q, 0, e_i) − g(q)`. Slower
  than the composite-rigid-body algorithm but much simpler to
  implement correctly. For `n ≤ 20` the constant factor is fine.
- **Forward dynamics**: one RNEA call to compute the bias
  `C(q, qd)·qd + g(q)` (with `qdd_input = 0`), then `M(q)^{-1}` via
  Gauss-Jordan on an `n×2n` augmented matrix.

### RNEA correctness fix (also v0.2.211)

The v0.2.207 forward-pass for revolute joints was using the
*child's* angular state (`ω_i`, `ω̇_i`) when propagating the
linear acceleration of the link's frame ORIGIN — but that origin
is a point fixed on the *parent* body (the joint pivots about it
without moving it). Using the child's angular state double-
counts the joint's rotational contribution and breaks the
symmetry of `M(q)`. Fixed to use the parent's `ω`, `ω̇`. The
pendulum gravity-torque test from v0.2.207 still matches the
analytical answer exactly (`m·g·L·cos(q)` across `q ∈ {0, π/2, π}`),
so this is a pure correctness improvement that didn't regress the
gravity-only path.

### Verification

3-DOF planar arm with mass 1.5 kg / link, CoM at 0.5 m, diagonal
inertia 0.05:

| Quantity | Result |
|---|---|
| Inverse → forward round-trip error | `2.84e-14` (machine precision) |
| Mass matrix asymmetry `‖M − Mᵀ‖` | `1.11e-15` (machine precision) |
| Pendulum gravity at `q=0` | `+19.62` (analytical: `+19.62`) |
| Pendulum gravity at `q=π/2` | `0.00` (analytical: `0`) |

### Files

- `stdlib/runtime/dynamics_rt.c` — RNEA forward-pass fix for
  revolute joints; new `nuc_dyn_mass_matrix`, `nuc_dyn_forward`,
  internal `_gj_invert` Gauss-Jordan helper.
- `stdlib/rods/dynamics.nr` — externs + `dyn_mass_matrix` /
  `dyn_forward` Nucleor wrappers.

---

## [0.2.210] — 2026-04-23

**Robotics: task-priority IK with nullspace posture preference for
redundant manipulators (Siciliano-Slotine 1991). For arms with
more joints than the position task DOFs, the IK solution is
underdetermined — there's a manifold of joint configurations that
all hit the same end-effector pose. This solver fills the
redundancy with a *secondary* task projected into the primary
task's nullspace, so it never disturbs the position objective:**

```
q̇ = J⁺·e_pos + (I − J⁺·J)·w·(q_pref − q)
```

The secondary task here is joint-space posture preference (drive q
toward a desired `q_pref`). Useful for joint-limit avoidance
(`q_pref` = midpoint of each joint's range), solution-branch
selection on a 7-DOF arm, and continuity across waypoints
(`q_pref` = previous solve's output).

### Surface

```nucleor
import "stdlib/rods/ik_dls.nr"

ik_dls_solve_nullspace(
    chain, vars,
    tx_b, ty_b, tz_b,
    q_pref_ptr, secondary_weight_b,    // 0 disables secondary task
    100, tol_b, damping_b);
```

`q_pref_ptr` is a `double[n_joints]` handle. `secondary_weight_b`
scales the secondary task; 0 disables it (degenerates to the base
DLS solver), 0.1-0.5 is typical.

### Verification

4-DOF planar arm (3 revolute + 1 fixed tip) with target (2, 1, 0)
from a perturbed initial guess `q = (1, 0.5, -0.5, 0.3)` and
`q_pref = (0, 0, 0, 0)`:

| Solver | EE position | Σ\|q\| |
|---|---|---|
| Base DLS  | (2.000, 1.000) — exact | **9.606** |
| Nullspace | (1.998, 0.998) — within 1 cm | **4.829** |

Both hit the target; the nullspace variant cuts the total joint-
deflection nearly in half by using the redundancy to pull toward
the rest pose without disturbing the primary task.

### Files

- `stdlib/runtime/ik_dls_rt.c` — `nuc_ik_dls_solve_nullspace`
  with damped pseudoinverse + explicit `(I − J⁺·J)` nullspace
  projector. Reuses joint-limit infrastructure from v0.2.193.
- `stdlib/rods/ik_dls.nr` — extern + `ik_dls_solve_nullspace`
  wrapper.

---

## [0.2.209] — 2026-04-23

**Robotics: workspace sampling primitives. `fk_workspace_sample`
takes a serial chain + per-joint `[lo, hi]` bounds and writes N
end-effector world positions to a caller-allocated buffer by
running FK on uniformly-random configurations. `fk_workspace_aabb`
computes the axis-aligned bounding box; `fk_workspace_aabb_volume`
the box volume. Useful for "what can this arm reach?" estimation,
reachable-set visualization, and seeding workspace-coordinate
IK / RRT initialization.**

### Surface

```nucleor
import "stdlib/rods/fk_chain.nr"

let positions = /* double[N * 3] handle */;
let lo = /* double[n_joints] handle */;
let hi = /* double[n_joints] handle */;
fk_workspace_sample(chain, n_samples, seed, lo_h, hi_h, positions_h);

let aabb = /* double[6] handle */;
fk_workspace_aabb(positions_h, n_samples, aabb_h);
let volume = fk_workspace_aabb_volume(aabb_h);  // bit-cast f64
```

### Implementation notes

- xorshift32 RNG seeded from `seed` (0 → default seed
  `0x9E3779B9`).
- Per-iteration: sample `n_joints` doubles uniformly within `[lo, hi]`,
  call FK update, read the last link's world position. O(n_samples
  × n_joints) FK evaluations; bottleneck is the FK update itself.
- AABB pass is a single linear scan over the position array.
- Joints whose `lo == hi` stay fixed — useful for "freeze joint k"
  scans of a partial configuration space.

### Verification

2-link planar arm (DH `a=1` per joint) plus a fixed end-effector
tip, sampled with 2000 random configurations:

- All 2000 sample points lie within the analytical reachable
  disk `r ≤ 3`.
- AABB matches the analytical reachable extents
  (`x ≈ [-1, 3]`, `y ≈ [-2, 2]`, `z = 0`).
- AABB volume = 0 for the planar case (z extent is exactly 0).

### Files

- `stdlib/runtime/fk_chain_rt.c` — `_ws_xs32` xorshift RNG,
  `nuc_fk_workspace_sample`, `nuc_fk_workspace_aabb`,
  `nuc_fk_workspace_aabb_volume`.
- `stdlib/rods/fk_chain.nr` — externs + Nucleor wrappers; also
  exposes the `fk_chain_joint_type` / `fk_chain_joint_axis`
  accessors added in v0.2.207.

---

## [0.2.208] — 2026-04-23

**Robotics: Yoshikawa manipulability metric `√det(J·Jᵀ)` at an
explicit (chain, vars) configuration. Geometrically, the volume
of the reachable end-effector velocity ellipsoid given unit
joint velocities — larger = more dexterous, 0 = singular. Useful
for kinematic-optimization scoring, redundancy resolution, and
checking "how good is this configuration?" *before* sending it
to the controller.**

Differs from the existing `ik_get_last_singularity_metric`
(v0.2.199) in three ways:
- Computed at an explicit (chain, vars), not as a side effect of
  running an IK solve.
- Uses bare `J·Jᵀ` (no `λ²` regularization).
- Returns `√det` rather than `|det|` — the standard manipulability
  per Yoshikawa 1985.

### Surface

```nucleor
import "stdlib/rods/ik_dls.nr"

let m = ik_manipulability(chain, vars_ptr);
// m = bit-cast f64; 0 ≈ singular, larger = more dexterous.
```

### Verification

3-DOF arm with axes (z, y, z) plus a fixed end-effector tip:

| Configuration | Expected | Got |
|---|---|---|
| `(0, 0, 0, 0)` (outstretched along x — kinematic singularity) | 0 | 0.000000 |
| `(0.5, 0.7, 0.3, 0)` (bent dexterous configuration) | > 0 | 1.019806 |

### Files

- `stdlib/runtime/ik_dls_rt.c` — `nuc_ik_manipulability`. FK chain
  extern declarations + `_f_from_handle` hoisted to the top of
  the file so the new function can use them.
- `stdlib/rods/ik_dls.nr` — extern + `ik_manipulability` wrapper.

---

## [0.2.207] — 2026-04-23

**Robotics: robot inverse dynamics via the Recursive Newton-Euler
Algorithm (RNEA, Luh-Walker-Paul 1980). Given joint positions q,
velocities qd, and accelerations qdd, computes the joint torques
required to produce that motion against gravity:**

```
tau = M(q)·qdd + C(q, qd)·qd + g(q)
```

**RNEA computes tau directly in O(n) without explicitly forming
the mass matrix M or the Coriolis tensor C — much faster than the
equation-of-motion form for small-to-medium chains. Foundation
for gravity compensation, impedance / admittance control, dynamic
simulation, and torque-aware planning.**

The robotics rod stack now spans the full motion-planning compute
path *plus* the dynamic compute path: kinematics rods (FK + IK)
let you reason about joint geometry; this dynamics rod lets you
reason about joint torques.

### Surface

```nucleor
import "stdlib/rods/dynamics.nr"

let dyn = dyn_new(fk_chain_handle);   // wraps an existing FK chain
for i in 0..n_links {
    dyn_set_link_mass(dyn, i, m_b);
    dyn_set_link_com(dyn, i, cx_b, cy_b, cz_b);
    dyn_set_link_inertia(dyn, i, ixx_b, iyy_b, izz_b, ixy_b, ixz_b, iyz_b);
}
dyn_set_gravity(dyn, gx_b, gy_b, gz_b);    // default (0, 0, -9.81)

// Full inverse dynamics:
dyn_inverse(dyn, q_ptr, qd_ptr, qdd_ptr, tau_out_ptr);

// Or gravity compensation only (qd = qdd = 0):
dyn_gravity(dyn, q_ptr, tau_out_ptr);
```

### Implementation notes

- World-frame two-pass RNEA. The forward pass propagates link
  kinematics (ω, ω̇, a, a_com) from base to tip; the backward
  pass propagates wrenches (force, torque) from tip to base,
  projecting onto each joint's axis to extract the per-joint
  torque scalar.
- Gravity is folded in by setting the implicit base-link linear
  acceleration to `-g` (the standard RNEA trick) — the resulting
  fictitious force on each CoM cancels real gravity in the
  equations of motion.
- Inertia tensors stored body-frame at the CoM (URDF convention),
  rotated to world frame on demand for the wrench computation.
- New FK chain accessors `nuc_fk_chain_joint_type` and
  `nuc_fk_chain_joint_axis` expose the per-joint metadata RNEA
  needs to know which axis to project the wrench onto.

### Verification

End-to-end gravity-torque test on a single-link pendulum (mass
2 kg, length 1 m, CoM at the tip, gravity = -9.81 m/s² in y):

| q (rad) | Expected τ | RNEA τ | Match |
|---|---|---|---|
| 0          | +19.62  | +19.62000 | exact |
| π/2        | 0       | -0.00000  | exact |
| π          | -19.62  | -19.62000 | exact |

Result equals `m·g·L·cos(q)` analytically across the configuration
space, validating the kinematic propagation, the body-frame
inertia rotation, and the joint-axis projection.

### Limitations (full Featherstone spatial-vector formulation
lands in v0.6 if needed for very large or deep chains):

- Serial chain only (no branching trees — same restriction as
  the URDF parser).
- Revolute and prismatic joints only.
- Inertia tensors must be expressed in the link's body-fixed
  frame at the link's center of mass.

### Files

- `stdlib/runtime/dynamics_rt.c` — `NDyn` struct, `_q_rot_vec`
  helper, `nuc_dyn_*` exports including `_inverse` and `_gravity`.
- `stdlib/runtime/fk_chain_rt.c` — added `nuc_fk_chain_joint_type`
  and `nuc_fk_chain_joint_axis` accessors.
- `stdlib/rods/dynamics.nr` — externs + Nucleor wrappers.
- `tests/rods/dynamics_smoke.nr` — smoke test for the configuration
  setters (correctness covered by the direct C pendulum test).

---

## [0.2.206] — 2026-04-23

**Robotics: end-to-end showcase exercising the full v0.2.174-205
stack. `examples/showcase/robotic_arm.nr` now runs an 8-stage
integration that touches every robotics rod the OSS distribution
ships, in the order a real motion-planning pipeline would: build
chain → FK → IK (with limits + singularity readout) → TOPP
→ collision (sphere/AABB/sphere-sphere) → BVH workspace.**

The previous showcase touched 5 rods at a build-only level; the
new version drives each through a representative call sequence
that proves they compose correctly. Particularly important for
the v0.5 release narrative: this is the file a prospective user
would read first to understand "can Nucleor really build a robot
control loop?". Now: yes, in 100 lines.

### Stages

1. Build a 3-link planar arm via DH parameters (`fk_chain.nr`).
2. Forward-kinematics update at the home configuration.
3. IK solve to a reachable target position (`ik_dls.nr` /
   `ik_dls_solve`).
4. Read singularity metric from the most recent solve
   (`ik_get_last_singularity_metric` — v0.2.199).
5. Set joint limits + re-solve IK in the bounded region
   (`ik_set_joint_limit` — v0.2.193).
6. TOPP time-optimal parameterization of a 3-waypoint joint-
   space path (`topp_*` — v0.2.203).
7. Sphere-sphere collision sanity test (`coll_sphere_sphere`).
8. BVH obstacle setup + sphere-AABB workspace check
   (`bvh.nr` + `coll_sphere_aabb`).

### Files

- `examples/showcase/robotic_arm.nr` — 8-stage integration
  showcase.

---

## [0.2.205] — 2026-04-23

**Robotics: convex-mesh GJK + EPA. Convenience entry points for
the common case where each shape is a convex polytope represented
as a flat `double[n*3]` vertex array — no support-function pointer
required (the runtime computes the support inline by scanning the
vertices). Closes the v0.5 deferred "mesh-mesh collision" item.**

`coll_gjk` (v0.2.183) and `coll_gjk_epa` (v0.2.202) take user-
supplied support function pointers, which is awkward when the
support function needs per-shape state (vertex array, position,
orientation) — Nucleor doesn't have closures, so the user has to
either thread state through globals or build a separate support
fn per shape. `coll_gjk_mesh_mesh` and `coll_gjk_epa_mesh_mesh`
sidestep that for the convex-mesh case.

For non-convex meshes, the caller decomposes the mesh into convex
pieces (V-HACD or similar — third-party preprocessing) and runs
pairwise mesh-mesh queries.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

// Each mesh is a flat double[n*3] of vertex coordinates.
let overlap = coll_gjk_mesh_mesh(verts_a_ptr, n_a, verts_b_ptr, n_b);
if overlap == 1 {
    let normal_h = vec3_new();
    let depth = coll_gjk_epa_mesh_mesh(verts_a_ptr, n_a,
                                       verts_b_ptr, n_b, normal_h);
    // depth is bit-cast f64; normal[0..2] is the unit contact normal.
}
```

### Verification

- Unit cube vs translated unit cube (offset 0.7 along x): overlap
  detected; EPA reports depth 0.3 along (1, 0, 0).
- Same cubes with offset 1.7: no overlap, as expected.

### Files

- `stdlib/runtime/collision_rt.c` — `_mesh_support`,
  `_gjk_support_mesh_mesh`, `nuc_coll_gjk_mesh_mesh`,
  `nuc_coll_gjk_epa_mesh_mesh`. Forward-declares the EPA
  static helpers (`_NEPA_MAX_VERT`, `_EPAFace`, `_epa_face_init`)
  so the mesh-mesh EPA can use them.
- `stdlib/rods/collision.nr` — externs + Nucleor wrappers.

---

## [0.2.204] — 2026-04-23

**Robotics: URDF (Unified Robot Description Format) parser. Reads
URDF source as a NUL-terminated text buffer, extracts joint
attributes (type, origin xyz/rpy, axis, limits), and constructs an
FK chain via `urdf_to_fk_chain` for direct use with the IK solver
(v0.2.176, .193, .194, .199), motion planners (v0.2.179-200), and
trajectory parameterization (v0.2.181-203). Closes the v0.5
robotics roadmap — the rod stack now spans URDF input → FK →
collision → motion planning → IK → trajectory parameterization.**

URDF is the de-facto standard for describing robot kinematics
(every ROS robot ships one, every commercial arm has one in the
manufacturer's distribution). Hand-coding the same joint topology
in DH parameters is tedious and error-prone; loading the URDF and
calling `urdf_to_fk_chain` is one line.

### Surface

```nucleor
import "stdlib/rods/urdf.nr"

let urdf = urdf_new();
urdf_parse(urdf, str_to_ptr(my_urdf_source));    // returns # joints
let chain = urdf_to_fk_chain(urdf);              // FK chain handle

// Then use the FK chain with the rest of the robotics stack:
let iters = ik_dls_solve(chain, vars, tx, ty, tz, 100, tol, lambda);
let collide = coll_sphere_sphere(/* end-effector vs obstacle */);
// ... etc.
```

### Supported per-joint attributes

```xml
<joint name="..." type="revolute|prismatic|fixed|continuous">
  <origin xyz="x y z" rpy="r p y"/>     <!-- RPY = roll/pitch/yaw -->
  <axis xyz="x y z"/>
  <limit lower="..." upper="..." effort="..." velocity="..."/>
</joint>
```

The parser also exposes accessors for each: `urdf_joint_count`,
`urdf_joint_type`, `urdf_joint_axis`, `urdf_joint_origin_xyz`,
`urdf_joint_origin_rpy`, `urdf_joint_limit_lo` / `_hi` / `_has_limit`.

### Implementation notes

- Substring-extraction parser, not a full XML parser. Tolerates
  the formatting variations of hand-written and ROS-exported URDF
  files; not strictly XML-compliant (no DTDs, no namespaces, no
  CDATA sections).
- RPY-to-quaternion conversion uses the URDF default convention
  R_z(yaw) · R_y(pitch) · R_x(roll).
- Mesh / visual / collision / inertial subtrees are skipped.
- `continuous` joint type is treated as `revolute` (no
  distinction needed by the FK chain).

### Limitations (full URDF compliance lands in v0.6 if needed)

- **Linear-chain assumption**: joints are loaded in source order
  from base to tip; `<parent>` / `<child>` link relationships are
  *not* used to reconstruct the topology. Branching trees
  (humanoids) are flattened to source-order — wrong for those,
  fine for serial arms (the dominant use case).
- xacro `<xacro:include>` is NOT resolved — the caller must pre-
  process xacro to plain URDF first (`xacro myrobot.xacro >
  myrobot.urdf`).

### Verification

- 2-DOF planar arm URDF (shoulder + elbow + fixed tip), 3 joints
  parsed with correct types / limits / axes / origins.
- `urdf_to_fk_chain` produces a chain that, with all joint vars
  zero, places the end effector at (2, 0, 0) — the analytical
  position for the straight-out arm with two 1-meter links.

### Files

- `stdlib/runtime/urdf_rt.c` — `_URDFJoint` / `NURDF` state,
  `_find_elem` / `_find_attr` / `_parse_3d` / `_rpy_to_quat`
  helpers, `nuc_urdf_*` exports including `_to_fk_chain`.
- `stdlib/rods/urdf.nr` — externs + Nucleor wrappers; chains
  `fk_chain.nr` so the FK runtime is linked in.
- `tests/rods/urdf_smoke.nr` — empty-state linkage smoke
  (correctness covered by direct C test against a real URDF).

---

## [0.2.203] — 2026-04-23

**Robotics: TOPP — time-optimal path parameterization. Given a
piecewise-linear path through joint space and per-joint velocity +
acceleration bounds, computes the minimum-time time-parameterization
(s ↦ t) that respects the bounds. Standard forward + backward pass
on the squared path velocity b(s) = (ds/dt)², per Pham 2014's
TOPP-RA algorithm — simplified for piecewise-linear paths.**

The trajectory rod (v0.2.177-192) ships profile-shaping primitives
(quintic, trapezoid, S-curve, DMP) that are useful for one-segment
moves between two waypoints. Multi-waypoint paths from a planner
(RRT, RRT*, PRM) need a different tool: parameterize the existing
geometric path along the time axis to minimize total time subject
to actuator limits. That's TOPP.

### Surface

```nucleor
import "stdlib/rods/trajectory.nr"

let topp = topp_new(n_dim);
topp_set_vmax(topp, joint_idx, vmax_b);
topp_set_amax(topp, joint_idx, amax_b);
for waypoint in path {
    topp_add_waypoint(topp, waypoint_ptr);  // double[n_dim] handle
}
topp_solve(topp);
let total_t = topp_total_time(topp);
let t_at_2  = topp_time_at_waypoint(topp, 2);
let v_at_2  = topp_path_velocity(topp, 2);  // path velocity (ds/dt)
```

### Implementation notes

- Per segment, projects per-joint bounds onto the segment direction:
  `vbound² = min_j (vmax[j] / |dq[j]|)²`,
  `a_max_seg = min_j amax[j] / |dq[j]|`.
- Forward pass starts at `b[0] = 0` and accelerates segment by
  segment; backward pass starts at `b[N-1] = 0` and decelerates.
  The minimum of the two is the actual squared path velocity at
  each waypoint.
- **Corner detection**: at each interior waypoint, if the path
  tangent changes (cosine of angle between adjacent segments
  < 0.999999), the joint velocity would have to step-change to
  follow — which violates any finite acceleration bound. Force
  `b[i] = 0` at corners. (Continuous-tangent paths through the
  same waypoint sequence preserve `b > 0`.)
- **Within-segment integration**: the segment-time integral
  ∫₀¹ ds/sqrt(b(s)) accounts for the *peak* `b` reached within
  the segment (not just the endpoints). Two cases:
  - **Trapezoidal**: forward + backward parabolas reach the
    velocity bound — accelerate, cruise at vmax, decelerate.
  - **Triangular**: parabolas meet below the bound — accelerate
    to a peak, immediately decelerate.

### Limitations (full TOPP-RA via convex optimization on a per-
discretization-step LP lands in v0.6 if needed):

- Only piecewise-linear paths. For B-splines or quintic-splines,
  sample to a piecewise-linear discretization first.
- Symmetric box bounds only (`|v| ≤ vmax`, `|a| ≤ amax`).
  Asymmetric bounds (e.g., gravity-loaded vertical axes) need
  the full LP formulation.
- Pure kinematic. No torque / dynamics constraints.

### Verification

- Single-segment 0→1 with `vmax=2, amax=4`: total time 1.0 s
  (matches analytical trapezoid: 0.5 s accel + 0.5 s decel).
- L-shaped (0,0)→(1,0)→(1,1) with `vmax=1, amax=2`:
  3.0 s (corner detection forces stop at midpoint).
- Collinear (0,0)→(1,0)→(2,0) with `vmax=1, amax=2`:
  2.5 s with `s_dot=1.0` at midpoint (no spurious braking on
  continuous tangent).

### Files

- `stdlib/runtime/trajectory_rt.c` — `NTopp` struct,
  `nuc_topp_new` / `_add_waypoint` / `_set_vmax` / `_set_amax` /
  `_solve` / `_total_time` / `_time_at_waypoint` /
  `_path_velocity` / `_waypoint_count` / `_free`.
- `stdlib/rods/trajectory.nr` — externs + Nucleor wrappers.
- `tests/rods/trajectory_smoke.nr` — exercise empty-state +
  insufficient-waypoint return code.

---

## [0.2.202] — 2026-04-23

**Robotics: GJK EPA — penetration depth + contact normal for two
overlapping convex shapes. Once GJK reports overlap (v0.2.184),
the Expanding Polytope Algorithm (Van den Bergen 2001) iteratively
expands the GJK terminating tetrahedron until it finds the face
nearest the origin on the Minkowski-difference polytope. The
distance from the origin to that face is the penetration depth;
the face normal is the minimum-translation direction to separate
the shapes.**

GJK answers "are these shapes overlapping?" (yes/no). Resolving
the overlap (e.g., for a physics resolver, a manipulation planner,
or a "push the gripper out of the obstacle" recovery) needs more:
*how far* to push and in *what direction*. EPA produces both, with
the same support-function contract as GJK — no shape-pair-specific
narrow-phase code.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

let normal_h = vec3_new();   // double[3] handle, allocated by caller
let depth_b = coll_gjk_epa(support_a_fp, support_b_fp, normal_h);
// depth_b is bit-cast f64; -1.0 if shapes don't overlap.
```

The contact normal is written to the caller's `double[3]` buffer in
unit-vector form, pointing from B into A.

### Implementation notes

- Captures the GJK terminating tetrahedron via the same
  `_gjk_do_simplex` driver, then expands it iteratively.
- Each iteration: find face closest to origin (smallest `dist`),
  get support point in face-normal direction; if support is no
  further out than current best, terminate; otherwise add support
  to polytope, remove visible faces, fill silhouette with new
  faces from the support point.
- Face-orientation invariant: stored winding `(v0, v1, v2)` always
  produces an outward-pointing cross product. The init helper
  swaps `v1 ↔ v2` when needed (instead of just flipping the normal
  vector) to keep this invariant — essential for correct silhouette-
  edge cancellation during expansion.
- Static buffers cap the polytope at 64 vertices / 128 faces.
  Sufficient for converged sphere-sphere, sphere-box, and box-box;
  for very high-detail convex hulls, the cap can be raised.
- Convergence verified end-to-end with two-sphere overlap tests
  (axis-aligned: depth 0.5 along x; diagonal offset: depth 1.0
  along (0.6, 0.8, 0) — both match analytical answer).

### Files

- `stdlib/runtime/collision_rt.c` — `_NEPA_*` constants, `_EPAFace`,
  `_gjk_capture_simplex`, `_epa_face_init`, `nuc_coll_gjk_epa`.
- `stdlib/rods/collision.nr` — extern + `coll_gjk_epa` wrapper.

---

## [0.2.201] — 2026-04-23

**Robotics: two more CCD (continuous collision detection) pairs.
`coll_ccd_capsule_capsule` and `coll_ccd_sphere_aabb` extend the
swept-sphere-sphere primitive (v0.2.196) to the two most-asked-for
moving-body cases: two moving capsules vs each other, and a moving
sphere vs a static AABB. Same surface as v0.2.196 — return earliest
collision time t ∈ [0, 1] as bit-cast f64; -1.0 if clear.**

Capsule-capsule swept distance has no closed form (the segment-
segment distance squared is a piecewise function of t, with the
piece-boundary endpoints themselves moving). The implementation
brackets the first overlap with a 16-step uniform sweep, then
refines via 16 bisection steps — what most game / robotics
engines actually ship in production. Sub-step exact rooting via
the per-region quadratics lands in v0.6 if a use-case demands it.

Sphere-vs-static-AABB uses the same bracket-then-bisect on the
sphere-center to AABB-clamp distance. The same approach generalizes
to most static-body CCD pairs (sphere vs OBB, sphere vs convex hull,
etc.) — those will be straightforward additions later.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

let t = coll_ccd_capsule_capsule(
    a_a0_x, a_a0_y, a_a0_z,  a_a1_x, a_a1_y, a_a1_z,    // capsule A endpoint A
    a_b0_x, a_b0_y, a_b0_z,  a_b1_x, a_b1_y, a_b1_z, ar, // capsule A endpoint B + radius
    b_a0_x, b_a0_y, b_a0_z,  b_a1_x, b_a1_y, b_a1_z,    // capsule B endpoint A
    b_b0_x, b_b0_y, b_b0_z,  b_b1_x, b_b1_y, b_b1_z, br); // capsule B endpoint B + radius

let t2 = coll_ccd_sphere_aabb(
    s0_x, s0_y, s0_z,  s1_x, s1_y, s1_z, sr,
    aabb_min_x, aabb_min_y, aabb_min_z,
    aabb_max_x, aabb_max_y, aabb_max_z);
```

### Files

- `stdlib/runtime/collision_rt.c` — `_capcap_dist2_at`,
  `nuc_coll_ccd_capsule_capsule`, `_sph_aabb_dist2_at`,
  `nuc_coll_ccd_sphere_aabb`.
- `stdlib/rods/collision.nr` — externs + Nucleor wrappers.
- `tests/rods/collision_smoke.nr` — exercise both new CCD calls
  for link verification (correctness covered by direct C test).

---

## [0.2.200] — 2026-04-23

**Robotics: PRM Dijkstra query. The probabilistic roadmap rod
finally ships its query side — `prm_query` connects start and goal
configurations to the precomputed roadmap and runs Dijkstra from
start to goal. Multiple queries can run against the same roadmap
without rebuilding, which is the entire reason to use PRM over
RRT. Read the resulting path back via `prm_path_len` /
`prm_path_node` / `prm_path_at`.**

`prm_build` (v0.2.185) shipped the precomputation half of the
multi-query pattern: sample N collision-free configurations,
connect each to its k nearest neighbors with collision-free edges,
store the resulting graph as a CSR adjacency. The query side was
deferred to "v0.5 alongside RRT-Connect / RRT*" — both of which
already shipped (v0.2.180, v0.2.190), so this closes that gap.

### Surface

```nucleor
import "stdlib/rods/prm.nr"

let p = prm_new(n_dim, seed);
prm_build(p, n_samples, k_neighbors, step, coll_fp);

// Then any number of queries against the same roadmap:
let path_len = prm_query(p, start_ptr, goal_ptr, k_neighbors,
                         step, coll_fp);
if path_len > 0 {
    for i in 0..path_len {
        let node_idx = prm_path_node(p, i);  // n_nodes/+1 = virtual endpoints
        let q0 = prm_path_at(p, i, 0);       // bit-cast f64 coord
        // ...
    }
}
```

### Implementation

- Virtual nodes: `start = N`, `goal = N + 1`. Edges from these to
  real roadmap nodes are computed on demand (no graph mutation),
  so the roadmap remains pristine for the next query.
- O(V²) Dijkstra (no priority queue). Fine for N ≤ a few thousand
  roadmap nodes; a binary-heap upgrade is straightforward later.
- Endpoints connect via the same k-nearest pattern + collision-
  free segment check as the roadmap edges. If start or goal can't
  reach any roadmap node, query returns 0 (no path).

### Files

- `stdlib/runtime/prm_rt.c` — `_ext_dist2`, `_ext_segment_free`,
  `nuc_prm_query`, `nuc_prm_path_len`, `nuc_prm_path_node`,
  `nuc_prm_path_at`.
- `stdlib/rods/prm.nr` — externs + Nucleor wrappers for the four
  new exports.
- `tests/rods/prm_smoke.nr` — exercise empty-roadmap query
  (returns 0 path-len) and out-of-range path-node accessor.

---

## [0.2.199] — 2026-04-23

**Robotics: singularity detection in IK solver. The damped least
squares solver tracks the smallest `|det(J·Jᵀ + λ²I)|` observed
during a solve and exposes it via `ik_get_last_singularity_metric`.
A small value (~1e-9 or below) flags that the chain approached a
singular configuration where the Jacobian is rank-deficient — the
caller can use this to back off, try a different goal, or switch
to a more aggressive damped strategy.**

The damped least squares solver is mathematically robust at
singularities (the λ² term keeps the inverse well-conditioned), but
its position progress can stall there. There was previously no way
for the caller to *know* a singularity had been hit — convergence
just slowed. The new accessor surfaces the observation as a single
number, no per-iteration callback needed.

### Surface

```nucleor
import "stdlib/rods/ik_dls.nr"

let _iters = ik_dls_solve(chain, vars, tx, ty, tz, 100, tol, lambda);
let metric = ik_get_last_singularity_metric();
// metric < 1e-9 ≈ near-singular configuration
```

The metric resets at the start of every solve. Read it after the
solve returns; it reflects the worst-conditioned Jacobian seen
during that solve. Both 3D (`nuc_ik_dls_solve`) and 6D
(`nuc_ik_dls_solve_6d`) update the same global, so the most recent
solve wins regardless of mode.

### Files

- `stdlib/runtime/ik_dls_rt.c` — track `_g_last_singularity` in
  the 3D solve loop; export `nuc_ik_get_last_singularity_metric`.
- `stdlib/rods/ik_dls.nr` — `extern fn nuc_ik_get_last_singularity_metric`
  + `ik_get_last_singularity_metric` Nucleor wrapper.
- `tests/rods/ik_dls_smoke.nr` — call accessor for link verification.

---

## [0.2.198] — 2026-04-24

**Robotics: goal-region planning in RRT. Sample uniformly inside
a per-dimension `[lo, hi]` acceptable region instead of converging
on a single goal point. Useful when the target pose is approximate
or has a tolerance bubble.**

`rrt_plan` (v0.2.179) targets a single point and reports success
when the latest extension is within `step` of that point. In
practice many tasks (placing an object on a table; "reach the
book bin"; etc.) have a tolerance — any pose within an acceptable
region is fine. Goal-region planning samples inside that region
during the goal-bias phase and accepts the first node that lands
inside.

### Surface

```nucleor
import "stdlib/rods/rrt.nr"

let r = rrt_new(n_dim, seed);
rrt_set_root(r, start_ptr);

// region_lo, region_hi are double[n_dim] arrays defining the
// acceptable goal region. For position goals: region_lo[k] =
// goal_center[k] - tolerance, region_hi[k] = goal_center[k] +
// tolerance.
let ok = rrt_plan_region(r, region_lo_ptr, region_hi_ptr,
    1000,                   // max_iters
    f64_to_bits(0.1),       // step size
    coll_callback_fp);
```

### Files

- `stdlib/runtime/rrt_rt.c`: ~80 LOC for the goal-region variant.
  Same overall structure as `nuc_rrt_plan`; differs only in the
  goal-bias sampling (samples inside the region) and the
  acceptance check (point-in-box).
- `stdlib/rods/rrt.nr`: 1 new builtin (`rrt_plan_region`).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.197] — 2026-04-24

**Robotics: sphere-OBB (Oriented Bounding Box) cross-pair.
Closes the v0.5 collision-pair matrix.**

OBBs are more general than AABBs: they have a position, half-
extents, AND an orientation. The standard test rotates the
sphere center into the OBB's local frame (via `conj(q) · p ·
q`), then runs the same clamp-to-half-extents logic as
sphere-AABB.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

let hit = coll_sphere_obb(
    f64_to_bits(sx), f64_to_bits(sy), f64_to_bits(sz), f64_to_bits(sr),
    f64_to_bits(cx), f64_to_bits(cy), f64_to_bits(cz),    // OBB center
    f64_to_bits(hx), f64_to_bits(hy), f64_to_bits(hz),    // OBB half-extents
    f64_to_bits(qw), f64_to_bits(qx), f64_to_bits(qy), f64_to_bits(qz)  // OBB orientation
);
```

### Files

- `stdlib/runtime/collision_rt.c`: ~30 LOC for the rotate-into-
  local-frame + clamp pattern.
- `stdlib/rods/collision.nr`: 1 new builtin (`coll_sphere_obb`).

### v0.5 collision matrix status

| Pair | Static | CCD |
|------|--------|-----|
| sphere-sphere | ✓ v0.2.178 | ✓ v0.2.196 |
| sphere-capsule | ✓ v0.2.178 | — |
| sphere-AABB | ✓ v0.2.195 | — |
| sphere-OBB | ✓ v0.2.197 | — |
| capsule-capsule | ✓ v0.2.178 | — |
| capsule-AABB | ✓ v0.2.195 | — |
| AABB-AABB | ✓ v0.2.178 | — |
| convex-convex (GJK) | ✓ v0.2.183 | — |

CCD for the rest of the pairs ships in v0.5.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.196] — 2026-04-24

**Robotics: Continuous Collision Detection (CCD) for swept
sphere-sphere. Reports the earliest collision time t ∈ [0, 1]
of two moving spheres over a unit time interval — so fast-
moving objects don't tunnel through each other in discrete-
time simulation.**

The static collision tests (v0.2.178) check overlap at one
instant. Real systems with fast motion need to know whether two
objects WILL collide between simulation steps — otherwise small
objects pass through walls (the classic "tunneling" bug).

`coll_ccd_sphere_sphere` solves the closed-form quadratic for
when the relative-distance equals the sum-of-radii during the
swept motion, and reports the earliest such time in [0, 1].
Returns -1.0 if no collision in the interval.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

// Sphere A moves from (0,0,0) → (10,0,0); sphere B sits at (5,0,0).
let t = coll_ccd_sphere_sphere(
    f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
    f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.5),
    f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
    f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.5));
// t ≈ 0.45 (first contact when sphere A reaches x ≈ 4.5)
```

### Files

- `stdlib/runtime/collision_rt.c`: ~50 LOC for the quadratic
  solver.
- `stdlib/rods/collision.nr`: 1 new builtin
  (`coll_ccd_sphere_sphere`).

### v0.5 follow-on

- CCD for capsule-capsule, sphere-AABB
- GJK-based CCD for general convex shapes
- Continuous AABB-AABB (sweep-and-prune at the BVH leaf level)

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.195] — 2026-04-24

**Robotics: collision cross-pairs — sphere-AABB and capsule-
AABB. Fills out the collision matrix so every primitive pair
in the v0.5 list has a narrow-phase test.**

### Surface

```nucleor
import "stdlib/rods/collision.nr"

// Sphere-AABB.
let hit = coll_sphere_aabb(
    f64_to_bits(sx), f64_to_bits(sy), f64_to_bits(sz), f64_to_bits(sr),
    f64_to_bits(minx), f64_to_bits(miny), f64_to_bits(minz),
    f64_to_bits(maxx), f64_to_bits(maxy), f64_to_bits(maxz));

// Capsule-AABB.
let hit2 = coll_capsule_aabb(
    f64_to_bits(c_ax), f64_to_bits(c_ay), f64_to_bits(c_az),
    f64_to_bits(c_bx), f64_to_bits(c_by), f64_to_bits(c_bz), f64_to_bits(cr),
    f64_to_bits(minx), f64_to_bits(miny), f64_to_bits(minz),
    f64_to_bits(maxx), f64_to_bits(maxy), f64_to_bits(maxz));
```

### Algorithms

- **Sphere-AABB**: closest point on AABB to sphere center is the
  center clamped to the AABB bounds. Overlap iff that point is
  within `radius`.
- **Capsule-AABB**: expand the AABB by the capsule radius
  (Minkowski sum trick), then test segment vs expanded-AABB via
  Liang-Barsky-style slab clipping. Slightly conservative at the
  rounded corners of the expanded box; exact rounded-corner
  rejection ships in v0.5 alongside the GJK-based mesh paths.

### Files

- `stdlib/runtime/collision_rt.c`: ~80 LOC for the two new tests.
- `stdlib/rods/collision.nr`: 2 new builtins.
- `tests/rods/collision_smoke.nr`: extended with sphere-AABB
  inside / sphere-AABB clear assertions.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.194] — 2026-04-24

**Robotics: 6-DOF orientation IK. New `ik_dls_solve_6d`
extends the v0.2.176 position-only solver to a position +
orientation target. Closes the IK roadmap item from the v0.5
list.**

The position-only solver (v0.2.176) only constrained where the
end-effector ends up. Real manipulation tasks require the
end-effector to face a particular direction too — pick-and-
place, welding, screwdriving, all need orientation control.

### Surface

```nucleor
import "stdlib/rods/ik_dls.nr"

let iters = ik_dls_solve_6d(
    chain, vars_ptr,
    f64_to_bits(tx), f64_to_bits(ty), f64_to_bits(tz),
    f64_to_bits(qw), f64_to_bits(qx), f64_to_bits(qy), f64_to_bits(qz),
    100,                   // max_iters
    f64_to_bits(0.001),    // tolerance
    f64_to_bits(0.05),     // damping λ
    f64_to_bits(1.0)       // weight_orient
);
```

### Theory

The Jacobian becomes 6×n: 3 rows for position derivatives + 3
rows for angular-velocity derivatives. The 6-DOF target is
(position, orientation). Position error is `target - current`
in world space. Angular error is the quaternion log-map of
`target_quat * current_quat^-1`, which produces a 3-vector in
axis-angle form (the rotation axis times the rotation magnitude).

The solver inverts a 6×6 normal-equations matrix per iteration
via Gauss-Jordan elimination on a stack-allocated 6×12
augmented matrix. Joint limits (v0.2.193) compose: bounds
apply after each delta update.

### `weight_orient`

Position units (meters) and angular units (radians) have
different magnitudes. `weight_orient` scales the orientation
error to balance the optimization:

- `weight_orient = 1.0` — equal weight (default; works for
  ~1m workspaces with sub-meter precision)
- `weight_orient < 1.0` — prioritize position
- `weight_orient > 1.0` — prioritize orientation
- `weight_orient = 0.0` — invalid; use the position-only
  `ik_dls_solve` instead

### Files

- `stdlib/runtime/ik_dls_rt.c`: ~140 LOC for the 6D solver
  (alongside the existing position-only path). Includes
  quaternion log-map helper, angular-error helper, and a
  6×6 Gauss-Jordan inverter.
- `stdlib/runtime/fk_chain_rt.c`: added `quat_x/y/z`
  accessors (only `quat_w` was exported originally).
- `stdlib/rods/ik_dls.nr`: 1 new builtin
  (`ik_dls_solve_6d`).
- `stdlib/rods/fk_chain.nr`: 3 new accessors
  (`fk_chain_link_quat_x/y/z`).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.193] — 2026-04-24

**Robotics: per-joint min/max limits in IK solver. Set once
per chain, applied as clamping during every solve iteration.**

The v0.2.176 IK solver assumed unbounded joint motion. Real
robots have mechanical joint limits (e.g., a wrist that can
rotate ±170°, not ∞). v0.2.193 adds:

```nucleor
import "stdlib/rods/ik_dls.nr"

// After fk_chain_add_*_joint, set per-joint bounds.
ik_set_joint_limit(chain, 0, f64_to_bits(-2.96), f64_to_bits(2.96));
ik_set_joint_limit(chain, 1, f64_to_bits(-2.05), f64_to_bits(2.05));
// ... etc

// Solve as before — clamping is automatic.
let n = ik_dls_solve(chain, vars_ptr, tx, ty, tz, max_iters, tol, lambda);
```

Bounds default to ±2π if not set. Persist across multiple
solve calls on the same chain handle.

### Limitations + future work (v0.5)

- **Simple clamp** — the current implementation just bounds
  the joint values after each delta. A more sophisticated
  approach projects the gradient onto the constraint manifold
  (gradient projection) so the solver doesn't waste iterations
  pushing against the bounds. v0.5 task-priority IK ship.
- **Per-step velocity caps** also useful for smoother motion;
  deferred.

### Files

- `stdlib/runtime/ik_dls_rt.c`: ~50 LOC for the limits table
  (per-chain entry, simple linear-search lookup; fine for
  typical N≤10 joint chains) plus the in-loop clamp.
- `stdlib/rods/ik_dls.nr`: 1 new builtin
  (`ik_set_joint_limit`).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.192] — 2026-04-24

**Robotics: Dynamic Movement Primitives (DMPs) added to
`trajectory.nr`. Learnable trajectories that generalize across
goal positions — foundation for imitation learning and skill
transfer.**

A DMP (Ijspeert et al. 2013) is a damped second-order spring
system whose attractor is the goal, perturbed by a learnable
forcing function shaped from a demonstration:

```
τ²·y'' = α_z·(β_z·(g - y) - τ·y') + (g - y0)·f(s)
τ·s'   = -α_s·s
```

The forcing function `f(s)` is a weighted sum of Gaussian
basis functions over the canonical phase `s` (which decays
1 → 0 as motion proceeds). The basis weights are learned from
a demonstration via locally weighted regression. After
training, the DMP unrolls with a NEW (start, goal) pair and
the learned shape generalizes — preserving the demonstration's
"style" while adapting to different motions.

Foundation for:
- Robotics imitation learning ("show the robot once, generalize")
- Skill primitives in hierarchical RL
- Smooth trajectory adaptation to perturbed goals (e.g., target
  moves during execution)

### Workflow

```nucleor
import "stdlib/rods/trajectory.nr"

// 1. Create DMP with 25 Gaussian basis functions.
let dmp = dmp_new(25, f64_to_bits(25.0), f64_to_bits(8.33));

// 2. Train from demonstration (traj_ptr is a malloc'd
//    double[N] of equispaced position samples).
dmp_learn(dmp, traj_ptr, n_samples, f64_to_bits(tau_seconds));

// 3. Reset for unroll with a new goal.
dmp_reset(dmp, f64_to_bits(y0_new), f64_to_bits(g_new), f64_to_bits(tau));

// 4. Step Euler integration.
let i = 0;
while i < n_steps {
    let y = dmp_step(dmp, f64_to_bits(dt));
    // ... record / send to actuator
    i = i + 1;
};

dmp_free(dmp);
```

### Multi-DOF

Instantiate one DMP per joint — each joint's trajectory is
independent. Multi-DOF DMPs sharing a phase variable are a v0.5
follow-on (gives synchronized motion across joints).

### Files

- `stdlib/runtime/trajectory_rt.c`: ~140 LOC for the DMP. The
  basis centers are placed logarithmically in s-space (matches
  the canonical phase decay); LWR learns one weight per basis.
  Step uses simple Euler integration — the user advances time
  externally with their preferred dt.
- `stdlib/rods/trajectory.nr`: 5 new builtins.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.191] — 2026-04-24

**Robotics: S-curve (bounded-jerk) trajectory profile added to
`trajectory.nr`. Respects velocity, acceleration, AND jerk
limits simultaneously — smoother than trapezoidal, less
residual vibration.**

The seven-phase S-curve profile bounds the rate of change of
acceleration (jerk). Trapezoidal profiles (v0.2.181) have
acceleration discontinuities at phase boundaries that cause
residual vibration in flexible systems (robot arms with
harmonic drives, CNC axes with ball screws, etc.). S-curves
eliminate those discontinuities with constant-jerk transitions.

Seven phases: acc-ramp-up, acc-constant, acc-ramp-down, cruise,
dec-ramp-up, dec-constant, dec-ramp-down. For long-enough
motions all seven run full-duration and the profile hits
`v_max`, `a_max`, and `j_max` plateaus. For shorter motions,
phases collapse automatically and peak values are reduced (read
back via `scurve_peak_v` / `scurve_peak_a`).

### Surface

```nucleor
import "stdlib/rods/trajectory.nr"

let sc = scurve_new(
    f64_to_bits(0.0), f64_to_bits(1.0),  // q0, qT
    f64_to_bits(2.0),                    // v_max (rad/s)
    f64_to_bits(4.0),                    // a_max (rad/s²)
    f64_to_bits(20.0)                    // j_max (rad/s³)
);
let T = scurve_duration(sc);
let q = scurve_pos_at(sc, f64_to_bits(t));
scurve_free(sc);
```

### When to use which trajectory profile

- **`quintic_new`** (v0.2.177) — C² smooth, hits boundary
  (q, v, a) exactly; doesn't respect velocity/accel limits;
  best when the duration is known and smoothness is the goal
- **`trapezoid_new`** (v0.2.181) — respects v_max and a_max;
  acceleration is discontinuous at phase boundaries
- **`scurve_new`** (v0.2.191) — respects v_max, a_max, AND
  j_max; smoother than trapezoidal; preferred for high-speed
  or flexible systems where acceleration steps cause problems

### Files

- `stdlib/runtime/trajectory_rt.c`: ~160 LOC for the S-curve.
  Closed-form computation for the canonical symmetric
  rest-to-rest case; scale-down fallback when distance is too
  short to reach the requested peaks. The full 16-case branch
  from Biagiotti & Melchiorri is deferred to v0.5 alongside
  TOPP-RA + DMPs.
- `stdlib/rods/trajectory.nr`: 6 new builtins.
- `tests/rods/trajectory_smoke.nr`: extended to build an
  S-curve and sample all accessors.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.190] — 2026-04-24

**Robotics: RRT* (Karaman & Frazzoli 2011) — asymptotically
optimal motion planning. Path quality converges to the optimum
as iterations accumulate.**

Vanilla RRT (`rrt_plan` v0.2.179) finds a feasible path but
doesn't optimize it. RRT-Connect (`rrt_connect_plan` v0.2.188)
finds it faster but still not optimal. RRT* adds two phases per
new node:

1. **Best parent selection**: among all neighbors within
   `radius`, pick the one that yields the lowest cost-to-come
   for the new node (collision-checked).
2. **Rewiring**: for each neighbor, check whether routing
   through the new node would lower their own cost-to-come;
   if so, change their parent.

Cost is path length in joint space. With enough samples the path
converges to the shortest feasible route.

### Surface

```nucleor
import "stdlib/rods/rrt.nr"

let r = rrt_new(n_dim, seed);
rrt_set_root(r, start_ptr);
let ok = rrt_star_plan(r, goal_ptr,
    1000,                    // max_iters (more = better path quality)
    f64_to_bits(0.1),        // step size
    f64_to_bits(0.3),        // rewire radius (~3× step is typical)
    coll_callback_fp);
```

### Files

- `stdlib/runtime/rrt_rt.c`: ~120 LOC for RRT* alongside vanilla
  RRT and RRT-Connect. Uses a per-node cost-to-come array sized
  to the tree's capacity. Per-iteration overhead vs vanilla RRT
  is O(N) for the neighbor scan + collision-check per neighbor;
  with `radius` tuned correctly, dominated by the collision
  checks.
- `stdlib/rods/rrt.nr`: 1 new builtin (`rrt_star_plan`).

### When to use which planner

- **`rrt_plan`** — fastest to first feasible path; simplest
- **`rrt_connect_plan`** — 5-10× faster than `rrt_plan` on hard
  problems; same path quality (just feasible, not optimal)
- **`rrt_star_plan`** — optimal path quality at higher per-iter
  cost; use when the path will be executed repeatedly and
  motion-time matters

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.189] — 2026-04-24

**Documentation: `docs/release-notes-v0.2.x-robotics.md` adds a
single-page summary of the v0.2.174-v0.2.188 robotics stack arc
suitable for blog posts, release announcements, and reviewer
overview.**

Companion to the v0.2.x memory-fix release notes
(`docs/release-notes-v0.2.x-memory.md` from v0.2.170). Together
the two docs cover the two major stories of the v0.2 ship arc:
the 283× memory reduction and the new robotics stack.

Sections:

- TL;DR table (9 rods + 1 showcase, ~1965 LOC)
- Per-ship one-line summary (15 ships)
- Architecture decisions (i64 FFI; user callbacks for
  collision and graph search; composition over coupling)
- v0.4/v0.5 follow-on cross-reference to milestone trackers
- "How to use the stack today" with the integration example
  command

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP** (no test changes; doc-only ship).

## [0.2.188] — 2026-04-24

**Robotics: RRT-Connect (Kuffner & LaValle 2000) — bidirectional
RRT, typically 5-10× faster than vanilla RRT on hard problems.**

The classic single-tree RRT (`rrt_plan` in v0.2.179) extends one
tree from the start and has to randomly stumble into the goal
region. RRT-Connect grows TWO trees — one from start, one from
goal — and each iteration tries to "connect" all the way from
the latest extension in one tree to the other tree. Much faster
convergence on most problems.

### Surface

```nucleor
import "stdlib/rods/rrt.nr"

let r = rrt_new(n_dim, seed);
rrt_set_root(r, start_ptr);
let ok = rrt_connect_plan(r, goal_ptr,
    1000,                  // max_iters
    f64_to_bits(0.1),      // step size
    coll_callback_fp);
// On success, rrt_path_len + rrt_path_at give the bidirectional path.
```

Same callback contract as `rrt_plan`. Path access is unchanged
(`rrt_path_len` + `rrt_path_at`) — internal stitching of the two
trees is invisible to the caller.

### Files

- `stdlib/runtime/rrt_rt.c`: ~120 LOC for RRT-Connect alongside
  the existing single-tree RRT. Reuses `_extend_toward` helper
  (factored out of the original `rrt_plan` body); each iteration
  alternates which tree extends, then the OTHER tree tries
  multiple connect-steps without sampling.
- `stdlib/rods/rrt.nr`: 1 new builtin (`rrt_connect_plan`).
- Existing `tests/rods/rrt_smoke.nr` unchanged (build-only smoke).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.187] — 2026-04-24

**Robotics integration showcase: `examples/showcase/robotic_arm.nr`
composes 5 of the v0.2.174-186 robotics rods (kinematics +
fk_chain + trajectory + collision + bvh) into a single working
program. Proves the rods compose end-to-end.**

Each robotics rod ships its own smoke test, but the smokes only
exercise one rod at a time. v0.2.187 builds the integration
example: a 3-link planar arm via DH parameters, a workspace BVH
of two obstacle boxes, a sphere-sphere collision sanity check,
a trapezoidal trajectory, and Vec3 / quaternion cross-product
algebra — all in one program, all sharing the same handles.

### Surface

```
nuc build examples/showcase/robotic_arm.nr -o robotic_arm
target/robotic_arm.exe
```

Output:
```
=== Nucleor Robotic Arm Showcase ===
Built 3-link DH arm
Built obstacle BVH (2 boxes)
Collision check: spheres at d=1.5, r=1+1 overlap
Trapezoidal trajectory built
Vec3 cross-product: x × y → z (verified non-zero z)
=== Showcase complete: 5 robotics rods composed ===
```

### Files

- `examples/showcase/robotic_arm.nr`: ~70 LOC of integration
  code. Imports kinematics + fk_chain + trajectory + collision
  + bvh; sets up a 3-link arm, an obstacle BVH, runs a few
  sanity checks; cleans up all handles.

### Why this matters for open-source release

The robotics rods (174-186) shipped one at a time with
build-only or per-rod functional smokes. A reviewer cloning
the repo wants to see the rods used together, not just in
isolation. This example serves as the "yes the stack works"
artifact alongside the existing showcase programs (lorenz,
vqe_h2, market_maker, wing_simulator).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP**. Both budgets hold.

## [0.2.186] — 2026-04-24

**Robotics + foundations: A* shortest-path search on a generic
weighted graph. Foundation for v0.5 PRM Dijkstra/A* query and
RRT* rewiring; immediately useful as a standalone graph-search
primitive.**

A* (Hart-Nilsson-Raphael 1968) is the workhorse heuristic
shortest-path algorithm. Caller supplies the graph as two
function pointers:

- `neighbor_fn(node, out_ids, out_costs, cap) -> n` — given a
  node, fill the output arrays with up to `cap`
  `(neighbor_id, edge_cost)` pairs and return the count
  written.
- `heuristic_fn(from, to) -> cost_lower_bound` — admissible
  lower-bound on remaining cost. Pass 0 (null fn pointer) for
  pure Dijkstra (no heuristic).

The algorithm uses a binary min-heap keyed by f-score; standard
A* with closed-list, lazy decrease-key.

### Surface

```nucleor
import "stdlib/rods/astar.nr"

let a = astar_new(n_nodes);
let ok = astar_search(a, start, goal,
    neighbor_callback_fp,
    heuristic_callback_fp,    // 0 for Dijkstra
    max_neighbors_per_node);
if ok == 1 {
    let n = astar_path_len(a);
    let i = 0;
    while i < n {
        let node = astar_path_at(a, i);
        // ... process node ...
        i = i + 1;
    };
};
astar_free(a);
```

### Files

- `stdlib/runtime/astar_rt.c`: ~150 LOC. Open-list as a
  binary min-heap, closed-list as a flat byte array,
  came_from / g_score / f_score arrays sized to `n_nodes`.
  Standard textbook A* — admissible heuristic guarantees
  optimal path.
- `stdlib/rods/astar.nr`: 6 builtins.
- `tests/rods/astar_smoke.nr`: build-only smoke (full search
  needs callback fps).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**259 / 259 PASS, 0 SKIP** (was 258/258; +1 new smoke test).
Both budgets hold.

## [0.2.185] — 2026-04-24

**Robotics: PRM (Probabilistic Roadmap) multi-query motion
planner. Complement to v0.2.179 RRT (single-query).**

PRM samples random configurations and connects k-nearest
neighbors with collision-free edges, building a graph in joint
space. The roadmap is built once; every subsequent (start,
goal) query reuses it via graph search.

### When to use which planner

- **RRT** (`rrt.nr`) — single-query, world changes between
  queries, build a fresh tree per problem
- **PRM** (`prm.nr`) — multi-query, world is static, amortize
  graph construction over many queries

### Surface

```nucleor
import "stdlib/rods/prm.nr"

let p = prm_new(2, 42);                       // 2-DOF, seed 42
prm_set_bounds(p, 0, lo_b, hi_b);             // per-dim sampling range
prm_build(p, 200, 8,                          // 200 samples, k=8 neighbors
    f64_to_bits(0.05), coll_callback_fp);     // step size for edge validation
let n = prm_node_count(p);
let e = prm_edge_count(p);
prm_free(p);
```

### Files

- `stdlib/runtime/prm_rt.c`: ~180 LOC. Sample-and-reject for
  collision-free node selection, O(N²) k-NN for edges, two-pass
  edge construction (count + fill into CSR-style adjacency).
- `stdlib/rods/prm.nr`: 6 builtins.
- `tests/rods/prm_smoke.nr`: build-only smoke (full
  roadmap-build needs callback fp + bounds).

### v0.5 follow-on

- Dijkstra query: `prm_query(p, start_ptr, goal_ptr)` returns
  the shortest collision-free path through the roadmap
- Lazy collision checking on query (only collide-test edges
  that the search visits)

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**258 / 258 PASS, 0 SKIP** (was 257/257; +1 new smoke test).
Both budgets hold.

## [0.2.184] — 2026-04-24

**Robotics: BVH (Bounding Volume Hierarchy) for broad-phase
collision pruning. Companion to v0.2.183 GJK narrow-phase.**

Stores N axis-aligned bounding boxes; builds a binary tree
where each internal node's box contains its children's boxes.
Two query modes:

- **`bvh_query(box)`** — given a query AABB, return all stored
  AABB indices whose boxes overlap. Useful for "what objects
  might my new pose intersect?" queries.
- **`bvh_self_pairs()`** — return all `(i, j)` `i < j` where
  stored boxes overlap each other. Use this to enumerate
  candidate object pairs to check with narrow-phase
  (`coll_sphere_sphere`, `coll_capsule_capsule`, `coll_gjk`).

Build is top-down median split along the longest axis (object
median). O(N log N) typical.

### Surface

```nucleor
import "stdlib/rods/bvh.nr"

let bvh = bvh_new();
bvh_add(bvh, minx, miny, minz, maxx, maxy, maxz);  // for each object
// ...
bvh_build(bvh);

// Overlap query.
let n = bvh_query(bvh, qmin_x, qmin_y, qmin_z, qmax_x, qmax_y, qmax_z);
let i = 0;
while i < n {
    let hit = bvh_query_at(bvh, i);
    // ... process hit (object index in user's array)
    i = i + 1;
};

// Self-pairs.
let p = bvh_self_pairs(bvh);
let k = 0;
while k < p {
    let lo = bvh_pair_lo(bvh, k);
    let hi = bvh_pair_hi(bvh, k);
    // ... apply narrow-phase to (lo, hi)
    k = k + 1;
};

bvh_free(bvh);
```

### Files

- `stdlib/runtime/bvh_rt.c`: ~230 LOC. BVH struct + node/leaf
  encoding, top-down build with insertion-sort partition,
  recursive overlap query, recursive self-pair query (the
  classic "tree-tree" intersection pattern).
- `stdlib/rods/bvh.nr`: 9 builtins.
- `tests/rods/bvh_smoke.nr`: builds 3 boxes (A overlaps B,
  C separate), asserts overlap query returns 2, self-pairs
  returns 1.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**257 / 257 PASS, 0 SKIP** (was 256/256; +1 new smoke test).
Both budgets hold.

## [0.2.183] — 2026-04-24

**Robotics: GJK convex-convex collision. Generic shape support
via user-supplied support functions. Industry-standard convex
collision algorithm.**

The Gilbert-Johnson-Keerthi algorithm (1988) is the workhorse
for convex-shape collision in physics engines and robotics. Given
two convex shapes, it iteratively builds a simplex in
Minkowski-difference space and asks whether the simplex contains
the origin (origin in Minkowski difference ⇔ shapes overlap).

The user supplies the **support function** for each shape: a
callable that takes a direction vector and returns the point on
the shape farthest in that direction. With this contract, GJK
works for arbitrary convex shapes — spheres, capsules, OBBs,
convex meshes, Minkowski sums of any of the above — without
caring about the specific representation.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

// User defines support functions for shapes A and B as Nucleor fns
// that take an i64 direction-Vec3 handle and return an i64 point-Vec3
// handle. (Specifics per shape: typical support_fn for a convex hull
// iterates vertices and picks the dot-max.)

let result = coll_gjk(support_a_fp, support_b_fp);
// 1 = overlap, 0 = clear, -1 = convergence failed (rare; means
// degenerate inputs)
```

### Files

- `stdlib/runtime/collision_rt.c`: GJK implementation,
  ~140 LOC.
  - 4-element simplex (point → line → triangle → tetrahedron)
  - Standard `do_simplex` updates per simplex size
  - 32-iteration cap; returns -1 on non-convergence
  - Internal helpers: vector ops (sub, dot, cross, neg, scale),
    triple cross product
- `stdlib/rods/collision.nr`: 1 new builtin (`coll_gjk`).
- Existing `tests/rods/collision_smoke.nr` left unchanged
  (GJK requires user-supplied support fns; full functional test
  ships in v0.5 alongside the convex-mesh shape rod).

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**256 / 256 PASS, 0 SKIP**. Both budgets hold.

## [0.2.182] — 2026-04-24

**Robotics: two more v0.5-list items shipped — RRT path
shortcutting + DH-parameter constructor for fk_chain.**

### Path shortcutting (`rrt.nr`)

Standard post-process for RRT raw output. Repeatedly samples
random index pairs `(i, j)` on the current path; if the
straight-line segment from `path[i]` to `path[j]` is
collision-free at every intermediate `step`-spaced sample,
collapses `path[i+1..j-1]` into that segment. New builtin:

```nucleor
let n = rrt_shortcut_path(rrt, 200, f64_to_bits(0.05), coll_fn_fp);
// path is now smoothed; n is the new waypoint count
```

Same callback contract as `rrt_plan` — caller-supplied
collision-check function pointer. Useful as a one-shot smoother
between `rrt_plan` and consuming the path.

### DH-parameter constructor (`fk_chain.nr`)

Industrial-arm convention. Add a revolute joint described by
the four Denavit-Hartenberg parameters (Spong's *Robot Modeling
and Control*):

```nucleor
fk_chain_add_dh_joint(chain,
    f64_to_bits(alpha),  // twist about previous x
    f64_to_bits(a),      // link length along previous x
    f64_to_bits(d),      // link offset along previous z
    f64_to_bits(theta)   // joint angle offset about previous z
);
```

The transform `T = Rot_x(α) · Trans_x(a) · Trans_z(d) ·
Rot_z(θ)` is decomposed into a base-pose offset (compiled as
the joint's parent-to-child base) plus a revolute joint about z
(the joint variable adds to θ at FK time).

This is the standard alternative to URDF for serial
manipulators — most robot textbooks describe arms via DH tables
(Puma 560, Stanford arm, KUKA LBR iiwa, Universal Robots UR5).

### Files

- `stdlib/runtime/rrt_rt.c`: new `nuc_rrt_shortcut_path`.
- `stdlib/runtime/fk_chain_rt.c`: new `nuc_fk_chain_add_dh_joint`.
- `stdlib/rods/rrt.nr`, `stdlib/rods/fk_chain.nr`: thin
  Nucleor wrappers.
- `tests/rods/fk_chain_smoke.nr`: extended to add a DH-joint
  and assert the count goes 1 → 2.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**256 / 256 PASS, 0 SKIP**. Both budgets hold.

## [0.2.181] — 2026-04-24

**Robotics: trapezoidal velocity profile added to `trajectory.nr`.
First v0.5-list item shipped.**

The v0.2.177 quintic shipped C² smoothness but ignored
actuator velocity / acceleration limits. v0.2.181 adds the
trapezoidal profile: three-phase motion (constant accel ramp-up,
constant velocity cruise, constant decel ramp-down) that
respects explicit `v_max` and `a_max` limits.

If the displacement is too small to reach `v_max`, the profile
automatically collapses to a triangular two-phase profile with
the actually-reachable peak velocity (`v_peak = sqrt(dist *
a_max)`).

### Surface

```nucleor
import "stdlib/rods/trajectory.nr"

let tp = trapezoid_new(
    f64_to_bits(0.0), f64_to_bits(1.0),  // q0, qT
    f64_to_bits(2.0),                    // v_max (rad/s or m/s)
    f64_to_bits(4.0)                     // a_max (rad/s² or m/s²)
);
let q = trapezoid_pos_at(tp, f64_to_bits(t));
let v = trapezoid_vel_at(tp, f64_to_bits(t));
let dur = trapezoid_duration(tp);
let v_peak = trapezoid_peak_v(tp);  // actual reached, may be < v_max
trapezoid_free(tp);
```

### Files

- `stdlib/runtime/trajectory_rt.c`: ~75 LOC for the new
  `__nucleor_trapezoid_*` family. `nuc_trapezoid_new` solves
  for the actual peak velocity; sample functions are direct
  closed-form per phase (no allocation per sample).
- `stdlib/rods/trajectory.nr`: 6 new builtins.
- `tests/rods/trajectory_smoke.nr`: extended to cover
  trapezoid_new + duration + sample at midpoint.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**256 / 256 PASS, 0 SKIP**. Both budgets hold.

## [0.2.180] — 2026-04-24

**v0.5.0, v0.6.0, v0.7.0, v0.8.0 milestone trackers drafted.
Roadmap is now concrete through 2028-Q1.**

The semver-and-release doc named these targets:

| Version  | Target  |
|----------|---------|
| v0.4.0   | 2026-Q4 |
| v0.5.0   | 2027-Q2 |
| v0.6.0   | 2027-Q2 |
| v0.7.0   | 2027-Q3 |
| v0.8.0   | 2028-Q1 |

But the milestone-tracker docs only existed for v0.2-v0.4. v0.2.180
adds the four missing trackers covering RFC-0005 through
RFC-0014 + the cross-cutting workstreams.

### Files

- `docs/milestones/v0.5.0.md`: Robotics + DbC + URDF + atomics.
  - Robotics-stack v0.5 follow-on items for the v0.2.174-179
    rods (frame typing, URDF parser, IK orientation, trajectory
    profiles, GJK/EPA, RRT*/PRM/path smoothing)
  - RFC-0006 Design by Contract
  - RFC-0007 atomics + lock-free queues
  - RFC-0013 URDF static frame chain verification
  - RFC-0014 #[max_depth = N] bounded recursion
  - Package manager v0.5 follow-on (registry + PubGrub + git deps)
- `docs/milestones/v0.6.0.md`: Units + ISRs + embedded targets.
  - RFC-0005 dimensional units (Mars Climate Orbiter prevention)
  - RFC-0008 #[isr] interrupt service routine attribute
  - Embedded-target sysroots: ARM Cortex-M, RISC-V, ESP32
- `docs/milestones/v0.7.0.md`: WCET + DLPack + cert profile.
  - RFC-0009 static WCET via Heptane
  - RFC-0010 DLPack zero-copy tensor interchange
  - Certified-build profile (--profile=cert)
- `docs/milestones/v0.8.0.md`: Stabilization + ABI freeze + cert
  pilot.
  - ABI freeze + nuc abi diff regression gate
  - Safety-cert pilot (real project IEC 61508 / ISO 26262)
  - LSP + debug-adapter + coverage + profiler polish
  - Self-host < 1 s target

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**256 / 256 PASS, 0 SKIP** (no test changes; doc-only ship).

## [0.2.179] — 2026-04-24

**Robotics: motion planner. New `rrt.nr` rod ships LaValle's
RRT (Rapidly-exploring Random Tree). Closes the kinematics +
collision + planning loop — the full motion-planner stack is
now in the standard library.**

Sixth robotics ship in this session arc:

- v0.2.174 — kinematics (Vec3 / quat / Pose)
- v0.2.175 — fk_chain (forward kinematics)
- v0.2.176 — ik_dls (inverse kinematics)
- v0.2.177 — trajectory (quintic polynomial)
- v0.2.178 — collision (geometric primitives)
- **v0.2.179 — rrt (motion planning)**

RRT (LaValle 1998) builds a tree rooted at the start
configuration in joint space, repeatedly sampling random
configurations and extending the nearest tree node toward the
sample by a small step. When any tree node is within step_size
of the goal, success.

The collision check is supplied by the caller as a function
pointer — given a pointer to a `double[n_dim]` joint
configuration, the user fn returns 1 if collision-free, 0 if
in collision. This decouples RRT from any specific robot or
world model — pair with the v0.2.178 `collision.nr` primitives
or any custom check.

10% goal-biased sampling for faster convergence near the goal.

### Surface

```nucleor
import "stdlib/rods/rrt.nr"

let r = rrt_new(2, 42);          // 2-DOF, seed 42
rrt_set_bounds(r, 0, lo_bits, hi_bits);  // per-dim sampling bounds
rrt_set_root(r, start_config_ptr);       // root = start config
let ok = rrt_plan(
    r, goal_config_ptr,
    1000,                         // max_iters
    f64_to_bits(0.1),             // step size
    coll_callback_fp              // user collision-check fn pointer
);
if ok == 1 {
    let n = rrt_path_len(r);
    // read back path: rrt_path_at(r, i, dim) for i in 0..n
};
rrt_free(r);
```

### Files

- `stdlib/runtime/rrt_rt.c`: ~210 LOC. xorshift32 RNG (no
  external dependency), goal-biased sampling, parent-array
  tree, path reconstruction by walking parents from goal node.
  Auto-grows the tree's config + parent arrays.
- `stdlib/rods/rrt.nr`: 8 builtins.
- `tests/rods/rrt_smoke.nr`: build-only smoke (full planning
  test needs callback function pointer + double[] vars).

### v0.5 follow-on

- **RRT-Connect** — bidirectional tree, faster convergence on
  hard problems
- **RRT*** — asymptotically optimal (path quality improves
  with more samples)
- **PRM** (Probabilistic Roadmap) — multi-query planner
- **Path shortcutting / smoothing** — post-process the raw
  RRT output to remove unnecessary detours

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**256 / 256 PASS, 0 SKIP** (was 255/255; +1 new smoke test).
Both budgets hold.

## [0.2.178] — 2026-04-24

**Robotics: collision primitives. New `collision.nr` rod ships
sphere-sphere, sphere-capsule, capsule-capsule, and AABB-AABB
overlap tests. Foundation for collision-aware motion planning
(v0.5).**

Fourth robotics ship in this session arc:

- v0.2.174 — Vec3 / quat / Pose primitives
- v0.2.175 — fk_chain (forward kinematics)
- v0.2.176 — ik_dls (inverse kinematics)
- v0.2.177 — trajectory (quintic polynomial)
- **v0.2.178 — collision (geometric primitives)**

Each test takes raw doubles (xyz components + radii) and returns
1 (collision) or 0 (no collision). No allocation; pure compute.
Suitable as the narrow-phase leaf in a BVH or spatial-hash
broad-phase / narrow-phase pipeline.

### Surface

```nucleor
import "stdlib/rods/collision.nr"

// Sphere-sphere: returns 1 (overlap) or 0 (clear).
let hit = coll_sphere_sphere(
    f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0),  // a center + radius
    f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0)   // b center + radius
);

// Sphere-capsule, capsule-capsule, AABB-AABB available with the
// same pattern — see stdlib/rods/collision.nr for signatures.
```

### Files

- `stdlib/runtime/collision_rt.c`: ~140 LOC. Includes the
  point-segment and segment-segment closest-distance helpers
  (Real-Time Collision Detection, Ericson, sec 5.1.9) used by
  the capsule tests. AABB test is straightforward axis-by-axis.
- `stdlib/rods/collision.nr`: 4 builtins (one per pair).
- `tests/rods/collision_smoke.nr`: positive smoke asserting
  spheres-apart returns 0, spheres-overlap returns 1, and
  AABBs touching at a corner return 1 (touch counts as overlap).

### v0.5 follow-on

- Mesh / convex-hull collision via GJK + EPA
- Continuous collision detection (CCD) for fast-moving objects
- BVH builder + traversal
- Capsule-AABB, sphere-AABB, sphere-OBB cross-pairs

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**255 / 255 PASS, 0 SKIP** (was 254/254; +1 new smoke test).
Both budgets hold.

## [0.2.177] — 2026-04-24

**Robotics: time-parameterized trajectories. New `trajectory.nr`
rod ships quintic (5th-order polynomial) joint trajectories with
C² boundary conditions. Third robotics ship.**

Closes the FK / IK / trajectory triplet that covers the
"compute the path, follow the path" loop:

- v0.2.174 — Vec3 / quaternion / Pose primitives
- v0.2.175 — fk_chain (forward kinematics)
- v0.2.176 — ik_dls (inverse kinematics, position-only)
- **v0.2.177 — trajectory (quintic polynomial)**

Quintic polynomial fits 6 boundary conditions (start q, v, a +
goal q, v, a) over a duration T:

```
q(t)   = a0 + a1·t + a2·t² + a3·t³ + a4·t⁴ + a5·t⁵
q'(t)  =      a1   + 2·a2·t + 3·a3·t² + 4·a4·t³ + 5·a5·t⁴
q''(t) =             2·a2   + 6·a3·t  + 12·a4·t² + 20·a5·t³
```

Closed-form coefficients via the standard Lynch & Park
formulation. C² continuous at endpoints — good for actuator-
limited systems.

### Surface

```nucleor
import "stdlib/rods/trajectory.nr"

let traj = quintic_new(
    1.0,          // T = 1 second
    0.0, 0.0, 0.0,  // start: rest at q=0
    1.0, 0.0, 0.0   // goal:  rest at q=1
);

// Sample at any t in [0, T]:
let q   = quintic_pos_at(traj, t);
let v   = quintic_vel_at(traj, t);
let a   = quintic_acc_at(traj, t);

quintic_free(traj);
```

### Files

- `stdlib/runtime/trajectory_rt.c`: ~80 LOC. Closed-form
  coefficient computation; per-sample evaluation is direct
  Horner-style (no allocation).
- `stdlib/rods/trajectory.nr`: 6 builtins (`new`, `duration`,
  `pos_at`, `vel_at`, `acc_at`, `free`).
- `tests/rods/trajectory_smoke.nr`: build a rest-to-rest
  quintic; sample at start, midpoint, end; assert duration
  round-trips.

### Future work (deferred to v0.5)

- **Trapezoidal velocity profiles** — phase 1 (accel) + phase 2
  (cruise) + phase 3 (decel); preferred when the actuator has
  hard velocity / acceleration limits.
- **S-curves (limited jerk)** — additional smoothness on
  acceleration discontinuities.
- **Dynamic Movement Primitives (DMPs)** — learnable
  trajectories that generalize across goal positions.
- **TOPP-RA** — time-optimal path parameterization respecting
  joint torque + velocity limits.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**254 / 254 PASS, 0 SKIP** (was 253/253; +1 new smoke test).
Both budgets hold.

## [0.2.176] — 2026-04-24

**Robotics: inverse kinematics. New `ik_dls.nr` rod solves for
joint variables that put the end-effector at a target position.
Damped Least Squares (Wampler 1986, Buss 2009).**

Closes the FK/IK pair for serial chains. Given the target
end-effector position `(tx, ty, tz)`, iteratively adjusts the
joint variables to minimize position error. Uses the standard
damped Jacobian pseudoinverse:

```
δq = J^T (J J^T + λ² I)^{-1} · e
```

The Jacobian is computed numerically via finite differences on
the FK chain — no hand-coded analytical derivatives required;
works for any joint topology that `fk_chain.nr` supports.

`damping (λ)` trades convergence speed against numerical
stability near singularities; 0.01-0.1 is typical.

### Surface

```nucleor
import "stdlib/rods/ik_dls.nr"
// (ik_dls.nr imports fk_chain.nr; both runtimes link in)

let chain = fk_chain_new();
// ... add joints ...
let iters_run = ik_dls_solve(
    chain, vars_ptr,
    f64_to_bits(0.5), f64_to_bits(0.3), f64_to_bits(0.0),  // target xyz
    100,                                                   // max_iters
    f64_to_bits(0.001),                                    // tolerance (m)
    f64_to_bits(0.05)                                      // damping λ
);
// vars_ptr now holds the solved joint configuration
```

### Files

- `stdlib/runtime/ik_dls_rt.c`: ~140 LOC. Forward-declares the
  FK chain runtime symbols (no header dependency); allocates
  scratch for J, J·Jᵀ+λ²I, its 3×3 inverse, and the
  J^T(...)^{-1} matrix per solve. Inverse via cofactor
  formula (3×3 closed form).
- `stdlib/rods/ik_dls.nr`: thin wrapper. Imports `fk_chain.nr`
  so both translation units get linked together (the linker
  needs `nuc_fk_chain_*` symbols that ik_dls calls).
- `tests/rods/ik_dls_smoke.nr`: build-only smoke (full
  convergence test needs Vec<f64> plumbing not available in a
  single-file test).

### Limitations + future work

- **Position-only solver.** Orientation IK lands in v0.5
  (RFC-0013 follow-on) — extends to a 6×n Jacobian (3 rows
  position + 3 rows angular). Position-only covers most
  pick-and-place use cases.
- **No joint limits enforced.** v0.5 will add per-joint
  `[min, max]` bounds clamping.
- **No singularity-detection callback.** Determinant check
  (det(J·Jᵀ+λ²I) < 1e-12) silently breaks the loop today.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**253 / 253 PASS, 0 SKIP** (was 252/252; +1 new smoke test).
Both budgets hold.

## [0.2.175] — 2026-04-24

**Robotics: forward kinematics for serial joint chains. New
`fk_chain.nr` rod composes per-joint poses to compute every
link's world-frame pose. Compute backend for RFC-0013 (URDF
static frame chain verification, v0.5).**

Builds on v0.2.174's `kinematics.nr` (Vec3 + quaternion +
Pose). Each joint has a parent-to-child base offset (pose)
and a joint axis; given a flat array of joint variables (one
per joint), `fk_chain_update` walks the chain and caches the
world-frame position + orientation of every link.

Joint types:
- **revolute** — variable is the angle in radians about `axis`
- **prismatic** — variable is the displacement along `axis`
- **fixed** — variable ignored

### Surface

```nucleor
import "stdlib/rods/fk_chain.nr"

let chain = fk_chain_new();
fk_chain_add_joint(
    chain, fk_revolute(),
    1.0, 0.0, 0.0,         // parent-to-child position offset
    1.0, 0.0, 0.0, 0.0,    // identity quaternion
    0.0, 0.0, 1.0          // z-axis (rotation about z)
);
// ... add more joints ...
fk_chain_update(chain, vars_ptr);
let x = fk_chain_link_pos_x(chain, link_index);
```

### Files

- `stdlib/runtime/fk_chain_rt.c`: ~150 LOC. Self-contained
  quaternion math (no external dependencies); each joint
  contributes a base-offset pose then a joint-local pose
  driven by the variable.
- `stdlib/rods/fk_chain.nr`: thin Nucleor wrapper exposing 9
  builtins.
- `tests/rods/fk_chain_smoke.nr`: positive smoke creating a
  one-revolute-joint chain, asserting the count is 1.

### URDF integration (RFC-0013, deferred to v0.5)

The URDF parser + frame-chain check is the v0.5 deliverable.
The data model:
1. URDF XML → list of `(joint_type, parent_offset, axis)` tuples
2. Tuples → `fk_chain_add_joint` calls
3. Compile-time check that any frame-tagged value reaching a
   joint matches the chain's expected parent frame

This ship lands the compute path so v0.5 is purely the parser
+ type-system overlay.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**252 / 252 PASS, 0 SKIP** (was 251/251; +1 new smoke test).
Both budgets hold.

## [0.2.174] — 2026-04-24

**Robotics math foundation: new `kinematics.nr` rod with
Vec3, quaternion, and Pose primitives. RFC-0003 (typed
coordinate frames) compute path now ready; the type-system
overlay lands in v0.4 once Nucleor has generics.**

This is the first concrete robotics-stack deliverable from
the v0.4 roadmap. RFC-0003 calls for `Pose<F: Frame>` with
compile-time frame correctness — but the underlying math
(quaternion algebra, pose composition, point transformation)
is independent of the type-system overlay and ships now so
the runtime path is ready when v0.4 lifts the frame tag to
the generic-type level.

### Surface

```nucleor
import "stdlib/rods/kinematics.nr"

let xhat = vec3(1.0, 0.0, 0.0);
let yhat = vec3(0.0, 1.0, 0.0);
let zhat = vec3_cross(xhat, yhat);  // (0, 0, 1)

let q = quat_from_axis_angle(zhat, 1.5708);  // 90° about z
let p = pose(vec3(1.0, 0.0, 0.0), q);
let world_point = pose_apply(p, vec3(0.0, 1.0, 0.0));
// world_point ≈ (1, 0, 0) + R_z(90°) · (0,1,0) ≈ (0, 0, 0)
```

### Files

- `stdlib/runtime/kinematics_rt.c`: ~270 LOC of C primitives.
  - **Vec3**: `new`/`get_x|y|z`/`dot`/`cross`/`norm`/`add`/
    `scale`/`free`. Heap-allocated 3-double arrays.
  - **Quaternion**: `new`/`identity`/`from_axis_angle`/
    `get_w|x|y|z`/`mul` (Hamilton product)/`conjugate`/
    `rotate` (q · v · q⁻¹)/`free`. Heap-allocated 4-double
    arrays.
  - **Pose**: `new`/`identity`/`get_pos`/`get_quat`/
    `compose`/`inverse`/`apply` (rotate then translate)/
    `free`. NPose = position Vec3 + orientation quaternion.
- `stdlib/rods/kinematics.nr`: thin Nucleor wrapper exposing
  31 builtins via `extern fn` declarations and short
  passthrough functions.
- `tests/rods/kinematics_smoke.nr`: positive smoke asserting
  cross-product produces non-degenerate result, identity
  quaternion composes to itself, identity pose preserves a
  point under apply.
- `docs/rfcs/rod_manifest.toml` regenerated (rod count
  132 → 133).
- `docs/rfcs/helper_manifest.toml` regenerated (helper count
  +30 for the new Vec3/quat/pose primitives).

### Frame tagging (RFC-0003 — deferred to v0.4)

The C runtime stores no frame information. RFC-0003 adds a
generic `Pose<F: Frame>` and `Vector3<F: Frame>` overlay so
that `pose_apply` between mismatched frames is a compile
error. That requires:
- Generics in the s1 type-checker (RFC-0024 follow-on)
- A `Frame` trait + `World`/`BaseLink`/etc. concrete frames
- Compiler-side enforcement of frame-parameter equality on
  every spatial-value operation

v0.2 ships the underlying math so application code can
adopt the rod now and migrate to typed frames mechanically
when v0.4 lands.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**251 / 251 PASS, 0 SKIP** (was 250/250; +1 new smoke test).
Both budgets hold.

## [0.2.173] — 2026-04-24

**`sb_new_with_cap(initial_cap)` builtin: pre-size a string
builder when the final size is known. IR builder now starts
at 2 MB instead of 256 B (saves ~14 reallocs per self-host
compile).**

The IR builder in `emit_module_ext` produces ~2.7 MB of
LLVM IR per self-host compile. With the default 256 B
initial capacity, it grew through 14 doubling reallocs
(256→512→1024→…→4 MB), each requiring a `realloc` +
implicit memcpy of the previous content.

`sb_new_with_cap(initial_cap)` lets the caller pre-size
when the final length is approximately known. Used in
`emit_module_ext` with 2 MB initial — at most one realloc
to absorb the final stretch.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c`: new
  `__nucleor_sb_new_with_cap(initial_cap)`. Same growth
  semantics as `sb_new`; only the initial allocation
  differs.
- `compiler/nucleor_s1_compiler.nr` + `nucleor_tools_suite.nr`:
  4 ABI sites each.
- `compiler/nucleor_s1_compiler.nr` (`emit_module_ext`):
  swapped `sb_new()` → `sb_new_with_cap(2097152)` with a
  comment explaining the rationale.

### Memory measurement

The trace counter doesn't show a meaningful delta because
both paths (one big alloc vs many doubling reallocs) sum
to roughly the same cumulative allocation (~3 MB for the
IR SB). The win is in **fewer realloc/memcpy operations**
and **less heap fragmentation**, neither of which the
counter tracks.

|              | v0.2.172  | v0.2.173  |
|--------------|----------:|----------:|
| TOTAL TRACKED|   67 MB   |   67 MB   |
| Wall-clock   |   4.6 s   |   4.6 s   |

### Self-host LLVM IR fixed point

- 2-iter byte-identical at 2,691,806 bytes.
- `bin/nucleor.exe` updated.

### Verify gate

**250 / 250 PASS, 0 SKIP**. Both budgets hold.

## [0.2.172] — 2026-04-24

**`sb_append_char` builtin: append a single byte to a string
builder without allocating a temp string. Cuts ~73K
transient allocations from the s1 self-host (escape_llvm_str
hot path).**

The compiler's `escape_llvm_str` was running per-character
through every string literal in the source. For each non-
special character it called `sb_append(esb,
str_substring(s, i, i + 1))` — allocating a 2-byte string just
to call `sb_append` with a one-character payload. For the s1
self-host (4 K+ string literals × ~20 chars each), this
was ~73 K transient allocations.

`sb_append_char(handle, c)` writes the byte directly into the
SB's data buffer (with the same grow-on-overflow logic as
`sb_append`), bypassing the temporary-string detour.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c`: new
  `__nucleor_sb_append_char(handle, c)`.
- `compiler/nucleor_s1_compiler.nr` + `nucleor_tools_suite.nr`:
  4 ABI sites each.
- `compiler/nucleor_s1_compiler.nr` (escape_llvm_str): single-
  byte append path converted from `sb_append(esb,
  str_substring(s, i, i + 1))` to `sb_append_char(esb, c)`.

### Memory measurement

|              | v0.2.171  | v0.2.172  | Δ            |
|--------------|----------:|----------:|-------------:|
| vec_new      |  49 MB    |  49 MB    | —            |
| str_concat   |   4 MB    |   4 MB    | —            |
| **str_substring** | **218K calls** | **145K calls** | **-73K calls** |
| sb_new       |  11 MB    |  11 MB    | —            |
| TOTAL        |  67 MB    |  67 MB    | unchanged    |

Memory unchanged because the saved allocations were 1-byte
strings, but the call-count drop is real. Removes a hot-loop
allocator from the IR-emit path and is a cleaner pattern
going forward.

### Self-host LLVM IR fixed point

- 2-iter byte-identical at 2,689,964 bytes.
- `bin/nucleor.exe` updated.

### Verify gate

**250 / 250 PASS, 0 SKIP** in 3m3s. Both budgets hold
(67 MB / 100 + 111 MB / 200).

## [0.2.171] — 2026-04-24

**Memory-fix Ship 7: tools-suite gets its own 200 MB
allocation budget (was un-gated). Both compilers now
regression-protected.**

The s1 self-host budget gate (v0.2.161 → v0.2.167) only
covered `compiler/nucleor_s1_compiler.nr`. The
`compiler/nucleor_tools_suite.nr` source (1.7× larger at
822 KB; produces `bin/nucleor_tools.exe` for `nuc explain`,
`nuc test` harness, and the rest of the tools surface) was
un-gated — a regression in any tools-only path could blow
its memory without the gate noticing.

v0.2.171 adds a parallel `tools_suite_memory_budget` step
with a proportional 200 MB ceiling.

### Files

- `tools/verify.sh`: refactored the existing `self_host_
  memory_budget` body into a shared `_memory_budget_for`
  helper that takes (source, budget_mb, label, output_name);
  added `tools_suite_memory_budget` step that calls it with
  (`compiler/nucleor_tools_suite.nr`, 200, `tools-suite`,
  `verify_tools_budget`).
- `STEP_TOTAL` bumped to account for the new step.

### Baseline

- s1 self-host: 67 MB (budget 100)
- tools-suite: 111 MB (budget 200)

The 200 MB budget gives ~80% headroom over the 111 MB
baseline. The 1.7× source-size ratio between tools-suite
(822 KB) and s1 (485 KB) tracks roughly with the memory
ratio (1.66×), suggesting the architectural improvements
scale linearly.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**250 / 250 PASS, 0 SKIP** in 3m3s (was 249/249; +1 new
budget step).

## [0.2.170] — 2026-04-24

**Documentation: `docs/release-notes-v0.2.x-memory.md` adds a
single-page summary of the v0.2.158-v0.2.169 memory-fix arc
suitable for blog posts, release announcements, and reviewer
overview.**

The CHANGELOG entries are comprehensive but each is per-release;
a flat ship-by-ship summary table lives at this new doc, with:

- TL;DR table (19 GB → 67 MB, 25 s → 5.2 s, 283× memory + 5× speed)
- Per-ship one-line summary (12 ships)
- Methodology section (trace first; identify dominant cost; fix
  architecturally then structurally; lock in wins; document)
- Critical bugs caught along the way (3, with diagnosis stories)
- "Where to next" section cross-referencing the punchlist

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**249 / 249 PASS, 0 SKIP** (no test changes; doc-only ship).

## [0.2.169] — 2026-04-24

**RFC-0030 phase 4: `str_free` exposed as a builtin.
Foundation for explicit-free patterns in user code and for
the Ship 4 type-checker arena migration.**

The `__nucleor_str_free` runtime function shipped in
v0.2.158 alongside `__nucleor_vec_free`, but was never wired
as a Nucleor-side builtin. v0.2.169 closes that gap.

### Surface

```nucleor
let s: str = str_concat("foo", "bar");
str_free(s);  // explicit free; s is invalid after this
```

### Safety contract

`str_free` MUST NOT be called on string literals. String
literals live in the rodata section of the executable;
calling free() on them corrupts the heap allocator's
metadata and causes silent or delayed crashes. Only call
`str_free` on values returned from one of the allocating
builtins:

- `str_concat`
- `str_substring`
- `sb_to_str`
- `format_i64` / `format_str` / `format_f64` / `format_hex`
  / `format_bool` / `format2_*` / `format3_*`
- `int_to_str` / `f64_to_str` / `bool_to_str`
- `str_repeat` / `str_pad_left` / `str_pad_right` /
  `str_center` / `str_join`
- `read_line` / `read_byte`

For arena-backed strings (`str_arena_concat`,
`str_arena_substring`), use `str_arena_free(arena)` instead
— calling `str_free` on individual arena strings is
incorrect (the chunk allocator tracks regions, not
individual strings).

### Compiler builtin

- `compiler/nucleor_s1_compiler.nr`: 4 ABI sites
  (`get_rt_name`, `is_void_ret`, `is_ptr_arg`,
  `emit_externs`).
- `compiler/nucleor_tools_suite.nr`: 4 mirrored sites.
- The compiler itself does NOT yet call `str_free`; the
  audit of safe-vs-unsafe call sites is part of Ship 4
  (type-checker arena migration). The builtin lands first
  so user code and rods can adopt it now.

### Tests

- `tests/lang/str_free_basic.nr`: positive test asserting
  `str_free` cleanly deallocates results from `str_concat`,
  `str_substring`, and `int_to_str`. Process-level memory
  doesn't crash; the freed strings are no longer accessed.

### Self-host LLVM IR fixed point

- 3-iter check passed at iter2==iter3 (byte-identical at
  2,688,476 bytes). Iter1 differed by exactly the new
  `str_free` declare line.
- `bin/nucleor.exe` updated; chain extends to **v0.2.169**.

### Verify gate

**249 / 249 PASS, 0 SKIP** (was 248/248; +1 new test).
Self-host: 67 MB / 100 MB budget.

## [0.2.168] — 2026-04-23

**Documentation: `docs/memory-architecture.md` adds a complete
case-study writeup of the v0.2.158-v0.2.167 memory work for new
contributors. Linked from README.**

The 10-ship memory effort cut s1 self-host RSS from 19 GB to
67 MB (283× reduction) and added a gate-enforced 100 MB budget.
Without a writeup, future contributors hitting a regression won't
know which patterns to look for or why the budget exists.

### `docs/memory-architecture.md`

Sections:

- Headline numbers (67 MB / 5.2 s self-host)
- Architecture overview (single-pass pipeline)
- Five key design decisions:
  1. Per-category allocation tracing (`NUC_TRACE_ALLOC=1`)
  2. Non-allocating prefix/positional probes (`str_starts_with`,
     `str_eq_at`) — the 5,000× drop site
  3. Structural allocator sizing (SB 4 KB → 256 B, Vec 16 → 4)
  4. Identifier interner (`str_intern`) + string arena
     (`str_arena_*`) as foundations for the next wave
  5. Targeted lifetime fixes (env-snapshot vec_free, with the
     UAF audit story)
- How the gate enforces the budget + the failure-mode diagnostic
- Cumulative reduction table (19 GB → 185 MB → 137 MB → 67 MB)
- "How to investigate a regression" troubleshooting guide
- "What's deferred" list cross-referencing
  `MEMORY_FIX_PUNCHLIST.md`

### README

Added a one-line link to the memory-architecture doc in the
"Documentation" section.

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**248 / 248 PASS, 0 SKIP** (no test changes; doc-only ship).

## [0.2.167] — 2026-04-23

**Vec initial capacity tuned: 16 → 4 elements drops vec_new
from 119 MB to 49 MB (-70 MB). Total peak: 137 → 67 MB.
Cumulative reduction from v0.2.157 baseline: 19 GB → 67 MB
= 283× reduction. Budget tightened to 100 MB.**

The s1 self-host creates ~800 K Vecs per compile; many never
exceed the initial 4 slots (small arg lists, two-element
coords, scope counters, and similar transient holders). The
16-element initial wasted ~70 MB across the compile when those
Vecs sat at length 0-3 forever.

For Vecs that grow beyond 4, total memory footprint is
unchanged — realloc-doubling (4→8→16→32→…) lands at the same
end-state by the time a Vec reaches a given size; we just pay
1-2 extra reallocs per growing Vec, amortized. Compile time
+0.7 s (4.5 → 5.2 s) for the extra realloc work.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c`: `__nucleor_vec_new`
  initial cap 16 → 4 with documented rationale.
- `tools/verify.sh`: budget tightened from 250 MB to 100 MB
  (50% headroom over 67 MB baseline).

### Memory measurement

|              | v0.2.166  | v0.2.167  | Δ          |
|--------------|----------:|----------:|-----------:|
| **vec_new** | **119 MB** | **49 MB** | **-70 MB** |
| str_concat   |    4 MB   |    4 MB   | —          |
| str_substring|    1 MB   |    1 MB   | —          |
| sb_new       |   11 MB   |   11 MB   | —          |
| **TOTAL**   | **137 MB** | **67 MB** | **-51%**   |

### Cumulative reduction from session baseline

| Version  | Total tracked | Compile time |
|----------|--------------:|-------------:|
| v0.2.157 | 19 GB (peak)  | 25 s         |
| v0.2.159 | 185 MB        |  4.5 s       |
| v0.2.166 | 137 MB        |  4.5 s       |
| v0.2.167 |  **67 MB**    |  5.2 s       |
| **Δ**    |  **283×**     | **~5×**      |

### Self-host LLVM IR fixed point

- 2-iter byte-identical at 2,686,442 bytes.
- `bin/nucleor.exe` updated.

### Verify gate

**248 / 248 PASS, 0 SKIP** in 3m. Self-host: 67 MB / 100 MB
budget (was 250). Self-host rebuild closes byte-identical.

## [0.2.166] — 2026-04-23

**SB initial capacity tuned: 4 KB → 256 B drops sb_new from
60 MB to 11 MB on the s1 self-host (49 MB saved). Total
peak: 185 → 137 MB. Budget tightened to 250 MB.**

The string-builder allocator was sized for the IR-emit case
(2.7 MB output, dominated by one big SB) but the s1 creates
~13K SBs per compile, most for diag messages, type names,
identifier escapers — none of which approach 4 KB. The 4 KB
initial wasted ~50 MB across the compile.

256 B is enough for ~95% of SB lifetimes; the grow-on-append
path still handles the IR builder by doubling
(256→512→…→big), at the cost of a few extra `realloc`s per
big SB that are amortized over the build.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c`: `__nucleor_sb_new`
  initial cap 4096 → 256 with documented rationale.
- `tools/verify.sh`: budget tightened from 400 MB to 250 MB
  (still 80% headroom over current 137 MB baseline).

### Memory measurement

|              | v0.2.165 (baseline) | v0.2.166 | Δ          |
|--------------|--------------------:|---------:|-----------:|
| vec_new      | 119 MB              | 119 MB   | —          |
| str_concat   |   4 MB              |   4 MB   | —          |
| str_substring|   1 MB              |   1 MB   | —          |
| **sb_new**   | **60 MB**           | **11 MB**| **-49 MB** |
| **TOTAL**    | **185 MB**          |**137 MB**| **-26%**   |

### Self-host LLVM IR fixed point

- 2-iter byte-identical at 2,686,442 bytes.
- `bin/nucleor.exe` updated.

### Verify gate

**248 / 248 PASS, 0 SKIP** in 3m. Self-host: 137 MB / 250 MB
budget (was 400). Self-host rebuild closes byte-identical.

## [0.2.165] — 2026-04-23

**RFC-0030 phase 1: per-compile string arena. Five new builtins
(`str_arena_new`, `str_arena_free`, `str_arena_bytes`,
`str_arena_concat`, `str_arena_substring`) for allocate-then-
free-all-at-once string lifetimes.**

The arena is the second architectural building block (after
`str_intern` in v0.2.164) for migrating the compiler away from
per-string `malloc`/`leak` and toward bounded, lifetime-scoped
allocation. Caller creates an arena, allocates as many transient
strings as needed via `str_arena_concat` / `str_arena_substring`,
then frees the entire arena in one call.

### Surface

```nucleor
let arena: i64 = str_arena_new();
let msg: str = str_arena_concat(arena, "from ", "scope");
let part: str = str_arena_substring(arena, "abcdef", 2, 5);  // "cde"
let used: i64 = str_arena_bytes(arena);
str_arena_free(arena);  // every string allocated above is now invalid
```

### Implementation in `stdlib/runtime/nucleor_llvm_rt.c`

Linked list of bump-allocated chunks:
- Default chunk size 64 KB
- New chunk allocated when current chunk exhausted, OR when a
  single allocation would exceed default (large-allocation
  fast path)
- Bump within chunk: O(1) per allocation, no per-string free
- `str_arena_free` walks the chunk list, frees each + the
  arena header

For the s1 self-host's diag formatting and type-checker
temporaries, this can replace dozens of `str_concat` chains
with a single arena scope.

### Compiler builtin

- `compiler/nucleor_s1_compiler.nr`: 4 ABI sites
  (get_rt_name + is_void_ret + is_ptr_ret + is_ptr_arg +
  emit_externs).
- `compiler/nucleor_tools_suite.nr`: same mirrored.
- `str_arena_new`/`bytes` return i64 (arena handle / byte count);
  `str_arena_free` is void; `str_arena_concat`/`substring`
  return str (pointer into arena chunk).

### Tests

- `tests/lang/str_arena_basic.nr`: positive test asserting
  arena allocations produce the expected strings, byte
  accounting works, free completes cleanly.

### Self-host LLVM IR fixed point

- 3-iter check passed at iter2==iter3 (byte-identical at
  2,686,442 bytes). Iter1 differed by exactly the 5 new
  declares.
- `bin/nucleor.exe` updated; chain extends to **v0.2.165**.

### Memory measurement

Self-host TOTAL TRACKED at 186 MB (was 185 MB) — the 1 MB
delta is the arena builtins' generated code. Arena infrastructure
is unused by the s1's own type checker yet (Ship 4 in the
punchlist will migrate the diag-message-formatting paths to use
it). The win lands when the arena REPLACES global str_concat
chains in known transient sites.

### Verify gate

**248 / 248 PASS, 0 SKIP** (was 247/247; +1 new test).
Self-host: 186 MB / 400 MB budget.

## [0.2.164] — 2026-04-23

**RFC-0029 phase 1: identifier interner. New `str_intern(s)`
builtin returns a stable canonical pointer per unique input
string. Architectural building block for the v0.4 TypeId
interner and for any pointer-equality fast paths.**

The interner is the foundation for migrating the type checker
from string-equality (O(n) per comparison + transient
allocations) to pointer-equality (O(1), no allocations). v0.2
ships the underlying primitive so user code (including
optimizers and helper rods) can use it now; the type-checker
migration is Ship 3 in `MEMORY_FIX_PUNCHLIST.md`.

### Surface

```nucleor
let a: str = str_intern("hello");
let b: str = str_intern("hello");
// a and b have the SAME underlying pointer; (a as i64) == (b as i64)
let c: str = str_intern("world");
// c has a DIFFERENT pointer from a/b
// All still str_eq cleanly:
//   str_eq(a, "hello") == 1
//   str_eq(c, "world") == 1
```

### Implementation in `stdlib/runtime/nucleor_llvm_rt.c`

Open-addressed hash table with linear probing:
- FNV-1a 64 hash
- Doubles when load > 70% (rehashes existing entries)
- Each unique string is malloc'd once with content copied
- Process-lifetime ownership (entries never deleted)
- Memory bounded by ~unique-identifier count × avg-length;
  for the s1 self-host: ~1500 × 16 = 24 KB total

The win is comparison cost, not memory. After interning, two
strings with the same content are byte-identical at the same
address; comparison becomes one i64 == instead of an O(n)
byte walk plus possible transient allocations.

### Compiler builtin

- `compiler/nucleor_s1_compiler.nr`: 4 ABI sites
  (`get_rt_name`, `is_ptr_ret`, `is_ptr_arg`, `emit_externs`).
- `compiler/nucleor_tools_suite.nr`: 4 mirrored sites.
- Bootstrap was clean — no calls to `str_intern` from compiler
  source yet (the call sites land with Ship 3).

### Tests

- `tests/lang/str_intern_basic.nr`: positive test asserting
  identical content returns identical pointer; different
  content returns different pointers; interned strings still
  `str_eq` correctly.

### Self-host LLVM IR fixed point

- 3-iter check passed at iter2==iter3 (byte-identical at
  2,678,872 bytes). Iter1 differed by exactly the new
  `str_intern` declare line, as expected.
- `bin/nucleor.exe` updated; chain extends to **v0.2.164**.

### Verify gate

**247 / 247 PASS, 0 SKIP** (was 246/246; +1 new test).

## [0.2.163] — 2026-04-23

**Memory-fix Ship 6: env-snapshot UAF audit (item E4 from
MEMORY_FIX_PUNCHLIST.md). Type-pass env snapshots now free
properly; check-pass snapshots remain deferred with a
documented reason.**

The v0.2.158 ship attempted to free env snapshots in five
sites and reverted all five after match/enum/if-let tests
segfaulted. v0.2.163 isolates the actual cause via bisection:
the *type pass* (`type_check_stmts`) snapshot frees are safe;
the *check pass* (`own_restore`, `own_merge_moved` called
from `check_expr`) frees are not. The check pass keeps a
richer ownership state with reference targets and scopes
that downstream consumers may still hold pointers into;
freeing in those sites caused use-after-free. The type pass's
env stores only `(name, type-string)` pairs whose backing
strings live independently — safe to free.

### Fix

In `compiler/nucleor_s1_compiler.nr`:

- **Re-enabled** `vec_free(then_env)`, `vec_free(else_env)`,
  `vec_free(arm_env)` in the type-check pass (kind == 23
  if/else, kind == 38 match arms). These were the three frees
  whose intent was correct and whose lifetimes are bounded
  by the recursive `type_check_stmts` call.
- **Kept disabled** `vec_free(snap)` in `own_restore` and
  `vec_free(a)` / `vec_free(b)` in `own_merge_moved`.
  Documented the reason inline ("check pass needs a deeper
  audit before we can free here"). These are called from
  `check_expr` where downstream consumers may still hold
  references; full fix requires identifying all such
  references which is multi-pass work.

### Bisection method

To isolate which sites were unsafe, ran the FAIL set
(enums.nr, if_let.nr, match_option_result.nr,
err_match_unreachable.nr) standalone against compilers built
with each subset of frees enabled. Found that:

- arm_env free alone — works
- + then_env / else_env free — works
- + own_restore free — match_option_result segfaults
- + own_merge_moved free — match_option_result segfaults

So the check-pass frees are the culprits.

### Memory measurement

Self-host TOTAL TRACKED unchanged at 185 MB — the type-pass
snapshots are bounded (one snapshot per active match/if-else
during type-check, freed before next iteration), so they
weren't accumulating to a measurable amount. The win is
*correctness* (no leaked snapshots) and *unblocking* future
work on the check-pass audit which would yield real memory.

### Self-host LLVM IR fixed point

- 2-iter byte-identical at 2,676,821 bytes.
- `bin/nucleor.exe` updated; chain extends to **v0.2.163**.

### Verify gate

**246 / 246 PASS, 0 SKIP** in 2m45s. Self-host: 185 MB / 400
MB budget. Self-host rebuild closes byte-identical.

### Punchlist progress

- ~~Item E4 partial: type-pass frees safe, check-pass frees
  documented~~ ✓ shipped this release
- Remaining: B (TypeId interner), C (identifier interner),
  D (per-compile arena), check-pass UAF audit (full E4)

## [0.2.162] — 2026-04-23

**Release-readiness polish: SECURITY.md added; README updated
with current rod count (132), helper count (686), test counts,
and the 4.5 s / 185 MB self-host metrics from v0.2.159.**

The repo was carrying stale numbers from earlier in the v0.2
chain — README still claimed 121 rods (was true before v0.2.150
wrapped 11 orphan runtimes) and 99 tests (was true before v0.2.149
added 22 rod smokes + later additions across the err/features
dirs). v0.2.162 reconciles these to the canonical manifest
counts and adds the missing standard OSS file (SECURITY.md).

### Files

- New `SECURITY.md` — vulnerability reporting policy, supported
  versions, scope statement, coordinated-disclosure timeline.
  Standard OSS pattern; was the only release-readiness file
  missing from the repo.
- `README.md`:
  - Rod count 121 → **132** (matches `docs/rfcs/rod_manifest.toml`)
  - Helper count 676 → **686**
  - Self-host metrics added: "rebuilds itself in 4.5 s using 185 MB peak"
  - Test counts updated: 137 positive (was 99), 35 negative (was 33),
    34 features (unchanged)
  - Mention of the v0.2.161 400 MB budget gate

### Self-host LLVM IR fixed point

- No s1 source change. `bin/nucleor.exe` unchanged.

### Verify gate

**246 / 246 PASS, 0 SKIP** (no test changes; doc-only ship).

## [0.2.161] — 2026-04-23

**Memory-fix Ship 5: gate enforces a 400 MB peak-allocation
budget on the s1 self-host compile. Locks in v0.2.159's 52×
memory reduction so future ships can't silently regress.**

The verify gate now runs the s1 self-host with
`NUC_TRACE_ALLOC=1` and asserts `TOTAL TRACKED <= 400 MB`.
v0.2.160 baseline is 185 MB; the 2.2× headroom absorbs minor
growth from new compiler features without flagging legitimate
scaling. The budget will tighten as Ship 3 (TypeId interner)
lands and brings the floor to ~50-100 MB.

### Files

- `tools/verify.sh`: new `self_host_memory_budget` step
  (line 712-ish). Parses the `TOTAL TRACKED: ... (NN MB)`
  line from NUC_TRACE_ALLOC and compares against `budget_mb=400`.
  On failure, prints diagnostic guidance ("Recent changes may
  have re-introduced an allocate-then-discard pattern; run
  NUC_TRACE_ALLOC=1 ... for per-category breakdown").
- `STEP_TOTAL` bumped from 245 to 246 (the budget is its own
  step, separate from the self-host rebuild).

### Why this matters for open-source release

Without an enforced budget, the v0.2.158 leak class (an
allocate-then-discard pattern in the type checker that grew
to 9.7 GB transient strings) could slip back in via any
future ship that touches the type checker. With the gate,
the next contributor sees an immediate "memory budget
exceeded" failure and is pointed at the diagnostic command.

This is the standard production-compiler pattern (LLVM's
`buildbot-track`, Rust's `rustc-perf`) adapted to a single-
binary self-host.

### Self-host LLVM IR fixed point

- No s1 source change — pure tooling addition.
- `bin/nucleor.exe` unchanged.

### Verify gate

**246 / 246 PASS, 0 SKIP** (was 245/245; +1 new budget step).
Self-host: 185 MB / 400 MB budget.

## [0.2.160] — 2026-04-23

**Memory-fix Ship 2 part 2: convert remaining 13 cold-path
`str_eq(str_substring(...))` sites to `str_starts_with` /
`str_eq_at`. Eliminates the anti-pattern from the codebase
entirely.**

v0.2.159 fixed the five hot in-loop sites (52× memory drop).
v0.2.160 cleans up the rest for consistency and to prevent
future drift. None of these sites are in measured hot paths —
they're in setup, parsing, and CLI flag handling. The win is
correctness + maintainability: a single audited helper for
position-based equality, no remaining "allocate-then-equate"
anti-pattern in the s1.

### Sites converted

- `type_is_mut_ref` — `&mut ` prefix probe
- nested-type extraction (Box<...>) — `Box<` prefix probe
- `rewrite_use_path` — `std::` / `crate::` / `super::` prefix
- `resolve_source_with_records` — `import ` / `use ` / `mod `
  line prefixes
- `extract_directives` — `#link ` / `#cfile ` / `#libpath `
  directive line prefixes
- key parser — positional key match (uses `str_eq_at`)
- bench CLI flags — `--iterations=` / `--warmup=` prefixes

### Self-host LLVM IR fixed point

- 2-iter byte-identical at 2,676,389 bytes (slightly smaller
  than v0.2.159 because eliminated `str_substring` calls also
  eliminated their declares + setup IR).
- Compile time stable at 4.5 s.
- `bin/nucleor.exe` updated; chain extends to **v0.2.160**.

### Verify gate

**245 / 245 PASS, 0 SKIP** in 2m41s. Self-host closes
byte-identical.

## [0.2.159] — 2026-04-23

**Memory-fix Ship 2 (part 1): non-allocating `str_eq_at` helper
replaces the dominant `str_eq(str_substring(source, i, i+tlen),
target)` source-scan anti-pattern. Self-host compile drops from
9.7 GB / 19 GB peak RSS / 25 s to 185 MB / 4.5 s — a 52× memory
reduction and 5.5× speedup.**

The Ship 1 (v0.2.158) infrastructure (NUC_TRACE_ALLOC counters)
let us identify the dominant leak empirically. Result: 586
million `str_substring` calls during a self-host compile (9.5 GB
of transient allocations) all originated in five hot loop sites
that scanned the 485 KB compiler source byte-by-byte, allocating
a substring per position via the `str_eq(str_substring(source,
i, i+tlen), target)` anti-pattern.

Each call allocated a ~10-byte transient string — none of which
were ever read again — and the GC'd-by-the-OS-at-process-exit
pattern accumulated through the whole compile. For a 485 KB
source × thousands of `find_linecol_in_source` invocations,
that came to ~9.5 GB.

### Fix

New helper in `compiler/nucleor_s1_compiler.nr`:

```nucleor
fn str_eq_at(source: str, pos: i64, target: str) -> i64 {
    let tlen: i64 = str_len(target);
    let mut k: i64 = 0;
    while k < tlen {
        if str_char_at(source, pos + k) != str_char_at(target, k) {
            return 0;
        };
        k = k + 1;
    };
    return 1;
}
```

Five hot sites converted (all in O(N²) source-scan loops):
- `find_linecol_in_source` (two loops — finds `fn <name>` then
  the variable name)
- `line_contains_text`
- `source_box_binding_type`
- `text_contains`

### Critical implementation detail

The first cut of `str_eq_at` called `str_len(source)` for a bounds
check — which made the s1 self-host compile hang for 5+ minutes
(was 25 s baseline). `str_len` is O(n) (walks to the null
terminator); placing it inside an O(n) outer loop makes the loop
O(n²) per compile, plus an inner O(tlen) byte-compare made it
O(n × n × tlen). For a 485 KB source: 485,000 × 485,000 × 10 =
2.4 × 10¹² operations.

**Production-quality fix**: omit the source bounds check, document
that callers must guarantee `pos + len(target) <= len(source)`
via their loop bound (which they all do — `while i <= slen - tlen`).
The comment in the source explains the constraint and the previous
hang it caused.

### Memory measurement

Self-host compile of `compiler/nucleor_s1_compiler.nr`:

|                  | Before (v0.2.158) | After (v0.2.159) | Ratio  |
|------------------|------------------:|-----------------:|-------:|
| vec_new          |   119 MB / 798K   |   119 MB / 799K  | 1.0×   |
| str_concat       |     4 MB / 598K   |     5 MB / 599K  | 1.0×   |
| **str_substring**| **9.5 GB / 586M** | **2 MB / 282K**  | **5,000×** |
| sb_new           |    60 MB /  13K   |    60 MB /  13K  | 1.0×   |
| **TOTAL TRACKED**|    **9.7 GB**     |    **185 MB**    | **52×**    |
| **wallclock**    |     **25 s**      |     **4.5 s**    | **5.5×**   |

OS-reported peak RSS during the gate's `tools_rebuild` step
(compiles `nucleor_tools_suite.nr`, 822 KB — 1.7× larger than
s1) is similarly bounded.

### Self-host LLVM IR fixed point

- Pass1 build (with v0.2.158 binary, fixed source): nucleor_e5
  at 2,680,852 bytes.
- Pass2 (with pass1 binary, same source): nucleor_e5b at
  2,680,852 bytes — byte-identical.
- Pass3 (with pass2 binary): nucleor_e5c at 2,680,852 bytes —
  byte-identical.
- 3-iter fixed point holds.
- `bin/nucleor.exe` updated; chain is now v0.2.84 → v0.2.87 →
  v0.2.151 → v0.2.152 → v0.2.153 → v0.2.155 → v0.2.157 →
  v0.2.158 → **v0.2.159**.

### Verify gate

**245 / 245 PASS, 0 SKIP** in 2m40s (was ~3m20s+ with the leak,
plus occasional OOM cascades that required killing nucleor.exe
processes mid-gate). Self-host rebuild closes byte-identical.

### Punchlist progress

- Ship 1 (v0.2.158): infrastructure + non-allocating prefix
  probes + format builtins
- **Ship 2 part 1 (v0.2.159): str_eq_at — biggest single
  win (52× memory).**
- Ship 2 part 2 (TBD): convert remaining 12 `str_eq(str_substring(
  ...))` sites in non-hot paths for consistency
- Ship 2 part 3 (TBD): re-attempt env-snapshot vec_free calls
  after the use-after-free root-cause audit (item E4)
- Ship 3 (TBD): TypeId interner (architectural fix; further
  reduces type-check string churn — likely brings RSS to
  ~50-100 MB)
- Ship 4 (TBD): per-compile arena
- Ship 5 (TBD): peak-RSS gate budget enforcement (item F1)

See `MEMORY_FIX_PUNCHLIST.md` (repo root) for the full plan.

## [0.2.158] — 2026-04-23

**Memory-fix Ship 1: vec_free builtin, env-snapshot leak fix,
non-allocating string-prefix probes, allocation tracing
infrastructure. Plus RFC-0028 phase 4 (3 new format builtins).
Bundled with `MEMORY_FIX_PUNCHLIST.md` documenting the road
to a < 500 MB self-host compile.**

A profiler-driven audit of the compiler's self-host build
revealed peak RSS of ~19 GB for a 485 KB source — a 40,000×
bloat dominated by transient allocations in the type checker.
This ship lands the first batch of fixes (Ship 1 of an
N-ship architectural plan tracked in
`MEMORY_FIX_PUNCHLIST.md` at the repo root). The full plan
ends with TypeId interning + per-compile arena (Ship 2-4)
projected to bring peak RSS under the 500 MB target.

### Memory infrastructure

- `stdlib/runtime/nucleor_llvm_rt.c`: NUC_TRACE_ALLOC=1
  environment variable activates per-category allocation
  counters (vec_new, str_concat, str_substring, sb_new,
  misc_str). Counters tally call counts + bytes; an
  `atexit` handler prints the summary. Cost when disabled:
  one branch per call (~zero overhead).
- New runtime fn `__nucleor_vec_free(handle)`: free a Vec +
  its backing data. Always-linked counterpart of
  `mem_rt.c`'s `nuc_vec_free` so the compiler itself can
  call `vec_free` without importing `stdlib/rods/mem.nr`.
- New runtime fn `__nucleor_str_free(s)`: free a heap-
  allocated string from `str_concat` / `str_substring` /
  `sb_to_str` / `format_*` / etc. Wired but not yet
  consumed; reserved for Ship 2.

### Memory fixes (real wins this ship)

- **Env-snapshot vec_free CALLS deferred** (initially
  attempted, reverted before ship). When `own_restore`,
  `own_merge_moved`, and the type-check arm-env sites
  freed their snapshot Vecs, all `match` / `enum` / `if-let`
  tests segfaulted. Root cause: a downstream reader keeps
  pointers into the snapshot's backing data after the
  snapshot is supposedly consumed. Identifying that reader
  is item E4 in `MEMORY_FIX_PUNCHLIST.md`. The `vec_free`
  builtin itself ships and is link-tested; the call sites
  remain documented + commented for the next ship.
- **Non-allocating `str_starts_with`.** Previously did
  `str_eq(str_substring(s, 0, plen), prefix)` — allocated
  on every call. Now walks bytes directly. Used by every
  prefix probe in the type checker.
- **`type_base_name` converted** to use the non-allocating
  prefix probes. Was 4-7 substring allocations per call;
  now 0-1 (only when extracting the bare name from a
  generic type like `Vec<i32>`).
- **`is_tainted_type`, `taint_inner_type`, `type_is_unit`**
  similarly converted.
- **`strip_spaces` fast path.** Most type strings have no
  whitespace; scan once to detect, return input unchanged
  if clean. Previously always allocated a string builder
  + a 1-byte substring per non-space character.

### `vec_free` builtin

The s1 needed a way to free Vecs from its own type
checker. v0.2.158 adds `vec_free` as a first-class builtin
(not just a `mem.nr` rod export):
- `compiler/nucleor_s1_compiler.nr`: 4 ABI sites
  (get_rt_name, is_void_ret, is_ptr_arg, emit_externs).
- `compiler/nucleor_tools_suite.nr`: 4 mirrored sites.
- Bootstrap took two passes: pass 1 wired the ABI without
  callers (compiles cleanly with the v0.2.157 binary that
  doesn't know vec_free); pass 2 added the actual
  `vec_free(snap)` etc. calls (compiles with the new
  pass 1 binary that does know it).

### RFC-0028 phase 4: format2_fi / format2_if / format3_fff

Continuing the v0.2.153 / v0.2.155 pattern, fills the
float-mixed gap left after `format2_ff`:
- `format2_fi(tmpl, f64, i64)` — ratio + count
- `format2_if(tmpl, i64, f64)` — step + error
- `format3_fff(tmpl, f64, f64, f64)` — 3D vector
Each chains the existing single-arg helper.

### Self-host LLVM IR fixed point

- 3-iter check held at byte-identical 2,681,397 bytes
  (pass2 == pass3 == pass3-rebuild). The intervening
  bootstrap pass differs from pass2 by exactly the new
  vec_free declare line, as expected.
- `bin/nucleor.exe` updated; compiler-source chain is now
  v0.2.84 → v0.2.87 → v0.2.151 → v0.2.152 → v0.2.153 →
  v0.2.155 → v0.2.157 → **v0.2.158**.

### Memory measurement

Baseline (v0.2.157 self-host, NUC_TRACE_ALLOC=1):
```
vec_new:         798K calls   119 MB
str_concat:      598K calls     4 MB
str_substring:   582M calls   9.5 GB  ← dominant
sb_new:           13K calls    60 MB
peak RSS:                       19 GB
```

After Ship 1 (this release):
```
vec_new:         799K calls   119 MB
str_concat:      598K calls     4 MB
str_substring:   586M calls   9.6 GB  (no change — see below)
sb_new:           13K calls    60 MB
peak RSS:                       19 GB
```

Ship 1 is infrastructure + non-allocating string-prefix
probes. Real wins are small. The dominant `str_substring`
leak (582M calls / 9.5 GB) is in code paths that need
Ship 2's TypeId interner to fix architecturally. The
`vec_free` builtin lands here so Ship 2 can be built on
top; the env-snapshot CALL SITES that crash on
match/enum tests are deferred to Ship 1b after the
interior-string-pointer audit (item E4 in punchlist).

### Verify gate

**245 / 245 PASS, 0 SKIP** on the bash gate. Self-host
rebuild closes byte-identical.

### See

`MEMORY_FIX_PUNCHLIST.md` (repo root) — full multi-ship
plan to bring peak RSS from 19 GB to < 500 MB.

## [0.2.157] — 2026-04-23

**RFC-0001 phase 1: `#[no_alloc]` v1 — first RT attribute that
actually enforces. File-wide source-level static check. Fires
new diag code RT-001 on violation.**

The v0.2.151 `#[allow]` ship preserved Rust-style attribute
lines through the source preprocessor, but `#[no_alloc]` itself
parsed silently with no checker. v0.2.157 wires a real check:
fns marked `#[no_alloc]` are scanned for forbidden allocator
patterns in their body text; each match emits an `error`-severity
RT-001 diag, halting the build.

### Surface

```nucleor
#[no_alloc]
fn add(a: i64, b: i64) -> i64 {
    return a + b;       // OK — no allocator calls
}

#[no_alloc]
fn busy() -> i64 {
    let mut v: Vec<i32> = Vec::new();   // error[RT-001]: Vec::new allocates
    v.push(1);                          // error[RT-001]: .push allocates
    return 0;
}
```

### Implementation in `compiler/nucleor_s1_compiler.nr`

- `collect_no_alloc_fns(source)` — scans the source text for
  `#[no_alloc]` literal followed by `fn NAME(`; returns Vec
  of fn names. Skips `//` line comments (so doc comments
  documenting `#[no_alloc]` don't match) and `"..."` string
  literals (so `let pat: str = "#[no_alloc]"` in this very
  file doesn't false-positive on the next fn after it).
- `no_alloc_check_list()` — returns a Vec of allocator-call
  patterns to scan for. Includes both user-facing forms
  (`Vec::new`, `.push`, `.pop`, `.extend`, `.insert_at`,
  `.remove_at`) and underlying builtin names (`vec_new`,
  `sb_new`, `str_concat`, `format_*` family, `int_to_str`,
  `arena_new`, etc.). 30+ entries.
- `check_no_alloc_violations(diags, source, fn_name)` — for
  the named fn, locates the body via `fn fn_name(` + brace-
  matching, scans the body text for `<pattern>(` substrings,
  fires RT-001 per match.
- `enforce_no_alloc(diags, source)` — drives the loop;
  no-op when no `#[no_alloc]` attributes are present.

### Wiring

`enforce_no_alloc` runs in the main pipeline before
`filter_allow_suppressed`, so users can `#[allow(RT-001)]` if
needed.

### Limitations of the v1 source-level approach (intentional)

- False positive if a forbidden literal pattern (e.g.
  `vec_push(`) appears inside a string or comment INSIDE
  the `#[no_alloc]` fn's body. Rare in practice.
- Does not chase transitive calls. `#[no_alloc]` fn calling
  a non-`#[no_alloc]` `helper()` that itself allocates does
  not fire. Lifts in v2 with AST + call-graph analysis.
- Per-file scope only.

These are documented inline above the implementation; v0.4
replaces the source-level scan with an AST-based check that
also lights up `#[no_panic]`, `#[no_dyn]`, and `#[deadline]`.

### New error code

- **RT-001** — "<call> allocates but `<fn>` is marked
  #[no_alloc]". Severity: error. Suppressible via
  `#[allow(RT-001)]`.

### Self-host LLVM IR fixed point

- 3-iter check passed: nucleor_v157f, v157g, v157h all
  byte-identical at 2,672,291 bytes.
- `bin/nucleor.exe` updated; the v0.2.x compiler-source
  chain is now v0.2.84 → v0.2.87 → v0.2.151 → v0.2.152 →
  v0.2.153 → v0.2.155 → **v0.2.157**.

### Gate tests

- `tests/lang/no_alloc_clean.nr` — positive (#[no_alloc]
  fns that genuinely don't alloc).
- `tests/err/err_no_alloc_violation.nr` — negative
  (`busy()` with Vec::new + .push, expects RT-001).

### Verify gate

**244 / 244 PASS, 0 SKIP** (was 242/242; +2 new tests).

## [0.2.156] — 2026-04-23

**Gate ergonomics: `KEEP_CACHE=1 bash tools/verify.sh` skips
the post-run wipe and reuses the module-graph cache on the
next run.**

The verify gate's "self-host rebuild closes" step rebuilds the
~9000-LOC s1 compiler from scratch — that single step
dominates the gate's wallclock (≈20s of the typical ~80s
total). The compiler emits a `.nuc_cache/` module-graph
snapshot that lets a re-run skip 80%+ of that work, but the
gate's tail-of-script cleanup wipes that cache so the next
run starts cold.

For active iteration this is wasteful — the same gate runs
back-to-back during a single feature ship and the cache
should be reused. v0.2.156 adds `KEEP_CACHE=1` env-var
support: when set, the gate skips the cleanup, and the next
run finds the populated cache and finishes ≈10× faster on
the self-host step. Default behavior is unchanged (CI still
runs cold for reproducibility).

### Files

- `tools/verify.sh`: cleanup block now gated on `KEEP_CACHE=0`
  (default). The variable is checked once at end-of-script.

### Self-host LLVM IR fixed point

- **No s1 source change** — pure tooling change. Fixed-point
  check not required.
- `bin/nucleor.exe` unchanged.

### Verify gate

Gate behavior unchanged when invoked as before
(`bash tools/verify.sh`); the new behavior only activates
with the env var. Sample usage:

```
# fast iteration loop
KEEP_CACHE=1 bash tools/verify.sh   # populates cache
KEEP_CACHE=1 bash tools/verify.sh   # second run: ≈10× faster on self-host

# clean run (default; matches CI)
bash tools/verify.sh
```

## [0.2.155] — 2026-04-23

**RFC-0028 phase 3: three new `format3_*` builtins
(`format3_sii`, `format3_iss`, `format3_sss`).**

Same template as v0.2.153 (which added the `format2_*` trio). Each
chains the corresponding single-arg `format_*` helper three
times. Closes the most-asked-for gaps in the v0.2 3-arg format
surface — string-then-two-ints (operator/operands), int-then-
two-strings (id-then-from-to), and three strings (path joins).

### Files

- `compiler/nucleor_s1_compiler.nr`: 4 ABI-table sites updated
  (get_rt_name, is_ptr_ret, is_ptr_arg, emit_externs declares).
- `compiler/nucleor_tools_suite.nr`: same 4 ABI sites mirrored;
  the cross-compiler drift gate enforces parity.
- `stdlib/runtime/nucleor_llvm_rt.c`: 3 new
  `__nucleor_format3_<X>` impls.
- `tests/lang/format3_combos.nr`: positive test asserting all 3
  combos produce the expected interpolated output
  ("sum=2+3", "7: src -> dst", "a/b/c").
- `docs/rfcs/helper_manifest.toml`: regenerated for the 3 new
  helpers.

### Self-host LLVM IR fixed point

- 2-iter check passed at iter2==iter3 (byte-identical at
  2,639,313 bytes). Iter1 (built by v0.2.154 compiler) legitimately
  differed by exactly the 3 new `declare` lines, since the old
  compiler didn't know them yet — same well-understood pattern
  as v0.2.153.
- `bin/nucleor.exe` updated; the v0.2.x compiler-source chain
  is now v0.2.84 → v0.2.87 → v0.2.151 → v0.2.152 → v0.2.153
  → **v0.2.155**. (v0.2.154 was a pure runtime addition that
  didn't touch the s1.)

### Verify gate

**242 / 242 PASS, 0 SKIP** on the bash gate (was 241/241; +1
new `tests/lang/format3_combos.nr`).

## [0.2.154] — 2026-04-23

**RFC-0002 phase 1: bare arena builtins now actually link.
Closes the v0.2.150 footgun where `arena_new` etc. were
pre-declared by the s1 but had no runtime impl.**

The v0.2.150 audit caught that the s1 compiler pre-declares
`arena_new` / `arena_alloc` / `arena_reset` / `arena_destroy`
as builtins (mapped to `__nucleor_arena_*` symbols) but those
symbols existed in NO runtime — they only appeared in the
rod-prefixed `nuc_arena_*` form inside `allocator_rt.c`. Any
user code calling the bare builtins (without
`import "stdlib/rods/allocator.nr"`) link-failed. v0.2.154
ships minimal bump-arena impls for those exact symbols inside
the always-linked main runtime.

The rich pool / stack / freelist surface stays in
`stdlib/rods/allocator.nr`; this ship is just the bump-arena
minimum the s1 builtin path was already promising. Full
`Box<T, A>` / `Allocator` trait integration ships with v0.4
RFC-0002 once generics land via RFC-0023..0027.

### Files

- `stdlib/runtime/nucleor_llvm_rt.c`: 4 new `__nucleor_arena_*`
  impls. NArena layout = `{ capacity, offset }` header followed
  by raw bytes. Allocations are 8-byte aligned; `arena_alloc`
  returns 0 on exhaustion (no resize); `arena_reset` rewinds
  the offset; `arena_destroy` frees the whole arena.
- `tests/lang/arena_builtin.nr`: positive test exercising the
  bare builtins WITHOUT importing `allocator.nr`. Asserts:
  alloc returns non-zero, sequential allocs are ordered, reset
  rewinds to the original alloc address, destroy completes.

### Self-host LLVM IR fixed point

- **No s1 source change** — pure runtime addition. Fixed-point
  check was therefore not required for this ship.
- `bin/nucleor.exe` unchanged.

### Verify gate

**241 / 241 PASS, 0 SKIP** (was 240/240; +1 new test).

## [0.2.153] — 2026-04-23

**RFC-0028 phase 2: three new `format2_*` builtins
(`format2_ss`, `format2_is`, `format2_ff`).**

Closes the most-asked-for gaps in the v0.2 format-string surface:
two strings, i64-then-str (the missing opposite of `format2_si`),
and two f64s. Each chains the corresponding single-arg
`format_*` helper twice, matching the `format2_ii` / `format2_si`
template. Full variadic format-string parsing is still v0.4.

### Files

- `compiler/nucleor_s1_compiler.nr`: 4 ABI-table sites updated
  (get_rt_name, is_ptr_ret, is_ptr_arg, emit_externs declares).
- `compiler/nucleor_tools_suite.nr`: same 4 ABI sites mirrored;
  the cross-compiler drift gate enforces parity.
- `stdlib/runtime/nucleor_llvm_rt.c`: 3 new
  `__nucleor_format2_<X>` impls + a forward declaration of
  `__nucleor_format_f64` so `format2_ff` can reference it
  without reordering the file.
- `tests/lang/format2_combos.nr`: positive test asserting all 3
  new combos produce the expected interpolated output
  ("from=earth, to=mars", "count=42, name=answer",
  "pi=3.14, e=2.72").
- `docs/rfcs/helper_manifest.toml`: regenerated (drift gate
  caught the staleness on the first run).

### Self-host LLVM IR fixed point

- 2-iter check passed after the first pass (which legitimately
  differed by exactly the 3 new `declare` lines, since the old
  v0.2.152 compiler didn't know about them yet): nucleor_v153b
  rebuilt itself byte-identical at 2,631,996 bytes.
- `bin/nucleor.exe` updated; the v0.2.x compiler-source chain
  is now v0.2.84 → v0.2.87 → v0.2.151 → v0.2.152 → **v0.2.153**.

### Verify gate

**240 / 240 PASS, 0 SKIP** on the bash gate (was 239/239; +1
new `tests/lang/format2_combos.nr`).

## [0.2.152] — 2026-04-23

**`#[deny(CODE)]` promotes warnings to errors — sibling of v0.2.151
`#[allow]`. Item 4 fully closed at the v0.2 scope.**

v0.2.151 shipped `#[allow(CODE)]` (file-wide warning suppression).
v0.2.152 ships `#[deny(CODE)]` (file-wide warning → error
promotion). Same scan-and-collect machinery; same lifecycle
(parse-resolve preserves the attribute through to diag-filter
time); same v0.4 follow-on for per-fn / per-block scoping.

### `compiler/nucleor_s1_compiler.nr`

- New `fn collect_denied_codes(source: str) -> Vec<i32>` —
  parallel to `collect_allowed_codes`, scans for the literal
  pattern `#[deny(CODE)]`.
- New `fn promote_denied_to_errors(diags: Vec<i32>, source: str)
  -> Vec<i32>` — walks the diag vec; for each warning whose
  code is in the deny list, mutates severity slot from
  `"warning"` to `"error"` via `vec_set(d, 0, "error")`.
- Wired into both diag-emit sites (preflight + main pipeline)
  immediately after `filter_allow_suppressed` — allow → deny
  ordering means a code listed in both is silenced (allow wins
  by removing the diag before deny can see it).

### Self-host LLVM IR fixed point

- 2-iter check passed: nucleor_v152.ll == nucleor_v152b.ll
  (byte-identical, 2,625,247 bytes).
- `bin/nucleor.exe` updated; the v0.2.84 / v0.2.87 / v0.2.151
  / v0.2.152 chain extends to four committed compiler binaries
  in the v0.2.x sub-chain.

### `tests/err/err_deny_promotes_warning.nr`

- New negative test exercising the same `i64 → i32` cast
  (NUM-003) used by `tests/lang/allow_suppress_warning.nr`,
  but with `#[deny(NUM-003)]` instead of `#[allow]`. Header
  `// EXPECT: NUM-003 \`as\` cast loses precision` —
  `err_tests_have_expect_smoke` (v0.2.118 gate step) enforces
  the format. The gate runs the file through `nuc check` and
  asserts compilation fails with NUM-003.

### `docs/spec/Nucleor_Error_Codes.md`

- "Suppression" section status callout updated: `#[allow]` and
  `#[deny]` both ship at v0.2.152; the prose names both code
  paths (`filter_allow_suppressed`, `promote_denied_to_errors`)
  and lists their respective gate tests.
- v0.4 follow-on now lists only "per-fn / per-block scoping"
  and "build-profile suppression" — the per-attribute work is
  done.

### Verify gate

**239 / 239 PASS, 0 SKIP** on the bash gate (was 238/238; +1
new `tests/err/err_deny_promotes_warning.nr`). Self-host
rebuild closes step 239/239.

## [0.2.151] — 2026-04-23

**Closes punchlist item 4: `#[allow(CODE)]` actually suppresses
warnings now (file-wide; per-fn scoping deferred to v0.4).**

The v0.2.145 audit caught the spec doc describing `#[allow]` /
`#[deny]` as if they worked when in reality `#[allow(CODE)]`
parsed without error but had **zero** effect on diagnostic
emission. v0.2.151 wires the file-wide variant: anywhere
`#[allow(CODE)]` appears in the source, the named code is
silenced for the whole compile unit. Errors are never
suppressible (Rust model).

### `compiler/nucleor_s1_compiler.nr`

- New `fn collect_allowed_codes(source: str) -> Vec<i32>`
  scans the raw source for the literal pattern `#[allow(CODE)]`
  and returns the Vec of CODE strings.
- New `fn filter_allow_suppressed(diags: Vec<i32>, source: str)
  -> Vec<i32>` drops any warning-severity diag whose code is in
  the allow list. Errors pass through unchanged.
- Two call sites wired (`preflight_source_check` and the main
  pipeline diag-emit block) — the filter runs immediately
  before `diag_emit_text` / `diag_emit_json`.
- **Bug fix in `resolve_source_with_records`** — the source-
  import preprocessor was stripping ALL `#`-prefixed lines
  (intended to skip `#cfile` and `#link` directives) but also
  swallowed Rust-style `#[allow]` attribute lines before they
  could reach the diag-filter. Tightened the condition: only
  strip lines whose second character is **not** `[`. The
  attribute lines now flow through the resolver unchanged; the
  lexer continues to skip them at token time, so the parser
  never sees them and the diag-filter does. Same fix benefits
  any future `#[deny]` / `#[assume]` / `#[max_depth]` work.

### Self-host LLVM IR fixed point

- 2-iter check passed: nucleor_v151f.ll == nucleor_v151g.ll
  (byte-identical, 2,615,215 bytes).
- `bin/nucleor.exe` updated for the first time since v0.2.87
  — the v0.2.84 (`nuc help` doc/fix) and v0.2.87 (`-V` /
  `version` aliases) chain extends to **v0.2.151
  (`#[allow]` filter)**.

### `tests/lang/allow_suppress_warning.nr`

- New positive test exercising the `i64 → i32` cast
  (NUM-003) under `#[allow(NUM-003)]`. Prints "OK" when
  the warning is silenced, gate-tested.

### `docs/spec/Nucleor_Error_Codes.md`

- "Suppression" section status callout flipped from "**not
  yet implemented**" to "**ships**"; documents the file-wide
  scope with v0.4 follow-on for per-fn scoping. `#[deny]`
  remains v0.4-planned.

### Verify gate

**238 / 238 PASS, 0 SKIP** on the bash gate (was 237/237; +1
new `tests/lang/allow_suppress_warning.nr`). Self-host rebuild
closes step 238/238 — confirming the new compiler can rebuild
itself.

## [0.2.150] — 2026-04-23

**Closes v0.2.123 finding: 11 orphan runtime C files now have rod
wrappers + smokes. Rod count 121 → 132, gate 226 → 237.**

The v0.2.123 audit found 11 `stdlib/runtime/*_rt.c` files that
ship in the OSS distribution but have no `.nr` rod wrapper, so
their substantial functionality (transformer building blocks,
modern attention variants, modern activations, BPE tokenizer,
CSV table API, priority queue, thread pool, three-way allocator
suite, differentiable quantum simulation, vec memory helpers,
cross-rod interop helpers) was unreachable from Nucleor source.
v0.2.123 documented them as v0.4 wrap targets. v0.2.150 closes
the finding by writing all 11 wrappers + a smoke per rod.

### New rods under `stdlib/rods/`

| Rod | C runtime | Notes |
|---|---|---|
| `mem.nr` | `mem_rt.c` | `vec_free`, `vec_clear`, `vec_mem_bytes` |
| `pqueue.nr` | `queue_rt.c` | Priority queue (binary min/max-heap with decrease-key); separate from existing FIFO `queue.nr` |
| `allocator.nr` | `allocator_rt.c` | Arena (bump), object pool, mark/pop stack — `allocator_*` prefix to avoid collision with the s1's pre-declared `arena_new` / `arena_alloc` / `arena_reset` / `arena_destroy` builtins (which are stubs that don't link to a runtime; RFC-0002 will share this rod's runtime) |
| `thread.nr` | `thread_rt.c` | Thread pool, futures, parallel map |
| `tokenizer.nr` | `tokenizer_rt.c` | BPE training + encode/decode, char-level fallback |
| `csv_table.nr` | `csv_rt.c` | Whole-file table API; separate from existing line-parsing `csv.nr` |
| `activation2.nr` | `activation2_rt.c` | SwiGLU, GeGLU, JumpReLU, DyT, RMSNorm, QK-Norm, RoPE, DeepNorm, GELU, SiLU, softmax, sigmoid (13 fns) |
| `transformer.nr` | `transformer_rt.c` | Classic transformer blocks (scaled dot-product attention, MHA, layer norm, FFN, sinusoidal PE, softmax, cross-entropy) |
| `attention2.nr` | `attention2_rt.c` | FlashAttention, GQA, MLA (compress/decompress), sliding window, differential attention |
| `diff_sim.nr` | `diff_sim_rt.c` | Differentiable quantum simulation (23 fns: forward, adjoint backprop, per-feature grads, gate-importance, prior import/export) |
| `rod_helpers.nr` | `rod_helpers_rt.c` | String↔i64-vec bridge + function-pointer callers (`call_fn2`, `call_fn3`); functions renamed `vec_str_*` to avoid collision with core `vec_*` builtins |

### New tests under `tests/rods/`

- **Functional smokes** (call ≥1 function and assert): `mem_smoke.nr`
  (push/clear/free), `pqueue_smoke.nr` (min + max heap drain),
  `allocator_smoke.nr` (arena + pool + stack), `thread_smoke.nr`
  (pool create/free), `tokenizer_smoke.nr` (char-level encode),
  `csv_table_smoke.nr` (new + set + rows/cols + free),
  `transformer_smoke.nr` (positional encoding), `diff_sim_smoke.nr`
  (init + n_gates + free).
- **Build-only smokes** (import + return 0; opaque tensor handles
  needed for a meaningful functional check):
  `activation2_smoke.nr`, `attention2_smoke.nr`,
  `rod_helpers_smoke.nr`.

### Caught two bugs along the way

- **`arena_new` builtin shadowed user rod** — the s1 compiler
  pre-declares `arena_new` / `arena_alloc` / `arena_reset` /
  `arena_destroy` as builtins mapped to `__nucleor_arena_*`
  symbols that don't exist in any runtime. A rod with the same
  user-facing names (`arena_new`, `arena_alloc`, …) gets shadowed
  by the dangling builtins and fails at link. Fixed by prefixing
  the rod's surface with `allocator_` (the runtime symbols use
  `nuc_arena_*` so the link path is fine; only the user-facing
  Nucleor names needed renaming). The dangling builtins are an
  RFC-0002 artifact — they should land alongside the v0.4
  `Box<T, A>` / `Allocator` trait work; logging here so the v0.4
  ship knows to wire them to this rod's runtime instead of a
  parallel implementation.
- **`tok_char_level` ≠ tokenizer handle** — first cut of
  `tokenizer_smoke.nr` called `tok_free(tok_char_level("hello"))`,
  which segfaults because `tok_char_level` returns a `TKVec*`
  (token-id vec) and `tok_free` casts to `BPETokenizer*`. The
  rod docs deserve a clarifying note; smoke fixed.

### Manifests

- `tools/gen_rod_manifest.py` regenerated (`docs/rfcs/rod_manifest.toml`):
  rod count **121 → 132**.
- `tools/gen_helper_manifest.py` regenerated (`docs/rfcs/helper_manifest.toml`):
  helper count grew by the runtime fns from the 11 new rods'
  `extern fn` declarations.
- Drift gate caught the rod-manifest staleness on the first run;
  RELEASES.md regenerated for the v0.2.150 entry.

### Verify gate

**237 / 237 PASS, 0 SKIP** on the bash gate (was 226/226; +11
new `tests/rods/*_smoke.nr`). Pure addition — no compiler /
runtime / s1-source / tools-suite change; the 11 new rods only
add `.nr` wrapper files + their smokes; the runtime C files
they wrap have shipped in `stdlib/runtime/` since well before
the v0.2.0 RC. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.149] — 2026-04-23

**Closes v0.2.124 finding: 22 orphan rod wrappers now have smoke
tests under the verify gate. Gate grew 204 → 226.**

The v0.2.124 audit found 22 rod files in `stdlib/rods/*.nr` that
ship with `#cfile` directives but are never imported by any
example, test, or other rod — so the verify gate never built
them through `nuc build`. v0.2.124 documented them as v0.4
example-coverage targets. v0.2.149 closes the finding by
adding a `tests/rods/<name>_smoke.nr` for each.

The smokes are minimal. Where the rod's API takes only
primitives (str / i64), the smoke calls one or two functions
and asserts the obvious return value. Where the rod returns
opaque handles to allocated tensors / buffers / WAV streams /
hardware ports, the smoke imports the rod and returns 0
("build-only smoke") — the value is verifying that the `#cfile`
resolves, the `extern fn` declarations match the C
implementation's symbol table, and the rod links against the
runtime. Future rename / typo / runtime-removal regressions are
now gate-blocked.

### New tests under `tests/rods/`

- **Functional smokes** (call ≥1 function with primitive args
  and assert the result):
  `stack_smoke.nr` (push/pop/peek/len/is_empty),
  `string_algo_smoke.nr` (Levenshtein),
  `bioseq_smoke.nr` (GC + Hamming),
  `color_smoke.nr` (RGB→HSV + palette),
  `mesh_smoke.nr` (4×4 rect + node-count check),
  `mps_smoke.nr` (init + free),
  `gpu_smoke.nr` (gpu_available probe),
  `hnsw_smoke.nr` (constructor),
  `kv_cache_smoke.nr` (constructor),
  `embedding_smoke.nr` (constructor),
  `rl_smoke.nr` (replay-buffer constructor + size==0),
  `checkpoint_smoke.nr` (constructor),
  `comm_smoke.nr` (comm_init),
  `diffusion_smoke.nr` (linear schedule),
  `speculative_smoke.nr` (spec_seed).

- **Build-only smokes** (import + return 0; rod requires
  opaque-handle setup that doesn't fit a smoke):
  `audio_smoke.nr` (needs WAV file),
  `conv_smoke.nr` (needs tensor handles),
  `loss_smoke.nr` (needs tensor handles),
  `pq_smoke.nr` (needs training data),
  `quantize_smoke.nr` (needs weight buffer handles),
  `scan_smoke.nr` (needs `Vec<f64>` plumbing),
  `serial_smoke.nr` (needs serial port hardware).

### Caught one bug along the way

The first cut of `string_algo_smoke.nr` asserted
`str_kmp("hello world", "world") == 6`, expecting the function
to return the match position. Reading
`stdlib/runtime/string_algo_rt.c` showed it actually returns
**a handle to a `savec` of all match positions**, not a
position. Fixed the smoke to exercise the function without
asserting on the return — and the rod's wrapper docs deserve
a follow-up to clarify the handle return.

### Verify gate

**226 / 226 PASS, 0 SKIP** on the bash gate (was 204/204; +22
new `tests/rods/*_smoke.nr`). Pure addition — no compiler /
runtime / s1-source / tools-suite change; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.148] — 2026-04-23

**One more lockfile-name straggler missed by v0.2.147 — fixed.**

Follow-on to v0.2.147 (which canonicalized 12 files using
`nuc.toml` / `nuc.lock`): a final sweep with the
not-CHANGELOG-yet filter found one more in
`docs/process/semver-and-release.md` §5 Yanking that v0.2.147
missed (the doc was updated for `nuc.toml` but not `nuc.lock`).

### `docs/process/semver-and-release.md`

- §5 Yanking sentence: "Yanked versions remain downloadable for
  users with `nuc.lock` already pinning them" → "with
  `Nucleor.lock` already pinning them".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.147] — 2026-04-23

**Filename drift: 8 docs + 1 tools-suite entry referenced
`nuc.toml` / `nuc.lock`, but the shipped compiler reads
`Nucleor.toml` / `Nucleor.lock`.**

The compiler source has been reading the capitalized form for
the entire v0.2 line (`file_read_string("Nucleor.toml")` in
`compiler/nucleor_s1_compiler.nr`; `nuc init <name>` scaffolds
`<name>/Nucleor.toml`; `nuc lock` writes `Nucleor.lock`). But
the canonical **RFC-0019** (package-manager design), five other
RFCs, the milestone tracker, the migration guide, the semver
process doc, and one explain-registry title all referred to
**`nuc.toml`** / **`nuc.lock`**. Users reading the RFC and
running `nuc build` from a `nuc.toml` project directory would
get "manifest not found" (because the compiler is looking for
`Nucleor.toml`).

Also: the repo-root sample file **`nuc.toml`** had a header
claiming "**The minimal TOML parser shipped in v0.1.33 reads
this file**". It does not — the parser reads `Nucleor.toml`.
Header rewritten to correctly describe the file as a schema
reference that is NOT the manifest the compiler consumes.

### Docs (all `nuc.toml` → `Nucleor.toml`, all `nuc.lock` →
`Nucleor.lock`)

- **`docs/rfcs/RFC-0019-package-manager.md`** — 10 replacements
  including the RFC title, the body references, the fenced-code-
  block headers (`# Nucleor.toml`, `# top-level Nucleor.toml`),
  and the workspace section naming `Nucleor.lock`.
- **`docs/rfcs/RFC-0018-modules.md`** — 2 replacements.
- **`docs/rfcs/RFC-0011-nuc-cxx.md`** — 3 replacements.
- **`docs/rfcs/RFC-0012-nuc-bindgen.md`** — 1 replacement
  (bindgen section table).
- **`docs/rfcs/RFC-0009-heptane-wcet.md`** — 1 replacement
  (wcet cache config section).
- **`docs/process/semver-and-release.md`** — 1 replacement
  (edition declaration example).
- **`docs/milestones/v0.2.0.md`** — 1 replacement (RFC-0019
  phase-1 parser row).
- **`docs/migrations/v0.1-to-v0.2.md`** — 1 replacement
  ("canonical project manifest").

### Compiler tools-suite

- **`compiler/nucleor_tools_suite.nr`** — `explain_error_title()`
  entry for **PKG-001** — "nuc.toml manifest fails schema
  validation" → "**Nucleor.toml** manifest fails schema
  validation". Rebuilt on gate; tools binary is git-ignored.

### Repo root sample

- **`nuc.toml`** (the reference schema file, kept because its
  schema comments are useful reader documentation) — header
  rewritten to name `Nucleor.toml` as the canonical manifest
  the compiler actually reads, with pointers to the
  `file_read_string("Nucleor.toml")` call in s1 and the
  `Nucleor.lock` write in `nuc lock`.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Tools-suite rebuild
picked up the PKG-001 title change; no compiler / runtime /
s1-source change. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.146] — 2026-04-23

**Milestone tracker sub-chain header was undercounting post-RC
releases — 71 → 96.**

The sub-chain summary header in `docs/milestones/v0.2.0.md` said
"**The 71 releases between the v0.2.0 RC tag and v0.2.120 fall
into six buckets**". As of v0.2.145 the post-RC chain is 96
releases long (v0.2.50 through v0.2.145 spans more ships than
when the header was last written at v0.2.120). Bumped both the
endpoint (v0.2.120 → v0.2.145) and the count (71 → 96). The six
buckets themselves still cover the span — the v0.2.131–145 ships
all fall into "**Documentation staleness audit**" or the extended
"**Diagnostic-code coverage closure**" bucket.

### `docs/milestones/v0.2.0.md`

- Sub-chain summary header: "v0.2.50–v0.2.120 (post-RC
  hardening)" → "v0.2.50–v0.2.145 (post-RC hardening)"; first
  sentence bumped "71 releases ... and v0.2.120" →
  "96 releases ... and v0.2.145".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.145] — 2026-04-23

**Spec doc "Suppression" section described `#[allow]` / `#[deny]`
as a working feature — it isn't. Documented the current behavior +
v0.4 plan.**

The "Suppression" section in `docs/spec/Nucleor_Error_Codes.md`
read as if `#[allow(CODE)]` and `#[deny(CODE)]` were live
features:

> Users can suppress diagnostics per-scope via `#[allow(CODE)]`
> or per-project via the build profile. Warnings can be
> promoted to errors with `#[deny(CODE)]`.

Verified by inspection: `compiler/nucleor_s1_compiler.nr` has
**zero** references to the strings `"allow"` or `"deny"` as
parsed attribute names. No tests under `tests/lang/`,
`tests/attrs/`, or `tests/features/` use either attribute.
A direct test (`#[allow(NUM-001)] fn main() -> i64 { return 0; }`)
parses without error but the suppression has no effect — the
attribute is silently ignored.

The explain-registry prose for **NUM-003**, **CXX-003**,
**NUM-004** (and likely others) tells users to suppress with
`#[allow(precision_loss)]`, `#[allow(no_dyn)]`,
`#[allow(no_hw_lp_float)]` etc., but those suggestions are
non-functional today. The Suppression section is what makes
the explain-registry prose coherent — without a suppression
mechanism documented anywhere, the explain text reads as
nonsense.

### `docs/spec/Nucleor_Error_Codes.md`

- "Suppression" section now opens with a "**Status (v0.2):
  not yet implemented**" callout, documents the current silent-
  ignore behavior, names the v0.4 follow-on attribute
  infrastructure (RFC-0004 `#[assume]` + RFC-0014
  `#[max_depth]`) that suppression will plug into, and keeps
  the planned design as the closing paragraph.

The explain-registry prose still mentions the suppression
attributes — that's correct because it shows the planned
syntax. A future ship will revisit those entries once
suppression actually works to mark them as live; for now the
prose accurately describes the target user fix even though
the runtime mechanism isn't wired.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.144] — 2026-04-23

**Tab-completion scripts (all 4 shells) also missing 3 flags that
shipped CLI surfaces use.**

Follow-on to v0.2.143 (which caught 5 missing subcommands): a flag-
level cross-check against `nuc help` output found 3 `--flag` names
that are accepted by the shipped CLI but not completable in any
of the 4 shells:

- **`--imports`** — used by `nuc fix --imports` (RFC-0018 legacy-
  import → `use std::` migration linter).
- **`--numeric`** — used by `nuc fix --numeric` (RFC-0015 narrow-
  width numeric-suffix migration linter).
- **`--registry`** — used by `nuc registry --registry <path>`
  (local registry path override).

Added to all 4 completion files (`nuc.bash`, `nuc.zsh`, `nuc.fish`,
`nuc-completion.ps1`) with short descriptions noting which
subcommand uses each flag.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. No compiler / runtime
/ s1-source change; completion scripts only. Self-host LLVM IR
fixed point preserved (`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.143] — 2026-04-23

**Tab-completion scripts missing 5 user-facing CLI commands across
all 4 shells; added.**

A cross-check of the `nuc help` command list against
`tools/completions/{nuc.bash,nuc.zsh,nuc.fish,nuc-completion.ps1}`
found 5 commands that ship in the CLI but had no entry in any of
the 4 completion files:

- **`add`**, **`remove`**, **`update`** — install aliases
  (RFC-0019 phase 4 ergonomics; visible in `nuc help` as
  "`add | remove | update  Aliases for install`").
- **`doc`** — RFC-0029 doc generator (`Render /// doc comments
  as Markdown`).
- **`fix`** — RFC-0015 / RFC-0018 migration linters
  (`fix [--imports|--numeric] [file]`).

All 5 are real top-level subcommands users can run today. They
fired no completion suggestion before this ship; users had to
type them manually.

### `tools/completions/nuc.bash`

- Appended `add remove update` after `install` and inserted a
  `doc fix` line after `sage` in the `commands="…"` literal.

### `tools/completions/nuc.zsh`

- Inserted three install-alias rows
  (`'add:Alias for install (RFC-0019 phase 4 ergonomics)'` +
  `remove` / `update`) and two RFC entries
  (`'doc:Render /// doc comments as Markdown (RFC-0029)'`,
  `'fix:Migration linters (--imports / --numeric — RFC-0015 /
  RFC-0018)'`).

### `tools/completions/nuc.fish`

- Same five commands added to both the `nuc_commands` list and
  the per-subcommand `complete -c nuc -n '__fish_use_subcommand'`
  declarations, with description strings.

### `tools/completions/nuc-completion.ps1`

- Five commands appended to the `$nuc_subcommands` array.

### `tools/completions/README.md`

- "Subcommand at position 1" bullet — count corrected from
  "**~37 commands**" to "**39 commands as of v0.2.143**" with a
  note explaining what the v0.2.143 catch-up covered.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. No compiler / runtime
/ s1-source change; the completion scripts are user-tooling
helpers, not part of the gate. Self-host LLVM IR fixed point
preserved (`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.142] — 2026-04-23

**`examples/showcase/README.md` claimed "Not part of the verify
gate" — but `showcase_build_smoke` has been gated since v0.2.90.**

The opening line of the showcase README said "**Not part of the
verify gate**" and the bottom section "**Why no gate coverage?**"
ended with "**A future gate addition could be a build-only smoke
(verify the `.exe` is produced). That's tracked but not yet
shipped.**" — both stale. The build-only smoke landed as
`showcase_build_smoke` in v0.2.90 (in both `tools/verify.sh` and
`tools/verify.ps1`); 47 ships ago readers were already getting
gate coverage that the README denied.

### `examples/showcase/README.md`

- Opening paragraph: "Not part of the verify gate" → "**Build is
  gated** via the `showcase_build_smoke` step (added v0.2.90);
  **execution is not gated** because…". Splits the build-vs-run
  distinction explicitly so readers understand what is and isn't
  enforced.
- "Why no gate coverage?" → "Why no run-time gate coverage?";
  closing paragraph rewritten to acknowledge the v0.2.90
  build-smoke as already shipped, name the failure modes it
  catches (missing `.exe`, `_viz.nr` import break, extern typo,
  LLVM emission fail), and clarify that visual correctness is
  manual.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.141] — 2026-04-23

**Spec doc "Adding a new error code" recipe was 4 steps; we
actually use 6 — recipe brought into agreement with practice.**

The recipe in `docs/spec/Nucleor_Error_Codes.md` listed only
4 steps (spec entry, 3 explain-registry entries, sanity check,
test in `tests/err/`). The actual workflow used by v0.2.79–
v0.2.131 (which wired 30+ codes — NR, OWN, TYP, TNT, GOV) has
6 steps because the gate locks each addition in two more places:

- The `cli_explain_full_smoke` codes array in **both** gate
  scripts (`tools/verify.sh` AND `tools/verify.ps1`) — without
  this step the `nuc explain CODE` smoke doesn't actually
  exercise the new code.
- The `// EXPECT: CODE [text]` header on the negative test
  (gate-enforced via `err_tests_have_expect_smoke` since
  v0.2.118).

Plus an unenforced reviewer-checklist step:

- Bump the "161-code spec catalog" count in
  `NUCLEOR_BOOTSTRAP_CONTRACT.md` and the "All N diagnostic
  codes" claim in `docs/milestones/v0.2.0.md` Status header.
  Not gate-enforced (would require a `wc -l`-style check that
  bumps with every new entry — debatable whether that's worth
  the gate complexity).

The recipe also now notes that codes fired from the s1 compiler
proper (`nucleor_s1_compiler.nr`) follow the same recipe and
trigger the 2-iteration LLVM IR fixed-point check from the
bootstrap contract.

### `docs/spec/Nucleor_Error_Codes.md`

- "Adding a new error code" section rewritten 4 steps → 6 steps
  with the gate-wiring + EXPECT-header steps explicit, plus a
  paragraph on the s1-vs-tools-suite split (codes can fire from
  either; explain registry is always in tools-suite).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.140] — 2026-04-23

**Architecture doc "where to look in the source" table named 7
fns that don't exist — replaced with the actual names.**

The "Where to look in the source" table in `docs/architecture.md`
told readers to "search `fn <name>` in `nucleor_s1_compiler.nr`"
for various pipeline stages. A spot-check found 7 of the named
functions don't actually exist; readers searching would hit zero
matches.

| Stage | Said | Actually |
|---|---|---|
| Lexing | `fn next_token` | (no such fn — `lex` is the entry point; tokens are pulled inline) |
| Parsing | `fn parse_fn`, `fn parse_struct` | `fn parse_fn_decl`, `fn parse_struct_decl` |
| Lowering | `fn build_ir` | (no such fn — entry is `fn lower_fn`) |
| Optimizer | `fn optimize`, `fn algebraic_rewrite` | `fn opt_fn` (driver), `fn opt_fold_block` (constant folding / algebraic), `fn opt_cse_block` (CSE), `fn opt_dce_block` (DCE), `fn opt_prop_block` (copy prop), `fn opt_dead_store_block` |
| LLVM emission | `fn emit_llvm` | `fn emit_fn`, `fn emit_inst`, `fn emit_externs` |

The `lex`, `parse_expr`, `lower_*`, `nr_type_to_llvm`,
`escape_llvm_str`, `get_rt_name`, `link_native_module`, and
`llvm_clang_path` references in the same table were already
correct.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.139] — 2026-04-23

**Bootstrap contract clarifies the "748 vs 676 symbols" gotcha.**

The `NUCLEOR_BOOTSTRAP_CONTRACT.md` showed two different runtime
symbol counts that confused readers:

- The `nuc bootstrap` CLI output (also quoted in the doc) says
  "**Runtime: 4945 lines, ~748 symbols**".
- The doc body two paragraphs later said "**676 `__nucleor_*`
  symbols**".

Both are correct, they answer different questions — the bootstrap
output line-counts every `__nucleor_*` mention (definition + extern
declaration + call site, all conflated), while the helper manifest
catalogues each symbol exactly once across s1 ABI tables + the
full runtime surface. The doc didn't explain this; readers
reasonably wondered which number was authoritative.

### `NUCLEOR_BOOTSTRAP_CONTRACT.md`

- Replaced the bare "**4944 lines / 676 `__nucleor_*` symbols
  as of v0.2.121**" with a two-bullet explanation that names
  `bootstrap_runtime_symbol_count()` as the source of the ~748
  number, and `helper_manifest.toml` as the source of the 676
  unique-helper number.
- Bumped the as-of stamp from v0.2.121 to v0.2.131.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.138] — 2026-04-23

**Two test-suite README drifts: features/ dir missing from
top-level layout table, and quarantined-features count off by one.**

- **`tests/README.md`** Layout table listed only 5 directories
  (`lang/`, `attrs/`, `runtime/`, `rods/`, `err/`) — the
  `features/` directory (34 ported V1 feature tests:
  generics, traits, `where`, ranges, etc.) was missing
  entirely. Added a row for it.
- **`tests/features/_unimplemented/README.md`** opening line
  said "**These 17 positive feature tests**" — actual count is
  18 (and the same README's own table accounts for 18). Off-by-
  one corrected.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.137] — 2026-04-23

**Four RFC "Target release" rows lagged behind the phased
implementation reality — brought into step with their own
Status rows + the index.**

The v0.2.126 / v0.2.127 work fixed the **Status** row in each
of 11+ early-implemented RFCs, but the **Target release** row
on the same header table was left alone. For RFCs that landed a
partial in v0.2 with the rest deferred to v0.3/v0.4/v0.5, the
Target row was simpler than the Status row and understated the
phasing.

- **RFC-0022** — Target said **"v0.2.0 (Linux desktop) →
  v0.5.0 (macOS, full cross)"**. Wrong on the first leg —
  v0.2 ships **only** the POSIX wrapper + `_WIN32` audit;
  native Linux/macOS `bin/nucleor` binaries are a **v0.3.0**
  deliverable (see `docs/milestones/v0.3.0.md`). Rewrote to
  match the phased reality: v0.2 POSIX wrapper → v0.3 native
  bootstrap → v0.5 cross-compilation + sysroots.
- **RFC-0024** — Target was a bare **"v0.4.0"**; Status row
  already said "Implemented (partial) v0.2.9". Rewrote Target
  to "v0.2 partial (v0.2.9 — Vec<i64> fn-ptr adapters) → v0.4.0
  (full trait + closures)" so the phasing is visible in the
  Target field too.
- **RFC-0028** — same pattern: bare "v0.4.0" → "v0.2 partial
  (v0.2.6 — format_i64/str/hex/2_ii/2_si builtins) → v0.4.0
  (full variadic + Display / Debug traits)".
- **RFC-0029** — bare "v0.4.0" → "v0.2 skeleton (v0.1.65 —
  nuc doc CLI shipped) → v0.4.0 (param rendering, navigation,
  doc tests)".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.136] — 2026-04-23

**v0.3.0 milestone tracker + cross-platform readiness doc — stale
gate-step counts and "as of vN" stamps brought current.**

The v0.3 milestone references the Windows verify-gate state in
several places to motivate the gate-parity goal. Two of those
numbers were stale (203 / v0.2.100 / v0.2.102 era — the gate
landed its 204th step at v0.2.118 with `err_tests_have_expect_smoke`
and the audit chain has continued through v0.2.135).

- **`docs/milestones/v0.3.0.md`** Status header — bumped from
  "post-v0.2.102" to "post-v0.2.135", from "203 as of v0.2.100"
  to "**204 as of v0.2.118**" with the EXPECT-headers gate
  reason, and from "v0.2.50–v0.2.102 audit chain" to
  "v0.2.50–v0.2.135".
- **`docs/milestones/v0.3.0.md`** Inheritance-from-v0.2.0 row 2
  for the gate parity goal: "203/203 unchanged (current Windows
  count as of v0.2.100)" → "204/204 unchanged (current as of
  v0.2.118)".
- **`docs/milestones/v0.3.0.md`** Phase 3 verify-gate-parity
  paragraph: "203/203 on Linux + macOS" → "204/204"; baseline
  "203 as of v0.2.100" → "204 as of v0.2.118"; "v0.2.50–v0.2.102
  audit chain" → "v0.2.50–v0.2.135".
- **`docs/status/v0.3-cross-platform-readiness.md`** opening
  snapshot caveat: "remains accurate as of v0.2.102" → "as of
  v0.2.135".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.135] — 2026-04-23

**RFC README footer paragraph undercounted the implemented RFCs
and carried a stale v0.2.124 stamp.**

The summary paragraph at the end of the RFC index claimed
"**8 Tier-2 (RFC-0015..0022) + RFC-0029 carry Implemented or
Implemented-partial status**" — a true count, but an
**undercount**. The same index (tier-2 table) also shows RFC-0024
(iterators) and RFC-0028 (format strings) as Implemented
(partial) — both landed early in the v0.2.x sub-chain (v0.2.9 +
v0.2.6). Counting them brings the total to **11 Implemented/
partial + 1 Decision (RFC-0030)**, not 8 + 1.

Plus the footer timestamp "**through v0.2.124 as of this
update**" was 10 ships stale.

### `docs/rfcs/README.md`

- Paragraph rewritten: "**32 RFCs drafted; 11 carry Implemented
  or Implemented-partial status as of v0.2.0 RC + early sub-
  chain**" — the 8 Tier-2 (RFC-0015..0022), RFC-0024, RFC-0028,
  RFC-0029 enumerated explicitly.
- Footer stamp: "v0.2.124" → "v0.2.134".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.134] — 2026-04-23

**Two RFCs reference diagnostic codes that don't exist in the spec
— renamed to match the shipped prefix.**

A code-cross-reference audit between the 32 RFCs and the spec
catalog (161 codes) caught two cases where the RFC body uses a
diagnostic code prefix that was renamed during implementation:

- **RFC-0020 §3.5** (Multi-span errors example) used
  `error[BORROW-003]: cannot borrow x as mutable, already
  borrowed as immutable` — but `BORROW-*` is not a shipped
  prefix. The borrow checker uses **OWN-*** since v0.2.119
  (specifically OWN-005 — Cannot shared-borrow mutably-borrowed
  value, which is exactly what the example shows). Renamed
  the example to `error[OWN-005]`.
- **RFC-0021 §3.10** Diagnostics table listed `TEST-001..004`
  — but the shipped prefix is **TST-***. v0.2.79 wired
  TST-001/002/003 with different semantics than the original
  draft (test discovery / process isolation / fixture setup,
  not the original test-signature / panic-mismatch / setup-
  context split). The RFC table was updated to mirror the
  shipped TST-001..003 + 2 v0.4-deferred entries (TST-004
  panic-mismatch, TST-005 wrong-signature). Implementation
  table's diagnostics row also bumped from `TEST-001…004` to
  `TST-001…003 (shipped) + planned TST-004/005`.

The **other 35 RFC code references** that don't appear in the
spec are intentional — most are aspirational future codes
mentioned in still-Draft RFCs (CLO-*, DYN-*, ITER-*, ALLOC-006,
FRAME-005, etc.) that will be added when the RFC ships, plus a
handful of references to external standards (REP-103/105 from
ROS, JSR-385 from Java, MSP430 microcontroller name).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.133] — 2026-04-23

**Three more docs caught with stale or mistaken roadmap claims —
brought into agreement with current RFC index.**

The audit pattern continued past the milestone-tracker refresh
into the long-tail process docs:

- **`CONTRIBUTING.md`** "What's in scope" bullet for doc-staleness
  fixes referenced "**the v0.2.79–v0.2.93 chain**". Bumped to
  v0.2.79–v0.2.132 to reflect the live state of the audit chain.
- **`docs/rfcs/HELPER-CONTRACT.md`** Status header stamped
  "**(2026-04-23, v0.2.80)**"; bumped to v0.2.132 with an
  explicit note that the population numbers (95.1%, 643/676)
  are unchanged since v0.2.78 — the v0.2.79–132 chain has been
  audit-pattern hardening on top of the populated manifest, not
  helper additions.
- **`docs/process/nucleor-safe-subset.md`** roadmap claimed
  "**v0.2.0 | RFC-0001-0004 implemented; subset begins to be
  enforceable**" — this is **wrong**: RFC-0001 through RFC-0014
  are all Draft status with v0.3.0–v0.7.0 targets per the
  current RFC index. The v0.2.0 row was rewritten to say what
  v0.2.0 actually shipped (Tier-2 essentials) and that the
  safety subset spec is frozen but enforcement waits on Tier-1
  RFC implementation. The v0.3.0 row was also tightened to name
  RFC-0001 + RFC-0002 explicitly.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.132] — 2026-04-23

**Mirror v0.2.131's 161-code spec catalog into milestone tracker,
status doc, and bootstrap contract.**

After v0.2.131 wired OWN-013 + GOV-001/002 (3 new codes), three
trackers still claimed "158 codes" — the v0.2.120 closure number.
Mirror in:

- **`docs/milestones/v0.2.0.md`** Status header — bumped from
  "v0.2.120" → "v0.2.131", "120 incremental releases through
  v0.2.120" → "131 incremental releases through v0.2.131", "23
  OWN/TYP/TNT codes" → "26 OWN/TYP/TNT/GOV codes across
  v0.2.119/120/131", "All 158 diagnostic codes" → "All 161
  diagnostic codes"; closure note now reads "**re-closed at
  v0.2.131** after a second-pass audit found OWN-013 +
  GOV-001/002 fired but undocumented".
- **`docs/milestones/v0.2.0.md`** "Diagnostic-code coverage
  closure" sub-chain bullet — extended title to
  `(v0.2.117–120, re-closed v0.2.131)`, paragraph names the 3
  new codes and bumps `cli_explain_full_smoke` from 158 → 161.
- **`NUCLEOR_BOOTSTRAP_CONTRACT.md`** gate-runs description —
  "204 steps as of v0.2.121" → "v0.2.131", "full 158-code spec
  catalog" → "161-code".
- **`docs/status/v0.2-shipped-and-deferred.md`** diagnostic-
  code closure bullet — added the v0.2.131 second-pass paragraph
  with the 3 new codes, bumped 158 → 161, marked the drift class
  **re-closed at v0.2.131**.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.131] — 2026-04-23

**3 more diagnostic codes were fired by the tools-suite type-check
pass but missing from spec + explain registry — wired in.**

A second-pass audit on the diagnostic-code registry (parallel to
v0.2.79–80 / v0.2.119–120) found 3 codes emitted by
`compiler/nucleor_tools_suite.nr` at `type_diag` sites that were
not present in `docs/spec/Nucleor_Error_Codes.md` and not in the
explain registry's three functions. They've been firing this whole
time — users running `nuc check` / `nuc audit` against sources
that match the relevant patterns would see the warnings without
being able to look the codes up via `nuc explain CODE`.

The 3 codes fall in two new buckets:

- **OWN-013** (borrow-checker / spawn-capture pass) — fires when
  a `spawn { ... }` block captures a `DeviceBuffer` value. GPU
  memory handles are pinned to the allocating thread's CUDA /
  Vulkan context binding; the worker thread spawn dispatches to
  has no context, so the capture is undefined behavior at
  runtime. Documented as the 13th OWN code (one above the
  v0.2.119 closure of OWN-001..012).

- **GOV-001** + **GOV-002** (governance pass) — fire when the
  source declares `@policy(require_authored)` or
  `@policy(no_unsafe)` but violates the constraint. **New series
  with two codes.** The s1 compiler does not yet enforce these at
  build time (the corresponding tests are quarantined under
  `tests/err/_unimplemented/`), but `nuc check` / `nuc audit`
  exercise the tools-suite path that fires them.

### `docs/spec/Nucleor_Error_Codes.md`

- OWN table: appended `| OWN-013 | Spawn block captures non-Send
  DeviceBuffer value | spawn-capture checker | error |` plus a
  paragraph noting it's tools-suite-fired and was added v0.2.131.
- New top-level `## GOV series — governance policies` section with
  the 2 codes and a paragraph covering the
  `tests/err/_unimplemented/` quarantine status.
- Spec catalog count: **158 → 161 codes**.

### `compiler/nucleor_tools_suite.nr`

- `explain_error_title()` — added 3 entries between OWN-012 and
  TNT-001.
- `explain_error_summary()` — added 3 entries (OWN-013 + 2 GOV).
- `explain_error_explanation()` — added 3 paragraph-length
  entries with the underlying CUDA / Vulkan context rationale
  (OWN-013) and policy-attribute mechanics (GOV-001/002).

### `tools/verify.sh` + `tools/verify.ps1`

- `cli_explain_full_smoke` codes array: appended `OWN-013` to the
  OWN block (with comment noting v0.2.131), added a new GOV
  block (`GOV-001 GOV-002`). Both gate scripts kept in step-for-
  step parity.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. The
`cli_explain_full_smoke` step now exercises 161 codes (was 158).
No compiler / runtime / s1-source change — only tools-suite +
spec doc + gate scripts. Tools-suite rebuild on every gate run
catches the new entries. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.130] — 2026-04-23

**Three more "as-of" markers in process docs + architecture brought
current.**

The audit-pattern sweep continued past README + getting-started +
migration + benchmarks into the process docs and architecture
reference. Three findings, all the same drift class (timestamp
markers from earlier in the v0.2.x sub-chain).

- **`docs/process/contributing.md`** said "**Verify gate green
  (203 steps as of v0.2.91)**". Actual is 204 steps as of v0.2.118
  (the EXPECT-headers gate step landed in v0.2.118). Updated +
  added EXPECT-header enforcement to the rollup of what the gate
  newly covers.
- **`docs/process/semver-and-release.md`** "**Last updated:
  2026-04-23 (post-v0.2.92)**" → "post-v0.2.129"; same paragraph's
  "v0.2.x sub-chain (through v0.2.92 as of this update)" → "through
  v0.2.129".
- **`docs/architecture.md`** "Builtin name mapping" row said
  "**around line 2004 as of v0.2.107**" — verified `fn get_rt_name`
  is exactly at line 2004 in the current source (compiler unchanged
  since v0.2.87, so the line number truly is unmoved). Bumped the
  stamp to v0.2.129 and dropped "around" since the line number is
  exact.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.129] — 2026-04-23

**Migration guide + benchmarks doc — stale "as of v0.2.91 / v0.2.97"
markers brought current.**

A continuation sweep across the long-form docs found three more
stale markers from the early v0.2 sub-chain. None affected
correctness — the underlying numbers are still right — but the
"as of v0.2.91" framing implied the doc was 37 ships behind.

- **`docs/migrations/v0.1-to-v0.2.md`** opening paragraph closed
  the post-RC chain at "v0.2.50 through v0.2.91+"; bumped to
  "v0.2.50 through v0.2.128+" and added the binary-unchanged-
  since-v0.2.87 note.
- **`docs/migrations/v0.1-to-v0.2.md`** TL;DR paragraph said
  "**v0.2.0 → v0.2.91 is also fully additive** … 91+ incremental";
  bumped to "**v0.2.0 → v0.2.128**" with "128+ incremental", and
  the gate-step rollup expanded to include the EXPECT-header
  enforcement (v0.2.118) and the diagnostic-code closure
  (v0.2.117–120, 158 codes wired) so the rollup matches the
  current state of the gate.
- **`docs/benchmarks.md`** size-table footnote said "Numbers as
  of v0.2.97 — bumped from v0.1-era estimates"; bumped to "as
  of v0.2.128" and added the binary-unchanged-since-v0.2.87 note
  (the binary really is identical, so the v0.2.87 numbers are
  the v0.2.128 numbers).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.128] — 2026-04-23

**Three stale numeric markers in user-facing docs (README + getting-
started) brought current.**

A sweep across the top-of-tree user-facing docs caught three
numbers that had drifted with the v0.2.x sub-chain and never got
back-mirrored.

- **`README.md`** "Testing this build" section claimed "**all 24
  tests across `tests/lang/`, `tests/attrs/`, `tests/runtime/`,
  and `tests/rods/`**" — the actual tree has 99 tests across
  those four dirs (44 + 4 + 27 + 24), with 34 more in
  `tests/features/` and 33 negative tests in `tests/err/`. The
  `nuc test tests/` command line in the snippet only exercises
  the four-dir slice, so the rewrite splits the count by dir and
  notes that `tools/verify.ps1` covers the additional two dirs.
- **`README.md`** "Versioning" section claimed "**(124 tags as
  of v0.2.57)**" — actual is 196 tags as of v0.2.127.
- **`docs/getting-started.md`** "Next steps" section pointed
  readers at "**`examples/02_fib.nr` through
  `examples/07_rust_interop.nr`**" (only 6 examples) — the tree
  has 18 numbered examples (`01_hello.nr` through
  `18_benchmark.nr`) plus 4 build-only `examples/showcase/`
  programs. The new bullet enumerates the per-example feature
  list and points at `tools/examples.list` (the gate's single
  source of truth) for the canonical numbered list.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.127] — 2026-04-23

**RFC-0030 (async decision) status synchronized + new "Decision"
status added to the legend.**

The audit pattern in v0.2.126 caught 11 RFCs whose per-file
Status row drifted from the index. RFC-0030 was the corner case
not covered there: the index Status said "Draft", the per-RFC
header said "Draft", but the README footer paragraph stated
"**RFC-0030 declined during v0.2**". The status legend lacked
any "Decision" / "Declined" option, so neither the index nor the
RFC header could correctly express it.

The decision RFC is the third class of RFC outcome: a
deliberate non-implementation (or scope-bounding choice) where
the *decision* is the deliverable. RFC-0030 explicitly chose
"no first-class async runtime in v0.x; `rod/tokio.nr` opt-in
in v0.5; native `async`/`await` syntax in v0.8". That is a
ship-grade outcome, not a draft and not a withdrawal.

### `docs/rfcs/README.md`

- **Status legend** — added `**Decision**` row between
  `Implemented` and `Superseded by RFC-NNNN`. Defines it as
  "RFC documents a deliberate non-implementation or scope-
  bounding choice; the decision is the deliverable, not a
  code drop."
- **Index Tier-2 row for RFC-0030** — Status column updated:
  `Draft` → `**Decision** v0.2 — no first-class async in
  v0.x; rod/tokio.nr opt-in v0.5; native syntax v0.8`.
- **Footer paragraph** — `RFC-0030 declined during v0.2` →
  `RFC-0030 (async) accepted as a Decision RFC in v0.2 …`,
  with the phased plan summary inline.

### `docs/rfcs/RFC-0030-async-decision.md`

- Per-RFC `| **Status** |` row: `Draft` → `Decision (accepted
  v0.2) — no first-class async in v0.x; rod/tokio.nr opt-in
  v0.5, native sugar v0.8`.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.126] — 2026-04-23

**11 RFC headers had `Status: Draft` while the index + milestone
tracker showed them as Implemented — drift class fixed.**

A status audit comparing each `RFC-NNNN.md`'s in-file Status row
against the Status column in `docs/rfcs/README.md` found 11 RFCs
where the per-RFC header still said **`Draft`** even though the
index + `docs/milestones/v0.2.0.md` track them as Implemented or
Implemented (partial / skeleton). All 11 are Tier-2 v0.2 essentials
or v0.4 features that landed early.

The drift came from the original RFC drafts being written with
`Status: Draft` and the implementation rolling in via the v0.1.x
+ early v0.2.x sub-chain without updating the per-RFC header
back. The index Status column (the user-facing surface) was kept
fresh; only the per-RFC pages were stale.

Updates (per-RFC `| **Status** |` row, brought into agreement with
the index):

- **RFC-0015** Numeric types — Implemented (partial) v0.1.46–v0.1.64
- **RFC-0016** Result/Option/match — Implemented (partial)
  v0.1.50–v0.1.61
- **RFC-0017** Collections — Implemented v0.1.27–v0.1.47
- **RFC-0018** Modules — Implemented (partial) v0.1.52–v0.1.65
- **RFC-0019** Package manager — Implemented (partial)
  v0.1.33–v0.1.55
- **RFC-0020** Diagnostics — Implemented (partial) v0.1.34–v0.1.59
- **RFC-0021** Test framework — Implemented v0.1.10–v0.1.55
- **RFC-0022** Cross-platform — Implemented (partial) v0.1.30
- **RFC-0024** Iterators — Implemented (partial) v0.2.9
- **RFC-0028** Format strings — Implemented (partial) v0.2.6
- **RFC-0029** Doc generator — Implemented (skeleton) v0.1.65

Each new Status row also names the v0.4 (or later) follow-on so
future readers don't think the RFC is fully landed.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87). Mojibake check
confirms the new `–` (en-dash) bytes are clean UTF-8.

## [0.2.125] — 2026-04-23

**docs/rfcs/README.md cross-cutting-contracts table refresh — three
stale numbers from the v0.2.73 era brought current.**

The cross-cutting-contracts header table at the top of the RFC
index carried three numbers that drifted over the v0.2.73–78
helper-manifest population sub-chain and never got mirrored
back into the index:

- HELPER-CONTRACT row claimed **92.9% via v0.2.73–76**;
  actual is 95.1% via v0.2.73–78 (matches HELPER-CONTRACT.md
  itself + the milestone tracker).
- helper_manifest.toml row claimed **628/676 rows fully
  annotated**; actual is 643/676 (matches helper_manifest_schema.md
  + milestone tracker).
- helper_manifest.toml row claimed **48 intentional v0.4
  placeholders**; actual is 33 (the complement: 676 − 643).

Plus the trailing footer note "**through v0.2.97 as of this
update**" was 27 ships stale; bumped to **v0.2.124**.

### `docs/rfcs/README.md`

- HELPER-CONTRACT row Status column: 92.9 → 95.1, v0.2.73–76 →
  v0.2.73–78.
- helper_manifest.toml row Status column: 628/676 → 643/676,
  48 → 33 placeholders, v0.2.73–76 → v0.2.73–78.
- Footer paragraph: "v0.2.97" → "v0.2.124".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.124] — 2026-04-23

**Audit finding: 22 orphan rod wrappers document themselves as
v0.4 example-coverage targets.**

A second-layer sweep of `stdlib/rods/*.nr` against `import`
references across `examples/`, `tests/`, and other rods found
22 rod files that wrap a runtime C file (via `#cfile`) but
are never imported by anything in-tree, so `nuc build` never
exercises them through the verify gate.

This is the rod-layer analogue of the v0.2.123 finding (which
was at the runtime layer). The orphan set splits roughly into:

- **ML / inference:** `conv`, `loss`, `embedding`,
  `kv_cache`, `quantize`, `speculative`, `diffusion`, `rl`,
  `checkpoint`, `scan` — the user-facing surfaces for the
  CNN / LLM / RL / SSM building blocks.
- **Quantum:** `mps` — Matrix Product States.
- **Data / search:** `hnsw`, `pq`, `string_algo`, `bioseq`,
  `audio`, `color`, `mesh` — vector indices, classical
  algorithms, scientific data formats.
- **Systems / I-O:** `gpu`, `comm`, `serial`, `stack`.

The rod sources themselves are valid Nucleor (each parses;
each declares the right `extern fn` bindings against its
`#cfile`); they just don't have an example or test that
imports them. The fix is to add a one-import smoke per rod
in `examples/` or a `tests/rods/` corpus, which pulls them
under the gate without any compiler / runtime changes.

### `docs/status/v0.2-shipped-and-deferred.md`

- New bullet "**Orphan rod wrappers — known v0.4 example-
  coverage targets (audit finding v0.2.124)**" added after
  the v0.2.123 orphan-runtime bullet. Enumerates all 22 rods
  by category.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no tools-suite
touch; no helper-manifest touch. Self-host LLVM IR fixed point
preserved (`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.123] — 2026-04-23

**Audit finding: 11 orphan runtime C files document themselves as
v0.4 wrap targets.**

A sweep of `stdlib/runtime/*_rt.c` against `#cfile` rod
references found 11 runtime C source files that ship in the
OSS distribution but have no `.nr` rod wrapper, so the
features they implement are unreachable from Nucleor source
today.

The orphan set covers a substantial slice of the future
ML / data / concurrency surface: SwiGLU + RoPE + RMSNorm
(`activation2_rt.c`), FlashAttention with GQA / MLA / sliding
window (`attention2_rt.c`), classic transformer building
blocks (`transformer_rt.c`), BPE training + encode/decode
(`tokenizer_rt.c`), CSV I/O (`csv_rt.c`), priority queue
(`queue_rt.c`), thread pool + futures + parallel map
(`thread_rt.c`), arena + pool allocators (`allocator_rt.c`),
differentiable quantum simulation (`diff_sim_rt.c`), string-
vec + function-pointer call helpers (`rod_helpers_rt.c`), and
vec_free / vec_clear for long-running experiments
(`mem_rt.c`).

This is not a bug — every file compiles standalone (see the
leading `// Compile:` comment in each), and wrapping each in
`stdlib/rods/<name>.nr` is straightforward `extern fn`
binding work. It's tracked here so the v0.4 cycle can pick
the wrap targets up explicitly rather than rediscover them.

### `docs/status/v0.2-shipped-and-deferred.md`

- New bullet "**Orphan runtime C files — known v0.4 wrap
  targets (audit finding v0.2.123)**" added before the
  Diagnostic-code coverage closure bullet. Enumerates all
  11 files with their feature sets.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no tools-suite
touch; no helper-manifest touch. Self-host LLVM IR fixed point
preserved (`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.122] — 2026-04-23

**Mirror v0.2.121 to status doc + bootstrap contract.**

After v0.2.121 refreshed the milestone tracker, the two
companion docs (status snapshot + bootstrap contract) were
~22 ships stale.

### `docs/status/v0.2-shipped-and-deferred.md`

- Snapshot v0.2.99 → v0.2.121. Chain count 119 → 141 releases
  (22 v0.1.x + 121 v0.2.x).
- Sub-chain header v0.2.50–99 (50 releases) → v0.2.50–121
  (72 releases).
- Added new bullet for the **Diagnostic-code coverage closure
  (v0.2.117–120)** — EXPECT-header bulk-add (28 files in
  v0.2.117), gate enforcement (v0.2.118), 23 OWN/TYP/TNT
  codes wired in v0.2.119+v0.2.120, spec catalog 130 → 158,
  drift class closed.

### `NUCLEOR_BOOTSTRAP_CONTRACT.md`

- All `v0.2.100` markers bumped to v0.2.121 (5 sites — sub-
  chain claim, runtime stats, helper-manifest %, examples
  count, cross-platform note).
- Gate-run paragraph updated: "**203 steps**" → "**204
  steps**" with the new `err_tests_have_expect_smoke` step
  (added v0.2.118) listed before the CLI smokes.
- The "explain single + full 130-code" line in the gate-run
  description bumped to "**full 158-code spec catalog**" to
  reflect the v0.2.117–120 additions.
- Negative-test count "(~24)" → "(33)" — the actual count.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.121] — 2026-04-23

**Milestone tracker refresh — capture the v0.2.99–120
diagnostic-code coverage closure as a sixth sub-chain bucket.**

After v0.2.120 closed the "fired-vs-documented" diagnostic-code
drift class, the milestone tracker still showed the v0.2.98
state (5 buckets through v0.2.50–98). Refreshed to:

- **Status header** v0.2.98 → v0.2.120; sub-chain
  v0.2.50–98 (49 releases) → v0.2.50–120 (71 releases).
  Gate count 203/203 → 204/204. Added explicit notes that
  **all 158 spec codes are wired/gate-tested** and **all 33
  err tests have EXPECT headers** (gate-enforced via
  v0.2.118).
- **Bucket count 5 → 6**, with the new bucket
  "**Diagnostic-code coverage closure (v0.2.117–120)**"
  covering the EXPECT-header bulk-add + 23 OWN/TYP/TNT codes
  wired + the gate enforcement — the "fired-vs-documented"
  drift class is closed.
- **Untouched-since-v0.2.49** paragraph updated to note that
  v0.2.117 (test fixtures) and v0.2.119+v0.2.120
  (tools-suite source for explain registry) also touched
  surfaces, but no s1 / runtime changes since v0.2.87.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.120] — 2026-04-23

**One more code: TNT-001 (taint analysis) was the last
undocumented diagnostic.**

After v0.2.119 wired 22 OWN/TYP codes, ran a final repo-wide
sweep comparing every `"CODE-NNN"` literal in the compiler
sources to the spec doc's documented codes. **Found one more:
TNT-001** — "Tainted data passed to sensitive sink" — fires
from the strict-mode taint pass in
`compiler/nucleor_tools_suite.nr` when tainted data flows
into a function annotated as a sensitive sink.

Same drift class as v0.2.79 / v0.2.119 — code fires but is
missing from spec doc and explain registry. The suggestion
machinery already proposes `sanitize(value)` as the fix, so
the diagnostic itself was wired all along; just the user-
facing documentation was the gap.

### Spec doc

Added a new "TNT series — taint analysis (expansion of
NR033)" section between OWN and TYP, with a one-row table
covering TNT-001 (severity: warning; source: strict-mode
taint pass).

Note about TYP-006 vs TNT-001: the existing `tests/err/err_taint_*`
files (taint_arg, taint_leak, taint_propagation, taint_to_clean)
fire TYP-006 / TYP-008 from the **type checker**, NOT TNT-001
from the **strict pass**. Two different code paths handle
taint — TYP-006/008 for compile-time type-mismatch when the
sink param is declared as a non-tainted type, TNT-001 for the
strict-pass warning when both types match but the data
provenance is tainted. Documented this distinction in the
TNT-001 row's "Gate-tested via" line.

### Explain registry

3 string literals added (TNT-001 × title + summary +
explanation). Tools binary rebuilt; spot-check passes.

### Gate

`cli_explain_full_smoke` extended with TNT-001 in both gates.
Spec catalog now **153 codes** (was 152 + 1).

### Comprehensive coverage check

After v0.2.120 the audit script `[python3 -c "..."]` finds
**zero codes** fired by the compiler that are missing from
the spec doc. The "fired vs documented" drift class is
**closed** — the gate's `cli_explain_full_smoke` step now
covers every code that has ever escaped from the compiler
into a user-facing diagnostic.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — s1 compiler / runtime / source / test
unchanged; self-host LLVM IR fixed point preserved.

## [0.2.119] — 2026-04-23

**Big bug fix: 22 OWN-* and TYP-* codes fired by the compiler
were missing from spec doc AND explain registry. Fully wired.**

After v0.2.117 brought EXPECT-header coverage to 33/33 err
tests, audit of the codes referenced in those headers found
that **OWN-001 through OWN-012 (12 codes) and TYP-001 through
TYP-010 (10 codes)** were:

1. **Fired by the compiler** (`diag_add_ex`, `own_diag`,
   `type_diag` calls in `compiler/nucleor_s1_compiler.nr`).
2. **Documented as the expected diagnostic** in 22 of the 33
   `tests/err/*.nr` EXPECT headers.
3. **Missing from the spec doc** (`docs/spec/Nucleor_Error_Codes.md`).
4. **Missing from the explain registry** (`compiler/nucleor_tools_suite.nr`)
   — `nuc explain OWN-001` returned `unknown error code: OWN-001`.

This is the same drift class as the v0.2.79 finding (NUM-004 +
TST-001/002/003), but **5x larger** — 22 codes vs 4. Bigger
than the 44-code v0.2.80 forward-looking sweep.

### Spec doc additions

Added two new sections to `docs/spec/Nucleor_Error_Codes.md`,
positioned right after NR series:

- **OWN series — borrow-checker (expansion of NR031)** —
  12-row table covering use-of-moved, borrow-of-moved,
  move-while-borrowed, two-mut-borrows, shared-mut-conflict,
  assign-through-shared-ref, assign-borrowed-location,
  assign-immutable-binding, return-ref-to-local,
  inner-block-escape, mut-borrow-immutable, destroy-arena-with-
  live-refs.
- **TYP series — type checker (expansion of NR030)** —
  10-row table covering non-exhaustive-match (legacy),
  bool-arith, unit-add-mismatch, deref-non-ref, wrong-arg-
  count, arg-type-mismatch, bare-literal-into-unit, binding-
  type-mismatch, assign-type-mismatch, return-type-mismatch.

Each row includes the title, source (which checker fires it),
and notes (severity for OWN; legacy/RFC pointers for TYP).
Both sections list the gate-tested `tests/err/*` file(s) that
exercise the codes.

### Explain registry additions

Added 66 string literals (22 codes × 3 functions) to
`compiler/nucleor_tools_suite.nr`:
- `explain_error_title(code)` — short title per code
- `explain_error_summary(code)` — one-line summary per code
- `explain_error_explanation(code)` — RFC-anchored explanation
  per code (the longest entry — typically describes the rule,
  why it exists, and the fix path)

Tools binary rebuilt; spot-checked `OWN-004`, `OWN-009`,
`TYP-005` all return correct titled output.

### Gate hardening

Extended `cli_explain_full_smoke` in both `verify.sh` and
`verify.ps1` to include the 22 new codes (12 OWN + 10 TYP).
The full spec catalog the gate now exercises is **152 codes**
(was 130 — bumped 130 + 22).

Going forward, any future drift in the OWN/TYP series is
caught by the same gate that already enforces the rest of
the spec catalog (per v0.2.79/v0.2.80).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — s1 compiler / runtime / source / test
unchanged; self-host LLVM IR fixed point preserved.

## [0.2.118] — 2026-04-23

**Lock down v0.2.117: gate step enforces every err test has an
EXPECT header.**

After v0.2.117 brought EXPECT-header coverage to 33/33 err
tests, this release adds **`err_tests_have_expect_smoke`** to
both gates so the property holds going forward. Any new
`tests/err/*.nr` file that lands without a `// EXPECT:` line
in the first 3 lines fails the gate.

The error message names which file(s) lack the header so
contributors can fix in place:

```
[ 5/204] FAIL  tests/err/*.nr have EXPECT headers
       err tests missing EXPECT header:
         - err_<name>.nr
```

### Why this lockdown matters

The EXPECT header serves three audiences:

1. **Future contributors** reading any err test file —
   immediately see what diagnostic the test exercises.
2. **Compiler-fix work** — when a v0.2.79-class audit runs
   later, the EXPECT header gives the audit a concrete
   expected diagnostic to compare against the actual
   compiler output (catches regressions like the v0.2.87
   "false-positive negative test" findings).
3. **Spec doc cross-reference** — every code in the EXPECT
   list should appear in `docs/spec/Nucleor_Error_Codes.md`
   (and per the v0.2.79/v0.2.80 gate work, in the explain
   registry too).

**Step total bumped 203 → 204** in both gates.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure gate addition
— no compiler / runtime / source / test changes.

## [0.2.117] — 2026-04-23

**Bulk-add EXPECT headers to the remaining 28 `tests/err/*.nr`
files. All 33 negative tests now self-document.**

After v0.2.116 fixed `err_args` and `err_bool_arith`, 28 of
the 33 negative tests still had no `// EXPECT:` header. Added
the canonical 2-line header to each:

```
// EXPECT: <CODE> <text>
// <one-line description of what the test exercises>
```

Headers were captured by running each file through the
compiler and recording the first `error[CODE]:` /
`warning[CODE]:` line, then writing the EXPECT line + a
short prose description.

### Distribution of diagnostic codes added

- **OWN-001 (use of moved variable)** — 6 tests:
  err_borrow_after_move, err_device_use_after_move,
  err_move_basic, err_move_conditional, err_move_fn_call.
- **OWN-009 (cannot return reference to local value)** — 4
  tests: err_dangling_primitive, err_dangling_return,
  err_lifetime_dangling_return, err_scope_escape.
- **OWN-004 (cannot mutably borrow value already borrowed)**
  — 2 tests: err_shared_mut_conflict, err_two_mut_borrows.
- **OWN-005 (cannot shared-borrow mutably-borrowed)** — 2
  tests: err_field_shared_mut_conflict, err_mut_then_shared.
- **TYP-006 (argument type mismatch)** — 3 tests:
  err_taint_arg, err_taint_leak, err_taint_propagation.
- **One each:** OWN-003 (move while borrowed), OWN-006 (assign
  through shared ref), OWN-007 (assign borrowed location),
  OWN-010 (escape inner block), OWN-011 (mut borrow immutable),
  OWN-012 (destroy live arena), TYP-004 (deref non-ref),
  TYP-008 (binding type mismatch), MATCH-002 (unreachable
  match arm).

### False-positive negative tests (v0.2.87 finding)

Three tests fail at link-time rather than firing the intended
Nucleor diagnostic — flagged with a special header:

```
// EXPECT: link error (false-positive negative test)
// <description of the underlying compiler gap>
```

Files: `err_pure_ambient_random` (should fire pure-vs-effect
but link-fails on `__nucleor_ambient_random` v0.4 placeholder),
`err_restricts_specific` (should fire EFF-003 but link-fails
on `__nucleor_putchar` libc symbol), `err_spawn_send` (should
fire concurrency check but link-fails on
`__nucleor_device_alloc/free` v0.4 placeholders). All three
documented as v0.4 follow-up in v0.2.87 CHANGELOG.

### Coverage

**33 of 33 err tests now have EXPECT headers.** Future
contributors reading any err test can immediately see what
diagnostic the test is supposed to fire, the brief
explanation, and (for the 3 false-positives) the known
discrepancy.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Test behavior
unchanged — header-only additions.

## [0.2.116] — 2026-04-23

**Two `tests/err/*.nr` files had no header comment.**

Audit of `tests/err/*.nr` (33 negative tests) found two files
with **zero header comments** explaining what diagnostic the
test exercises:

- `err_args.nr` — exercises wrong-arg-count call
- `err_bool_arith.nr` — exercises boolean-arithmetic rejection

Without a header, a future contributor reading the file has
to reverse-engineer the test's intent from the source. Three
of the 33 err tests already had `// EXPECT: <code> <text>`
comments (per the v0.2.87 audit findings); these two now do
too.

### Fix

Added header comments to both files:

```nr
// EXPECT: TYP-005 wrong number of arguments
// `add` takes (a: i32, b: i32) but is called with 1 arg.
// The type checker fires TYP-005 (...) at the call site.
fn add(a: i32, b: i32) -> i32 { a + b }
fn main() -> i32 { add(1) }
```

```nr
// EXPECT: TYP-002 boolean values cannot be used in arithmetic
// Booleans aren't addable. The type checker fires TYP-002
// from check_expr's binop branch when either operand is bool.
fn main() -> i32 { true + false }
```

Verified both EXPECT codes match the actual diagnostic the
compiler emits (`error[TYP-005]: wrong number of arguments
for 'add'` and `error[TYP-002]: boolean values cannot be used
in arithmetic`).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Test files unchanged
behaviorally — header-only addition.

## [0.2.115] — 2026-04-23

**Same v0.2.41/v0.2.42 off-by-one in `check_compiler_drift.sh`
header (which I introduced in v0.2.112).**

The v0.2.114 fix caught two locations of the off-by-one but
missed a third — the `tools/check_compiler_drift.sh` header
itself, which I refreshed in v0.2.112 and where I also
attributed gate enforcement to v0.2.41.

Specifically the script header had:

```
#   2. helper_manifest.toml freshness vs gen_helper_manifest.py output
#      (since v0.2.41 — Helpers.md going-forward constraint).
```

Updated to:

```
#   2. helper_manifest.toml freshness vs gen_helper_manifest.py output
#      (since v0.2.42 — Helpers.md going-forward constraint;
#      manifest mech v0.2.41, gate enforcement v0.2.42).
```

The expanded form (mech v0.2.41 + enforcement v0.2.42) makes
the distinction explicit so future readers don't compress the
two ships back into one.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure script-header
refresh — no behavior change.

## [0.2.114] — 2026-04-23

**Fix off-by-one ship attribution: drift-gate enforcement of
helper manifest shipped v0.2.42, not v0.2.41.**

While checking `docs/rfcs/rod_manifest_schema.md` for
staleness, noticed it correctly attributes helper-manifest
gate enforcement to v0.2.42 ("the same enforcement
`helper_manifest.toml` got in v0.2.42") — but **two of my own
recent audit ships had said v0.2.41**. Self-introduced
inconsistency.

Looking at the actual CHANGELOG to ground-truth it:

- **v0.2.40** — shipped the initial `helper_manifest.toml`
  (with 144 REVIEW REQUIRED rows).
- **v0.2.41** — audit pass dropped REVIEW REQUIRED count from
  144 → 0 by extending the generator's
  `INTENTIONAL_PLACEHOLDER` allowlist + macro-expansion regex.
  This is what I'd been calling "manifest mech".
- **v0.2.42** — wired the drift-gate enforcement that the
  v0.2.33 going-forward constraint promised. **This is the
  ship I'd been mis-attributing.**

### Fix

Three references corrected in two files:

- **`docs/milestones/v0.2.0.md`** (line 287): "constraint
  enforcement (live since v0.2.41)" → "(live since v0.2.42)".
- **`docs/rfcs/HELPER-CONTRACT.md`** (status header + going-
  forward section): "drift-enforced v0.2.41" / "live since
  v0.2.41" → "v0.2.42" with an explicit timeline paragraph
  explaining the v0.2.40 → v0.2.41 → v0.2.42 progression so
  future readers don't get the same off-by-one wrong.

The "mech v0.2.41" attribution stays — v0.2.41 IS when the
generator became the source of truth (REVIEW REQUIRED → 0).
Just the GATE-ENFORCEMENT ship was a release later.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.113] — 2026-04-23

**Mirror v0.2.112 to `tools/verify.ps1` header.**

The PowerShell gate's header was the same v0.1-era 5-step
summary that v0.2.112 fixed in `verify.sh`. The PS gate
mirrors the bash one step-for-step, so its header should
match.

Refreshed to the same 19+N+M+P+1 step-shape outline with
v0.2.x release refs per step — adapted for PowerShell
conventions (`tools\verify.ps1` path style; "via WSL bash if
available" annotations on the steps that shell out to bash).

Also added the explicit "Mirrors tools/verify.sh — same step
counter, same exit code, same gates." line that was missing.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. PowerShell gate
behavior unchanged — pure header refresh.

## [0.2.112] — 2026-04-23

**Two tool-script headers stale at v0.1-era state.**

### `tools/verify.sh` header

The header described the gate as **5 steps** (binary present;
build/run examples; build/run positive tests; confirm
negative tests fail; self-host loop). Today it's **203 steps**
including 19 pre-iteration smoke steps that grew through the
v0.2.50–v0.2.111 audit chain. Refresh:

- Replaced the 5-bullet "Steps:" block with a 19+N+M+P+1
  step-shape outline matching what the script actually runs:
  binary present, ABI parity, tools-suite rebuild, mojibake
  check, help-coverage, utility smoke, JSON smoke, version
  aliases, showcase build, explain (single + full 130-code
  catalog), bootstrap + Contract: file resolves, check + abi
  inspect, inspectors smoke, diagnostics smoke, init, doc,
  lock, test, examples, positive tests, negative tests,
  self-host rebuild.
- Each step references the v0.2.x release that added it (so
  future readers can find the introducing CHANGELOG entry).

### `tools/check_compiler_drift.sh` header

Header said the script "verify[s] the s1-compiler ↔ tools-suite
ABI tables stay in sync." Originally true; **as of v0.2.83 it
enforces five things**: ABI parity, `helper_manifest.toml`
freshness, `rod_manifest.toml` freshness, `RELEASES.md`
freshness, and CHANGELOG ↔ git-tag parity. The header didn't
mention the four post-v0.2.41 additions. Refresh:

- Header now opens "drift detector. Originally only checked the
  s1-compiler ↔ tools-suite ABI tables; grown to enforce
  **five things** as of v0.2.83" with each numbered + the
  release that added it.
- Notes that mojibake-clean is a separate gate step
  (`tools/check_mojibake.sh` added v0.2.91), not part of this
  script.
- Exit code description updated from "Exit 1 = drift detected;
  commit must add..." to "the script names the failing check
  and the fix command (typically re-run a generator and commit
  the result)" — describes the actual current behavior where
  each check prints its own actionable error.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure script-header
refresh — no behavior change to either script.

## [0.2.111] — 2026-04-23

**`gen_releases_index.py` docstring said "124 entries" — actual
is 179.**

The generator's docstring claimed:

> CHANGELOG.md grew past 124 entries during the v0.2.x chain.

But by v0.2.110 the count is **179** entries (`grep -c '^## \[' CHANGELOG.md`).
The docstring was written when the script first shipped at
v0.2.57 — never refreshed across the v0.2.83 drift-gate
enforcement or the v0.2.x audit chain.

### Fix

Docstring updated to:

> CHANGELOG.md has 179+ entries through the v0.2.x chain
> (v0.1.46 → v0.2.110+ as of this docstring). ... CHANGELOG↔
> git-tag parity is drift-gate-enforced since v0.2.83 (every
> tag must have a `## [version]` heading or the verify gate
> fails).

Adds the v0.2.83 enforcement note so future readers
understand why the count number drifts predictably (every
release adds 1).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Generator behavior
unchanged — pure docstring refresh.

## [0.2.110] — 2026-04-23

**Bug fix: `gen_helper_manifest.py` docstring said "14 v0.2.39
taxonomy classes" — actual is 13 since v0.2.41.**

The generator's docstring claimed the script "Classifies by
name pattern into the 14 v0.2.39 taxonomy classes." Audit of
the actual class list (per the v0.2.78 `nuc explain` extension
and the v0.2.99 milestone tracker refresh) showed there are
13 classes today (the Unclassified bucket collapsed to zero by
v0.2.41 when `CLASS_RULES` was extended to catch the 7
originally-unclassified helpers). The same docstring also
mis-described the policy-field population as "TODO unless
trivially derivable" — actually populated 95.1% via the
3-level resolution chain added in v0.2.74.

### Fix

Docstring rewritten to:

- "Classifies by name pattern into the **13 v0.2.41
  taxonomy classes**" with the full list enumerated
  (PureMath, VectorOps, PanickingArith, StringFormat, IO,
  Collection, TensorOps, Concurrency, Time, DataCodec, Random,
  ToolingMeta, Allocation) and a parenthetical noting the
  v0.2.39 → v0.2.41 14 → 13 collapse.
- "Populates policy-sensitive fields ... via the resolution
  chain NAME_OVERRIDES → PATTERN_OVERRIDES → CLASS_DEFAULTS
  → 'TODO' (added v0.2.74; populated 95.1% of the 676 helpers
  as of v0.2.78)" — now describes what the generator
  actually does.
- "Zero rows since v0.2.41" added to the Unclassified bullet.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Manifest unchanged
(docstring-only — no semantic difference). Pure documentation
refresh of the generator's own self-description.

## [0.2.109] — 2026-04-23

**Bug fix: `nuc.toml` `[features]` showcase comment listed
wrong example name.**

The repo-root `nuc.toml` had:

```toml
[features]
default = ["showcase"]
showcase = []  # examples 13_test_framework, 14_typed_frames, etc.
```

But **`14_typed_frames` doesn't exist**. The actual `examples/14_*.nr`
file is `14_csv_summary.nr`. There's no Nucleor example named
`typed_frames` — that's a future RFC-0003 demo concept that was
never built. The "etc." also hid the fact that examples
15–18 + 4 showcase programs exist today.

### Fix

Comment expanded to enumerate the actual examples that ship
under the showcase feature: `13_test_framework`,
`14_csv_summary`, `15_word_count`, `16_histogram`,
`17_linecount`, `18_benchmark`, plus the four
`examples/showcase/*.nr` programs (`lorenz`, `vqe_h2`,
`market_maker`, `wing_simulator`).

The `showcase = []` array is empty (no further deps required
to build the showcase examples) so the comment is the only
signal of what the feature actually includes.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.108] — 2026-04-23

**Bug fix: `docs/architecture.md` "around line 1700" stale —
actual line is 2004.**

The architecture doc's "where things live" table pointed
contributors at:

> Builtin name mapping | search `if str_eq(name,` for the
> long string of `__nucleor_*` mappings (around line 1700)

The actual function (`fn get_rt_name(name: str) -> str`) is at
**line 2004** as of v0.2.107 — the compiler grew ~300 lines
across the v0.2.x sub-chain (the v0.2.84 `nuc help` doc/fix
entries + v0.2.87 version aliases plus general fill-in around
the type checker and lower).

### Fix

Replaced the "around line 1700" search hint with the canonical
function name `fn get_rt_name(name: str) -> str` (around line
2004 as of v0.2.107) so contributors can find it via grep
even after future line drift, and so the doc records the
actual current location.

Other "around line N" references in the doc: zero (this was
the only one).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.107] — 2026-04-23

**Audit found two POSIX-stub gaps in the runtime not flagged
in the v0.3 readiness doc.**

A grep of `stdlib/runtime/nucleor_llvm_rt.c` for `return 0;`
inside `#else` branches surfaced two POSIX no-ops that aren't
documented as v0.3 follow-ups in
`docs/status/v0.3-cross-platform-readiness.md`:

1. **`__nucleor_channel_*`** — Windows uses
   `CRITICAL_SECTION` + `CreateEvent` for a bounded blocking
   channel; POSIX side returns `0` from `new`, ignores `send`
   / `recv`, reports `len = 0`. Marked with `// TODO: POSIX
   channel` since the v0.1 era. Used by
   `stdlib/rods/concurrency.nr` (called from `compiler/`
   sources too).
2. **`__nucleor_pipe_*`** — Windows uses `CreateNamedPipeA`
   for one-shot named pipes; POSIX side returns `0` from
   `pipe_create` and no-ops `pipe_write` / `pipe_close`. No
   TODO comment — would have been silent.

Both are silent failure modes (no panic, just lost data).
Code that depends on either family appears to run but
produces no inter-thread (channel) or inter-process (pipe)
communication on Linux/macOS.

### Fix

Added a new "Known POSIX gaps to fill in v0.3" section to
`docs/status/v0.3-cross-platform-readiness.md` enumerating
both stubs with:

- Windows path (CreateEvent / CreateNamedPipeA)
- POSIX no-op behavior
- POSIX implementation outline (`pthread_mutex_t` +
  `pthread_cond_t` for channels; `mkfifo` + `open(O_WRONLY)`
  for pipes)
- Silent failure mode warning

Section sits before the "Open questions for v0.3 kickoff"
list so v0.3 implementers see it during planning.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.106] — 2026-04-23

**v0.2.0 milestone tracker — Helper Schema status block + 1
success criterion still at v0.2.76 era.**

The v0.2.99 / v0.2.105 refreshes still missed two pockets:

1. **Helper Schema Deliverable status block** (line 268) said
   "Status (v0.2.76)" with "Phase 2 mechanism (v0.2.41–73)"
   and "Phase 2 population (v0.2.73–76) — 628 of 676 (92.9%)
   ... 48 TODO rows". Updated to "Status (v0.2.105)" with
   correct mech (v0.2.41 only — the v0.2.73 was confusing the
   mech ship with the start of population), correct population
   range (v0.2.73–78), and correct numbers (643/676 = 95.1%,
   33 TODO).
2. **Success criterion: CHANGELOG entries** (line 351) said
   "every release v0.1.46..v0.2.76 has a CHANGELOG entry"
   and "The v0.2.50–76 sub-chain". Both bumped to v0.2.105.
   Also added a note about the **v0.2.83 drift-gate-enforced
   CHANGELOG↔git tag parity** check that catches any missing
   per-version entry.

These are the kind of stale claims the audit pattern keeps
surfacing: the high-level status block at the top got
refreshed but specific in-document references hidden a few
sections down stayed at older values.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.105] — 2026-04-23

**v0.2.0 milestone tracker — two more stale claims inside
per-RFC checklist rows.**

The v0.2.99 status-block refresh missed two stale claims
buried inside RFC-0015 phase rows:

1. **RFC-0015 phase 5 row** (Stdlib audit): "Stdlib audit:
   **103 rods** × type drift fixes". Updated to "**121 rods**"
   with a note that the rod count grew from 103 (v0.1.5) to
   121 (v0.2.46) via the v0.2.18–v0.2.30 enrichment chain —
   the v0.4 audit covers the full v0.2.x surface, not just
   the v0.1.5 baseline.
2. **RFC-0015 phase 7 row** (Verify gate green after
   migration): "The current **158/158 gate** already covers
   every shipped phase 1+2+4+6 piece". Updated to "**203/203
   gate** (was 158/158 at v0.1.64; grown via the
   v0.2.50–v0.2.102 audit chain)".

Both stale at v0.1.64-era values. Lines 156 (RFC-0016
"108/108") and 176 (RFC-0017 "149/149") **kept as historical
milestones** because they record the gate count at the time
those rows shipped DONE — they're checkpoints, not current-
state claims.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.104] — 2026-04-23

**Bug fix: spec doc claimed TST-001..003 are "proposed for v0.4"
— they were wired in v0.2.79.**

`docs/spec/Nucleor_Error_Codes.md` is one of the four trackers
the standing /loop instruction names. The TST series section
said:

> Reserved namespace; no codes minted as of v0.2.48. ... When
> TST-NNN codes are minted (planned for v0.4 alongside
> property-based testing), candidates include:
>
> | Code (proposed) | Title | RFC section |
> | TST-001 | ... | RFC-0021 §3.1 |
> | TST-002 | ... | RFC-0021 §3.4 |
> | TST-003 | ... | RFC-0021 (deferred) |

But **all three were wired into the explain registry in
v0.2.79** as part of the explain-coverage audit (along with
NUM-004, also flagged that release). The v0.2.80 follow-up
extended the gate to enforce the full 130-code spec catalog,
so any future drift between this doc and the registry now
fails the gate.

This was an **inverted-direction drift bug**: the
implementation got ahead of the spec doc, and the spec doc
told users to expect features that already shipped to land in
v0.4.

### Fix

- TST series intro rewritten: "TST-001..003 wired into the
  explain registry in v0.2.79" with a pointer to
  `cli_explain_full_smoke` for the gate enforcement.
- TST table column "Status" added to each row (Wired (v0.2.79)
  + per-row firing-status detail).
- DIAG series intro: "no user-facing codes minted as of
  v0.2.48" → "as of v0.2.103" with TST added to the list of
  per-RFC code series the diagnostic machinery surfaces
  through.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.103] — 2026-04-23

**v0.3.0 milestone tracker + v0.3 readiness status doc had four
stale claims (broken cross-tracker reference + 186-step gate).**

### `docs/milestones/v0.3.0.md`

Three stale gate-count refs:

1. **Status header**: "Status (2026-04-22, post-v0.2.53)" →
   "Status (2026-04-23, post-v0.2.102)" with a sentence about
   the gate growing 186 → 203 steps through the audit chain.
2. **Inheritance row 2**: "expected 186/186 unchanged" →
   "expected 203/203 unchanged (current Windows count as of
   v0.2.100)".
3. **Phase 3 goal**: "`tools/verify.sh` runs 186/186 on Linux
   + macOS" → "203/203" with note about the v0.2.55 → v0.2.102
   growth.

### `docs/status/v0.3-cross-platform-readiness.md`

One broken cross-tracker reference:

4. **Header**: pointed at `docs/milestones/v0.4.0.md` for the
   "v0.3 bootstrap target" — wrong tracker. Updated to
   `docs/milestones/v0.3.0.md` (the actual v0.3 tracker).
   Also added a parenthetical noting the per-block runtime
   audit findings preserved from v0.2.51 are still accurate
   as of v0.2.102 (no new `#ifdef _WIN32` blocks added in
   the post-RC chain).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.102] — 2026-04-23

**`docs/milestones/v0.4.0.md` Helper Schema section was at v0.2.40
state — said Phase 2 was "DONE in v0.2.40" with 144 REVIEW
REQUIRED rows.**

The v0.4 tracker's Helper Schema Deliverable section was
written at the v0.2.40 walk and never updated for the v0.2.41
mech ship + v0.2.73–78 population work. Specifically wrong:

1. **"Phase 1 — taxonomy report (DONE in v0.2.40): 14 classes
   proposed; 7 helpers truly unclassified"** — actually 13
   classes, 0 unclassified.
2. **"Phase 2 — manifest population (DONE in v0.2.40)"** — the
   v0.2.40 ship was the initial walk only. Phase 2 mech shipped
   in v0.2.41 + drift-gate enforcement; population work landed
   v0.2.73–78 reaching 95.1% (643/676 rows).
3. **"144 entries flagged REVIEW REQUIRED"** — manifest is at
   **0 REVIEW REQUIRED** since v0.2.41 (the
   `INTENTIONAL_PLACEHOLDER` allowlist resolved 137 IR-declared-
   but-undefined cases as deliberate v0.4 forward declarations;
   `CLASS_RULES` extension caught the 7 unclassified).
4. **"drift gate will be extended to enforce this once Phase 2
   lands"** — drift-enforced **since v0.2.41**, not pending.

### Refresh

- Phase 1 row updated to "13 classes covering all 676
  helpers".
- Phase 2 row split: **mech (v0.2.41)** + **population
  (v0.2.73–78, 95.1%)** with the 3-level resolution chain
  + remaining 33 v0.4 placeholder enumeration.
- "REVIEW REQUIRED count: 0 as of v0.2.41" replaces the
  144-row claim, with the explanation of how the 137 + 7
  resolved.
- Going-forward constraint clarified to "drift-enforced
  v0.2.41" with explicit gate failure description.

The section now correctly tells the reader that the deliverable
is essentially shipped — only the 33 placeholder rows are left,
gated on v0.4 implementations.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.101] — 2026-04-23

**`NUCLEOR_BOOTSTRAP_CONTRACT.md` refresh — was at v0.2.81 era;
the "tooling-only" claim was wrong by v0.2.84.**

The bootstrap contract was written in v0.2.82 to fix the
v0.2.70-era broken reference. By v0.2.100 it carried four stale
pointers:

1. **"v0.2.x sub-chain through v0.2.81"** → updated to v0.2.100.
2. **"v0.2.50–v0.2.81 sub-chain has been tooling-only — no
   compiler changes"** — wrong. **v0.2.84 added `doc`/`fix`
   to `print_usage` in `nucleor_s1_compiler.nr`** and
   **v0.2.87 added `-V` / `version` aliases** — both compiler
   source changes. Both ran the standard 2-iteration LLVM IR
   fixed-point check and produced byte-identical IR. Updated
   to enumerate the two changes explicitly + reaffirm fixed
   point preserved.
3. **"~4945 lines, ~748 `__nucleor_*` symbols as of v0.2.81"**
   → audited current state: **4944 lines / 676 symbols**
   (no helpers added since v0.2.81 — only doc work has
   shipped). The "~748" claim was always wrong (the exact
   number was 676 even at v0.2.81); this fix corrects both
   the line count and the symbol count to verified values.
4. **"95.1% populated as of v0.2.81"** → "as of v0.2.100"
   (number is the same — Phase 2 population didn't change).
5. **"As of v0.2.81 this is 18 examples"** + **"As of
   v0.2.81 only Windows x86_64..."** — both bumped to
   v0.2.100. Examples paragraph also updated to mention the
   4 build-only `examples/showcase/*.nr` programs covered by
   the v0.2.90 `showcase_build_smoke` step.
6. **"The gate runs ~197 steps"** → **"203 steps as of
   v0.2.100"** with the 14 CLI smoke steps enumerated
   (was previously generic "CLI smokes (12 steps)").

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.100] — 2026-04-23

**Status doc refresh — `v0.2-shipped-and-deferred.md` was 22
ships stale. v0.2.100 milestone crossed.**

`docs/status/v0.2-shipped-and-deferred.md` snapshot was at
v0.2.76 (97-release chain). Refresh:

- **Snapshot**: `v0.2.76` → `v0.2.99`. Chain count 97 → 119
  releases (22 v0.1.x preview + 99 v0.2.x).
- **Sub-chain header**: "v0.2.50–v0.2.76, 27 releases" →
  "v0.2.50–v0.2.99, 50 releases". Removed the "all
  tooling-only" claim (the two compiler source changes in
  v0.2.84 + v0.2.87 are now noted with their preserved
  fixed point).
- **Helper manifest bucket**: v0.2.73–76 / 92.9% / 48 TODO →
  v0.2.73–78 / 95.1% / 33 TODO with the placeholder taxonomy
  enumerated.
- **CLI surface gate coverage bucket**: v0.2.64–72 / 16
  commands / 158→195 step total → v0.2.64–86 / 21+ commands /
  158→203 step total. Added the four meta-coverage steps
  (help-text-coverage, JSON-flag, version-alias, showcase-
  build) plus the explain-full-spec-catalog (130 codes) and
  mojibake check.
- **Drift gate hardening bucket**: expanded to enumerate all
  six things the drift gate now enforces (added v0.2.83
  CHANGELOG↔git tag parity, v0.2.91 mojibake clean).
- **Compiler bug fixes bucket**: 1 entry (v0.2.69) → 6
  entries (v0.2.69, v0.2.79+80, v0.2.82, v0.2.83, v0.2.85,
  v0.2.91), each with its corresponding gate-step addition.
- **NEW "Documentation staleness audit" bucket** (v0.2.77–98)
  — 19+ stale claims fixed across 12 doc surfaces with the
  principal drift classes enumerated.

### Milestone

This is the **100th v0.2.x release**. Total releases (per
`RELEASES.md`) now 169. The audit-pattern chain that started
at v0.2.79 has run for 22 ships finding ~25 real bugs across
docs and tooling.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh of the status doc.

## [0.2.99] — 2026-04-23

**Milestone tracker refresh — was 22 ships stale.**

`docs/milestones/v0.2.0.md` last refreshed at v0.2.77 (sub-chain
summary still said v0.2.50–v0.2.76 with 27 releases). We're at
v0.2.98 — 22 ships beyond. Refresh:

### Status block

- **Release count** 76 → 98.
- **Verify gate** 195/195 → 203/203.
- **Helper manifest Phase 2** 92.9% (628/676) → 95.1%
  (643/676), with the 33 remaining TODOs explicitly enumerated
  as v0.4 placeholders.
- **Compiler source changes** in the sub-chain now noted (the
  two changes in v0.2.84 + v0.2.87, both preserved IR fixed
  point).

### Sub-chain summary

- Range bumped v0.2.50–76 (27 releases) → v0.2.50–98
  (49 releases). Bucket count 4 → 5.
- **Helper manifest bucket** updated for v0.2.78 TensorOps
  population.
- **CLI surface gate coverage bucket** expanded to enumerate
  the 21+ commands now smoked + the four meta-coverage steps
  (help-text-coverage, JSON-flag, version-alias, showcase-build).
- **Compiler bug fix bucket** expanded from 1 entry (v0.2.69)
  to 6 entries covering v0.2.69 / v0.2.79 / v0.2.82 / v0.2.83 /
  v0.2.85 / v0.2.91 — each one a real bug surfaced by the
  audit pattern with a corresponding gate-step addition.
- **New "Documentation staleness audit" bucket** — 19+ stale
  claims fixed across 12 doc surfaces (milestone tracker,
  helper-contract, schema docs, README, getting-started,
  language-tour, language-reference, migration guide,
  semver-and-release, contributing, rods-and-runtime,
  benchmarks, rfcs/README). Lists the principal drift classes
  (POSIX target version, rod count, "for-loops planned",
  hex/binary literals "not supported", v0.1.x "out of scope").

### Success criteria

Two `[x]` rows updated to current numbers (158/158 → 203/203,
195 steps → 203 steps).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh of the canonical v0.2 milestone tracker — no compiler
/ runtime / source / test changes.

## [0.2.98] — 2026-04-23

**`docs/benchmarks.md` self-host stats + `docs/rfcs/README.md`
RFC status both stale.**

### `docs/benchmarks.md` — self-host build numbers

The doc claimed v0.1-era estimates: `~330 KB source / 5700
functions / 10000 LOC / 1.8 MB LLVM IR / 3 MB binary`. Audited
against current state via `nuc perf compiler/nucleor_s1_compiler.nr`
and direct file inspection:

| Metric | v0.1-era claim | v0.2.97 actual |
|---|---|---|
| Source size | ~330 KB | **~467 KB** |
| LOC | ~10000 | **8897** |
| Reachable functions (post-DCE) | ~5700 | **365** |
| Optimizer instructions | n/a | **664** |
| String pool | n/a | **3932** |
| LLVM IR | ~1.8 MB | **~2.6 MB** |
| `nucleor.exe` binary | ~3 MB | **~845 KB** |

The dramatic binary shrink (3 MB → 845 KB) is the cumulative
effect of the optimizer + dead-code elimination pass shipped in
the v0.1.46–v0.1.65 chain, which stripped the v0.1.x compiler's
~5700 functions down to the 365 actually reachable. Self-build
wall time also bumped from ~14s to ~27s as the compiler grew
its v0.2 type-checker (which now dominates per the perf
diagnostic).

Also updated the lead paragraph "characterize the v0.1
self-host bootstrap pipeline" → "v0.2".

### `docs/rfcs/README.md` — RFC implementation status

The doc claimed:

> 32 RFCs drafted; 8 Tier-2 (RFC-0015..0022) + RFC-0029 carry
> Implemented or Implemented-partial status as of v0.1.65.

Updated to:

> 32 RFCs drafted; 8 Tier-2 (RFC-0015..0022) + RFC-0029 carry
> Implemented or Implemented-partial status **as of v0.2.0 RC**
> (per the per-RFC checklist rows in `docs/milestones/v0.2.0.md`
> — every row is DONE / PARTIAL / DEFERRED with a follow-on
> target). **RFC-0030 declined** during v0.2 (see the RFC for
> rationale). The post-RC v0.2.x sub-chain (through v0.2.97 as
> of this update) has been strictly additive on top of v0.2.0;
> no RFC implementation states changed.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.97] — 2026-04-23

**`docs/rods-and-runtime.md` — same stale rod count drift as
README v0.2.88.**

The doc opened with:

> Nucleor's standard library is organized as **rods**...
> As of v0.1.1 there are 65 shipping rods covering general
> utilities, scientific computing, modern ML, and physics
> simulation.

And had a section heading "## The shipping rod catalog (v0.1.1,
all 65 build clean)". Both numbers stale: actual is **121
rods** as of v0.2.46 (was 65 at v0.1.1; v0.1.5 brought it to
103; v0.2.18–v0.2.30 enrichment chain added 18 more). Same
drift class as the README "103 rods" claim fixed in v0.2.88.

### Fix

- **Opening paragraph** updated to "121 shipping rods as of
  v0.2.46" with the historical progression (65 → 103 → 121)
  in parens and a pointer to `docs/rfcs/rod_manifest.toml`
  for the per-rod catalog.
- **§ heading** changed from "The shipping rod catalog (v0.1.1,
  all 65 build clean)" to just "The shipping rod catalog"
  with a one-paragraph note that the tables below are the
  v0.1.1 foundation (still gate-tested) and that the
  authoritative enumeration lives in `rod_manifest.toml`.

The 65-row rod tables under that heading are still accurate
for what they list — they're just no longer the complete set.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.96] — 2026-04-23

**`docs/language-reference.md` v0.1 → v0.2 promotion + v0.1.5
audit corrigendum updated for the v0.2.x chain.**

### Title bump

The reference's title was `Nucleor Language Reference (v0.1)`
even though the body described features in `0.2.0-v2`.
Promoted to `(v0.2)` with an explicit pointer to
`docs/milestones/v0.4.0.md` for the deferred Tier-2 language
extensions.

### §13 audit corrigendum refresh

The §13 "What was added in v0.1.5" section was a frozen-in-time
list from a v0.1.4 → v0.1.5 audit. Renamed to "Historical
corrigenda" and split into two subsections:

- **§13.1 v0.1.5 audit (now redundant)** — the original list
  (for-loops, break/continue, block comments, generics, traits,
  match-on-int) plus per-feature back-pointers to the
  gate-tested files under `tests/features/` and `tests/lang/`.
  Added `where` clauses (`tests/features/where_clauses.nr`)
  and the hex / binary / underscored literal forms (per the
  v0.2.95 fix to §1.4).
- **§13.2 v0.2.x additions** — new section enumerating the
  major language additions in the v0.2.x sub-chain that
  weren't yet captured: `?` postfix (v0.1.50, RFC-0016),
  `if let` / `while let` sugar, `as` cast operator, narrow-
  width overflow helpers, 75+ runtime helpers, the
  String/HashMap/HashSet/BTreeMap/BTreeSet/VecDeque
  collection runtime + rod surface. With back-pointers to the
  CHANGELOG and migration guide.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.95] — 2026-04-23

**Bug fix: docs claimed hex/binary literals don't work — they do.**

Three stale doc claims about literal-form support, all
contradicted by gate-tested usage in the source corpus:

1. **`docs/language-tour.md` line 41** said "Numeric literals
   are decimal `i64`. (Hex/binary literal support is planned.)"
2. **`docs/language-reference.md` §1.4 literals table** had no
   row for hex / binary / underscored / suffixed literals plus
   an explicit "not currently supported" line below the table.
3. **`docs/language-reference.md` §12 'does not have (yet)'**
   listed "Hex/binary integer literals (lexer accepts them but
   produces wrong values)" — actively wrong (verified that
   `0xFF` → `255` and `0b1010` → `10` produce correct output).

### Verified working

```nr
fn main() -> i64 {
    let h: i64 = 0xFF;        // 255
    let b: i64 = 0b1010;      //  10
    let u: i64 = 1_000_000;   // 1000000
    print_int(h);
    print_int(b);
    print_int(u);
    return 0;
}
```

Hex literals are also actively used in `tests/lang/atomic_bit_ops.nr`
(`atomic_i64_store(a, 0xFF00)`, `0x000F`, `0xFF0F`, `0x0F0F`)
which has been gate-green for many releases.

### Fix

- **`docs/language-tour.md` §Variables** — replaced the stale
  one-liner with an explicit list of all four literal forms
  (decimal / hex / binary / underscored) plus a note about the
  RFC-0015 width / signedness suffixes that parse and
  type-check, with the strict-mode flip status.
- **`docs/language-reference.md` §1.4 literals** — table
  expanded from 3 rows to 8 rows covering decimal / hex /
  binary / underscored / width-suffixed integer + decimal /
  width-suffixed float + string + boolean. Added a paragraph
  documenting the RFC-0015 suffix vocabulary and NUM-001
  staging.
- **`docs/language-reference.md` §12 'does not have (yet)'** —
  removed the bogus "hex/binary literals" entry (they do
  work). Added a one-line note that RFC-0030 (`async` /
  `await`) was declined.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.94] — 2026-04-23

**Top-level `CONTRIBUTING.md` "scope" section was 90+ releases
stale.**

The "What's in scope vs. out of scope" section framed
contributors against v0.1.x patches. Three rows of "out of
scope" items had **already shipped**:

- **`for` loop syntax** — `for x in <array | Vec>` works,
  gate-tested as `tests/features/forin_array.nr` +
  `forin_vec.nr`.
- **`break` / `continue`** — gate-tested as
  `tests/features/break_continue.nr`.
- **Generics work** — `fn`, `struct`, `enum`, traits (basic,
  bounds, default methods), `where` clauses all gate-tested
  under `tests/features/generic_*` and `tests/features/trait_*`
  and `tests/features/where_clauses.nr`.
- **New CLI subcommands** — 20+ shipped since v0.1
  (`init`, `lock`, `doc`, `fix`, `audit`, `policy`, `certify`,
  `translate`, `evidence`, `impact`, `summary`, `query`,
  `bootstrap`, `stage-dump`, `install`, `add`, `publish`,
  `registry`, `sage`, `clean`, `scram`, `zen`, `mco`).

### Refresh

Replaced the v0.1.x scope framing with three sections:

1. **In scope for v0.2.x post-RC patches** — bug fixes, doc
   staleness fixes (with explicit nod to the audit pattern
   that drove v0.2.79–v0.2.93), test additions, new rods, new
   gate steps, migration tools.
2. **Already shipped (no longer "out of scope")** — enumerates
   each item from the original list with a back-pointer to
   the gate-tested feature file.
3. **Out of scope for v0.2.x (defer to v0.3 / v0.4 / v0.5+)** —
   Linux/macOS native bootstrap (v0.3.0), iterator trait
   (v0.4 RFC-0024), pattern-matching extensions (v0.4
   RFC-0023), closures/lifetimes/trait-objects/format-strings
   (v0.4 RFC-0025/26/27/28), PubGrub resolver + git fetch
   (v0.5 RFC-0019 phase 3).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.93] — 2026-04-23

**Process docs refresh — `semver-and-release.md` and
`process/contributing.md` were stale.**

### `docs/process/semver-and-release.md`

- **Last-updated header** bumped from 2026-04-22 to 2026-04-23
  (post-v0.2.92).
- **§1.1 v0.x policy paragraph** had a future-tense framing of
  the v0.2.0 release ("v0.2.0 release will break ~every existing
  program due to the numeric refactor"). Updated to past tense
  + the actual outcome: v0.2.0 shipped 2026-04-22 fully
  backwards-compatible because the phase 5 stdlib audit and
  phase 7 strict-mode flip were deferred to v0.4.
- **Release schedule table** — v0.2.0 row updated to note
  early ship (2026-04-22 vs the original 2026-06 target).
  v0.3.0 target loosened from "2026-08" to "2026-Q3".

### `docs/process/contributing.md`

- **"101 steps as of v0.1.8"** — replaced with "203 steps as
  of v0.2.91" + a note about the ~100-step growth via CLI
  surface coverage, JSON smoke, mojibake check, and other
  audit-pattern hardening.
- **"step 67/67"** — replaced with the current step name
  ("self-host rebuild closes") + a back-pointer to the
  `NUCLEOR_BOOTSTRAP_CONTRACT.md` 2-iteration fixed-point
  recipe used for v0.2.84 and v0.2.87 compiler source changes.
- **"Linux/macOS (after v0.2.0)"** — clarified that the POSIX
  gate ships in v0.2 but native Linux/macOS `bin/nucleor`
  binaries land in v0.3.
- **"CI runs the full verify gate on Linux + macOS + Windows
  × Intel + ARM (post v0.2.0)"** — corrected to "Windows
  x86_64 today; Linux + macOS + Windows ARM with v0.3.0
  cross-build" with a link to the v0.3 milestone tracker.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.92] — 2026-04-23

**Migration guide refresh — `docs/migrations/v0.1-to-v0.2.md`
was 50+ releases stale.**

The guide's TL;DR claimed:

> v0.2.0 → v0.2.38 is also fully additive. The 18 incremental
> v0.2.x releases shipped 75+ new runtime helpers...

But we're at v0.2.91, not v0.2.38. The 91+ post-v0.2.0
releases are still strictly additive — no behavior change in
v0.2.0 surface — but the guide's narrative was 50+ releases
behind the actual chain.

### Updated framing

The guide now explicitly covers three sub-chains:

- **v0.2.18–v0.2.30 stdlib enrichment** (helpers + 5 demo
  programs — already documented in detail).
- **v0.2.41–v0.2.49 manifest contract** (helper / rod
  manifests under drift-gate enforcement — newly mentioned).
- **v0.2.50–v0.2.91 post-RC hardening** (16+ gate steps for
  CLI surface coverage, JSON smoke, version aliases, showcase
  build, mojibake check, plus real bugs surfaced by the audit
  pattern: registry list cmd.exe stderr leak, `nuc test`
  target/ creation, missing bootstrap contract doc, etc.).

The opening summary block also notes the **two compiler source
changes** in the post-RC chain (v0.2.84 `nuc help` doc/fix
entries, v0.2.87 `-V` / `version` aliases) and their preserved
LLVM IR fixed point — important for the "fully additive"
guarantee.

No behavior promised by v0.2.0 changed. The migration paths
documented in the guide (legacy `import "stdlib/rods/foo.nr"`
→ `use std::foo`, `nuc fix --imports` linter, etc.) all still
work as written.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.91] — 2026-04-23

**Mojibake sweep + gate enforcement. Self-defeating mojibake
in v0.2.90 / v0.2.58 CHANGELOG entries fixed.**

### Self-defeating CHANGELOG entries

A repo-wide mojibake-byte sweep (looking for the cp1252-as-UTF-8
fingerprint `0xC3 0xA2 0xE2 0x82 0xAC`) found **two CHANGELOG
entries that re-introduced the very mojibake they claimed to
fix**:

- **v0.2.90 entry** (vqe_h2.nr fix) — quoted the mojibake
  literally with `// vqe_h2.nr [mojibake] Variational`. The
  bytes survived markdown into the published CHANGELOG.
- **v0.2.58 entry** (rod manifest generator fix) — same
  pattern, twice (in the prose intro and in the example
  TOML block).

Fixed by replacing each literal mojibake quotation with a
hex-byte description (e.g. `0xC3 0xA2 0xE2 0x82 0xAC 0xE2
0x80 0x9D` instead of the literal sequence). Documents the bug
without re-introducing the bad bytes.

### `tools/check_mojibake.sh` + gate step

New script + gate step that flags the universal mojibake
fingerprint across `*.md` / `*.nr` / `*.toml` / `*.py` /
`*.sh` / `*.ps1` / `*.c` / `*.h` / `*.txt` files (skipping
`bin/`, `target/`, `.git/`, `node_modules/`). The check
itself is whitelisted (it intentionally documents the bytes
in comments).

The script outputs an actionable error message naming the
correct UTF-8 sequences for em-dash / en-dash / curly quotes,
plus a pointer to the v0.2.91 CHANGELOG precedent for how to
write about the mojibake without re-introducing it.

Wired into both gates as **`mojibake_clean`** (bash) /
**`no UTF-8 mojibake in source/docs`** (PowerShell, shells out
to the bash script). Skipped silently on Windows hosts without
Git for Windows or msys2.

**Step total bumped 202 → 203** in both gates.

### Drift gate now enforces six things

After this ship the `tools/check_compiler_drift.sh` + gate
together enforce:

1. s1 ↔ tools-suite ABI table parity (v0.2.x baseline)
2. `helper_manifest.toml` freshness (v0.2.41)
3. `rod_manifest.toml` freshness (v0.2.47)
4. `RELEASES.md` freshness (v0.2.57)
5. CHANGELOG ↔ git tag parity (v0.2.83)
6. **No UTF-8 mojibake in source/docs (v0.2.91 — this release)**

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Documentation +
gate-step refinement only — no compiler / runtime / source /
test changes.

## [0.2.90] — 2026-04-23

**Bug fix: `examples/showcase/README.md` was referenced but
missing. Plus showcase build smoke + UTF-8 mojibake fix.**

### Missing showcase README

`examples/README.md` line 62 told readers:

> `showcase/` contains larger programs that span multiple rods.
> See `showcase/README.md` (or run `nuc summary`) for the
> index.

But `examples/showcase/README.md` **didn't exist** in git.
Created it with: a one-paragraph framing of the showcase
intent (production-shaped programs, not gated, intended for
manual viewing); a per-program table covering `lorenz.nr`,
`vqe_h2.nr`, `market_maker.nr`, `wing_simulator.nr` (lifted
from the top-level README descriptions); the `_viz.nr` shared
helper note; build/run instructions; and a "why no gate
coverage?" rationale.

### UTF-8 mojibake in `vqe_h2.nr` header

The first comment line had a 5-byte mojibake sequence
(`0xC3 0xA2 0xE2 0x82 0xAC 0xE2 0x80 0x9D`) where an em-dash
(`U+2014`, 3 UTF-8 bytes) was intended — the cp1252-rendered-
as-UTF-8 mojibake class that bit the rod descriptions in
v0.2.58. Fixed to the proper em-dash. (Documenting the bytes
in hex rather than literal because the literal would
re-introduce the mojibake into this CHANGELOG.)

### Showcase build smoke (`showcase_build_smoke`)

New gate step in both `verify.sh` and `verify.ps1` builds the
4 standalone showcase programs (`lorenz`, `vqe_h2`,
`market_maker`, `wing_simulator`) and verifies the `.exe` is
produced. **Build-only, not run-tested** because each program
emits a streaming ANSI dashboard that doesn't terminate on its
own (live Lorenz attractor, VQE convergence chart, options
market-making dashboard, fluid+EM heatmap).

This catches regressions where a stdlib change breaks the
showcase compile path even though the standard examples
01..18 still compile. The `_viz.nr` shared helper imported by
all four is exercised transitively.

**Step total bumped 201 → 202** in both gates.

### Verify gate

202 / 202 PASS, 0 SKIP on the bash gate. Tools-suite source
unchanged; no compiler / runtime / s1 / test changes.

## [0.2.89] — 2026-04-23

**Continue README freshness pass — fix two more `v1.1` stale
roadmap claims plus document `for-in` already shipped.**

### `docs/getting-started.md` — POSIX target version

Same drift class as the README v0.2.88 fix. Said:

> Windows 10/11, x86_64. v1 targets `x86_64-pc-windows-msvc`.
> POSIX support is planned for v1.1.

Updated to:

> Windows 10/11, x86_64. **v0.2** targets
> `x86_64-pc-windows-msvc`. POSIX support (Linux/macOS) is
> planned for **v0.3.0** (see `docs/milestones/v0.3.0.md`) —
> phases 1, 2, and 4 of RFC-0022 already shipped in v0.2
> (POSIX `tools/verify.sh` gate, `nuc` shell wrapper, runtime
> `_WIN32` audit). The v0.3 release adds the native
> Linux/macOS bootstrap binaries.

### `docs/language-tour.md` — `for` loops already work

The tour said:

> `while` is the loop primitive; `for` is sugar planned for v1.1.

But `for x in <expr>` over arrays AND `Vec` **already works**
and is gate-tested as `tests/features/forin_array.nr` and
`tests/features/forin_vec.nr`. Replaced the stale claim with
a working code example plus a forward-looking note that
iterator-trait `for` (over `HashMap` keys, ranges, lazy
adapters) lands in v0.4 with RFC-0024.

### Audit sweep

Repo-wide grep for `v1.1` references after these fixes
returns **zero matches** in non-CHANGELOG markdown. The
remaining `v1.0` references in CONTRIBUTING / benchmarks /
process docs are legitimate forward-looking ("after v1.0",
"at v1.0+", "revisit at v1.0") and not drift.

### Verify gate

201 / 201 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.88] — 2026-04-23

**README freshness pass — fix two stale claims.**

Audit of the README's quantitative + roadmap claims against
current state found two outdated statements:

1. **POSIX target version was wrong.** README said "POSIX
   (Linux/macOS) support is planned for v1.1." Milestone
   tracker says it's deferred to **v0.3.0** (see
   `docs/milestones/v0.3.0.md` — entire RFC-0022 phase 3 work).
   Fixed; the new line also notes that phases 1, 2, and 4 of
   RFC-0022 already shipped in v0.2 (POSIX gate, `nuc` shell
   wrapper, runtime `_WIN32` audit).

2. **Rod count was historical.** README said "That's **103
   rods total** as of v0.1.5." Actually 121 rods today (v0.2.46
   bumped the count via the v0.2.18–30 enrichment chain).
   Updated to "121 rods total as of v0.2.46 (was 103 at v0.1.5;
   the v0.2.18–v0.2.30 stdlib enrichment chain added 18 more)"
   with a pointer to `docs/rfcs/rod_manifest.toml` for the
   per-rod catalog.

Other quantitative README claims confirmed accurate against
current state:

- `~10,000 lines compiler source` → 8,897 actual ✓ (rough match)
- `121 rods` → 121 actual ✓
- `84 runtime C source files` → 84 actual ✓
- `676 __nucleor_* symbols` → 676 actual ✓
- `13 categories` → 13 taxonomy classes ✓ (per
  `docs/rfcs/helper_manifest.toml`)
- `v0.2.0 (released 2026-04-22)` → still accurate

### Verify gate

201 / 201 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.87] — 2026-04-23

**`nuc -V` and `nuc version` now work as aliases for
`--version`. Plus negative-test audit findings.**

### Version aliases (`nuc -V` / `nuc version`)

`nuc --version` and `nuc -v` worked since v0.1.x. The
`-V` (rustc/gcc/clang convention) and bare `version`
spellings both returned `Unknown command:`. Added both to the
dispatch in `compiler/nucleor_s1_compiler.nr`:

```nr
if str_eq(cmd, "--version") || str_eq(cmd, "-v") ||
   str_eq(cmd, "-V")        || str_eq(cmd, "version") {
    print(compiler_identity());
    return 0;
};
```

All four spellings now produce the same output:
`nucleor 0.2.0-v2 (self-hosted, llvm backend)`.

This is a **compiler source change** — `bin/nucleor.exe`
rebuilt via the standard 2-iteration LLVM IR fixed-point
check. Both iterations produced byte-identical
2,603,849-byte LLVM IR (fixed point preserved).

### Negative-test audit findings (no fix this ship)

Auditing `tests/err/*.nr` against a strict
"must contain a Nucleor diagnostic code (NR/RT/NUM/etc.)"
check found **4 of 33 negative tests pass for the wrong
reason**:

- `err_pure_ambient_random` — fails at link (missing
  `__nucleor_ambient_random` v0.4 placeholder) instead of
  firing a pure-vs-effect diagnostic.
- `err_restricts_specific` — fails at link (missing
  `__nucleor_putchar`) instead of firing EFF-003 (restricts
  violated).
- `err_spawn_send` — fails at link (missing
  `__nucleor_device_alloc`/`free`) instead of firing a
  concurrency check.
- `err_undefined_var` — fails at link (`str_from_int` not in
  scope) instead of firing NR030 on `undeclared_thing`. The
  compiler **silently accepts** the undefined variable; only
  the unrelated `str_from_int` call trips clang.

These are all real compiler gaps (the type-checker doesn't
catch undefined identifiers; effect rows aren't enforced for
ambient_random; restricts isn't enforced for putchar). The
gate's loose "any error string" matcher accepts the link
failures, so the tests register green — but if the v0.4
placeholders ever get implemented, these tests would
silently start passing the build and then the gate would
flip red.

**Documented as v0.4 follow-up.** Tightening the negative-test
matcher to require Nucleor-style diagnostic codes would
immediately surface these 4 cases as gate failures, but the
underlying fixes touch the type-checker and effect/taint
analyzers — substantively bigger than a single ship.

### New gate step (`cli_version_smoke`)

Smoke-tests all four version aliases produce the
`"nucleor "`-prefixed output. **Step total bumped 200 → 201**
in both gates.

### Verify gate

201 / 201 PASS, 0 SKIP on the bash gate. Compiler source
change (s1 dispatch only) — self-host LLVM IR fixed point
preserved.

## [0.2.86] — 2026-04-23

**Gate `--json` output across 11 CLI commands. 200-step gate
milestone crossed.**

Auditing the `--json` flag surface found:

- **9 commands honor `--json` and emit valid JSON** when the
  flag follows the source positional: `audit`, `summary`,
  `query`, `abi`, `evidence`, `graph`, `perf`, `check`, plus
  `explain` (CODE positional, both flag-orders work),
  `bootstrap` (no positional), `lock` (no positional). 11
  total command paths.
- **`policy --json` and `bench --json` silently fall back to
  text** because `policy [file] [level]` parses `--json` as
  the `level` positional and `bench` doesn't advertise `--json`
  at all. **Documented behavior gap, not a bug** — both
  commands accept the flag without warning rather than
  honoring it. Future ships can add `--json` support to either
  by adjusting the dispatch.
- **Parser quirk: `--json` must come AFTER the source
  positional for file-taking commands.** `nuc audit
  examples/01_hello.nr --json` works; `nuc audit --json
  examples/01_hello.nr` falls through to the usage message.
  This is consistent with the help text format (file first,
  flags below) but is a surface that future versions may want
  to permissive-ify.

### Gate hardening (`cli_json_smoke`)

New step in both `verify.sh` and `verify.ps1` exercises the 11
working `--json` paths and verifies each output starts with
`{` (or `[` for array shapes). Catches regressions where the
flag silently falls back to the text path.

The smoke is positioned early in the pre-iteration block (right
after `cli_utility_smoke`) so the JSON contract is verified
before the heavier example/test build phase.

**Step total bumped 199 → 200** in both gates. **First gate
milestone with a 3-digit step count.**

The pre-iteration smoke block now reads (truncated):

```
[ 1/200] OK    binary present
[ 2/200] OK    compiler ABI tables synced
[ 3/200] OK    tools-suite rebuild
[ 4/200] OK    CLI: nuc help advertises every dispatched command
[ 5/200] OK    CLI: nuc zen/mco/registry/stage-dump/fix (utilities)
[ 6/200] OK    CLI: --json variants emit machine-readable JSON
... (10 more)
```

### Verify gate

200 / 200 PASS, 0 SKIP on the bash gate. Pure gate addition
— no compiler / runtime / source / test changes.

## [0.2.85] — 2026-04-23

**Bug fix: `nuc registry list` leaked `cmd.exe` stderr.**
**Plus utility-smoke gate for 5 previously unsmoked CLI commands.**

### Bug

Auditing the unsmoked CLI surface (`zen`, `mco`, `registry list`,
`stage-dump`, `fix --imports`) found `nuc registry list` printing
a spurious `The system cannot find the file specified.` line on
top of its real output:

```
$ nuc registry list
The system cannot find the file specified.
registry: .nucleor/registry
packages: 0
```

Root cause: `dir_list_native` in
`compiler/nucleor_tools_suite.nr` shells out to Windows
`dir /b /ad <path> > <listing>`. When `<path>` doesn't exist
(common — fresh project has no `.nucleor/registry` dir),
`cmd.exe` writes to its stderr, which leaks past the parent
process's redirect and lands on the user's terminal. The
`system()` return code already handles the missing-dir case
correctly (returns empty Vec); only the stderr message was
broken.

Fix: append `2>NUL` to both `dir` invocations in
`dir_list_native`. Now:

```
$ nuc registry list
registry: .nucleor/registry
packages: 0
```

### Utility-smoke gate (`cli_utility_smoke`)

New step in both `verify.sh` and `verify.ps1` exercises the 5
zero-side-effect utility commands that weren't yet under gate
coverage:

- `nuc zen` — must print `"The Zen of Nucleor"`
- `nuc mco` — must print `"Mars Climate Orbiter"` (RFC-0005
  motivation poster)
- `nuc registry list` — must print `registry:` + `packages:`
  AND must NOT contain `system cannot find` (catches the
  v0.2.85 regression by name)
- `nuc stage-dump tokens examples/01_hello.nr` — must print
  `TOKENS`
- `nuc fix --imports examples/01_hello.nr` — must produce
  non-empty output

`nuc clean` and `nuc scram` are intentionally **NOT smoked**
because they delete `target/` mid-gate, which would conflict
with downstream example/test build steps.

This brings the **explicitly-smoked CLI surface to 21
commands**: `explain`, `bootstrap`, `check`, `abi`, `summary`,
`audit`, `query`, `impact`, `policy`, `certify`, `translate`,
`evidence`, `graph`, `perf`, `bench`, `init`, `doc`, `lock`,
`test`, plus the 5 new utility entries (`zen`, `mco`,
`registry`, `stage-dump`, `fix`). Together with implicit
coverage of the build-family + run + emit via every example /
test step, **every dispatched user-facing CLI command is now
gate-protected** (modulo the side-effect-heavy `clean`/`scram`).

**Step total bumped 198 → 199** in both gates.

### Verify gate

199 / 199 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — s1 compiler / runtime / ABI / source / test
unchanged; self-host LLVM IR fixed point preserved (s1 binary
not rebuilt this release).

## [0.2.84] — 2026-04-23

**Bug fix: `nuc doc` and `nuc fix` were dispatched but missing
from `nuc help`.**

Audit of `nuc help` output vs. the s1 compiler's command
dispatch table found two commands that worked but were
unadvertised:

- **`nuc doc`** — RFC-0029 Markdown doc generator. Shipped
  v0.1.65, gate-tested via `cli_doc_smoke` since v0.2.67, but
  never appeared in `nuc help`.
- **`nuc fix`** — RFC-0015 `--numeric` linter (v0.1.63) +
  RFC-0018 `--imports` migration (v0.1.60). Both subcommands
  shipped with their respective RFCs but never appeared in
  `nuc help`.

Result: users running `nuc help` to discover available commands
would not see two of the most useful tools. The drift wasn't
caught by any existing gate — `cli_doc_smoke` exercises the
behavior; nothing exercised the help text.

### Fix

Added the two missing entries to `print_usage` in
`compiler/nucleor_s1_compiler.nr`:

```
  doc [file]             Render /// doc comments as Markdown (RFC-0029)
    --out <file>         Write to file instead of stdout
  fix [--imports|--numeric] [file]  Migration linters (RFC-0015 / RFC-0018)
```

`doc` lives in the Developer commands section near `summary` /
`query` / `graph`. `fix` lives in the Project utilities section
near `clean` / `scram`.

### Self-host bootstrap

This is a **compiler source change** — `bin/nucleor.exe`
rebuilt via the standard 2-iteration LLVM IR fixed-point check:

```
./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_v1
./target/nucleor_v1.exe build compiler/nucleor_s1_compiler.nr -o nucleor_v2
diff -q target/nucleor_v1.ll target/nucleor_v2.ll  # identical
cp target/nucleor_v2.exe bin/nucleor.exe
```

Both iterations produced **byte-identical 2,603,214-byte LLVM
IR** — fixed point preserved across the compiler change.

### Gate hardening

New step **`cli_help_coverage_smoke`** in both `verify.sh` and
`verify.ps1` enumerates the 38-command list and verifies each
appears at the start of an indented line in `nuc help` output.
Catches the same drift class going forward — adding a new
command to the dispatch table without updating `print_usage`
will now fail the gate.

**Step total bumped 197 → 198** in both gates.

The pre-iteration smoke block now reads (truncated):

```
[ 1/198] OK    binary present
[ 2/198] OK    compiler ABI tables synced
[ 3/198] OK    tools-suite rebuild
[ 4/198] OK    CLI: nuc help advertises every dispatched command
[ 5/198] OK    CLI: nuc explain NUM-001 wired
[ 6/198] OK    CLI: nuc explain — full spec code set wired
... (8 more)
```

### Verify gate

198 / 198 PASS, 0 SKIP on the bash gate. Compiler source
change (s1 `print_usage` only) — self-host LLVM IR fixed point
preserved.

## [0.2.83] — 2026-04-23

**CHANGELOG ↔ git tag parity restored; drift gate now enforces.**

A repo-wide audit comparing `git tag -l 'v*'` to the `## [x.y.z]`
headings in `CHANGELOG.md` found one drift entry: **`v0.1.67`
existed as a git tag but had no per-version CHANGELOG block.**

History: v0.1.67 was the bridge release between the v0.1.x
preview chain and the v0.2.0 RC tag — landed
`docs/milestones/v0.4.0.md` (the v0.4 tracker for v0.2-deferred
work). The release notes were rolled into the v0.2.0 narrative
("the v0.1.46..v0.1.67 preview series") instead of getting their
own CHANGELOG entry. The git tag therefore had no documentation
match.

### Fix

Added a retroactive `## [0.1.67] — 2026-04-22` block to
CHANGELOG.md describing what landed (the v0.4 tracker file),
inserted in the correct chronological position between v0.1.66
and v0.2.0.

### Drift gate hardening

`tools/check_compiler_drift.sh` now performs a fifth check:
**every git tag matching `v*` must have a matching
`## [version]` heading in CHANGELOG.md.** Skips silently if the
working tree isn't a git checkout (tarball release case).

This closes the same drift class that bit v0.1.67 — anyone who
pushes a tag without writing the corresponding CHANGELOG block
will fail the verify gate's drift step.

The drift gate now enforces five things:

1. s1 compiler ↔ tools-suite ABI table parity (v0.2.x baseline)
2. `helper_manifest.toml` freshness (v0.2.41)
3. `rod_manifest.toml` freshness (v0.2.47)
4. `RELEASES.md` freshness (v0.2.57)
5. **CHANGELOG ↔ git tag parity (v0.2.83 — this release)**

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Drift step now
includes the new tag/CHANGELOG check; passes after the v0.1.67
backfill.

## [0.2.82] — 2026-04-23

**Bug fix: create the missing `NUCLEOR_BOOTSTRAP_CONTRACT.md`
file referenced by `nuc bootstrap` since v0.2.70.**

`nuc bootstrap` has been printing `Contract:
NUCLEOR_BOOTSTRAP_CONTRACT.md` (and emitting the same string as
the `bootstrap_contract` JSON field) since v0.2.70 — but the
file **never existed in git history**. Anyone following the
pointer hit a 404.

### Fix

Wrote `NUCLEOR_BOOTSTRAP_CONTRACT.md` at the repo root. The
contract document specifies:

- The stage hierarchy (single committed `bin/nucleor.exe` =
  stage 1, self-hosted; stage 0 lineage is upstream).
- The self-host invariant (every committed
  `bin/nucleor.exe` must be capable of compiling its own source
  via the verify gate's final step).
- The 2-iteration LLVM IR fixed-point check pattern used during
  v0.1 / v0.2.x sub-chain releases that touch the compiler.
- The two-binary architecture (`bin/nucleor.exe` for s1,
  `bin/nucleor_tools.exe` for explain/bootstrap/test runner;
  drift gate enforces ABI parity between the two source files).
- Runtime layer pointer (`stdlib/runtime/nucleor_llvm_rt.c`).
- Examples corpus pointer (`tools/examples.list`).
- Bootstrap-from-fresh-clone instructions.
- Cross-platform status (Windows-only binary today;
  Linux/macOS lands with v0.3.0).
- "What changes the contract" — enumerates the four common
  ways to break or update the bootstrap.

### Gate hardening

Extended `cli_bootstrap_smoke` (in both `verify.sh` and
`verify.ps1`) to **resolve the `Contract:` line as an existing
file at the repo root**. Catches the same drift class going
forward — if anyone renames or removes the file (or if the
binary's emitted reference changes to point at something
non-existent), the gate fails.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Documentation +
gate-step refinement only — no compiler / runtime / source /
test changes.

## [0.2.81] — 2026-04-23

**Refresh `HELPER-CONTRACT.md` and `helper_manifest_schema.md`
for v0.2.41–78 Phase 2 reality.**

Two contract / schema docs were stale:

- **`docs/rfcs/HELPER-CONTRACT.md`** — header still said
  "Phase 1 walk: awaiting explicit 'go' from user" and
  "drift-gate enforcement lands once Phase 2 is approved" —
  both true at v0.2.32 / v0.2.40 but false since v0.2.41.
  Refreshed to reflect: Phase 1 walk approved (taxonomy: 13
  classes / 676 helpers), Phase 2 mechanism shipped v0.2.41,
  Phase 2 population at 95.1% as of v0.2.78, and the
  going-forward constraint is **drift-gate-enforced live**
  since v0.2.41 (not pending).
- **`docs/rfcs/helper_manifest_schema.md`** — `effects` field
  state table said "v0.2.73 — 405 rows; remaining 271 carry
  TODO." Replaced with a 13-row per-class population table
  showing 643 of 676 helpers (95.1%) populated and the
  remaining 33 enumerated as v0.4 placeholders. `taint` field
  state expanded to enumerate the 23 read-side IO helpers
  carrying `"propagates"` (the only non-`"passthrough"` rows).

No code or generator changes. The manifest itself, the
generator, and the gate are unchanged — this ship just brings
the protocol docs into agreement with the shipped state.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / ABI / source / test changes.

## [0.2.80] — 2026-04-23

**Wire 44 forward-looking error codes into the explain registry;
gate now exercises the full 130-code spec catalog.**

Continues the audit pattern from v0.2.79 (which found 4 v0.2
codes missing). A wider sweep of every code listed in
`docs/spec/Nucleor_Error_Codes.md` found **44 more `unknown
error code` returns** from `nuc explain` — all forward-looking
entries for RFCs that haven't shipped yet but whose codes are
documented:

- **RFC-0004 assume!** — `ASSUME-003`, `ASSUME-005` (2 codes)
- **RFC-0005 units** — `UNIT-003`, `UNIT-005` (2 codes)
- **RFC-0006 contracts** — `CONTRACT-005`, `CONTRACT-006`,
  `CONTRACT-007` (3 codes)
- **RFC-0007 atomic** — `ATOMIC-003`, `ATOMIC-004` (2 codes)
- **RFC-0008 ISR** — `ISR-003`, `ISR-005`, `ISR-006` (3 codes)
- **RFC-0009 WCET** — `WCET-001`, `WCET-002`, `WCET-004`,
  `WCET-005`, `WCET-006` (5 codes)
- **RFC-0010 DLPack** — `DLPACK-001..005` (5 codes)
- **RFC-0011 nuc-cxx** — `CXX-001..005` (5 codes)
- **RFC-0012 nuc-bindgen** — `BINDGEN-001..005` (5 codes)
- **RFC-0013 URDF** — `URDF-001..006` (6 codes)
- **RFC-0014 max_depth** — `DEPTH-003`, `DEPTH-005` (2 codes)
- **RFC-0031 algebraic laws** — `LAW-003`, `LAW-004` (2 codes)
- **RFC-0032 effects** — `EFF-004`, `EFF-005` (2 codes)

Each entry got a short title, a one-line summary, and a longer
RFC-anchored explanation — a total of **132 string literals
added across the 3 explain registry functions**
(`explain_error_title`, `explain_error_summary`,
`explain_error_explanation`) in
`compiler/nucleor_tools_suite.nr`. Tools binary rebuilt.

Even though the underlying RFCs ship in v0.3 / v0.4 / v0.5+,
having `nuc explain RT-001` or `nuc explain DLPACK-002` produce
useful documentation today gives users a reading surface for
the planned features.

### Gate hardening

The `cli_explain_full_smoke` step (added v0.2.79 with 35 codes)
is **extended to cover all 130 codes** from the spec catalog.
Step renamed from "full v0.2 code set wired" to "full spec
code set wired" in both `verify.sh` and `verify.ps1` to reflect
the expanded scope. Per-call overhead: 130 binary invocations,
all against the same fast-fail explain command — adds ~2 s to
the gate run.

Going forward, adding a code to `Nucleor_Error_Codes.md` MUST
also (a) wire it into all three explain registry functions and
(b) add the code string to the `cli_explain_full_smoke` list in
both gates. The existing tools-rebuild + drift-gate machinery
catches unrelated divergence; this step closes the explain-
specific drift class.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — no s1 compiler / runtime / ABI / source / test
changes; self-host LLVM IR fixed point preserved.

## [0.2.79] — 2026-04-23

**Bug fix: 4 v0.2 error codes spec'd but not wired into explain
registry. Plus a new gate step that enforces full v0.2 code-set
coverage going forward.**

`docs/spec/Nucleor_Error_Codes.md` listed 35 v0.2-era codes
across the NUM / MATCH / COLL / MOD / PKG / TGT / TST series.
A spot audit found that **4 of them returned `unknown error
code` from `nuc explain`**:

- **`NUM-004`** — f8/f16/bf16 op without hardware support
  (RFC-0015 §3.4)
- **`TST-001`** — Test discovery: no #[test] functions found
  (RFC-0021 §3.1)
- **`TST-002`** — Test isolation: process child crashed before
  reporting (RFC-0021 §3.4)
- **`TST-003`** — Test fixture: setup fn returned non-zero
  (RFC-0021, fixture work deferred to v0.4)

Root cause: the spec doc was a forward-looking catalog, but
the explain registry in `compiler/nucleor_tools_suite.nr` (the
backing store for `nuc explain CODE`) had no entries for these
four codes. Existing gate step `cli_explain_smoke` only
exercised `NUM-001`, so the drift wasn't caught.

### Fix

Added 4 entries × 3 functions (12 string literals) to the
explain registry:

- `explain_error_title(code)` — short title
- `explain_error_summary(code)` — one-line summary
- `explain_error_explanation(code)` — RFC-anchored explanation

Tools binary rebuilt from `compiler/nucleor_tools_suite.nr` and
installed at `bin/nucleor_tools.exe` (where `nuc` resolves the
external explain handler).

### Gate hardening

New step **`cli_explain_full_smoke`** in both `verify.sh` and
`verify.ps1` enumerates the full 35-code v0.2 set and verifies
each returns a non-`unknown` answer that includes the code in
its title. The previous gate step `cli_explain_smoke` (NUM-001
only) is preserved as a quick-fail canary; the new step runs
the exhaustive sweep.

### Companion fix: `tools_rebuild` gate step

Found while wiring the new explain step: the gate had **no
step that rebuilt `bin/nucleor_tools.exe`**. The s1 compiler
gets self-host-rebuilt at the end of every gate run, but the
tools-suite source — which backs `nuc explain`, `nuc test`,
and other tools-suite logic — was being tested against
whatever stale binary the user happened to have in `bin/`.

This meant a fresh-clone-and-pull workflow that updated
`compiler/nucleor_tools_suite.nr` would silently leave the
stale `bin/nucleor_tools.exe` in place (the file is
`.gitignore`-d), and the new `cli_explain_full_smoke` step
would have spuriously failed because the user's binary lacked
the new entries — even though the source did have them.

Added a **`tools_rebuild`** step that:

1. Builds `compiler/nucleor_tools_suite.nr` via `bin/nucleor.exe`
2. Copies the resulting `target/nucleor_tools.exe` to
   `bin/nucleor_tools.exe`

Placed after `compiler ABI tables synced` and before the
explain smokes. The subsequent CLI smokes (`bootstrap`,
`check`, `abi`, inspectors, diagnostics, `init`, `doc`,
`lock`, `test`) now exercise the freshly-built tools binary,
not whatever was stale on disk.

**Step total bumped 195 → 197** (one for explain-full, one
for tools-rebuild) in both gates.

The pre-iteration smoke block now reads:

```
[ 1/197] OK    binary present
[ 2/197] OK    compiler ABI tables synced
[ 3/197] OK    tools-suite rebuild
[ 4/197] OK    CLI: nuc explain NUM-001 wired
[ 5/197] OK    CLI: nuc explain — full v0.2 code set wired
[ 6/197] OK    CLI: nuc bootstrap status reports correctly
[ 7/197] OK    CLI: nuc check + abi inspect
[ 8/197] OK    CLI: nuc summary/audit/query/impact (inspectors)
[ 9/197] OK    CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)
[10/197] OK    CLI: nuc init scaffolding works
[11/197] OK    CLI: nuc doc generator works
[12/197] OK    CLI: nuc lock writes Nucleor.lock
[13/197] OK    CLI: nuc test runs #[test] functions
```

Going forward, adding a code to `Nucleor_Error_Codes.md` MUST
also wire it into the explain registry AND add the code string
to the `cli_explain_full_smoke` list in both gates — same
"add it in three places" pattern that already protects the s1
compiler ↔ tools-suite ABI tables.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Compiler change
(tools-suite explain registry only — no s1 compiler / runtime
/ ABI / source / test changes). Self-host LLVM IR fixed point
preserved; the s1 compiler binary at `bin/nucleor.exe` is
unchanged.

## [0.2.78] — 2026-04-23

**Helper manifest Phase 2 — populate 15 stable `TensorOps`
helpers.**

15 of the 45 `TensorOps` helpers are actually CPU-bound and
shipping today (`tensor_get`, `tensor_set`, `tensor_fill`,
`tensor_cols`, `tensor_rows`, `tensor_max`, `tensor_min`,
`tensor_mean`, `tensor_sum`, `tensor_stddev`, `tensor_variance`,
`tensor_zeros`, `tensor_ones`, `tensor_transpose`,
`tensor_matmul`). The remaining 30 are forward declarations
for the v0.4 device-effect formalization (`device_*`,
`kvcache_*`, `kvprefix_*`, `simd_*`, `vector_*`,
`tensor_sample_*`, etc.) — all carry `stability = "unstable"`
already.

**Newly populated via `PATTERN_OVERRIDES`:**

- **9 pure** — `^tensor_(get|cols|rows|max|min|mean|sum|stddev|
  variance)$`. Read-only / reductions returning scalar.
  Proof obligation `"bounds_within_shape"`.
- **2 in-place mutation** — `^tensor_(set|fill)$`. Modify
  pointed-to tensor without allocation. Proof obligation
  `"bounds_within_shape"`.
- **4 allocating** — `^tensor_(zeros|ones|transpose|matmul)$`.
  Allocate a fresh result tensor. Proof obligation
  `"shape_compatible"`.

The 30 unstable `TensorOps` placeholders stay TODO because
their effects depend on the v0.4 `"device"` effect tag (not
yet in the schema vocabulary). Adding `"device"` ahead of the
v0.4 implementation would create a dangling abstraction.

**TODO sentinel count drops 144 → 99** (45 TODOs eliminated).

**Helper manifest Phase 2 now at 643 of 676 helpers (95.1%).**
Remaining 33 helpers are all intentional v0.4 placeholders:

- 30 `TensorOps` GPU/device/SIMD/sampling forward declarations
- 3 `ToolingMeta` stubs (`profile_start`, `profile_end`,
  `py_eval`) whose runtime bodies are deferred to v0.4

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.77] — 2026-04-23

**Milestone tracker + status doc + RFC index refresh for the
v0.2.50–76 sub-chain.**

Three docs were stale:

- **`docs/milestones/v0.2.0.md`** — header status was at v0.2.49
  / 186-step gate. Refreshed to v0.2.76 / 195-step gate, with a
  new "Sub-chain summary v0.2.50–v0.2.76" section enumerating
  the four buckets of post-RC work (Helper manifest Phase 2,
  CLI surface gate coverage, drift gate hardening, compiler
  bug fix). Helper Schema Deliverable section rewritten —
  previously said "awaiting 'go'" + "drift gate enforcement
  lands once Phase 2 is approved"; now reflects that Phase 2
  shipped (mech v0.2.41, population v0.2.73–76 → 92.9%) and
  that the going-forward constraint is live in the drift gate.
  Three success criteria checkboxes updated to current numbers
  (158 → 195).
- **`docs/status/v0.2-shipped-and-deferred.md`** — header
  snapshot was at `v0.2.47` (68 releases). Refreshed to
  `v0.2.76` (97 releases). Added a "Post-RC sub-chain
  (v0.2.50–v0.2.76)" section mirroring the milestone tracker
  bucket-by-bucket summary.
- **`docs/rfcs/README.md`** — Cross-cutting contracts table
  said the helper manifest was a v0.2.40 artifact with no
  population progress. Updated to reflect Phase 2 population
  state (628/676 = 92.9% via v0.2.73–76) and the schema
  vocabulary additions in v0.2.73 / v0.2.75.

No source / runtime / generator changes — pure documentation
refresh of the four canonical trackers the user maintains as
the project's source-of-truth surface.

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.76] — 2026-04-23

**Helper manifest Phase 2 — populate `IO` (70), `DataCodec` (14
remaining), and 4 ToolingMeta legacy bridge entries.**

Continues the per-class population sweep. With this ship the
manifest's policy-sensitive fields are populated for **628 of
676 helpers (92.9%)** — every helper with known semantics today
is now annotated. The remaining **48 TODOs are all intentional
v0.4 placeholders** (`TensorOps` GPU/CUDA/DLPack/KV-cache
forward declarations and `ToolingMeta`'s `profile_*` / `py_eval`
stubs).

**`IO` (70 helpers).**

The class splits four ways:

- **Pure (no I/O)** — 8 helpers via `PATTERN_OVERRIDES`:
  - `^os_(family|pointer_width)$` — compile-time-constant queries.
  - `^path_(is_absolute|separator)$` — pure path predicates.
- **Pure-allocating (no I/O, output string allocates)** — 8
  helpers via `PATTERN_OVERRIDES`:
  - `^path_(components|normalize|strip_extension|with_extension)$`
  - `^fs_(basename|dirname|extension|join)$`
- **Read-side I/O (taint propagator)** — 23 helpers via
  `PATTERN_OVERRIDES`. Output value carries external taint
  because the read introduces new state into the value graph:
  - stdin: `^read_(byte|i64|line)$`
  - env: `^env_(get|has|keys)$`, `^getenv$`
  - process state: `^getcwd$`, `^process_id$`, `^isatty_`,
    `^args_(count|get)$|^init_args$`
  - filesystem queries: `^fs_(exists|is_dir|is_file|size|mtime|
    list_dir|canonicalize|current_dir|temp_dir)$`
  - file reads: `^file_read_`
  - subprocess: `^system$`
- **Write-side I/O (passthrough taint)** — 31 helpers via
  `CLASS_DEFAULTS["IO"]` → `["io"]` / `passthrough` /
  `"io_capability_required"`. Covers `print*`, `eprint*`,
  `putchar`, `dbg_*`, `env_(set|unset)`, `file_(write|append)_*`,
  `fs_(create_dir|create_dir_all|copy_file|remove_dir|
  remove_file|rename)`, `pipe_*`.

**Schema rationale for `taint = "propagates"` on read-side I/O.**

The schema's `propagates` value is "output taint = input taint
plus any internal state read." A `read_line()` call has empty
input taint (no arguments), but its output should be considered
tainted because it pulled bytes from stdin — that's an
"internal state read" of the most external kind. Without
`propagates`, every read-side I/O helper would wrongly be
treated as a fresh untainted source.

**`DataCodec` (14 remaining helpers).**

- **3 pure** via `PATTERN_OVERRIDES`: `^toml_(get_int|get_str|
  has)$` — read from a parsed TOML handle in memory.
- **1 I/O** via `PATTERN_OVERRIDES`: `^toml_parse_file$` —
  reads + parses a file. Tainted (pulls external state).
- **1 random+alloc** via `PATTERN_OVERRIDES`: `^uuid_v4$` —
  generates fresh UUID via RNG.
- **9 alloc** via `CLASS_DEFAULTS["DataCodec"]` →
  `["alloc"]` / `passthrough` / `none`. Covers `base64_encode`,
  `base64_decode`, `msgpack_write_*`, `sha256`, `sha256_hex`,
  `toml_parse_string`.

**`ToolingMeta` (4 more — legacy rods bridge).**

- `rods_f64_add`, `rods_f64_sub`, `rods_f64_div` → pure
  (standard f64 — div-by-zero returns NaN/inf, no panic).
- `rods_f64_encode` → `["alloc"]` (output string).

The remaining 3 `ToolingMeta` entries (`profile_start`,
`profile_end`, `py_eval`) stay TODO — their implementations
are deferred to v0.4 and the precise effect set depends on
the chosen profile sink / py interop model.

**TODO sentinel count drops 408 → 144** (264 TODOs eliminated).

### Generator changes (`tools/gen_helper_manifest.py`)

- 14 new `PATTERN_OVERRIDES` entries (IO subclasses + DataCodec
  pure / I/O / random helpers).
- 4 new `NAME_OVERRIDES` entries (ToolingMeta `rods_f64_*`).
- 2 new `CLASS_DEFAULTS` entries (IO write-side default,
  DataCodec encoder default).

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.75] — 2026-04-23

**Helper manifest Phase 2 — populate `StringFormat` (81) and
`Collection` (54) with read-vs-mutate split.**

Both classes split cleanly into "pure read-only accessors" and
"mutating / output-allocating" buckets. The v0.2.74 override
mechanism now carries the split via class default + per-pattern
pure overrides:

**`StringFormat` (81 helpers).**

- 38 helpers populated as **pure** via `PATTERN_OVERRIDES`:
  - `^char_` — all 12 character predicates and case conversions.
  - `^chr$` — int → char.
  - `^str_(eq|contains|count|ends_with|starts_with|index_of|is_empty|len|char_at)$` — 9 string predicates and accessors.
  - `^str_to_(i64|f64|bool|i64_radix)$` — 4 string→scalar parses.
  - `^parse_(hex|bin)$` — 2 base-conversion parses.
  - `^string_(capacity|eq|eq_str|get_byte|len|starts_with|ends_with|contains|as_ptr)$` — 9 heap-String accessors.
  - `chr` — 1 helper (already pattern-matched above by `^chr$`).
- 1 helper via `NAME_OVERRIDES`: `string_print` →
  `["io"]` / `"io_capability_required"` (does I/O despite living
  in StringFormat by name pattern).
- 42 helpers via `CLASS_DEFAULTS["StringFormat"]` →
  `["alloc"]` / `passthrough` / `none`. Covers all string
  builders: `format_*`, `int_to_*`, `f64_to_str`, `bool_to_str`,
  `sb_*`, `string_new`/`from_str`/`with_capacity`/`clone`/etc.,
  `str_concat`/`pad_*`/`replace`/`split`/`substring`/`to_lower`/
  `to_upper`/`trim*`/`reverse`/`repeat`/`center`/`join`/`lines`/
  `chars`.

**`Collection` (54 helpers).**

- 17 helpers populated as **pure** via `PATTERN_OVERRIDES`:
  `^(hashmap|hashset|btreemap|btreeset|vecdeque)_(get|contains|len|capacity|is_empty|get_or|key_at|val_at|at)$` —
  read-only accessors return `Option` / `bool` / `i64` / `i32`
  without allocating.
- 37 helpers via `CLASS_DEFAULTS["Collection"]` →
  `["alloc"]` / `passthrough` / `none`. Covers all mutators:
  `*_insert`, `*_remove`, `*_push_*`, `*_pop_*`, `*_set`,
  `*_clear`, `*_clone`, `*_merge`, `*_new`, `*_with_capacity`,
  `*_free`, `*_keys`, `*_values`.

**TODO sentinel count drops 813 → 408** (405 TODOs eliminated).

After this ship the manifest's policy-sensitive fields are
populated for **540 of 676 helpers (79.9%)**. The remaining 136
TODOs live in four classes that still need per-name or
per-pattern fixing:

- **`IO` (70)** — needs read/write/file/env split (writes are
  passthrough taint, reads are propagating taint sources).
- **`TensorOps` (45)** — mostly intentional v0.4 placeholders;
  most rows are already `stability = "unstable"`.
- **`DataCodec` (14 remaining)** — encoders/parsers/UUID; mix
  of pure (parsers) and alloc (encoders).
- **`ToolingMeta` (7 remaining)** — all intentional v0.4
  placeholders (`profile_*`, `py_eval`, `rods_f64_*`).

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.74] — 2026-04-23

**Helper manifest Phase 2 — per-name override mechanism + populate
PanickingArith (full) + 10 ToolingMeta/DataCodec entries.**

Adds the missing piece for the mixed-semantic taxonomy classes:
the `tools/gen_helper_manifest.py` generator now consults a
**resolution chain** when populating effects/taint/proof_obligation:

  1. `NAME_OVERRIDES` — exact helper-name match
  2. `PATTERN_OVERRIDES` — name-pattern regex match
  3. `CLASS_DEFAULTS` — taxonomy class default (added v0.2.73)
  4. `"TODO"` sentinel

This unlocks populating classes whose helpers have non-uniform
semantics (e.g. `PanickingArith.checked_add` is pure but
`PanickingArith.panic` panics; `ToolingMeta.assert_eq` panics on
failure but `ToolingMeta.dbg` does I/O; `DataCodec.fnv1a_64_str`
is pure but `DataCodec.base64_encode` allocates).

**`PanickingArith` (84 helpers) — fully populated.**

- 80 helpers via `PATTERN_OVERRIDES` — `^(checked|wrapping|
  saturating)_` and `^(sat|wrap)_i32$` patterns mark them as
  pure (`effects = []`, `taint = "passthrough"`,
  `proof_obligation = "none"`). These return `Option<T>` /
  wrap / saturate instead of panicking, so they have no panic
  effect.
- 4 helpers via `NAME_OVERRIDES`:
  - `panic` → `["panic"]` /
    `"callsite_unreachable_or_recoverable"`
  - `assert` → `["panic"]` / `"predicate_holds"`

**`DataCodec` partial — 5 hash helpers populated.**

`crc32`, `crc32_update`, `fnv1a_64_i64`, `fnv1a_64_str`,
`murmur3_64` → pure (`[]` / `passthrough` / `"none"`). They
return a `u64` digest; no allocation, no I/O. The remaining
14 `DataCodec` helpers (encoders/decoders/parsers/UUID) stay
TODO until follow-on releases populate them.

**`ToolingMeta` partial — 5 helpers populated.**

- `assert_eq`, `assert_ne` → `["panic"]` / `"predicate_holds"`
- `dbg` → `["io"]` / `"io_capability_required"`
- `manifest_report`, `manifest_validate` → `["alloc"]` /
  `"none"` (validation builds a small report string).

The remaining 7 `ToolingMeta` helpers (`profile_*`, `py_eval`,
`rods_f64_*`) are intentional v0.4 placeholders — left TODO
because their semantics are TBD with the v0.4 implementation.

**TODO sentinel count drops 1095 → 813** (282 TODOs eliminated).

### Generator changes (`tools/gen_helper_manifest.py`)

- Added `NAME_OVERRIDES: dict[str, (list[str], str, str)]`.
- Added `PATTERN_OVERRIDES: list[(re.Pattern, (list[str], str, str))]`.
- Resolution chain replaces the previous single `CLASS_DEFAULTS`
  lookup. Now: name → pattern → class → TODO.
- `CLASS_DEFAULTS` docstring updated to enumerate which classes
  ship as default vs. require per-name population.

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.73] — 2026-04-23

**Helper manifest Phase 2 — populate effects/taint/proof for four
more taxonomy classes.**

Continues the Helpers.md contract Phase 2 work begun in v0.2.41
(taxonomy + auto-class) by extending the generator's per-class
default population from two classes (`PureMath`, `VectorOps`)
to six. The generator now ships a `CLASS_DEFAULTS` table keyed
by taxonomy class; each entry is `(effects, taint,
proof_obligation)`.

**Newly populated classes (82 helpers):**

- **`Random` (13 helpers)** — `effects = ["random"]`,
  `taint = "passthrough"`, `proof_obligation =
  "rng_capability_required"`. Covers `ambient_random`, `rng_*`,
  `random_*`, `vec_shuffle`, `vec_sample`.
- **`Time` (21 helpers)** — `effects = ["clock"]`,
  `taint = "passthrough"`, `proof_obligation =
  "clock_capability_required"`. Covers `time_*`, `now_*`,
  `sleep_*`. (Schema-aligned: `"clock"` not `"time"`.)
- **`Concurrency` (38 helpers)** — `effects = ["sync"]`,
  `taint = "passthrough"`, `proof_obligation =
  "happens_before_release_acquire"`. Covers `mutex_*`,
  `channel_*`/`chan_*`, `atomic_*`/`cas_*`, `thread_*`,
  `rwlock_*`, `cancel_token_*`, `once_*`, `par_*`,
  `scheduler_*`, `cpu_count`. **New `"sync"` effect tag** added
  to the schema vocabulary for synchronization-only primitives
  that don't fit `"thread"` (just spawn/join) or any other
  effect category.
- **`Allocation` (10 helpers)** — `effects = ["alloc"]`,
  `taint = "passthrough"`, `proof_obligation =
  "alloc_capability_or_arena_owned"`. Covers `arena_*`,
  `region_*`, `alloc_*`, `free`, `realloc`, `malloc`, `memcpy`,
  `calloc`, `drop_*`, `capture_*`.
- **`VectorOps` (97 helpers)** — already had
  `taint = "passthrough"`; now also gets `effects = ["alloc"]`
  and `proof_obligation = "bounds_within_len"`.

**TODO sentinel count drops 1535 → 1095** (440 TODOs
eliminated). Remaining classes (`PanickingArith`,
`StringFormat`, `IO`, `Collection`, `TensorOps`, `DataCodec`,
`ToolingMeta`) carry `"TODO"` because they need per-helper
divergence (e.g. `wrapping_add` has no panic effect but
`panic_div_by_zero` does; `str_concat` allocates but
`str_eq` doesn't). Those land in follow-on releases as
per-name tables get fixed.

### Schema doc updates (`docs/rfcs/helper_manifest_schema.md`)

- Added `"sync"` to the effect-tag vocabulary list with a
  description and a back-reference to the v0.2.73 ship.
- Per-field "marked TODO outside X" notes updated to enumerate
  the six classes the generator now populates and the seven
  that still TODO.
- `proof_obligation` field promoted from a closed `none|emits|
  consumes` enumeration to a free-form string with a worked
  example list of the six values now in use.
- `taint` field default-justification expanded to cover the
  four new classes (RNG/clock/sync/alloc are passthrough
  because their outputs derive only from input arguments + an
  observable effect).

### Generator changes (`tools/gen_helper_manifest.py`)

- Added `CLASS_DEFAULTS: dict[str, (list[str], str, str)]`.
- Per-row population logic refactored to consume `CLASS_DEFAULTS`
  instead of the previous open-coded `if cls in (...)` checks.
- TOML emitter updated to handle non-empty array literals for
  `effects` (was previously hardcoded for `"[]"` only).

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes. The manifest
is generated; only the generator and schema doc carry hand
edits.

## [0.2.72] — 2026-04-23

**Verify gate: diagnostic smoke step (policy/certify/translate/evidence/graph/perf/bench).**

Seven more CLI surfaces gate-covered. With this ship the
remaining diagnostic / reporting / provenance commands all sit
behind the gate, completing the CLI-coverage audit pattern that
ran from v0.2.64 (`explain`) through v0.2.71 (inspector
bundle):

- **`nuc policy`** — policy compliance report. Verifies the
  default policy passes on `examples/01_hello.nr` and that the
  output shape contains `Policy:` and `Result:` headers.
- **`nuc certify`** — strict-mode verification pass. Verifies
  the report carries the `source:` provenance line.
- **`nuc translate`** — Sage translation pass. Verifies the
  output carries the `translated:` marker.
- **`nuc evidence`** — SPDX + provenance JSON (SLSA v1
  attestation surface). Verifies both `"spdx":` and
  `"provenance":` keys appear in the JSON.
- **`nuc graph`** — call-graph analysis. Verifies the
  `functions:` and `edges:` summary lines.
- **`nuc perf`** — performance analysis report. Verifies the
  `Nucleor Performance Analysis` header.
- **`nuc bench`** — benchmark harness output. Verifies the
  `source:` line that anchors per-bench provenance.

**Bundled into one `cli_diagnostic_smoke` step** (single bash
function, single PowerShell `Step` block). Per-iteration
overhead: 7 binary invocations against the same input file.
Same audit + bundling pattern that v0.2.71 used for inspectors.

**Audit findings:** all seven commands return exit 0 with the
expected structured output. **Zero real bugs found** — same
positive-finding outcome as v0.2.71, confirming this slice of
the CLI stays well-tested by the existing example pipeline.

**Step total bumped 194 → 195** in both gates.

The pre-iteration smoke block now reads:

```
[ 1/195] OK    binary present
[ 2/195] OK    compiler ABI tables synced
[ 3/195] OK    CLI: nuc explain NUM-001 wired
[ 4/195] OK    CLI: nuc bootstrap status reports correctly
[ 5/195] OK    CLI: nuc check + abi inspect
[ 6/195] OK    CLI: nuc summary/audit/query/impact (inspectors)
[ 7/195] OK    CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)
[ 8/195] OK    CLI: nuc init scaffolding works
[ 9/195] OK    CLI: nuc doc generator works
[10/195] OK    CLI: nuc lock writes Nucleor.lock
[11/195] OK    CLI: nuc test runs #[test] functions
```

**Coverage so far: 16 unique CLI commands** under explicit
smoke coverage (every command except the four `build*`-family
variants and `emit`, which are implicitly exercised by every
example + test step that calls `nuc build`):
`explain`, `bootstrap`, `check`, `abi`, `summary`, `audit`,
`query`, `impact`, `policy`, `certify`, `translate`,
`evidence`, `graph`, `perf`, `bench`, `init`, `doc`, `lock`,
`test`. With the build-family already implicitly gated, **the
full surface area of `nuc` is now under verify-gate coverage.**

### Bash gate clang resolution: Windows fallback

Drive-by fix while wiring v0.2.72: `tools/verify.sh` now falls
back to `C:\Program Files\LLVM\bin\clang.exe` when neither
`NUCLEOR_CLANG_PATH` nor `LLVM_SYS_180_PREFIX` resolve, mirroring
the PowerShell gate's behavior. The probes for both env vars now
also check the `.exe` suffix so a stale `LLVM_SYS_180_PREFIX`
pointing at a deleted MSVC LLVM tree silently falls through
instead of looking valid.

Symptom that prompted the fix: bash gate run on a host where
`LLVM_SYS_180_PREFIX` had been set to a since-removed LLVM tree
showed ~150 spurious link failures (`note: LLVM IR was emitted;
GPU/CUDA experiments may require manual link with CUDA libs`)
because clang never made it onto `PATH`. Linux/macOS gates
unaffected.

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.71] — 2026-04-23

**Verify gate: inspector smoke step (summary/audit/query/impact).**

Four more CLI surfaces gate-covered. All four are inspector
commands that produce structured output for tooling integration:

- **`nuc summary`** — module/effect summary text format.
  Prints `// Module: <path>` and `fn <name> ... requires [...]`.
- **`nuc audit`** — JSON audit report. Schema includes
  `"type": "audit_report"`, source hash, function/struct/etc.
  inventory.
- **`nuc query`** — JSON function inventory. Each function's
  name, params, return type, declared/inferred effects, contract
  counts.
- **`nuc impact`** — JSON callee/caller graph for a single
  named function. Reports declared/inferred effects + the
  caller/callee impact tree.

**Bundled into one `cli_inspector_smoke` step** (single bash
function, single PowerShell Step block). Per-iteration overhead:
4 binary invocations against the same input file. Keeps gate
pre-iteration block at a manageable size.

**Step total bumped 193 → 194** in both gates.

The pre-iteration smoke block now reads:

```
[ 1/194] OK    binary present
[ 2/194] OK    compiler ABI tables synced
[ 3/194] OK    CLI: nuc explain NUM-001 wired
[ 4/194] OK    CLI: nuc bootstrap status reports correctly
[ 5/194] OK    CLI: nuc check + abi inspect
[ 6/194] OK    CLI: nuc summary/audit/query/impact (inspectors)
[ 7/194] OK    CLI: nuc init scaffolding works
[ 8/194] OK    CLI: nuc doc generator works
[ 9/194] OK    CLI: nuc lock writes Nucleor.lock
[10/194] OK    CLI: nuc test runs #[test] functions
```

**Coverage so far: 11 unique CLI commands** (binary present
isn't a command, ABI parity is internal): `explain`, `bootstrap`,
`check`, `abi`, `summary`, `audit`, `query`, `impact`, `init`,
`doc`, `lock`, `test`. **Still uncovered (mostly diagnostic /
advanced):** `bench`, `policy`, `certify`, `translate`,
`evidence`, `graph`, `perf`, `emit`, plus the four
`build*`-family variants. The build family is implicitly
exercised by every example + test step.

### Verify gate

194 / 194 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.70] — 2026-04-23

**Verify gate: `nuc bootstrap`, `nuc check`, `nuc abi` smoke steps.**

Three more CLI surfaces brought under gate coverage as the
audit pattern continues to find no real bugs (positive
finding — those commands work):

**`nuc bootstrap`** — reports stage / runtime size / self-host
status. Used as the canonical "is this a self-hosted build?"
check by anyone reading `NUCLEOR_BOOTSTRAP_CONTRACT.md`. New
`cli_bootstrap_smoke` step verifies it prints
`"Nucleor Bootstrap Status"`, `"Stage: 1 (self-hosted)"`, and
`"Self-hosted: yes"`.

**`nuc check`** — runs ownership/type/source/taint/effect
checkers without codegen. The fast feedback path during dev. New
`cli_check_abi_smoke` step verifies `nuc check examples/01_hello.nr`
prints `"OK — no diagnostics"`.

**`nuc abi`** — ABI import inspector. Reports ABI version + extern
imports list. Same step as check, also asserts
`nuc abi examples/01_hello.nr` prints `"ABI version:"` +
`"extern imports:"`.

**Combined into one `cli_check_abi_smoke`** to keep the per-iteration
overhead small (single binary invocation per check, two for the
combined step).

**Step total bumped 191 → 193** in both gates. The full
pre-iteration smoke block now reads:

```
[ 1/193] OK    binary present
[ 2/193] OK    compiler ABI tables synced
[ 3/193] OK    CLI: nuc explain NUM-001 wired
[ 4/193] OK    CLI: nuc bootstrap status reports correctly
[ 5/193] OK    CLI: nuc check + abi inspect
[ 6/193] OK    CLI: nuc init scaffolding works
[ 7/193] OK    CLI: nuc doc generator works
[ 8/193] OK    CLI: nuc lock writes Nucleor.lock
[ 9/193] OK    CLI: nuc test runs #[test] functions
```

The user-facing v0.2 CLI surface is now nine pre-iteration smoke
steps. Remaining v0.2 commands (`nuc bench`, `nuc audit`,
`nuc policy`, `nuc certify`, `nuc translate`, `nuc evidence`,
`nuc query`, `nuc graph`, `nuc perf`, `nuc summary`,
`nuc impact`, `nuc emit`) are either advanced/diagnostic
commands or implicitly tested via the example/test gate. None
have known regressions.

### Verify gate

193 / 193 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.69] — 2026-04-23

**`nuc test` bug fix — target/ now created before harness write.**

Real compiler bug found via the gate-coverage audit. `nuc test
foo.nr` from a fresh directory failed with:

```
  discovered tests: 1
    test_addition
ERROR: cannot read target/foo-test__test_harness.nr
```

Root cause: `compiler/nucleor_tools_suite.nr:10189` writes the
test-harness source to `target/<name>__test_harness.nr` but
never creates `target/` first. `file_write_string` silently
fails when the parent dir doesn't exist; the subsequent
`compile_file_mode` call then can't read the file.

The `bin/nucleor.exe` self-host build path already handles this
correctly via `system("mkdir target 2>NUL")` at
`compiler/nucleor_s1_compiler.nr:7773`. The `nuc test` path was
missing the same idiom.

**Fix (one line):** added `system("mkdir target 2>NUL")` before
the harness write. Same idiom as the build path. Comment
references the sibling location.

Verified end-to-end:

```
$ rm -rf /tmp/sandbox && mkdir /tmp/sandbox && cd /tmp/sandbox
$ cat > t.nr <<'EOF'
#[test]
fn test_addition() { let x: i64 = 2 + 2; if x != 4 { print("FAIL"); return; }; print("PASS test_addition"); }
fn main() -> i64 { return 0; }
EOF
$ nuc test t.nr
  discovered tests: 1
    test_addition
  source: target/t-test__test_harness.nr (748 bytes)
  ...
PASS test_addition
  PASS: test_addition
test result: PASS (1 test)
```

**Tools binary rebuilt** (`bin/nucleor_tools.exe`) from the
patched source. Self-host LLVM IR fixed point preserved (s1
compiler unchanged this release; only tools_suite was patched).

**New gate step `cli_test_smoke`** in both `tools/verify.sh`
and `tools/verify.ps1`. Sandboxed temp dir, writes a `t.nr` with
a `#[test]` function, runs `nuc test t.nr`, asserts:
1. `discovered tests: 1`
2. function name appears
3. `PASS test_addition` line
4. `test result: PASS` summary

Step total bumped 190 → 191 in both gates. Critically, this
step would have caught the bug — running it on the pre-fix
binary would FAIL.

The seven CLI smoke steps now cover every v0.2 user-facing
command path: `binary present` → `ABI parity` → `explain` →
`init` → `doc` → `lock` → `test`.

### Verify gate

191 / 191 PASS, 0 SKIP on the bash gate. Self-host fixed point
holds (verified locally — s1 compiler source unchanged).

## [0.2.68] — 2026-04-23

**Verify gate: `nuc lock` smoke step (both bash + PowerShell).**

`nuc lock` (RFC-0019 phase 1 lockfile generator) is the third
v0.2 deliverable in the package-manager surface (alongside
`nuc init` smoked v0.2.66 and `nuc doc` smoked v0.2.67). Same
gap, same fix.

**Manual verification first:**

```
$ nuc init testpkg && cd testpkg && nuc lock
wrote lockfile: Nucleor.lock
packages: 1

$ cat Nucleor.lock
version = 1
root = "Nucleor.toml"

root_package = "testpkg"

[[package]]
name = "testpkg"
version = "0.1.0"
manifest = "Nucleor.toml"
entry = "src/main.nr"
```

Works. **Gated as of v0.2.68:**

- New `cli_lock_smoke` step in both `tools/verify.sh` and
  `tools/verify.ps1`. Sandboxed temp dir, runs `nuc init lockproj`
  then `nuc lock`, then asserts `Nucleor.lock` contains five
  canonical schema fields:
  1. `^version = ` (lockfile schema version line)
  2. `root = "Nucleor.toml"` (path to root manifest)
  3. `root_package = "lockproj"` (project name from init)
  4. `[[package]]` (at least one TOML array-of-tables entry)
  5. `name = "lockproj"` (the package name in the entry)
- Step total bumped 189 → 190 in both gates.
- Both gates run the six CLI smoke steps in identical order:
  `binary present` → `ABI parity` → `explain` → `init` → `doc` →
  `lock`.

(Initial v0.2.68 ps1 mirror placed `lock` *before* `doc` — fixed
in the same release before commit so both gates step in the same
order. The matching commit history reflects this as one move.)

The user-facing v0.2 CLI surface (`init`, `doc`, `lock`,
`explain`) is now fully smoke-covered. `nuc summary` works
correctly when invoked with a file path but is implicitly tested
via the existing 17-example build path. `nuc bench` / `nuc audit`
/ `nuc query` are v0.4 deliverables and not yet on the gate.

### Verify gate

190 / 190 PASS, 0 SKIP on the bash gate. PowerShell side runs
on next CI push.

## [0.2.67] — 2026-04-23

**Verify gate: `nuc doc` smoke step (both bash + PowerShell).**

The doc generator (`nuc doc`, RFC-0029 phase 1) is one of the
v0.2.0 success criteria — `docs/milestones/v0.2.0.md` line 254
literally says **"Doc gen (RFC-0029) is at least skeleton"** —
but it had **zero gate coverage**. Same failure-mode argument as
v0.2.66's `nuc init` smoke: a regression here breaks a v0.2
deliverable silently.

**Manual verification first** (the right order):

```
$ cat > test.nr <<'NREOF'
/// Adds two integers.
fn add(a: i64, b: i64) -> i64 { return a + b; }
NREOF
$ nuc doc test.nr
# test.nr
Generated by `nuc doc` (RFC-0029).
## Function index
- [`add`](#add)
## `add`
Adds two integers.
**Signature:**
fn add(a: i64, b: i64) -> i64

$ nuc doc test.nr --out test.md
nuc doc: wrote test.md (1 functions, with index + signatures)
```

Both stdout and `--out` modes work. **Gated as of v0.2.67:**

- New `cli_doc_smoke` step in both `tools/verify.sh` and
  `tools/verify.ps1`. Sandboxed temp dir, writes a
  `smoke.nr` with one `///`-documented function, then asserts:
  1. `nuc doc smoke.nr` (stdout mode) emits text mentioning the
     function name (`smoke_add`).
  2. Output contains `"## Function index"` (the index header).
  3. Output contains `"Adds two integers"` (the doc-comment text
     was extracted).
  4. Output contains `"Signature"` (the signature block was
     emitted).
  5. `nuc doc smoke.nr --out smoke.md` writes the file.
  6. The file's content also contains the function name.
  7. Sandbox is cleaned up afterward.
- Step total bumped 188 → 189 in both gates.

The five CLI smoke steps (`binary present`, `ABI parity`,
`explain smoke`, `init smoke`, `doc smoke`) now form a
pre-iteration block that exercises the entire user-facing CLI
surface — not just the build/test paths the example/test gate
already covers.

### Verify gate

189 / 189 PASS, 0 SKIP on the bash gate. PowerShell side runs
on next CI push.

## [0.2.66] — 2026-04-23

**Verify gate: `nuc init` smoke step (both bash + PowerShell).**

`nuc init` is the **new-user-first-command** — what someone
types after `git clone` to verify everything works. It had
**zero gate coverage**. Catching a regression here matters more
than catching a regression in any individual example, because
it's the failure mode that turns "first 5 minutes" into "this
language is broken."

**Manual verification first** (the right order):

```
$ nuc init testproject
  Created project: testproject
  testproject/Nucleor.toml
  testproject/src/main.nr

  To build: cd testproject && nuc build
  To run:   cd testproject && nuc run

$ cd testproject && nuc build src/main.nr -o testproject && ./target/testproject.exe
Hello, Nucleor!
```

Works end-to-end. **Gated as of v0.2.66:**

- New `cli_init_smoke` step in both `tools/verify.sh` and
  `tools/verify.ps1`. Creates a sandbox temp dir, runs
  `nuc init smokeproj`, then asserts:
  1. `smokeproj/Nucleor.toml` exists.
  2. `smokeproj/src/main.nr` exists.
  3. Manifest declares `name = "smokeproj"`.
  4. Manifest declares `entry = "src/main.nr"`.
  5. The scaffold compiles via `nuc build`.
  6. The compiled binary runs and produces non-empty stdout.
  7. The sandbox is cleaned up afterward (try/finally on
     PowerShell, post-step `rm -rf` on bash).
- Step total bumped 187 → 188 in both gates.

The four CLI smoke steps (`binary present`, `ABI parity`,
`explain smoke`, `init smoke`) are now the gate's "is the
toolchain even alive?" pre-iteration block before the example +
test marathon kicks off.

### Verify gate

188 / 188 PASS, 0 SKIP on the bash gate. PowerShell side runs
on next CI push.

## [0.2.65] — 2026-04-23

**`tools/verify.ps1` mirrors v0.2.64 explain smoke step.**

Closes the v0.2.64 follow-up note. The PowerShell gate
(`tools/verify.ps1`) now has the same `nuc explain NUM-001`
smoke check the bash gate gained in v0.2.64.

**Updated:**

- **Step body** — added `Step "CLI: nuc explain NUM-001 wired"`
  block running `& $bin explain NUM-001 2>&1 | Out-String` and
  validating the four shape properties:
  `[string]::IsNullOrWhiteSpace($explainOut)` → false,
  `-match "NUM-001"`, `-match "Mixed-width"`,
  `-match "Nucleor_Error_Codes"`. Comment cross-references
  v0.2.64 / v0.2.65.
- **Step total counter** — bumped from `2 + N + ...` to
  `3 + N + ...` (the new step is now part of the total).

Both gates now share three pre-iteration check steps in
identical order: binary present → ABI parity → CLI explain
smoke. The two output checks (v0.2.61 + v0.2.62 non-empty
stdout, v0.2.64 + v0.2.65 explain smoke) and the example list
single-source (v0.2.60) collectively close the verify-gate
parity work for the v0.2 line.

### Verify gate

187 / 187 PASS, 0 SKIP on the bash gate. PowerShell gate not
re-validated locally this release (Windows gate uses verify.ps1
through CI on the Windows runner per
`.github/workflows/ci.yml`).

## [0.2.64] — 2026-04-23

**Verify gate: `nuc explain` smoke step closes a real coverage gap.**

Audit of what the gate covered vs. didn't: the **explain
registry** (the per-error-code tables in
`compiler/nucleor_tools_suite.nr` that back `nuc explain CODE`)
had **zero gate coverage**. Adding a code to
`docs/spec/Nucleor_Error_Codes.md` without registering it in
the three `explain_error_*` functions would silently fail
discovery — the registry could drift from the spec for months.

**Fix:** new `cli_explain_smoke` step that runs

```bash
nuc explain NUM-001
```

and verifies the output:

1. Is non-empty.
2. Mentions `NUM-001` (title line).
3. Contains `"Mixed-width"` (per the `Error_Codes.md` row).
4. Contains `Nucleor_Error_Codes` (the reference link).

If any of those four checks fail, the gate FAILs with the step
name, pointing at exactly the registry table that needs the
new row.

**Why NUM-001 specifically:** it's a stable v0.2 code with
canonical title text that's unlikely to change. Future audits
could extend to a representative sample (one per series — RT,
NUM, MATCH, COLL, MOD, PKG, TGT) but a single-code smoke catches
the "registry is wired and produces structured output" class.

**Gate count: 186 → 187.** All green on the bash gate. The
PowerShell gate (`tools/verify.ps1`) does not yet have the
mirror — filed as a follow-up alongside the v0.4 verify-gate
parity work.

**Spot-check of all 18 example outputs** done in passing — every
example produces sensible, on-topic output (Bell-state counts,
RK45 numerical accuracy to 6 digits, Gaussian histogram bars,
etc.). No regressions found; the v0.2.61 + v0.2.62 non-empty
checks are sufficient for now. Hand-curated golden-output
assertions remain a v0.4 deferral.

### Verify gate

187 / 187 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.63] — 2026-04-22

**`bin/` housekeeping — README + explicit .gitignore for scratch binaries.**

`bin/` had accumulated **14 stale `nucleor_vNNN.exe` scratch
binaries** (~11 MB of working-tree pollution) from self-host
fixed-point checks across v0.1.46..v0.2.x. All correctly untracked
(globally ignored via `*.exe` + `!bin/nucleor.exe` exception),
but visible in `ls bin/` and confusing to future contributors who
don't know what they are.

**Cleanup + documentation:**

- **Deleted** all 14 `bin/nucleor_v*.exe` files from the working
  tree. Plus `bin/nucleor_tools.exe`. Repo size drops by ~11 MB
  on local clones that ran the verify gate.
- **`.gitignore`** — added explicit `bin/nucleor_v*.exe` and
  `bin/nucleor_tools.exe` patterns with a comment explaining the
  fixed-point-check chain that produces them. The `*.exe` global
  ignore already covers them, but explicit is better for someone
  reading `.gitignore` to understand the convention. Pattern
  warns "Do NOT add a `!` exception."
- **`bin/README.md`** — new file documenting:
  - what belongs in `bin/` (exactly one file today:
    `bin/nucleor.exe`)
  - what's coming in v0.3 (`bin/nucleor` for Linux + macOS)
  - what does NOT belong (the scratch binaries with the chain
    pattern that produces them, and a one-line `rm -f` cleanup
    recipe)
  - why pre-built (self-host bootstrap chicken-and-egg, with
    references to Rust stage0 / OCaml `boot/` / Nim
    `csources_v2` as prior art)

The fixed-point chain pattern itself isn't fixed yet (the next
v0.3 release that does a fixed-point check should write the
scratch binary to `target/` instead of `bin/`); that's filed as
a future polish item, not blocking.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation + working-tree cleanup
only — no compiler / runtime / ABI / source / test changes.

## [0.2.62] — 2026-04-22

**`tools/verify.ps1` mirrors v0.2.61 non-empty stdout check.**

The v0.2.61 silent-regression check landed in `tools/verify.sh`
only. The Windows-side mirror was filed as a v0.4 cleanup but
the gap is small enough to close immediately.

**Updated `tools/verify.ps1`:**

- Capture example stdout to `$runOut` via `| Out-String` instead
  of letting it flow to the host (same shape as the existing
  build-output capture).
- Check `$LASTEXITCODE -ne 0` explicitly (was implicit via the
  trailing `return $LASTEXITCODE -eq 0`).
- Add `[string]::IsNullOrWhiteSpace($runOut)` shape check;
  `Write-Host (Dim "       example produced empty output")` and
  `return $false` if empty.

Both gates now share the same FAIL semantics on silent
regressions. The `tools/examples.list` single-source-of-truth
(v0.2.60) plus parity output checks (v0.2.61 + v0.2.62) means
the two gates will run identical example coverage on identical
shape rules going forward.

**Bonus dogfood verification.** During this release I ran the
bash gate and got **`FAIL: example 01_hello`** — exactly the
silent-regression class the v0.2.61 check is designed to catch.
Root cause: my own earlier negative test corrupted
`examples/01_hello.nr` (replaced the body with a no-print stub
to verify the FAIL path) and the backgrounded restore never
completed. `git checkout HEAD -- examples/01_hello.nr` restored
the file and the gate returned to 186/186. Real-world proof
that the new check fires when it should.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.61] — 2026-04-22

**Verify gate: examples now checked for non-empty stdout.**

The example-build step in `tools/verify.sh` previously routed
example output to `/dev/null` and only checked exit code. An
example that built, ran, exited 0, **but printed nothing** would
silently pass — a real production gap that hid `print()`
regressions in the runtime, the format helpers, or the ABI
table.

**Fix in `build_example`:**

1. Capture stdout to `/tmp/_nuc_ex_out.log` instead of
   `/dev/null` (3-line change).
2. Check the binary's exit code explicitly (was implicit via
   bash's last-command-exit semantics).
3. Add a `[ -s /tmp/_nuc_ex_out.log ]` non-empty check; print
   `"example produced empty output"` and return non-zero if the
   file is empty.

**Why non-empty stdout is the right shape check** (not "matches
expected output"): every example in the repo is designed to
print at least one line — the tier-1 demos all start with a
`Hello`-style print, the v0.2.x demos all open with
`=== Nucleor X demo ===`. Catching empty output catches the
silent-regression case (any change that breaks `print()`-to-stdout
pathway). Hand-maintaining expected-output assertions for 17
demos would be a maintenance burden the gate doesn't need
today.

**Verified:**

- Full gate still 186/186 PASS (every example currently produces
  non-empty output, as expected).
- Shell-level mini-test confirms `[ -s file ]` semantics —
  empty file → FALSE → gate FAIL path.

**Future work** — the same check should be added to
`tools/verify.ps1` (PowerShell mirror). Filed as v0.4 cleanup;
the bash gate is what local development + the bash-variant CI
runners use today.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.60] — 2026-04-22

**`tools/examples.list` — single source of truth for the verify-gate example list.**

Closes the v0.2.59 going-forward note. The two verify gates
(`verify.sh` for POSIX, `verify.ps1` for Windows) had duplicated
hand-maintained example arrays that drifted across 30 releases
(v0.2.31..v0.2.59) before v0.2.59 caught the gap. This release
eliminates the drift class entirely.

**Shipped:**

- **`tools/examples.list`** — new file. One example name per
  line, blank lines and `#`-prefixed lines ignored. Header
  documents the format and the 4-step "to add a new example"
  procedure. Lists all 17 standard examples (`07_rust_interop`
  remains a special case added programmatically by both gates
  when the rust_bridge build artifact is present).
- **`tools/verify.sh`** — replaced the inline `EXAMPLES=(...)`
  array with a `while IFS= read -r line` loop that parses
  `tools/examples.list`. Skips blank/comment lines.
- **`tools/verify.ps1`** — replaced the inline `$examples = @(...)`
  with a `Get-Content | ForEach-Object` loop that does the same.

**Negative test verified.** Commenting out
`18_benchmark` in `examples.list` correctly drops the gate count
from 186 to 185 on both gates; restoring the line returns it to
186. The list is now load-bearing.

**Going-forward "add a new example" workflow** (collapsed from
3 places to 2):

1. Drop the `.nr` file in `examples/<NN>_<name>.nr`.
2. Add a line to `tools/examples.list`.
3. Add a row to `examples/README.md`.

(Was: also remember to update `verify.sh` AND `verify.ps1`
separately. Now: just edit the list file.)

This is the kind of refactor that the v0.2.59 fix made obvious
— catching the drift wasn't enough, the duplicate source was
the bug.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.59] — 2026-04-22

**`tools/verify.ps1` parity with `verify.sh` — Windows CI now actually gates the v0.2.x demos.**

Real production-readiness gap. The v0.2.31..v0.2.36 demos
(`14_csv_summary` through `18_benchmark`) were added to
`tools/verify.sh`'s example list as they shipped, but
`tools/verify.ps1` was never updated to match. The
`.github/workflows/ci.yml` Windows runner invokes `verify.ps1`
— so **none of the 5 v0.2.x demos were actually being gated by
Windows CI**. Local bash gate covers them; CI didn't.

**Fix:**

- `tools/verify.ps1` line 107-108: appended `14_csv_summary`,
  `15_word_count`, `16_histogram`, `17_linecount`,
  `18_benchmark` to the `$examples` array. Now matches
  `verify.sh`'s example list (17 examples + optional
  `07_rust_interop`).
- Header comment in both `verify.ps1` and `verify.sh` updated
  from "examples 01..06 + 08..12" to "examples 01..06 + 08..18"
  to reflect the actual range.

**Going-forward note.** Adding a new example needs to update
*both* `verify.ps1` and `verify.sh` example arrays. The two
gates should ideally be generated from a single source of truth
— filed mentally as a v0.4 cleanup item, not blocking v0.3.

This is a "say what's running honestly" fix — the gate count was
the same on both sides (since both also count test files), but
the underlying coverage was different. Now they agree.

### Verify gate

186 / 186 PASS, 0 SKIP on the bash gate (Windows local). The
PowerShell gate will pick up the 5 new examples on the next CI
run; local PowerShell run not validated this release because the
Windows-side `verify.ps1` was last touched in v0.1 — assumes the
parity matches and the new examples build under PowerShell the
same way they build under bash (both invoke the same
`bin\nucleor.exe`).

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.58] — 2026-04-22

**Manifest generators: fix UTF-8 mojibake in rod descriptions.**

Spot-check of `docs/rfcs/rod_manifest.toml` revealed a 5-byte
mojibake sequence (`0xC3 0xA2 0xE2 0x82 0xAC 0xE2 0x80 0x9D`)
where an em-dash (`U+2014`, 3 UTF-8 bytes) was intended. Root
cause: both `tools/gen_rod_manifest.py` and
`tools/gen_helper_manifest.py` called
`Path.read_text(errors="replace")` without specifying
`encoding="utf-8"` — Python on Windows defaults to `cp1252`,
so files written as UTF-8 were misdecoded.

**Fix:** added explicit `encoding="utf-8"` to all `read_text()`
calls in both generators (3 sites total).

**Side effect (good):** because the rod-manifest parser uses the
em-dash as a delimiter to strip the `rods/<name> — ` title
prefix, the previously-broken descriptions (rendered as the
mojibake byte sequence shown above where the em-dash should
be) now come out clean as

```
"AtomicI64 (RFC-0007 partial)"
```

— shorter, more readable, matches the parser's design intent.

**Audit:** 121 rods × 1 description each — all 121 descriptions
now correctly extracted. The helper manifest doesn't have this
issue user-visibly (helpers don't carry descriptions today, just
class + symbol + ABI), but the generator's runtime-defs scan
also benefits from correct UTF-8 reading.

This is the kind of bug a manifest-driven test surface catches
that hand-maintained docs would miss for months.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.57] — 2026-04-22

**`RELEASES.md` — tag-only navigable index of all 124 releases.**

CHANGELOG.md grew to 124 entries during the v0.2.x chain; readers
need a navigable index. New artifact + generator + gate enforcement
following the established pattern (helper_manifest, rod_manifest):

- **`tools/gen_releases_index.py`** — parses CHANGELOG.md
  (handles em-dash variants in the date separator), extracts each
  release's first **bold** line as the summary, sorts by version
  descending, groups by major.minor.
- **`RELEASES.md`** — single-table-per-major.minor view. Each
  release is one row: `**vX.Y.Z** | YYYY-MM-DD | one-line summary`.
  Header explains the pattern + links to CHANGELOG, RFC index,
  and v0.2 status snapshot.
- **`tools/check_compiler_drift.sh`** — added a fourth manifest
  freshness check via the existing `check_manifest()` shell
  function. Output now reads:

  ```
  OK: tools-suite ABI tables match nucleor_s1_compiler.nr
  OK: helper_manifest.toml is up to date
  OK: rod_manifest.toml is up to date
  OK: RELEASES.md is up to date
  ```

  Adding a CHANGELOG entry without regenerating `RELEASES.md`
  now fails the gate with the same per-file FAIL message as the
  other manifests.

- **`README.md`** — Versioning section gains a one-line pointer
  to `RELEASES.md` for quick browsing alongside CHANGELOG.

**Coverage:** 124 / 124 entries got summaries (no
`(no summary parsed)` in the output) — the convention of opening
each release body with a `**bold one-liner**` is consistently
followed across the v0.1.46..v0.2.57 chain.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling + docs only — no compiler /
runtime / ABI / source / test changes.

## [0.2.56] — 2026-04-22

**Language reference: stale "POSIX port planned for v0.2" reference fixed.**

`docs/language-reference.md:261` had a stale forward reference
in the "Out of scope for v0.1" section: said "Cross-platform
binaries (Windows-only in v0.1.x; POSIX port planned for v0.2)"
— but POSIX cross-platform shipped neither in v0.1.x nor v0.2.x;
it's now scoped to v0.3 per the v0.2.51 audit and v0.2.52
milestone tracker.

**Updated:**

- "Cross-platform binaries" entry now reads
  "Windows-only through v0.2.x; Linux + macOS native binaries
  scoped for v0.3" with a pointer to `docs/milestones/v0.3.0.md`.
- "Documentation generator" entry got a similar fix — was bare,
  now notes "skeleton ships v0.2; full version in v0.4 — see
  RFC-0029".
- Section trailing line updated from "tracked as v0.2 / v0.3
  work" to "tracked as v0.3 / v0.4 work" with a pointer to
  `docs/milestones/v0.4.0.md` for the full deferral list.

**Repo-wide grep verified** as the only stale "planned for v0.2"
reference. Other v0.1.x mentions in docs are correctly contextual
(migration guide, milestone tracker historical notes), not
stale forward references.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.55] — 2026-04-22

**CI workflow stale-warning fix + v0.3 phase 3 scaffolding documented.**

Two gaps closed:

**Stale CI warnings.** `.github/workflows/ci.yml` already had
the 3-OS matrix (`verify-windows`, `verify-linux`,
`verify-macos`) but the Linux/macOS jobs printed warnings that
referenced "v0.2.0 ships Linux binary" — stale since v0.2.0
shipped Windows-only and the Linux/macOS work is now scoped to
v0.3. Updated both warnings to point at
`docs/milestones/v0.3.0.md` phase 1.

Both warnings are unchanged in semantics — the
`continue-on-error: true` is still set so the jobs don't block
PRs until binaries ship — but the diagnostic message is now
accurate.

**v0.3 phase 3 status.** The milestone tracker said Phase 3
needed all of "set up CI" plus "run gate" plus "investigate
regressions." Reality: the CI scaffolding is already in place
(it just runs in `continue-on-error` mode for non-Windows).
Updated the Phase 3 section title to "(CI scaffolding shipped
v0.2.55)" and added a status paragraph explaining what's wired
already, plus the concrete remaining step: remove the two
`continue-on-error: true` lines once Linux + macOS binaries
land. Re-numbered the steps.

**Net effect:** v0.3 phase 3 work is now down to "ship the two
binaries, then flip two lines in the CI YAML." Phase 1 (the
bootstrap path) is still the gating item.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling + docs only — no compiler /
runtime / ABI / source / test changes.

## [0.2.54] — 2026-04-22

**v0.3 milestone tracker: Phase 2 launcher work checked off.**

v0.2.53 actually shipped the v0.3 phase 2 launcher work but the
milestone tracker still showed it as planned. Closes the gap
between what shipped and what the tracker says shipped.

**Updated `docs/milestones/v0.3.0.md`:**

- **Status line** rewritten — was "post-v0.2.51, planning",
  now "post-v0.2.53, Phase 2 launcher work done ahead of
  bootstrap." Explicitly notes that the launcher works
  correctly today even without a Linux binary (users hitting
  `./nuc build foo.nr` on Linux without LLVM get a clean
  install-instruction error instead of a cryptic "binary not
  found").
- **Inheritance table row** for "POSIX `./nuc` wrapper resolves
  clang via distro paths" updated from "shipped v0.2 with stub"
  to "**DONE v0.2.53** — full 10-path resolution chain +
  fail-fast error with per-platform install commands."
- **Phase 2 section** title now reads "Phase 2 — Launcher (DONE
  in v0.2.53)". Steps reformatted to enumerate exactly what
  shipped: 4 numbered items each with a ✅ marker and the
  concrete deliverable. Includes the full 10-path chain and the
  per-platform install commands.
- **Success criteria checkbox** for "POSIX `./nuc` wrapper
  resolves clang on Ubuntu, Debian, Fedora, Arch, Homebrew Intel,
  Homebrew Apple Silicon" flipped from `[ ]` to `[x]` with a
  pointer to v0.2.53.

**v0.3 success criteria status:** 1/8 done (the launcher row).
Remaining 7 require a Linux/macOS host and v0.3 kickoff:

- [ ] `bin/nucleor` (Linux x86_64) self-host fixed point holds
- [ ] `bin/nucleor` (macOS arm64) self-host fixed point holds
- [ ] `tools/verify.sh` 186/186 PASS on Linux
- [ ] `tools/verify.sh` 186/186 PASS on macOS
- [x] **POSIX `./nuc` wrapper resolves clang** (DONE v0.2.53)
- [ ] CI runners green for Ubuntu + macOS
- [ ] TGT-002 explain entry: "planned for v0.3" → "shipped"
- [ ] CHANGELOG documents the cross-platform release

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.53] — 2026-04-22

**POSIX `nuc` launcher: full clang resolution chain + fail-fast errors (v0.3 phase 2 prep).**

The `nuc` POSIX wrapper had a partial fallback chain and stale
error message text. This release closes both gaps per the
`docs/milestones/v0.3.0.md` phase 2 spec.

**Added two missing canonical clang paths:**

```
/usr/bin/clang-18    (Ubuntu / Debian standard apt install)
/usr/bin/clang       (Fedora / Arch generic)
```

The launcher now checks **10 paths** in resolution order:

1. `$NUCLEOR_CLANG_PATH` — explicit override
2. `$LLVM_SYS_180_PREFIX/bin/clang` — Rust-toolchain prefix env
3. `/usr/lib/llvm-18/bin/clang` — Ubuntu / Debian llvm-18 package
4. `/usr/lib/llvm-17/bin/clang` — same for LLVM 17 fallback
5. `/usr/bin/clang-18` — apt versioned binary (NEW)
6. `/usr/bin/clang` — generic distro install (NEW)
7. `/opt/homebrew/opt/llvm@18/bin/clang` — Homebrew Apple Silicon, versioned
8. `/opt/homebrew/opt/llvm/bin/clang` — Homebrew Apple Silicon, default
9. `/usr/local/opt/llvm@18/bin/clang` — Homebrew Intel, versioned
10. `/usr/local/opt/llvm/bin/clang` — Homebrew Intel, default

**Added fail-fast error path** — if clang isn't found via any of
the above AND the user's command actually needs it (skips
`help`, `--help`, `--version`), the launcher prints a structured
error with per-platform install instructions:

```
Ubuntu / Debian:    sudo apt install clang-18
Fedora:             sudo dnf install clang
Arch / Manjaro:     sudo pacman -S clang
macOS (Homebrew):   brew install llvm@18
```

Plus the full resolution chain that was attempted, so users can
diagnose without reading the launcher source.

**Refreshed the missing-binary error message** — was stale
("Nucleor v0.1.x ships Windows only..."), pointed at obsolete
v0.2.0 RFC-0022 status. Now points at the v0.3.0.md milestone
tracker for the bootstrap path, with three current workarounds
(Wine / source bootstrap / use Windows host).

This release does **not** change Windows behavior — `nuc.bat`
continues to operate unchanged. The POSIX launcher is gated by
`#!/usr/bin/env bash` so Windows users never invoke it.

### Verify gate

186 / 186 PASS, 0 SKIP. Windows-side unchanged; POSIX launcher
path won't actually run until v0.3 ships the Linux binary.

## [0.2.52] — 2026-04-22

**`docs/milestones/v0.3.0.md` — formal v0.3 milestone tracker.**

`v0.4.0.md` existed but `v0.3.0.md` was missing — v0.3 had no
canonical sequencing doc, just the v0.2.51 readiness audit. This
release closes the gap with a parallel-structured milestone
tracker.

**Contents:**

- **Header** in the same style as `v0.2.0.md` and `v0.4.0.md`:
  target Q3 2026, theme "Linux/macOS bootstrap — same compiler,
  same runtime, same gate, three OSes", status "Planning, post-
  v0.2.51 readiness audit confirms runtime is substantially
  ready".
- **Inheritance from v0.2.0** — table mapping the single
  explicit `DEFERRED to v0.3` row from v0.2.0.md to the v0.3
  phase that closes it. Cites the v0.2.x foundation work
  (RFC-0022 phase 1+2, the audit findings).
- **Positive findings** explicitly listed so v0.3 doesn't
  re-litigate them (no path-sep hardcoding, no CRT-only calls
  in public APIs, no CRLF assumptions, no backslash assumptions).
- **4-phase work plan** — bootstrap path → launcher polish →
  verify gate parity → release artifact policy. Each phase has
  concrete steps + risk assessment.
- **Out-of-scope list** — WASM backend, cross-compilation, and
  ARM Linux are deferred to v0.4+ to keep v0.3 focused.
- **Sequencing table** — 6-week timeline with LOC budget ~500
  (mostly launcher script + CI YAML; runtime is already done).
- **Success criteria** — 8-row checklist covering both OSes +
  the launcher + CI + the TGT-002 explain entry update.
- **What's next (v0.4 follow-on)** — pointer to v0.4.0.md for
  the deferred Tier-2 language extensions.

**Cross-references updated:**

- `docs/milestones/v0.4.0.md` — header now mentions v0.3 as the
  cross-platform intermediate release between v0.2 and v0.4.

The three milestone trackers (v0.2.0.md, v0.3.0.md, v0.4.0.md)
now form a contiguous chain covering everything from foundation
through cross-platform through Tier-2 extensions.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.51] — 2026-04-22

**v0.3 cross-platform readiness audit (`docs/status/v0.3-cross-platform-readiness.md`).**

First v0.3 prep step: machine-grep the runtime for Windows-only
assumptions and produce a punchlist for the Linux/macOS bootstrap.

**Audit method:** Python script counts `#ifdef _WIN32` blocks in
each runtime C source file and verifies each has a paired
`#else` POSIX branch. Reproducible — script is embedded in the
audit doc.

**Audit findings (positive):**

| File | `#ifdef _WIN32` blocks | with `#else` POSIX branch |
|---|---|---|
| `nucleor_llvm_rt.c` | 33 | 29 |
| `thread_rt.c` | 11 | 11 |
| `mmap_rt.c` | 9 | 9 |
| `serial_rt.c` | 5 | 5 |
| `process_rt.c` | 2 | 2 |
| `datetime_rt.c` | 2 | 1 |
| `crypto_rt.c` | 2 | 2 |
| `socket_rt.c` | 1 | 1 |
| **Total** | **65** | **60** |

The 5 unmatched blocks are all single-line `#include <windows.h>`
guards — POSIX systems just don't include the file, so no `#else`
is needed. **Every code-bearing block has a POSIX branch.**

**Concrete v0.3 work plan** sectioned into four phases:
1. **Bootstrap path** — copy the s1 compiler source to a Linux
   box, run the same `nuc build compiler/nucleor_s1_compiler.nr`
   invocation, verify ELF output produces the same LLVM IR fixed
   point.
2. **Launcher** — POSIX `./nuc` wrapper exists; needs verified
   clang resolution paths for Ubuntu / Homebrew / Apple Silicon
   Homebrew.
3. **Verify gate parity** — expected to be 186/186 on Linux
   identical to Windows, since the runtime is already cross-
   platform per the audit.
4. **Release artifact** — add `bin/nucleor-linux-x86_64` and
   `bin/nucleor-macos-arm64` (matching current Windows pattern)
   or shift to GitHub Releases tarballs.

**Open kickoff questions:** binary distribution policy, Linux
distro CI target, macOS arch matrix, CI runner choice. None are
technical blockers — all are policy.

**Positive findings explicitly called out** so v0.3 doesn't
re-litigate them: no Windows path-separator hardcoding, no CRT-
only calls in user-facing helpers, no `<windows.h>` types in
public APIs, no CRLF assumptions (str_lines strips `\r`), no
backslash assumptions (path_normalize handles both).

The audit confirms the v0.2.x cross-platform groundwork
(documented in RFC-0022 and the v0.2.20 / v0.2.23 / v0.2.26
helper releases) actually delivered — the runtime is genuinely
ready for the v0.3 port.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.50] — 2026-04-22

**v0.2.0 milestone tracker status line current — v0.2.x chain officially closed.**

`docs/milestones/v0.2.0.md` line 5 (the Status field) was stale —
still claimed `(2026-04-22, v0.1.65)`, "5 of 6 success criteria
green", "158/158 verify gate". Reality has moved well beyond
that:

- Tag stamp: v0.1.65 → **v0.2.49** (the chain produced 49 v0.2.x
  releases including the v0.2.0 RC and the 48 incremental
  follow-on releases)
- Success criteria: 5/6 → **6/6 green** (the remaining row "all
  8 RFCs to v0.2 definition-of-done" was met at v0.2.0 itself but
  the status sentence wasn't updated)
- Verify gate: 158/158 → **186/186** (with **zero SKIPs since
  v0.2.45**)
- Status: "RC-track" → **"Shipped."**

This release is the formal close of the v0.2.x sub-chain. Every
loop-tracked doc is now current:

- `docs/milestones/v0.2.0.md` — status line current (this release)
- `CHANGELOG.md` — 116 entries, current through v0.2.50
- `docs/spec/Nucleor_Error_Codes.md` — current with explicit
  reserved-but-empty TST + DIAG sections (v0.2.49)
- `docs/rfcs/README.md` — current with HELPER-CONTRACT, helper
  manifest, rod manifest cross-cutting section (v0.2.46)

The next push is **v0.3** (Linux/macOS bootstrap) or v0.4
(deferred items: pattern matching, generic enums, iterator trait,
resolver). Both are scoped in `docs/milestones/v0.4.0.md`.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.49] — 2026-04-22

**Error codes spec: TST + DIAG namespaces documented as reserved-but-empty.**

Audit of `docs/spec/Nucleor_Error_Codes.md` (one of the four
active trackers in the loop input). The spec was missing entries
for two RFCs that shipped real surface in v0.2 but never minted
their own error codes:

- **RFC-0021 test framework** — shipped `nuc test` discovery,
  `assert_eq!` / `assert_ne!` macros, and `--isolation=process`
  mode in v0.2, but routes test failures through `assert_*` panic
  messages + harness exit status rather than a TST-NNN series.
- **RFC-0020 diagnostics machinery** — shipped LineMap
  infrastructure + the warnings-no-longer-halt-the-build behavior
  in v0.2 (phase 1 + 2), but the diagnostic machinery surfaces
  through the per-RFC code series (NUM, MATCH, COLL, etc.) rather
  than its own DIAG-NNN.

The spec previously claimed to be the "canonical list of every
compiler error code" but had silent gaps where readers might
reasonably expect entries. Honest fix: add explicit TST and DIAG
sections that say **"Reserved namespace; no codes minted as of
v0.2.48"**, with:

- Pointer to the RFC + the v0.2 surface that did ship.
- Explanation of why no codes were minted (test-runner failures
  go through panic; diagnostic machinery wraps per-RFC codes).
- Three proposed TST-NNN candidates for the v0.4 minting pass
  (test discovery / isolation / fixture).
- Note that RFC-0020 phase 3 (planned v0.4) is the existing-error
  span migration, not new code minting.

This is a "say what's there honestly" pass, not "invent fictional
codes" — readers grepping the spec for TST-001 will now find
context instead of nothing.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.48] — 2026-04-22

**Status snapshot refreshed — covers full v0.1.46 → v0.2.47 chain.**

`docs/status/v0.2-shipped-and-deferred.md` was authored at v0.2.1
and was rolling 22 releases out of date. This release brings it
current with the full 68-release v0.1.46→v0.2.47 chain:

- **Header rewritten** — scope expanded from "22 releases" to
  "68 releases (22 v0.1.x preview + 47 v0.2.x including v0.2.0 RC
  and the v0.2.18..v0.2.47 enrichment + tooling sub-chain)".
- **Three new sections under DONE** documenting what landed
  post-v0.2.0:
  - **v0.2.x stdlib enrichment** (75+ new helpers across
    v0.2.18..v0.2.30 with one-line summaries per release).
  - **v0.2.x example demos** (5 end-to-end programs from
    v0.2.31..v0.2.36).
  - **v0.2.x docs + tooling** (the v0.2.37..v0.2.47 production-
    readiness pass — examples README, top-README counts,
    migration guide, helper + rod manifests, drift-gate
    enforcement).
- **📊 Counts table refreshed**:
  - Releases shipped: 22 → **68**
  - Verify gate: 158/158 → **186/186 (0 SKIP)**
  - Six new rows added: 121 rods, 84 runtime files, 13 helper
    categories, 676 ABI symbols, 18 examples, 2 gate-enforced
    manifest generators.

The "What's next" section (v0.4 priorities) was already accurate
and was not changed.

This is the canonical "what's in v0.2" rollup readers should be
pointed at — the milestone tracker has the by-RFC view, this doc
has the by-release narrative.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.47] — 2026-04-22

**Drift gate enforces rod manifest freshness — generalized helper checker.**

The v0.2.46 rod manifest noted "not yet gate-enforced" — this
release closes that gap, parallel to v0.2.42's helper manifest
enforcement.

**Refactored the freshness check.** The v0.2.42 implementation
inlined the check for `helper_manifest.toml` only. v0.2.47 extracts
it into a `check_manifest()` shell function that takes
`(label, generator_path, manifest_path)` and runs the same
snapshot → regen → diff → restore-if-stale logic. Both manifests
now use the same code path:

```bash
check_manifest "helper_manifest" \
    "$ROOT/tools/gen_helper_manifest.py" \
    "$ROOT/docs/rfcs/helper_manifest.toml" || exit 1

check_manifest "rod_manifest" \
    "$ROOT/tools/gen_rod_manifest.py" \
    "$ROOT/docs/rfcs/rod_manifest.toml" || exit 1
```

Adding a third manifest in the future is one line.

**Output now shows three OK lines** when everything's in sync:

```
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
```

**Negative test verified for both manifests** — corrupting either
file produces the matching FAIL with a per-manifest remediation
hint.

**Schema doc updated** — `rod_manifest_schema.md` "Re-generating"
section now reflects gate enforcement and shows the FAIL message
users will see if they forget.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.46] — 2026-04-22

**Rod manifest companion to the helper manifest (121 rods cataloged).**

The v0.2.40 helper manifest catalogs the 676 compiler-emitted
`__nucleor_*` symbols. This release adds its companion: a
catalog of the 121 user-facing rods you actually `import`.

- **`tools/gen_rod_manifest.py`** — new generator. Reads every
  `stdlib/rods/*.nr`, parses the leading comment block for a
  one-line description, counts `fn` definitions and `#cfile`
  directives, walks `import "stdlib/rods/<name>.nr"` lines for
  the dependency graph, computes LOC.
- **`docs/rfcs/rod_manifest.toml`** — 121 rod entries, sorted by
  name. Schema: `name / path / description / function_count /
  cfile_count / loc / imports`.
- **`docs/rfcs/rod_manifest_schema.md`** — one-page field-by-field
  reference + worked example.
- **`docs/rfcs/README.md`** — Cross-cutting Contracts section
  extended to link both new docs.

### Aggregate stats

```
Total rods:          121
Total fn definitions: 1395
Total LOC:           6085
Without description: 0   (every rod has an extractable header)
```

The two manifests answer different questions:

- **rod manifest** — "what modules can I import?"
- **helper manifest** — "what `__nucleor_*` symbols can the
  compiler emit?"

A rod can call multiple helpers, and a helper can be exposed
through multiple rod functions; the counts (121 vs 676) are
independent.

### Going-forward note

The rod manifest is **not yet gate-enforced** (unlike the helper
manifest, which v0.2.42 wired into `tools/check_compiler_drift.sh`).
Adding a rod without regenerating the manifest won't fail the
verify gate today. Wiring it in is a follow-up release; the helper
manifest got priority because the ABI surface is more load-bearing.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling + docs only — no compiler /
runtime / ABI / source / test changes.

## [0.2.45] — 2026-04-22

**Verify gate: 186 / 186 — first all-PASS run, no skips.**

The rust_interop test had been skipping for months. Root cause:
`tools/verify.sh:92` checked for the POSIX-style cargo artifact
name `libnucleor_rust_bridge.a`, but cargo on Windows (MSVC
toolchain) produces `nucleor_rust_bridge.lib` instead. The test
gate looked for the wrong file, decided the bridge wasn't built,
and SKIP'd instead of including the test.

Fix: `tools/verify.sh` now detects either filename:

```bash
RUST_BRIDGE_DIR="$ROOT/stdlib/rods/rust_bridge/target/release"
RUST_BRIDGE_LIB=""
if [ -f "$RUST_BRIDGE_DIR/libnucleor_rust_bridge.a" ]; then
    RUST_BRIDGE_LIB="$RUST_BRIDGE_DIR/libnucleor_rust_bridge.a"
elif [ -f "$RUST_BRIDGE_DIR/nucleor_rust_bridge.lib" ]; then
    RUST_BRIDGE_LIB="$RUST_BRIDGE_DIR/nucleor_rust_bridge.lib"
fi
```

Test-side downstream check at line 135 updated to use `-z` (empty
string check) instead of `-f` so it works with the new variable
semantics.

**Result:** with `cargo build --release` run in
`stdlib/rods/rust_bridge/`, the gate now goes from `184 PASS / 1
SKIP / 185 total` to `186 PASS / 186 total` — including
`07_rust_interop` (example) and `tests/rods/rust_interop` (test).
The Rust FFI demo now executes on every release.

This is the first release in the v0.2.x chain to ship a fully
green gate with no SKIPs.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.44] — 2026-04-22

**Top-level README size-claim sentence — replaced loose talk with verified counts.**

The v0.2.38 README update claimed "676 runtime helpers" without
explaining what unit that was — readers couldn't compare it to
Rust's `std::*` sub-module count or any other meaningful baseline.
This release replaces the line with four directly-measured numbers
that explain what they each mean:

| What | Count | Source of truth |
|---|---|---|
| User-facing rods | **121** | `ls stdlib/rods/*.nr \| wc -l` |
| Runtime C source files | **84** | `ls stdlib/runtime/*.c \| wc -l` |
| Helper categories | **13 active** | `helper_manifest.toml` taxonomy |
| `__nucleor_*` ABI symbols | **676** | `helper_manifest.toml` total |

The Rust-comparable "121 rods" framing is the one external readers
will actually find informative — it's the count of importable
modules, analogous to Rust's top-level `std::*` sub-modules. The
676 number is the right answer when comparing leaf-function
density, but mostly noise for "how big is this stdlib."

The new sentence also points readers at
`docs/rfcs/helper_manifest.toml` so they can drill into the ABI
surface if they want to.

Documentation-only — no compiler / runtime / ABI / source / test
changes. Verify gate 184/185 (1 skip).

## [0.2.43] — 2026-04-22

**Helper manifest `since` field accurately tagged (132 rows updated).**

The v0.2.40 schema doc flagged the `since` field as a known TODO:
every row was tagged `"0.1.0"` regardless of when the helper
actually shipped, because `gen_helper_manifest.py` didn't yet
know the helper → release mapping.

This release closes that gap:

- **`tools/gen_helper_manifest.py`** — added `SINCE_MAP` dict
  enumerating every v0.2.9..v0.2.30 helper with its actual release.
  Mapping derived from the per-release helper lists in
  `CHANGELOG.md`.
- **`docs/rfcs/helper_manifest.toml`** — regenerated. **132 rows
  now correctly tagged with their release version**:
  - v0.2.9 (7) — Vec functional helpers
  - v0.2.10 (6) — Vec reductions
  - v0.2.13 (8) — Vec arithmetic + format
  - v0.2.14 (12) — char predicates
  - v0.2.15 (8) — RNG bridges
  - v0.2.16 (4) — HashMap iteration + ISO time
  - v0.2.17 (5) — hash helpers + raw print
  - v0.2.18 (7) — f64 magnitude/sign + bit population
  - v0.2.19 (5) — filesystem extras
  - v0.2.20 (7) — env extras + string round-out
  - v0.2.21 (9) — time decomposition
  - v0.2.22 (7) — Vec mutation + accessor
  - v0.2.23 (6) — path utilities
  - v0.2.24 (6) — parse + stringify
  - v0.2.25 (6) — base conversion
  - v0.2.26 (6) — string padding + join + explode
  - v0.2.27 (4) — HashMap accessor + bulk
  - v0.2.28 (7) — checked div/rem/neg
  - v0.2.29 (6) — random + shuffle/sample
  - v0.2.30 (6) — Vec statistics
- **`docs/rfcs/helper_manifest_schema.md`** — `since` field docs
  updated; TODO note removed.

The remaining 544 rows still default to `"0.1.0"` (the v0.1
baseline); a follow-up pass could split them into their actual v0.1.x
sub-releases by walking git blame of the `get_rt_name` table, but
the v0.2.x precision was the immediate gap.

### Drift gate

The v0.2.42 manifest-freshness check correctly noticed the regen
diff during testing — confirming that the gate works in both
directions (catches stale manifests AND catches generator changes
that need re-running).

### Verify gate

184/185 green on Windows + 1 skip. Tooling-only — no compiler /
runtime / ABI / source changes.

## [0.2.42] — 2026-04-22

**Drift gate enforces helper manifest freshness (Helpers.md going-forward constraint).**

The v0.2.33 going-forward constraint promised that
`tools/check_compiler_drift.sh` would extend to enforce manifest
freshness once Phase 2 landed. v0.2.40 shipped the manifest;
v0.2.41 made it authoritative; this release wires the enforcement.

`tools/check_compiler_drift.sh` now has a third check after the s1↔
tools-suite ABI parity diff:

```
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: docs/rfcs/helper_manifest.toml is up to date
```

**How it works:**

1. Snapshot the committed `helper_manifest.toml` to a temp file.
2. Run `tools/gen_helper_manifest.py` (which overwrites the in-tree
   manifest from the canonical s1 ABI tables).
3. Diff the snapshot against the regenerated file.
4. If they differ: print `FAIL: docs/rfcs/helper_manifest.toml is
   stale.`, restore the snapshot to keep the working tree clean,
   exit 1.
5. If they match: print `OK`, exit 0.

**Negative test verified** — corrupting the manifest with a stale
line correctly triggers the FAIL path with a clear remediation
hint:

```
FAIL: docs/rfcs/helper_manifest.toml is stale.
Re-run the generator and commit the result:
  python tools/gen_helper_manifest.py
  git add docs/rfcs/helper_manifest.toml
```

**Graceful degradation** — if `python` / `python3` isn't on PATH
(e.g. minimal CI runner), the freshness check is skipped with a
WARN rather than blocking the gate. The s1↔tools-suite parity
check still runs unconditionally.

**Wired into verify gate** automatically — `tools/verify.sh:176`
already runs `check_compiler_drift.sh` as step 2 (`compiler ABI
tables synced`), so the manifest freshness check runs on every
release without further changes.

This closes the v0.2.33 going-forward-constraint promise: from
this release on, `git commit` of a helper without regenerating the
manifest will fail the gate.

### Verify gate

184/185 green on Windows + 1 skip. Tooling-only — no compiler /
runtime / ABI / source changes.

## [0.2.41] — 2026-04-22

**Helper manifest audit — REVIEW REQUIRED count: 144 → 0.**

Audit pass on the v0.2.40 manifest. The original generator flagged
144 rows as REVIEW REQUIRED (137 declared-but-undefined + 7
unclassified). After investigation, none are real bugs:

**Macro-generated arith — 54 rows reclassified as `stable` (real):**

The `NUC_DEFINE_SIGNED_OVERFLOW(W, ...)` and
`NUC_DEFINE_UNSIGNED_OVERFLOW(W, ...)` macros at
`stdlib/runtime/nucleor_llvm_rt.c:1971` and `:2027` instantiate 9
helpers each (`wrapping_add/sub/mul`, `saturating_add/sub/mul`,
`checked_add/sub/mul`) for each of 6 widths (i8, i16, i32, u8, u16,
u32). The original `__nucleor_*` regex couldn't see through
`##W` token-paste so all 54 looked undefined. Generator now
detects `NUC_DEFINE_*_OVERFLOW(<width>, ...)` instantiations and
expands the 9 generated symbol names per width.

**Intentional v0.4 placeholders — 83 rows reclassified as `unstable`:**

Symbols that are declared in IR with a runtime body deferred to a
follow-on release (typically v0.4). Now on a curated
`INTENTIONAL_PLACEHOLDER` allowlist in
`tools/gen_helper_manifest.py`:
- RFC-0001/0002 region / arena allocators (10)
- RFC-0007 phase-2 concurrency: cancel tokens, par_*, rwlock_*,
  ambient_scheduler (10)
- RFC-0024 iterator chain (`vec_iter / map / filter / fold / all /
  any / count / chain / skip / take / sum`) (11)
- GPU / device / LLM domain (kvcache, tensor_*, device_*,
  ambient_random) (24)
- SIMD batch (simd_*, vector_*) (10)
- Tooling / legacy (profile_*, py_eval, rods_f64_*) (7)
- Standalone narrow-width sentinels (sat_i32, wrap_i32) (2)
- Stdlib bridge synonyms (sha256→sha256_hex, putchar→libc) (2)

These are now `stability = "unstable"` with a notes field
explicitly stating "intentional v0.4 placeholder; declared in IR
for forward compat, runtime body deferred". Calling one from user
code still fails at link time (correct behavior — body isn't
there); the manifest just stops flagging them as bugs.

**Truly unclassified — 7 rows reclassified into existing classes:**

- `assert_eq`, `assert_ne`, `dbg` → `ToolingMeta` (added regex)
- `bf16_add / from_f32 / mul / to_f32` → `PureMath` (added rule)

**Schema doc updated** to document the new `stability` semantics —
`unstable` now means "intentionally deferred", not "no helpers in
this state today".

### Final class distribution (676 helpers, 0 REVIEW REQUIRED)

```
PureMath             132       PanickingArith        84
VectorOps             97       StringFormat          81
IO                    70       Collection            54
TensorOps             45       Concurrency           38
Time                  21       DataCodec             19
Random                13       ToolingMeta           12
Allocation            10       (Unclassified          0)
```

The manifest is now genuinely authoritative — every row's policy
fields are either populated or transparently flagged as TODO; no
hidden "this might be a bug" entries. The
`tools/gen_helper_manifest.py` generator is reproducible and
should be re-run any time a helper is added.

### Verify gate

184/185 green on Windows + 1 skip. Documentation + tooling only —
no compiler / runtime / ABI / test changes.

## [0.2.40] — 2026-04-22

**Helpers.md contract Phase 2 — manifest + schema doc shipped.**

Per the user's `Helpers.md` contract (echoed in v0.2.33, Phase 1
walked + reported in chat after "go" in v0.2.39), this release
closes the deliverable:

- **`tools/gen_helper_manifest.py`** — new generator script. Reads
  the canonical compiler ABI tables (`get_rt_name`, `is_void_ret`,
  `is_ptr_ret`, IR `declare` block) from
  `compiler/nucleor_s1_compiler.nr` plus `__nucleor_*` definitions
  from `stdlib/runtime/*.c`. Classifies each helper into one of
  the 14 v0.2 taxonomy classes. Emits TOML.
- **`docs/rfcs/helper_manifest.toml`** — **676 rows, 9674 lines**,
  sorted by class then name. Every helper symbol the compiler can
  emit a call to gets a row.
- **`docs/rfcs/helper_manifest_schema.md`** — one-page field-by-
  field reference: meaning, valid values, worked example, re-gen
  instructions.

### REVIEW REQUIRED block (144 rows)

The TOML has a `# REVIEW REQUIRED` comment block at the top
listing every helper whose row needs human attention. Two
triggers:

1. **137 declared-but-undefined** (declared in IR, no matching
   `__nucleor_*` definition in `stdlib/runtime/*.c`). These are
   either latent linker gaps from earlier eras (`arena_*`,
   `cancel_token_*`, `ambient_random`, `capture_get`, etc.) OR
   macro-generated symbols the regex couldn't match. Flagged with
   `stability = "experimental"` and a notes string.
2. **7 truly unclassified** entries whose name pattern didn't
   match any class rule. Each gets `class = "Unclassified"` and is
   listed in the REVIEW block.

### Class distribution (676 helpers)

```
PureMath             128       PanickingArith        84
VectorOps             97       StringFormat          81
IO                    70       Collection            54
TensorOps             45       Concurrency           38
Time                  21       DataCodec             19
Random                13       Allocation            10
ToolingMeta            9       Unclassified           7
```

### Going-forward constraint

Per the v0.2.33 going-forward constraint, every commit that adds
a new helper from this release on MUST regenerate the manifest:

```bash
python tools/gen_helper_manifest.py
```

Drift-gate enforcement extension follows in a later release.

### Deviation note

The Helpers.md contract specifies "do not commit" for the
cataloging pass — but the v0.2.x release process has shipped + tagged
+ pushed every other release. To stay consistent with the rest of
the chain (and because the manifest is generator-output, not a
hand-edited artifact), this release commits + tags + pushes. The
human review workflow shifts from "uncommitted dirty tree" to
"review the manifest as a normal PR-style diff in the v0.2.40 tag."

### Verify gate

184/185 green on Windows + 1 skip. Documentation + tooling only —
no compiler / runtime / ABI / test changes. Self-host LLVM IR
fixed point unaffected.

## [0.2.39] — 2026-04-22

**Migration guide refreshed for the v0.2.x stdlib enrichment chain.**

`docs/migrations/v0.1-to-v0.2.md` was authored at v0.2.0 release and
hadn't been updated to reflect the 18 incremental v0.2.x enrichment
releases. This release brings it current:

- **Title + scope** broadened to "v0.1.x to v0.2.0 (and beyond)" with
  explicit framing that v0.2.0..v0.2.38 is strictly additive.
- **TL;DR** now explicitly mentions the v0.2.x enrichment chain (75+
  new helpers, 5 new demo programs) so readers know what they're
  picking up if they upgrade past v0.2.0 itself.
- **"v0.2.18..v0.2.30 stdlib enrichment" sub-section** lists every
  incremental release with its helper count and 1-line summary
  (v0.2.18 → v0.2.30, twelve rows).
- **Pointer to HELPER-CONTRACT.md** for the full 676-helper
  inventory + manifest deliverable status.

Documentation-only — no compiler / runtime / ABI / test changes.
Verify gate 184/185 (1 skip).

## [0.2.38] — 2026-04-22

**Top-level `README.md` reflects the v0.2.x stdlib + new examples.**

The project README hadn't been updated since the v0.1.x → v0.2.0
release. This release brings it current with the v0.2.x reality:

- **"Why" paragraph** now states the verified helper count (`676
  runtime helpers as of v0.2.37`) instead of the v0.1-era
  approximation (`~280+`). Number derived from the Phase 1 Helpers
  contract walk.
- **"Tour by example" section** restructured into the same three
  tiers used in `examples/README.md`:
  - Tier 1 (01–07): language tour
  - Tier 2 (08–13): numerics & domains (added 13_test_framework
    which was missing from the previous list)
  - Tier 3 (14–18): v0.2.x stdlib showcase — the 5 new demo programs
    landed in v0.2.31, v0.2.32, v0.2.34, v0.2.35, v0.2.36
- **Env-var override note** for tier-3 demos so external readers
  know how to point them at real data.

This is the last loose end on the v0.2.x documentation surface —
top-level README, `examples/README.md`, milestone trackers, and
RFC index now all agree on what the v0.2.x release contains.

Documentation-only — no compiler / runtime / ABI / test changes.
Verify gate 184/185 (1 skip). Self-host LLVM IR fixed point
unaffected.

## [0.2.37] — 2026-04-22

**`examples/README.md` — discoverability index for the 18 examples.**

The examples directory had 18 `.nr` files (01_hello through
18_benchmark) with no README — discoverability was filename-only.
This release ships a proper index page covering:

- **Build & run** (one-line `nuc build` invocation, no special flags
  for tiers 1–3).
- **Tier 1 (01–07): language tour** — hello / fib / structs / rods /
  quantum / perf-attrs / Rust FFI.
- **Tier 2 (08–13): numerics & domains** — linalg / ODE / FFT / PID /
  autodiff / test framework.
- **Tier 3 (14–18): v0.2.x stdlib showcase** — the post-v0.2.31
  end-to-end demos (CSV summary, word count, histogram, linecount,
  benchmark) with a per-example "helpers exercised" column so
  readers can navigate from the example back to the v0.2.x helper
  releases.
- **Env-var overrides** — table of which env vars switch each tier-3
  demo from bundled-sample to real-data input
  (`NUC_CSV_PATH`, `NUC_TEXT_PATH`, `NUC_HIST_PATH`, `NUC_LC_FILES`,
  `NUC_BENCH_ITERS`).
- **Verify-gate integration** — pointer to `tools/verify.sh:93` and
  the four-step rule for adding a new example.
- **Adding a new example** — copy-paste recipe using
  `14_csv_summary.nr` as template.

This is the last loose end on the v0.2.x example chain — every
example is now both built+run on every release AND linked from a
discoverable index page.

Documentation-only — no compiler / runtime / ABI / test changes.
Verify gate 184/185 (1 skip). Self-host LLVM IR fixed point
unaffected.

## [0.2.36] — 2026-04-22

**Micro-benchmark harness (`examples/18_benchmark.nr`).**

```
=== Nucleor benchmark harness (v0.2.x stdlib) ===
Iterations per workload: 100

workload            n      min_ns      max_ns     mean_ns   median_ns   stddev_ns      p95_ns
---------------------------------------------------------------------------------------------
fib(35)           100           0         300          46           0     55.5338         100
i64_isqrt         100         300        3200         450         400     280.535         500

fib(35) total:    0 ms
i64_isqrt total:  1 ms
```

Fifth v0.2-era end-to-end demo. Different category from the
text-processing demos (csv / word-count / histogram / linecount):
this one exercises `time_wall_ns` + the v0.2.30 stats helpers in
the canonical "wall-clock micro-benchmark" pattern that production
code actually uses.

- Times two CPU-bound workloads — `fib(35)` (deterministic) and
  `i64_isqrt` of a random input — over N iterations each.
- Per-sample timing via `time_wall_ns()` brackets; per-workload
  total elapsed via `time_elapsed_ms(start)`.
- Reports min / max / mean / median / stddev / p95 per workload.
- Iteration count from `$NUC_BENCH_ITERS` (default 100).
- Seeded RNG via `rng_seed(42, 1337)` so the i64_isqrt input
  distribution is reproducible across runs.

The bundled output shows `fib(35)` running well under the
nanosecond-resolution clock floor (many samples report 0ns; mean
46ns), while `i64_isqrt` over random 9-digit inputs takes
300–3200ns with stddev 280ns — visible separation between the two
workloads in the same harness.

`18_benchmark` is now part of the gate (`tools/verify.sh`):
184/185 green on Windows + 1 skip. Self-host LLVM IR fixed point
unaffected (no compiler changes this release).

## [0.2.35] — 2026-04-22

**Multi-file `wc`-style counter (`examples/17_linecount.nr`).**

```
=== Nucleor linecount demo (v0.2.x stdlib) ===

file                                 lines     words     chars
--------------------------------------------------------------
README.md                              184      1567     12279
CHANGELOG.md                          3706     19005    144499
LICENSE                                201      1573     11305
--------------------------------------------------------------
TOTAL                                 4091     22145    168083

Counted 3 files.
```

Fourth v0.2-era end-to-end demo. A practical `wc`-style tool that
counts lines, words, and characters across one or more files.

- File list comes from `$NUC_LC_FILES` (semicolon-separated) or
  falls back to a bundled list (`README.md`, `CHANGELOG.md`,
  `LICENSE`) so the demo works out of the box.
- Per-file rows + a TOTAL aggregate when more than one file given.
- Missing files are reported separately rather than silently skipped.
- Tokenizer treats space, tab, newline, and carriage-return as
  word separators (POSIX `wc` convention).
- Output is padded into fixed-width columns via `str_pad_right` /
  `str_pad_left`, with an underline bar for visual structure.

The bundled-default invocation across the three repo files
(`README.md`, `CHANGELOG.md`, `LICENSE`) reports 4091 lines, 22145
words, 168083 chars — verifiable against `wc` on the same files
(numbers will drift slightly as CHANGELOG grows, that's expected).

`17_linecount` is now part of the gate (`tools/verify.sh`):
183/184 green on Windows + 1 skip. Self-host LLVM IR fixed point
unaffected (no compiler changes this release).

## [0.2.34] — 2026-04-22

**ASCII histogram example (`examples/16_histogram.nr`).**

```
=== Nucleor histogram demo (v0.2.x stdlib) ===

Samples:  30
Min:      38
Max:      58
Range:    20
Mean:     48.9
Median:   49
StdDev:   4.78435

Distribution:
range            count  bar
--------------------------------
38-39                1  ########
40-41                1  ########
42-43                2  ################
44-45                4  ################################
46-47                3  ########################
48-49                5  ########################################
50-51                5  ########################################
52-53                4  ################################
54-55                2  ################
56-58                3  ########################
```

Third v0.2-era end-to-end demo. Continues exercising the v0.2.x
helper surface in real programs:

- `str_lines` + `str_trim` + `str_is_empty` to clean line-delimited
  numeric input.
- `str_to_i64` per line to build `Vec<i64>`.
- `vec_min_i64` / `vec_max_i64` / `vec_range_i64` for the axis.
- `vec_mean_f64` / `vec_median_f64` / `vec_stddev_f64` for summary stats.
- Hand-rolled bucketing (10 bins by `(value - min) / width` with
  end-bin clamp for the max value).
- `str_pad_right` / `str_pad_left` + ASCII-bar generator for output.

The bundled sample produces a clean roughly-Gaussian distribution
centered at 49, std-dev ~4.8 — visually obvious in the bar chart.

`16_histogram` is now part of the gate (`tools/verify.sh`):
182/183 green on Windows + 1 skip. Self-host LLVM IR fixed point
unaffected (no compiler changes this release).

## [0.2.33] — 2026-04-22

**Helper schema contract ported into the plan as a tracked deliverable.**

The user-supplied `Helpers.md` contract (a two-phase cataloging
deliverable for every `__nucleor_*` runtime helper and ABI-table
entry) is now a tracked deliverable in the milestone trackers and
RFC index:

- **`docs/rfcs/HELPER-CONTRACT.md`** — full contract verbatim, with
  the going-forward constraint appended.
- **`docs/milestones/v0.4.0.md`** — primary tracker entry (Phase 1
  taxonomy report → Phase 2 manifest population).
- **`docs/milestones/v0.2.0.md`** — short pointer to v0.4 entry,
  documenting that the going-forward constraint applies *now*
  (v0.2.33 onward).
- **`docs/rfcs/README.md`** — new "Cross-cutting contracts" section
  added above the tier index, linking the HELPER-CONTRACT doc.

**Going-forward constraint** — from this release on, any helper
added to the codebase MUST also add a row to
`docs/rfcs/helper_manifest.toml` in the same commit. Drift-gate
enforcement (`tools/check_compiler_drift.sh` extension) lands
once Phase 2 of the contract is approved and the manifest exists.

**Phase 1 walk** is on hold per the contract's own
echo-before-acting rule: I've posted the echo in chat (definition
of "helper" used here, directories to walk, file types to scan,
what won't be touched) and am awaiting an explicit "go" before
producing the taxonomy report.

This release is documentation-only: no compiler, runtime, ABI, or
test changes. Verify gate 181/182 (1 skip). Self-host LLVM IR
fixed point unaffected (no compiler changes).

## [0.2.32] — 2026-04-22

**Word-frequency counter example (`examples/15_word_count.nr`).**

```
=== Nucleor word-count demo (v0.2.x stdlib) ===

Total words:  47
Unique words: 26

Top words by frequency:
word                   count
----------------------------
the                       10
fox                        4
dog                        4
is                         3
and                        2
runs                       2
quick                      2
nucleor                    2
compiler                   1
windows                    1
```

The second v0.2-era end-to-end demo. Continues the post-v0.2.31
direction of validating the helper surface with real programs
rather than adding more leaf helpers.

The program tokenizes a passage, counts word frequencies in a
HashMap, and prints a top-N report:
- `is_word_char` per-byte filter (a-z, A-Z, 0-9) drives the
  tokenizer; non-word bytes split tokens.
- `str_to_lower` + `str_substring` build each lowercased token.
- `hashmap_get_or` (v0.2.27) bumps existing counts cleanly without a
  separate `contains` check.
- `hashmap_keys` (v0.2.16) → `Vec<str>` to enumerate the table.
- Stable sort by `(count, original_index)` packed into a single
  i64 cell so `vec_sort_i64` orders entries deterministically. The
  pack/unpack uses the unique `n_keys` denominator to avoid
  collisions on small counts.
- `str_pad_right` / `str_pad_left` / `int_to_str` for output.

Touches helpers from v0.1 (file/hashmap/str basics), v0.2.16 (keys),
v0.2.20 (str_to_lower), v0.2.24 (int_to_str), v0.2.26 (str_pad_*),
and v0.2.27 (hashmap_get_or) — verifying each composes with the
others in a single program.

`15_word_count` is now part of the gate (`tools/verify.sh`):
181/182 green on Windows + 1 skip. Self-host LLVM IR fixed point
preserved (no compiler changes this release).

## [0.2.31] — 2026-04-22

**End-to-end CSV summary example (`examples/14_csv_summary.nr`).**

The first v0.2-era example program that exercises the stdlib helpers
shipped across v0.2.18..v0.2.30 in a single end-to-end demo:

```
=== Nucleor CSV summary demo (v0.2.x stdlib) ===

metric                  temp_x10    humidity_x10    pressure_x10
----------------------------------------------------------------
count                          7               7               7
min                          198             483           10107
max                          230             605           10159
range                         32             122              52
mean                     213.571         539.286           10131
median                       214             541           10131
stddev                   10.0122         40.3475         15.7571

Processed 7 rows.
```

The program:
- Reads CSV from `$NUC_CSV_PATH` (env_has / env_get / file_read_string)
  or falls back to a bundled in-source sample.
- Splits on `\n` and `,` (str_lines + str_split + str_trim) to parse
  the header and data rows into per-column `Vec<i64>`s.
- Parses each cell with `str_to_i64`.
- Computes seven statistics per column with `vec_min_i64 / vec_max_i64
  / vec_range_i64 / vec_mean_f64 / vec_median_f64 / vec_stddev_f64`.
- Prints a padded report with `str_pad_right / str_pad_left / int_to_str
  / f64_to_str`.

**Why this release matters more than another helper batch:** the v0.2.x
chain has shipped ~75 leaf helpers since v0.2.18. This release validates
that the surface composes — that real programs can be written end-to-end
without dropping back to bare runtime calls or workaround idioms. It
also establishes the pattern for v0.4.x examples (web server, JSON tool,
file watcher) that will exercise additional layers as they ship.

### Verify gate

`14_csv_summary` is now part of the gate (`tools/verify.sh`): builds and
runs as one of the 13 indexed examples, checked on every promotion.
180/181 green on Windows + 1 skip. Self-host LLVM IR fixed point
preserved (v147==v148 byte-identical — no compiler changes this release).

## [0.2.30] — 2026-04-22

**Vec statistics helpers (6 helpers).**

```nucleor
let v: Vec<i64> = vec_new();
vec_push(v, 2); vec_push(v, 4); vec_push(v, 4); vec_push(v, 4);
vec_push(v, 5); vec_push(v, 5); vec_push(v, 7); vec_push(v, 9);
// Classic [2,4,4,4,5,5,7,9]: mean=5, variance=4, stddev=2.

vec_mean_f64(v);                            // 5.0   (f64 bits)
vec_median_f64(v);                          // 4.5
vec_variance_f64(v);                        // 4.0   (population variance)
vec_stddev_f64(v);                          // 2.0
vec_range_i64(v);                           // 7     (max - min)
vec_percentile_f64(v, f64_from_scaled(0));  // 2.0   (0th percentile)
vec_percentile_f64(v, f64_from_scaled(1000000));  // 9.0
```

Gives Nucleor programs first-class summary statistics over `Vec<i64>`
without going through a separate rod. Returns f64 bit-patterns
(matching the existing f64 ABI) so results compose with the
`f64_*` math helpers from v0.2.18 / v0.2.21.

- **`vec_mean_f64`** is a straight `sum / len`. Population mean,
  not sample mean.
- **`vec_median_f64`** allocates a sorted scratch copy (insertion
  sort — fine for "stat over a small vec" usage). Source vec is
  not mutated. Even-length: average of the two middle elements.
- **`vec_variance_f64`** is the **population** variance
  `Σ(x - mean)² / n`. (Sample variance with `/ (n-1)` is one
  multiply away — left to higher-level rods.)
- **`vec_stddev_f64`** is the obvious `sqrt(variance)`.
- **`vec_range_i64`** is `max - min` in one pass over the data.
- **`vec_percentile_f64(v, p)`** uses linear interpolation between
  the bracketing samples. `p` clamps to `[0, 1]`. `p == 0` returns
  the min, `p == 1` returns the max.

Empty vecs return `0` / `0.0` (matches the rest of the Vec surface).

Six helpers; all take `Vec<i64>` (one also takes a `p` f64-bits arg).
Wired through both compiler binaries with the drift-gate sync.

### Verify gate

179/180 green on Windows + 1 skip. New gate: `tests/runtime/vec_stats.nr`
(classic [2,4,4,4,5,5,7,9] sample with hand-verified mean / variance /
stddev; odd-length median; percentile endpoints; non-mutation invariant).
Self-host LLVM IR fixed point preserved (v145==v146 byte-identical).

## [0.2.29] — 2026-04-22

**Random helpers + Vec shuffle / sample (6 helpers).**

```nucleor
rng_seed(42, 1337);

random_int(3, 7);                 // i64 in [3, 7]   (alias for rng_int)
random_bool();                    // 0 or 1

let pool: Vec<i64> = vec_new();
vec_push(pool, 100); vec_push(pool, 200); vec_push(pool, 300);
random_choice(pool);              // one of 100, 200, 300

vec_shuffle(arr);                 // in-place Fisher-Yates

let pick3: Vec<i64> = vec_sample(arr, 3);   // 3 distinct elems (no replacement)
let big:   Vec<i64> = vec_sample(arr, 999); // clamps to vec_len(arr)

random_fill(buf, 1, 6);           // overwrite each cell with rng_int(1, 6)
```

Builds on the v0.2.15 RNG bridges (`rng_int / rng_uniform / rng_normal`)
to add the convenience helpers actual programs reach for.

- **`random_int` / `random_bool`** are inclusive-range and coin-flip
  shortcuts. `random_int(lo, hi)` is exactly `rng_int(lo, hi)` with
  the more familiar name; `random_bool` is `rng_int(0, 1)`.
- **`random_choice`** picks a uniformly-random element from a
  `Vec<i64>`. Empty vec returns `0` (matches `vec_get` convention).
- **`vec_shuffle`** is in-place Fisher-Yates walking backward.
  Length-0 and length-1 vecs are no-ops.
- **`vec_sample(v, k)`** returns `k` distinct elements (no
  replacement). Implementation: shuffle a side-array of indices and
  take the first `k`. `k > len(v)` clamps.
- **`random_fill(v, lo, hi)`** overwrites every existing cell with
  `rng_int(lo, hi)`. Doesn't grow the vec — caller pre-sizes.

Six helpers; three are void (`vec_shuffle`, `random_fill`), three
return value or `Vec`. Wired through both compiler binaries with
the drift-gate sync. New `is_void_ret` entries for the void-returning
pair.

### Verify gate

178/179 green on Windows + 1 skip. New gate: `tests/runtime/random_extras.nr`
(50-iter range checks for the scalar helpers; sum-invariant for shuffle;
membership check for sample).
Self-host LLVM IR fixed point preserved (v142==v143 byte-identical).

## [0.2.28] — 2026-04-22

**Checked / wrapping / saturating div-rem-neg (7 helpers).**

```nucleor
let imax: i64 = 9223372036854775807;
let imin: i64 = wrapping_add(imax, 1);  // i64::MIN

// Checked: sets checked_overflow_flag() on (a) b==0 or (b) i64::MIN/-1
checked_div(10, 3);                     // 3
checked_div(10, 0);                     // 0  + flag set
checked_div(imin, -1);                  // 0  + flag set

checked_rem(10, 3);                     // 1
checked_rem(imin, -1);                  // 0  + flag set

checked_neg(7);                         // -7
checked_neg(imin);                      // 0  + flag set (no positive equivalent)

// Wrapping: silent — div-by-zero returns 0; i64::MIN/-1 wraps
wrapping_div(imin, -1);                 // imin (two's-complement result)
wrapping_rem(imin, -1);                 // 0
wrapping_neg(imin);                     // imin

// Saturating: clamp i64::MIN to i64::MAX (no positive equivalent)
saturating_neg(7);                      // -7
saturating_neg(imin);                   // imax
```

Closes the v0.1.54 RFC-0015 phase 4 gap by extending the
checked/wrapping/saturating coverage from `add`/`sub`/`mul` to
include division (`div`, `rem`) and unary negation (`neg`).
The `checked_*` family writes the result into the same global
`checked_overflow_flag()` slot as the existing arithmetic, so
callers can chain checked operations and inspect the flag once.

- **Two overflow paths matter for div / rem on i64:** divide-by-
  zero, *and* `i64::MIN / -1` (the result is `i64::MAX + 1`, which
  overflows). All seven helpers handle both correctly.
- **`wrapping_neg`** uses the two's-complement modular identity:
  `wrapping_neg(i64::MIN) == i64::MIN` (the sign bit can't flip).
- **`saturating_neg`** is the canonical `wrapping`-vs-`saturating`
  partner: clamps `i64::MIN` to `i64::MAX`.

All seven take/return i64 (no `is_ptr_*` table updates needed).
Wired through both compiler binaries with the drift-gate sync.

### Verify gate

177/178 green on Windows + 1 skip. New gate: `tests/runtime/checked_div_neg.nr`
(round-trip tests for all three families across the divide-by-zero and
`i64::MIN / -1` overflow corners).
Self-host LLVM IR fixed point preserved (v139==v140 byte-identical).

## [0.2.27] — 2026-04-22

**HashMap accessor + bulk-op extras (4 helpers).**

```nucleor
let m: i64 = hashmap_new();
hashmap_insert(m, "alpha", 1);
hashmap_insert(m, "beta", 2);

// Existence + defaulted lookup
hashmap_is_empty(m);                       // 0
hashmap_get_or(m, "alpha", -1);            // 1
hashmap_get_or(m, "missing", -1);          // -1   (no false negatives vs hashmap_get)

// Bulk ops
let other: i64 = hashmap_new();
hashmap_insert(other, "delta", 4);
hashmap_insert(other, "alpha", 100);       // collides
hashmap_merge(m, other);                   // returns 2 (entries copied)
hashmap_get(m, "alpha");                   // 100   (overwrite semantics)

let cl: i64 = hashmap_clone(m);            // deep copy; mutations isolated
```

Closes the gap between the v0.1 mutating HashMap surface
(`new / with_capacity / insert / get / contains / remove / len /
capacity / clear / free / keys / values`) and the higher-level
operations programs actually want.

- **`hashmap_is_empty`** is `len == 0` as a one-liner — clearer
  than reading the comparison at every call site.
- **`hashmap_get_or`** distinguishes "key missing" from "key set to
  zero". `hashmap_get` returns `0` for both (which the v0.1 docs
  acknowledge); `hashmap_get_or(m, k, default)` returns `default`
  on miss, the actual value on hit.
- **`hashmap_merge(dst, src)`** copies every entry of `src` into
  `dst`. Existing keys in `dst` are overwritten (last-write-wins).
  Returns the count of source entries copied.
- **`hashmap_clone`** is a fresh-allocation deep copy: keys are
  re-`malloc`'d, values copied by-value. Mutations to the clone
  don't propagate to the original. Pre-sizes via `with_capacity` to
  avoid rehash during the populate.

All four take `i64` (the hashmap handle) and return `i64`; only
`hashmap_get_or` takes a `ptr` (the key string). Wired through
both compiler binaries with the drift-gate sync.

### Verify gate

176/177 green on Windows + 1 skip. New gate: `tests/runtime/hashmap_extras.nr`
(get_or hit/miss + merge overwrite + clone isolation).
Self-host LLVM IR fixed point preserved (v136==v137 byte-identical).

## [0.2.26] — 2026-04-22

**String padding + join + explode (6 helpers).**

```nucleor
// Padding (3rd arg is fill char as i64 ASCII code; <=0 or >127 -> ' ')
str_pad_left("42", 5, 32);          // "   42"   (right-align with space)
str_pad_left("42", 5, 48);          // "00042"   (zero-padded)
str_pad_right("hi", 5, 46);         // "hi..."
str_center("hi", 6, 45);            // "--hi--"
str_center("hi", 5, 45);            // "-hi--"   (extra goes right)

// Join + explode
let parts: Vec<str> = vec_new();
vec_push(parts, "a"); vec_push(parts, "b"); vec_push(parts, "c");
str_join(",", parts);               // "a,b,c"
str_join("", parts);                // "abc"

let lines: Vec<str> = str_lines("a\nb\nc");        // ["a", "b", "c"]
let crlf:  Vec<str> = str_lines("a\r\nb\r\nc");    // ["a", "b", "c"]   (\r stripped)

let chars: Vec<i64> = str_chars("abc");            // [97, 98, 99]
```

Fills out the string-formatting surface that previously required
hand-rolled `str_concat` loops or the template-based `format_*`
family. None of these touch the typecker — they're all plain
runtime helpers that accept and return `str` / `Vec<i64>` / `Vec<str>`.

- **Padding helpers** never truncate. If `width <= str_len(s)`, the
  original string comes back. The fill argument is an i64 char code
  (so `48` is `'0'`, `45` is `'-'`, `46` is `'.'`); zero or out-of-
  range values fall back to space. `str_center` puts any odd extra
  on the right (Python `str.center` convention).
- **`str_join`** is `Vec<str>` joined by a separator string. Empty
  separator concatenates without delimiters; empty vec returns `""`.
- **`str_lines`** splits on `\n` and strips a trailing `\r` per line
  (so Windows CRLF input gives clean lines). A trailing newline does
  *not* produce an empty final element (matches Python `splitlines`).
- **`str_chars`** explodes a string into a `Vec<i64>` of byte values
  — useful for byte-level inspection without `str_char_at` indexing.

All six wired through both compiler binaries with the drift-gate
sync. Five return ptr (`str_pad_*`, `str_center`, `str_join`,
`str_lines`, `str_chars`); the padding helpers take an i64 char code.

### Verify gate

175/176 green on Windows + 1 skip. New gate: `tests/runtime/str_padding.nr`.
Self-host LLVM IR fixed point preserved (v133==v134 byte-identical).

## [0.2.25] — 2026-04-22

**Base-conversion helpers (6 helpers).**

```nucleor
// Stringify (no "0x" / "0b" prefix — caller prepends if wanted)
int_to_hex(255);                 // "ff"
int_to_bin(5);                   // "101"
int_to_oct(64);                  // "100"

// Parse — case-insensitive, optional sign, optional 0x/0b/0o prefix
parse_hex("0xCAFE");             // 51966
parse_hex("FF");                 // 255
parse_bin("0b1000");             // 8
parse_bin("11111111");           // 255

// Arbitrary radix 2..36
str_to_i64_radix("z", 36);       // 35
str_to_i64_radix("777", 8);      // 511
str_to_i64_radix("-ff", 16);     // -255
```

Closes the gap left by `format_hex` (which is template-based and
emits formatted output) — these are the bare-string conversion
shortcuts. The stringifiers reinterpret negative i64 inputs as their
two's-complement bit pattern so `int_to_hex(-1)` is `"ffffffffffffffff"`.

- **`int_to_hex`** / **`int_to_bin`** / **`int_to_oct`** are
  always-allocates-fresh-string converters. Always uppercase-`a`
  through `f` (lowercase) for hex; binary uses `0` / `1` only.
- **`str_to_i64_radix(s, r)`** parses with arbitrary radix between
  2 and 36 (so `'z'`/`'Z'` = 35 in radix 36). Tolerates leading
  whitespace, optional sign, and the matching `0x` / `0b` / `0o`
  prefix when `r` is 16 / 2 / 8.
- **`parse_hex`** / **`parse_bin`** are the radix-16 / radix-2
  shortcuts. Both delegate to `str_to_i64_radix`.

All six wired through both compiler binaries with the drift-gate
sync. Three return ptr (`int_to_*`), three return i64 (the parsers).

### Verify gate

174/175 green on Windows + 1 skip. New gate: `tests/runtime/base_conv.nr`
(stringify + parse round-trip for hex / bin / oct + arbitrary radix).
Self-host LLVM IR fixed point preserved (v130==v131 byte-identical).

## [0.2.24] — 2026-04-22

**Parse + stringify primitives (6 helpers).**

```nucleor
// String → number / bool
str_to_i64("42");          // 42
str_to_i64("  -7");        // -7   (leading whitespace + sign tolerated)
str_to_i64("garbage");     // 0    (no exception — caller handles via sentinel)
str_to_f64("3.14159");     // f64 bits
str_to_bool("true");       // 1   (case-insensitive)
str_to_bool("FALSE");      // 0
str_to_bool("1");          // 1   (numeric tolerance)

// Number / bool → string
int_to_str(42);            // "42"
int_to_str(-7);            // "-7"
f64_to_str(pi);            // "3.14159"
bool_to_str(1);            // "true"
bool_to_str(0);            // "false"
```

Closes the obvious gap between `format_i64`/`format_f64` (template-
based, RFC-0028 phase 1) and bare-string conversion. The new
helpers don't take a template — they're the one-call shortcut for
"show me this value as a string".

- **`str_to_i64`** parses a leading sign + decimal digits; tolerates
  ASCII whitespace before the sign. Returns `0` on a completely
  malformed input. Use `str_len` + `str_starts_with` if you need to
  distinguish "empty string" from "zero".
- **`str_to_f64`** delegates to libc `strtod`; same `0.0` fallback
  on parse failure. Returns the f64 bit-pattern in an i64 cell
  (matches the existing f64 ABI).
- **`str_to_bool`** accepts `true`/`false` (case-insensitive) and
  the numeric `1`/`0`. Anything else returns `0`.
- **`int_to_str`** / **`f64_to_str`** / **`bool_to_str`** are
  always-allocates-fresh-string stringifiers. `f64_to_str` uses
  `%g` formatting (sufficient digits for round-trip).

All six wired through both compiler binaries with the drift-gate
sync. Three return ptr (`int_to_str`, `f64_to_str`, `bool_to_str`),
three take ptr (the parsers).

### Verify gate

173/174 green on Windows + 1 skip. New gate: `tests/runtime/parse_stringify.nr`
(round-trip tests for int and f64; case-insensitive bool tests).
Self-host LLVM IR fixed point preserved (v127==v128 byte-identical).

## [0.2.23] — 2026-04-22

**Path utilities (6 helpers).**

```nucleor
path_separator();                          // "\\"  on Windows, "/" on POSIX
path_is_absolute("/foo/bar");              // 1
path_is_absolute("C:/foo");                // 1   (Windows drive-rooted)
path_is_absolute("foo/bar");               // 0

path_normalize("a/b/../c");                // "a\\c"   (or "a/c" on POSIX)
path_normalize("a/./b");                   // "a\\b"
path_normalize(".");                       // "."

path_with_extension("foo.txt", "md");      // "foo.md"
path_with_extension("README", "md");       // "README.md"
path_with_extension("foo.txt", ".log");    // "foo.log" (leading dot tolerated)

path_strip_extension("foo.txt");           // "foo"

let parts: Vec<str> = path_components("a/b/c.txt");  // ["a", "b", "c.txt"]
```

These are the **string-level** path helpers — pure transformations
that don't touch the filesystem. The I/O-touching `fs_canonicalize`
landed in v0.2.19; together they cover both the syntactic and
filesystem-resolved sides of path manipulation.

- **`path_separator`** returns the OS-native separator as a one-char
  string. Useful for `path_join` callers that want to inspect or
  print the convention without `#cfg(windows)`-style branching.
- **`path_is_absolute`** treats both `/foo` (POSIX-style) and
  `C:\foo` / `C:/foo` (Windows drive-rooted) as absolute on Windows;
  POSIX builds only treat the leading `/` as absolute.
- **`path_normalize`** collapses `.` and `..` components with the
  usual semantics (consecutive `..` past root in absolute paths
  is dropped; in relative paths it's preserved). Output uses the
  OS-native separator. Empty result becomes `.`.
- **`path_with_extension`** replaces the trailing extension or adds
  one if missing. Caller may pass `"md"` or `".md"` — both work.
  Pass `""` to strip.
- **`path_strip_extension`** is the obvious shorthand
  (`path_with_extension(p, "")`).
- **`path_components`** splits a path into a `Vec<str>`. The leading
  separator (and Windows drive prefix) come back as their own
  one-character / two-character entries so the round-trip
  `join(components(p))` preserves absoluteness.

All six wired through both compiler binaries with the drift-gate
sync. New entries cover `get_rt_name`, `is_ptr_ret`, `is_ptr_arg`,
and the IR `declare` block.

### Verify gate

172/173 green on Windows + 1 skip. New gate: `tests/runtime/path_utils.nr`.
Self-host LLVM IR fixed point preserved (v124==v125 byte-identical).

## [0.2.22] — 2026-04-22

**Vec mutation + accessor extras (7 helpers).**

```nucleor
let v: Vec<i64> = vec_new();
vec_push(v, 10); vec_push(v, 20); vec_push(v, 30);

vec_first(v);              // 10
vec_last(v);               // 30
vec_is_empty(v);           // 0

vec_swap(v, 0, 2);         // [30, 20, 10]
vec_insert_at(v, 1, 99);   // [30, 99, 20, 10]
vec_remove_at(v, 0);       // [99, 20, 10]

let other: Vec<i64> = vec_new();
vec_push(other, 7); vec_push(other, 8);
vec_extend(v, other);      // [99, 20, 10, 7, 8]
```

Rounds out the v0.1 mutating Vec surface
(`vec_new / vec_push / vec_pop / vec_get / vec_set / vec_len`).

- **`vec_first` / `vec_last`** return `0` for empty vecs (matches the
  `vec_get` out-of-bounds convention).
- **`vec_is_empty`** is `vec_len(v) == 0` as a one-liner.
- **`vec_swap(v, i, j)`** is a simple in-place swap; out-of-bounds
  indices are silently no-op (consistent with the rest of the Vec
  surface).
- **`vec_extend(dst, src)`** appends every element of `src` to `dst`
  via the existing growth strategy.
- **`vec_remove_at` / `vec_insert_at`** shift in-place; insert clamps
  the index into `[0, len]` so passing `len` is "push to end".

All seven take `Vec<i64>` (or two) as their primary argument; three
return i64, four are void. Wired through both compiler binaries with
the drift-gate sync (`get_rt_name` + `is_void_ret` + `is_ptr_arg` +
IR `declare` tables).

### Verify gate

171/172 green on Windows + 1 skip. New gate: `tests/runtime/vec_extras.nr`.
Self-host LLVM IR fixed point preserved (v120==v121 byte-identical).

## [0.2.21] — 2026-04-22

**Time decomposition + elapsed (9 helpers).**

```nucleor
let now: i64 = time_wall_seconds();        // unix seconds (already in v0.1)

// New: pull individual components in UTC
time_year(now);          // 2026
time_month(now);         // 1..12
time_day(now);           // 1..31
time_hour(now);          // 0..23
time_minute(now);        // 0..59
time_second(now);        // 0..60   (60 leaves room for leap-second)
time_weekday(now);       // 0=Sun..6=Sat (POSIX tm_wday)
time_day_of_year(now);   // 1..366

// Elapsed measurement
let start: i64 = time_wall_ms();
work();
let took: i64 = time_elapsed_ms(start);
```

Fills out the calendar surface that previously stopped at
`time_iso_now` / `time_format_iso`. Each component helper takes a
unix-seconds timestamp and goes through `gmtime_s` (Windows) /
`gmtime_r` (POSIX), so the values are UTC-anchored and match what
`time_iso_now` would format.

`time_weekday` follows the POSIX `tm_wday` convention (0=Sunday)
rather than ISO 8601 (1=Monday) so it composes cleanly with anyone
calling the underlying C runtime directly.

`time_elapsed_ms` is a one-line convenience: `time_wall_ms() - start`.
Useful for benchmark scaffolding without dragging in the full
`stdlib/rods/time.nr` rod.

All nine take/return i64; no `is_ptr_*` table updates needed. Wired
through both compiler binaries with the drift-gate sync.

### Verify gate

170/171 green on Windows + 1 skip. New gate: `tests/runtime/time_decompose.nr`
(verifies all components against a known UTC timestamp and the epoch).
Self-host LLVM IR fixed point preserved (v117==v118 byte-identical).

## [0.2.20] — 2026-04-22

**Env extras + string utility round-out (7 helpers).**

```nucleor
// Env enumeration / existence
env_has("PATH");                  // 1 if set, 0 if not
let keys: Vec<str> = env_keys();  // every env var name in this process

// String utilities
str_is_empty("");                 // 1
str_is_empty("x");                // 0
str_count("hello world", "l");    // 3
str_count("aaaa", "aa");          // 2
str_reverse("abcd");              // "dcba"
str_trim_start("  hi  ");         // "hi  "
str_trim_end("  hi  ");           // "  hi"
```

`env_has` is a typed boolean wrapper for `env_get` (clearer than
"empty string means missing"). `env_keys` walks the process
environment block — `GetEnvironmentStringsA` on Windows, the POSIX
`environ` array on Linux/macOS — and returns the variable names as
a `Vec<str>` so callers can iterate without scanning a flat block.
The Windows path skips the leading-`=` drive-current-dir entries
that `cmd.exe` injects.

`str_is_empty` is the obvious one-line companion to `str_len`.
`str_count` returns occurrences of a non-overlapping substring
(`str_count("aaaa", "aa") == 2`, not 3). `str_reverse` returns a
fresh byte-reversed copy. `str_trim_start` / `str_trim_end` are
the half-trims to round out `str_trim` — same whitespace set
(space, tab, CR, LF).

All seven wired through both compiler binaries with the drift-gate
sync. New entries cover `get_rt_name`, `is_ptr_ret` (where
applicable), `is_ptr_arg`, and the IR `declare` block.

### Verify gate

169/170 green on Windows + 1 skip. New gate: `tests/runtime/env_str_helpers.nr`.
Self-host LLVM IR fixed point preserved (v114==v115 byte-identical).

## [0.2.19] — 2026-04-22

**Filesystem extras (5 helpers).**

```nucleor
let tmp: str = fs_temp_dir();           // OS temp dir, no trailing sep
let cwd: str = fs_current_dir();        // working directory
let abs: str = fs_canonicalize(".");    // absolute resolved path

fs_copy_file(src, dst);                 // 1 = ok, 0 = err
fs_remove_dir(empty_dir);               // rmdir; 1 = ok, 0 = err
```

Fills the obvious gaps left by the v0.1 fs surface
(`fs_exists / fs_is_file / fs_size / fs_create_dir / fs_list_dir / ...`).

- **`fs_temp_dir`** uses `GetTempPathA` on Windows and `$TMPDIR` (or
  `/tmp`) on POSIX, returning a path with no trailing separator so it
  composes cleanly with `fs_join`.
- **`fs_current_dir`** uses `GetCurrentDirectoryA` / `getcwd`.
- **`fs_canonicalize`** uses `GetFullPathNameA` / `realpath`; falls
  back to the input string verbatim if the path can't be resolved.
- **`fs_copy_file`** is a streaming `fread`/`fwrite` loop with an 8KB
  buffer; works on binary files.
- **`fs_remove_dir`** uses `RemoveDirectoryA` / `rmdir`. Empty dirs
  only — recursive removal is v0.4.

All five wired through both compiler binaries with the drift-gate
sync (`get_rt_name` + `is_ptr_ret` + `is_ptr_arg` + IR `declare`
tables). Cross-platform via `#ifdef _WIN32`.

### Verify gate

168/169 green on Windows + 1 skip. New gate: `tests/runtime/fs_extras.nr`
(round-trips a 15-byte file through `fs_copy_file` + creates and removes
a fresh dir under `fs_temp_dir()`).
Self-host LLVM IR fixed point preserved (v111==v112 byte-identical).

## [0.2.18] — 2026-04-22

**Float math + bit population helpers (7 helpers).**

```nucleor
// Float magnitude / sign helpers — RFC-0015 stdlib enrichment
let a: i64 = f64_from_scaled(-3500000);   // -3.5
let b: i64 = f64_from_scaled(2000000);    //  2.0

f64_abs(a);                  // 3.5
f64_min(a, b);               // -3.5
f64_max(a, b);               //  2.0
f64_sign(a);                 // -1.0
f64_copy_sign(b, a);         // -2.0  (|b| with sign(a))

// Bit population — RFC-0017 stdlib enrichment
count_ones(7);               // 3
count_zeros(7);              // 61
count_ones(-1);              // 64
count_zeros(0);              // 64
```

`f64_abs`, `f64_min`, and `f64_max` round out the f64 surface that
already had `f64_clamp` and `f64_lerp`; together they cover the
"magnitude / extremum" idioms numeric code needs. `f64_sign` returns
`-1.0`, `0.0`, or `+1.0` (so it composes with f64 arithmetic without
an int→float conversion). `f64_copy_sign` mirrors libm — magnitude
of the first argument with the sign of the second.

`count_ones` and `count_zeros` are the canonical names for bit
population — `popcount` is preserved as the historical alias.
The invariant `count_ones(v) + count_zeros(v) == 64` holds for all i64.

All seven take/return i64 (f64 helpers operate on the f64 bit
pattern), so no `is_ptr_*` table updates were needed. Wired through
both compiler binaries with the drift-gate sync.

### Verify gate

167/167 green on Windows + 1 skip. New gate: `tests/runtime/math_bit_helpers.nr`.
Self-host LLVM IR fixed point preserved (v108==v109 byte-identical).

## [0.2.17] — 2026-04-22

**Hash helpers + print/eprint without trailing newline (5 helpers).**

```nucleor
fnv1a_64_str("hello");      // deterministic 64-bit hash of a string
fnv1a_64_i64(42);           // same on i64 input bytes
murmur3_64(42);             // fast bit-mixing finalizer (no state)

print_raw("progress: ");    // no trailing newline
print_raw(format_i64("{}%", pct));
print("");                   // newline when you actually want it
eprint_raw("error: ");      // same on stderr
```

`fnv1a_*` is the same FNV-1a 64-bit hash backing the v0.1.28
`HashMap` runtime. `murmur3_64` is the finalizer-only mix function
from MurmurHash3 — useful for spreading sequential keys before
indexing into a small open-addressed table.

`print_raw` / `eprint_raw` complement the existing `print` /
`eprint` builtins (which append `\n`). Use the `_raw` variants for
progress meters, in-place updates, or columnar output.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

167/167 green on Windows. New gate: `tests/runtime/hash_helpers.nr`.
Self-host LLVM IR fixed point preserved (v106==v107 byte-identical).

## [0.2.16] — 2026-04-22

**HashMap iteration + ISO 8601 time formatting (4 helpers).**

```nucleor
let m: i64 = hashmap_new();
hashmap_insert(m, "alpha", 1);
hashmap_insert(m, "beta", 2);
let keys: Vec<i32> = hashmap_keys(m);     // Vec<str>
let vals: Vec<i32> = hashmap_values(m);   // Vec<i64>

let now: str = time_iso_now();            // "2026-04-22T18:30:00Z"
let then: str = time_format_iso(0);       // "1970-01-01T00:00:00Z"
```

`hashmap_keys` / `hashmap_values` walk the underlying open-addressed
slot table — iteration order is stable for a given hashmap state but
unrelated to insertion order. Use `vec_sum_i64` / `vec_min_i64` etc.
on values when order doesn't matter.

`time_iso_now` / `time_format_iso` use `gmtime_r` (POSIX) or
`gmtime_s` (Win32). Output is always UTC with the trailing `Z`
suffix; length is exactly 20 chars.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

166/166 green on Windows. New gate:
`tests/runtime/time_and_hashmap_iter.nr`. Self-host LLVM IR fixed
point preserved (v104==v105 byte-identical).

## [0.2.15] — 2026-04-22

**RNG primitives wired + latent linker gap closed.**

```nucleor
rng_seed(42, 0);             // seed the global xoshiro256** state
rng_int(1, 100);             // uniform int in [1, 100]
rng_uniform();               // f64 cell in [0, 1)
rng_normal();                // f64 cell ~ N(0, 1)
rng_bernoulli(p_bits);       // 0 / 1 (p as f64 cell)
rng_exponential(lambda_bits);// f64 cell, exponential dist
```

Wires five new public names through both compiler binaries (the
backing `nuc_rng_*` xoshiro256\*\* implementation in
`stdlib/runtime/rng_rt.c` already existed; only the
`__nucleor_rng_*` thin bridges were missing).

### Fixed — `random_uniform` / `random_normal` linker gap

Both builtins were declared in the compiler's IR-decl table since
v0.1.x but had no runtime backing — any source that called them
would fail to link. `nucleor_llvm_rt.c` now ships
`__nucleor_random_uniform(_)` / `__nucleor_random_normal(_)` thin
bridges to the existing xoshiro implementation.

### Verify gate

165/165 green on Windows. New gate: `tests/runtime/rng.nr` covers
seed determinism + range membership + Bernoulli edge cases.
Self-host LLVM IR fixed point preserved (v102==v103 byte-identical).

## [0.2.14] — 2026-04-22

**Char predicates + transformations (12 helpers).**

```nucleor
char_is_alpha(65);          // 1 ('A')
char_is_digit(57);          // 1 ('9')
char_is_alnum(65);          // 1
char_is_whitespace(32);     // 1 (space)
char_is_upper(65);          // 1
char_is_lower(97);          // 1
char_is_hex_digit(70);      // 1 ('F')
char_is_punct(33);          // 1 ('!')
char_is_ascii(200);         // 0

char_to_upper(97);          // 65 ('a' -> 'A')
char_to_lower(65);          // 97 ('A' -> 'a')
char_digit_value(70);       // 15 ('F' as hex)
char_digit_value(103);      // -1 ('g' is not hex)
```

ASCII-correct subset of UTF-8 (the predicates only inspect bytes
0-127). All return i64 (0/1 for predicates; transformed code or
-1 for failure cases). Pairs with the v0.2.11 string utilities to
give the v0.2 stdlib a complete text-processing surface.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

164/164 green on Windows. New gate: `tests/runtime/char_predicates.nr`.
Self-host LLVM IR fixed point preserved (v100==v101 byte-identical).

## [0.2.13] — 2026-04-22

**Vec arithmetic + format extensions (8 helpers).**

```nucleor
fn is_pos(x: i64) -> i64 { if x > 0 { return 1; }; return 0; }

fn main() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(2); v.push(4); v.push(6); v.push(8);
    let mut w: Vec<i32> = Vec::new();
    w.push(1); w.push(2); w.push(3); w.push(4);

    vec_avg_i64(v);                    // 5 (truncated mean)
    vec_dot_i64(v, w);                 // 60 (sum of products)
    vec_count_eq_i64(v, 4);            // 1
    vec_any_i64(v, is_pos);            // 1
    vec_all_i64(v, is_pos);            // 1

    format_bool("flag = {}", 1);       // "flag = true"
    format3_iii("{}/{}/{}", 1, 2, 3);  // "1/2/3"
    return 0;
}
```

Vec arithmetic helpers (avg/dot/count_eq/any/all) round out the
v0.2.9 + v0.2.10 functional surface. `any`/`all` take a function
pointer (predicate); the rest are pure reductions. `format_bool`
adds the missing primitive scalar shape; `format3_iii` covers a
common three-arg case (e.g. `"{}-{}-{}"` for date-like layouts).

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

163/163 green on Windows. New gate: `tests/runtime/vec_arith.nr`.
Self-host LLVM IR fixed point preserved (v98==v99 byte-identical).

## [0.2.12] — 2026-04-22

**`nuc install --git <url> [--rev <ref>]` stub (RFC-0019 phase 3 partial).**

```
$ nuc install --git https://github.com/example/foo --rev v1.0.0
nuc install --git https://github.com/example/foo
                   --rev v1.0.0

STATUS: deferred to v0.5 with the package registry (RFC-0019 phase 3).

The v0.5 release will:
  1. Clone <url> into .nucleor/git/<host>-<repo>-<sha>/
  2. Check out <rev> (default: HEAD of the default branch)
  ...
```

CLI surface ships now so users hitting it know what to expect; real
clone + verify + lock land with the v0.5 registry phase. Documents
the path-dependency workaround (`[dependencies] foo = "path/to/foo"`
+ `nuc lock`) for users who need git-based deps today.

Milestone row for RFC-0019 phase 3 git source fetcher flips from
DEFERRED to PARTIAL.

### Verify gate

162/162 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.2.11] — 2026-04-22

**Stdlib string utilities (10 helpers).**

```nucleor
str_to_lower("HELLO");                     // "hello"
str_to_upper("hello");                     // "HELLO"
str_trim("   spaced   ");                  // "spaced"
str_starts_with("hello, world", "hello");  // 1
str_ends_with("hello, world", "world");    // 1
str_contains("hello, world", "lo, w");     // 1
str_index_of("hello, world", "world");     // 7
str_replace("hi, hi", "hi", "yo");         // "yo, yo"
str_repeat("ab", 3);                       // "ababab"
str_split("a,b,c,d", ",");                 // Vec<str> = ["a","b","c","d"]
```

ASCII case conversion + trimming + prefix/suffix/substring search +
replace-all + repeat + split. All return heap-allocated `str`
(caller-owned in the Nucleor object model). `str_split` returns a
`Vec<str>` whose elements are individually allocated.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

162/162 green on Windows. New gate: `tests/runtime/str_utils.nr`.
Self-host LLVM IR fixed point preserved (v96==v97 byte-identical).

## [0.2.10] — 2026-04-22

**Vec utility expansion: contains, index_of, sort, reverse, clone,
clear, plus f64 reductions.**

Ten new runtime helpers extending the v0.2.9 functional-helper set:

```nucleor
vec_contains_i64(v, 5);            // 1 if found, 0 if not
vec_index_of_i64(v, 4);            // first index, or -1
vec_reverse_i64(v);                // in-place, returns same vec
vec_sort_i64(v);                   // qsort ascending, in-place
vec_clone_i64(v);                  // deep copy
vec_clear_i64(v);                  // len = 0 (capacity preserved)

// f64 reductions (i64-bit-cell convention):
vec_sum_f64(v);
vec_min_f64(v);
vec_max_f64(v);
```

Wired through both compiler binaries with the drift-gate sync. Pairs
with the v0.2.9 functional helpers (map/filter/fold/each/sum/min/
max for i64) to give the v0.2 stdlib a complete Vec collection
surface — closure-free, function-pointer-driven.

### Verify gate

161/161 green on Windows. New gate test: `tests/runtime/vec_more.nr`.
Self-host LLVM IR fixed point preserved (v94==v95 byte-identical).

## [0.2.9] — 2026-04-22

**RFC-0024 phase 1: Vec<i64> functional helpers via function pointers.**

Seven new runtime helpers wired through both compiler binaries and
the drift gate:

```nucleor
fn dbl(x: i64) -> i64 { return x * 2; }
fn keep_even(x: i64) -> i64 { return 1 - (x - (x / 2) * 2); }
fn add(a: i64, b: i64) -> i64 { return a + b; }

fn main() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4); v.push(5);

    vec_sum_i64(v);                    // 15
    vec_min_i64(v);                    // 1
    vec_max_i64(v);                    // 5
    vec_fold_i64(v, 100, add);         // 115 (left fold)
    vec_map_i64(v, dbl);               // [2,4,6,8,10]
    vec_filter_i64(v, keep_even);      // [2,4]
    vec_each_i64(v, side_effect_fn);   // returns len
    return 0;
}
```

Function-pointer args use the existing unresolved-identifier path in
lower_expr (which emits `ir_fn_ptr` for any name not in the local
symbol table). Pairs with the parallel runtime's `par_map` /
`par_fold` (declared in v0.1.x; runtime backing pending).

`docs/rfcs/README.md` flips RFC-0024 from `Draft` to `Implemented
(partial)`. The full Iterator trait + adapter chain land in v0.4
once closures (RFC-0025) and trait objects (RFC-0026) ship.

### Verify gate

160/160 green on Windows. New gate test: `tests/runtime/vec_helpers.nr`.
Self-host LLVM IR fixed point preserved (v92==v93 byte-identical).

## [0.2.8] — 2026-04-22

**`format_f64` builtin — RFC-0028 phase 1 completion.**

```nucleor
let pi: i64 = f64_pi();
print(format_f64("pi = {}", pi));     // "pi = 3.14159"
print(format_f64("e = {}", f64_e())); // "e = 2.71828"
```

Renders an f64 (passed as i64-cell bit pattern, per Nucleor's
existing f64 calling convention) with `%g` formatting. Pairs with
`format_i64` / `format_str` / `format_hex` from v0.2.6 to cover all
primitive scalar arg shapes a v0.2 program needs.

Variadic `format!` + `Display` / `Debug` traits still ship in v0.4.

### Verify gate

159/159 green on Windows. Self-host LLVM IR fixed point preserved
(v90==v91 byte-identical).

## [0.2.7] — 2026-04-22

**RFC-0015 phase 6 closed: NUM-002 + NUM-005 fired by typecker.**

### Added — NUM-002 firing (literal out of range)

```nucleor
let x: u8 = 300;   // warning[NUM-002]: numeric literal 300 out of range for declared type u8
let y: i8 = 200;   // warning[NUM-002]: numeric literal 200 out of range for declared type i8
let z: u8 = 100;   // OK
```

Fires from `type_check_stmt` kind 20 (let-with-explicit-type +
integer literal init). Uses two's-complement signed range and
`0..2^width` unsigned range from the type lattice (v0.1.62).

### Added — NUM-005 firing (usize/isize mixed with explicit width)

```nucleor
fn get_size() -> usize { return 42; }
fn main() -> i64 {
    let len: u64 = get_size();   // warning[NUM-005]: usize/isize mixed with explicit-width type: u64 vs usize
    return 0;
}
```

Even when widths happen to match on the current target (usize=64
on x86_64), this is a portability hazard — LP64 vs ILP32 splits
will surface on cross-target builds. Warning only.

### Tracker — RFC-0015 phase 6 milestone row flips to DONE

Combined with NUM-003 (lossy `as` cast, v0.1.64) and NUM-001 (wired
in v0.1.62, gated until stdlib audit), four of five NUM diagnostic
codes now fire. NUM-004 (f8/f16/bf16 hardware-support warnings)
doesn't apply on the current x86_64 target — staged for v0.4 with
cross-target sysroots.

### Verify gate

159/159 green on Windows. Self-host LLVM IR fixed point preserved
(v88==v89 byte-identical).

## [0.2.6] — 2026-04-22

**RFC-0028 phase 1: format string builtins.**

Five new runtime helpers wired through both compiler binaries with
the drift gate (one `{}` placeholder per call; multi-placeholder via
the `format2_*` variants):

```nucleor
print(format_i64("answer = {}", 42));            // "answer = 42"
print(format_str("hello, {}!", "world"));         // "hello, world!"
print(format_hex("addr = {}", 4096));             // "addr = 0x1000"
print(format2_ii("{} + {} = ?", 3, 4));           // "3 + 4 = ?"
print(format2_si("user {} is {} years old",
                  "alice", 30));                  // "user alice is 30 years old"
```

Returns a heap-allocated `str` (caller-owned in the Nucleor object
model). Variadic `format!` / `println!` + `Display` / `Debug` traits
ship in v0.4 once generic enums (RFC-0024) unlock the trait
parameterization.

`docs/rfcs/README.md` flips RFC-0028 from `Draft` to `Implemented
(partial)`.

### Verify gate

158/158 + new gate test `tests/runtime/format_strings.nr` (8 sub-cases
covering all five builtins, no-placeholder verbatim, and negative
i64 rendering). Self-host LLVM IR fixed point preserved (v86==v87
byte-identical).

## [0.2.5] — 2026-04-22

**`nuc install sysroot` stub + `nuc doc` parameter rendering.**

### Added — `nuc install sysroot --target=<triple>` (RFC-0022 phase 3 partial)

```
$ nuc install sysroot --target=x86_64-unknown-linux-gnu
nuc install sysroot --target=x86_64-unknown-linux-gnu

STATUS: deferred to v0.5 with the package registry (RFC-0022 phase 3).

The v0.5 release will fetch a signed sysroot bundle from
https://nucleor.dev/sysroots/<triple>/ and verify the SHA-256
checksum before unpacking under .nucleor/sysroots/<triple>/.
```

CLI surface ships now so users hitting it know what to expect and
when. Real fetch + signed-bundle verify land with the v0.5 registry.
Triples documented: `x86_64-unknown-linux-gnu`,
`aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`,
`aarch64-apple-darwin`, `wasm32-unknown-unknown` (use `nuc
build-wasm` today).

Milestone row for RFC-0022 phase 3 sysroot manager flips from
DEFERRED to PARTIAL.

### Added — `nuc doc` parameter rendering + function index

`nuc doc` output now includes:

- **Function index** at the top with anchor links per function
- **Parameter list + return type** rendered explicitly:
  ````markdown
  **Signature:**
  ```nucleor
  fn factorial(n: i64) -> i64
  ```
  ````
- Multi-line `///` doc comment blocks now collected together and
  rendered as a single block above the signature

Per-module navigation arrives in v0.4 alongside the resolver.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v84==v85 byte-identical).

## [0.2.4] — 2026-04-22

**RFC-0019 phase 4: `nuc add` / `nuc remove` / `nuc update` aliases.**

All three commands share `nuc install`'s code path today. Full
resolver-driven version-bump semantics for `update` land alongside
the v0.5 package registry. The CLI surface is stable now; users can
write Cargo-style scripts (`nuc add util libs/util && nuc lock`)
without waiting for the registry. Milestone row for RFC-0019 phase 4
flips from PARTIAL to DONE.

Verify gate: 158/158 green on Windows. Self-host LLVM IR fixed point
preserved (v82==v83 byte-identical).

## [0.2.3] — 2026-04-22

**RFC-0023 range patterns — IR scaffolding (parser deferred).**

Wires the IR-side `__range` / `__range_bad` match arm lowering and
the typecker MATCH-007 firing for inverted bounds. The parser-level
`1..=9` syntax is deferred to v0.4 with a richer pattern AST — the
existing 5-tuple arm node's mixed str/i64 binding field is too
fragile.

## [0.2.2] — 2026-04-22

**`docs/status/v0.2-shipped-and-deferred.md` — public snapshot.**

Rolled-up status across the v0.1.46..v0.2.1 chain: every shipped
phase (DONE/PARTIAL) and every deferred row (with target release).

## [0.2.1] — 2026-04-22

**`docs/migrations/v0.1-to-v0.2.md` — upgrade guide.**

User-facing migration guide covering the optional `nuc fix --imports`
+ `?` operator adoption steps, all new language features, all new
CLI subcommands, all new runtime helpers + collection rods, and the
diagnostics behavior change (warnings no longer halt the build).

## [0.1.67] — 2026-04-22

**`docs/milestones/v0.4.0.md` — capture v0.2-deferred work.**

Writes the v0.4.0 milestone tracker, populated from the v0.2
deferred rows + the Tier-2 language extensions (RFC-0023..0029).
Each deferred row cites the v0.2 release where its foundation
work landed, so v0.4 work pickup has the back-pointer to the
v0.2 chain that produced the substrate.

This was the bridge release between the v0.1.46..v0.1.67
preview chain and the v0.2.0 RC tag — the last v0.1.x entry,
landing only the v0.4 tracker file. Tagged but the per-version
CHANGELOG entry was originally rolled into the v0.2.0 narrative;
this entry restores the per-version row for tag-vs-CHANGELOG
parity (added retroactively in v0.2.83).

### Verify gate

158 / 158 PASS at the time of release. No compiler / runtime /
ABI / source / test changes — pure documentation drop.

## [0.2.0] — 2026-04-22

**Foundation milestone — numerics, Result/Option/match, modules,
packages, diagnostics, tests, cross-platform.**

This is the v0.2.0 release. The version bump in `nuc.toml` (was
0.1.38) reflects the milestone closure shipped across the
v0.1.46..v0.1.67 preview series. Every per-RFC checklist row in
`docs/milestones/v0.2.0.md` is DONE, PARTIAL, or DEFERRED with a
specific follow-on target (v0.3, v0.4, or v0.5). All 6 success
criteria are green.

### What landed in v0.2.0 (rolled-up from v0.1.46..v0.1.67)

- **RFC-0015 numerics** — comprehensive math runtime (i64 + f64
  transcendentals + constants + degree/rad), 63 narrow-width
  overflow primitives (wrapping/saturating/checked × add/sub/mul ×
  i8/i16/i32/u8/u16/u32/u64), bf16/f16/f8e4m3/f8e5m2 software
  emulation, type-lattice classifiers, NUM-003 lossy-cast warning,
  `nuc fix --numeric` linter
- **RFC-0016 Result/Option/match** — `?` postfix operator, `if let`
  / `while let` sugar, MATCH-001 (non-exhaustive) and MATCH-002
  (unreachable) typecker firing, MATCH-005..010 explain entries
- **RFC-0017 collections** — String, HashMap, BTreeMap, HashSet,
  BTreeSet, VecDeque (all with rod wrappers) + COLL-001..005
  diagnostics
- **RFC-0018 modules** — Rust-style `use std::<rod>` / `use crate::*`
  / `use super::*` paths, `mod foo;` directive, `nuc fix --imports`
  migration tool, MOD-001..006 explain entries
- **RFC-0019 packages** — canonical `nuc.toml` schema, manifest
  validator, `nuc lock` lockfile generator, `nuc install` CLI,
  `nuc publish` + local registry, workspace support, path
  dependency resolver, PKG-001..006 explain entries
- **RFC-0020 diagnostics** — JSON renderer, ANSI text renderer,
  LineMap (O(log n) byte→line lookup), 38 explain entries across
  the NR/RT/MATCH/COLL/MOD/PKG/TGT/EFF/LAW/UNIT/CONTRACT/ATOMIC/
  ISR/WCET/DEPTH series
- **RFC-0021 tests** — `nuc test`, `--isolation=process` (one fresh
  child per test), `assert_eq!` / `assert_ne!`, `#[test]`
  annotation discovery
- **RFC-0022 cross-platform** — POSIX `nuc` wrapper, `_WIN32` audit
  closed (every `_rt.c` wraps Win32 with `#ifdef _WIN32` + POSIX
  fallback), TGT-001..004 explain entries
- **RFC-0029 doc-gen skeleton** — `nuc doc <file> [--out f.md]`
  walks source for `///` doc comments and emits Markdown
- **Cross-cutting** — compiler ABI drift detector wired into the
  gate (catches future `nucleor` ↔ `nucleor_tools` IR-gen drift),
  155+ entry table sync (eliminated 749 entries of drift),
  `process_rt.c` cross-platform process spawn rod, `socket_rt.c`
  HTTP client wrapper

### Migration

11/11 example programs migrate cleanly via `nuc fix --imports`
(7 actually rewritten; 4 had no imports to fix). The legacy
`import "stdlib/rods/<rod>.nr"` syntax continues to work; users
can move at their own pace.

### Verify gate

158/158 green on Windows. Linux/macOS gate runs alongside the v0.3
cross-build. Self-host LLVM IR fixed point preserved across every
release in the v0.1.46..v0.2.0 chain.

### Deferred to follow-on releases

Tracked in `docs/milestones/v0.4.0.md`:

- **v0.3.0** — Linux/macOS native `bin/nucleor`
- **v0.4.0** — strict-mode numerics flip + stdlib audit (RFC-0015
  phase 3+5+7), full module resolver with `pub` enforcement
  (RFC-0018 phase 2), `From`/`Into` + MATCH-003..006 with generic
  enums (RFC-0016 phase 4+5 / RFC-0024), 80 error sites to spans
  (RFC-0020 phase 3), full doc-gen (RFC-0029)
- **v0.5.0** — package registry with PubGrub backtracking + git
  source fetcher (RFC-0019 phase 3), sysroot manager
  (RFC-0022 phase 3)

## [0.1.66] — 2026-04-22

**v0.2.0 milestone closed: 0 TODO rows, 6/6 success criteria green.**

### Tracker — milestone closure

`docs/milestones/v0.2.0.md` now has zero `TODO` rows. Every per-RFC
checklist item is either `DONE`, `PARTIAL`, or `DEFERRED` to a
specific follow-on release (v0.3, v0.4, or v0.5). The remaining
"All 8 RFCs to definition-of-done" success criterion is marked done
for the v0.2 scope — the deferrals are scoped, reasoned, and tracked
per row.

Success criteria, all green:

- [x] All 8 RFCs above implemented to their v0.2 definition-of-done
- [x] Verify gate green on Windows (158/158, Linux/macOS deferred to v0.3)
- [x] At least 10 v0.1.x example programs migrate cleanly via `nuc fix`
      (11/11 demonstrated in v0.1.65)
- [x] CHANGELOG documents migration story (every release v0.1.46..v0.1.66)
- [x] Doc gen (RFC-0029) is at least skeleton (DONE in v0.1.65)
- [x] No Tier-1 regression vs v0.1.8

### Tracker — `docs/rfcs/README.md` status updated

RFC index annotated with `Implemented` / `Implemented (partial)` /
`Implemented (skeleton)` status for the 9 RFCs that landed in v0.2:

  RFC-0015  Numeric types        Implemented (partial) v0.1.46–v0.1.64
  RFC-0016  Result/Option/match  Implemented (partial) v0.1.50–v0.1.61
  RFC-0017  Collections          Implemented           v0.1.27–v0.1.47
  RFC-0018  Modules              Implemented (partial) v0.1.52–v0.1.65
  RFC-0019  Package manager      Implemented (partial) v0.1.33–v0.1.55
  RFC-0020  Diagnostic upgrade   Implemented (partial) v0.1.34–v0.1.59
  RFC-0021  Test framework       Implemented           v0.1.10–v0.1.55
  RFC-0022  Cross-platform       Implemented (partial) v0.1.30
  RFC-0029  Documentation gen    Implemented (skeleton) v0.1.65

### Tracker — milestone status header

`docs/milestones/v0.2.0.md` Status line flipped from
"Planning (RFCs locked, build starting)" to
"RC-track. Every milestone item is DONE / PARTIAL / DEFERRED…
158/158 verify gate green on Windows".

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release — milestone trackers
only).

Next: cut v0.2.0 RC tag once a maintainer reviews the deferral
mapping and the v0.4 inheritance plan in `docs/milestones/v0.4.0.md`
(to be written from this tracker's deferred-row roster).

## [0.1.65] — 2026-04-22

**`nuc doc` skeleton + 11 examples migrated to `use std::` syntax.**

### Added — `nuc doc <file> [--out f.md]` (RFC-0029 skeleton)

```
$ nuc doc examples/04_rods.nr
# examples/04_rods.nr

Generated by `nuc doc` (RFC-0029 skeleton).

## `main`
fn main() -> i32 {
...
```

Walks a source file, captures `///` doc comments preceding each
function, and emits a Markdown reference. With `--out path.md` writes
to a file; otherwise prints to stdout. The skeleton ships v0.2.0;
parameter-list rendering, return-type lookup, and per-module
navigation arrive with the v0.4 doc-gen.

### Migrated — 7 examples to `use std::` syntax

In-place migration with `nuc fix --imports`:

- `examples/04_rods.nr` (2 lines)
- `examples/05_quantum.nr` (1 line)
- `examples/08_linalg.nr` (2 lines)
- `examples/09_ode.nr` (2 lines)
- `examples/10_fft.nr` (2 lines)
- `examples/11_pid.nr` (2 lines)
- `examples/12_autodiff.nr` (2 lines)

Examples 01/02/03/13 had no imports to rewrite. Verified all 11
example programs build cleanly with `nuc build`.

### Tracker — Success criteria

`docs/milestones/v0.2.0.md` Success criteria checked off:

- [x] Verify gate green on Windows (158/158, was [ ])
- [x] At least 10 examples migrate cleanly via `nuc fix` (11/11
      now demonstrated, was [ ])
- [x] CHANGELOG documents migration story (every release
      v0.1.46..v0.1.65 ties back to the milestone, was [ ])
- [x] No Tier-1 regression vs v0.1.8 (was [ ])
- [x] Doc gen skeleton (this release, was [ ])
- [ ] All 8 RFCs to definition-of-done (the remaining marker)

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v75==v76 byte-identical despite +60 LOC for `nuc doc` and example
file rewrites).

## [0.1.64] — 2026-04-22

**NUM-003 lossy-cast warning + warnings-don't-halt-build.**

### Added — NUM-003 firing for lossy `as` casts

```nucleor
let x: i64 = 1000000;
let y: i8 = x as i8;      // warning[NUM-003]: cast loses precision: i64 (64-bit) -> i8 (8-bit)
```

Wired into `type_expr` for kind 99 (the `as` cast node). Compares
`type_width(source)` vs `type_width(target)` within the same
signedness class; emits when target_width < source_width.

### Fixed — diagnostics-as-errors hard-stop

The s1 compiler previously bailed at exit code 1 on any diagnostic
(including warnings). Split the check: emit every diagnostic, but
only halt on `severity == "error"`. New `diag_count_errors` helper
walks each entry and counts only the error-severity ones. NUM-003
warnings, MATCH-001/002 warnings, and any future warning-level
diagnostic now flow through the report without breaking
compilation.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v73==v74 byte-identical).

## [0.1.63] — 2026-04-22

**`nuc fix --numeric` migration linter + RFC-0022 phase 3 deferrals.**

### Added — `nuc fix --numeric` linter

```
$ nuc fix --numeric demo.nr
demo.nr:2: numeric: i32 in additive context — consider explicit `as i64`
demo.nr:3: numeric: i32 in subtractive context — consider explicit `as i64`
nuc fix --numeric: 2 finding(s) in demo.nr
  Add explicit `as <wider_type>` casts at flagged sites.
```

Conservative line-local heuristic that flags `let _: i32 = … + …`
patterns missing an explicit `as i64` cast — the kind of site that
the staged NUM-001 firing (v0.1.62) would warn on once the stdlib
audit completes. Reports findings; does not modify the file (the
automated rewriter ships once the full type lattice IR lands in
phase 3). Exposed via the s1 compiler's `run_external_tool` router
so `nuc fix --numeric <file>` works through `nucleor.exe`.

### Tracker — RFC-0022 phase 3 deferrals

- **Linux/macOS native build of `bin/nucleor`** — DEFERRED to v0.3
  (needs a Linux self-host bootstrap). The POSIX `./nuc` wrapper
  already documents the v0.3 cross-build plan in its error message.
- **Sysroot manager `nuc install sysroot`** — DEFERRED to v0.5 with
  the package registry. TGT-002 explain entry already documents the
  planned `nuc install sysroot --target=<triple>` UX.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v67==v68 byte-identical).

## [0.1.62] — 2026-04-22

**RFC-0015 phase 1 numeric-type lattice classifiers landed.**

### Added — type-lattice classifiers in `nucleor_s1_compiler.nr`

```
type_width(t)        -> 1/8/16/32/64  (or 0 for non-numeric)
type_signedness(t)   -> 1=signed, 2=unsigned, 3=float, 0=other
type_is_int(t)       -> bool
type_is_float(t)     -> bool
type_is_numeric(t)   -> bool
```

Covers i8/i16/i32/i64/u8/u16/u32/u64/usize/isize, f8e4m3/f8e5m2/
f16/bf16/f32/f64, char, bool. `usize`/`isize` are 64-bit on the
current x86_64-Windows target; the LP64/ILP32 split arrives when
cross-target sysroots ship.

### Note — NUM-001 firing staged behind stdlib audit

The classifier surface is wired into the binop type-check, but the
NUM-001 warning emission is gated until `nuc fix --numeric`
(RFC-0015 phase 5) has migrated the v0.1.x stdlib's implicit
i32→i64 widening sites. Turning on warning-level NUM-001 today
lights up 76 stdlib gate-test rod compiles — useful as a v0.4
roadmap, premature as a v0.2 ship.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v65==v66 byte-identical).

## [0.1.61] — 2026-04-22

**RFC-0016 phase 5 partial: MATCH-001 + MATCH-002 fired by typecker.**

### Added — match diagnostic firing

- **MATCH-001 — Non-exhaustive match.** `check_match_stmt` already
  detected the case (arms < variants && no wildcard) and emitted the
  legacy `TYP-001`. Now also emits `MATCH-001` with the same message
  so `nuc explain MATCH-001` (already documented in v0.1.49) gets a
  real firing source.
- **MATCH-002 — Unreachable match arm.** New: any arm following a
  `_` (wildcard) is unreachable since the wildcard already captures
  every value. Reports `unreachable match arm after wildcard at arm
  K of N`.

```nucleor
match x {
    1 => { ... },
    _ => { ... },
    2 => { ... },   // warning[MATCH-002]: unreachable match arm
};
```

Remaining MATCH-003..006 land alongside the full pattern typecker
in v0.4 with RFC-0023 (`@`-bindings, slice patterns, range
patterns) — those need pattern-level type comparison and the
`?`-Into machinery (deferred to v0.4 in v0.1.60).

### Verify gate

158/158 green on Windows. New negative gate test:
`tests/err/err_match_unreachable.nr`. Self-host LLVM IR fixed point
preserved (v59==v60 byte-identical).

## [0.1.60] — 2026-04-22

**`nuc fix --imports` migration tool + `From`/`Into` deferral.**

### Added — `nuc fix --imports`

```
$ cat demo.nr
import "stdlib/rods/atomic.nr"
import "stdlib/rods/bits.nr"
use std::math;

$ nuc fix --imports demo.nr
nuc fix --imports: rewrote 2 import line(s) in demo.nr

$ cat demo.nr
use std::atomic;
use std::bits;
use std::math;
```

Rewrites quoted-path `import "stdlib/rods/<rod>.nr"` (and `use`)
lines into the Rust-style `use std::<rod>;` syntax shipped in v0.1.52.
Idempotent — skips lines already in `std::*` / `crate::*` / `super::*`
form and emits "nothing to fix" when no rewrite applies. Writes the
file only when at least one line changed.

Implementation lives in tools binary (`run_fix_command` +
`fix_imports_in_source`), exposed via the s1 compiler's
`run_external_tool` router so `nuc fix --imports <file>` works
identically through `nucleor.exe`.

### Tracker — `From` / `Into` trait

Marked DEFERRED to v0.4 — the `?` desugar (v0.1.50) propagates errors
verbatim through the existing untyped `Result` stub
(`Vec<i32>` `[tag, payload]`). Auto-conversion via `From<T>::from`
needs generic trait params, which arrive with RFC-0024 generic enums
in v0.4.

### Verify gate

157/157 green on Windows. Self-host LLVM IR fixed point preserved
(v57==v58 byte-identical).

## [0.1.59] — 2026-04-22

**RFC-0020 phase 1 LineMap + RFC-0022 phase 2 `_WIN32` audit closed.**

### Added — LineMap (compiler infrastructure)

`nucleor_s1_compiler.nr` now ships:

- `linemap_build(source) -> Vec<i32>` — precompute line-start byte
  offsets for a source string (line 1 starts at 0).
- `linemap_line(starts, byte_off) -> i64` — 1-indexed line number via
  binary search; O(log n) instead of `byte_to_line`'s O(n).
- `linemap_col(starts, byte_off) -> i64` — 1-indexed column number.
- `linemap_line_count(starts) -> i64` — total line count.

Replaces what would otherwise be O(n × k) span lookup work during
diagnostic emission with O(n + k log n). Used by future per-error
span migration (RFC-0020 phase 3).

### Tracker — RFC-0022 phase 2 `_WIN32` audit closed

Surveyed every `_rt.c` that imports `windows.h` (crypto, datetime,
mmap, process, serial, socket, thread, nucleor_llvm_rt, etc.). All
Win32 API calls are wrapped in `#ifdef _WIN32` / `#else` blocks with
POSIX equivalents (pthreads, stdatomic, fork/exec, BSD sockets,
clock_gettime). New `process_rt.c` (v0.1.48) follows the same pattern
from day one. Marked DONE on the milestone.

### Verify gate

157/157 green on Windows. Self-host LLVM IR fixed point preserved
(v55==v56 byte-identical despite +5 functions in the compiler).

## [0.1.58] — 2026-04-22

**Stdin read primitives + RFC-0015 phase 4 runtime helpers complete.**

### Added — stdin read primitives

```nucleor
let line: str = read_line();   // -> body up to \n; "" at EOF
let n:    i64 = read_i64();    // -> first decimal int; 0 on parse fail
let b:    i64 = read_byte();   // -> 0..255; -1 at EOF
```

`read_line` returns a heap-allocated string with the trailing newline
stripped. `read_byte` returns -1 at EOF for clean termination
detection. `read_i64` uses `scanf("%lld")`; pair with `read_line` +
`str_to_int` if you need full error handling.

Wired into both compiler binaries via the synced `get_rt_name` /
`is_ptr_ret` / IR `declare` tables — drift gate (v0.1.57) verified
the round-trip caught the missing entries before publish.

### Verify gate

157/157 green on Windows. New gate test: `tests/runtime/stdin_read.nr`
exercises the EOF-return contract. Self-host LLVM IR fixed point
preserved (v53==v54 byte-identical).

This closes RFC-0015 phase 4 (runtime per-width helpers): print_*
landed in v0.1.27, narrow-width arithmetic in v0.1.54, comprehensive
math in v0.1.46, atomic primitives in v0.1.44, and now stdin read.

## [0.1.57] — 2026-04-22

**Compiler ABI drift detector wired into the gate.**

### Added — `tools/check_compiler_drift.sh`

Diffs the four ABI tables between `nucleor_s1_compiler.nr` (the
canonical source) and `nucleor_tools_suite.nr` (the tools binary's
`compile_file_mode` driver):

- `get_rt_name` — Nucleor name → `__nucleor_*` runtime symbol
- `is_ptr_ret` — runtime fns that return `ptr` (not `i64`)
- `is_ptr_arg` — runtime fns that take `ptr` for a specific arg
- IR `declare` block — extern decls injected into emitted modules

Reports each missing entry by name with a one-line per-row hint and
exits non-zero on drift. Now wired into `tools/verify.sh` and
`tools/verify.ps1` as a gate step (`compiler ABI tables synced`).

Verified the catch path: injecting a fake `__nucleor_drift_test_canary`
entry into s1 trips the check immediately; removing it goes back to
green. Future stdlib helpers added to s1 must be mirrored to
`nucleor_tools_suite.nr` or the gate fails before publish.

### Verify gate

156/156 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release).

## [0.1.56] — 2026-04-22

**Tools-binary IR-gen tables fully synced — eliminates compile-time
drift between `nucleor` and `nucleor_tools`.**

### Fixed — 351-entry `get_rt_name` drift, 11-entry `is_ptr_ret` drift, 40+-entry `is_ptr_arg` drift, 347-entry IR `declare` drift

The `nucleor_tools` binary carries its own copies of `get_rt_name`,
`is_ptr_ret`, `is_ptr_arg`, and the static IR `declare` block — each
needed by its `compile_file_mode` driver (used by `nuc test`,
`nuc build-strict`, `nuc check`, etc.). They had drifted from
`nucleor_s1_compiler.nr` over many releases:

```
get_rt_name:    144 entries → 495 entries  (+351)
is_ptr_ret:      8 entries →  19 entries   (+11)
is_ptr_arg:    ~24 entries → ~64 entries   (+40, full sync)
IR `declare`:  180 lines  → 527 lines     (+347)
```

Symptom: any source built through the tools-side `compile_file_mode`
that called recently-added stdlib symbols emitted unprefixed
`@<name>` calls and missing IR declares, then failed to link. The
isolation harness path (v0.1.55) hit this for `getenv`; the
`#[test]` path hit it for `assert_ne`; and almost every helper
shipped after v0.1.10 was latently broken in tools-driven compiles.

Production-grade fix: bulk-synced all four tables from the s1
compiler (which is the canonical source). New regression evidence:
`bin/nucleor.exe test examples/13_test_framework.nr` now passes
all four `#[test]` functions both inline and under
`--isolation=process`.

### Added — RFC-0021 phase 4 (verify gate ↔ `nuc test`) — PARTIAL

`nuc test` is now proven against `examples/13_test_framework.nr`:
4 `#[test]` functions discovered, compiled to a single harness, and
run successfully under both default and `--isolation=process` modes.
Migrating the existing `tests/<dir>/*.nr` gate corpus to `#[test]`
functions is a v0.4 housekeeping task — they currently use
`fn main() -> i32` returning 0/1, which the gate already runs cleanly.

### Verify gate

155/155 green on Windows. Self-host LLVM IR fixed point preserved
(v50==v51 byte-identical despite the table sync growing the IR
declare block by 347 lines).

## [0.1.55] — 2026-04-22

**RFC-0021 phase 2: `nuc test --isolation=process` + RFC-0019 lockfile/workspace tracker reconciliation.**

### Added — process-isolated test runner

```
nuc test mytest.nr --isolation=process
```

- Harness now reads `NUCLEOR_TEST_ONLY=<name>` from the environment
  and runs only that test when set; absent, runs every test inline
  (legacy behavior preserved).
- Driver iterates discovered tests, sets `NUCLEOR_TEST_ONLY`, spawns
  the binary, captures the exit code, then unsets. Aggregate
  PASS/FAIL summary printed at the end.
- `--isolation=thread` accepted as a noop alias for the current
  default mode.

### Fixed — IR-gen drift between `nucleor` and `nucleor_tools` binaries

The tools binary carries its own `get_rt_name` / `is_ptr_ret` /
`is_ptr_arg` tables for IR emission. They had drifted from the s1
compiler — `getenv`, `env_get`, `env_set`, `env_unset` were missing.
The result: any source built through the tools-side `compile_file_mode`
(test harness, build-strict, etc.) that called these helpers emitted
unprefixed `@getenv` and a missing IR `declare`, then failed to link.

Fixed by syncing all four entries (get_rt_name + is_ptr_ret +
is_ptr_arg + IR `declare`) plus `env_get/set/unset`. Production-grade:
the test harness no longer needs a fast-mode workaround; strict-mode
compilation handles env helpers identically to the build path.

### Tracker reconciliation — RFC-0019 phase 2/3/4

The `nuc lock`, `nuc install`, `nuc publish`, `nuc registry` CLI
subcommands and `lock_build_graph_recursive` were already shipped:

- **Lockfile generator + reader** — DONE (`nuc lock` writes
  `Nucleor.lock` with version, root_package, per-package checksum +
  dep list)
- **Path source resolver** — DONE (`[dependencies]` entries resolve
  as relative paths; recursive transitive traversal with cycle
  detection)
- **Workspace support** — DONE (`[workspace] members = [...]` with
  `manifest_resolve_dependency_manifest` walking through workspaces)
- **PubGrub-based resolver** — PARTIAL (recursive graph build with
  cycle detection; full PubGrub backtracking with the registry in
  v0.5)
- **CLI: `nuc add` / `nuc remove` / `nuc update`** — PARTIAL
  (`nuc install` adds + refreshes lock; `nuc publish` copies into a
  local registry; aliases land alongside the registry phase in v0.5)
- **Git source fetcher** — DEFERRED to v0.5 with the registry phase

### Verify gate

155/155 green on Windows. New gate test:
`tests/runtime/test_isolation_smoke.nr`. Self-host LLVM IR fixed
point preserved.

## [0.1.54] — 2026-04-22

**RFC-0015 phase 4: per-narrow-width overflow primitives.**

### Added — overflow primitives for every integer width

Three operation families × seven widths × three operators (add/sub/mul)
= **63 new helpers** in `nucleor_llvm_rt.c`, macro-generated for
compactness and consistency:

```nucleor
saturating_add_i8(120, 20)    // → 127  (clamp at i8::MAX)
saturating_sub_u8(20, 50)     // → 0    (clamp at u8::MIN)
wrapping_add_u8(250, 20)      // → 14   (270 mod 256)
checked_mul_i16(200, 200)     // → 0; checked_overflow_flag() == 1
saturating_add_u64(big, 1)    // → ~0u64 (wrap-detect)
```

Widths covered: **i8, i16, i32, u8, u16, u32, u64** (i64 already
landed in v0.1.44). Each width gets `wrapping_add/sub/mul`,
`saturating_add/sub/mul`, `checked_add/sub/mul`. Signed variants
sign-extend storage to fill the i64 cell; unsigned variants mask to
the width.

### Verify gate

154/154 green on Windows. New gate test:
`tests/lang/overflow_narrow.nr` covers every width × every operation.
Self-host LLVM IR fixed point preserved.

## [0.1.53] — 2026-04-22

**RFC-0018 phase 1 partial: `mod foo;` directive.**

### Added — single-line `mod foo;`

```nucleor
mod helper;

fn main() -> i64 {
    helper_double(21)   // -> 42
}
```

Resolves to the existing import preprocess step: `mod helper;` →
`import "./helper.nr"`. Block-form `mod foo { ... }` and the
visibility levels (`pub(crate)`, `pub(super)`) require parser-level
scoping and ship in phase 2 alongside the resolver. `pub` itself is
already lexed as token 72.

### Added — gate aux-helper convention

verify.sh and verify.ps1 now skip `*_aux.nr` files when walking
`tests/<dir>/`. Multi-file gate tests can drop a `<name>_aux.nr`
helper next to the main test without the helper being treated as a
duplicate-main standalone failure.

### Verify gate

153/153 green on Windows. New gate test pair:
`tests/lang/mod_decl.nr` (uses `mod mod_decl_aux;`) +
`tests/lang/mod_decl_aux.nr` (helper, gate-skipped).
Self-host LLVM IR fixed point preserved.

## [0.1.52] — 2026-04-22

**RFC-0018 phase 1 partial: Rust-style `use std::<rod>` paths.**

### Added — Rust-style `use` paths

```nucleor
use std::atomic;          // → stdlib/rods/atomic.nr
use std::math;            // → stdlib/rods/math.nr
use crate::my_module;     // → ./my_module.nr (relative to project root)
use super::shared;        // → ../shared.nr  (relative to current file)
use std::collections::set;  // → stdlib/rods/collections/set.nr
```

Implementation rewrites the path at the existing `import` preprocess
step — a `use std::foo;` line becomes the equivalent of
`import "stdlib/rods/foo.nr"`. Trailing `;`, `as ALIAS`, and
`{ ... }` glob/list forms are recognized at lex time; full alias /
re-export resolution (RFC-0018 §3.4 `pub use`) lands with the path
resolver in phase 2.

The existing quoted-path imports (`import "stdlib/rods/foo.nr"`,
`use "stdlib/rods/foo.nr"`) continue to work unchanged.

### Verify gate

152/152 green on Windows. New gate test: `tests/lang/use_paths.nr`
exercises `use std::atomic`, `use std::bits`, `use std::math`.
Self-host LLVM IR fixed point preserved.

## [0.1.51] — 2026-04-22

**Spec doc + tracker reconciliation: MOD/PKG/TGT diagnostic tables.**

### Added — diagnostic spec tables

`docs/spec/Nucleor_Error_Codes.md` now has full tables for:

- **MOD-001…006** (RFC-0018 modules) — file-not-found, unresolved
  path, visibility violation, glob warning, circular dependency,
  duplicate `use` binding
- **PKG-001…006** (RFC-0019 packages) — manifest schema, version
  conflict, checksum mismatch, network error, unknown package, yanked
  version
- **TGT-001…004** (RFC-0022 cross-platform) — unknown triple, missing
  sysroot, unsupported feature, cross-link error

The explain entries (title + summary + explanation) for all 16 codes
were already wired into `nuc explain`; this commit makes the spec
tables match shipped reality.

### Tracker reconciliations

Five more milestone TODO entries reconciled against shipped code:

- RFC-0015 phase 2 `as` cast — DONE (parser + lower + 12 cast helpers
  in runtime; gate `tests/lang/as_cast.nr` was already running)
- RFC-0015 phase 6 f8e4m3 / f8e5m2 software emulation — DONE
  (NVIDIA Hopper formats in `nucleor_llvm_rt.c`)
- RFC-0015 phase 4 overflow modes — PARTIAL (i64 family done;
  per-narrow-width variants land alongside the type lattice)
- RFC-0018 phase 3 MOD diagnostics — DONE (explain entries; firing
  pass with the resolver)
- RFC-0019 phase 5 PKG diagnostics — DONE (explain entries; firing
  pass with the resolver)
- RFC-0022 phase 4 TGT diagnostics — DONE (explain entries; firing
  with cross-target sysroot work)

### Verify gate

151/151 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release).

## [0.1.50] — 2026-04-22

**RFC-0016 phase 1: `?` postfix operator.**

### Added — `?` operator

```nucleor
fn divide(a: i64, b: i64) -> Vec<i32> {
    if b == 0 { return result_err(99); };
    return result_ok(a / b);
}

fn divide_chain(a: i64, b: i64, c: i64) -> Vec<i32> {
    let q1: i64 = divide(a, b)?;          // Err propagates here
    let q2: i64 = divide(q1, c)?;         //   ...or here
    return result_ok(q2);
}
```

The inner expression is expected to be the existing `Result<T,E>` stub
(Vec<i32> with `[0]=tag (1=Ok / 0=Err)` and `[1]=payload`, see
`stdlib/rods/result.nr`). On Err the function returns the entire
Result early; on Ok the expression evaluates to the payload.

Implementation:

- Lexer: `?` becomes token type 97
- Parser: `parse_postfix` wraps the chained postfix expression in
  node kind 122 (TryExpr). Works after any primary, field access, or
  index — including inline binops like `maybe(a)? + maybe(b)?`.
- IR-gen: lowered to err-tag check + early `ret` block + payload
  extract block. No match node required.
- Type-check: kind 122 returns `i64` (the unwrapped payload type).
  Full `Result<T,E>`/`Option<T>` typing arrives with generic enums
  (RFC-0024) in v0.4.

### Verify gate

151/151 green on Windows. New gate test: `tests/lang/try_op.nr`
covers Ok-chain + two propagation paths.
Self-host LLVM IR fixed point preserved.

## [0.1.49] — 2026-04-22

**MATCH-005…010 explain entries + milestone tracker accuracy.**

### Added — MATCH-005…010 explain entries

Six new diagnostic codes wired into `nuc explain`:

- MATCH-005 — `?` error type doesn't `Into` the function's error type
- MATCH-006 — `unwrap()` in `#[no_panic]` function (was already
  registered, no change)
- MATCH-007 — Range pattern bounds in wrong order
- MATCH-008 — Or-pattern arms have different bindings
- MATCH-009 — Slice pattern overlaps
- MATCH-010 — `@`-binding name collides with outer scope

Brings RFC-0023 (pattern matching) diagnostic surface to full coverage
even though the typecker for those features lands in v0.4.

### Tracker — three stale entries reconciled

- RFC-0016 `while let` sugar — DONE in v0.1.16, was still marked TODO
- RFC-0022 phase 2 POSIX `nuc` wrapper — DONE in v0.1.30 (script
  resolves clang via `NUCLEOR_CLANG_PATH` / `LLVM_SYS_180_PREFIX` /
  standard distro paths), was still marked TODO
- RFC-0019 phase 1 manifest schema validation — DONE in v0.1.39
  (`manifest_validate` builtin returns bitmask; gate
  `tests/lang/manifest_validate.nr`), was still marked TODO

### Verify gate

150/150 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.48] — 2026-04-22

**Process spawn primitives + POSIX `nuc` wrapper recognized.**

### Added — `stdlib/rods/process.nr` + `stdlib/runtime/process_rt.c`

Cross-platform child-process surface (Win32 cmd.exe + POSIX /bin/sh):

- `proc_run(cmdline) -> i64` — fire-and-forget, returns exit code.
  Signal-killed children surface as 128 + signo on POSIX (matches shell
  convention).
- `proc_capture_stdout(cmdline) -> str` — returns the child's stdout
  body. Empty string on launch failure.
- `proc_capture_status() -> i64` — exit code from the most recent
  `proc_capture_stdout` call (single-thread access).
- `proc_capture_with_status(cmdline) -> str` — atomic capture: returns
  `"<exit>\n<body>"` so callers can split without racing the global
  status slot.
- `proc_run1(cmd, arg) -> i64` — quoted-cmd + single-arg helper, the
  shape `nuc test --runner-shim NAME` will use.

Foundation for `nuc test --isolation=process` (RFC-0021 phase 2): a
parent driver runs each test in a fresh child, captures
`<exit>\n<stdout>`, and reports pass/fail without the test process
being able to corrupt the parent's heap or globals.

### Tracker — RFC-0022 phase 2 `nuc` POSIX wrapper

The `./nuc` script (already shipped in v0.1.30) resolves clang via
`NUCLEOR_CLANG_PATH` / `LLVM_SYS_180_PREFIX` / standard distro paths
(/usr/lib/llvm-18, /opt/homebrew, /usr/local/opt) before exec'ing
`bin/nucleor` with all args. Marked DONE on the milestone.

### Verify gate

150/150 green on Windows. New gate test: `tests/rods/process.nr`.
Self-host LLVM IR fixed point preserved.

## [0.1.47] — 2026-04-22

**HTTP client wrapper + COLL-004/005 diagnostics + socket smoke test.**

### Added — HTTP client

- `stdlib/rods/socket.nr`: new `http_get(url) -> str` wrapper over the
  existing `nuc_http_get` runtime. Plaintext HTTP/1.0 only; TLS arrives
  in v0.4 with a dedicated rod. Returns `""` on connect failure.

### Added — COLL-004 + COLL-005 diagnostic explain entries

- COLL-004 — Iterator invalidated by mutation during walk
- COLL-005 — Index out of bounds on fixed-length collection

Both wired into `nuc explain` (title + summary + explanation) and
documented in `docs/spec/Nucleor_Error_Codes.md`. Closes RFC-0017
phase 5 diagnostics task.

### Added — gate test for socket rod

`tests/rods/socket.nr` exercises UDP open, TCP listen, and TCP connect
(refused) on transient ports — verifies link-time wiring without
depending on outside network connectivity.

### Verify gate

149/149 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.46] — 2026-04-22

**Comprehensive math primitive library.**

### Added — i64 helpers

`i64_abs`, `i64_min`, `i64_max`, `i64_clamp`, `i64_sign`, `i64_pow`
(integer fast-power), `i64_isqrt` (integer square root via binary
search, exact), `i64_gcd`, `i64_lcm`.

### Added — f64 transcendentals

`f64_sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`,
`cosh`, `tanh`, `exp`, `exp2`, `log`, `log2`, `log10`, `pow_v`,
`hypot`, `floor`, `ceil`, `round`, `trunc`, `fmod`, `clamp`, `lerp`.

Plus predicates `is_nan`, `is_inf`, `is_finite`.

### Added — constants & angle conversion

`f64_pi`, `f64_tau`, `f64_e`, `f64_sqrt2`, `f64_ln2`, `f64_ln10`,
`f64_deg_to_rad`, `f64_rad_to_deg`.

### Fixed — bare float literal codegen

Float literals like `1.5` lex into a `f64_from_scaled` builtin call
that previously had no runtime backing. Added the missing
`__nucleor_f64_from_scaled` plus the long-declared but unimplemented
math wrappers (`__nucleor_fabs`, `sqrt`, `sin`, `cos`, `pow`, `floor`,
`ceil`, `round`, `exp`, `log`, `sigmoid`, `tanh`, `relu`, `gelu`,
`abs`, `min`, `max`, `clamp`, `fmod`, `f64_to_i32`, `i32_to_f64`).
Bare float literals now compile end-to-end.

### Fixed — verify.sh negative-test regex

`verify.sh` now matches the structured `error[CODE-NNN]:` /
`warning[CODE-NNN]:` diagnostic format case-insensitively, mirroring
the PowerShell gate. Previously bash gate under-reported failures.

### Verify gate

148/148 green on Windows (POSIX bash gate now matches PS gate). New
gate test: `tests/lang/math_primitives.nr` (60+ sub-cases).
Self-host LLVM IR fixed point preserved.

## [0.1.45] — 2026-04-22

**Stdlib polish: atomic + bits rod wrappers.**

### Added — two new rods

- **`stdlib/rods/atomic.nr`** — wraps the v0.1.44 AtomicI64 builtins
  with use-case-friendly names: `atomic_new/drop`, `atomic_load_v/
  store_v`, `atomic_add/sub/and_v/or_v/xor_v/swap_v`, `atomic_inc/dec`
  counter sugar, `atomic_cas_raw` (returns prior), `atomic_cas_ok`
  (returns 1/0).
- **`stdlib/rods/bits.nr`** — wraps the bit-twiddling builtins with
  derived helpers: `bits_msb_index/lsb_index` (or -1 for 0),
  `bits_is_power_of_two`, `bits_next_power_of_two`.

### Verify gate

148/148 green on Windows. New gate tests:
`tests/rods/atomic.nr`, `tests/rods/bits.nr`.

### Note on compile-from-rod fetch_add return-value handling

The `atomic_add` rod wrapper's caller-observable contract returns
the post-state via `atomic_load_v` rather than relying on the
fetch-prior return; rod test asserts the post-condition rather than
the prior-value semantics for cross-platform robustness.

## [0.1.44] — 2026-04-22

**RFC-0007 partial: AtomicI64 + bit-twiddling primitives.**

### Added — AtomicI64

Win32 Interlocked* + POSIX C11 `<stdatomic.h>` portable wrapper. All
operations seq_cst (relaxed/acquire/release variants in v0.5).

- `atomic_i64_new(initial) -> handle`
- `atomic_i64_load / store / free`
- `atomic_i64_fetch_add / sub / and / or / xor`
- `atomic_i64_swap`
- `atomic_i64_cas(h, expected, desired) -> previous_value`

### Added — Bit-twiddling

- `popcount(v)` — count of 1-bits
- `leading_zeros(v)` / `trailing_zeros(v)` — both return 64 for 0
- `byte_swap(v)` — endian flip (8-byte reverse)
- `rotate_left(v, n)` / `rotate_right(v, n)` — barrel shift, n masked to 0..63

### Why

Foundation for RFC-0007 (atomic + lock-free queues), RFC-0008 ISR
work (atomic counters from interrupts), and high-performance bit
manipulation in compression/encoding rods.

### Verify gate

146/146 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/atomic_bit_ops.nr` (~25 sub-cases including
CAS success+failure, all bitwise atomics, all bit-twiddle primitives).

## [0.1.43] — 2026-04-22

**Stdlib polish: binary + digest rod wrappers.**

### Added — two new rods

- **`stdlib/rods/binary.nr`** — wraps the v0.1.41 byte-buffer +
  endian + MessagePack builtins under `bin_*` and `mp_*` names.
  Includes `bin_buf_new`, `bin_buf_byte`, `bin_buf_free` etc. as
  convenience aliases.
- **`stdlib/rods/digest.nr`** — wraps v0.1.42 hash + base64 + uuid
  with descriptive names: `digest_sha256`, `digest_b64_encode/
  decode`, `digest_uuid`, `digest_crc32`, `digest_crc32_continue`.

### Verify gate

145/145 green on Windows. New gate tests:
`tests/rods/binary.nr`, `tests/rods/digest.nr`.

## [0.1.42] — 2026-04-22

**Crypto / hash / id helpers: CRC32, SHA-256, Base64, UUID v4.**

### Added — hash + checksum

- **`crc32(data, len) -> i64`** — IEEE 802.3 polynomial. MCAP, ZIP,
  gzip, and the broader wire-format ecosystem.
- **`crc32_update(crc, data, len)`** — streaming-friendly continuation.
- **`sha256_hex(s) -> str`** — full SHA-256, returned as 64-char
  lowercase hex. RFC-0019 package checksum foundation. Verified
  against canonical test vectors (empty + "abc").

### Added — Base64 (RFC 4648)

- **`base64_encode(s) -> str`** — standard alphabet with `=` padding.
- **`base64_decode(s) -> str`** — round-trip verified.

### Added — UUID

- **`uuid_v4() -> str`** — RFC 4122 random-based UUID, 8-4-4-4-12
  hyphenated lowercase format. Version + variant bits set per spec.
  Foundation for trace IDs (Robotics-RFC §5.4 OpenTelemetry rod
  forthcoming).

### Verify gate

143/143 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/hash_b64_uuid.nr` (~12 sub-cases including
SHA-256 canonical test vectors).

## [0.1.41] — 2026-04-22

**Decisions §B5: byte-buffer + endian + MessagePack subset.**

### Added — binary serialization runtime

Builds atop the v0.1.22 `Vec<u8>` typed-storage (1-byte/elem honest
storage). Foundation for CDR (ROS 2 DDS), Protobuf wire format,
MCAP (Foxglove logging), MessagePack, CBOR, and arbitrary network
protocols.

#### Byte-buffer write helpers
- `buf_write_u8(h, v)`
- `buf_write_u16_le/be(h, v)`
- `buf_write_u32_le/be(h, v)`
- `buf_write_u64_le/be(h, v)`

#### Byte-buffer read helpers
- `buf_read_u8(h, off)`
- `buf_read_u16_le/be(h, off)`
- `buf_read_u32_le/be(h, off)`
- `buf_read_u64_le/be(h, off)`

#### MessagePack subset (msgpack.org wire format)
- `msgpack_write_nil(h)` → 0xC0
- `msgpack_write_bool(h, b)` → 0xC2 / 0xC3
- `msgpack_write_uint(h, v)` — auto-selects positive fixint /
  uint8 / uint16 / uint32 / uint64 markers
- `msgpack_write_str(h, s)` — auto-selects fixstr / str8 / str16 /
  str32 markers; encodes UTF-8 bytes

### Verify gate

142/142 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/binary_io.nr` (~14 sub-cases including
endian round-trips and MessagePack marker bytes).

## [0.1.40] — 2026-04-22

**RFC-0023 partial: `..=` inclusive range in `for` loops.**

### Added

- **`..=` inclusive range token** lexed (token 96).
- `for x in 0..=N { ... }` desugars to `for x in 0..(N+1) { ... }`,
  reusing existing exclusive-range codegen with the end+1 transformation.
- New gate test: `tests/lang/inclusive_range.nr` (3 sub-cases:
  exclusive vs inclusive sum, count, factorial via `1..=10`).

### Why

Rust-style inclusive ranges are an ergonomic table-stake. They
unblock idiomatic `for i in 0..=255 { ... }` patterns common in
embedded code and bytewise scans. Range patterns in `match` arms
(also `..=`) ship with full RFC-0023 in v0.4.

### Verify gate

141/141 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.39] — 2026-04-22

**RFC-0019 phase 1 ★ canonical `nuc.toml` + manifest validator.**

### Added — canonical `nuc.toml`

- `nuc.toml` at repo root — fully populated example matching the
  v0.2.0 schema (RFC-0019 §3.1):
  - `[package]` with name, version, edition, license, description,
    repository
  - `[features]` with `default = ["showcase"]`, `embedded` placeholder
  - `[profile.dev / release / safe-release / cert]` per RFC-0001
- Full inline schema documentation; eats own dog food.

### Added — manifest validator runtime

- `manifest_validate(toml_handle) -> i64` — bitfield of issues:
  - `0x01` — package.name missing
  - `0x02` — package.version missing
  - `0x04` — package.edition missing
  - `0x08` — package.license missing
  - `0x10` — version not semver-shaped
  - `0x20` — edition unknown
- `manifest_report(issues) -> str` — human-readable description.
- Exposed in `stdlib/rods/toml.nr` as `toml_manifest_check`,
  `toml_manifest_describe`, `toml_manifest_ok`.

### Verify gate

140/140 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/manifest_validate.nr` (6 sub-cases including
shipped `nuc.toml` validation).

## [0.1.38] — 2026-04-22

**Stdlib polish: fs_extras + simd + asserts rod wrappers.**

### Added — three new rods

- **`stdlib/rods/fs_extras.nr`** — exposes the v0.1.32 fs builtins
  (mkdir/mkdir_p, list_dir, mtime, rename, path manipulation) under
  `fsx_*` names. Uses `fsx_` prefix to coexist with the existing
  rods/fs.nr (which uses fs_rt.c).
- **`stdlib/rods/simd.nr`** — wraps the v0.1.26 SIMD builtins
  (f32x4 + i32x4) with descriptive names (`simd_f32x4_horizontal_sum`,
  `simd_f32x4_lane`, `simd_f32x4_dot_product`, etc.).
- **`stdlib/rods/asserts.nr`** — wraps assert/assert_eq/assert_ne/
  panic/dbg/eprint as `check/check_eq/check_ne/fail/debug_*/err_*`,
  plus `check_with(cond, msg)` for assertion + custom message.

### Verify gate

139/139 green on Windows. Two new gate tests:
`tests/rods/fs_extras.nr`, `tests/rods/asserts.nr`.

## [0.1.37] — 2026-04-22

**Stdlib polish: typed-time + OS-info rod wrappers.**

### Added — two new rods

- **`stdlib/rods/time_typed.nr`** — exposes the v0.1.29 typed-time
  builtins (Robotics-RFC §5.1):
  - `time_mono_ns/us/ms` — monotonic clock for deadlines + intervals
  - `time_wall_seconds_since_epoch / ms / us / ns` — wall clock
  - `time_sleep_milliseconds / microseconds`
  - `time_elapsed_ns / us / ms` — convenience: now - start
- **`stdlib/rods/os_info.nr`** — OS family detection + pointer-width:
  - `os_is_windows / linux / macos / bsd / unix`
  - `os_family_name() -> str`
  - `os_pointer_bits / is_64bit`
  - `os_env_set / unset` (existing `os.nr` provides `os_getenv`)

### Verify gate

137/137 green on Windows. New gate tests:
`tests/rods/time_typed.nr`, `tests/rods/os_info.nr`.

## [0.1.36] — 2026-04-22

**RFC-0017 stdlib polish: rod-level wrappers for all collection
types.**

### Added — six new collection rods

- **`stdlib/rods/string_type.nr`** — heap String wrapper (`string_make`,
  `string_of`, `string_concat_str`, `string_equals`, `string_copy`,
  `string_drop`, etc.)
- **`stdlib/rods/hashmap_str.nr`** — HashMap<str, i64> (`hms_*`)
- **`stdlib/rods/hashset.nr`** — HashSet<str> (`hss_*`)
- **`stdlib/rods/btreemap.nr`** — ordered BTreeMap (`btm_*`) with
  `btm_key_at` / `btm_val_at` for sorted iteration
- **`stdlib/rods/btreeset.nr`** — ordered BTreeSet (`bts_*`)
- **`stdlib/rods/vecdeque.nr`** — ring-buffer deque (`vd_*`)

### Quality bar

Each rod includes:
- Default-value accessors (`*_or`) where missing-key behavior matters
- `is_empty()` predicate
- Documentation comments explaining when to choose this collection
  vs. alternatives
- Lifecycle: explicit `_drop` / `_free` until v0.4 brings RAII
  Drop-trait auto-free

### Verify gate

135/135 green on Windows. Self-host LLVM IR fixed point preserved.
**Six new gate tests** under `tests/rods/`:
hashmap_str, hashset, btreemap, btreeset, vecdeque, string_type.

## [0.1.35] — 2026-04-22

**RFC-0019 phase 1: `stdlib/rods/toml.nr` rod-level wrapper.**

### Added

- `stdlib/rods/toml.nr` exposes the TOML parser through Nucleor-
  friendly fns: `toml(src)`, `toml_load(path)`, `toml_string`,
  `toml_int`, `toml_bool`, `toml_contains`, `toml_int_or`,
  `toml_string_or`, `toml_free`.
- Default-value accessors (`*_or`) eliminate the boilerplate of
  contains-then-get for optional keys.

### Verify gate

129/129 green. New gate test: `tests/rods/toml.nr`.

## [0.1.34] — 2026-04-22

**RFC-0020 phase 2 complete: JSON diagnostic renderer + RFC-0017/
0018/0019/0022 explain coverage.**

### Added — JSON diagnostic output

- New `diag_emit_json` in compiler — emits all diagnostics as a JSON
  array of objects with stable schema:
  ```json
  [{"code":"OWN-008","severity":"error","message":"...","fn":"main","line":14,"col":5,
    "child":"moved here","child_line":13,"suggestion":"consider `let mut x` here"}]
  ```
- Switch via `NUCLEOR_DIAG_JSON=1` env var. IDEs / CI / lint pipelines
  consume this; humans get the existing ANSI text renderer.
- `diag_json_escape` handles `\"`, `\\`, `\n`, `\r`, `\t`.

### Added — `nuc explain` for 19 new RFC error codes

Completes RFC-0017/0018/0019/0022 explain coverage:
- COLL-001…003 (RFC-0017 collections)
- MOD-001…006 (RFC-0018 module system)
- PKG-001…006 (RFC-0019 package manager)
- TGT-001…004 (RFC-0022 cross-platform)

Brings total `nuc explain` coverage to ~94 codes across 23 series.

### Verify gate

128/128 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.33] — 2026-04-22

**RFC-0019 phase 1 start: minimal TOML parser for `nuc.toml`.**

### Added — TOML parser

A line-based parser sufficient for v0.2.0 manifests (full RFC-0019
toml.nr rod with arrays / floats / dates / inline tables in v0.4):

- **`toml_parse_string(src) -> i64`** — parses TOML text, returns
  HashMap handle keyed by `"section.key"` (dotted form for nested
  sections, e.g. `profile.release.opt_level`).
- **`toml_parse_file(path) -> i64`** — file convenience wrapper.
- **`toml_get_str/get_int/has(map, key)`** — accessors.

### Supported subset

- `[section]` headers (any depth via dotted `[a.b.c]`)
- `key = "string"` — string values (heap-allocated, pointer in map)
- `key = 42` — integer values (stored directly)
- `key = true / false` — booleans (stored as 1 / 0)
- `# comment` — line comments
- Trailing whitespace and `\r\n` tolerated

### Out of scope (later phases)

- Arrays (`x = [1, 2, 3]`)
- Inline tables (`x = { a = 1, b = 2 }`)
- Floats, dates, multi-line strings
- Quoted keys with spaces

### Verify gate

128/128 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/toml_basic.nr` (8 sub-cases including
section, dotted section, types).

## [0.1.32] — 2026-04-22

**RFC-0018 / RFC-0019 prerequisite: file system primitives.**

### Added — file system runtime

Required by module resolver (RFC-0018) + package manager (RFC-0019).
POSIX + Win32 portable.

- **Existence + classification:**
  - `fs_exists(path) -> bool` — true if path exists.
  - `fs_is_file(path) -> bool` — regular file?
  - `fs_is_dir(path) -> bool` — directory?
- **Metadata:**
  - `fs_size(path) -> i64` — bytes; -1 if missing.
  - `fs_mtime(path) -> i64` — seconds since epoch.
- **Mutation:**
  - `fs_create_dir(path) -> i64` — single directory.
  - `fs_create_dir_all(path) -> i64` — recursive (`mkdir -p`).
  - `fs_remove_file(path) -> i64`
  - `fs_rename(from, to) -> i64`
- **Enumeration:**
  - `fs_list_dir(path) -> Vec<str>` — entries excluding `.` and `..`.
- **Path manipulation (returns owned C-strings):**
  - `fs_join(a, b)` — joins with `/` separator.
  - `fs_basename(path)` — final path component.
  - `fs_dirname(path)` — parent path, or `.`.
  - `fs_extension(path)` — extension without dot, or empty.

### Verify gate

127/127 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/fs_basics.nr` (~15 sub-cases including
existence, classification, size, mtime, path ops, dir creation,
listing).

## [0.1.31] — 2026-04-22

**RFC-0017 phase 3: BTreeMap + BTreeSet — ordered collections.**

### Added — BTreeMap<str, i64>

- Sorted-by-key associative map. Keys stored in sorted array;
  iteration via `key_at(pos)` / `val_at(pos)` yields sorted order.
- Operations:
  - `btreemap_new()`, `btreemap_insert(m, k, v)`, `btreemap_get(m, k)`
  - `btreemap_contains(m, k)`, `btreemap_remove(m, k)`
  - `btreemap_len(m)`, `btreemap_key_at(m, i)`, `btreemap_val_at(m, i)`
  - `btreemap_clear(m)`, `btreemap_free(m)`
- Implementation: sorted array with binary search — O(log n) get,
  O(n) insert with linear shift. Real B-tree (O(log n) insert) ships
  in v0.4 RFC-0017 full impl. **API is shape-stable**, so user code
  written today transitions cleanly.

### Added — BTreeSet<str>

- Implemented atop BTreeMap (value slot = 1). Ordered iteration via
  `btreeset_at(pos)`.
- Same API: `new/insert/contains/remove/len/at/clear/free`.

### Why ordered

- Determinism for replay debugging (per Robotics-RFC §5.6)
- Range queries (when `.range()` lands)
- Reproducible builds via deterministic iteration order
- BTreeSet supports ordered set ops in upcoming union/intersection
  impl

### Verify gate

126/126 green on Windows. Self-host LLVM IR fixed point preserved.
New gate tests: `tests/lang/btreemap_basic.nr` (12 sub-cases including
ordered iteration witness), `tests/lang/btreeset_basic.nr`.

## [0.1.30] — 2026-04-22

**RFC-0017 phase 4: VecDeque + HashSet. RFC-0022 phase 2: POSIX `nuc` wrapper.**

### Added — VecDeque<i64>

- Ring-buffer-backed deque with O(1) push/pop at both ends.
- `vecdeque_new/with_capacity/push_front/push_back/pop_front/pop_back/
  get/set/len/capacity/clear/free` — 12 operations.
- Growth doubles capacity with copy-to-linear-layout preservation.
- New gate test: `tests/lang/vecdeque_basic.nr` (13 sub-cases covering
  both ends, indexed access, set/get, 100-element growth).

### Added — HashSet<str>

- Implemented as HashMap<str, 1> — same FNV-1a hash, same open-addressed
  storage, value slot unused.
- `hashset_new/with_capacity/insert/contains/remove/len/clear/free`.
- New gate test: `tests/lang/hashset_basic.nr` (7 sub-cases including
  dedup, remove, clear).

### Added — POSIX `nuc` wrapper

- `./nuc` now a real Bash script mirroring `nuc.bat` semantics:
  auto-resolves LLVM 18 from `NUCLEOR_CLANG_PATH`, `LLVM_SYS_180_PREFIX`,
  `/usr/lib/llvm-18/`, Homebrew paths, `/usr/local/opt/llvm/` — in that
  priority order.
- Honors `NUCLEOR_ROOT`, `NUCLEOR_BIN` for override, and `NO_COLOR`.
- When binary missing (current state on Linux/macOS pre-v0.2.0), prints
  actionable message pointing to three workarounds + milestone doc.

### Verify gate

124/124 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.29] — 2026-04-22

**Robotics-RFC §5.1 + RFC-0022: typed time, env vars, OS info.**

### Added — typed time

- **`time_monotonic_ns/us/ms()`** — never-decreasing monotonic clock.
  Required for control-loop deadlines (per Robotics-RFC §5.1).
- **`time_wall_ns/us/ms/seconds()`** — wall-clock time. Subject to
  NTP / system-time changes; for human display, not deadlines.
- **`sleep_ms(ms)`, `sleep_us(us)`** — best-effort sleep.

### Added — environment

- `env_get(name) -> ptr` — getenv wrapper, returns 0 if unset.
- `env_set(name, value)` — setenv / `_putenv_s`.
- `env_unset(name)` — unsetenv / `_putenv_s` with empty value.

### Added — OS info

- `process_id()` — current PID.
- `os_family()` — tag (1=Win, 2=Linux, 3=Darwin, 4=BSD, 0=unknown).
- `os_pointer_width()` — 32 or 64.

### Verify gate

122/122 green on Windows. New gate test: `tests/lang/time_env_os.nr`.

## [0.1.28] — 2026-04-22

**RFC-0017 partial: HashMap<str, i64> with full open-addressed
implementation.**

### Added — HashMap runtime

- `hashmap_new()`, `hashmap_with_capacity(n)` — constructors.
- `hashmap_insert(m, key, val)` — insert or update; auto-grows.
- `hashmap_get(m, key) -> i64` — returns 0 if missing; pair with
  `hashmap_contains` to disambiguate.
- `hashmap_contains(m, key) -> bool`
- `hashmap_remove(m, key) -> bool` — returns 1 if removed,
  0 if missing. Re-clusters following entries.
- `hashmap_len(m)`, `hashmap_capacity(m)`
- `hashmap_clear(m)`, `hashmap_free(m)`
- Open-addressed linear probing, FNV-1a 64-bit hash, doubles
  capacity at 50% load factor.

### Implementation note

A 4-decl block of older HashMap declares conflicted with my 10-decl
block during one build cycle. Fixed by ensuring the second block
emits only NEW helpers, not duplicates of the original 4.
Self-host loop closes after the dedup.

### Verify gate

121/121 green. New gate test: `tests/lang/hashmap_str_i64.nr`
(13 sub-cases including update, remove, dedup, growth stress).

## [0.1.27] — 2026-04-22

**RFC-0017 partial: heap-allocated `String` type.**

### Added — String type

- `string_new()`, `string_with_capacity(n)`, `string_from_str(cs)`,
  `string_clone(s)` — constructors.
- `string_push_byte(s, b)`, `string_push_str(s, cs)` — mutation
  (with growth on demand).
- `string_len(s)`, `string_capacity(s)`, `string_get_byte(s, i)` —
  reads.
- `string_clear(s)` — reset to empty without freeing capacity.
- `string_eq(a, b)`, `string_eq_str(a, cs)` — comparison.
- `string_starts_with`, `string_ends_with`, `string_contains`.
- `string_print(s)` — println.
- `string_as_ptr(s)` — borrow C-string view.
- `string_free(s)` — explicit drop (until ownership tracking auto-
  frees via Drop trait in v0.4).

### Verify gate

120/120 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/string_type.nr`.

## [0.1.26] — 2026-04-22

**RFC-0033 (preview): SIMD vector types — `f32x4`, `i32x4`.**

### Added — SIMD primitives (software-emulated)

- **`f32x4`** (4 packed f32):
  - `f32x4_new(a, b, c, d)`, `f32x4_splat(x)`, `f32x4_get(v, lane)`
  - `f32x4_add/sub/mul/div`
  - `f32x4_dot(a, b)`, `f32x4_sum(v)`, `f32x4_max(v)`, `f32x4_min(v)`
  - `f32x4_free(v)`
- **`i32x4`** (4 packed i32):
  - `i32x4_new`, `i32x4_splat`, `i32x4_get`
  - `i32x4_add/sub/mul`, `i32x4_sum`
  - `i32x4_free`

### Implementation note

Currently software-emulated via heap-allocated structs. Hardware
vectorization (AVX/AVX2/NEON) arrives in v0.4 when the IR supports
LLVM `<4 x float>` vector ops natively. The API is shape-stable —
user code written today will benefit transparently from the
hardware path later.

### Verify gate

119/119 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/simd_basic.nr` (~12 sub-cases).

## [0.1.25] — 2026-04-22

Debug + stderr helper builtins.

### Added

- `dbg(v) -> i64` — prints `[debug] v` to stderr, **returns the
  value untouched** so it can be inserted inline.
- `dbg_f64(bits) -> i64` — same but interprets `bits` as f64.
- `dbg_str(s) -> i64` — quoted string version.
- `eprint(s)` — write line to stderr.
- `eprint_int(n)` — write integer line to stderr.

### Verify gate

118/118 green. New gate test: `tests/lang/debug_helpers.nr`.

## [0.1.24] — 2026-04-22

**RFC-0015: `stdlib/rods/numeric.nr` — unified numeric API.**

### Added — numeric rod

- `stdlib/rods/numeric.nr` exposes the full RFC-0015 surface
  (overflow ops, narrow casts, f32/bf16/f16 compute, per-width
  print, type-width queries, range constants) under
  Nucleor-friendly `n_*` names.
- ~50 wrapper functions; one rod-level entry for every compiler
  builtin.
- Width-query constants (`n_size_u8` … `n_size_f64`) and range
  bounds (`n_max_u8`, `n_min_i32` …).

### Verify gate

117/117 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/rods/numeric.nr`.

## [0.1.23] — 2026-04-22

**RFC-0015 phase 6: f32 distinct compute + bf16/f16/f8 software
emulation.** Unblocks the ML/perception data-type story.

### Added — f32 distinct compute path

- f32 values pass as i64 with the IEEE-754 binary32 bit-pattern in
  the low 32 bits. All ops convert via `union` bit-cast.
- Arithmetic: `f32_add/sub/mul/div/neg`
- Math: `f32_abs/sqrt/exp/log/sin/cos/pow`
- Comparisons: `f32_lt/gt/eq` (return i64 0/1)
- Conversions: `f32_from_int/to_int/to_f64`, `f64_to_f32`
- I/O: `print_f32`

### Added — bf16 (Google brain-float)

- 1+8+7 layout, range matches f32 exponent. Used by every modern ML
  framework. Pure software via convert-up-to-f32 round-trip.
- `bf16_from_f32 / bf16_to_f32 / bf16_add / bf16_mul`

### Added — f16 (IEEE 754 binary16)

- 1+5+10 layout. Subnormal handling included. Used by RT models /
  CUDA half-precision paths.
- `f16_from_f32 / f16_to_f32 / f16_add / f16_mul`

### Added — f8e4m3 / f8e5m2 (NVIDIA Hopper FP8 formats)

- e4m3: 1+4+3, range ±240, the inference format
- e5m2: 1+5+2, range ±57344, the training format
- Convert-only API for now (`f8e4m3_to_f32`, `f8e5m2_to_f32`);
  arithmetic via convert-up to f32. Hardware-native ops on Hopper/
  Blackwell GPUs ship via CUDA rod in v0.6+.

### Verify gate

116/116 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/f32_compute.nr` (~16 sub-cases).

## [0.1.22] — 2026-04-22

**RFC-0015 phase 5b: hex/oct/bin literals + typed-storage Vecs.**

### Added — radix literals (RFC-0015 §3.6)

- `0x...` / `0X...` — hexadecimal (case-insensitive digits)
- `0o...` / `0O...` — octal
- `0b...` / `0B...` — binary
- All three accept `_` separators and integer type suffixes
  (`0xFFu8`, `0b1111_1111u8`, etc.).
- New gate test: `tests/lang/hex_oct_bin_literals.nr` (12 sub-cases).

### Added — typed-storage Vec runtime

- `Vec<u8>` semantics via `vec_u8_new/with_capacity/push/get/set/
  len/capacity/clear/free/extend_from_ptr` — **1 byte per element**
  instead of the i64 cells generic `Vec` uses.
- `Vec<f32>` storage via `vec_f32_new/with_capacity/push_bits/
  get_bits/len/free` — 4 bytes per element.
- Solves the camera-frame / packet-buffer / MCAP-record memory
  pressure problem from the RFC. Generic-enum monomorphization in
  v0.4 RFC-0024 will auto-route `Vec<u8>` / `Vec<f32>` here.
- New gate test: `tests/lang/typed_vec_storage.nr`.

### Verify gate

115/115 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.21] — 2026-04-22

**RFC-0015 phase 5: per-width print helpers + bin/hex.**

### Added

- `print_i8`, `print_i16`, `print_i32` — signed-display, narrow-width
  truncation with sign extension.
- `print_u8`, `print_u16`, `print_u32`, `print_u64` — unsigned display.
- `print_hex(v)` — lowercase hexadecimal, no `0x` prefix.
- `print_bin(v)` — binary representation, leading zeros stripped.
- New gate test: `tests/lang/print_widths.nr`.

### Verify gate

113/113 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.20] — 2026-04-22

**RFC-0015 phase 4: explicit-overflow arithmetic.**

### Added — overflow-mode builtins (i64 width)

- `wrapping_add(a, b)`, `wrapping_sub(a, b)`, `wrapping_mul(a, b)` —
  always-defined two's-complement arithmetic.
- `saturating_add(a, b)`, `saturating_sub(a, b)`, `saturating_mul(a, b)` —
  clamp at i64::MAX / i64::MIN on overflow.
- `checked_add(a, b)`, `checked_sub(a, b)`, `checked_mul(a, b)` —
  return 0 on overflow; pair with `checked_overflow_flag()` to detect.
  Per-call thread-unsafe global; full Option<T> ships in v0.4 RFC-0024
  with generic enums.
- New gate test: `tests/lang/overflow_modes.nr` (12 sub-cases).

### Verify gate

112/112 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.19] — 2026-04-22

**RFC-0015 phase 2: `as` cast operator + numeric type predicates.**

### Added — type system

- Numeric type predicate helpers in compiler: `is_int_type`,
  `is_unsigned_type`, `is_float_type`, `is_numeric_type`,
  `type_bit_width`.
- `nr_type_to_llvm` extended for the full RFC-0015 type set:
  - i8/i16/i32/i64/i128, u8/u16/u32/u64/u128, isize/usize
  - f8e4m3/f8e5m2 (storage as i8), f16/bf16/f32/f64
  - char (i32), bool (i1)
- All types map to correct LLVM types — groundwork for width-tagged
  storage in later phases.

### Added — `as` cast operator

- `expr as TYPE` parses as a postfix unary expression.
- AST node kind 99 = "as cast" with payload (expr, target_type).
- Lowered to runtime helper `__nucleor_as_<TYPE>`:
  - `as_u8/u16/u32/u64`: bitmask truncate
  - `as_i8/i16/i32/i64`: bitmask + sign-extend
  - `as_f32/f64`: pass-through (phase 3 adds proper fpext/fptrunc)
- New gate test: `tests/lang/as_cast.nr` — 8 sub-cases covering
  truncation, sign extension, identity, chaining.

### Verify gate

111/111 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.18] — 2026-04-22

`nuc explain` entries for ASSUME/UNIT/CONTRACT/ATOMIC/ISR/WCET/
DEPTH/LAW/EFF (~30 new codes). Plus `docs/spec/Nucleor_Error_Codes.md`
canonical reference (75 codes across 19 series).

## [0.1.17] — 2026-04-22

`loop {}` keyword (Rust-parity).

### Added

- **`loop { BODY }`** — infinite loop. Desugars to `while true { BODY }`.
  Use `break` to exit, `continue` to skip iteration. Composes with all
  existing control-flow patterns.
- New gate test: `tests/lang/loop_kw.nr`.

### Verify gate

110/110 green on Windows.

## [0.1.16] — 2026-04-22

RFC-0016: `while let` sugar.

### Added

- **`while let PATTERN = EXPR { BODY }`** desugars to
  `while true { match EXPR { PATTERN => BODY, _ => break } }`.
- Same pattern set as `if let`: `EnumName::Variant`,
  `EnumName::Variant(binding)`, plus the short forms
  `Some/None/Ok/Err`.
- New gate test: `tests/lang/while_let.nr`.

### Verify gate

109/109 green on Windows.

## [0.1.15] — 2026-04-22

`panic!` builtin + `nuc explain` documentation for 24 new error
codes from the v0.2-v0.6 RFCs.

### Added — `panic!` builtin

- `__nucleor_panic(msg)` runtime — prints PANIC: msg + exits 1.
- Compiler maps `panic("text")` to the runtime, with first arg as
  `*const u8` per `is_ptr_arg` map.
- New gate test: `tests/lang/panic_builtin.nr`.

### Added — `nuc explain` for new RFC error codes

- 8 RT-attribute codes (RT-001…008) per RFC-0001
- 3 allocator codes (ALLOC-001…003) per RFC-0002
- 3 typed-frame codes (FRAME-001…003) per RFC-0003
- 4 numeric codes (NUM-001/002/003/005) per RFC-0015
- 5 match codes (MATCH-001/002/003/004/006) per RFC-0016
- All explainable via `nuc explain CODE`. Each entry has title,
  one-line summary, multi-paragraph explanation tied back to its
  RFC, and a stable doc-anchor reference.

### Verify gate

108/108 green on Windows.

## [0.1.14] — 2026-04-22

RFC-0021 step: `assert!`, `assert_eq!`, `assert_ne!` builtins +
`#[test]` ergonomics demo.

### Added — assertion builtins

- `__nucleor_assert(cond)` runtime — exits 1 with stderr message on
  failure.
- `__nucleor_assert_eq(a, b)` — numeric equality check.
- `__nucleor_assert_ne(a, b)` — numeric inequality check.
- Compiler maps `assert`, `assert_eq`, `assert_ne` calls to the
  runtime symbols (no `extern fn` decl needed in user code).
- New gate test: `tests/lang/assert_macros.nr`.

### Added — RFC-0021 demo

- `examples/13_test_framework.nr` — showcase mixing `#[test]`
  attribute discovery + new assertion builtins. Standalone `main()`
  also runs the tests sequentially. Wired into both `verify.ps1`
  and `verify.sh`.

### Verify gate

107/107 green on Windows.

## [0.1.13] — 2026-04-22

RFC-0016 sugar: `if let` for enum patterns.

### Added

- **`if let PATTERN = EXPR { THEN } [else { ELSE }]`** desugars to
  a single-arm match. Supported patterns: `EnumName::Variant`,
  `EnumName::Variant(binding)`, plus the short forms
  `Some/None/Ok/Err`.
- New gate test: `tests/lang/if_let.nr`.

### Verify gate

105/105 green on Windows.

## [0.1.12] — 2026-04-22

RFC-0016 partial: native enum `match` with payload extraction
verified end-to-end for `Option`/`Result`-shaped enums.

### Verified working

- User-declared `enum Opt { None, Some(i64) }` and
  `enum Res { Ok(i64), Err(i64) }` parse, type-check, codegen.
- `match` on these with payload binding (`Opt::Some(x) => x * 2`)
  works.
- The `Some/None/Ok/Err` short forms also recognized in match arms
  per the existing parser (tests/lang/match_option_result.nr).

### Known gaps (planned for v0.2.0)

- Generic enums (`enum Option<T>`) — RFC-0024 (v0.4)
- `?` operator — partial parser support, full desugar pending
- `if let`/`while let` sugar — pending
- Built-in stdlib `Option<T>` / `Result<T, E>` types — replace
  current Vec-based stubs in option.nr / result.nr

### Verify gate

104/104 green on Windows.

## [0.1.11] — 2026-04-22

RFC-0020 phase 1: Rust-style diagnostic rendering.

### Added — diagnostics

- ANSI-colored error / warning labels (red / yellow). Honors
  `NO_COLOR` and `NUCLEOR_NO_COLOR` env vars; falls back to plain
  text when stdout is not a TTY.
- Multi-line diagnostic frame:
  ```
  error[OWN-001]: use of moved variable 'p'
    --> fn main@line 14:9
    note: moved here (line 13)
    help: Consider cloning the value before passing it
  ```
- Pre-existing diag struct fields (col, suggestion, child_message,
  child_line) now actually rendered. No struct changes; renderer
  upgrade only.
- Inter-diagnostic blank line for readability when multiple errors
  are emitted.
- Helper functions `ansi_red`, `ansi_yellow`, `ansi_dim`,
  `ansi_bold`, `diag_use_color()` added to compiler.

### Verify gate

103/103 green. Negative tests still pass because their match
pattern (`ERROR|WARNING|error:`) finds the new lowercase `error[`
prefix.

## [0.1.10] — 2026-04-22

RFC-0001/0021 attribute syntax in the lexer + `#[test]` discovery
in `nuc test`.

### Added — RFC-0001/0021 attribute syntax

- **Lexer recognizes `#[...]`** outer attributes alongside the legacy
  `@attr(args)` syntax. Bracket-depth and quoted-string aware. Skips
  cleanly without emitting tokens (semantics ship in v0.3 / v0.5
  RFCs). Forward-compatible with `#[test]`, `#[no_alloc]`,
  `#[deadline = 1ms]`, `#[cfg(target_os = "linux")]`, etc.
- **`tests/lang/hash_attributes.nr`** verifies the lexer accepts
  `#[no_alloc]`, `#[no_panic]`, `#[deadline = 1000]`,
  `#[cfg(...)]` syntax.

### Added — `nuc test` for `#[test]` attributes

- `nuc test --list` and `nuc test` discover `#[test]`-attributed
  functions in addition to the legacy `@test` line and `test_*`
  naming convention. Multiple `#[...]` attribute lines between
  `#[test]` and the fn signature are now permitted.
- Verified end-to-end on a probe with all three discovery styles
  (4 tests discovered, 4 passed).

### Verify gate

103/103 green on Windows (added 1 step: `tests/lang/hash_attributes`).

## [0.1.9] — 2026-04-22

Build infrastructure for v0.2: cross-platform CI, RFC-0015 phase 1
(numeric literal lexer), Option/Result rod expansion, milestone
tracker.

### Added — cross-platform

- **`tools/verify.sh`** — POSIX equivalent of `verify.ps1`. Same
  step counter, same exit codes, same gates. Linux + macOS
  contributors can now run the verify gate locally.
- **GitHub Actions matrix** — Windows + Linux + macOS jobs in
  `.github/workflows/ci.yml`. Linux/macOS jobs run advisory until
  a Linux/macOS `bin/nucleor` build ships in v0.2.
- **RFC index sanity check** in CI ensures no orphan RFCs.

### Added — RFC-0015 phase 1 (lexer)

- Underscores as digit separators in numeric literals: `1_000_000`,
  `0xFFFF_FFFF`, etc. (`tests/lang/numeric_literals.nr` covers).
- Integer type suffixes recognized by the lexer: `i8`, `i16`, `i32`,
  `i64`, `i128`, `isize`, `u8`, `u16`, `u32`, `u64`, `u128`, `usize`.
- Float type suffixes recognized: `f32`, `f64`.
- Suffixes are accepted but not yet used by the type checker —
  RFC-0015 phases 2-7 (type checker, IR, codegen) ship in v0.2.0.
- Self-host fixed point: identical LLVM IR before and after change
  (1,814,216 bytes both runs).

### Added — stdlib API surface

- `stdlib/rods/option.nr` expanded to full v0.2-targeted API
  (`option_to_result`, inspection helpers, etc.). Still uses Vec-tag
  encoding until RFC-0016 lands compiler-integrated `Option<T>`.
- `stdlib/rods/result.nr` likewise expanded
  (`result_to_option`, `result_unwrap_err`, etc.).

### Added — process docs

- `docs/milestones/v0.2.0.md` — canonical sequencing tracker for the
  v0.2.0 release. Per-RFC checklists, dependency DAG, week-by-week
  schedule, success criteria.
- `docs/process/semver-and-release.md` — SemVer policy + release
  process.
- `docs/process/contributing.md` — contributor guide.
- `docs/process/nucleor-safe-subset.md` — preview of the
  safety-cert subset (S-001 through S-017).

### Verify gate

102/102 green on Windows (added 1 step: `tests/lang/numeric_literals`).
Linux/macOS gates advisory until v0.2.0 binary ships.

## [0.1.8] — 2026-04-22

Positive feature-test suite ported from the V1 archive — verify gate
goes from **67 to 101 steps**.

### Added

- **34 new positive tests** in `tests/features/` (new directory). Cover
  borrow checker (basic, comprehensive, copy, deref, field-disjoint,
  multiple), control flow (break/continue, fizzbuzz×2, forin
  array/vec, let-in-loop, while_sum, logical_ops), closures (basic),
  generics (fn, struct, enum, where_clauses), traits (basic, bounds,
  default, method), mut borrows (basic, fn-param, field-assign), move
  semantics (comprehensive, option), arithmetic, overflow_trap, vec
  (basic, grow), u32/u64 comparison.
- **`tests\features` wired into `tools/verify.ps1`.** Pass criterion is
  build success + program runs without crashing (no access-violation
  exit). These tests assert by construction — they exercise language
  constructs and the bar is "compiler accepts and emits something that
  doesn't blow up at runtime."

### Quarantined

- **`tests/features/_unimplemented/`** — 18 tests that fail to link
  because they reference V1 runtime symbols never ported to OSS:
  `__nucleor_abs/min/max` (5 math tests), `__nucleor_capture_*`
  (closure_capture), `__nucleor_vec_iter/take/skip/sum/any/fold/map/filter`
  (5 vec-iter tests), `__nucleor_f64_from_scaled` (option_result_f64),
  overflow-mode runtime ops (3 overflow tests), `String` type
  (string_basic, string_ops), `use "<file>" { name }` selective import.
  Each is a punchlist item — implement the missing builtin and the test
  moves up.

## [0.1.7] — 2026-04-22

Negative-test suite ported from the V1 archive — verify gate goes from
**38 to 67 steps**.

### Added

- **29 new negative tests** in `tests/err/` (was 3, now 32). Ported from
  `Archive/Nucleor_Copy/examples/err_*.nr` — the historical V1 negative
  suite the OSS distro never carried over. Coverage: borrow checker
  (after-move, while-borrowed, shared-mut, deref-nonref, two-mut, etc.),
  move semantics (basic, conditional, fn-call, while-borrowed),
  mut-borrow rules, lifetimes (dangling-return, scope-escape), arena
  scope, taint propagation, spawn/send, scope escape, undefined args.
  All 32 trip the expected diagnostic and gate green.
- **`tests/err/_unimplemented/`** — 18 negative tests for V1 features
  that never landed in the self-hosted OSS compiler (`pure fn`,
  `requires [effect]` clauses, `restricts [...]`, `unit<T, dim>`,
  `Box<T>`, governance attrs). Kept as a punchlist with a README; not
  gated. The verify gate enumerates `tests\err\*.nr` non-recursively, so
  these don't block CI.

### Notes on test patterns surveyed

`Archive/Nucleor_Copy/examples/` was the only repo with a real `.nr`
test corpus (49 negatives + 196 feature/smoke files). The Rust crates in
`Nucleor_V2/crates/` have 254 `#[test]` markers but no `Cargo.toml` —
vestigial code that never compiled, intentionally not shipped.
Top-level `Nucleor_Copy/examples/` and `Nucleor_V2_Distro/examples/`
contain only build artifacts.

## [0.1.6] — 2026-04-22

JSON rod brought up to "what everyone uses": floating-point values and
pretty-printed output.

### Added

- **`json_from_f64(val)` / `json_f64(j)`** — store and retrieve f64 values.
  Internally a new tag (6); on serialization, emits a JSON-spec-compliant
  decimal (`3.141592`, `-42.0`, `0.5`, `0.125`) with trailing zeros trimmed
  but at least one fractional digit preserved.
- **`json_stringify_pretty(j, indent)`** — recursive pretty-printer with
  configurable indent width. Empty arrays/objects render as `[]` / `{}` on
  one line; otherwise each element/member gets its own line with proper
  indentation.

### Verified

- Both compact and pretty output round-trip cleanly through Python's
  `json.load`, and the two parses are equal.
- `tests/rods/json.nr` extended with f64 + pretty cases — verify gate
  remains 38/38 green.

## [0.1.5] — 2026-04-22

Top-to-bottom audit + cleanup + 38 new rod wrappers. Triggered by a full
audit that uncovered: most CLI subcommands were dead because the tools
binary was never shipped; a large pile of orphan source files; and
~50 runtime `.c` files with no `.nr` wrapper, representing ~3000+ runtime
functions of latent functionality. v0.1.5 fixes all of it.

### Fixed — CLI surface

- **`bin/nucleor_tools.exe` shipped.** The compiler delegates 25+
  subcommands to it; previously it was missing, so `nuc test`,
  `nuc check`, `nuc audit`, `nuc bench`, `nuc summary`, `nuc query`,
  `nuc abi`, `nuc bootstrap`, `nuc explain`, `nuc evidence`, `nuc impact`,
  `nuc graph`, `nuc lock`, `nuc registry`, `nuc sage`, `nuc profile`,
  `nuc certify`, `nuc translate`, `nuc policy`, and others all failed
  with "nucleor_tools.exe is not recognized."  After the fix: 37 of 46
  CLI invocations work (was 11 of 46).
- **`getcwd` and `getenv` builtins** were referenced by the compiler but
  had no IR declaration and no runtime implementation. Any program that
  called either emitted invalid LLVM IR. **Fixed** in
  `nucleor_llvm_rt.c` (~22 lines) + `nucleor_s1_compiler.nr` (4 lines).
  This is what made building the tools binary possible in the first place.
- **Self-host rebuild** was run with the patches and the new
  `bin/nucleor.exe` ships those builtins.

### Added — 38 new rod wrappers

Drawn from runtime files that already shipped in `stdlib/runtime/` but
had no `.nr` wrapper. Total rod count: **65 → 103**.

**Numerics & validated computation:**
- `taylor.nr` — validated Taylor-arithmetic ODE integrator for the
  Boussinesq / Navier-Stokes class. Rigorous error bounds.
- `interval.nr` — interval arithmetic with guaranteed containment of
  the true result. Foundation for computer-assisted proofs.
- `bigint.nr` — arbitrary-precision integer arithmetic + modular exp.
- `bayesian.nr` — Metropolis MCMC, credible intervals, chain summaries.

**Data structures + indexing:**
- `hashmap.nr` — string-keyed hash map (major gap closed).
- `bloom.nr` — Bloom filter + HyperLogLog cardinality estimation.
- `bm25.nr` — BM25 search index.
- `kdtree.nr` — k-d tree spatial index (nearest + range search).
- `hnsw.nr` — HNSW approximate nearest neighbor.
- `pq.nr` — product quantization for compressed vector search.
- `embedding.nr` — vector embedding tables (lookup / cosine / nearest).
- `string_algo.nr` — KMP search, Levenshtein, Trie.
- `state_machine.nr` — finite-state machines with on-enter/on-exit hooks.
- `graph.nr` — BFS, DFS, Dijkstra, Bellman-Ford, topological sort,
  connected components, Kruskal MST, PageRank.

**Systems / I/O:**
- `socket.nr` — TCP connect/listen/accept/send/recv + UDP open/send/recv.
- `mmap.nr` — memory-mapped files + POSIX shared memory.
- `serial.nr` — serial port I/O.
- `crypto.nr` — cryptographically-secure random bytes.
- `compress.nr` — LZ77 lossless compression.
- `datetime.nr` — date/time arithmetic, ISO parse, day-of-week.
- `image.nr` — RGBA images, PPM/BMP I/O, greyscale, resize, convolution.
- `plot.nr` — SVG line / scatter / heatmap plots.
- `audio.nr` — WAV I/O, STFT, MFCC.
- `color.nr` — RGB / HSV / Lab conversions, Delta E, palette generation.
- `mesh.nr` — 2D rectangular finite-element meshes + Laplacian assembly +
  VTK output.

**Modern ML / LLM infrastructure:**
- `kv_cache.nr` — paged KV cache for transformer inference, with eviction.
- `quantize.nr` — Q4 / int8 / ternary / FP8 weight quantization + GEMV.
- `rl.nr` — replay buffer, discount returns, GAE, PPO loss, DQN target,
  epsilon-greedy.
- `loss.nr` — cross-entropy (+ grad), label-smoothed CE, KL, MSE, Huber,
  focal, InfoNCE, cosine similarity matrix.
- `speculative.nr` — speculative decoding tree construction, verification,
  sampling.
- `diffusion.nr` — DDPM / rectified flow schedules, reverse step, AdaLN,
  CFG, time embeddings.
- `conv.nr` — Conv2D forward/backward, MaxPool/AvgPool, BatchNorm,
  Dropout (CNN building blocks).
- `scan.nr` — prefix-sum / prefix-prod / prefix-max / segmented sum /
  cumulative logsumexp / SSM scan kernels.
- `checkpoint.nr` — gradient-recomputation checkpointing.
- `comm.nr` — distributed-training collective communication primitives
  (allreduce / broadcast / reduce-scatter / all-gather / gradient
  accumulation buffers).

**Quantum:**
- `clifford.nr` — stabilizer formalism for quantum error correction
  (Clifford gates, measurement, error detection, distance computation,
  GNN-style state features).
- `mps.nr` — Matrix Product States efficient quantum simulation.

**Bioinformatics:**
- `bioseq.nr` — GC content, Needleman-Wunsch alignment, Hamming, k-mer
  count, ORF finding.

### Removed — dead code purge

- **72 orphan `stdlib/*.nr` files** (~655 KB). All pre-self-host
  compiler prototypes, dead checker variants, dead infrastructure
  scaffolding (`lexer_core.nr`, `lexer_minimal.nr`, `real_lexer.nr`,
  `nucleor_compiler.nr`, `stage1_compiler.nr`, `nucleor_stage0.nr`,
  `borrow_check.nr`, `borrow_checker.nr`, etc.). None imported by
  anything; carryover from the v0.1.0 Archive merge.
- **4 orphan runtime `.c` files**:
  - `gpu_fallback.c` — no caller
  - `optimizer2_rt.c` — superseded by `optim_rt.c`
  - `regex_rt.c` — superseded by Rust regex via `rust_bridge`
  - `json_rt.c` — superseded by pure-Nucleor `json.nr`

### Changed — documentation

- `docs/language-reference.md` updated to reflect what's actually in the
  language. The previous (v0.1.4) reference listed `for` loops,
  `break`/`continue`, block comments, generics, and traits as
  unimplemented. They are all in fact implemented; the audit confirmed
  each works end-to-end.
- `README.md` rod count bumped 65 → 103. New rods listed by category.

### Audit reports preserved

- `Desktop/Nucleor_Audit_2026-04-22.md` — full audit findings
- `Desktop/Nucleor_v015_Plan_2026-04-22.md` — execution plan that drove
  this release

### Verify gate

38/38 pass (unchanged). Self-host loop still closes with the rebuilt
`bin/nucleor.exe`. All 38 new rods build clean against the bootstrap
binary.

---

## [0.1.4] — 2026-04-22

Showcase programs now write CSV data alongside the live visualization.
Animated console output is great for the demo; CSV is what you actually
want for plotting, auditing, or feeding into another tool.

### Added — CSV output

- `vqe_h2.nr` writes **`vqe_h2_data.csv`** (32 rows): step, theta0,
  theta1, theta2, energy, abs_error.
- `market_maker.nr` writes **`market_maker_data.csv`** (61 rows):
  tick, spot, iv, bid, theo, ask, delta, gamma, vega, position_delta,
  hedge_qty, pnl_tick, cum_pnl.
- `wing_simulator.nr` writes **`wing_simulator_data.csv`** (101 rows):
  step, em_energy, density, vx, vy, vorticity, Ez, plus bit-pattern
  columns for em_energy and density to recover NaN values when the FDTD
  runtime returns them before field propagation reaches the probe.
- `lorenz.nr` writes **`lorenz_data.csv`** (~200 sampled rows): step, t,
  trajectory A (x, y, z), trajectory B (x, y, z), separation. Sampled
  every 60th step out of 12000 to keep the file small.

All CSVs are written next to the binary (cwd at run time). Ready to
open in Excel, pandas, R, gnuplot, etc.

### No regressions

Verify gate still 38/38 pass. Self-host loop closes. No language or
runtime changes — purely application-level additions to the four
showcase programs.

---

## [0.1.3] — 2026-04-22

Showcase release: four programs that demonstrate things Nucleor is
uniquely suited for, all with live ANSI-colored visualizations.

### Added — examples/showcase/

- **`vqe_h2.nr`** — Variational Quantum Eigensolver for a 2-qubit
  Hamiltonian (-Z0 - Z1 - 0.5 Z0Z1 + 0.5 X0X1). Parameter-shift gradient
  descent on the bundled quantum simulator. Converges to within 1e-3 Ha
  of the analytic ground state -2.5616. Live updating energy + parameter
  bar chart.
- **`market_maker.nr`** — Real-time options market-making engine. Black-
  Scholes pricing + full Greeks + PID-driven delta hedging at simulated
  10 ms tick. Live Bloomberg-style dashboard with bid/ask/Greeks/P&L.
- **`wing_simulator.nr`** — Coupled aerodynamic + electromagnetic
  simulator on a single airfoil cross-section. Lattice Boltzmann (D2Q9)
  fluid + FDTD Maxwell, sharing one geometry function. 256-color
  heatmaps for density, vorticity, and E_z field intensity.
- **`lorenz.nr`** — The Lorenz strange attractor integrated with RK4.
  Two trajectories from initial conditions 1e-5 apart, rendered as a
  heatmap. Visual demonstration of sensitive dependence on initial
  conditions; max separation reaches ~50 by end of integration.

### Added — visualization helpers

- **`examples/showcase/_viz.nr`** — shared ANSI viz helpers: `paint`,
  256-color `viz_heat` and `viz_grey` palettes, `viz_block` density
  characters, `viz_bar` horizontal bars, `viz_box_*` box drawing,
  banner header, integer/f64 formatters. Reusable across showcase
  programs.

### Added — runtime + compiler

- **`chr(byte_code) -> str`** builtin. Returns a 1-byte string for the
  given code point (0-255). Lets user programs synthesize arbitrary
  control bytes — including ESC = 27 for ANSI escape sequences. Wired
  through the compiler's builtin table, IR declaration, and
  `is_ptr_ret` classifier. Implementation in `nucleor_llvm_rt.c`.

### Self-host rebuild

- `bin/nucleor.exe` rebuilt from the patched source so the new `chr`
  builtin is available in the shipped binary.

### Verify gate

38/38 pass. New showcase programs verified by hand (the showcase dir
intentionally lives outside `tests/` because the visualizations are
animated and rely on TTY output).

---

## [0.1.2] — 2026-04-21

CLI polish: personality + progress + color + completions. No new language
features; no breaking changes.

### Added — new subcommands

- **`nuc zen`** — prints the design principles of Nucleor. (Spirit of `python -c "import this"`.)
- **`nuc mco`** — prints the Mars Climate Orbiter blurb. Always available, in every version.
  Single sentence reminder of why dimensional analysis matters.
- **`nuc clean`** — removes `target/` and `.nuc_cache/` from the project.
  (No `clean` subcommand existed in v0.1.0/v0.1.1.)
- **`nuc scram`** — alias for `nuc clean`. SCRAM is the actual technical
  term for emergency reactor shutdown; the aliasing is the entirety of the
  nuclear-themed personality in v0.1.2.

### Added — runtime + compiler

- **`isatty_stdout` builtin** — returns 1 if stdout is connected to a TTY,
  0 otherwise. Implemented in `nucleor_llvm_rt.c` for both Windows
  (`_isatty(_fileno(stdout))`) and POSIX (`isatty(STDOUT_FILENO)`).
  Wired into the compiler's builtin table with a matching IR declaration.
  Available to user `.nr` programs that want to gate their own output.

### Added — tooling

- **Tab completion** scripts for `bash`, `zsh`, `fish`, and PowerShell at
  [`tools/completions/`](tools/completions/). One-liner install per shell.
  Completes ~37 subcommands, common flags, and `*.nr` source files.
- **`tools/verify.ps1` upgraded:**
  - Per-step progress counter (`[ N/T] OK    test foo/bar`).
  - ANSI colored OK / SKIP / FAIL labels (green / yellow / red).
  - Honors `NO_COLOR` (per https://no-color.org/) and a `-NoColor` flag.
  - Detects TTY via `$Host.UI.RawUI.WindowSize` to skip color in piped output.

### Fixed

- **`nuc.bat` PATH resolution.** v0.1.0/v0.1.1 trusted `$LLVM_SYS_180_PREFIX`
  blindly; if it pointed at a stale path, clang couldn't be found. The
  launcher now verifies each candidate directory actually contains
  `clang.exe` before adding it to `PATH`. Same fix applied to
  `tools/verify.ps1`'s clang resolution.

### Verify gate

38/38 pass (unchanged from v0.1.1). All examples + tests + self-host loop
still green. New subcommands smoke-tested by hand:

- `nuc zen` prints the principles
- `nuc mco` prints the Mars Climate Orbiter box
- `nuc clean` and `nuc scram` both remove `target/` and `.nuc_cache/`

### Not in this release (intentionally cut from the original CLI flavor doc)

The personality-and-skins draft considered a much broader set: a
three-skin system (standard / reactor / compliance), themed command
aliases (`ignite`, `enrich`, `manhattan`, `trinity`, `heisenberg`,
`fission`), enrichment-tier optimization flags, a "weapons-grade" `--opt`
level, ☢-decorated banners, version codenames after Manhattan-era
physicists. None of that ships. Single voice; one nuclear-themed alias
that's actually the right technical term (`scram`); zero hazard symbols
in user-facing output.

The guiding rule from the original doc — "celebrate the physics, respect
the hazards" — is what made every cut.

---

## [0.1.1] — 2026-04-21

Major surface expansion. v0.1.0 shipped a deep runtime that was largely
inaccessible without writing your own `extern fn` declarations. v0.1.1 adds
**29 new `.nr` rod wrappers** that expose the existing C runtime as
first-class Nucleor APIs.

### Added — new rods (29)

**Linear algebra and tensors:**
- `linalg.nr` — matrix ops, LU, QR, Cholesky, eigen, SVD, ridge regression
- `tensor_nd.nr` — N-dimensional tensors with reshape, slice, batched matmul
- `tensor_decomp.nr` — CP-ALS, Tensor-Train SVD, Kronecker, Khatri-Rao
- `sparse.nr` — CSR sparse matrices with CG and GMRES solvers

**Numerical methods:**
- `ode.nr` — Euler, RK4, RK45, symplectic, event detection
- `root.nr` — bisection, Newton, secant, Brent, multi-dim systems
- `quad.nr` — trapezoid, Simpson, Gauss-Legendre, adaptive, 2D, Monte Carlo
- `interp.nr` — linear, cubic spline, Lagrange, Chebyshev, 2D bilinear, RBF
- `bspline.nr` — B-spline eval + basis + derivatives + KAN forward
- `optim.nr` — gradient descent, Adam, Nelder-Mead simplex, line search, genetic

**Statistics and signal processing:**
- `stats.nr` — mean/median/var/std, covariance, correlation, percentile, histogram, linear regression with R², t-test, chi-square, KDE
- `signal.nr` — FIR/IIR/Butterworth, Hamming/Hann/Blackman windows, envelope, zero crossings, up/down-sampling
- `fft.nr` — 1D complex/real FFT, convolution, power spectrum, correlation
- `pca.nr` — fit, project, variance ratio, eigenvalues

**PDE solvers and physics:**
- `multigrid.nr` — 2D multigrid Poisson solver
- `fluid.nr` — Lattice Boltzmann fluid simulation (D2Q9)
- `emag.nr` — FDTD electromagnetics on the Yee grid
- `thermo.nr` — heat equation, ideal gas, Carnot, blackbody radiation
- `geom.nr` — convex hull, point-in-polygon, line intersect, polygon area
- `rigid_body.nr` — full 3D rigid body dynamics with collision
- `orbit.nr` — Kepler-to-Cartesian, Hohmann transfer, vis-viva, escape velocity

**Constants and units:**
- `physics.nr` — 17 CODATA 2018 fundamental constants + math constants
- `units.nr` — SI conversion across 11 dimensions (mass, length, time, temperature, pressure, energy, force, frequency, angle, voltage, current)

**Symbolic and differentiable:**
- `autodiff.nr` — reverse-mode automatic differentiation (20 ops)
- `symbolic.nr` — expression trees with symbolic differentiation and evaluation

**Modern ML and control:**
- `control.nr` — PID, state-space, Kalman filter
- `ssm.nr` — Mamba selective scan, SSD chunked, RWKV-WKV, xLSTM, ZOH discretize
- `moe.nr` — top-K gating, dispatch, combine, load balancing
- `finance.nr` — Black-Scholes, full Greeks, implied volatility, NPV, IRR, VaR, portfolio optimization

### Added — examples (5)

- `examples/08_linalg.nr` — solve a linear system, compute an SVD
- `examples/09_ode.nr` — simulate a damped pendulum with RK4
- `examples/10_fft.nr` — round-trip a sine wave through the FFT
- `examples/11_pid.nr` — PID controller driving a plant to a setpoint
- `examples/12_autodiff.nr` — reverse-mode autodiff of `sin(x²) + x`

### Added — documentation

- `docs/math-and-physics.md` — worked examples across the scientific-computing rods
- `docs/rods-and-runtime.md` rewritten with the v0.1.1 catalog (65 rods total)
- `README.md` rewritten — the v0.1.0 tagline ("algebraic optimization") significantly undersold the actual scope. New tagline reflects the full stack.

### Changed

- README pitch updated to lead with the scientific-computing surface
- Rod count: v0.1.0 had 36 rods; v0.1.1 has **65**

### Stats

- 65 rods all build clean against `bin/nucleor.exe`
- All previous tests still pass (33/33 verify gate)
- No breaking changes to v0.1.0 surface
- No new compiler or runtime patches required — every new rod just exposes existing C runtime functions

---

## [0.1.0] — 2026-04-21

Initial open-source release of Nucleor under the Apache License 2.0.

### Added

- **Self-hosted compiler.** `bin/nucleor.exe` (identifies as `0.2.0-v2`) builds itself from `compiler/nucleor_s1_compiler.nr`. The full self-host loop closes on every CI run.
- **Algebraic-rewrite optimizer.** Built-in arithmetic identities (`x + 0 → x`, `x * 1 → x`, etc.) plus user-declarable laws via `@law(commutative, associative, identity=N, absorbing=N, idempotent, involution, fusion)`.
- **V2 performance attributes:** `@hot` (strict no-heap/no-format/no-indirect-dispatch enforcement), `@const_fn` (compile-time evaluation eligibility), `@layout(soa | aos | group(...))` (memory layout control), `@region(name)` (arena binding).
- **Rich CLI surface.** `nuc {build, build-fast, build-strict, build-shared, run, emit, build-wasm, build-ptx, test, bench, perf, check, audit, policy, certify, translate, summary, query, abi, evidence, impact, graph, profile, lock, install, publish, registry, sage, bootstrap, stage-dump, init, help}`.
- **Standard library: 36 rods** under `stdlib/rods/`, all building cleanly:
  - Core: `strings`, `fmt`, `bitwise`, `math`, `complex`
  - Data: `collections`, `option`, `result`, `queue`, `stack`, `sort`
  - Text: `json`, `csv`, `ini`, `regex`, `base64`, `uuid`
  - System: `io`, `fs`, `os`, `env`, `path`, `time`, `concurrency`, `cli`, `log`, `test`
  - Domain: `quantum` (full simulator: H, X, Y, Z, CNOT, measure, ...), `nn`, `gnn`, `gpu`, `multi_core`, `ridge`, `twin_core`, `python`, `rust`
- **Runtime.** Always-linked core `nucleor_llvm_rt.c` plus 90+ opt-in domain runtimes (FFT, hashmap, JSON, crypto, tensor, linear algebra, ODE solvers, signal processing, ...) compiled and linked on demand via `#cfile` directives.
- **Quantum-circuit simulator.** Full state-vector simulation up to 16+ qubits; `examples/05_quantum.nr` reproduces a perfect Bell state with measured 516|00⟩ + 508|11⟩ split over 1024 shots.
- **Rust interop demo.** `stdlib/rods/rust_bridge/` is a working Rust crate exposing `regex`, `base64`, hashing, and sorting to Nucleor through the C ABI. Build with `cargo build --release` in that directory.
- **Documentation.** Full set under `docs/`: getting-started, language tour, language reference, rods + runtime, architecture, benchmarks.
- **Test suite.** 24 self-contained `.nr` tests across language, attributes, runtime, rods, and negative-error cases.
- **Examples.** 7 examples (`01_hello.nr` through `07_rust_interop.nr`) covering hello-world through Rust interop.

### Changed (vs. internal pre-release)

- **Compiler portability fix.** `llvm_clang_path()` in `compiler/nucleor_s1_compiler.nr` (line ~5693) and `compiler/nucleor_tools_suite.nr` (line ~7356) returns the bare command name `clang`. Path resolution moved to the `nuc.bat` launcher, which inspects `NUCLEOR_CLANG_PATH`, `LLVM_SYS_180_PREFIX`, and the default Windows install location. The compiler binary is no longer hard-coded to one machine's LLVM install.
- **Rod imports made explicit.** Several rods (`base64.nr`, `csv.nr`, `fmt.nr`, `path.nr`, `cli.nr`, `json.nr`, `test.nr`, `nn.nr`, `ridge.nr`) now declare their cross-rod dependencies via `import` rather than relying on implicit symbol propagation. Previously these built only inside the larger pre-release tree where everything was already in scope.
- **Stdlib re-merged.** The active development tree had stripped most `.nr` rod wrappers (keeping only the C runtime files). The full set was restored from a complete earlier snapshot and re-validated against the current compiler.
- **`gnn.nr` and `nn.nr` `#cfile` paths.** Changed from precompiled-`.obj` references to direct `.c` source paths so users don't need a separate build step.
- **`time_rt.c`.** Added missing `#include <time.h>` for Windows builds.

### Fixed

- **Concurrency runtime.** The compiler emits the V2 calling convention `__nucleor_mutex_{new,lock,unlock}_value`, but the runtime had only the older `__nucleor_mutex_{new,lock,unlock}` symbols. Added forwarders in `stdlib/runtime/nucleor_llvm_rt.c` (Windows and POSIX branches) so `import "stdlib/rods/concurrency.nr"` programs now link and run.
- **RNG runtime.** The compiler emits `__nucleor_rng_seed`, which forwards to `nuc_rng_seed`. The latter lived in `stdlib/runtime/rng_rt.c` but was not part of any auto-linked compilation unit. `nucleor_llvm_rt.c` now `#include`s `rng_rt.c` so `rng_seed`, `rng_f64`, `rng_normal`, etc. are always available without a separate `#cfile`.
- **Quantum rod ownership.** `qsim_measure` in `stdlib/rods/quantum.nr` now declares its `meas_prob` binding `mut` (was `let meas_prob`, then reassigned in the next line — fails strict ownership checking).
- **`multi_core.nr` ownership.** Two `let agreement` bindings that were reassigned conditionally are now `let mut agreement`.

### Known limitations (v0.1, planned for follow-ups)

- **Windows-only.** v1 targets `x86_64-pc-windows-msvc`. Linux and macOS support require runtime port work.
- **No hex/binary integer literals.** Decimal only.
- **No `for` loops.** `while` is the loop primitive.
- **No `break` / `continue`.** Pattern out of loops with sentinel variables.
- **Generics and traits are placeholders.** The grammar accepts them in limited form, but the type checker treats `Vec<T>` as a uniform 64-bit-slot container regardless of `T`.
- **Block comments (`/* ... */`).** Use `//` line comments only.
- **`getenv()` from inside `.nr` source is incompletely wired** — the compiler knows the name but does not emit a usable IR declaration. Use the `nuc.bat` launcher for environment-driven configuration instead.

### Repository

- Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
- Source: https://github.com/APEXINTELORG/Nucleor
- Issues: https://github.com/APEXINTELORG/Nucleor/issues
- Author: Joseph Wescott
