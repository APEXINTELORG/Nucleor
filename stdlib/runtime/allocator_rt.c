// allocator_rt.c — Custom Memory Allocators for Nucleor
// Arena (bump allocator), object pool, allocation stats.
//
// Compile: clang -c stdlib/runtime/allocator_rt.c -o target/allocator_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ================================================================
//  Arena Allocator (bump allocation, free all at once)
// ================================================================

typedef struct {
    char *base;
    int capacity;
    int offset;
    int peak;
    int n_allocs;
} Arena;

long long nuc_arena_new(long long size_bytes) {
    int sz = (int)size_bytes;
    Arena *a = (Arena *)malloc(sizeof(Arena));
    a->base = (char *)malloc(sz);
    a->capacity = sz;
    a->offset = 0;
    a->peak = 0;
    a->n_allocs = 0;
    return (long long)a;
}

// Allocate n bytes, returns handle (offset into arena)
long long nuc_arena_alloc(long long h, long long n_bytes) {
    Arena *a = (Arena *)(void *)h;
    int n = (int)n_bytes;
    // Align to 8 bytes
    int aligned = (a->offset + 7) & ~7;
    if (aligned + n > a->capacity) return -1; // out of memory
    a->offset = aligned + n;
    if (a->offset > a->peak) a->peak = a->offset;
    a->n_allocs++;
    return (long long)(a->base + aligned);
}

// Reset arena (free all allocations)
void nuc_arena_reset(long long h) {
    Arena *a = (Arena *)(void *)h;
    a->offset = 0;
    a->n_allocs = 0;
}

long long nuc_arena_used(long long h) { return ((Arena *)(void *)h)->offset; }
long long nuc_arena_peak(long long h) { return ((Arena *)(void *)h)->peak; }
long long nuc_arena_capacity(long long h) { return ((Arena *)(void *)h)->capacity; }

void nuc_arena_free(long long h) {
    Arena *a = (Arena *)(void *)h;
    if (a) { free(a->base); free(a); }
}

// ================================================================
//  Object Pool (fixed-size slot allocator)
// ================================================================

typedef struct {
    char *base;
    int obj_size;
    int capacity;
    int *free_list; // stack of free slot indices
    int free_top;   // top of free stack
    int n_used;
} ObjPool;

long long nuc_pool_new(long long obj_size, long long capacity) {
    int sz = (int)obj_size, cap = (int)capacity;
    // Align object size to 8 bytes
    sz = (sz + 7) & ~7;
    ObjPool *p = (ObjPool *)malloc(sizeof(ObjPool));
    p->obj_size = sz;
    p->capacity = cap;
    p->base = (char *)calloc(cap, sz);
    p->free_list = (int *)malloc(cap * sizeof(int));
    // Initialize free list (all slots free)
    for (int i = 0; i < cap; i++) p->free_list[i] = cap - 1 - i;
    p->free_top = cap;
    p->n_used = 0;
    return (long long)p;
}

// Allocate one slot, returns pointer
long long nuc_pool_alloc(long long h) {
    ObjPool *p = (ObjPool *)(void *)h;
    if (p->free_top <= 0) return 0; // pool exhausted
    int slot = p->free_list[--p->free_top];
    p->n_used++;
    return (long long)(p->base + slot * p->obj_size);
}

// Free one slot (pass the pointer returned by alloc)
void nuc_pool_free_slot(long long h, long long ptr) {
    ObjPool *p = (ObjPool *)(void *)h;
    long long offset = (long long)((char *)(void *)ptr - p->base);
    int slot = (int)(offset / p->obj_size);
    if (slot >= 0 && slot < p->capacity) {
        p->free_list[p->free_top++] = slot;
        p->n_used--;
    }
}

long long nuc_pool_used(long long h) { return ((ObjPool *)(void *)h)->n_used; }
long long nuc_pool_available(long long h) { return ((ObjPool *)(void *)h)->free_top; }
long long nuc_pool_capacity(long long h) { return ((ObjPool *)(void *)h)->capacity; }

void nuc_pool_free(long long h) {
    ObjPool *p = (ObjPool *)(void *)h;
    if (p) { free(p->base); free(p->free_list); free(p); }
}

// ================================================================
//  Stack allocator (LIFO, for temporary computation buffers)
// ================================================================

typedef struct {
    char *base;
    int capacity;
    int top;
    int *marks;
    int n_marks;
    int marks_cap;
} StackAlloc;

long long nuc_stack_alloc_new(long long size_bytes) {
    int sz = (int)size_bytes;
    StackAlloc *s = (StackAlloc *)malloc(sizeof(StackAlloc));
    s->base = (char *)malloc(sz);
    s->capacity = sz;
    s->top = 0;
    s->marks_cap = 64;
    s->marks = (int *)malloc(64 * sizeof(int));
    s->n_marks = 0;
    return (long long)s;
}

long long nuc_stack_alloc_push(long long h, long long n_bytes) {
    StackAlloc *s = (StackAlloc *)(void *)h;
    int n = (int)n_bytes;
    int aligned = (s->top + 7) & ~7;
    if (aligned + n > s->capacity) return 0;
    s->top = aligned + n;
    return (long long)(s->base + aligned);
}

// Save current position (mark)
void nuc_stack_alloc_mark(long long h) {
    StackAlloc *s = (StackAlloc *)(void *)h;
    if (s->n_marks >= s->marks_cap) {
        s->marks_cap *= 2;
        s->marks = (int *)realloc(s->marks, s->marks_cap * sizeof(int));
    }
    s->marks[s->n_marks++] = s->top;
}

// Pop back to last mark
void nuc_stack_alloc_pop(long long h) {
    StackAlloc *s = (StackAlloc *)(void *)h;
    if (s->n_marks > 0) s->top = s->marks[--s->n_marks];
    else s->top = 0;
}

void nuc_stack_alloc_free(long long h) {
    StackAlloc *s = (StackAlloc *)(void *)h;
    if (s) { free(s->base); free(s->marks); free(s); }
}
