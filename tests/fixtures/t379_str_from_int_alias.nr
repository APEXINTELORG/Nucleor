// t379_str_from_int_alias.nr — v0.3.103 regression fixture.
//
// Pins `str_from_int(n)` as an alias for `int_to_str(n)`. Pre-v0.3.103,
// only `int_to_str` was registered as a user-callable runtime helper —
// but the compiler's own self-host source uses the historical name
// `str_from_int` everywhere, and Rust users who notice the function
// in the source were natural to reach for the same name. They hit
// `clang: use of undefined value '@str_from_int'` on attempt. The
// fix is a one-line route in get_rt_name (and the drift mirror) so
// both names resolve to `__nucleor_int_to_str`.
//
// Returns 2 = str_len("42"), proving the alias dispatches correctly.

fn main() -> i64 {
    let s: str = str_from_int(42);
    return str_len(s);
}
