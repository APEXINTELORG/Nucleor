// rods/vecdeque — verify rod wrapper
import "stdlib/rods/vecdeque.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let q: i64 = vd_new();
    if vd_is_empty(q) != 1 { fail = fail + 1; print("FAIL empty"); };

    // FIFO usage
    vd_push_back(q, 1);
    vd_push_back(q, 2);
    vd_push_back(q, 3);
    if vd_pop_front(q) != 1 { fail = fail + 1; print("FAIL fifo pop 1"); };
    if vd_pop_front(q) != 2 { fail = fail + 1; print("FAIL fifo pop 2"); };

    // LIFO usage
    vd_push_back(q, 4);
    vd_push_back(q, 5);
    if vd_pop_back(q) != 5 { fail = fail + 1; print("FAIL lifo pop 5"); };

    // Push front
    vd_push_front(q, 0);
    if vd_get(q, 0) != 0 { fail = fail + 1; print("FAIL push_front 0"); };

    vd_free(q);

    if fail == 0 { print("OK vecdeque"); return 0; };
    return 1;
}
