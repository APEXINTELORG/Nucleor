// EXPECT: error[NR036] recursive type
// err_nr036_self_recursive_struct — v0.6.36 negative fixture
// closes probe finding 2026-05-01-self-recursive-struct-infinite-
// size-accepted. Pre-fix this Rust E0072 case was accepted at
// parse + type-check and crashed at instantiation with
// STATUS_STACK_OVERFLOW (Windows exception 0xC00000FD) — the
// struct contains itself directly so the size is infinite.
// v0.6.36 catches it at parse-time. Workaround: wrap in
// Box<Node>, Option<Box<Node>>, or &Node so the field is a
// fixed size.
//
// EXPECT: NR036 fires; build halts (no segfault).

struct Node { val: i64, next: Node }

fn main() -> i32 { 0 }
