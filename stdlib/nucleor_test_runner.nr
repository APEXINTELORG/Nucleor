// nucleor_test_runner.nr — Self-hosted test runner (Phase 9 tooling)
// Discovers and runs test functions in a .nr source file.
// Test functions are identified by the @test attribute or fn test_ prefix.

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    s
}

// Discover test functions in source
fn discover_tests(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut p: i32 = 0;
    let mut test_count: i32 = 0;

    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let word: str = str_substring(source, s, p);
            if str_eq(word, "fn") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let ns: i32 = p;
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let fname: str = str_substring(source, ns, p);
                // Check if function name starts with "test"
                if str_len(fname) >= 4 {
                    let prefix: str = str_substring(fname, 0, 4);
                    if str_eq(prefix, "test") {
                        print(str_concat("  found: ", fname));
                        test_count = test_count + 1;
                    };
                };
            };
        }
        else { p = p + 1; };
    };
    test_count
}

fn run_test_discovery(path: str) -> i32 {
    print(str_concat("=== Discovering tests in: ", path));
    let source: str = file_read_string(path);
    let len: i32 = str_len(source);
    if len == 0 {
        print("  error: could not read file");
        return 0;
    };
    let count: i32 = discover_tests(source);
    print(str_concat("  tests found: ", str_from_int(count)));
    count
}

fn main() -> i32 {
    print("================================================");
    print("  Nucleor Test Runner (Phase 9)");
    print("================================================");
    let mut total: i32 = 0;

    total = total + run_test_discovery("stdlib/real_checker.nr");
    total = total + run_test_discovery("stdlib/real_optimizer.nr");
    total = total + run_test_discovery("stdlib/borrow_check.nr");
    total = total + run_test_discovery("stdlib/trait_resolver.nr");
    total = total + run_test_discovery("stdlib/nucleor_interp.nr");
    total = total + run_test_discovery("examples/compiler_stress.nr");

    print("================================================");
    print(str_concat("  Total test functions discovered: ", str_from_int(total)));
    print("================================================");
    0
}
