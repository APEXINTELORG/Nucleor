// Phase 2c: Pass &mut T to function that mutates

struct Vec2 { x: i32, y: i32 }

fn scale(v: &mut Vec2, factor: i32) {
    v.x = v.x * factor;
    v.y = v.y * factor;
}

fn swap_xy(v: &mut Vec2) {
    let tmp: i32 = v.x;
    v.x = v.y;
    v.y = tmp;
}

fn main() -> i32 {
    let mut p: Vec2 = Vec2 { x: 3, y: 4 };
    print_int(p.x);       // 3
    print_int(p.y);       // 4

    scale(&mut p, 10);
    print_int(p.x);       // 30
    print_int(p.y);       // 40

    swap_xy(&mut p);
    print_int(p.x);       // 40
    print_int(p.y);       // 30

    0
}
