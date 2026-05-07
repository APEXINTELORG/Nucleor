// EXPECT: error[EFF-003]
// R05 Queue B v0844: the same-file restricts transitive budget now
// reaches beyond the prior depth=3 helper ladder. This five-hop
// un-rowed chain reaches a rowed `net.connect` leaf, so `restricts
// [net]` must reject it with EFF-003.

fn leaf() -> i32 requires [net.connect] { 1 }
fn l5() -> i32 { leaf() + 1 }
fn l4() -> i32 { l5() + 1 }
fn l3() -> i32 { l4() + 1 }
fn l2() -> i32 { l3() + 1 }
fn l1() -> i32 { l2() + 1 }

fn main() -> i32 {
    restricts [net] {
        l1()
    }
}
