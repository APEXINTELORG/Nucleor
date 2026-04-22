// =====================================================
// rods/vecdeque — VecDeque<i64> (RFC-0017 phase 4)
// =====================================================
// Import: import "stdlib/rods/vecdeque.nr"
//
// Ring-buffer deque with O(1) push/pop at both ends. Random access
// via get/set is O(1) through ring-offset arithmetic.
//
// Use VecDeque when you need:
//   - FIFO queue semantics (push_back / pop_front)
//   - LIFO stack semantics (push_back / pop_back)
//   - Both-ends-amortized work like sliding-window analytics
// Use Vec when you only need a growable array (push_back + indexed read).
// =====================================================

fn vd_new() -> i64 { return vecdeque_new(); }
fn vd_with_capacity(n: i64) -> i64 { return vecdeque_with_capacity(n); }

fn vd_push_back(q: i64, v: i64) -> i64 { return vecdeque_push_back(q, v); }
fn vd_push_front(q: i64, v: i64) -> i64 { return vecdeque_push_front(q, v); }
fn vd_pop_front(q: i64) -> i64 { return vecdeque_pop_front(q); }
fn vd_pop_back(q: i64) -> i64 { return vecdeque_pop_back(q); }

fn vd_get(q: i64, i: i64) -> i64 { return vecdeque_get(q, i); }
fn vd_set(q: i64, i: i64, v: i64) -> i64 { return vecdeque_set(q, i, v); }

fn vd_len(q: i64) -> i64 { return vecdeque_len(q); }
fn vd_is_empty(q: i64) -> i64 {
    if vecdeque_len(q) == 0 { return 1; };
    return 0;
}
fn vd_capacity(q: i64) -> i64 { return vecdeque_capacity(q); }
fn vd_clear(q: i64) -> i64 { return vecdeque_clear(q); }

fn vd_free(q: i64) -> i64 { return vecdeque_free(q); }
