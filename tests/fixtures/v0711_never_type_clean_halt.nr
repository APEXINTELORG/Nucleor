// v0.7.11 (defensive halt — COMPILER CRASH FIX): canonical Rust
// never type `!` (used for diverging fns `fn forever() -> !`,
// `panic!()`-only bodies, etc.) pre-fix CRASHED the compiler with
// SIGSEGV (rc=139) because parse_type had no `!` branch and fell
// through to a NULL deref. Now halts cleanly with `() / concrete
// type + panic!() in body` workaround pointer. Negative fixture
// (compile rejects). This is a HARD crash → clean halt fix —
// adopters porting Rust diverging-fn code no longer hit a
// compiler bug.
fn forever() -> ! {    // ← halts: never type unsupported (was SIGSEGV)
    loop {
        print_int(0);
    }
}

fn main() -> i32 {
    print_int(0);
    return 0;
}
