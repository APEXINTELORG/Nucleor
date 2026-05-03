// EXPECT: error[TYP-040] duplicate enum variant `A` in `enum E` (Rust E0428)
// err_typ_040_dup_enum_variant — v0.6.27 negative fixture
// closes probe finding 2026-05-02-enum-duplicate-variant-names-
// silently-accepted. Pre-fix `enum E { A, A, A }` was silently
// accepted with all 3 variants kept distinct, and MATCH-001
// confirmed "1 arms for enum with 3 variants" — Nucleor saw them
// as separate. v0.6.27 mirrors Rust E0428 at decl-time.
//
// EXPECT: TYP-040 fires; build halts.

enum E { A, A, A }

fn main() -> i32 { 0 }
