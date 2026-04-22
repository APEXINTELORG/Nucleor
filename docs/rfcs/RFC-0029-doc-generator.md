# RFC-0029 — Documentation Generator (`nuc doc`)

| Field | Value |
|---|---|
| **Number** | 0029 |
| **Title** | Documentation generator — `nuc doc`, `///` doc comments, doc tests |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 |
| **Depends on** | RFC-0021 (test framework — for doc tests), RFC-0019 (package metadata) |

---

## 1. Summary

`nuc doc` reads `///` doc comments and emits navigable HTML +
optionally extracts code examples as runnable doc tests.

```nucleor
/// Returns the Euclidean distance between two 2D points.
///
/// # Arguments
///
/// * `a` — first point
/// * `b` — second point
///
/// # Examples
///
/// ```
/// use geom::distance;
/// let d = distance(Point { x: 0.0, y: 0.0 }, Point { x: 3.0, y: 4.0 });
/// assert_eq!(d, 5.0);
/// ```
pub fn distance(a: Point, b: Point) -> f64 { ... }
```

```bash
nuc doc                  # build docs into target/doc/
nuc doc --open           # build and open in browser
nuc doc --no-deps        # only this crate
nuc test --doc           # run code blocks in doc comments
```

---

## 2. Motivation

Without docs, libraries are unusable. `cargo doc` is a cornerstone
of Rust adoption. Same for our ecosystem.

Prior art: Rustdoc (canonical), Doxygen (C++), Sphinx (Python),
godoc (Go).

---

## 3. Design

### 3.1 Doc comment syntax

```nucleor
/// Outer doc comment (applies to next item)
//! Inner doc comment (applies to enclosing item, e.g., module)

/** Multi-line outer */
/*! Multi-line inner */
```

Markdown body. Supports headers, lists, code blocks, links, tables,
images.

### 3.2 Documented items

Functions, structs, enums, traits, modules, constants, statics,
type aliases, impl blocks, methods, fields. Public-only by default;
`--document-private-items` opts in.

### 3.3 Generated HTML

Per-crate site with:
- Sidebar nav (modules / types / functions / traits)
- Per-item page (signature, doc, source link, examples)
- Cross-crate linking via doc comments
- Search index (full-text)
- Theme support (light / dark / Ayu)

### 3.4 Doc tests

Code blocks marked `nucleor` (or unmarked, default) extracted as
runnable tests:

````
/// ```
/// let x = 2 + 2;
/// assert_eq!(x, 4);
/// ```
````

`nuc test --doc` extracts and runs them. Each is wrapped in a
`fn main() { … }` if not present. `no_run` annotation skips
execution; `compile_fail` requires compile error; `ignore` skips.

### 3.5 Cross-crate links

```
/// See [`other_crate::Foo`] for details.
/// Or [`Bar`](crate::module::Bar) with explicit path.
```

Resolved at doc generation; broken links are warnings.

### 3.6 Compose with package manager

`docs.nucleor.dev/<crate>/<version>/` mirror of registry crates'
docs (built on publish).

### 3.7 Diagnostics

| Code | Meaning |
|---|---|
| DOC-001 | Broken intra-doc link |
| DOC-002 | Doc test fails to compile |
| DOC-003 | Doc test fails at runtime |
| DOC-004 | Missing doc on `pub` item (warning under `#![warn(missing_docs)]`) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Lexer | Doc-comment kinds | ~80 |
| AST | Attach docs to items | ~120 |
| Doc extractor | Walk AST, emit JSON intermediate | ~600 |
| HTML renderer | Templates + search | ~1500 |
| Doc test extractor + runner | Hook into `nuc test` | ~500 |
| Markdown parser | Existing rod or new | ~400 |
| `nuc doc` CLI | Subcommand | ~300 |
| Diagnostics | DOC-001…004 | ~150 |
| **Total** | | **~3650** |

---

## 5. Alternatives considered

- **External tool (Doxygen)** — works but inconsistent with the
  language; ship in core.
- **No doc gen** — non-starter for ecosystem.

## 6. Open questions

1. KaTeX/MathJax for math? Recommend yes for the science crowd.
2. Mermaid diagrams? Yes via post-processor.
3. Theme system pluggable? v0.5+.
4. RFC-flavored output (long-form docs in addition to API ref)? Yes.

## 7. Definition of done

- [ ] `///` parses, attaches to items
- [ ] HTML renders for stdlib (largest test case)
- [ ] Doc tests run
- [ ] CHANGELOG documents

## 8. Future extensions

- LaTeX (KaTeX)
- mdBook-style book docs
- Coverage / doc completeness reports

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~3650 fits
