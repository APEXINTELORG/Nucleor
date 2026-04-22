fn main() -> i32 {
    let mut i = 1;
    while i <= 30 {
        if i % 15 == 0 {
            print_int(0);
        } else {
            if i % 3 == 0 {
                print_int(3);
            } else {
                if i % 5 == 0 {
                    print_int(5);
                } else {
                    print_int(i);
                }
            }
        }
        i = i + 1;
    }
    0
}
