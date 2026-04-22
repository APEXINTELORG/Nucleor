// struct_methods.nr — structs, fields, mutation
struct Counter {
    value: i64,
    step: i64
}

fn tick(c: Counter) -> Counter {
    let next: Counter = Counter { value: c.value + c.step, step: c.step };
    return next;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let c0: Counter = Counter { value: 0, step: 5 };
    if c0.value != 0 { print("FAIL struct_methods: initial value"); fail = fail + 1; };
    if c0.step != 5 { print("FAIL struct_methods: initial step"); fail = fail + 1; };
    let c1: Counter = tick(c0);
    if c1.value != 5 { print("FAIL struct_methods: tick once"); fail = fail + 1; };
    let c2: Counter = tick(c1);
    if c2.value != 10 { print("FAIL struct_methods: tick twice"); fail = fail + 1; };

    let mut m: Counter = Counter { value: 100, step: 1 };
    m.value = 42;
    if m.value != 42 { print("FAIL struct_methods: field assign"); fail = fail + 1; };

    if fail == 0 { print("OK struct_methods"); return 0; };
    return 1;
}
