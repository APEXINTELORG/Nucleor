---
title: `struct U;` (canonical Rust unit-struct syntax) fails parse with `error[NR020]: expected '{', got ';'`. Only `struct U {}` (empty-braces form) works. Translators producing Nucleor from Rust hit this constantly because `struct Marker;` is canonical Rust.
severity: wrong-error / parser-gap (translation-fidelity hazard)
probe_file: probes/parse/unit_struct_semi.nr (will be filed)
diagnostic_actual: `PANIC: error[NR020]: parse error at byte 8: expected '{', got ';'.`
diagnostic_expected: build succeeds — `struct U;` and `struct U {}` are both valid unit-struct declarations (matching Rust)
discovered_against: main v0.5.24 (probe rebased)
commit: probe (post-rebase) + main 71330cf
---

## Repro

```nr
struct U;                       // ← FAILS: expected '{', got ';'
fn main() -> i32 {
    let u: U = U;
    print_int(0);
    0
}
```

vs. the workaround that works:

```nr
struct U {}
fn main() -> i32 {
    let u: U = U {};
    print_int(0);
    0
}
```

## Actual

```
PANIC: error[NR020]: parse error at byte 8: expected `{`, got `;`.
```

The diagnostic is clean and accurate. The fix is to accept the semicolon-form unit-struct in `parse_struct_decl`.

## Discovery context

Hit while probing the `Greet`/`P` trait + default-method shape:

```nr
trait Greet {
    fn name(self: &Self) -> str;
    fn hello(self: &Self) -> str { str_concat("hello, ", self.name()) }
}
struct P;                               // ← parse-fail HERE
impl Greet for P { fn name(self: &P) -> str { "world" } }
```

Switching `struct P;` → `struct P {}` makes the rest work end-to-end (default method `hello()` returns `"hello, world"` ✓; trait + default method machinery is sound — the parser is the only gap).

## Hazard tier

**Translation-fidelity hazard for Nucleor_Translate.** The translator project (per memory) targets Rust → Nucleor. Rust's canonical unit-struct is `struct Foo;`. Every Rust file with a marker type or zero-size newtype hits this. Adopters can workaround manually, but the translator output is intended to be turn-key — every `struct Foo;` in input source produces a broken Nucleor file.

Sister with `2026-05-01-keyword-silent-strip-audit.md` family — both are translation-fidelity gaps that bite Rust→Nucleor pipelines disproportionately.

## Suspected fix

In `compiler/nucleor_s1_compiler.nr` `parse_struct_decl` (or wherever `struct NAME` parses): after consuming the name, lookahead — if next token is `;`, accept as unit-struct (zero fields, no body); else expect `{`.

Construction site: also need `let u: U = U;` (no braces) to parse as a value-of-unit-type expression. Currently `U` is a path expression — already valid, but unit-struct construction with `U` (no `{}`) needs the type-checker to recognize it as the unit-struct's value form.

Both fixes likely co-located (parse + value-form). Estimated 1-shape parse-rule addition + 1 value-form recognition.

## Cross-ref

- `2026-05-01-keyword-silent-strip-audit.md` — sister translation-fidelity gap
- v0.5.19 ASYNC-001 — sister parse-time keyword/syntax gap
- Nucleor_Translate project memory — this gap multiplies by every Rust-source `struct Foo;` in the translator's training corpus

## Probe

`probes/parse/unit_struct_semi.nr` — minimal repro.
`probes/parse/unit_struct_braces.nr` — workaround that compiles cleanly.


## Promoted

- Fix shipped: v0.5.28 — `parse_struct_decl` now accepts `;`
  after the optional generic params (token 43 = SEMI).
- Both `struct U;` and `struct U {}` lower to the same
  kind-33 empty-fields decl with the same gparams list.
- Construction still requires `U {}` value form. Bare-ident
  unit-struct construction is a follow-up (probe may re-file
  if blocking adopters).
- 5-line edit at `compiler/nucleor_s1_compiler.nr:2560`.
- Round-1 == round-2 IR fixed-point preserved.
- Promoted: 2026-05-01 by main agent (probe commit 71330cf).
