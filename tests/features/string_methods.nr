// v0.4.124: extended String surface — 10 new method dispatches
// added on top of v0.4.114's `new/push/len/...` baseline:
//   is_empty, to_uppercase, to_lowercase, trim, trim_start,
//   trim_end, find, substring, char_at, as_str.
// All routed through new __nucleor_string_* runtime helpers
// in nucleor_llvm_rt.c with the standard 5-table mirror.

fn main() -> i32 {
    let mut s: String = String::new();
    s.push(72); s.push(105);
    let u: String = s.to_uppercase();
    u.print();
    let l: String = u.to_lowercase();
    l.print();
    let mut t: String = String::new();
    t.push(32); t.push(72); t.push(105); t.push(32);
    let trimmed: String = t.trim();
    trimmed.print();
    print_int(s.is_empty() as i64);
    print_int(s.find("i"));
    let sub: String = s.substring(0, 1);
    sub.print();
    print_int(s.char_at(0));
    0
}
