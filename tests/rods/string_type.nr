// rods/string_type — verify the heap String wrapper
import "stdlib/rods/string_type.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let s: i64 = string_of("hello");
    if string_length(s) != 5 { fail = fail + 1; print("FAIL len 5"); };
    if string_byte_at(s, 0) != 104 { fail = fail + 1; print("FAIL byte 0"); };

    string_concat_str(s, ", world");
    if string_length(s) != 12 { fail = fail + 1; print("FAIL len 12 after concat"); };

    if string_equals_str(s, "hello, world") != 1 { fail = fail + 1; print("FAIL equals_str"); };
    if string_has_prefix(s, "hello") != 1 { fail = fail + 1; print("FAIL prefix"); };
    if string_has_suffix(s, "world") != 1 { fail = fail + 1; print("FAIL suffix"); };
    if string_has_substr(s, ", w") != 1 { fail = fail + 1; print("FAIL substr"); };

    let copy: i64 = string_copy(s);
    if string_equals(s, copy) != 1 { fail = fail + 1; print("FAIL copy equals"); };

    string_drop(s);
    string_drop(copy);

    if fail == 0 { print("OK string_type"); return 0; };
    return 1;
}
