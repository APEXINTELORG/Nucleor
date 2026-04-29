// repro_v83_uninit_immutable_let.nr — v0.4.83 TYP-008 ext.
// Pre-fix `let x: i64;` (immutable, no initializer) silently
// compiled — the binding used the LLVM alloca's zero-init memory,
// so reads returned 0 with no diagnostic. Adopters thought
// Nucleor zero-defaults all bindings; in fact this is undefined
// behavior territory in any real codegen.
//
// Rust E0381 rejects this at first read; Nucleor doesn't do
// flow analysis. v0.4.83 catches the unambiguous case (immutable
// + no init = the binding can NEVER be assigned later — would
// hit OWN-008 — so it's a definite zero-read silent miscompute).
//
// Accepted patterns (still compile):
//   let mut x: i64;        — mutable, can be assigned later
//   let x: i64 = 5;        — immutable with init
//   let _: i64 = anything; — wildcard binding (intentional discard)
//
// EXPECT: build fails (msg contains "without initializer").

fn main() -> i64 {
    let x: i64;
    println!("{}", x);
    return 0;
}
