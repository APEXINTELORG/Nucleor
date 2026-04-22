// Error test: restricts [io] blocks builtin io.write effects

fn main() -> i32 {
    restricts [io] {
        print_int(1);
        0
    }
}
