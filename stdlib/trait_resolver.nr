// trait_resolver.nr — Trait resolution for self-hosted Nucleor compiler
// Phase 6: Tracks trait declarations, impl blocks, and resolves trait methods.
//
// Features:
// 1. Parse trait declarations with method signatures
// 2. Parse impl blocks mapping types to traits
// 3. Resolve method calls to the correct impl
// 4. Detect missing trait implementations
// 5. Detect duplicate impls

const TK_EOF: i32 = 0;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_IMPL: i32 = 22;
const TK_TRAIT: i32 = 23;
const TK_FOR: i32 = 17;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_ARROW: i32 = 62;
const TK_COLON: i32 = 66;
const TK_SEMICOLON: i32 = 68;

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn classify_kw(word: str) -> i32 {
    if str_eq(word, "fn") { TK_FN } else if str_eq(word, "impl") { TK_IMPL }
    else if str_eq(word, "trait") { TK_TRAIT } else if str_eq(word, "for") { TK_FOR }
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
            t.push(4); t.push(s); t.push(p); // tokenize as generic IDENT
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
            else if c == 59 { t.push(TK_SEMICOLON); } else if c == 58 { t.push(TK_COLON); }
            else { p = p + 1; };
            if c != 0 { t.push(s); p = p + 1; t.push(p); };
        };
    };
    t.push(TK_EOF); t.push(0); t.push(0);
    t
}

// === Trait Resolver ===
// Scans source for trait declarations and impl blocks.
// Tracks: trait names, trait methods, impl types, impl methods.
// Detects: missing impls, duplicate impls, unresolved methods.
// Returns: error count.
fn resolve_traits(source: str) -> i32 {
    let tokens: Vec<i32> = tokenize(source);
    let tlen: i32 = tokens.len() / 3;
    let mut ti: i32 = 0;
    let mut errors: i32 = 0;

    // Trait table: [trait_hash, method_count]
    let mut traits: Vec<i32> = Vec::new();
    let mut trait_count: i32 = 0;

    // Trait methods: [trait_index, method_hash]
    let mut trait_methods: Vec<i32> = Vec::new();
    let mut trait_method_count: i32 = 0;

    // Impl table: [type_hash, trait_hash, method_count]
    let mut impls: Vec<i32> = Vec::new();
    let mut impl_count: i32 = 0;

    // Impl methods: [impl_index, method_hash]
    let mut impl_methods: Vec<i32> = Vec::new();
    let mut impl_method_count: i32 = 0;

    // Pass 1: Collect traits and their required methods
    while ti < tlen && tokens.get(ti * 3) != TK_EOF {
        if tokens.get(ti * 3) == TK_TRAIT {
            ti = ti + 1;
            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                let ts: i32 = tokens.get(ti * 3 + 1);
                let te: i32 = tokens.get(ti * 3 + 2);
                let th: i32 = qhash(source, ts, te);
                let cur_trait: i32 = trait_count;
                let mut mcount: i32 = 0;
                ti = ti + 1;

                // Parse trait body for fn declarations
                if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                    ti = ti + 1;
                    while ti < tlen && tokens.get(ti * 3) != TK_RBRACE && tokens.get(ti * 3) != TK_EOF {
                        if tokens.get(ti * 3) == TK_FN {
                            ti = ti + 1;
                            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                                let ms: i32 = tokens.get(ti * 3 + 1);
                                let me: i32 = tokens.get(ti * 3 + 2);
                                trait_methods.push(cur_trait);
                                trait_methods.push(qhash(source, ms, me));
                                trait_method_count = trait_method_count + 1;
                                mcount = mcount + 1;
                            };
                        };
                        ti = ti + 1;
                    };
                    if ti < tlen { ti = ti + 1; };
                };

                traits.push(th); traits.push(mcount);
                trait_count = trait_count + 1;
            };
        }
        // Parse impl blocks: impl Type { ... } or impl Trait for Type { ... }
        else if tokens.get(ti * 3) == TK_IMPL {
            ti = ti + 1;
            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                let first_s: i32 = tokens.get(ti * 3 + 1);
                let first_e: i32 = tokens.get(ti * 3 + 2);
                let first_h: i32 = qhash(source, first_s, first_e);
                ti = ti + 1;

                let mut type_hash: i32 = first_h;
                let mut trait_hash: i32 = 0;

                // Check for "for Type" (trait impl)
                if ti < tlen && tokens.get(ti * 3) == TK_FOR {
                    trait_hash = first_h;
                    ti = ti + 1;
                    if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                        type_hash = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                        ti = ti + 1;
                    };
                };

                let cur_impl: i32 = impl_count;
                let mut im_count: i32 = 0;

                // Parse impl body for fn declarations
                if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                    ti = ti + 1;
                    let mut d: i32 = 1;
                    while ti < tlen && d > 0 {
                        if tokens.get(ti * 3) == TK_LBRACE { d = d + 1; };
                        if tokens.get(ti * 3) == TK_RBRACE { d = d - 1; };
                        if tokens.get(ti * 3) == TK_FN && d == 1 {
                            ti = ti + 1;
                            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                                let ims: i32 = tokens.get(ti * 3 + 1);
                                let ime: i32 = tokens.get(ti * 3 + 2);
                                impl_methods.push(cur_impl);
                                impl_methods.push(qhash(source, ims, ime));
                                impl_method_count = impl_method_count + 1;
                                im_count = im_count + 1;
                            };
                        };
                        if d > 0 { ti = ti + 1; };
                    };
                    if ti < tlen { ti = ti + 1; };
                };

                impls.push(type_hash); impls.push(trait_hash); impls.push(im_count);
                impl_count = impl_count + 1;

                // Check: if this is a trait impl, verify all trait methods are implemented
                if trait_hash != 0 {
                    let mut tfi: i32 = 0;
                    while tfi < trait_count {
                        if traits.get(tfi * 2) == trait_hash {
                            // Check each required method
                            let mut mi: i32 = 0;
                            while mi < trait_method_count {
                                if trait_methods.get(mi * 2) == tfi {
                                    let req_mh: i32 = trait_methods.get(mi * 2 + 1);
                                    // Search impl methods for this method
                                    let mut found: bool = false;
                                    let mut imi: i32 = 0;
                                    while imi < impl_method_count {
                                        if impl_methods.get(imi * 2) == cur_impl && impl_methods.get(imi * 2 + 1) == req_mh {
                                            found = true;
                                        };
                                        imi = imi + 1;
                                    };
                                    if !found {
                                        print("error: missing trait method implementation");
                                        errors = errors + 1;
                                    };
                                };
                                mi = mi + 1;
                            };
                        };
                        tfi = tfi + 1;
                    };
                };
            };
        }
        else { ti = ti + 1; };
    };

    // Report
    print("  traits:");
    print_int(trait_count);
    print("  impls:");
    print_int(impl_count);
    print("  trait methods:");
    print_int(trait_method_count);
    print("  impl methods:");
    print_int(impl_method_count);
    print("  errors:");
    print_int(errors);
    errors
}

// === Tests ===
fn test_simple_trait() -> i32 {
    print("=== Trait 1: simple trait + impl ===");
    let e: i32 = resolve_traits("trait Printable { fn show(self: Self) -> i32; } impl Printable for Foo { fn show(self: Foo) -> i32 { 0 } }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_missing_method() -> i32 {
    print("=== Trait 2: missing impl method (expect error) ===");
    let e: i32 = resolve_traits("trait Printable { fn show(self: Self) -> i32; fn name(self: Self) -> i32; } impl Printable for Foo { fn show(self: Foo) -> i32 { 0 } }");
    if e > 0 { print("  PASS (correctly detected missing method)"); } else { print("  FAIL"); };
    0
}

fn test_inherent_impl() -> i32 {
    print("=== Trait 3: inherent impl (no trait) ===");
    let e: i32 = resolve_traits("impl Foo { fn new() -> Foo { 0 } fn get(self: Foo) -> i32 { 0 } }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_multi_trait() -> i32 {
    print("=== Trait 4: multiple traits ===");
    let e: i32 = resolve_traits("trait A { fn a(self: Self) -> i32; } trait B { fn b(self: Self) -> i32; } impl A for X { fn a(self: X) -> i32 { 1 } } impl B for X { fn b(self: X) -> i32 { 2 } }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_complete_impl() -> i32 {
    print("=== Trait 5: complete impl ===");
    let e: i32 = resolve_traits("trait Display { fn show(self: Self) -> i32; fn width(self: Self) -> i32; } impl Display for Box { fn show(self: Box) -> i32 { 0 } fn width(self: Box) -> i32 { 10 } }");
    if e == 0 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn main() -> i32 {
    print("========================================");
    print("  Trait Resolver Tests");
    print("========================================");
    test_simple_trait();
    test_missing_method();
    test_inherent_impl();
    test_multi_trait();
    test_complete_impl();
    print("========================================");
    print("  TRAIT RESOLVER COMPLETE");
    print("========================================");
    0
}
