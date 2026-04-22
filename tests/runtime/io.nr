// io.nr — basic print and string concatenation paths
fn main() -> i64 {
    let s: str = str_concat("Hello, ", "Nucleor!");
    if str_eq(s, "Hello, Nucleor!") != 1 {
        print("FAIL io: concat");
        return 1;
    };
    print(s);          // round-trip via stdout
    print("OK io");
    return 0;
}
