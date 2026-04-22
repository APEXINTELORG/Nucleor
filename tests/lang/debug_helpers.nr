// debug_helpers.nr — RFC: dbg!/eprint! family
// dbg(v) prints "[debug] v" to stderr and returns the value untouched.
// eprint(s) writes to stderr.

fn main() -> i32 {
    let x: i64 = 42;
    let y: i64 = dbg(x);     // prints to stderr, returns 42
    if y != x { print("FAIL: dbg should be identity\n"); return 1; };

    eprint("warning: testing eprint");
    eprint_int(99);
    dbg_str("inspecting message");

    print("OK debug_helpers");
    return 0;
}
