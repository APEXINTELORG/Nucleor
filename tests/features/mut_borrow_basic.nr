// Phase 2c: Mutate struct field through &mut reference

struct Counter { value: i32 }

fn increment(c: &mut Counter) {
    c.value = c.value + 1;
}

fn main() -> i32 {
    let mut a: Counter = Counter { value: 0 };
    print_int(a.value);        // 0
    increment(&mut a);
    print_int(a.value);        // 1
    increment(&mut a);
    increment(&mut a);
    print_int(a.value);        // 3
    0
}
