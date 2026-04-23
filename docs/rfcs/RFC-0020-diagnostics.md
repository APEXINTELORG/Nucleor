# RFC-0020 — Diagnostic Upgrade: spans, snippets, color, suggestions

| Field | Value |
|---|---|
| **Number** | 0020 |
| **Title** | Diagnostic upgrade — Rust-style errors with spans, source snippets, ANSI color, fix suggestions |
| **Status** | Implemented (partial) v0.1.34–v0.1.59 — see `docs/milestones/v0.2.0.md`; v0.2 DoD met (LineMap + JSON + 158 explain entries); full span migration deferred to v0.4 |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 |
| **Depends on** | none |

---

## 1. Summary

Replace today's `OWN-008 cannot assign to immutable binding` with
Rust E-style output:

```
error[OWN-008]: cannot assign to immutable binding `x`
  --> src/main.nr:14:5
   |
13 |     let x: i64 = 10;
   |         - help: consider `let mut x` here
14 |     x = 20;
   |     ^^^^^^ cannot assign twice to immutable binding
   |
   = note: immutable bindings are sealed at declaration
```

Color, spans, snippets, suggestions. Compiler errors become helpful
rather than cryptic.

---

## 2. Motivation

Today: `error: cannot assign to immutable binding` — name + phrase, no
location, no context. Users have to grep their codebase to find the
problem.

The compiler is good enough that wrong code is the common case in
practice. Bad diagnostics turn every error into a debugging session.
Rust's diagnostic-quality investment is one reason it has the
adoption it does.

---

## 3. Design

### 3.1 The `Diagnostic` type

```nucleor
struct Diagnostic {
    code: &'static str,        // "OWN-008"
    severity: Severity,        // error / warning / note / help
    message: String,
    span: Span,                // primary location
    secondary_spans: Vec<(Span, String)>,   // related locations with messages
    notes: Vec<String>,
    helps: Vec<String>,
    suggestions: Vec<Suggestion>,    // structured fix-it
}
```

### 3.2 The `Span` type

```nucleor
struct Span {
    file: FileId,
    start_byte: u32,
    end_byte: u32,
}
```

Lexer/parser track byte spans on every token. AST/IR carry spans on
every node. The `LineMap` per file converts byte → line/column for
display.

### 3.3 Renderer

ANSI color when stdout is a TTY. Plain text when piped or
`--no-color`. JSON output for IDE consumption (`--message-format=json`).

```
error[CODE]: short message
  --> path/to/file.nr:LINE:COL
   |
LINE | source line
   | ^^^^ inline message under the span
   |
   = help: suggestion text
   = note: additional context
```

### 3.4 Suggestions

Structured fix-it: machine-readable replacement for IDE auto-apply.

```nucleor
struct Suggestion {
    span: Span,
    replacement: String,
    applicability: Applicability,    // MachineApplicable / MaybeIncorrect / HasPlaceholders / Unspecified
}
```

`MachineApplicable` suggestions can be auto-applied via `nuc fix`.

### 3.5 Multi-span errors

```
error[BORROW-003]: cannot borrow `x` as mutable, already borrowed as immutable
  --> src/main.nr:14:9
   |
12 |     let r1 = &x;
   |              -- immutable borrow occurs here
13 |     let r2 = &mut x;
   |              ^^^^^^ mutable borrow occurs here
14 |     drop(r1);
   |          -- immutable borrow later used here
```

### 3.6 Backtraces in panics

In `--profile=debug`, panics print Rust-style backtrace:

```
thread 'main' panicked at 'index out of bounds: 12 not in 0..10', src/main.nr:14:5
note: run with NUC_BACKTRACE=1 environment variable to display backtrace
```

`NUC_BACKTRACE=1` enables full unwind. Available because we ship
LLVM unwind tables in debug.

### 3.7 Diagnostic API for users

Compiler-internal `Diagnostic` constructor exposed as
`diagnostic!(code, span, message)` macro. Users (writing custom
tooling) can produce same-format errors.

### 3.8 Error code documentation

Every code (`OWN-008`, `RT-001`, `MATCH-002`, etc.) gets a doc page
at `docs/error-codes/CODE.md`. `nuc explain CODE` prints it.

```
$ nuc explain OWN-008
This error occurs when ...
```

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Lexer | Track byte spans on every token | ~150 |
| Parser/AST | Span on every node | ~200 |
| `Diagnostic` infrastructure | New struct + builder | ~400 |
| Renderer (text + JSON) | ANSI rendering | ~600 |
| Span propagation | Through type checker, IR, codegen | ~500 |
| Migrate existing errors | ~80 sites in compiler | ~600 |
| `nuc explain` + per-code docs | New command + ~80 doc pages | ~400 |
| **Total** | | **~2850** |

---

## 5. Alternatives considered

- **External tool** — defeats the purpose; compiler must own this.
- **Match LLVM diagnostic format** — Rust style is more user-friendly.
- **No spans, just file:line** — half-measure; do it once properly.

## 6. Open questions

1. Suggestion auto-apply via `nuc fix` — yes for MachineApplicable,
   prompt for MaybeIncorrect.
2. Per-warning suppression (`#[allow(...)]`) — ship in v0.2.
3. Error code stability — codes never change meaning across releases;
   add new codes for new diagnostics.

## 7. Definition of done

- [ ] All errors carry spans
- [ ] Renderer produces Rust-style output with color
- [ ] `nuc explain CODE` works for all current codes
- [ ] JSON output for IDEs
- [ ] `nuc fix --auto` applies MachineApplicable suggestions
- [ ] CHANGELOG documents

## 8. Future extensions

- "Did you mean" typo-correction (Levenshtein search over symbols)
- Inline-comment-driven test diagnostics (`//~ ERROR foo` style)
- Severity escalation per project (`#![deny(unused)]` style)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2850 fits
- [ ] Pitch survives ("debugging the compiler error becomes easier
      than the underlying bug")
