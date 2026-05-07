// R05 Queue B v0844 positive smoke: the deeper same-file helper walk
// must not reject a clean un-rowed helper ladder.

fn p5() -> i32 { 1 }
fn p4() -> i32 { p5() + 1 }
fn p3() -> i32 { p4() + 1 }
fn p2() -> i32 { p3() + 1 }
fn p1() -> i32 { p2() + 1 }

fn main() -> i32 {
    restricts [net] {
        let r: i32 = p1();
        if r == 5 { 0 } else { 1 }
    }
}
