fn maybe_div(a: f64, b: f64) -> Option<f64> {
    if b == 0.0 {
        None
    } else {
        Some(a / b)
    }
}

fn main() -> i32 {
    let ok: Option<f64> = maybe_div(10.0, 2.0);
    let none: Option<f64> = maybe_div(1.0, 0.0);

    let v1: f64 = match ok {
        Some { value } => value,
        None => -1.0,
    };
    let v2: f64 = match none {
        Some { value } => value,
        None => -1.0,
    };
    print_f64(v1);
    print_f64(v2);

    let r1: Result<f64, i32> = Ok(3.5);
    let r2: Result<f64, i32> = Err(7);

    let x1: f64 = match r1 {
        Ok { value } => value,
        Err { value } => i32_to_f64(value),
    };
    let x2: f64 = match r2 {
        Ok { value } => value,
        Err { value } => i32_to_f64(value),
    };
    print_f64(x1);
    print_f64(x2);
    0
}
