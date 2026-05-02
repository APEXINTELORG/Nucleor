// stdlib `str_substring_strict` opt-in bounds-checked variant.
//
// EXPECT: build success, runtime exit 0, output "OK str_substring_strict_basic".

fn main() -> i32 {
    let s: str = "nucleor";

    let a: str = str_substring_strict(s, 0, 3);
    if str_eq(a, "nuc") == 0 { print("FAIL prefix"); return 1; };

    let b: str = str_substring_strict(s, 3, 7);
    if str_eq(b, "leor") == 0 { print("FAIL suffix"); return 2; };

    let empty: str = str_substring_strict(s, 4, 4);
    if str_len(empty) != 0 { print("FAIL empty"); return 3; };

    print("OK str_substring_strict_basic");
    0
}
