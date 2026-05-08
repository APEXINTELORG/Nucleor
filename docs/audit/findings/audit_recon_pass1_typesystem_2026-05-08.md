# Recon Audit Pass 1 — Layer 2: Type System

**Date:** 2026-05-08
**Compiler:** Nucleor v1.0.0 (self-hosted, llvm backend)
**Project:** `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_r05_with_row_v0842`
**Scope:** Type inference, generics, traits, trait bounds, where-clauses, type errors, coercions, pattern type-checking.

## Summary

| Severity | Count |
|---|---|
| Critical | 4 |
| High     | 12 |
| Medium   | 6 |
| Low      | 2 |
| Note     | 4 |

## Coverage Map

| Axis | Items checked | Items skipped | Reason |
|---|---|---|---|
| Functional   | generic fn, generic struct, generic enum, trait decl/impl, default methods, where clauses, struct field type-check, enum-payload type-check, return-type, arg-type, match-arm types, if-branch types, struct field add/missing/extra, return type | const-generics | known-unsupported (parser PANIC at `<const N: usize>`) |
| Edge         | empty `<>` params, zero-method trait, zero-variant enum, deeply nested 10-level Vec, 16 type params, recursive struct (direct), mutually recursive struct, generic self-referential struct, redundant `<T: Foo + Foo>` |  |  |
| Adversarial  | duplicate `<T, T>`, duplicate impl Trait for Type, two traits same method (E0034), conflicting bounds, unbound type-name in where, contradictory where bound, recursive generic call, circular default trait methods, shadow primitive `<i64>` |  |  |
| AttackSurface| 50-trait where chain, 10-instantiation generic, deep nesting, mono explosion attempt | none, type-erasure model bounds the surface | |
| Diagnostic   | unknown type in param, unknown method on struct, integer-literal range, ambiguous trait dispatch, span pointing, narrowing cast loss | none |  |
| Composition  | generic × ownership (use-after-move), generic × default-method chain |  |  |
| Inference    | let with no annotation on generic-call result, ambiguous T (no constraint), int-literal width adaptation, i32→i64 widening, i64→i32 narrowing, int→f64, str/i64 erasure |  |  |

Audit reproducers live in `audit_scratch_typesystem/`. All compile invocations use:
`bin/nucleor.exe build audit_scratch_typesystem/<name>.nr -o target/<name>.exe`.

## Findings

### F-001 [High] [Functional] Generic struct/fn type-parameter arity is not enforced

**Reproducers:** `audit_scratch_typesystem/f002_wrong_arity_generic.nr`, `f003_three_args.nr`
```nr
struct Pair<A, B> { first: A, second: B }
fn main() -> i32 {
    // Pair<A,B> declared, constructed with 1 type arg ...
    let p: Pair<i32> = Pair<i32> { first: 10, second: 20 };
    print_int(p.first + p.second);  // prints 30
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f002_wrong_arity_generic.nr -o target/f002.exe`
**Observed:** Exit 0, runs and prints `30`. F003 (three type args) likewise compiles cleanly.
**Expected:** TYP-`<arity>` rejecting wrong number of type arguments — Rust E0107 ("wrong number of type arguments: expected 2, found 1").
**Remediation:** In `compiler/nucleor_s1_compiler.nr`, the type-form parser at the use site (let-type, `Pair<...>` in struct construction) does not cross-check declared type-param count from the struct decl. Add an arity check in the type-name resolution path (search for the place that consumes `<...>` after a struct/enum name in type position — the same spot that builds the substitution map). Add `tests/err/err_generic_arity_mismatch.nr` with `Pair<i32>` and `Pair<i32, i32, i32>`. Note that under the type-erasure model the wrong-arity uses do not cause runtime corruption directly, but they break the next layer when monomorphization ships (RFC text in the compiler at line ~28040 already flags type-erasure as transitional).

---

### F-002 [Critical] [Functional / Inference] Silent miscompile — pattern-matching one enum's value against another enum's variants is accepted

**Reproducer:** `audit_scratch_typesystem/f017_pattern_wrong_enum.nr`
```nr
enum A { Red, Blue }
enum B { On, Off }

fn main() -> i32 {
    let a: A = A::Red;
    let r: i64 = match a {
        B::On  => 1,
        B::Off => 2,
    };
    print_int(r as i32);  // prints 1 (silently)
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f017_pattern_wrong_enum.nr -o target/f017.exe`
**Observed:** Compiles cleanly, runs, prints `1`. Match arms reference variants of enum `B` while scrutinee is enum `A`, but lowering treats both as integer tags so `A::Red` (tag 0) silently matches `B::On` (tag 0).
**Expected:** TYP-`<arm_pattern_type_mismatch>` — pattern variant must belong to the scrutinee's enum type. Rust E0308 / E0532.
**Remediation:** In `compiler/nucleor_s1_compiler.nr`, the match-arm type-checker (search `match_arm` / `pattern` near `MATCH-` diagnostics, also near `infer_user_variant_binding_type` ~line 36492) compares scrutinee and arm pattern **integer tags** but not enum identities. Before lowering, resolve each `Path::Variant` pattern to its declaring enum and unify with the scrutinee enum's name; emit a new TYP code on mismatch. Add `tests/err/err_match_pattern_wrong_enum.nr` mirroring this reproducer. This is currently a silent miscompile at runtime — high severity.

---

### F-003 [Critical] [Composition / Functional] Silent narrowing — `let b: i32 = a;` accepted for `a: i64` and truncates to low 32 bits without diagnostic

**Reproducer:** `audit_scratch_typesystem/f043_i64_to_i32.nr`
```nr
fn main() -> i32 {
    let a: i64 = 1234567890123;
    let b: i32 = a;        // narrowing without `as`
    print_int(b);          // prints 1912276171 (low 32 bits)
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f043_i64_to_i32.nr -o target/f043.exe`
**Observed:** Exit 0; runtime prints `1912276171` (silent truncation).
**Expected:** TYP-008 mismatch (per language reference §2: "Numeric primitives are not implicitly converted between widths"), or NUM-003 escalated to error.
**Remediation:** The let-binding type-check (search for `TYP-008` emission) accepts a wider integer to a narrower binding. Add explicit width comparison and reject (or downgrade with an opt-in `#[allow(implicit_narrow)]` only — but the spec says no implicit widening at all). Add `tests/err/err_implicit_int_narrow.nr` and `tests/err/err_implicit_int_widen.nr` (see F-004).

---

### F-004 [High] [Coercion] Silent widening — `let c: i64 = a;` accepted for `a: i32`

**Reproducer:** `audit_scratch_typesystem/f020_integer_literal_default.nr`
```nr
fn main() -> i32 {
    let a: i32 = 1;
    let b: i64 = 2;
    let c: i64 = a;          // i32 → i64 implicit
    print_int((b + c) as i32);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f020_integer_literal_default.nr -o target/f020.exe`
**Observed:** Exit 0; prints `3`.
**Expected:** Spec §2 says "Numeric primitives are not implicitly converted between widths." Either reject, or document the exception.
**Remediation:** Same site as F-003. Add the symmetric reject for `wider_decl < rhs_width`. Either make the spec match (add a paragraph permitting widening) or fix the checker — pick one, but both surfaces (F-003 and F-004) must agree.

---

### F-005 [High] [Functional] Silent acceptance of `let f: f64 = 3` (int literal binding to f64)

**Reproducer:** `audit_scratch_typesystem/f021_float_int_mix.nr`
```nr
fn main() -> i32 {
    let f: f64 = 3;        // int literal, declared f64
    print_int(0);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f021_float_int_mix.nr -o target/f021.exe`
**Observed:** Compiles cleanly. The integer literal `3` is bit-stored into the f64 slot; the language reference says f64 is i64-bitcast through the C ABI but a literal `3` is not `3.0`.
**Expected:** TYP-008 type mismatch (no implicit int-to-float coercion), or require `3 as f64` / `3.0`.
**Remediation:** Same let-binding type-check as F-003/F-004. Reject when LHS is `f64` and RHS literal/expr is integer-typed. Add `tests/err/err_int_literal_to_f64.nr`.

---

### F-006 [Critical] [Functional] Generic enum payload not type-checked against type argument

**Reproducer:** `audit_scratch_typesystem/f023_generic_enum_payload_check.nr`
```nr
enum Holder<T> { Some(T), None }

fn main() -> i32 {
    let h: Holder<i64> = Holder::Some("hello");  // str → i64 slot
    print_int(0);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f023_generic_enum_payload_check.nr -o target/f023.exe`
**Observed:** Compiles cleanly. The string pointer is silently stored where the i64 is expected.
**Expected:** TYP-006 / new TYP code for variant-payload type mismatch.
**Remediation:** In the variant-construction lowering (search the call site that resolves `EnumName::Variant(...)` to the variant's payload-type list — likely near `infer_enum_variant_payload_type` ~line 36585), once a binding-type is known (the user wrote `let h: Holder<i64>`) substitute the type-param map and check each payload arg against the substituted payload type. Add `tests/err/err_generic_enum_payload_mismatch.nr`.

---

### F-007 [Critical] [Functional] Generic struct field type not enforced after instantiation

**Reproducer:** `audit_scratch_typesystem/f045_pair_field_access_wrong_type.nr`
```nr
struct Pair<A, B> { first: A, second: B }

fn main() -> i32 {
    let p: Pair<i64, str> = Pair<i64, str> { first: 10, second: "hi" };
    let s: i64 = p.second;   // p.second is str under the instantiation, declared i64 here
    print_int(0);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f045_pair_field_access_wrong_type.nr -o target/f045.exe`
**Observed:** Compiles cleanly.
**Expected:** TYP-008 binding type mismatch — field access of `Pair<i64, str>::second` is `str`, not `i64`.
**Remediation:** Generic struct fields whose declared type is a type-parameter are not propagating the substitution at field-access checking. Hook the field-access type-checker to the struct's declared param list and the use-site instantiation (the binding's annotation already carries `<i64, str>`). Same area as F-001 / F-006. Add `tests/err/err_generic_struct_field_substitute.nr`.

---

### F-008 [High] [Functional] Generic struct field initializer type not checked at construction

**Reproducer:** `audit_scratch_typesystem/f024_generic_struct_field_init_mismatch.nr`
```nr
struct Pair<A, B> { first: A, second: B }
fn main() -> i32 {
    let p: Pair<i32, i32> = Pair<i32, i32> { first: "x", second: 20 };
    print_int(p.second);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f024_generic_struct_field_init_mismatch.nr -o target/f024.exe`
**Observed:** Exit 0, builds clean. (Concrete-struct equivalent F-032 correctly emits TYP-008.)
**Expected:** TYP-008 struct-field type mismatch (parity with concrete structs at f032).
**Remediation:** Same fix as F-001 / F-007. Once the type-param map is built at construction site, every field initializer must be checked against the substituted field type. Add `tests/err/err_generic_struct_field_init.nr`.

---

### F-009 [High] [Functional] Trait impl missing required method (no default body) is silently accepted

**Reproducer:** `audit_scratch_typesystem/f036_impl_missing_method.nr`
```nr
trait Foo {
    fn one(self) -> i64;
    fn two(self) -> i64;
}
struct P { v: i64 }
impl Foo for P {
    fn one(self) -> i64 { self.v }
    // `two` not implemented, no default body in trait
}
fn main() -> i32 {
    let p: P = P { v: 5 };
    print_int(p.one() as i32);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f036_impl_missing_method.nr -o target/f036.exe`
**Observed:** Exit 0, compiles clean.
**Expected:** TYP-`<impl_missing_method>` — Rust E0046.
**Remediation:** In `compiler/nucleor_s1_compiler.nr`, the impl-block walker needs a coverage check: for each method declared in the trait without a default body, ensure the impl has it. Search for `parse_trait_decl` (line 4594) and the impl-collection pass; cross-reference at typeck time. Add `tests/err/err_impl_missing_method.nr`.

---

### F-010 [High] [Functional] Trait impl signature mismatch silently accepted

**Reproducer:** `audit_scratch_typesystem/f038_impl_signature_mismatch.nr`
```nr
trait Foo { fn op(self, x: i64) -> i64; }
struct P { v: i64 }
impl Foo for P {
    fn op(self, x: str) -> i64 { self.v }   // wrong arg type
}
fn main() -> i32 {
    let p: P = P { v: 5 };
    print_int(p.op("hi") as i32);
    0
}
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f038_impl_signature_mismatch.nr -o target/f038.exe`
**Observed:** Exit 0.
**Expected:** TYP-`<impl_signature>` — Rust E0053.
**Remediation:** Same coverage walk as F-009; for each method in trait, also check param types and return type match. Add `tests/err/err_impl_signature_mismatch.nr`.

---

### F-011 [High] [Functional] Trait impl with extra (non-trait) method silently accepted

**Reproducer:** `audit_scratch_typesystem/f037_impl_extra_method.nr`
```nr
trait Foo { fn one(self) -> i64; }
struct P { v: i64 }
impl Foo for P {
    fn one(self) -> i64 { self.v }
    fn extra(self) -> i64 { 42 }    // not in Foo
}
```
**Observed:** Exit 0; the orphan `extra` is silently part of the impl block.
**Expected:** TYP-`<impl_extra_method>` — Rust E0407 ("method `extra` is not a member of trait `Foo`").
**Remediation:** Same impl-block walker; the symmetric check (every impl method must be declared in the trait, modulo defaults). Note: inherent impls may relax this once supported. Add `tests/err/err_impl_extra_method.nr`.

---

### F-012 [High] [Edge] Mutually recursive structs accepted (infinite size, F015 single-node version is rejected)

**Reproducer:** `audit_scratch_typesystem/f016_mutual_recursive_struct.nr`
```nr
struct A { b: B, v: i64 }
struct B { a: A, w: i64 }
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f016_mutual_recursive_struct.nr -o target/f016.exe`
**Observed:** Compiles clean.
**Expected:** NR036 / E0072 — recursive type with infinite size. The existing direct-recursion check (F015 catches `Node { next: Node }`) does not extend to cycles of length > 1.
**Remediation:** The recursive-struct detector (search for `NR036` and `recursive struct`) only walks one level. Replace with a multi-struct cycle detector — depth-first cycle search across the struct dependency graph keyed on direct (non-Box/Vec/`*`) field types. Add `tests/err/err_mutually_recursive_struct.nr`.

---

### F-013 [High] [Edge] Generic self-referential struct `Wrap<T> { inner: Wrap<T> }` accepted

**Reproducer:** `audit_scratch_typesystem/f056_struct_using_generic_param.nr`
```nr
struct Wrap<T> { inner: Wrap<T> }
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f056_struct_using_generic_param.nr -o target/f056.exe`
**Observed:** Compiles clean.
**Expected:** Same NR036 family as F015; generic type with self-referential field of same instantiation has infinite size.
**Remediation:** Extend the recursive-struct detector (per F-012) to compare field types modulo type-parameter substitution: a field whose normal-form type equals the enclosing struct's normal-form type is a cycle. Add `tests/err/err_recursive_generic_struct.nr`.

---

### F-014 [High] [Adversarial] Where-clause references a type variable not in the fn type-parameter list

**Reproducer:** `audit_scratch_typesystem/f049_trait_self_unbounded_other.nr`
```nr
trait Foo { fn foo(self) -> i64; }
fn run<T>(x: T) -> i64 where U: Foo { 0 }   // U is not a type-param of run
fn main() -> i32 { print_int(0); 0 }
```
**Observed:** Compiles clean.
**Expected:** A diagnostic — `unknown type-parameter U in where clause`.
**Remediation:** When parsing/validating where clauses (search `parse_generic_params` line 3185 and the where-clause sibling), verify each LHS identifier appears in the type-param list of the enclosing fn/struct/impl. Add `tests/err/err_where_unknown_type_param.nr`.

---

### F-015 [High] [Adversarial] Duplicate type-parameter names `<T, T>` silently accepted

**Reproducer:** `audit_scratch_typesystem/f011_duplicate_type_param.nr`
```nr
fn dup<T, T>(x: T, y: T) -> T { x }
```
**Observed:** Compiles clean.
**Expected:** Diagnostic — Rust E0403 ("the name `T` is already used").
**Remediation:** In `parse_generic_params` (line 3185), keep a set of already-seen names and emit on duplicate. One-line fix essentially. Add `tests/err/err_duplicate_type_param.nr`.

---

### F-016 [High] [Adversarial] Generic param name shadowing a primitive (`<i64>`) silently accepted

**Reproducer:** `audit_scratch_typesystem/f057_uppercase_lowercase.nr`
```nr
fn use_it<i64>(x: i64) -> i64 { x }
```
**Observed:** Compiles clean.
**Expected:** Diagnostic — type-param name must not collide with a built-in / primitive.
**Remediation:** Same parser site as F-015. Reject when param identifier matches the primitive set (`i64`, `i32`, `i16`, `i8`, `u*`, `f64`, `bool`, `str`, `void`). Add `tests/err/err_type_param_shadows_primitive.nr`.

---

### F-017 [Medium] [Edge] Empty `<>` type parameter list is silently accepted on fn and struct

**Reproducer:** `audit_scratch_typesystem/f012_empty_type_params.nr`
```nr
fn nothing<>() -> i64 { 7 }
struct Z<> { v: i64 }
```
**Observed:** Compiles clean. Empty `<>` is meaningless syntax.
**Expected:** A parse-time warning or rejection — Rust accepts `<>` as a no-op but most languages reject. Either way, document.
**Remediation:** Same parser site as F-015 / F-016. Decide policy and either tolerate (with warning that user probably meant a list) or reject. Low priority — cosmetic.

---

### F-018 [High] [Inference] Ambiguous inference accepted: `let v = make()` where `make` returns `Vec<T>` with no constraint

**Reproducer:** `audit_scratch_typesystem/f019_ambiguous_inference.nr`
```nr
fn make<T>() -> Vec<T> { Vec<T>::new() }
fn main() -> i32 {
    let v = make();      // T is unconstrained
    print_int(0);
    0
}
```
**Observed:** Compiles clean.
**Expected:** TYP-`<ambiguous_inference>` — Rust E0282 ("type annotations needed").
**Remediation:** When binding has no type annotation and RHS is a call to a generic fn whose return type contains an unbound type variable, demand annotation. Search for `infer_var_type_from_source` (line 37115) and the let-binding entry point. Add `tests/err/err_ambiguous_generic_inference.nr`.

---

### F-019 [Critical] [Adversarial] Compiler PANICs (stack-trace-style abort) on duplicate impl + ambiguous trait method instead of clean diagnostic

**Reproducers:** `audit_scratch_typesystem/f014_duplicate_impl.nr`, `f051_method_ambig.nr`
```nr
trait Foo { fn foo(self) -> i64; }
struct P { v: i64 }
impl Foo for P { fn foo(self) -> i64 { self.v } }
impl Foo for P { fn foo(self) -> i64 { self.v + 100 } }
```
**Command:** `bin/nucleor.exe build audit_scratch_typesystem/f014_duplicate_impl.nr -o target/f014.exe`
**Observed:**
```
ERROR: ambiguous method `P::foo()` ...
PANIC: ambiguous method dispatch: P__foo
```
**Expected:** A clean diagnostic with code (TYP-`<conflicting_impl>` / E0119) and a non-zero exit, not a `PANIC`. The condition is detected; the way it's reported is the bug. The trailing PANIC produces an exit code that downstream tooling cannot distinguish from an internal compiler error.
**Remediation:** Replace the `panic("ambiguous method dispatch: ...")` call with a proper diagnostic emission and exit. Search for the string "ambiguous method dispatch" in `compiler/nucleor_s1_compiler.nr`. Same pattern likely repeats elsewhere (PANIC used for user errors); audit and convert. Add `tests/err/err_duplicate_impl_block.nr` and `tests/err/err_two_traits_same_method_name.nr` once converted.

---

### F-020 [High] [Diagnostic] Compiler PANICs on `let EnumPath::Variant(a, b) = expr;` (let-pattern destructure) instead of "unsupported syntax" diagnostic

**Reproducer:** `audit_scratch_typesystem/f035_let_pattern_destructure.nr`
```nr
enum Pair { P(i64, i64) }
fn main() -> i32 {
    let p: Pair = Pair::P(10, 20);
    let Pair::P(a, b) = p;
    print_int((a + b) as i32);
    0
}
```
**Observed:**
```
PANIC: error[NR020]: parse_primary cannot start an expression at token kind 46 ...
```
**Expected:** A clean "feature not supported" diagnostic pointing at the `let` site, or actually support the pattern in `let`. Currently `if let` and `while let` are supported but bare `let` is not.
**Remediation:** In the parser (search `parse_primary`), handle the `let <Path::Variant>(...) = ...` form with a dedicated diagnostic ("let destructure unsupported — use `if let`"). The PANIC is wrong-class. Add `tests/err/err_let_pattern_destructure_unsupported.nr`.

---

### F-021 [High] [Diagnostic] Method-call diagnostic on a struct misreports receiver type as `Vec<T>` and lists Vec methods

**Reproducer:** `audit_scratch_typesystem/f033_method_call_no_impl.nr`
```nr
struct P { v: i64 }
fn main() -> i32 {
    let p: P = P { v: 5 };
    let r: i64 = p.does_not_exist();   // P has no impl block at all
    print_int(0);
    0
}
```
**Observed:**
```
error[TYP-005]: receiver type `Vec<T>` has no method `.does_not_exist()` ...
Supported Vec method families: push, pop, len, ...
```
**Expected:** Receiver should be reported as `P`, and the diagnostic should suggest defining an `impl ... for P` block. The current message blames `Vec<T>` which the user did not use, severely confusing.
**Remediation:** Search for the `TYP-005` emission for "receiver type" — it appears to default to `Vec<T>` when struct-method dispatch fails to find any candidate. Plumb the actual receiver type through. Add `tests/err/err_method_on_struct_with_no_impl.nr`.

---

### F-022 [Medium] [Adversarial] Circular default trait methods accepted with no warning (runtime stack overflow)

**Reproducer:** `audit_scratch_typesystem/f048_circular_trait_default.nr`
```nr
trait Circ {
    fn a(self) -> i64 { self.b() }
    fn b(self) -> i64 { self.a() }
}
struct P { v: i64 }
impl Circ for P {}
```
**Observed:** Compiles clean. At runtime would stack-overflow (not exercised here to avoid OS dialog).
**Expected:** A warning or error — at least one of the trait's default methods must terminate the recursion when the impl provides nothing. Some of this is undecidable in general, but the specific case "two-method cycle, neither overridden by impl" is statically detectable.
**Remediation:** When emitting the synthesis fn from a trait default body (compiler comment near line 34320 mentions this), build a call graph of defaults; for each impl that overrides nothing, walk the graph and reject closed cycles. Medium priority — runtime symptom is a stack overflow which the OS reports (less dangerous than a silent miscompile). Add `tests/err/err_circular_default_trait_methods.nr`.

---

### F-023 [Medium] [Functional] Match arms produce different types — accepted

**Reproducer:** `audit_scratch_typesystem/f027_arm_type_mismatch.nr`
```nr
enum E { A, B, C }
fn main() -> i32 {
    let e: E = E::A;
    let r: i64 = match e {
        E::A => 1,
        E::B => "two",        // str arm in i64 context
        E::C => 3,
    };
    print_int(0);
    0
}
```
**Observed:** Compiles clean and runs (prints 0, but the binding `r` would carry mixed types if E::B were taken).
**Expected:** The existing `MATCH-011` diagnostic catches the int-scrutinee with str-pattern shape. The dual case — heterogeneous **arm RHS** types — is not covered. Should be a TYP / MATCH error: arms must unify to the binding type (`i64`).
**Remediation:** In the match-arm typeck, pin the arm-result type to the binding's declared/inferred type or to the first arm's type, and reject divergent arms. Search for `MATCH-011`. Add `tests/err/err_match_arms_diverge_types.nr`.

---

### F-024 [Medium] [Diagnostic] Type mismatch on `if`-expression branch reports wrong types in the message (`i32` vs the actual `i64`)

**Reproducer:** `audit_scratch_typesystem/f042_if_branch_diff_types.nr`
```nr
fn main() -> i32 {
    let r: i64 = if true { 1 } else { "two" };
    print_int(0);
    0
}
```
**Observed:**
```
error[TYP-024]: `if`-expression branches have incompatible types:
then-branch is `i32`, else-branch is `str`. ...
```
**Expected:** Then-branch is bound to an `i64` context (`let r: i64`); the literal `1` should resolve to `i64`. Reporting it as `i32` is misleading. Also the span points at `fn main` rather than at the `if`-branch.
**Remediation:** The TYP-024 emission uses the literal's default type rather than the inferred (context-driven) type. After type-checking, prefer the bound type. Span — point at the conflicting branch. Search `TYP-024`.

---

### F-025 [Medium] [Diagnostic] TYP-025 reports wrong type ("type 'i32'" for an integer literal that should default to i64)

**Reproducer:** `audit_scratch_typesystem/f052_generic_inference_with_bound.nr`
```nr
trait Foo { fn foo(self) -> i64; }
fn run<T: Foo>(x: T) -> i64 { x.foo() }
fn main() -> i32 {
    print_int(run(42) as i32);   // 42 default-typed
    0
}
```
**Observed:**
```
error[TYP-025]: type 'i32' does not implement trait 'Foo' ...
```
**Expected:** The literal `42` should default to `i64`; "type 'i32' does not implement Foo" is misleading.
**Remediation:** Check the integer-literal default type policy across diagnostics. Either default literals to i64 globally (preferred per spec §2 — "i32 used for `main` return; mostly equivalent to i64 in expressions") or be precise about which width was chosen. Search for `does not implement trait` and the literal-type fixup that precedes it.

---

### F-026 [Medium] [Diagnostic] Recursive-struct detector is detected but reported via PANIC after a clean diagnostic

**Reproducer:** `audit_scratch_typesystem/f015_self_recursive_struct.nr`
```nr
struct Node { val: i64, next: Node }
```
**Observed:**
```
error[NR036]: recursive type `Node` has infinite size ...
PANIC: nucleor: recursive struct Node contains itself directly via field next
```
**Expected:** Clean exit on the diagnostic without the PANIC line. The diagnostic is fine; the PANIC follows it and pollutes the exit-code surface (the trailing `panic()` is what produces the `PANIC:` prefix).
**Remediation:** After the `error[NR036]` emission, route through normal diagnostic-aware exit, not `panic()`. Same family as F-019.

---

### F-027 [Low] [Functional] `<T: Foo + Foo>` (redundant trait bound) accepted with no warning

**Reproducer:** `audit_scratch_typesystem/f050_redundant_trait_bound.nr`
```nr
fn run<T: Foo + Foo>(x: T) -> i64 { x.foo() }
```
**Observed:** Compiles clean.
**Expected:** Warning — Rust E0046? actually rustc gives a warning, not an error. Acceptable here; raise as Low.
**Remediation:** Optional. In `parse_generic_params` after collecting bounds, dedupe and warn on duplicates.

---

### F-028 [Low] [Edge] Zero-variant enum (`enum Void {}`) accepted but cannot be constructed (parity check)

**Reproducer:** `audit_scratch_typesystem/f039_zero_variant_enum.nr`
```nr
enum Void {}
```
**Observed:** Compiles clean (which is correct — uninhabited enums are valid). No tests verify this case in the existing suite.
**Expected:** No diagnostic. **Note:** language reference §5 doesn't say zero-variant is allowed; needs documenting.
**Remediation:** Document zero-variant enums in `docs/language-reference.md` §5 (or explicitly reject if intent is "must have ≥ 1 variant"). Add `tests/lang/zero_variant_enum.nr` as a positive test.

---

### F-029 [Note] [AttackSurface] Generic monomorphization is type-erased, not per-instantiation

**Reproducer:** `audit_scratch_typesystem/f055_compose_diff_types.nr`
```nr
fn id<T>(x: T) -> T { x }
fn main() -> i32 {
    let a: i64 = id(1);
    let b: str = id("hi");
    ...
}
```
**Observed:** Resulting LLVM IR contains exactly one `define i64 @id(i64 %p.0)` — both call sites lower to the same body; pointer types are reused as i64 via the C ABI.
**Expected:** This is a documented choice (compiler comment line ~28040 calls it transitional). Note for risk register: any optimization or layout change that breaks the i64-sized-everything assumption (e.g. an f32 type, narrow ints, fat-pointer strings) will silently miscompile. The type erasure also defeats most monomorphization-bomb attack vectors — a positive — but at the cost of soundness for non-i64-sized T.
**Remediation:** No fix needed in this audit. Track as a risk for any future "narrow int / f32 / fat pointer" RFC. Document the constraint at the top of the generic-fn section in the language reference: "generic type parameters must lower to a 64-bit-wide ABI value." Add a regression test that fails clearly if the i64-everywhere assumption breaks for a generic call site.

---

### F-030 [Note] [Edge] Recursive generic call with deeper instantiation does not loop the compiler

**Reproducer:** `audit_scratch_typesystem/f001_recursive_generic.nr`
**Observed:** Compiles clean. Combined with F-029, this is unsurprising — type erasure means there's nothing to expand. Still worth recording as the "monomorphization-bomb" attack-surface check.
**Expected / Remediation:** No action. When per-instantiation monomorphization eventually ships, the same fixture should be a regression test against unbounded expansion (compile budget / depth limit).

---

### F-031 [Note] [Edge] Long where-clause chains (10–50 traits) compile in seconds with no quadratic blowup

**Reproducer:** `audit_scratch_typesystem/f025_long_where_chain.nr`
**Observed:** Sub-second compile.
**Expected / Remediation:** No action; sanity baseline. Re-run after impl-coverage and signature-check fixes (F-009, F-010) ship.

---

### F-032 [Note] [Inference] `let v = id(42)` (bound generic, no annotation) is accepted and compiles

**Reproducer:** `audit_scratch_typesystem/f005_generic_bound_inference.nr`
**Observed:** Compiles clean. Combined with F-029 (type erasure), the inference is a no-op since both call sites lower identically.
**Expected / Remediation:** No action; will need revisiting alongside F-029 when real monomorphization ships.

## Cross-layer observations

(Findings outside this audit's scope — recorded but not investigated further.)

- **CL-1 (ownership × generic)** `audit_scratch_typesystem/f061_use_after_move_with_generic.nr`: Calling `consume<T>(x: T)` with a struct, then using the struct after, is **not** flagged as OWN-001 use-after-move. The ownership tracker may not see the move when the parameter is generic. Severity high if reproducible at Layer 3 — flagged here for borrow-check audit.

- **CL-2 (parser × type)** `audit_scratch_typesystem/f035_let_pattern_destructure.nr`: PANIC at `parse_primary` for `let Variant(a, b) = expr;`. Belongs in lexer/parser audit, but listed under F-020 here because the symptom is type-system-shaped (pattern type-checking).

- **CL-3 (codegen × type)** F-029 (type erasure of generics) is observable in IR. Any IR optimization that assumes per-call-site signature fidelity would be a hazard. Flagged for codegen audit.

- **CL-4 (PANIC-as-diagnostic, repeated)** F-019, F-020, F-026: at least three places use `panic(...)` to surface user-facing errors after a real diagnostic was already emitted. Audit the full set with a grep for `panic(` calls in `compiler/` whose strings start with `nucleor:` or are introduced by error-path code; convert to clean exits.

---

## Final brief summary

- **Critical (4):** F-002 silent miscompile (cross-enum match), F-003 silent integer narrowing, F-006 generic enum payload type unchecked, F-019 PANIC instead of diagnostic on duplicate impl.
- **High (12):** F-001 generic arity, F-004 implicit widening, F-005 int→f64 implicit, F-007 generic struct field access type, F-008 generic struct field init type, F-009 impl missing method, F-010 impl signature mismatch, F-011 impl extra method, F-012 mutual recursion, F-013 generic recursive struct, F-014 unbound type-param in where, F-015 duplicate type-param, F-016 type-param shadows primitive, F-018 ambiguous inference, F-020 PANIC on let-pattern, F-021 wrong receiver type in error.
- **Medium (6):** F-017 empty `<>`, F-022 circular default, F-023 match-arm-RHS divergence, F-024 wrong type in if-branch error, F-025 wrong type ("i32") in TYP-025 error, F-026 PANIC after clean NR036.
- **Low (2):** F-027 redundant `Foo + Foo`, F-028 zero-variant enum needs spec doc.
- **Note (4):** F-029 type-erased generics, F-030 recursive-generic compile, F-031 long where chain ok, F-032 ambiguous-but-erased inference.

Total findings: 28 (22 actionable bugs).
