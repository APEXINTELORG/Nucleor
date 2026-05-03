---
title: `print(s)` function-call form silently appends a newline (Rust `println!` semantics) while `print!(s)` macro form correctly does NOT (Rust `print!` semantics). Adopters writing canonical `print(x); print(y)` expecting concatenation get separate lines instead.
severity: silent-miscompute / API-naming-mismatch (translation-fidelity)
probe_file: probes/strings/print_fn_adds_newline.nr (probe-branch)
diagnostic_actual: pre-fix — `print(...)` appends newline; `print!(...)` macro does not
diagnostic_expected: parity (`print` matches `print!`)
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main f78d922
status: DOC-ONLY — divergence from Rust is intentional in v0.6 today. `print(s)` is the historical Nucleor convenience helper that includes a newline (matches the most common adopter expectation: "print this line"); `print!(s)` macro form preserves Rust no-newline semantics for explicit control.
---

## Closure (analysis-only — no compiler change)

The function-call vs macro-form divergence is unfortunately
visible in the API surface, but it's been the Nucleor v0.6
convention since the runtime helper landed. Switching the
function form to "no newline" would silently break:

- Every existing fixture using `print("foo")` expecting a
  newline (the dominant adopter pattern in
  `tests/fixtures/`).
- Every example in `examples/` that calls `print(s)` for
  human-readable line output.
- The compiler self-host (which uses `print` extensively for
  diagnostics and progress messages, all expecting newline
  termination).

The API surface today:

| Form | Adds newline? | Maps to |
|---|---|---|
| `print(s)` (fn) | YES | `__nucleor_print` (newline-included) |
| `print!(s)` (macro) | NO | `__nucleor_print_raw` |
| `println(s)` (fn) | YES (alias for `print`) | same as `print` |
| `println!(s)` (macro) | YES | newline-emitting variant |
| `print_raw(s)` (fn) | NO | `__nucleor_print_raw` |

Adopters porting from Rust who need precise no-newline
behavior have three working forms today: `print!(s)`,
`print_raw(s)`, or building the line via `sb_*` and calling
`print` once at the end.

## Adopter migration

```nucleor
// "print three letters concatenated, no newlines between":
print!("A");
print!("B");
print!("C");
// → output: "ABC" (no newline, no separator)

// or equivalently:
print_raw("A");
print_raw("B");
print_raw("C");

// "print three lines":
print("AAA");          // current default — adds newline
print("BBB");
print("CCC");
// → output: "AAA\nBBB\nCCC\n"
```

## Forward-roadmap

A future v1 API alignment pass could rename the function form to
`println` (matching the newline behavior) and add a `print` fn
variant matching `print!` macro semantics. That's a documented
breaking change requiring an adopter migration cycle, so it's
deferred until the v1 boundary.

## Promoted

- No code change in v0.6.50 batch.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
