// t385_iter_count.nr — v0.3.108 regression fixture.
//
// Pins `.iter().count()` as the iterator-length terminator
// (mirrors Rust `Iterator::count()`). Pre-v0.3.108, the canonical
// pattern `let n = v.iter().count();` failed at clang link with
// `unresolved external symbol __nucleor_vec_count` — `count` was
// not in `iter_method_for_vec` and there was no runtime helper.
// Adopters reaching for this terminator (very common in iterator
// pipelines that report a count rather than collect to a Vec)
// hit this on first use.
//
// Implementation mirrors the v0.3.102 `.collect()` ship:
//   1. Runtime: `__nucleor_vec_count_i64` returns v->len.
//   2. Compiler: `count` added to iter_method_for_vec; registered
//      in get_rt_name + is_ptr_arg + is_ptr_ret(=0, returns i64)
//      + IR header declare list. Mirrored in tools_suite.
//   3. helper_manifest.toml regenerated.
//
// Returns 5 from a 5-element vec, proving the chain
// `vec![1,2,3,4,5].iter().count()` lowers and the int return
// reaches the call site without ABI mismatches.

fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3, 4, 5];
    return v.iter().count();
}
