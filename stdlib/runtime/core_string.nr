// core_string.nr — Nucleor-native string operations (Stage A)
// Replaces the C runtime's strlen/strcmp/str_concat with pure Nucleor.
//
// Strings in Nucleor are immutable byte sequences (UTF-8).
// Represented as a pointer to null-terminated bytes.
// All string operations allocate new storage (no mutation).

// These will use nr_alloc from core_memory.nr when compiled
// through the LLVM IR emitter. For now, they use the C runtime.

fn nr_str_len(s: str) -> i32 {
    let mut i: i32 = 0;
    while str_char_at(s, i) != 0 {
        i = i + 1;
    };
    i
}

fn nr_str_eq(a: str, b: str) -> bool {
    let la: i32 = str_len(a);
    let lb: i32 = str_len(b);
    if la != lb { return false; };
    let mut i: i32 = 0;
    while i < la {
        if str_char_at(a, i) != str_char_at(b, i) { return false; };
        i = i + 1;
    };
    return true;
}

// Note: nr_str_concat, nr_str_substring, nr_str_char_at will be
// implemented using nr_alloc + raw byte copying when the LLVM IR
// emitter provides memory access instructions (load/store).
// For the initial bootstrap, we use the C runtime versions.

fn main() -> i32 {
    // Test nr_str_len
    let s: str = "hello";
    let len: i32 = nr_str_len(s);
    if len == 5 { print("str_len: PASS"); } else { print("str_len: FAIL"); print_int(len); };

    // Test nr_str_eq
    if nr_str_eq("hello", "hello") { print("str_eq same: PASS"); } else { print("str_eq same: FAIL"); };
    if !nr_str_eq("hello", "world") { print("str_eq diff: PASS"); } else { print("str_eq diff: FAIL"); };
    if !nr_str_eq("hi", "hello") { print("str_eq len: PASS"); } else { print("str_eq len: FAIL"); };

    print("=== CORE STRING MODULE READY ===");
    0
}
