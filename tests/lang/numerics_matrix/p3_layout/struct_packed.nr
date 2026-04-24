// p3_layout/struct_packed.nr — Phase 3: #[repr(packed)] struct

#[repr(packed)]
struct Header {
    tag: u8,
    val: i32,
}

fn main() -> i32 {
    let h = Header { tag: 1, val: 100 };
    if h.tag != 1 || h.val != 100 {
        print("FAIL: packed struct round-trip\n");
        return 1;
    };
    print("OK struct_packed\n");
    return 0;
}
