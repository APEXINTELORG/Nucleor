// EXPECT: ERROR: `(expr)(args)` direct-call form
//
// v0.6.12 (probe finding 2026-05-02-fn-ptr-struct-field-direct-call-
// returns-pointer): pre-fix `(struct.field)(args)` for a fn-pointer
// field silently lowered as if `(args)` were a separate parenthesized
// expression — the call's args were dropped and the result was the
// function-pointer ADDRESS, not the call result. Adopters writing the
// canonical Rust dispatch-table-via-struct pattern got a giant address-
// like number where they expected the call result.
//
// v0.6.12 fix: clean halt at parse time with workaround pointer
// (extract the fn-pointer to a local first, then call it). Real fix —
// extending parse_postfix to accept `(args)` on any callable expression
// + emitting indirect-call IR via inttoptr + call — is a substantial
// multi-ship change deferred to a follow-on RFC.

struct Op { f: fn(i64) -> i64 }
fn dbl(x: i64) -> i64 { return x * 2; }

fn main() -> i32 {
    let o: Op = Op { f: dbl };
    print_int((o.f)(21) as i32);
    return 0;
}
