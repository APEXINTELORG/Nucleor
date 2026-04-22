// Phase 2a: Move semantics — comprehensive passing tests

struct Widget { id: i32 }

fn take_widget(w: Widget) -> i32 { w.id }

fn main() -> i32 {
    // 1. Field access does NOT move the struct
    let w: Widget = Widget { id: 10 };
    print_int(w.id);    // field access — no move
    print_int(w.id);    // still valid
    let r: i32 = take_widget(w);  // NOW w moves
    print_int(r);

    // 2. Multiple Copy uses are fine
    let x: i32 = 5;
    let a: i32 = x;
    let b: i32 = x;
    let c: i32 = x;
    print_int(a);
    print_int(b);
    print_int(c);

    // 3. Move in both branches — both consume, that's fine
    let w2: Widget = Widget { id: 20 };
    let cond: bool = true;
    let val: i32 = if cond {
        take_widget(w2)
    } else {
        take_widget(w2)
    };
    print_int(val);
    // w2 is definitely moved after this (both branches move it)

    // 4. Strings move too
    let s: str = "hello";
    let s2: str = s;   // s moves to s2
    print(s2);          // ok

    // 5. Arrays move
    let arr: [i32; 3] = [1, 2, 3];
    let arr2: [i32; 3] = arr;  // arr moves to arr2
    print_int(arr2[0]);         // ok

    // 6. Tuples move
    let t: (i32, i32) = (1, 2);
    let t2: (i32, i32) = t;    // t moves to t2
    print_int(t2.0);            // ok

    0
}
