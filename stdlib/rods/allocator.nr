// rods/allocator — Bump arena, object pool, mark/pop stack allocator
//
// Three allocator flavors share one runtime, all returning raw byte
// addresses (i64). This rod is the v0.4 ergonomic wrapper around
// `stdlib/runtime/allocator_rt.c` — full RFC-0002 `Box<T, A>` /
// `Allocator` trait integration arrives in v0.4.
//
//   - Arena (bump): O(1) alloc, no per-allocation free; reset
//     wipes the whole arena. Use for per-frame / per-request
//     allocation patterns where everything dies together.
//   - Object Pool: fixed-size slots, freelist of recycled
//     entries. Use for hot allocate/free of same-typed objects
//     (linked-list nodes, particles, packet buffers).
//   - Stack Allocator: bump with mark/pop. `mark` records the
//     current offset; `pop` unwinds back to it. Use for nested
//     scopes that need to deallocate everything from a checkpoint.
//
// See `stdlib/runtime/allocator_rt.c`.
#cfile "../runtime/allocator_rt.c"

// ----- Arena (bump) -----
extern fn nuc_arena_new(size_bytes: i64) -> i64;
extern fn nuc_arena_alloc(h: i64, n_bytes: i64) -> i64;
extern fn nuc_arena_reset(h: i64);
extern fn nuc_arena_used(h: i64) -> i64;
extern fn nuc_arena_peak(h: i64) -> i64;
extern fn nuc_arena_capacity(h: i64) -> i64;
extern fn nuc_arena_free(h: i64);

// `allocator_arena_*` prefix avoids colliding with `arena_new` /
// `arena_alloc` / `arena_reset` / `arena_destroy` — those names are
// reserved by the s1 compiler for the (still-unimplemented) RFC-0002
// `Arena` builtin path. This rod's bump arena is shipped today via
// the `nuc_arena_*` runtime in `allocator_rt.c`; once RFC-0002 lands
// the builtin path will share the same runtime.
fn allocator_arena_new(size: i64) -> i64 { return nuc_arena_new(size); }
fn allocator_arena_alloc(a: i64, n: i64) -> i64 { return nuc_arena_alloc(a, n); }
fn allocator_arena_reset(a: i64) { nuc_arena_reset(a); }
fn allocator_arena_used(a: i64) -> i64 { return nuc_arena_used(a); }
fn allocator_arena_peak(a: i64) -> i64 { return nuc_arena_peak(a); }
fn allocator_arena_capacity(a: i64) -> i64 { return nuc_arena_capacity(a); }
fn allocator_arena_free(a: i64) { nuc_arena_free(a); }

// ----- Object Pool -----
extern fn nuc_pool_new(obj_size: i64, capacity: i64) -> i64;
extern fn nuc_pool_alloc(h: i64) -> i64;
extern fn nuc_pool_free_slot(h: i64, ptr: i64);
extern fn nuc_pool_used(h: i64) -> i64;
extern fn nuc_pool_available(h: i64) -> i64;
extern fn nuc_pool_capacity(h: i64) -> i64;
extern fn nuc_pool_free(h: i64);

fn allocator_pool_new(obj_size: i64, capacity: i64) -> i64 {
    return nuc_pool_new(obj_size, capacity);
}
fn allocator_pool_alloc(p: i64) -> i64 { return nuc_pool_alloc(p); }
fn allocator_pool_free_slot(p: i64, ptr: i64) { nuc_pool_free_slot(p, ptr); }
fn allocator_pool_used(p: i64) -> i64 { return nuc_pool_used(p); }
fn allocator_pool_available(p: i64) -> i64 { return nuc_pool_available(p); }
fn allocator_pool_capacity(p: i64) -> i64 { return nuc_pool_capacity(p); }
fn allocator_pool_free(p: i64) { nuc_pool_free(p); }

// ----- Stack allocator (bump + mark/pop) -----
extern fn nuc_stack_alloc_new(size_bytes: i64) -> i64;
extern fn nuc_stack_alloc_push(h: i64, n_bytes: i64) -> i64;
extern fn nuc_stack_alloc_mark(h: i64);
extern fn nuc_stack_alloc_pop(h: i64);
extern fn nuc_stack_alloc_free(h: i64);

fn allocator_stack_new(size: i64) -> i64 { return nuc_stack_alloc_new(size); }
fn allocator_stack_push(s: i64, n: i64) -> i64 { return nuc_stack_alloc_push(s, n); }
fn allocator_stack_mark(s: i64) { nuc_stack_alloc_mark(s); }
fn allocator_stack_pop(s: i64) { nuc_stack_alloc_pop(s); }
fn allocator_stack_free(s: i64) { nuc_stack_alloc_free(s); }
