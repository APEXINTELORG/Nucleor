// Error test: effect inference through 4-level deep call chain
// leaf requires [net.connect], each wrapper calls the previous
// level4 has NO declared effects but the compiler infers net.connect
fn leaf() -> i32 requires [net.connect] { 1 }
fn level2() -> i32 { leaf() + 1 }
fn level3() -> i32 { level2() + 1 }
fn level4() -> i32 { level3() + 1 }

fn main() -> i32 {
    restricts [net] {
        level4()
    }
}
