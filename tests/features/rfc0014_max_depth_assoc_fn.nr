// RFC-0014 #[max_depth = N] on an impl associated fn (no self) (v0.5.9).
//
// probe finding 2026-05-01 (slug
// `2026-05-01-max-depth-self-assoc-fn-still-link-fails`):
// v0.5.7 closed `self.method` form of impl-method recursion under
// `#[max_depth = N]`, but the no-self assoc-fn form (recurses via
// `Type::method(...)`) still link-failed because the wrapper-rewrite's
// Layer 2 was gated on `arg_names` starting with `self`.
//
// v0.5.9 extends Layer 2: when arg_names doesn't start with `self`,
// backward-scan from the #[max_depth] line to find the enclosing
// `impl <Type> { ... }` (or `impl Trait for <Type> { ... }`). If
// found, emit the wrapper's call as `<Type>::<inner>(<args>)`. If
// not found (free fn at module level), keep the existing free-fn
// dispatch shape.
//
// EXPECT: build success, runtime exit 0, prints `3` then
// "OK rfc0014_max_depth_assoc_fn".

struct Node { val: i64 }

impl Node {
    #[max_depth = 5]
    fn count(depth: i64) -> i64 {
        if depth >= 3 { return depth; };
        Node::count(depth + 1)
    }
}

fn main() -> i32 {
    let r: i64 = Node::count(0);
    print_int(r as i32);
    if r != 3 { print("FAIL count"); return 1; };
    print("OK rfc0014_max_depth_assoc_fn");
    0
}
