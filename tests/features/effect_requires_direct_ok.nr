// Direct same-file requires propagation: broad `io` permits `io.read`.

fn read_sensor() -> i32 requires [io.read] {
    42
}

fn middle() -> i32 requires [io] {
    read_sensor()
}

fn main() -> i32 requires [io] {
    if middle() == 42 { 0 } else { 1 }
}
