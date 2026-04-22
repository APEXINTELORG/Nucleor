// stack.nr — Stack (LIFO) data structure using Vec
fn stack_new() -> Vec<i32> { return Vec::new(); }
fn stack_push(s: Vec<i32>, val: i64) -> i64 { s.push(val); return 0; }
fn stack_pop(s: Vec<i32>) -> i64 {
    if s.len() == 0 { return 0 - 1; };
    let val: i64 = s.get(s.len() - 1);
    s.pop();
    return val;
}
fn stack_peek(s: Vec<i32>) -> i64 {
    if s.len() == 0 { return 0 - 1; };
    return s.get(s.len() - 1);
}
fn stack_len(s: Vec<i32>) -> i64 { return s.len(); }
fn stack_is_empty(s: Vec<i32>) -> i64 { if s.len() == 0 { return 1; }; return 0; }
