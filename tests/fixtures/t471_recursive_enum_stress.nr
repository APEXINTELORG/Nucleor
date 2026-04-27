// t471_recursive_enum_stress.nr -- v0.3.235 stress permutations
// for RFC-NRT-004 §B+§C (Nucleor_Translate).
//
// Goes beyond the minimal RFC repros to lock down the working
// behavior across all the shapes that worried the filer:
//   - 6 variants in one enum
//   - mix of unit / single-payload / 2-payload / 3-payload /
//     3-payload-with-recursion / 4-payload-with-recursion
//   - all multi-payload bindings USED (a+b, x+y+z, recursive l)
//   - recursive payload bindings used as match scrutinees in
//     inner matches (the §A-class trigger)
//
// Acceptance: this fixture returns 0.

pub enum Node {
    Empty,
    Leaf(i64),
    Pair(i64, i64),
    Triple(i64, i64, i64),
    Branch(str, Node, Node),
    Tag(str, Node, Node, Node),
}

fn dispatch(n: Node) -> i64 {
    match n {
        Node::Empty => return 10,
        Node::Leaf(v) => return 20 + v,
        Node::Pair(a, b) => return 30 + a + b,
        Node::Triple(x, y, z) => return 40 + x + y + z,
        Node::Branch(name, l, r) => return 50,
        Node::Tag(t, a, b, c) => return 60,
    };
}

fn use_pair(n: Node) -> i64 {
    match n {
        Node::Pair(a, b) => {
            if a != 7 { return 1; };
            if b != 11 { return 1; };
            return 0;
        },
        _ => return 1,
    };
}

fn use_triple(n: Node) -> i64 {
    match n {
        Node::Triple(x, y, z) => {
            if x != 1 { return 1; };
            if y != 2 { return 1; };
            if z != 3 { return 1; };
            return 0;
        },
        _ => return 1,
    };
}

fn use_branch_recurse(n: Node) -> i64 {
    match n {
        Node::Branch(name, l, r) => {
            match l {
                Node::Leaf(v) => {
                    if v != 99 { return 1; };
                    return 0;
                },
                _ => return 1,
            };
        },
        _ => return 1,
    };
}

fn main() -> i64 {
    let e: Node = Node::Empty;
    let lf: Node = Node::Leaf(5);
    let pr: Node = Node::Pair(7, 11);
    let tr: Node = Node::Triple(1, 2, 3);
    let br: Node = Node::Branch("x", Node::Leaf(99), Node::Empty);
    let tg: Node = Node::Tag("y", Node::Empty, Node::Empty, Node::Empty);

    if dispatch(e)  != 10 { return 1; };
    if dispatch(lf) != 25 { return 1; };
    if dispatch(pr) != 48 { return 1; };
    if dispatch(tr) != 46 { return 1; };
    if dispatch(br) != 50 { return 1; };
    if dispatch(tg) != 60 { return 1; };

    if use_pair(pr) != 0 { return 1; };
    if use_triple(tr) != 0 { return 1; };
    if use_branch_recurse(br) != 0 { return 1; };

    return 0;
}
