// EXPECT: error[PARSE-STMT-SEMI]
fn main() -> i64 {
    1
    2;
    return 0;
}
