// rods/rod_helpers — Cross-rod interop helpers
//
// Two distinct utility families for rods that need to break out of
// the i64-only FFI:
//
//   - **String <-> i64 vec bridge** — `vec_str_push` /
//     `vec_str_get` / `vec_str_set` let a Vec<i64> hold C-string
//     pointers. The underlying storage is a normal Vec; the pointer
//     value is just stored as i64. The "str" suffix is a reminder
//     to the reader that the i64 is a `const char *` payload.
//
//   - **Function-pointer callers** — `call_fn2(fp, a, b)` and
//     `call_fn3(fp, a, b, c)` invoke an i64-typed function pointer
//     with the given args. Used by rods that take user callbacks
//     (sort comparators, reducers, parallel-map kernels) without
//     the compiler needing to type-check across the FFI boundary.
//
// See `stdlib/runtime/rod_helpers_rt.c`.
#cfile "../runtime/rod_helpers_rt.c"

extern fn vec_push_s(v: i64, s: str);
extern fn vec_get_s(v: i64, i: i64) -> str;
extern fn hvec_push_s(v: i64, s: str);
extern fn hvec_get_s(v: i64, i: i64) -> str;
extern fn hvec_set_s(v: i64, i: i64, s: str);
extern fn call_fn2(fp: i64, a: i64, b: i64) -> i64;
extern fn call_fn3(fp: i64, a: i64, b: i64, c: i64) -> i64;

// String <-> i64 vec bridge (the `*_str_*` aliases avoid colliding
// with the core `vec_push` / `vec_get` builtins).
fn vec_str_push(v: i64, s: str) { vec_push_s(v, s); }
fn vec_str_get(v: i64, i: i64) -> str { return vec_get_s(v, i); }

// Hash-vec / NS_Sage compat aliases (mirror the runtime's hvec_*).
fn hvec_str_push(v: i64, s: str) { hvec_push_s(v, s); }
fn hvec_str_get(v: i64, i: i64) -> str { return hvec_get_s(v, i); }
fn hvec_str_set(v: i64, i: i64, s: str) { hvec_set_s(v, i, s); }

// Function-pointer callers.
fn rod_call_fn2(fp: i64, a: i64, b: i64) -> i64 { return call_fn2(fp, a, b); }
fn rod_call_fn3(fp: i64, a: i64, b: i64, c: i64) -> i64 {
    return call_fn3(fp, a, b, c);
}
