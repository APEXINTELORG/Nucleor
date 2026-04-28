// repro_v61_vec_eq_arith_guard.nr
//
// v0.4.61 NUC-FEEDBACK silent-miscompute close — closes deferred
// item #1 from the queue (Vec<T> arithmetic + ==/!= silent
// miscompute).
//
// Pre-fix `v1 == v2` for two Vec<T> values returned FALSE even when
// the elements matched (binop did integer pointer-compare on the
// Vec ptrs). `v1 + v2` etc. silently SIGSEGVed (i64_add on Vec
// ptrs produced garbage that crashed when later used). Adopters
// writing the canonical Rust idiom (where Vec<T>::PartialEq does
// element-wise compare) got quiet wrong results.
//
// v0.4.61 emits TYP-011 with a workaround hint (vec_len + element
// loop). The source-scan fallback recovers `Vec<T>` from
// `let v: Vec<T> = vec![...]` declarations even when tenv stores
// "" because vec! macro's init type couldn't be inferred at type-
// check. This was the path that crashed the compiler in v0.4.55;
// v0.4.61 ships it cleanly by binding lhs/rhs nids to local i64
// vars and only invoking infer_var_type_from_source under a guarded
// kind-3 check.

fn main() -> i64 {
    let v1: Vec<i64> = vec![1, 2, 3];
    let v2: Vec<i64> = vec![1, 2, 3];
    if v1 == v2 {                            // TYP-011 expected
        println!("eq");
    } else {
        println!("ne");
    };
    return 0;
}
