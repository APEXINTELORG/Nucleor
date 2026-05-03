---
title: `#[cfg(...)]` attribute silently dropped from declarations. BOTH branches of `#[cfg(target_os="X")] fn foo()` + `#[cfg(not(target_os="X"))] fn foo()` are emitted, producing a "duplicate pub fn" PANIC that hides the real issue (cfg unprocessed). Test-only `#[cfg(test)]` items leak into release builds. Cross-platform Rust translation produces unbuildable Nucleor.
severity: silent-miscompute (translation-fidelity, build-system semantic)
probe_file: probes/parse/rust_syntax_audit/cfg_attribute.nr (probe-branch)
diagnostic_actual: pre-fix — paired-cfg case → `PANIC: duplicate pub fn name across modules: os_name`. Single-cfg case → builds, function emitted unconditionally with no warning.
diagnostic_expected: clean parse-time ERROR pointing at workarounds (manually delete inactive branch / move test-only code out / wait for cfg-evaluation ship).
discovered_against: main v0.5.26 (probe rebased)
commit: probe (post-rebase) + main 0684d57
status: CLOSED in v0.6.25 via clean parse-time halt + workaround pointer. Real cfg-evaluation deferred to a post-v0.6 RFC.
---

## Closure (main agent v0.6.25)

`compiler/nucleor_s1_compiler.nr` lex-time `#[...]` consumer — added a
detection at the top of the attribute-skip block. When `str_eq_at(src,
p+2, "cfg")` matches AND the next character is `(` (= `#[cfg(`) or `_`
(= `#[cfg_attr`), emit a clean ERROR with workaround pointer and panic.

Other attributes (`#[no_alloc]`, `#[deadline]`, `#[isr]`, `#[max_depth]`,
etc.) flow through unchanged via the existing silent skip.

## Adopter migration

```nucleor
// Pre-v0.6.25 (silent-drop + duplicate-fn PANIC):
#[cfg(target_os="windows")]
fn os_name() -> str { "windows" }

#[cfg(not(target_os="windows"))]
fn os_name() -> str { "other" }

// v0.6.25 workarounds:
// (a) For cross-platform code: manually delete the inactive branch
//     before building.
// (b) For test-only code: gate behind a runtime flag, or move to
//     a separate `_test.nr` file that isn't imported in release.
// (c) Wait for the future cfg-evaluation ship.
```

## Side-effect: `tests/lang/hash_attributes.nr` updated

The fixture had a `#[cfg(target_os = "linux")]` line from the v0.2.x
era when the lexer silently accepted everything. v0.6.25 hard-rejects
this — fixture updated to drop the cfg line. Other attrs (#[test],
#[no_alloc], #[no_panic], #[deadline]) remain in the positive test
because they're still silently consumed.

## Forward-roadmap (full cfg-evaluation)

Real `#[cfg(...)]` evaluation requires:
- A cfg-context (target_os, target_arch, feature flags, profile, ...).
- Recursive cfg-expression evaluator (`not`, `any`, `all`).
- Parse-time pruning so only the matching branch reaches type-check.

Deferred to a post-v0.6 RFC.

## Promoted

- Fixture: `tests/err/err_cfg_attribute_not_supported.nr` (negative).
- Side-effect: `tests/lang/hash_attributes.nr` updated.
- Fix shipped: v0.6.25.
- Promoted: 2026-05-02 NIGHT by main agent (probe commit on
  `origin/probe/exploration`).
