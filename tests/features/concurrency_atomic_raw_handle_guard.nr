// F-CONC-001: legacy raw atomic helpers must reject forged/freed handles.
//
// Pre-fix, these calls dereferenced the raw i64 as a pointer and could
// SEGV or corrupt the heap. The runtime now validates raw handles against
// the atomic registry before touching memory.

import "stdlib/rods/atomic.nr"

fn main() -> i64 {
    if atomic_load_v(12345) != 0 { return 1; };
    if atomic_i64_load(67890) != 0 { return 2; };

    let h: i64 = atomic_new(41);
    if h == 0 { return 4; };
    if atomic_load_v(h) != 41 { atomic_drop(h); return 8; };
    if atomic_add(h, 1) != 41 { atomic_drop(h); return 16; };
    if atomic_load_v(h) != 42 { atomic_drop(h); return 32; };

    atomic_drop(h);
    if atomic_load_v(h) != 0 { return 64; };
    if atomic_i64_load(h) != 0 { return 128; };
    if atomic_add(h, 1) != 0 { return 256; };
    atomic_drop(h);
    return 0;
}
