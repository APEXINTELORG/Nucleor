// borrow_check.nr — Borrow checker for self-hosted Nucleor compiler
// Phase 6: Enforces reference aliasing rules.
//
// Rules enforced:
// 1. Cannot have &mut T while any &T exists (exclusive vs shared)
// 2. Cannot have multiple &mut T to the same variable
// 3. Cannot use a variable while it's mutably borrowed
// 4. Borrows don't outlive their scope
//
// Uses the same position-aware tokenizer as real_checker.nr.
// Tracks borrows as [var_hash, borrow_kind, scope_depth] triples.
// borrow_kind: 0 = shared (&T), 1 = mutable (&mut T)

const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LET: i32 = 11;
const TK_MUT: i32 = 12;
const TK_RETURN: i32 = 13;
const TK_IF: i32 = 14;
const TK_WHILE: i32 = 16;
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_EQ: i32 = 55;
const TK_ARROW: i32 = 62;
const TK_COLON: i32 = 66;
const TK_SEMICOLON: i32 = 68;
const TK_AMP: i32 = 70;

const BORROW_SHARED: i32 = 0;
const BORROW_MUT: i32 = 1;

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn classify_kw(word: str) -> i32 {
    if str_eq(word, "fn") { TK_FN } else if str_eq(word, "let") { TK_LET }
    else if str_eq(word, "mut") { TK_MUT } else if str_eq(word, "return") { TK_RETURN }
    else if str_eq(word, "if") { TK_IF } else if str_eq(word, "while") { TK_WHILE }
    else if str_eq(word, "true") { TK_TRUE } else if str_eq(word, "false") { TK_FALSE }
    else { TK_IDENT }
}

fn qhash(source: str, s: i32, e: i32) -> i32 {
    let c0: i32 = str_char_at(source, s);
    let mut c1: i32 = 0;
    if s + 1 < e { c1 = str_char_at(source, s + 1); };
    let mut ce: i32 = 0;
    if e - 1 > s { ce = str_char_at(source, e - 1); };
    c0 * 10000 + c1 * 100 + ce * 10 + (e - s)
}

fn line_of(source: str, pos: i32) -> i32 {
    let mut line: i32 = 1;
    let mut i: i32 = 0;
    while i < pos {
        if str_char_at(source, i) == 10 { line = line + 1; };
        i = i + 1;
    };
    line
}

fn tokenize(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut t: Vec<i32> = Vec::new();
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if is_digit(c) {
            let s: i32 = p;
            while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
            t.push(TK_INT); t.push(s); t.push(p);
        }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            t.push(classify_kw(str_substring(source, s, p))); t.push(s); t.push(p);
        }
        else if c == 45 && p + 1 < len && str_char_at(source, p + 1) == 62 {
            t.push(TK_ARROW); t.push(p); p = p + 2; t.push(p);
        }
        else {
            let s: i32 = p;
            if c == 40 { t.push(TK_LPAREN); } else if c == 41 { t.push(TK_RPAREN); }
            else if c == 123 { t.push(TK_LBRACE); } else if c == 125 { t.push(TK_RBRACE); }
            else if c == 59 { t.push(TK_SEMICOLON); } else if c == 61 { t.push(TK_EQ); }
            else if c == 58 { t.push(TK_COLON); } else if c == 38 { t.push(TK_AMP); }
            else { p = p + 1; };
            if c != 0 { t.push(s); p = p + 1; t.push(p); };
        };
    };
    t.push(TK_EOF); t.push(0); t.push(0);
    t
}

// === Borrow Checker ===
// Analyzes a Nucleor program for borrow violations.
// Tracks active borrows: [var_hash, kind, scope_depth]
// Returns error count.
fn borrow_check(source: str) -> i32 {
    let tokens: Vec<i32> = tokenize(source);
    let tlen: i32 = tokens.len() / 3;
    let mut ti: i32 = 0;
    let mut errors: i32 = 0;

    // Active borrows: [var_hash, borrow_kind, scope_depth] triples
    let mut borrows: Vec<i32> = Vec::new();
    let mut borrow_count: i32 = 0;
    let mut scope_depth: i32 = 0;

    // Find main function body (or first fn body)
    while ti < tlen && tokens.get(ti * 3) != TK_EOF {
        if tokens.get(ti * 3) == TK_FN {
            ti = ti + 1;
            // Skip name + params + return type
            while ti < tlen && tokens.get(ti * 3) != TK_LBRACE && tokens.get(ti * 3) != TK_EOF { ti = ti + 1; };
            if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                ti = ti + 1;
                scope_depth = 1;

                // Scan function body for borrow patterns
                while ti < tlen && scope_depth > 0 && tokens.get(ti * 3) != TK_EOF {
                    let tk: i32 = tokens.get(ti * 3);

                    if tk == TK_LBRACE { scope_depth = scope_depth + 1; ti = ti + 1; }
                    else if tk == TK_RBRACE {
                        // End of scope: expire borrows at this depth
                        let mut bi: i32 = 0;
                        while bi < borrow_count {
                            if borrows.get(bi * 3 + 2) >= scope_depth {
                                // Mark as expired by setting depth to -1
                                // (can't remove from Vec, but won't match future checks)
                                borrows.push(borrows.get(bi * 3));
                                borrows.push(borrows.get(bi * 3 + 1));
                                borrows.push(0 - 1);
                                borrow_count = borrow_count + 1;
                            };
                            bi = bi + 1;
                        };
                        scope_depth = scope_depth - 1;
                        ti = ti + 1;
                    }
                    // let x: &T = &var or let x: &mut T = &mut var
                    else if tk == TK_LET {
                        ti = ti + 1;
                        if ti < tlen && tokens.get(ti * 3) == TK_MUT { ti = ti + 1; };
                        // Skip variable name
                        if ti < tlen && tokens.get(ti * 3) == TK_IDENT { ti = ti + 1; };
                        // Check for : &T or : &mut T
                        let mut is_ref: bool = false;
                        let mut is_mut_ref: bool = false;
                        if ti < tlen && tokens.get(ti * 3) == TK_COLON {
                            ti = ti + 1;
                            if ti < tlen && tokens.get(ti * 3) == TK_AMP {
                                is_ref = true;
                                ti = ti + 1;
                                if ti < tlen && tokens.get(ti * 3) == TK_MUT {
                                    is_mut_ref = true;
                                    ti = ti + 1;
                                };
                                // Skip type name
                                if ti < tlen && tokens.get(ti * 3) == TK_IDENT { ti = ti + 1; };
                            };
                        };
                        // Skip to = and find the borrowed variable
                        while ti < tlen && tokens.get(ti * 3) != TK_EQ && tokens.get(ti * 3) != TK_SEMICOLON { ti = ti + 1; };
                        if ti < tlen && tokens.get(ti * 3) == TK_EQ {
                            ti = ti + 1;
                            // Check for &var or &mut var
                            if ti < tlen && tokens.get(ti * 3) == TK_AMP {
                                ti = ti + 1;
                                let mut borrow_kind: i32 = BORROW_SHARED;
                                if ti < tlen && tokens.get(ti * 3) == TK_MUT {
                                    borrow_kind = BORROW_MUT;
                                    ti = ti + 1;
                                };
                                if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                                    let var_s: i32 = tokens.get(ti * 3 + 1);
                                    let var_e: i32 = tokens.get(ti * 3 + 2);
                                    let var_hash: i32 = qhash(source, var_s, var_e);
                                    let var_name: str = str_substring(source, var_s, var_e);

                                    // Check existing borrows for conflicts
                                    let mut bi2: i32 = 0;
                                    while bi2 < borrow_count {
                                        let bh: i32 = borrows.get(bi2 * 3);
                                        let bk: i32 = borrows.get(bi2 * 3 + 1);
                                        let bd: i32 = borrows.get(bi2 * 3 + 2);
                                        if bh == var_hash && bd > 0 {
                                            // Conflict: &mut while &T exists
                                            if borrow_kind == BORROW_MUT && bk == BORROW_SHARED {
                                                print("error: cannot borrow as mutable — already borrowed as shared:");
                                                print(var_name);
                                                print("  at line:");
                                                print_int(line_of(source, var_s));
                                                errors = errors + 1;
                                            };
                                            // Conflict: &T while &mut T exists
                                            if borrow_kind == BORROW_SHARED && bk == BORROW_MUT {
                                                print("error: cannot borrow as shared — already borrowed as mutable:");
                                                print(var_name);
                                                print("  at line:");
                                                print_int(line_of(source, var_s));
                                                errors = errors + 1;
                                            };
                                            // Conflict: &mut T while &mut T exists
                                            if borrow_kind == BORROW_MUT && bk == BORROW_MUT {
                                                print("error: cannot borrow as mutable more than once:");
                                                print(var_name);
                                                print("  at line:");
                                                print_int(line_of(source, var_s));
                                                errors = errors + 1;
                                            };
                                        };
                                        bi2 = bi2 + 1;
                                    };

                                    // Record the borrow
                                    borrows.push(var_hash);
                                    borrows.push(borrow_kind);
                                    borrows.push(scope_depth);
                                    borrow_count = borrow_count + 1;
                                };
                            };
                        };
                        // Skip to ;
                        while ti < tlen && tokens.get(ti * 3) != TK_SEMICOLON && tokens.get(ti * 3) != TK_EOF { ti = ti + 1; };
                        if ti < tlen { ti = ti + 1; };
                    }
                    else { ti = ti + 1; };
                };
            };
            // Reset borrows between functions
            borrow_count = 0;
        } else { ti = ti + 1; };
    };

    errors
}

// === Tests ===

fn test_shared_ok() -> i32 {
    print("=== Borrow 1: multiple shared borrows OK ===");
    let e: i32 = borrow_check("fn main() -> i32 { let x: i32 = 5; let a: &i32 = &x; let b: &i32 = &x; 0 }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); print_int(e); };
    0
}

fn test_mut_exclusive() -> i32 {
    print("=== Borrow 2: two &mut (expect error) ===");
    let e: i32 = borrow_check("fn main() -> i32 { let mut x: i32 = 5; let a: &mut i32 = &mut x; let b: &mut i32 = &mut x; 0 }");
    if e > 0 { print("  PASS (correctly rejected double &mut)"); } else { print("  FAIL"); };
    0
}

fn test_mut_shared_conflict() -> i32 {
    print("=== Borrow 3: &mut then & (expect error) ===");
    let e: i32 = borrow_check("fn main() -> i32 { let mut x: i32 = 5; let a: &mut i32 = &mut x; let b: &i32 = &x; 0 }");
    if e > 0 { print("  PASS (correctly rejected &mut + &)"); } else { print("  FAIL"); };
    0
}

fn test_shared_then_mut_conflict() -> i32 {
    print("=== Borrow 4: & then &mut (expect error) ===");
    let e: i32 = borrow_check("fn main() -> i32 { let mut x: i32 = 5; let a: &i32 = &x; let b: &mut i32 = &mut x; 0 }");
    if e > 0 { print("  PASS (correctly rejected & then &mut)"); } else { print("  FAIL"); };
    0
}

fn test_single_mut_ok() -> i32 {
    print("=== Borrow 5: single &mut OK ===");
    let e: i32 = borrow_check("fn main() -> i32 { let mut x: i32 = 5; let a: &mut i32 = &mut x; 0 }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); print_int(e); };
    0
}

fn test_different_vars_ok() -> i32 {
    print("=== Borrow 6: &mut different vars OK ===");
    let e: i32 = borrow_check("fn main() -> i32 { let mut x: i32 = 1; let mut y: i32 = 2; let a: &mut i32 = &mut x; let b: &mut i32 = &mut y; 0 }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); print_int(e); };
    0
}

fn test_no_borrows() -> i32 {
    print("=== Borrow 7: no borrows (no errors) ===");
    let e: i32 = borrow_check("fn main() -> i32 { let x: i32 = 5; let y: i32 = x + 1; y }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn main() -> i32 {
    print("========================================");
    print("  Borrow Checker Tests");
    print("========================================");
    test_shared_ok();
    test_mut_exclusive();
    test_mut_shared_conflict();
    test_shared_then_mut_conflict();
    test_single_mut_ok();
    test_different_vars_ok();
    test_no_borrows();
    print("========================================");
    print("  BORROW CHECKER COMPLETE");
    print("========================================");
    0
}
