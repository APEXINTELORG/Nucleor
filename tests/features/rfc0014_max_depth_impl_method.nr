// RFC-0014 #[max_depth = N] on an impl method (v0.5.7).
//
// Probe-agent finding 2026-05-01 (slug
// `2026-05-01-max-depth-impl-method-self-recursion-not-bounded`):
// `#[max_depth = N]` on an impl method that recursively calls
// `self.method(depth + 1)` falsely fired DEPTH-001. Two-layer bug:
//
// 1. The static analyzer's `md_first_param_name` returned `self` as
//    the depth-binding parameter (it didn't skip the method
//    receiver), so the guard / increment patterns checked against
//    the wrong identifier.
// 2. The wrapper-rewrite (`expand_max_depth`) emitted a call to the
//    inner via free-fn dispatch `__nuc_md_inner(self, depth)` even
//    when the rewritten fn was an impl method. clang link then
//    failed with "undefined value '@__nuc_md_inner_*'" because the
//    inner had been registered as an impl method (Tree-mangled),
//    not a free fn.
//
// v0.5.7 fixes both: `md_first_param_name` skips a leading `self`
// (or `&self` / `&mut self`) and returns the next ident; the
// wrapper-rewrite detects a `self`-prefixed `arg_names` and emits
// `self.<inner>(<rest>)` so the call lowers as a method dispatch.
//
// EXPECT: build success, runtime exit 0, prints `3` then
// "OK rfc0014_max_depth_impl_method".

struct Tree { val: i64 }

impl Tree {
    #[max_depth = 5]
    fn count(self, depth: i64) -> i64 {
        if depth >= 3 { return depth; };
        self.count(depth + 1)
    }
}

fn main() -> i32 {
    let t: Tree = Tree { val: 0 };
    let r: i64 = t.count(0);
    print_int(r as i32);
    if r != 3 { print("FAIL count"); return 1; };
    print("OK rfc0014_max_depth_impl_method");
    0
}
