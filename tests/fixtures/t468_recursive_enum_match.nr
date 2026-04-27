// t468_recursive_enum_match.nr -- v0.3.231 regression pin for
// RFC-NRT-004 (Nucleor_Translate).
//
// Reported against v0.3.223: declaring `enum Tree { Leaf(i64),
// Node(Tree) }` with `match Tree::Node(inner) => match inner { ... }`
// emitted `%r.X = ptrtoint ptr @inner to i64` -- the bound payload
// was lowered as an `@global` symbol reference instead of a `%ssa`
// local, so clang failed at link with "use of undefined value
// '@inner'".
//
// Status by the time this fixture lands (v0.3.230): the bug is no
// longer reproducible. Likely closed by the v0.3.184/186
// match_bind_payloads_typed work for typed enum payloads. This
// fixture pins the working behavior so it can't silently regress.
//
// Acceptance criterion from the RFC: this fixture returns 0.

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
            // Using `inner` (a bound payload of the Node variant whose
            // payload type is the enum itself) is the trigger that used
            // to emit @inner instead of %inner. Now lowers correctly.
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
