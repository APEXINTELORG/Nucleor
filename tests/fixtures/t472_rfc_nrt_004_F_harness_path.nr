// Probe RFC-NRT-004 §F: harness-path parser fix for §A/§B/§C.
// Uses #[test] which routes through nucleor_tools.exe (the
// harness path that was previously broken even though `nuc build`
// was already correct).

pub enum E {
    Pair(i64, i64),
    Other,
}

#[test]
fn pair_use() {
    match E::Pair(1, 2) {
        E::Other => assert!(false, "wrong arm"),
        E::Pair(a, b) => {
            assert!(a == 1, "a should be 1");
            assert!(b == 2, "b should be 2");
        },
    };
}

pub enum Tree {
    Leaf(i64),
    Node(Tree),
}

#[test]
fn recursive_use() {
    let leaf: Tree = Tree::Leaf(42);
    let node: Tree = Tree::Node(leaf);
    match node {
        Tree::Leaf(v) => assert!(false, "wrong arm"),
        Tree::Node(inner) => {
            match inner {
                Tree::Leaf(v) => assert!(v == 42, "leaf should be 42"),
                Tree::Node(_) => assert!(false, "wrong inner arm"),
            };
        },
    };
}

pub enum M {
    Single,
    Call(str, M),
    BinOp(str, M, M),
}

#[test]
fn multi_multi_dispatch() {
    let single: M = M::Single;
    let call: M   = M::Call("foo", M::Single);
    let binop: M  = M::BinOp("+", M::Single, M::Single);

    let r1: i64 = match single {
        M::Single => 100,
        M::Call(name, arg) => 200,
        M::BinOp(op, lhs, rhs) => 300,
    };
    let r2: i64 = match call {
        M::Single => 100,
        M::Call(name, arg) => 200,
        M::BinOp(op, lhs, rhs) => 300,
    };
    let r3: i64 = match binop {
        M::Single => 100,
        M::Call(name, arg) => 200,
        M::BinOp(op, lhs, rhs) => 300,
    };
    assert!(r1 == 100, "single dispatch");
    assert!(r2 == 200, "call dispatch");
    assert!(r3 == 300, "binop dispatch");
}
