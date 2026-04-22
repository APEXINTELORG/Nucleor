// layout.nr — @layout(soa) does not change observable struct semantics
@layout(soa)
struct Particle {
    x: i64,
    y: i64,
    z: i64,
    mass: i64
}

fn make(x: i64, y: i64, z: i64, m: i64) -> Particle {
    let p: Particle = Particle { x: x, y: y, z: z, mass: m };
    return p;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let p: Particle = make(1, 2, 3, 100);
    if p.x != 1 { print("FAIL layout: x"); fail = fail + 1; };
    if p.y != 2 { print("FAIL layout: y"); fail = fail + 1; };
    if p.z != 3 { print("FAIL layout: z"); fail = fail + 1; };
    if p.mass != 100 { print("FAIL layout: mass"); fail = fail + 1; };
    if fail == 0 { print("OK layout"); return 0; };
    return 1;
}
