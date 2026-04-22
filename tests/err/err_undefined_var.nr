// EXPECT: undefined variable / type error
// This file should FAIL to compile. The reference to `undeclared_thing`
// has no binding in scope.
fn main() -> i64 {
    let x: i64 = undeclared_thing + 1;
    print(str_from_int(x));
    return 0;
}
