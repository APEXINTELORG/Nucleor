// rods/pqueue — Priority queue (binary min/max-heap with decrease-key)
//
// The FIFO sibling lives in `queue.nr`. This rod wraps the binary-heap
// runtime in `stdlib/runtime/queue_rt.c`. Two heap variants share the
// runtime: pass `0` to `pq_new` for a min-heap (default for Dijkstra-
// style algorithms), `1` for a max-heap (default for top-K selection).
//
// Keys are i64-encoded so users can store float bits, packed
// (priority, index) pairs, or raw priorities; the runtime compares
// keys as signed i64.
//
// `pq_decrease_key` rewrites the key for an existing value (lookup
// is by the value pointer / handle stored at push time).
//
// See `stdlib/runtime/queue_rt.c`.
#cfile "../runtime/queue_rt.c"

extern fn nuc_pq_new(heap_type: i64) -> i64;
extern fn nuc_pq_push(h: i64, key_bits: i64, value: i64);
extern fn nuc_pq_pop(h: i64) -> i64;
extern fn nuc_pq_pop_key(h: i64) -> i64;
extern fn nuc_pq_peek(h: i64) -> i64;
extern fn nuc_pq_peek_key(h: i64) -> i64;
extern fn nuc_pq_size(h: i64) -> i64;
extern fn nuc_pq_empty(h: i64) -> i64;
extern fn nuc_pq_decrease_key(h: i64, value: i64, new_key_bits: i64);
extern fn nuc_pq_free(h: i64);

// Constructors. `pq_min` for Dijkstra / shortest-path, `pq_max` for
// best-K selection.
fn pq_min() -> i64 { return nuc_pq_new(0); }
fn pq_max() -> i64 { return nuc_pq_new(1); }

// Push `(key, value)`. Both are i64; encode floats by reinterpreting
// the bits.
fn pq_push(h: i64, key: i64, value: i64) { nuc_pq_push(h, key, value); }

// Pop the top entry (lowest-key for min-heap, highest-key for max).
// `pq_pop` returns the value; `pq_pop_key` returns the key.
fn pq_pop(h: i64) -> i64 { return nuc_pq_pop(h); }
fn pq_pop_key(h: i64) -> i64 { return nuc_pq_pop_key(h); }

// Peek without removing.
fn pq_peek(h: i64) -> i64 { return nuc_pq_peek(h); }
fn pq_peek_key(h: i64) -> i64 { return nuc_pq_peek_key(h); }

fn pq_size(h: i64) -> i64 { return nuc_pq_size(h); }
fn pq_empty(h: i64) -> i64 { return nuc_pq_empty(h); }

// Lower an existing entry's key (for Dijkstra). The runtime locates
// the entry by its `value` (the pointer / handle stored at push time).
fn pq_decrease_key(h: i64, value: i64, new_key: i64) {
    nuc_pq_decrease_key(h, value, new_key);
}

fn pq_free(h: i64) { nuc_pq_free(h); }
