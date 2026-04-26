// Probe NUC-FEEDBACK-008 v2: replicate original interleaving pattern.
import "stdlib/rods/strings.nr"

struct TI {
    data: Vec<i64>,
    len: i64,
}

fn ti_new(text: str) -> TI {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    let n: i64 = str_len(text);
    while i < n {
        v.push(str_char_at(text, i));
        i = i + 1;
    };
    return TI { data: v, len: n };
}

fn ti_decode(t: &TI) -> str {
    let mut s: str = "";
    let mut i: i64 = 0;
    while i < t.len {
        s = str_concat(s, strings_char_to_str(t.data[i]));
        i = i + 1;
    };
    return s;
}

fn ti_count(t: &TI) -> i64 {
    return t.len;
}

fn ti_print_flat(label: str, t: &TI) -> i64 {
    print(label);
    let mut i: i64 = 0;
    while i < t.len {
        print(t.data[i]);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    let tokens: TI = ti_new("Nucleor ML!");
    let decoded: str = ti_decode(&tokens);
    ti_print_flat("char tokenizer ids:", &tokens);
    print("decoded text:");
    print(decoded);
    print("decoded length:");
    print(ti_count(&tokens));
    println!("end");
    return 0;
}
