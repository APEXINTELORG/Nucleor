// vecdeque_basic.nr — RFC-0017 phase 4: ring-buffer deque
// O(1) push/pop from both ends; indexed access via ring offset.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let q: i64 = vecdeque_new();
    if vecdeque_len(q) != 0 { fail = fail + 1; print("FAIL: empty len\n"); };

    // Push back
    vecdeque_push_back(q, 10);
    vecdeque_push_back(q, 20);
    vecdeque_push_back(q, 30);
    if vecdeque_len(q) != 3 { fail = fail + 1; print("FAIL: push_back len\n"); };
    if vecdeque_get(q, 0) != 10 { fail = fail + 1; print("FAIL: get 0 after push_back\n"); };
    if vecdeque_get(q, 2) != 30 { fail = fail + 1; print("FAIL: get 2 after push_back\n"); };

    // Pop front
    if vecdeque_pop_front(q) != 10 { fail = fail + 1; print("FAIL: pop_front\n"); };
    if vecdeque_len(q) != 2 { fail = fail + 1; print("FAIL: len after pop_front\n"); };
    if vecdeque_get(q, 0) != 20 { fail = fail + 1; print("FAIL: get 0 after pop_front\n"); };

    // Push front
    vecdeque_push_front(q, 5);
    vecdeque_push_front(q, 1);
    if vecdeque_len(q) != 4 { fail = fail + 1; print("FAIL: len after push_front\n"); };
    if vecdeque_get(q, 0) != 1 { fail = fail + 1; print("FAIL: get 0 after push_front\n"); };
    if vecdeque_get(q, 1) != 5 { fail = fail + 1; print("FAIL: get 1 after push_front\n"); };

    // Pop back
    if vecdeque_pop_back(q) != 30 { fail = fail + 1; print("FAIL: pop_back\n"); };
    if vecdeque_len(q) != 3 { fail = fail + 1; print("FAIL: len after pop_back\n"); };

    // Set / get
    vecdeque_set(q, 1, 99);
    if vecdeque_get(q, 1) != 99 { fail = fail + 1; print("FAIL: set then get\n"); };

    // Growth: push 100 elements through to trigger re-allocation
    vecdeque_clear(q);
    let mut i: i64 = 0;
    while i < 100 {
        vecdeque_push_back(q, i);
        i = i + 1;
    };
    if vecdeque_len(q) != 100 { fail = fail + 1; print("FAIL: grew to 100\n"); };
    if vecdeque_get(q, 0) != 0 { fail = fail + 1; print("FAIL: grew[0]\n"); };
    if vecdeque_get(q, 99) != 99 { fail = fail + 1; print("FAIL: grew[99]\n"); };

    // Clear
    vecdeque_clear(q);
    if vecdeque_len(q) != 0 { fail = fail + 1; print("FAIL: cleared\n"); };

    vecdeque_free(q);

    if fail == 0 { print("OK vecdeque_basic\n"); return 0; };
    return 1;
}
