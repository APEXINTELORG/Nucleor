// imports.nr — verify cross-rod symbol resolution
import "stdlib/rods/strings.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    if strings_contains("hello world", "world") != 1 {
        print("FAIL imports: strings_contains");
        fail = fail + 1;
    };
    if strings_starts_with("nucleor", "nuc") != 1 {
        print("FAIL imports: strings_starts_with");
        fail = fail + 1;
    };
    if strings_ends_with("nucleor", "leor") != 1 {
        print("FAIL imports: strings_ends_with");
        fail = fail + 1;
    };

    let upper: str = strings_to_upper("hi");
    if str_eq(upper, "HI") != 1 {
        print("FAIL imports: strings_to_upper");
        fail = fail + 1;
    };

    if fail == 0 { print("OK imports"); return 0; };
    return 1;
}
