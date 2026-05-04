// v0.8.12 fixture: str method dispatch for untyped let bindings.
//
// Pre-fix: `let s = "literal"` (no type annotation) left `__type_s`
// unregistered because the let-lowering type-inference block had no
// kind-2 (str literal) branch. Method calls on `s` fell through
// recv_is_vec==1 → tried to emit `vec_split` / `vec_contains` /
// etc. — wrong-class TYP-005 "undefined function 'vec_split'" at
// clang link. Explicitly-typed `let s: str = "literal"` was fine.
//
// Fix (v0.8.12): added `else if ik == 2 { tstr = "str"; }` to the
// let-lowering type-inference block, registering `__type_s = "str"`
// for string-literal RHS bindings without annotations.

fn main() -> i64 {
    // split: pre-fix emitted vec_split (TYP-005 undefined)
    let sentence = "alpha beta gamma";
    let parts: Vec<str> = sentence.split(" ");
    let part_count: i64 = vec_len(parts);

    // contains: pre-fix emitted vec_contains_i64 (silent wrong answer)
    let needle = "beta";
    let found: i64 = if sentence.contains(needle) { 1 } else { 0 };

    // starts_with: pre-fix emitted vec_starts_with (TYP-005 undefined)
    let sw: i64 = if sentence.starts_with("alpha") { 1 } else { 0 };

    // len: pre-fix emitted vec_len (silent miscompute)
    let greeting = "hi";
    let gl: i64 = greeting.len() as i64;

    // expected: 3 + 1 + 1 + 2 = 7
    part_count + found + sw + gl
}
