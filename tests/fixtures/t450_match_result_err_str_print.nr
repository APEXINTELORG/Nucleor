// t450_match_result_err_str_print.nr -- v0.3.184 regression
// fixture.
//
// Regression introduced in v0.3.176 (match arm binding type
// registration): I unconditionally set __type_<name> to "i64"
// for every match arm payload binding. That works for Some(i64)
// and Ok(i64) but BREAKS for Result::Err(str) -- print(err_str)
// dispatched to print_i64 and printed the str pointer as int.
//
// Same hazard class as the v0.3.181/182 vec_get/hashmap_get str
// fixes -- the i64 default was too aggressive.
//
// Fix (v0.3.184): variant-aware payload type via new
// match_bind_payload_type(ename, vname) helper. Result::Err
// defaults to "str" (the conventional payload); everything else
// stays "i64". match_bind_payloads_typed is the new entry point
// that takes a payload_type param.

fn main() -> i64 {
    let ok_v: Result<i64, str> = Ok(42);
    match ok_v {
        Ok(v) => print(v),       // expected 42 (i64 -- still works)
        Err(s) => print(s),
    }

    let err_v: Result<i64, str> = Err("bad");
    match err_v {
        Ok(v) => print(v),
        Err(s) => print(s),      // expected "bad" -- pre-fix pointer
    }

    return 42;
}
