// Nucleor stdlib: vec_core
// Vector operations for bootstrap compiler.

fn vec_contains(v: Vec<i32>, target: i32) -> bool {
    let mut i: i32 = 0;
    let n: i32 = v.len();
    let mut found: bool = false;
    while i < n {
        if v.get(i) == target {
            found = true;
        };
        i = i + 1;
    };
    found
}

fn vec_sum(v: Vec<i32>) -> i32 {
    let mut total: i32 = 0;
    let mut i: i32 = 0;
    let n: i32 = v.len();
    while i < n {
        total = total + v.get(i);
        i = i + 1;
    };
    total
}

fn vec_max(v: Vec<i32>) -> i32 {
    let mut best: i32 = v.get(0);
    let mut i: i32 = 1;
    let n: i32 = v.len();
    while i < n {
        let val: i32 = v.get(i);
        if val > best {
            best = val;
        };
        i = i + 1;
    };
    best
}

fn main() -> i32 {
    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    let s: i32 = vec_sum(v);
    print_int(s);
    0
}
