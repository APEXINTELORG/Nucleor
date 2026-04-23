// rods/string_algo — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/string_algo.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    // KMP returns a handle to a savec of match positions; just exercise it
    let _h: i64 = str_kmp("hello world", "world");
    // Levenshtein returns the edit distance directly
    let d: i64 = str_levenshtein("kitten", "sitting");
    if d != 3 { fail = fail + 1; print("FAIL levenshtein"); };
    if fail == 0 { print("OK string_algo_smoke"); };
    return fail;
}
