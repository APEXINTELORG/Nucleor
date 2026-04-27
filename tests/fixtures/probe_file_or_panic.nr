// Probe: file_read_string_or_panic on missing file should PANIC
fn main() -> i64 {
    let s: str = file_read_string_or_panic("nonexistent_path_xyz123.txt");
    println!("{}", s);
    return 0;
}
