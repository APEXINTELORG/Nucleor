// EXPECT: error[TYP-041] duplicate struct decl `W` (Rust E0428)
// err_typ_041_dup_struct_decl — v0.6.27 negative fixture
// closes probe finding 2026-05-02-duplicate-struct-decl-silently-
// accepted (repros 1+2). Pre-fix `struct W { … } struct W { … }`
// was silently accepted; first decl won for `W { … }` initialization
// with the second decl's fields unreachable. v0.6.27 mirrors Rust
// E0428 at the collection pass.
//
// EXPECT: TYP-041 fires; build halts.

struct W { v: i64 }
struct W { name: str }

fn main() -> i32 { 0 }
