// Probe NUC-FEEDBACK-008: print after dynamic str output truncates
import "stdlib/rods/strings.nr"

fn build_str() -> str {
    let mut s: str = "";
    let chars: Vec<i64> = vec![78, 117, 99, 108, 101, 111, 114];
    let mut i: i64 = 0;
    while i < 7 {
        let c: str = strings_char_to_str(chars[i]);
        s = str_concat(s, c);
        i = i + 1;
    };
    return s;
}

fn main() -> i64 {
    let decoded: str = build_str();
    print("decoded text:");
    print(decoded);
    print("decoded length:");
    print(str_len(decoded));
    println!("after end print done");
    return 0;
}
