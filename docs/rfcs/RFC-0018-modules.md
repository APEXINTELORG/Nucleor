# RFC-0018 — Module System: `mod`, `pub`, `use`, paths, visibility

| Field | Value |
|---|---|
| **Number** | 0018 |
| **Title** | Module system — `mod foo;`, `pub fn`, `use crate::x::y`, namespacing |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 |
| **Depends on** | none |

---

## 1. Summary

Replace `import "path/to/file.nr"` with a real module system:

```nucleor
// src/main.nr
mod parser;        // declares src/parser.nr or src/parser/mod.nr
mod codegen;
use crate::parser::Token;
use crate::codegen::{Backend, Optimize};

fn main() { ... }
```

```nucleor
// src/parser.nr
pub struct Token { ... }
pub fn parse(src: &str) -> Vec<Token> { ... }

mod helpers;       // src/parser/helpers.nr — private to parser
fn internal_only() { ... }     // not pub — private to parser module
```

Three resolutions:
- `crate::x::y` — project-root-relative
- `super::x` — parent-module-relative
- `std::x` — standard library
- `<package>::x` — third-party from registry (RFC-0019)

---

## 2. Motivation

Current `import "path"` makes every program a flat global namespace.
Two `fn helper` in different files collide. No visibility control.
Required by T1.4 (package manager) and T1.7 (Linux paths differ).

Prior art: Rust mod system (canonical). Go uses package-per-directory.
Recommend Rust style — cleaner, more flexible (multiple modules per
crate, nested visibility).

---

## 3. Design

### 3.1 Module declaration

```nucleor
mod parser;        // resolves to ./parser.nr or ./parser/mod.nr
mod codegen { ... }   // inline module
```

### 3.2 Visibility

```nucleor
pub fn public_api() { }
pub(crate) fn crate_only() { }     // visible within same crate
pub(super) fn parent_only() { }    // visible to parent module
fn private() { }                   // visible only within current module
```

`pub` applies to `fn`, `struct`, `enum`, `trait`, `mod`, `use`,
`const`, `static`, `type`. Struct fields: per-field `pub`.

### 3.3 Path syntax

```nucleor
crate::parser::Token       // from project root
super::utils::format       // parent module
self::helpers::slug        // current module (rarely needed)
std::io::Read              // standard library
toml::Parser               // third-party package
```

### 3.4 Use declarations

```nucleor
use crate::parser::Token;
use crate::parser::{Token, Lexer, Span};
use crate::parser::*;                      // glob (discouraged outside prelude)
use crate::parser::Token as ParserToken;   // rename
pub use crate::parser::Token;              // re-export
```

### 3.5 Project structure

```
my_project/
├── nuc.toml
├── src/
│   ├── main.nr      # crate root (binary)
│   ├── parser.nr    # mod parser;
│   ├── parser/
│   │   ├── helpers.nr     # mod helpers; (within parser)
│   │   └── span.nr        # mod span; (within parser)
│   └── codegen.nr
└── tests/
    └── integration.nr
```

For libraries: `src/lib.nr` is the crate root.

### 3.6 Migration from import

`import "stdlib/rods/json.nr"` becomes `use std::json` (after stdlib
re-org per RFC). Old `import` is deprecated v0.2, removed v0.4.

A `nuc fix --imports` tool migrates v0.1.x code.

### 3.7 Name mangling

Module path appears in mangled symbol names so `parser::helper` and
`codegen::helper` don't collide at link time:
`__nucleor_parser__helper`, `__nucleor_codegen__helper`.

### 3.8 Composition with package manager (RFC-0019)

Top-level package name from `nuc.toml` becomes accessible as
`<pkg>::...` in other crates. Inside the crate, refer via `crate::`.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| MOD-001 | Module file not found at expected path |
| MOD-002 | Path references non-existent module/item |
| MOD-003 | Visibility violation (private item used outside module) |
| MOD-004 | Glob `use *` from a module without an explicit prelude (warning) |
| MOD-005 | Circular module dependency |
| MOD-006 | Two `use` declarations bind the same name |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `mod`, `use`, visibility keywords, paths | ~400 |
| Resolver | Path-to-symbol resolution, visibility check | ~600 |
| Codegen | Mangling | ~150 |
| Migration tool `nuc fix --imports` | Convert v0.1 imports | ~300 |
| Diagnostics | MOD-001…006 | ~250 |
| **Total** | | **~1700** |

---

## 5. Alternatives considered

- **Stay with `import` only** — blocks package manager.
- **Go-style package-per-directory** — less flexible, conflates dir
  with namespace.
- **Header-style** (`include`) — preprocessor-textual; rejected.

## 6. Open questions

1. Inline `mod foo { … }` — useful for tests; ship in v0.2.
2. `mod tests` convention for in-source tests — yes, mirror Rust.
3. Re-export shadowing — error on ambiguity.
4. Path-segment case convention — `snake_case` modules,
   `UpperCamelCase` types.

## 7. Definition of done

- [ ] All path forms parse, resolve, mangle correctly
- [ ] Visibility enforced
- [ ] `nuc fix --imports` migrates existing code
- [ ] Verify gate green after migration
- [ ] CHANGELOG documents migration

## 8. Future extensions

- Module-level conditional compilation (`#[cfg(target_os = "linux")] mod foo;`) — v0.4
- `extern crate`-style explicit dep declaration — v0.4

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~1700 fits
- [ ] Migration tool covers >90% of v0.1.x code
