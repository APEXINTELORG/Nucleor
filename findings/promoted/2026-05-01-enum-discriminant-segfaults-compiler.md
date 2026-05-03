---
title: Nucleor compiler SEGFAULTS (exit 139, no diagnostic) when source contains an enum variant with a non-zero explicit discriminant. `enum X { A = 5 }` crashes the compiler. Multi-variant `enum X { A = 0, B = 1 }` (canonical Rust) crashes. Only the trivial all-zero discriminant case compiles. CRASH-class compiler bug — translates to "build hangs / crashes" for adopters.
severity: CRITICAL crash-class (compiler segfault on canonical Rust syntax — no diagnostic)
probe_file: probes/enums/enum_discriminant_segfault.nr (probe-branch)
diagnostic_actual: pre-fix — `bash: ... Segmentation fault ./bin/nucleor.exe run …` `exit=139`. No Nucleor-side diagnostic.
diagnostic_expected: clean ERROR `enum explicit discriminants not yet supported in v0.6; use plain variants and rely on order-based discriminants` BEFORE the segfaulting code path.
discovered_against: main v0.5.28 (probe rebased)
commit: probe (post-rebase) + main 5c8c9c08
status: CLOSED in v0.6.35 via parse-time NR035 halt at the `=` token in `parse_enum_decl`. Real explicit-discriminant lowering deferred to a post-v0.6 RFC.
---

## Closure (main agent v0.6.35)

`compiler/nucleor_s1_compiler.nr` `parse_enum_decl` variant-loop —
after consuming `vname`, checks if the next token is `=` (token
kind 40 in the lexer). If yes, emits `error[NR035]` with the
workaround pointer and panics cleanly with the variant + enum
name in the panic message.

NR035 registered in:
- `is_known_diag_code` (compiler).
- `tools/nucleor_tools_suite.nr` (title + explanation + RFC-ref).
- `tools/verify.sh` + `tools/verify.ps1` codes-arrays (T3.23 +
  T3.24 drift gates).
- `docs/spec/Nucleor_Error_Codes.md` (NR series row).

## Adopter migration

```nucleor
// Pre-v0.6.35: SEGFAULT, exit 139, no diagnostic
enum Code { OK = 0, WARN = 1, ERR = 2 }

// v0.6.35: clean NR035 halt at parse-time with workaround pointer.
//
// Workaround: drop the `= N` and rely on order-based discriminants.
//   enum Code { OK, WARN, ERR }   // discriminants 0, 1, 2 in order
//
// For FFI / wire-protocol values needing specific numbers, build
// a separate const table (`const OK_CODE: i64 = 0;` etc.) until
// real explicit-discriminant lowering lands.
```

## Forward-roadmap (real explicit-discriminant support)

Real explicit-discriminant lowering needs:
- Enum AST to carry per-variant i64 values (currently only the
  variant name + payload types are stored — kind 37 has 2 fields).
- IR-emit path to propagate the explicit values to match-arm
  dispatch + `as i32`/`as i64` cast lowering.
- Type-checker to enforce uniqueness across variants of the same
  enum (Rust E0081 — duplicate explicit discriminant value).
- Negative-discriminant support (Rust permits `enum X { A = -1 }`).

Substantial. Deferred to a post-v0.6 RFC.

## Promoted

- Fixture: `tests/err/err_nr035_enum_explicit_discriminant.nr`.
- Fix shipped: v0.6.35.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
