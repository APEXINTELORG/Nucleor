// Hazard sweep #5 — harder patterns.

pub struct Box { pub inner: str }
pub enum Tree { Leaf(i64), Node(Tree, Tree) }

// HAZARD 26: Method call on bound payload (struct method form)
fn box_inner_str(b: Box) -> str { return b.inner; }
fn hz26_method_on_payload() -> i64 {
    let opt: Option<Box> = Some(Box { inner: "hello" });
    match opt {
        None => return 1,
        Some(b) => {
            let s: str = box_inner_str(b);
            if str_eq(s, "hello") != 1 { return 1; };
        },
    };
    return 0;
}

// HAZARD 27: Recursive enum traversal with format
fn tree_depth(t: Tree) -> i64 {
    match t {
        Tree::Leaf(v) => return 1,
        Tree::Node(l, r) => {
            let dl: i64 = tree_depth(l);
            let dr: i64 = tree_depth(r);
            if dl > dr { return dl + 1; };
            return dr + 1;
        },
    };
}
fn hz27_recursive_enum() -> i64 {
    let t: Tree = Tree::Node(Tree::Leaf(1), Tree::Node(Tree::Leaf(2), Tree::Leaf(3)));
    let d: i64 = tree_depth(t);
    let s: str = format!("depth={}", d);
    if str_eq(s, "depth=3") != 1 { return 1; };
    return 0;
}

// HAZARD 28: Comparison chain in if
fn hz28_cmp_chain() -> i64 {
    let x: i64 = 5;
    if x > 0 && x < 10 {
        return 0;
    };
    return 1;
}

// HAZARD 29: Negative literal directly in format (no parentheses)
fn hz29_neg_literal() -> i64 {
    let s: str = format!("n={}", 0 - 7);
    if str_eq(s, "n=-7") != 1 { return 1; };
    return 0;
}

// HAZARD 30: Empty string format
fn hz30_empty_str() -> i64 {
    let s: str = format!("{}", "");
    if str_eq(s, "") != 1 { return 1; };
    if str_len(s) != 0 { return 1; };
    return 0;
}

fn main() -> i64 {
    if hz26_method_on_payload() != 0 { println!("FAIL hz26"); return 26; };
    if hz27_recursive_enum() != 0 { println!("FAIL hz27"); return 27; };
    if hz28_cmp_chain() != 0 { println!("FAIL hz28"); return 28; };
    if hz29_neg_literal() != 0 { println!("FAIL hz29"); return 29; };
    if hz30_empty_str() != 0 { println!("FAIL hz30"); return 30; };
    println!("all clean");
    return 0;
}
