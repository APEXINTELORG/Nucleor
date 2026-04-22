// Phase 6a: Logical AND (&&) and OR (||) operators

fn main() -> i32 {
    let a = true;
    let b = false;
    let c = true;

    // AND: true && false = 0
    if a && b { print_int(1); } else { print_int(0); }

    // AND: true && true = 1
    if a && c { print_int(1); } else { print_int(0); }

    // OR: true || false = 1
    if a || b { print_int(1); } else { print_int(0); }

    // OR: false || false = 0
    if b || b { print_int(1); } else { print_int(0); }

    // Combined: (true && true) || false = 1
    if (a && c) || b { print_int(1); } else { print_int(0); }

    // Comparison with logical: (5 > 3) && (2 < 10) = 1
    if (5 > 3) && (2 < 10) { print_int(1); } else { print_int(0); }

    0
}
