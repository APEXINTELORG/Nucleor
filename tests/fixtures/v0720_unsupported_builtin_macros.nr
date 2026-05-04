// v0.7.20 negative fixture — `file!()` halts cleanly (was wrong-class
// NR020 expected `)`, got `;`). Sister halts: line!/column!/module_path!/
// stringify!/concat!/env!/option_env!/include_str!/include_bytes!.
fn main() -> i64 {
    let f: str = file!();
    print(f);
    return 0;
}
