# RFC-0026 — Trait Objects (`dyn Trait`, vtables)

| Field | Value |
|---|---|
| **Number** | 0026 |
| **Title** | Trait objects — `Box<dyn Trait>`, `&dyn Trait`, vtable dispatch |
| **Status** | Partial (audited v0.4.184) — basic `trait` + `impl Trait for Type` declarations parse, type-check, and dispatch correctly via `Type::method()` static calls (e.g. `Cat::say()`). The `dyn Trait` machinery + vtable lowering is NOT yet implemented: `Box<dyn Greet>` as a return type fails type-check. **Deferred to v0.5+:** `dyn Trait`, `Box<dyn Trait>`, `&dyn Trait`, vtable construction, dynamic dispatch through trait-object pointers. |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 |
| **Depends on** | RFC-0002 (Box for owned trait objects) |

---

## 1. Summary

Add dynamic dispatch through trait objects, alongside the existing
static (monomorphized) dispatch.

```nucleor
trait Drawable {
    fn draw(&self, canvas: &mut Canvas);
    fn bounds(&self) -> Rect;
}

let shapes: Vec<Box<dyn Drawable>> = vec![
    Box::new(Circle { r: 5.0 }),
    Box::new(Rect { w: 10.0, h: 4.0 }),
    Box::new(Triangle { ... }),
];

for s in &shapes {
    s.draw(&mut canvas);    // dynamic dispatch
}

fn render(items: &[&dyn Drawable]) {
    for item in items { item.draw(&mut canvas); }
}
```

Unblocks the `err_box_use_after_move` quarantined test and enables
heterogeneous collections.

---

## 2. Motivation

Today only static (monomorphized) dispatch — `fn f<T: Trait>(x: T)`.
Heterogeneous collections impossible without trait objects.

`#[no_dyn]` (RFC-0001) lets RT code reject this; non-RT code wants
the flexibility.

---

## 3. Design

### 3.1 Object-safe traits

A trait is **object-safe** iff:
- All methods take `self` / `&self` / `&mut self` (no `Self` in
  return types except as `&Self`/`&mut Self`)
- No generic methods (would need infinite vtable)
- No `Self: Sized` clause on methods

Compiler enforces; non-object-safe traits cannot become trait objects.

### 3.2 The `dyn` keyword

`dyn Trait` is the unsized type "any value implementing Trait."
Behind a pointer (`Box<dyn>`, `&dyn`, `*const dyn`, `Rc<dyn>`,
`Arc<dyn>`).

### 3.3 Vtable layout

```
struct DynTrait {
    data: *mut u8,           // pointer to T
    vtable: *const VTable,
}

struct VTable {
    drop_fn: fn(*mut u8),
    size: usize,
    align: usize,
    method_0: fn(*const u8, ...) -> ...,
    method_1: fn(...) -> ...,
    // ...
}
```

One vtable per (trait, type) combination. Generated at compile time,
deduplicated at link time.

### 3.4 Coercion

`Box<T>` where `T: Trait` coerces to `Box<dyn Trait>`. Same for
`&T → &dyn Trait`, etc. Uses unsized-coercion rules.

### 3.5 Multiple bounds

```nucleor
fn f(x: &(dyn Drawable + Send)) { ... }    // multiple traits
```

Currently no auto-traits in Nucleor (no Send/Sync formalization yet);
defer to v0.5.

### 3.6 Composition with `#[no_dyn]`

`#[no_dyn]` rejects:
- `dyn Trait` types in any signature
- `Box<dyn Trait>` allocations
- Calls through trait objects

### 3.7 Composition with allocator types (RFC-0002)

`Box<dyn Trait, A>` works — vtable is unaffected by allocator. Useful
for arena-allocated trait objects.

### 3.8 Diagnostics

| Code | Meaning |
|---|---|
| DYN-001 | Trait is not object-safe (`Self` in return; generic method) |
| DYN-002 | `dyn Trait` used in `#[no_dyn]` function |
| DYN-003 | Coercion to `dyn Trait` requires explicit annotation in ambiguous context |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Type checker | Object-safety check, dyn coercion | ~400 |
| IR | Trait-object representation | ~250 |
| Codegen | Vtable emission, dynamic-dispatch lowering | ~500 |
| Diagnostics | DYN-001…003 | ~150 |
| **Total** | | **~1300** |

---

## 5. Alternatives considered

- Static dispatch only — current; insufficient for heterogeneous
  collections.
- Existential types (`impl Trait`) for return positions — ship
  alongside (small extension).

## 6. Open questions

1. Auto-traits (Send/Sync) — defer to v0.5.
2. Arc<dyn Trait> — needs RFC-0033 (atomic Arc); ship in v0.5.
3. Vtable inlining for monomorphic call sites — optimizer optimization.

## 7. Definition of done

- [ ] Object-safety check correct
- [ ] `Box<dyn>`, `&dyn`, `&mut dyn` work
- [ ] Vtable codegen correct
- [ ] `err_box_use_after_move` test moved out of quarantine
- [ ] CHANGELOG documents

## 8. Future extensions

- Auto-traits (Send/Sync) — v0.5
- Custom DST (dynamically sized types) — v0.7+
- Existential types in return positions

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~1300 fits
