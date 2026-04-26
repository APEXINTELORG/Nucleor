// t447_print_vec_str_element.nr -- v0.3.181 regression fixture.
//
// NUC-FEEDBACK-006 (Nucleor_ML_Suite_ParallelAgent, 2026-04-26):
// String values printed as pointer-like integers in pandas
// string-key groupby parity examples. Adopters saw output like
// "2878868296144" where category strings ("red", "blue", "green")
// should appear.
//
// Root cause: v0.3.178 added builtin runtime-helper return-type
// fallbacks for print() dispatch, including hardcoded
// `vec_get -> i64` (and similarly `.get/.first/.last/.pop` method
// returns). For Vec<str> the element is a string pointer that
// MUST dispatch to print_str -- not print_i64. The over-aggressive
// i64 fallback printed the str pointer as an integer.
//
// Same hazard class as v0.3.143/163/164/178 -- a real expression
// adopters write produces nonsense output with no diagnostic.
//
// Fix (v0.3.181): for vec_get/first/last/pop (kind 7) and
// .get/.first/.last/.pop/.front/.back (kind 8), use
// indexed_element_full_type on the receiver to derive T from
// Vec<T>. Dispatch by element type. For str elements, leave
// p_helper empty so the default print_str fires (correct).

fn main() -> i64 {
    let mut v: Vec<str> = Vec::new();
    v.push("red");
    v.push("blue");
    v.push("green");
    print(vec_get(v, 0));   // expected "red", pre-fix pointer int
    print(vec_get(v, 1));   // expected "blue"
    print(vec_get(v, 2));   // expected "green"

    let mut vi: Vec<i64> = Vec::new();
    vi.push(42);
    print(vec_get(vi, 0));  // expected "42" (still i64 dispatch)

    let mut vf: Vec<f64> = Vec::new();
    vf.push(3.14);
    print(vec_get(vf, 0));  // expected "3.140000" (f64 dispatch)

    return 42;
}
