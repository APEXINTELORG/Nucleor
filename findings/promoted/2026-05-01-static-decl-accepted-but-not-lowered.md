---
title: `static GREET: str = "hello";` is accepted at parse-time and type-check, but never produces an LLVM `@GREET` symbol. Use sites lower as `@GREET` references and fail at clang link with `error: use of undefined value '@GREET'`. Worse than parse-time rejection — the diagnostic is a non-actionable LLVM IR error far downstream from the source.
severity: silent-miscompute / wrong-error (accept-then-fail-far-downstream class)
probe_file: probes/parse/rust_syntax_audit/static_decl.nr (probe-branch)
diagnostic_actual: pre-fix — `target/p_static.ll:891:23: error: use of undefined value '@GREET'` (clang link), no Nucleor-side hint that `static` decls aren't supported.
diagnostic_expected: clean ERROR at parse-time pointing at workarounds (`const` for literal-init, fn-wrap for computed-init).
discovered_against: main v0.5.27 (probe rebased)
commit: probe (post-rebase) + main 74d9b0b
status: CLOSED in v0.6.21 (parse-time halt with workaround pointer; full `static` support deferred to forward-roadmap).
---

## Repro (now halts)

```nucleor
static GREET: str = "hello";

fn main() -> i32 {
    print(GREET);
    return 0;
}
```

Pre-v0.6.21: built and produced LL with `@GREET` reference; clang
link failed with `error: use of undefined value '@GREET'` deep in
the synthesized IR, no source-line attribution.

Post-v0.6.21: clean parse-time `ERROR: 'static' items are not yet
supported in Nucleor` + workaround pointer (use `const NAME: T =
VALUE;` for literals or wrap in a fn for computed values).

## Closure (main agent v0.6.21)

`compiler/nucleor_s1_compiler.nr` `parse_program` — added a check
when the current token is identifier `static` (no dedicated lexer
token, since `static` was previously silently consumed by the
module-item loop's catch-all advance branch). Emits a clean ERROR
pointing at the workarounds and panics.

The check sits next to the existing `let`-at-module-scope halt
(v0.4.79) and the statement-level-keyword-at-module-scope halt
(v0.3.75) — same loud-halt-with-workaround-pointer pattern.

## Adopter migration

```nucleor
// Pre-v0.6.21:
static GREET: str = "hello";

// v0.6.21:
const GREET: str = "hello";          // literal init — preferred
fn greet() -> str { return "hello"; } // computed init — fn-wrap
```

## Forward-roadmap (full `static` support)

Real `static` support requires:
- Module-scope mutable storage (writeable globals)
- Initialization-order discipline (lazy vs eager init)
- Thread-safety story (probably reuse the `atomic.nr` surface)
- Linker section discipline (BSS vs DATA vs RODATA)

Deferred to a future RFC; for now adopters use `const` (immutable),
atomics (mutable shared), or thread-local storage.

## Promoted

- Fixture: `tests/err/err_static_decl_not_supported.nr`.
- Fix shipped: v0.6.21 (clean halt; full support deferred).
- Promoted: 2026-05-02 PM by main agent (probe commit on
  `origin/probe/exploration`).
