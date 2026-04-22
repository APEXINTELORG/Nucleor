// =====================================================
// rods/queue — FIFO queue using Vec
// =====================================================
// Import: import "stdlib/rods/queue.nr"
// Provides: queue_new, queue_push, queue_pop, queue_peek,
//   queue_len, queue_is_empty
// =====================================================

// Queue layout (Vec):
//   [0] = items Vec (the backing store)
//   [1] = head index (front of queue)
//   [2] = count (number of items)

fn queue_new() -> Vec<i32> {
    let mut q: Vec<i32> = Vec::new();
    let mut items: Vec<i32> = Vec::new();
    q.push(items);
    q.push(0);
    q.push(0);
    return q;
}

// Push an item to the back of the queue
fn queue_push(q: Vec<i32>, val: i64) {
    let items: i64 = q.get(0);
    vec_push(items, val);
    vec_set(q, 2, q.get(2) + 1);
}

// Pop an item from the front of the queue
// Returns the value, or 0 if empty
fn queue_pop(q: Vec<i32>) -> i64 {
    let count: i64 = q.get(2);
    if count == 0 { return 0; };
    let items: i64 = q.get(0);
    let head: i64 = q.get(1);
    let val: i64 = vec_get(items, head);
    vec_set(q, 1, head + 1);
    vec_set(q, 2, count - 1);
    return val;
}

// Peek at the front item without removing it
// Returns the value, or 0 if empty
fn queue_peek(q: Vec<i32>) -> i64 {
    let count: i64 = q.get(2);
    if count == 0 { return 0; };
    let items: i64 = q.get(0);
    let head: i64 = q.get(1);
    return vec_get(items, head);
}

// Get the number of items in the queue
fn queue_len(q: Vec<i32>) -> i64 {
    return q.get(2);
}

// Check if the queue is empty
fn queue_is_empty(q: Vec<i32>) -> i64 {
    if q.get(2) == 0 { return 1; };
    return 0;
}
