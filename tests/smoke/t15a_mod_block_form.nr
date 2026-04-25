// T1.5a (v0.2.340) smoke: `mod foo { ... }` inline block-form is
// now recognized by the resolver. The block contents are spliced
// into the outer source (no namespacing yet — that's T1.5b).
// Brace tracking is string- and line-comment-aware so a `}` inside
// "}" or after // doesn't terminate the block early.

mod tests_inner {
    fn helper_add(a: i64, b: i64) -> i64 { return a + b; }
    fn helper_neg(x: i64) -> i64 { return 0 - x; }
}

mod tests_tricky {
    // The `}` in this comment must not close the module.
    fn brace_in_str() -> str { return "}"; }
    fn nested() -> i64 {
        let s: str = "{}";
        if 1 == 1 { return 7; };
        return 0;
    }
}

#[test]
fn test_mod_block_helper_visible_outside() {
    // Block-form has no namespacing in T1.5a; helpers are flat.
    assert_eq(helper_add(2, 3), 5);
    assert_eq(helper_neg(7), 0 - 7);
}

#[test]
fn test_mod_block_brace_in_string() {
    let s: str = brace_in_str();
    assert_eq(str_len(s), 1);
}

#[test]
fn test_mod_block_brace_in_comment_does_not_close_early() {
    assert_eq(nested(), 7);
}
