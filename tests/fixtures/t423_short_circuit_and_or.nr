// t423_short_circuit_and_or.nr — v0.3.148 regression fixture.
//
// Pre-v0.3.148, parse_and_expr / parse_or_expr lowered `&&` and `||`
// to bitwise `and i64` / `or i64` of both operand values. The LOGIC
// was correct for strict 0/1 booleans but the RHS was ALWAYS evaluated
// even when the LHS guard determined the result. Adopters relying on
// short-circuit safety hit silent miscompiles or crashes:
//
//   if x != 0 && deref(x).field == y { ... }   // crash if x == 0
//   if cached != null || compute_expensive() { ... }   // double work
//
// Fix: emit branch IR for op 36 (&&) and op 37 (||). For && the LHS
// being false stores 0 directly to a result alloca; for || the LHS
// being true stores 1. The RHS only evaluates when needed.
//
// Earlier v0.3.145 attempt at this fix used mid-function alloca
// placement (via ir_block_add). That broke stage C self-host with a
// silent exit on large s1 source — likely an LLVM stack-frame
// expectation. v0.3.148 uses ir_fn_add_entry_alloca which hoists the
// result slot to the entry block, the same pattern the while/loop
// lowering already uses.
//
// This fixture exercises the actual short-circuit semantic: a
// touch() helper increments a tracker Vec each time it's called.
// With short-circuit, touch() should NOT be called when the guard
// makes the result determinable. Pre-v0.3.148, touch() always ran.
// Returns 42 if all 4 short-circuit cases behave correctly.

fn touch(v: Vec<i64>) -> i64 {
    v.push(1);
    return 1;
}

fn main() -> i64 {
    // Case 1: false && touch() — touch must NOT run
    let mut t1: Vec<i64> = Vec::new();
    let cond_false: i64 = 0;
    if cond_false == 1 && touch(t1) == 1 { return 99; };
    if vec_len(t1) != 0 { return 1; };

    // Case 2: true && touch() — touch SHOULD run (RHS is reached)
    let mut t2: Vec<i64> = Vec::new();
    let cond_true: i64 = 1;
    if cond_true == 1 && touch(t2) == 1 {
        if vec_len(t2) != 1 { return 2; };
    } else {
        return 3;
    };

    // Case 3: true || touch() — touch must NOT run
    let mut t3: Vec<i64> = Vec::new();
    if cond_true == 1 || touch(t3) == 1 {
        if vec_len(t3) != 0 { return 4; };
    } else {
        return 5;
    };

    // Case 4: false || touch() — touch SHOULD run
    let mut t4: Vec<i64> = Vec::new();
    if cond_false == 1 || touch(t4) == 1 {
        if vec_len(t4) != 1 { return 6; };
    } else {
        return 7;
    };

    return 42;
}
