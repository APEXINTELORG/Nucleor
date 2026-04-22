// regex.nr — basic character-class predicates from stdlib/rods/regex.nr
// (For full regex with quantifiers, see rods/rust.nr backed by Rust's regex crate.)
import "stdlib/rods/regex.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // regex_match_digit / regex_match_alpha take (str, position)
    if regex_match_digit("abc7", 3) != 1 {
        print("FAIL regex: digit at pos 3");
        fail = fail + 1;
    };
    if regex_match_digit("abc7", 0) == 1 {
        print("FAIL regex: false positive digit at pos 0");
        fail = fail + 1;
    };
    if regex_match_alpha("abc7", 0) != 1 {
        print("FAIL regex: alpha at pos 0");
        fail = fail + 1;
    };
    if regex_match_alpha("abc7", 3) == 1 {
        print("FAIL regex: false positive alpha at pos 3");
        fail = fail + 1;
    };

    // regex_find_first(haystack, pattern_string)
    let pos: i64 = regex_find_first("hello world", "world");
    if pos != 6 {
        print("FAIL regex: find_first should be 6");
        fail = fail + 1;
    };

    if fail == 0 { print("OK regex"); return 0; };
    return 1;
}
