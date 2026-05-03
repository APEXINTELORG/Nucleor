// EXPECT: error[TYP-039] field `x` is already declared in this struct (Rust E0124)
// err_typ_039_dup_field_in_struct_decl — v0.6.27 negative fixture
// closes probe finding 2026-05-02-duplicate-struct-decl-silently-
// accepted (repro 3). Pre-fix, `struct P { x: i64, x: i64 }` parsed
// silently and TYP-017 only fired at the init site. v0.6.27 catches
// the duplicate field at the decl-site so adopters writing typo'd
// decls (`struct Date { day: i64, day: i64, month: i64 }`) get the
// signal at the decl, not at the first construction.
//
// EXPECT: TYP-039 fires; build halts.

struct P { x: i64, x: i64, y: i64 }

fn main() -> i32 { 0 }
