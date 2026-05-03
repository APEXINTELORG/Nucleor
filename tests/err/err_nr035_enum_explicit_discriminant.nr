// EXPECT: error[NR035] explicit enum discriminants
// err_nr035_enum_explicit_discriminant — v0.6.35 negative fixture
// closes probe finding 2026-05-01-enum-discriminant-segfaults-
// compiler. Pre-fix this canonical Rust C-style enum syntax
// crashed the compiler with SEGFAULT (exit 139) inside the
// type/ownership pass — no diagnostic. v0.6.35 halts at parse-
// time at the `=` token with a clean NR035 diagnostic + workaround
// pointer (drop the `= N` and rely on order-based discriminants;
// for FFI / wire-protocol-required values use a separate const
// table until real explicit-discriminant lowering ships).
//
// EXPECT: NR035 fires; build halts (no segfault).

enum Code { OK = 0, WARN = 1, ERR = 2 }

fn main() -> i32 { 0 }
