# RFC-0034 — Compile-Time `[]` Parameters vs Runtime `()` Parameters

| Field | Value |
|---|---|
| **Number** | 0034 |
| **Title** | Compile-Time `[]` Parameters vs Runtime `()` Parameters |
| **Status** | Draft (design-only — pinned for v0.5; full implementation target v1.0) |
| **Author** | Joseph Wescott + GPT-5.5 |
| **Created** | 2026-04-29 |
| **Target release** | v0.5 design; v1.0 implementation |
| **Depends on** | RFC-0024 (Generics + scoping), RFC-0036 (MLIR backend), RFC-0037 (`@device(gpu)`), RFC-0038 (Shape-typed tensors) |

---

## 1. Summary

Introduce a first-class split between compile-time parameters and runtime
parameters.

Runtime values stay in parentheses:

```nucleor
fn add(a: i64, b: i64) -> i64 { return a + b; }
```

Compile-time parameters live in square brackets:

```nucleor
fn matmul<T: Numeric>[M: usize, N: usize, K: usize](a: Tensor<T>, b: Tensor<T>) -> Tensor<T>
```

At the call site:

```nucleor
let c = matmul<f32>[1024, 512, 256](a, b);
```

`[]` parameters are known before lowering. They can control tensor shapes,
array sizes, tile sizes, GPU block dimensions, code pruning, and autotuning.
Each distinct `[]` instantiation produces a specialized IR body.

This RFC deliberately preserves existing `<T>` type-generics syntax.
Square brackets add **value-level compile-time parameters** on top of
existing type generics.

---

## 2. Motivation

### 2.1 What's wrong today

Nucleor needs a single mechanism for several related features:

- const generics for tensor and matrix dimensions,
- kernel tile sizes,
- device specialization,
- autotuning search spaces,
- shape arithmetic,
- MLIR transform parameters,
- compile-time configuration flags.

Without one mechanism, each feature invents its own parameter syntax. That
leads to inconsistent APIs and hard-to-cache specialization.

### 2.2 What we want

We want this distinction to be obvious:

```nucleor
fn kernel<T: Numeric>[N: usize, TILE: usize = 16](x: Tensor<T, [N]>) -> Tensor<T, [N]>
```

- `T` is a type parameter.
- `N` and `TILE` are compile-time values.
- `x` is a runtime value.

The compiler can specialize the function for each `[N, TILE]` pair and
cache the resulting IR.

### 2.3 Why now

v0.6 Tensor design and later GPU/MLIR work need a stable answer to where
shape and tiling parameters live. This RFC pins that answer before those
features depend on incompatible forms.

---

## 3. Design

### 3.1 Syntax

Function declarations may contain both type generics and compile-time
parameters.

```nucleor
fn name<T: Trait>[CT: Kind, CT2: Kind = default](runtime_params...) -> Ret { ... }
```

Both parts are optional.

```nucleor
fn plain(a: i64) -> i64
fn generic<T>(x: T) -> T
fn const_only[N: usize](x: Vec<i64>) -> Vec<i64>
fn both<T>[N: usize](x: Tensor<T, [N]>) -> Tensor<T, [N]>
```

The grammar extension is:

```text
FnDecl     ::= "fn" Ident TypeParams? CtParams? "(" Params? ")" Return? Body
TypeParams ::= "<" TypeParamList ">"
CtParams   ::= "[" CtParamList "]"
CtParam    ::= Ident ":" CtKind Default?
Default    ::= "=" CtExpr
```

The call syntax mirrors the declaration syntax:

```nucleor
f<T>[N](runtime_args...)
```

If only compile-time values are supplied:

```nucleor
make_vec[1024]()
```

If only type generics are supplied:

```nucleor
identity<i64>(x)
```

### 3.2 What can appear in `[]`

Compile-time parameters may be:

| Kind | Example | Notes |
|---|---|---|
| `usize` | `[N: usize]` | array/tensor lengths, tile sizes |
| `u64` | `[MASK: u64]` | bit masks, hash seeds |
| `i64` | `[OFFSET: i64]` | signed offsets, but bounds-checked |
| `bool` | `[CHECKED: bool]` | code pruning |
| enum values | `[ORDER: MemoryOrder]` | target and ABI choices |
| shape expressions | `[Shape: ShapeExpr]` | foundation for RFC-0038 |
| device tags | `[D: DeviceTag]` | CPU/GPU/backend specialization |

Type parameters remain in `<T>`.

```nucleor
fn vec_add<T: Numeric>[N: usize](a: Tensor<T, [N]>, b: Tensor<T, [N]>) -> Tensor<T, [N]>
```

This RFC chooses **Option A** from the brief: `<T>` continues for type
generics; `[]` adds value-level compile-time parameters.

### 3.3 Why not replace `<T>` with `[]`

Replacing `<T>` with `[]` would produce one uniform parameter mechanism, but
it would break or churn existing generic code. The value of that cleanup is
not worth the migration cost.

Nucleor therefore uses:

- `<...>` for type parameters and trait bounds,
- `[...]` for compile-time values.

A later RFC may permit type parameters inside `[]` as sugar, but this RFC
does not require it.

### 3.4 Defaults

Compile-time parameters may have defaults.

```nucleor
fn vec_add<T: Numeric>[N: usize, TILE: usize = 16](a: Tensor<T, [N]>, b: Tensor<T, [N]>) -> Tensor<T, [N]>
```

A call may omit defaulted parameters from the right.

```nucleor
vec_add<f32>[1024](a, b)      // TILE = 16
vec_add<f32>[1024, 32](a, b)  // TILE = 32
```

Defaults must be compile-time expressions using only earlier compile-time
parameters and constants.

### 3.5 Inference

The compiler may infer a compile-time parameter when it appears in runtime
argument types.

```nucleor
fn len<T>[N: usize](x: Tensor<T, [N]>) -> usize {
    return N;
}

let x: Tensor<f32, [64]> = ...;
let n = len<f32>(x);  // infer N = 64
```

If a compile-time parameter has no default and cannot be inferred, the call
fails with `CTPARAM-001`.

### 3.6 Body usage

Inside the function body, compile-time parameters are immutable constants.
They may be used in:

- array sizes,
- tensor shapes,
- match arms,
- compile-time `if` pruning,
- loop bounds that the optimizer may unroll,
- MLIR transform parameters,
- `@device(gpu)` launch geometry.

They may not be assigned to mutable bindings.

```nucleor
fn bad[N: usize]() {
    N = N + 1;  // error[CTPARAM-002]
}
```

A compile-time parameter can be copied into a runtime value:

```nucleor
let n_runtime: usize = N;
```

but that does not make runtime values usable as compile-time parameters.

### 3.7 Compile-time expressions

A compile-time expression may contain:

- literals,
- compile-time parameters,
- pure arithmetic on compile-time integers,
- enum constants,
- shape constructors,
- compiler-known constants.

Examples:

```nucleor
Tensor<f32, [N + M]>
Tensor<f32, [N * 2]>
Tensor<f32, [R, C]>
```

The first implementation should support `+`, `-`, `*`, `/` on integer
parameters and report `CTPARAM-005` for shape arithmetic that underflows or
exceeds target bounds.

### 3.8 Monomorphization

Each unique compile-time-parameter instantiation produces a specialized
body.

```nucleor
vec_add<f32>[1024, 16](a, b)
vec_add<f32>[1024, 16](c, d)
```

share one specialization.

```nucleor
vec_add<f32>[1024, 32](a, b)
```

produces another specialization.

The specialization key is:

```text
function_name + type_args + normalized_compile_time_args + compiler_version
```

The compiler may later use content-addressed hashing instead of name-based
keys, but the semantic rule is: same normalized `[]` values produce the
same body.

### 3.9 Deduplication

Normalized compile-time values deduplicate.

```nucleor
f[16](x)
f[8 + 8](x)
```

produce the same specialization if the compiler folds `8 + 8` to `16`.

### 3.10 Autotuning

Compile-time parameters are the autotuning surface.

```nucleor
#[autotune(TILE in [8, 16, 32, 64])]
fn matmul<T: Numeric>[M: usize, N: usize, K: usize, TILE: usize = 16](a: Tensor<T>, b: Tensor<T>) -> Tensor<T>
```

`nuc autotune` searches the declared parameter space for a target:

```text
nuc autotune matmul --target=x86_64-linux
```

Results are cached under:

```text
target/.nuc_autotune/<fn>.json
```

The cache key must include:

- function typed-AST hash,
- target triple,
- compiler version,
- runtime/MLIR backend version if applicable,
- declared search space.

### 3.11 GPU specialization

`@device(gpu)` functions use compile-time parameters for geometry and
layout.

```nucleor
@device(gpu)
fn vec_add<T: Numeric>[N: usize, BLOCK: usize = 256](a: Tensor<T, [N]>, b: Tensor<T, [N]>) -> Tensor<T, [N]> {
    let i: usize = block_idx() * BLOCK + thread_idx();
    if i < N { ... };
}
```

RFC-0037 defines GPU lowering. This RFC only defines where `BLOCK`, `N`,
and similar knobs live.

### 3.12 MLIR integration

Each `[]` instantiation may become an MLIR module with compile-time values
attached as attributes.

Example conceptual lowering:

```text
nuc.func @matmul__f32__M1024_N512_K256 attributes { M = 1024, N = 512, K = 256 }
```

RFC-0036 defines the full MLIR path. RFC-0034 only requires that the
compile-time values are available to that path.

### 3.13 Shape-typed tensors

RFC-0038 builds on this RFC.

```nucleor
let a: Matrix<f32, [R, K]>;
let b: Matrix<f32, [K, C]>;
let c: Matrix<f32, [R, C]> = matmul<f32>[R, C, K](a, b);
```

Shape expressions in `[]` are compile-time facts. The type checker rejects
shape mismatches before lowering.

---

## 4. Reference-level explanation

### 4.1 Declaration normalization

A declaration:

```nucleor
fn f<T: Numeric>[N: usize, TILE: usize = 16](x: Tensor<T, [N]>) -> Tensor<T, [N]>
```

normalizes to a function signature carrying:

```text
name: f
type_params: [T: Numeric]
ct_params: [N: usize, TILE: usize = 16]
rt_params: [x: Tensor<T, [N]>]
return: Tensor<T, [N]>
```

### 4.2 Call checking

At a call site:

```nucleor
f<f32>[128](x)
```

The type checker:

1. resolves `f`,
2. checks type arguments,
3. fills omitted compile-time defaults,
4. infers omitted compile-time values from runtime argument types,
5. checks every compile-time value against its kind,
6. forms the specialization key,
7. type-checks runtime arguments against the specialized signature.

### 4.3 Inference failure

```nucleor
fn make_zero[N: usize]() -> Tensor<f32, [N]> { ... }
let x = make_zero();
```

`N` cannot be inferred because it appears only in the return type. This is
an error unless `N` has a default.

```text
error[CTPARAM-001]: compile-time parameter 'N' cannot be inferred
  = help: call `make_zero[128]()` or give N a default
```

### 4.4 Compile-time values are not runtime variables

```nucleor
fn f[N: usize]() {
    let mut n: usize = N;  // OK, runtime copy
    n = n + 1;             // OK, modifies copy
    N = N + 1;             // error
}
```

### 4.5 Specialization and visibility

Specialized names are internal implementation details. Users cannot refer
to `matmul__f32__M1024_N512_K256` directly.

Externally visible symbol names remain controlled by `#[export]` or module
visibility rules.

---

## 5. Diagnostics

RFC-0034 introduces `CTPARAM` diagnostics.

| Code | Title | Severity |
|---|---|---|
| `CTPARAM-001` | Compile-time argument cannot be inferred and has no default | error |
| `CTPARAM-002` | Value is not a compile-time constant | error |
| `CTPARAM-003` | Compile-time argument kind mismatch | error |
| `CTPARAM-004` | Autotune attribute on non-compile-time parameter | error |
| `CTPARAM-005` | Shape arithmetic out of bounds | error |
| `CTPARAM-006` | Duplicate specialization with incompatible body | error |
| `CTPARAM-007` | Default value references later parameter | error |
| `CTPARAM-008` | Compile-time parameter used as mutable storage | error |
| `CTPARAM-009` | Autotune search space is empty | error |
| `CTPARAM-010` | Reserved | reserved |

### 5.1 Example: non-constant value

```nucleor
let n: usize = read_i64();
let x = make_vec[n]();
```

```text
error[CTPARAM-002]: compile-time argument 'n' is a runtime value
  = help: pass a literal or a value derived from compile-time parameters
```

### 5.2 Example: kind mismatch

```nucleor
make_vec["hello"]();
```

```text
error[CTPARAM-003]: expected compile-time argument of kind usize, got str
```

### 5.3 Example: bad autotune attribute

```nucleor
#[autotune(x in [1, 2, 3])]
fn f(x: i64) -> i64 { return x; }
```

```text
error[CTPARAM-004]: autotune parameter 'x' is not a compile-time parameter
```

---

## 6. Implementation plan

### 6.1 Parser

Add parser support for:

- `fn name<T>[...]`,
- function calls with optional `<...>` and `[...]`,
- type positions containing shape expressions such as `Tensor<T, [N]>`,
- defaults in compile-time parameter lists,
- `#[autotune(...)]` parameter search-space syntax.

### 6.2 Type checker

Add compile-time parameter environments.

```text
ctenv: name -> { kind, value?, default?, inferred? }
```

The checker must separate type parameters from compile-time value
parameters. A type parameter may not be used where a value is required,
and a value parameter may not be used as a type.

### 6.3 Specialization table

Add a specialization table:

```text
(base_fn, type_args, ct_args) -> specialized_fn_id
```

If the key exists, reuse the existing body. Otherwise instantiate and
lower a new body.

### 6.4 Lowering

Compile-time values are substituted before ordinary expression lowering.
Compile-time `if` conditions may prune dead branches before lowering.

```nucleor
fn f[CHECKED: bool](x: i64) -> i64 {
    if CHECKED {
        return checked_abs(x);
    } else {
        return abs(x);
    };
}
```

The specialization `f[true]` lowers only the checked branch if the parser
and AST representation support compile-time branch pruning.

### 6.5 Autotune driver

`nuc autotune` should:

1. find the function,
2. read autotune search spaces,
3. enumerate candidate `[]` values,
4. compile each specialization,
5. run benchmark harness,
6. persist the best candidate to `target/.nuc_autotune/<fn>.json`,
7. optionally pin that choice in a lockfile.

### 6.6 Cache integration

Specialization keys should be compatible with the content-addressed cache.
A change in compile-time parameter values changes the typed-AST hash and
therefore the cached artifact.

---

## 7. Migration

Existing generic code is unchanged.

```nucleor
fn id<T>(x: T) -> T { return x; }
```

continues to compile.

New code uses `[]` only when it needs compile-time value parameters.

No existing `<T>` code is deprecated by this RFC.

The Tensor design should adopt the compile-time shape form:

```nucleor
Tensor<T, [Shape], Device>
```

rather than a runtime `Shape` value.

---

## 8. Drawbacks

- Function syntax becomes more complex.
- Specialization can increase code size.
- Inference rules can be surprising when a parameter appears only in the
  return type.
- Autotuning can make builds slower unless cached aggressively.
- Shape arithmetic creates a new class of compile-time errors.

---

## 9. Rationale and alternatives

### 9.1 Use `<T, N>` for everything

Rejected. It blurs type parameters and value parameters and makes call-site
meaning unclear.

### 9.2 Replace `<T>` entirely with `[]`

Rejected for compatibility. Existing generic source should not churn.

### 9.3 Use runtime shape values

Rejected. Runtime shape values cannot drive monomorphization, static shape
checking, or MLIR transform schedules.

### 9.4 Use macros for specialization

Rejected. Macros hide specialization from the type checker and cache.
Compile-time parameters must be first-class typed facts.

---

## 10. Prior art

- Mojo-style separation of compile-time parameters from runtime
  parameters.
- Rust const generics for value-level type parameters.
- Zig `comptime` values.
- C++ templates, with Nucleor rejecting template-style unconstrained
  substitution in favor of explicit kinds and diagnostics.
- MLIR Transform dialect schedule parameters.

Nucleor adopts the explicit parameter split while preserving existing
Nucleor generic syntax.

---

## 11. Unresolved questions

1. Should compile-time type parameters eventually be permitted inside
   `[]` as sugar?
2. Should compile-time string parameters be allowed for kernel names and
   resource paths?
3. What is the exact upper bound for specialization count before the
   compiler warns?
4. Should autotune results be committed to `Nucleor.lock`?
5. How much compile-time branch pruning lands in the first implementation?

Author recommendation: keep the first implementation narrow — integers,
bools, enum tags, and shape expressions — then expand after the Tensor and
GPU paths are stable.

---

## 12. Future extensions

- `@device(gpu)` launch geometry through `[]` parameters (RFC-0037).
- MLIR transform schedules parameterized by `[]` values (RFC-0036).
- Shape-typed tensors and matrices (RFC-0038).
- Content-addressed specialization cache (RFC-0040).
- User-defined compile-time functions once the evaluator is stable.

---

## 13. Definition of done

- [ ] Parser accepts `fn name<T>[...](...)`.
- [ ] Parser accepts call-site `f<T>[...](...)`.
- [ ] Existing `<T>` generic code remains valid.
- [ ] Type checker stores compile-time parameter environments.
- [ ] Defaults and inference are implemented.
- [ ] Each unique `[]` value set creates one specialization.
- [ ] Specializations deduplicate after normalization.
- [ ] `CTPARAM-001` through `CTPARAM-009` are documented and wired into
      `nuc explain`.
- [ ] Tensor type grammar can use `Tensor<T, [Shape], Device>`.
- [ ] Autotune attribute syntax is parsed, even if the driver lands later.

---

## 14. Acceptance checklist

- [ ] Maintainer approves Option A: `<T>` stays for type generics; `[]`
      adds compile-time value params.
- [ ] v0.6 Tensor design can depend on this grammar.
- [ ] v1.0 MLIR/GPU design can consume `[]` values as specialization knobs.
- [ ] No v0.2–v0.4 source breakage.
- [ ] Implementation plan fits existing monomorphization and cache strategy.
