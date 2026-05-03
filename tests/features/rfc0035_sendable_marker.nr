// RFC-0035 first-pass positive: explicit Sendable marker impl permits
// a user type to cross an async_spawn boundary.

trait Sendable {}

struct Packet {
    v: i64,
}

impl Sendable for Packet {}

fn packet_worker(p: Packet) -> i64 {
    return p.v + 1;
}

fn main() -> i32 {
    let p: Packet = Packet { v: 41 };
    let h: i64 = async_spawn(packet_worker, p);
    let r: i64 = async_await(h);
    if r != 42 { print("FAIL rfc0035_sendable_marker\n"); return 1; };
    print("OK rfc0035_sendable_marker\n");
    return 0;
}
