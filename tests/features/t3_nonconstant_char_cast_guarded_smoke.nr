fn main() -> i64 {
    let v: i64 = args_count() + 64;
    if v >= 0 && v < 0xD800 {
        let c: char = v as char;
        let n: i64 = c as i64;
        if n != v {
            return 1;
        };
        return 0;
    };
    return 2;
}
