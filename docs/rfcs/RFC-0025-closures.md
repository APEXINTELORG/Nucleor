# RFC-0025 — Closures with Capture

| Field | Value |
|---|---|
| **Number** | 0025 |
| **Title** | Closures with environment capture (`Fn`, `FnMut`, `FnOnce`) |
| **Status** | Implemented (audited v0.4.183) — closure literals (`\|x\| x * 2`, `\|a, b\| a + b`, `\|\| 42`) bind to `i64` (the pre-RFC-0025 ABI for fn pointers), call directly via `f(args)`, capture outer-scope variables by value (`let mul = 10; let scale = \|x\| x * mul;` — `mul` captured), and pass through generic higher-order functions. v0.4.164 closed the TYP-014 over-tightening that briefly broke this surface. **Still deferred to v0.5+:** formal `Fn` / `FnMut` / `FnOnce` trait types (currently all closures are i64-typed callable; there's no type distinction between by-value and by-mutable-reference capture), capture-by-reference syntax (`move \|\| ...` / `\| \| &x.field`), and closure-returning-closure (currying through return types). |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 |
| **Depends on** | RFC-0026 (trait objects for `Box<dyn Fn>`) |

---

## 1. Summary

Implement first-class closures with environment capture and the
three-trait family (`Fn`, `FnMut`, `FnOnce`). Unblocks the
quarantined `closure_capture.nr` test.

```nucleor
let multiplier: i32 = 3;
let triple = |x: i32| -> i32 { x * multiplier };       // captures multiplier by value
let nums: Vec<i32> = (1..=5).map(triple).collect();    // [3,6,9,12,15]

let mut counter: i32 = 0;
let mut incr = || { counter += 1; counter };           // FnMut: borrows counter mutably
incr(); incr(); assert_eq!(counter, 2);

let owner = String::from("hello");
let consume = move || println!("{}", owner);           // move: takes ownership
consume();
// owner moved, can't use here
```

---

## 2. Motivation

Today closures exist syntactically but `__nucleor_capture_get/set`
runtime symbols are missing — see quarantined test. Iterator
adapters from RFC-0024 require closures.

Prior art: Rust's three-trait Fn family (canonical for ownership
languages); C++ lambdas with `[]`/`[=]`/`[&]` captures; Swift
closures.

---

## 3. Design

### 3.1 The three traits

```nucleor
trait FnOnce<Args> {
    type Output;
    fn call_once(self, args: Args) -> Self::Output;     // consumes the closure
}

trait FnMut<Args>: FnOnce<Args> {
    fn call_mut(&mut self, args: Args) -> Self::Output; // mutable borrow
}

trait Fn<Args>: FnMut<Args> {
    fn call(&self, args: Args) -> Self::Output;          // shared borrow
}
```

Hierarchy: `Fn` ⊂ `FnMut` ⊂ `FnOnce` (more permissive callees can
satisfy more restrictive callers).

### 3.2 Capture inference

The compiler analyzes the closure body to infer the minimal capture:

- If body only reads captured var → `Fn`
- If body mutates captured var → `FnMut`
- If body moves captured var → `FnOnce`
- `move ||` keyword forces move-by-value captures regardless

```nucleor
let f1 = |x| x + 1;             // no capture
let f2 = |x| x + base;          // capture base by &
let f3 = |x| { count += x; count };   // capture count by &mut → FnMut
let f4 = move |x| use(owned, x);     // capture owned by-value → FnOnce
```

### 3.3 Storage

Each closure compiles to an anonymous struct holding its captured
state:

```nucleor
// |x| x + base where `base: i32` is in scope:
struct __closure_3 { base: i32 }
impl Fn<(i32,)> for __closure_3 {
    type Output = i32;
    fn call(&self, args: (i32,)) -> i32 { args.0 + self.base }
}
```

### 3.4 Passing closures

```nucleor
fn apply<F: Fn(i32) -> i32>(f: F, x: i32) -> i32 { f(x) }       // generic, monomorphized
fn apply_dyn(f: &dyn Fn(i32) -> i32, x: i32) -> i32 { f(x) }    // trait object
fn apply_box(f: Box<dyn Fn(i32) -> i32>, x: i32) -> i32 { f(x) }
```

Generic = inlined, no allocation. `&dyn` = vtable, no allocation.
`Box<dyn>` = vtable + heap.

### 3.5 Composition with `#[no_alloc]` / `#[no_dyn]`

- Closures themselves don't allocate (stack-allocated struct).
- `Box<dyn Fn>` allocates → forbidden in `#[no_alloc]`.
- `&dyn Fn` is dynamic dispatch → forbidden in `#[no_dyn]`.
- Generic `F: Fn` is monomorphized → fine in RT context.

### 3.6 Function-pointer coercion

A closure with no captures coerces to `fn` pointer:

```nucleor
let f: fn(i32) -> i32 = |x| x * 2;     // OK, no captures
let g: fn(i32) -> i32 = |x| x * mult;  // ERROR: captures mult
```

### 3.7 Diagnostics

| Code | Meaning |
|---|---|
| CLO-001 | Capture inference inferred FnMut/FnOnce but caller expects Fn |
| CLO-002 | Move-by-value capture used after move |
| CLO-003 | Closure with captures coerced to `fn` |
| CLO-004 | Recursive closure (use `fn` instead) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `move ||`, closure syntax already exists | ~50 |
| Type checker | Capture inference, three-trait selection | ~600 |
| IR | Anonymous struct synthesis per closure | ~300 |
| Codegen | Closure-as-struct + impl generation | ~250 |
| Stdlib | `Fn`/`FnMut`/`FnOnce` traits | ~150 |
| Diagnostics | CLO-001…004 | ~150 |
| **Total** | | **~1500** |

---

## 5. Alternatives considered

- **Function pointers only** — current state; loses captures.
- **Single trait** (no Fn/FnMut/FnOnce split) — loses ownership info.
- **Boxed closures only** — works but performance penalty.

## 6. Open questions

1. Async closures — defer to v0.8.
2. Closure-traits-as-objects with type erasure — supported via `dyn`.
3. Recursive closures (`let fact = |n| if n == 0 { 1 } else { n * fact(n-1) }`)
   — Rust doesn't allow; require named fn. Recommend same.

## 7. Definition of done

- [ ] All three traits work
- [ ] Capture inference handles all cases
- [ ] `move` keyword works
- [ ] `closure_capture.nr` un-quarantined
- [ ] CHANGELOG documents

## 8. Future extensions

- Async closures (v0.8)
- Coroutine-style `yield` closures (research)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~1500 fits
