// repro_v98_debug_vec_str_and_option.nr — extends v0.4.97.
// v0.4.97 only had vec_to_debug_str_i64. v0.4.98 adds dispatch
// for Vec<str> → ["a", "b"] and Vec<Option<i64>> →
// [Some(1), None, Some(3)] via type_first_arg type lookup.
//
// EXPECT runtime output:
//   ["a", "b", "c"]
//   [Some(1), None, Some(3)]

fn main() -> i64 {
    let v: Vec<str> = vec!["a", "b", "c"];
    println!("{:?}", v);

    let w: Vec<Option<i64>> = vec![Some(1), None, Some(3)];
    println!("{:?}", w);

    return 0;
}
