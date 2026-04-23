// rods/mem — Vec memory-management extensions (free, clear, footprint)
//
// The default Vec lifecycle is grow-only; vec_clear lets long-running
// programs reuse a Vec without realloc, and vec_free returns its
// backing storage to the allocator. These are opt-in helpers — every
// Vec works unchanged whether or not you call them.
//
// See `stdlib/runtime/mem_rt.c`.
#cfile "../runtime/mem_rt.c"

extern fn nuc_vec_free(handle: i64);
extern fn nuc_vec_clear(handle: i64);
extern fn nuc_vec_mem_bytes(handle: i64) -> i64;

// Free a Vec and its data array. The handle is invalid after this call.
fn vec_free(v: i64) { nuc_vec_free(v); }

// Reset Vec length to 0 without freeing the backing array.
// The next vec_push starts writing at index 0 again; the underlying
// allocation is kept for reuse.
fn vec_clear(v: i64) { nuc_vec_clear(v); }

// Total bytes the Vec currently holds (struct header + capacity * 8).
fn vec_mem_bytes(v: i64) -> i64 { return nuc_vec_mem_bytes(v); }
