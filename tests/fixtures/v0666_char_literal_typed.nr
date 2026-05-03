// v0.6.66 (probe finding 2026-05-01-rust-syntax-translation-fidelity-audit
// char-literal row): canonical Rust `let c: char = 'a';` accepted at type-
// check. Pre-fix failed TYP-008 because char literals lex as i32 codepoints
// while binding type was "char".
fn main() -> i32 {
    let c: char = 'a';
    print_int(c as i32);
    let n: char = '\n';
    print_int(n as i32);
    let z: char = '\0';
    print_int(z as i32);
    return 0;
}
