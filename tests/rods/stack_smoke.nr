// rods/stack — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/stack.nr"

fn main() -> i64 {
    let s: Vec<i32> = stack_new();
    stack_push(s, 42);
    stack_push(s, 7);
    let mut fail: i64 = 0;
    if stack_len(s) != 2 { fail = fail + 1; print("FAIL len"); };
    if stack_peek(s) != 7 { fail = fail + 1; print("FAIL peek"); };
    if stack_pop(s) != 7 { fail = fail + 1; print("FAIL pop"); };
    if stack_is_empty(s) != 0 { fail = fail + 1; print("FAIL empty"); };
    stack_pop(s);
    if stack_is_empty(s) != 1 { fail = fail + 1; print("FAIL empty2"); };
    if fail == 0 { print("OK stack_smoke"); };
    return fail;
}
