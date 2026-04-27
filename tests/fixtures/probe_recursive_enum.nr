// Probe: RFC-NRT-004 -- recursive enum payload extraction emits @global
// instead of %ssa local for the inner pattern match.
pub enum Tree {
    Leaf(i64),
    Node(Tree),
}

fn test_recursive_enum_use() -> i64 {
    let leaf: Tree = Tree::Leaf(42);
    let node: Tree = Tree::Node(leaf);
    match node {
        Tree::Leaf(v) => return 1,
        Tree::Node(inner) => {
            match inner {
                Tree::Leaf(v) => {
                    if v != 42 { return 1; };
                    return 0;
                },
                Tree::Node(_) => return 1,
            };
        },
    };
}

fn main() -> i64 {
    return test_recursive_enum_use();
}
