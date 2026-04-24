// p11_format/print_u8.nr — Phase 11: print_u8 prints unsigned

fn main() -> i32 {
    let a: u8 = 200;
    print_u8(a);   // should print "200"
    print("\n");
    print("OK print_u8\n");
    return 0;
}
