// nucleor:module-namespace mod_b
// §H spike module B. Same shape as mod_a.nr but with prefix `mod_b`.
// Without §H, kind_to_str / run would link-collide with mod_a.

pub fn kind_to_str(k: i64) -> str {
    if k == 0 { return "b_zero"; };
    if k == 1 { return "b_one"; };
    return "b_other";
}

pub fn run(k: i64) -> str {
    return kind_to_str(k);
}
