# RFC-0033 — Effects in Function Types (`with [...]`)

| Field | Value |
|---|---|
| **Number** | 0033 |
| **Title** | Effects in Function Types (`with [...]`) |
| **Status** | Draft (design-only — pinned for v0.5; full implementation target v0.9) |
| **Author** | Joseph Wescott + GPT-5.5 |
| **Created** | 2026-04-29 |
| **Target release** | v0.5 design; v0.9 implementation |
| **Depends on** | RFC-0001 (RT attributes), RFC-0032 (Effects), RFC-0031 (Algebraic laws), RFC-0030 (Async decision) |

---

## 1. Summary

Promote Nucleor's existing effect discipline into the function type
itself.

Today Nucleor already has several effect-like surfaces:

- RT attributes from RFC-0001: `#[no_alloc]`, `#[no_panic]`,
  `#[no_dyn]`, `#[deadline = N]`
- RFC-0032 syntax: `pure fn`, `requires [...]`, `restricts [...]`
- algebraic law annotations from RFC-0031
- FFI annotations such as `#[ffi_no_alloc]` and `#[ffi_no_panic]`

Those mechanisms are useful, but they are mostly syntactic facts about
declarations. RFC-0033 makes the facts part of the function type through
a `with [...]` clause.

```nucleor
fn parse(s: str) -> Result<Config, ParseErr> with [Alloc, Panic]
fn pid_step(err: f64) -> f64 with [no_alloc, no_panic, no_dyn, deadline(1000us)]
fn read_config(p: str) -> Config with [Filesystem.readonly("/etc/nucleor")]
fn pure_compute(x: f64) -> f64 with [pure]
fn db_write(k: str, v: str) -> bool with [Database.write("users")]
```

The type of a function is no longer only:

```text
(A, B) -> C
```

It becomes:

```text
(A, B) -> C with [Effects...]
```

Effect rows are checked by the type checker. A function that calls an
allocating function must either list `Alloc` in its own row, delegate to a
capability that grants the effect, or fail to compile.

This RFC does **not** introduce effect handlers. RFC-0039 owns handler
semantics. This RFC only gives effects a place in function types so later
features can reason about them mechanically.

---

## 2. Motivation

### 2.1 What's wrong today

Nucleor's safety surface is strong, but fragmented.

A `#[no_alloc]` function is checked for allocation. A `pure fn` from
RFC-0032 is checked for impurity. A `restricts [io]` declaration rejects
some calls. A `#[deadline]` declaration participates in RT diagnostics.
Those mechanisms are all pointing at the same underlying idea: a function
has observable capabilities and obligations.

The problem is that the current spelling does not give the type checker a
single object to compare.

For example, these should be type-level questions:

```nucleor
fn run_step(f: fn(f64) -> f64 with [no_alloc, no_panic], x: f64) -> f64 {
    return f(x);
}
```

The compiler should accept a pure or no-alloc function in that position,
and reject a function that may allocate or panic. That check is clumsy if
effects are only attributes attached to declarations.

### 2.2 What we want

We want a function's effect contract to be visible at every call site,
function-pointer assignment, generic bound, closure type, extern import,
and trait method declaration.

Specifically:

1. A caller can state which effects it permits.
2. A callee advertises which effects it may perform.
3. A function pointer can include an effect row.
4. A closure can carry an effect row inferred from its body.
5. Generic functions can be polymorphic over effects.
6. Existing v0.2–v0.4 source continues to compile through sugar mapping.

### 2.3 Why this is a v0.5 design item

v0.6 and later features need a stable answer to the question: "where do
side effects live in the type system?"

Examples:

- `@device(gpu)` should imply a small effect row such as
  `[no_alloc, no_panic, no_dyn]` plus device-specific effects.
- actors need effects such as `ActorIsolated(Counter)`.
- `nuc verify` needs a finite list of proof obligations attached to
  functions.
- content-addressed caching needs the effect row in the typed-AST hash.

RFC-0033 pins the representation early so later designs do not invent
parallel mechanisms.

---

## 3. Design

### 3.1 Syntax

A function declaration may include a `with [...]` clause after the return
type and before the body.

```nucleor
fn name(args...) -> Ret with [effect, effect, ...] {
    ...
}
```

If a function has no explicit return type, the `with [...]` clause follows
the parameter list:

```nucleor
fn log(msg: str) with [IO.write(stdout)] {
    print(msg);
}
```

Empty `with []` means the empty effect row. It is equivalent to
`with [pure]` for user-facing purposes, but the compiler internally stores
it as an empty row plus a normalized `pure` marker for diagnostics.

```nucleor
fn add(a: i64, b: i64) -> i64 with [] {
    return a + b;
}
```

The grammar extension is:

```text
FnDecl      ::= Attrs? "fn" Ident GenericParams? "(" Params? ")" Return? EffectClause? Body
Return      ::= "->" Type
EffectClause ::= "with" "[" EffectList? "]"
EffectList  ::= Effect ("," Effect)*
Effect      ::= Ident EffectArgs?
EffectArgs  ::= "(" EffectArgList? ")"
```

Effects are parsed after type parsing and before body parsing. This keeps
function-type parsing unambiguous:

```nucleor
let f: fn(i64) -> i64 with [no_alloc];
```

### 3.2 Effect rows

The effect row is a set of normalized effect entries.

```text
with [Alloc, Panic]
```

normalizes to:

```text
{ Alloc, Panic }
```

Duplicate effects are rejected unless the duplicate carries identical
quantitative values and appears through sugar expansion. For example,
`#[no_alloc] fn f() -> i64 with [no_alloc]` is accepted and normalized to
one `no_alloc` entry; `with [deadline(1000us), deadline(2000us)]` is
rejected.

Rows use set-union semantics for ordinary effects.

```text
{ Alloc } ∪ { Panic } = { Alloc, Panic }
```

Quantitative effects have per-effect composition rules; see §3.7.

### 3.3 Canonical effect taxonomy

#### 3.3.1 Resource effects

Resource effects describe what the function may touch.

| Effect | Meaning |
|---|---|
| `Alloc` | May allocate from a heap-like allocator |
| `Panic` | May panic or trap under ordinary execution |
| `Dyn` | May use dynamic dispatch |
| `Filesystem.read(path)` | May read from the file system at path or path prefix |
| `Filesystem.write(path)` | May write to the file system at path or path prefix |
| `Network.connect(host)` | May open a network connection |
| `Database.read(name)` | May read from a named database/table/resource |
| `Database.write(name)` | May write to a named database/table/resource |
| `Process.spawn` | May create a process or OS thread |
| `Time.read` | May read wall-clock or monotonic time |
| `Random` | May consume nondeterministic or PRNG state |
| `IO.read(stream)` | May read from a named stream |
| `IO.write(stream)` | May write to a named stream |

The exact string payload is intentionally conservative. A path or resource
string is compiler-visible, but the compiler does not need full path-
solver semantics for v0.9. Prefix matching is enough for the first
implementation.

#### 3.3.2 Anti-effects

Anti-effects are compiler-checked absence claims.

| Anti-effect | Meaning |
|---|---|
| `no_alloc` | Body and transitive callees must not allocate |
| `no_panic` | Body and transitive callees must not panic |
| `no_dyn` | Body and transitive callees must not use dynamic dispatch |
| `no_format` | Body must not use formatting macros or string-building helpers |
| `pure` | Body must have no resource effects and no nondeterminism |

Anti-effects are not ordinary effects. They are obligations. A function
with `with [no_alloc]` does not have an effect; it has a promise that
`Alloc` is absent from the body and transitive callees.

`pure` is a composite obligation:

```text
pure ≡ no_alloc + no_panic + no_dyn + no_format + no_io + no_time + no_random
```

The compiler may report the specific failed sub-obligation rather than a
generic pure violation.

#### 3.3.3 Quantitative effects

Quantitative effects carry values.

| Effect | Meaning |
|---|---|
| `deadline(N)` | Function is expected to complete within N |
| `max_depth(N)` | Recursion depth is bounded by N |
| `stack_budget(N)` | Maximum stack use is bounded by N |
| `alloc_budget(N)` | Maximum allocation budget is bounded by N |

The first implementation only requires `deadline(N)` and `max_depth(N)`.
The others are reserved spellings for future verification work.

#### 3.3.4 Algebraic-law effects

Law annotations become effect entries so higher-order functions can require
or propagate them.

| Effect | Meaning |
|---|---|
| `law.commutative` | Operation claims commutativity |
| `law.associative` | Operation claims associativity |
| `law.identity(x)` | Operation claims identity element x |
| `law.idempotent` | Operation claims idempotence |

A law effect is not a side effect. It is a proof-carrying obligation and
optimization permission. RFC-0041 may later discharge the proof.

#### 3.3.5 Async effects

Async constructs are represented as effects but not fully specified here.

| Effect | Meaning |
|---|---|
| `Async` | Function participates in the async runtime |
| `Spawn` | Function may spawn a task/thread |
| `Await` | Function may suspend at an await point |
| `ActorIsolated(T)` | Function executes under actor T isolation |

RFC-0035 and RFC-0039 define the concurrency and handler semantics. This
RFC only reserves the row entries.

### 3.4 Attribute mapping

Existing attributes remain valid. They desugar into `with [...]` rows.

| Existing syntax | Effect-row mapping |
|---|---|
| `#[no_alloc]` | `with [no_alloc]` |
| `#[no_panic]` | `with [no_panic]` |
| `#[no_dyn]` | `with [no_dyn]` |
| `#[deadline = N]` | `with [deadline(N)]` |
| `#[max_depth = N]` | `with [max_depth(N)]` |
| `#[ffi_no_alloc]` | extern function type has `with [no_alloc]` |
| `#[ffi_no_panic]` | extern function type has `with [no_panic]` |
| `#[hot]` / `@hot` | `with [hot]`, normalized to `no_alloc + no_dyn + no_format` |
| `@law(commutative, ...)` | `with [law.commutative]` plus law metadata |

If both forms are present, the compiler merges them.

```nucleor
#[no_alloc]
fn f() -> i64 with [no_panic] { ... }
```

normalizes to:

```text
fn f() -> i64 with [no_alloc, no_panic]
```

Conflicting quantitative entries are errors:

```nucleor
#[deadline = 1000us]
fn f() -> i64 with [deadline(2000us)] { ... }
```

produces `EFF-005`.

### 3.5 Reconciliation with RFC-0032

RFC-0032 syntax remains source-compatible and becomes sugar.

| RFC-0032 syntax | RFC-0033 normalized form |
|---|---|
| `pure fn f(...) -> T` | `fn f(...) -> T with [pure]` |
| `fn f(...) requires [io.read]` | `fn f(...) with [io.read]` |
| `fn f(...) restricts [io]` | a caller-side effect-row restriction check |

`requires [...]` and `restricts [...]` become compatibility spellings. The
stored function type uses only the normalized effect row.

A function may not mix `requires` and `with` if the two spellings disagree.
If they agree, the compiler accepts them and emits an upgrade suggestion.

```nucleor
pure fn add(a: i64, b: i64) -> i64 with [] { return a + b; }
```

is accepted because `pure` and `with []` normalize to the same obligation
set.

### 3.6 Subtyping

A function with effect row `R` is assignable to a function pointer expecting
effect row `S` iff:

```text
R ⊆ S
```

A narrower-effect function can be used where a wider-effect function is
allowed.

```nucleor
fn pure_inc(x: i64) -> i64 with [] { return x + 1; }
fn may_alloc(x: i64) -> i64 with [Alloc] { return x + 1; }

let f: fn(i64) -> i64 with [Alloc] = pure_inc;  // OK: [] ⊆ [Alloc]
let g: fn(i64) -> i64 with [] = may_alloc;      // error[EFF-001]
```

Anti-effects are obligations, so they are checked by implication rather
than ordinary set inclusion. A function requiring `no_alloc` can accept a
callee whose row proves no allocation. It cannot accept a callee whose row
contains `Alloc` or whose allocation status is unknown.

### 3.7 Effect inheritance through the call graph

If function `f` calls function `g`, then `g`'s resource effects must be
contained in `f`'s row.

```nucleor
fn read_file(p: str) -> str with [Filesystem.read("/etc/nucleor")] { ... }

fn load() -> str with [] {
    return read_file("/etc/nucleor/config.toml");
}
```

This produces:

```text
error[EFF-003]: effect leak from call to 'read_file'
```

Correct code either lists the effect:

```nucleor
fn load() -> str with [Filesystem.read("/etc/nucleor")] {
    return read_file("/etc/nucleor/config.toml");
}
```

or passes a capability token whose type grants the effect.

### 3.8 Capabilities

Some resource effects require a lexical capability.

```nucleor
fn read_config(p: str) -> Config with [Filesystem.readonly("/etc/nucleor")] {
    return parse_config(file_read_string(p));
}
```

The rule is:

> A body may perform a capability-guarded effect only if the function's
> `with` row includes that capability, or the body receives a value whose
> type grants that capability.

The first implementation may model capabilities as row entries only. A
future implementation can lower them into explicit capability-token
parameters.

### 3.9 Generics and effect polymorphism

Higher-order functions may be polymorphic over effect rows.

```nucleor
fn map<T, U, E>(xs: Vec<T>, f: fn(T) -> U with [E]) -> Vec<U> with [E] {
    let mut out: Vec<U> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(xs) {
        out.push(f(xs[i]));
        i = i + 1;
    };
    return out;
}
```

`E` is an effect-row parameter. The map function's own effect row includes
`E` because calling `f` may perform those effects.

If `map` allocates the output vector, the full row is:

```nucleor
with [Alloc, E]
```

Effect-row parameters are never runtime values. They are compile-time type
facts.

### 3.10 Closures

Closure literals receive inferred effect rows.

```nucleor
let f = |x: i64| x + 1;              // fn(i64) -> i64 with []
let g = |p: str| file_read_string(p); // fn(str) -> str with [Filesystem.read(*)]
```

A closure passed to a parameter with a required effect row is checked like
any other function pointer.

```nucleor
fn apply_no_alloc(f: fn(i64) -> i64 with [no_alloc], x: i64) -> i64 {
    return f(x);
}
```

### 3.11 Extern functions

Extern functions must carry explicit effect rows or FFI attributes.

```nucleor
#[ffi_no_alloc, ffi_no_panic]
extern fn host_log(msg: str);

extern fn socket_connect(host: str) -> i64 with [Network.connect("*")];
```

Missing extern effect annotations default to conservative effects:

```text
with [Alloc, Panic, Dyn, IO]
```

unless a target-specific ABI profile says otherwise.

---

## 4. Reference-level explanation

### 4.1 Normalization

The compiler normalizes all effect spellings into a single internal row.

Input:

```nucleor
#[no_alloc, deadline = 1000us]
pure fn step(x: i64) -> i64 requires [law.identity(0)] {
    return x;
}
```

Normalized function type:

```text
fn(i64) -> i64 with [pure, no_alloc, deadline(1000us), law.identity(0)]
```

The normalizer must:

1. collect attributes,
2. parse `pure fn`, `requires`, `restricts`, and `with`,
3. expand composite effects such as `pure` and `hot`,
4. reject contradictions,
5. store the canonical row on the function signature.

### 4.2 Call checking

At each call site:

1. Compute callee row.
2. Compute caller row.
3. Check that callee resource effects are contained in caller row.
4. Check that callee anti-effect obligations do not contradict caller
   obligations.
5. Compose quantitative effects.
6. Emit diagnostics for violations.

### 4.3 Deadline composition

A caller with `deadline(N)` may call a callee with `deadline(M)` only if
`M <= N` or the compiler can prove the call is outside the deadline-
critical path.

The v0.9 implementation may use the conservative rule:

```text
callee deadline must be <= caller deadline
```

More precise WCET composition is future work.

### 4.4 Law effects

Law effects are not assumed true merely because they are written. They are
accepted as proof obligations. Optimizations may use a law effect only if
one of these is true:

- the law is built into the compiler for a primitive operation,
- the law has been discharged by `nuc verify`,
- the build profile allows unchecked law use.

This keeps RFC-0033 compatible with RFC-0041.

---

## 5. Diagnostics

RFC-0033 expands the EFF diagnostic family.

| Code | Title | Severity |
|---|---|---|
| `EFF-001` | Effect row mismatch on function assignment or call | error |
| `EFF-002` | Anti-effect violation | error |
| `EFF-003` | Effect leak from callee into caller | error |
| `EFF-004` | Capability not in scope | error |
| `EFF-005` | Quantitative effect composition failure | error |
| `EFF-006` | Algebraic-law contradiction | error |
| `EFF-007` | Extern effect row conflicts with FFI attributes | error |
| `EFF-008` | `pure` body has an effect | error |
| `EFF-009` | Reserved | reserved |
| `EFF-010` | Reserved | reserved |

### 5.1 Example: row mismatch

```nucleor
fn allocs(x: i64) -> i64 with [Alloc] { ... }
let f: fn(i64) -> i64 with [] = allocs;
```

```text
error[EFF-001]: function with effects [Alloc] cannot be assigned to expected row []
  = help: widen the expected function type to `with [Alloc]`
  = help: or remove allocation from 'allocs'
```

### 5.2 Example: anti-effect violation

```nucleor
fn f() -> i64 with [no_alloc] {
    let v: Vec<i64> = Vec::new();
    return vec_len(v);
}
```

```text
error[EFF-002]: allocation inside function declared with [no_alloc]
  = help: move allocation outside the function and pass the buffer in
```

### 5.3 Example: capability not in scope

```nucleor
fn f() -> str with [] {
    return file_read_string("/etc/nucleor/config.toml");
}
```

```text
error[EFF-004]: Filesystem.read("/etc/nucleor") capability is not in this function's effect row
  = help: add `with [Filesystem.readonly("/etc/nucleor")]`
```

---

## 6. Implementation plan

### 6.1 Parser

Add parsing for:

- function declaration `with [...]`,
- function type `fn(A) -> B with [...]`,
- extern function `with [...]`,
- closure type storage of inferred effect row.

Compatibility parsing for `pure fn`, `requires`, and `restricts` remains.

### 6.2 Signature table

Extend function signatures with an effect-row field:

```text
(name, params, return_type, is_pub, effect_row)
```

Every call to `sig_add`, `sig_find`, and `sig_rtype` must be audited so
the row is available to type checking.

### 6.3 Type checker

Add an effect-checking pass that runs after ordinary type inference but
before lowering. It computes each function's actual effects from:

- direct operations,
- builtin helper calls,
- runtime helper metadata,
- callee signature rows,
- extern rows,
- macro-expanded formatting calls,
- closure captures and calls.

Then it compares inferred effects against declared rows.

### 6.4 Runtime helper metadata

The existing helper manifest already carries `effects` metadata. RFC-0033
makes this metadata type-checking input rather than documentation only.

A helper row such as:

```toml
effects = ["alloc"]
```

maps to `Alloc` in the effect row.

### 6.5 Migration tool

`nuc fmt --upgrade-effects` rewrites equivalent attributes into `with`
syntax on opt-in.

Before:

```nucleor
#[no_alloc, no_panic]
fn f(x: i64) -> i64 { return x + 1; }
```

After:

```nucleor
fn f(x: i64) -> i64 with [no_alloc, no_panic] { return x + 1; }
```

The rewrite is not required for correctness. It is a style migration.

---

## 7. Migration

There is zero source breakage.

Existing code using attributes, `pure fn`, `requires`, or `restricts`
continues to compile. The compiler normalizes old spellings into effect
rows internally.

The migration path is:

1. v0.5: RFC accepted, grammar reserved.
2. v0.9: implementation lands with compatibility sugar.
3. later: `nuc fmt --upgrade-effects` can rewrite old spellings.
4. old spellings remain accepted unless a later RFC explicitly deprecates
   them.

---

## 8. Drawbacks

- Function types become more verbose.
- Effect rows add another dimension to type errors.
- Conservative inference can reject code that is actually safe.
- Capability strings can become ad hoc if not normalized carefully.
- Generic effect polymorphism adds complexity to function-pointer and
  closure typing.

---

## 9. Rationale and alternatives

### 9.1 Keep effects as attributes only

Rejected. Attributes work for declarations but not for function pointers,
closures, higher-order functions, trait methods, or generic constraints.

### 9.2 Use only `pure` / impure

Rejected. Nucleor needs more precision than a binary purity split. A
function that reads time is not the same as one that writes a database.
A function that allocates is not the same as one that may panic.

### 9.3 Use monadic effect types

Rejected for Nucleor's surface. Explicit monads create too much friction
for robotics and systems users. Effect rows keep ordinary function-call
syntax while preserving static reasoning.

### 9.4 Make anti-effects ordinary effects

Rejected. `no_alloc` is not an effect; it is the absence of an effect.
Representing it as a positive effect leads to bad subtyping behavior.

---

## 10. Prior art

- Koka-style effect rows for row-polymorphic effects.
- F\* and verification-oriented effect typing.
- Unison-style abilities.
- Rust's `Send`/`Sync` and async traits as type-carried behavioral
  constraints.
- Swift's actor and Sendable model as evidence that concurrency effects
  belong in type checking.
- Nucleor RFC-0001 and RFC-0032 as the immediate local precedent.

This RFC adopts the effect-row idea but keeps Nucleor's existing RT and
capability vocabulary.

---

## 11. Unresolved questions

1. Should `pure` be stored as a literal row entry or only as the empty row
   plus obligations?
2. How much path reasoning should `Filesystem.read("...")` perform in the
   first implementation?
3. Should `Time.read` and `Random` be disallowed by `pure` but permitted by
   a weaker `deterministic` effect row?
4. How should effect rows print in diagnostics when generic row variables
   are involved?
5. Should trait methods inherit effect rows from trait declarations by
   default, or require each impl method to repeat them?

Author recommendation: store `pure` as a normalized obligation marker for
clear diagnostics, but treat the actual resource row as empty.

---

## 12. Future extensions

- Effect handlers (RFC-0039).
- Actor isolation and Sendable checking (RFC-0035).
- `nuc verify` proof discharge of effect obligations (RFC-0041).
- Effect-aware content-addressed cache keys (RFC-0040).
- Profile-specific effect policies, such as cert-mode refusing unchecked
  law effects.

---

## 13. Definition of done

- [ ] Parser accepts `with [...]` on function declarations, function types,
      extern functions, and trait methods.
- [ ] Existing `pure fn`, `requires`, `restricts`, and RT attributes normalize
      into effect rows.
- [ ] Signature table stores effect rows.
- [ ] Function pointer assignment checks effect-row subtyping.
- [ ] Call sites detect effect leaks.
- [ ] Anti-effects are enforced transitively.
- [ ] Extern functions require explicit rows or conservative defaults.
- [ ] `EFF-001` through `EFF-008` are documented and wired into `nuc explain`.
- [ ] `nuc fmt --upgrade-effects` implements opt-in style migration.
- [ ] Existing v0.4 tests continue to pass without source changes.

---

## 14. Acceptance checklist

- [ ] Maintainer approves syntax.
- [ ] Maintainer approves attribute-to-effect mapping.
- [ ] No v0.2–v0.4 source breakage.
- [ ] v0.6 Tensor design can refer to `with [...]` without ambiguity.
- [ ] v0.9 implementation milestone can use this RFC as a complete spec.
