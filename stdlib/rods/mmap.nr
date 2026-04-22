// =====================================================
// rods/mmap — Memory-mapped files + shared memory
// =====================================================
// Import: import "stdlib/rods/mmap.nr"
// Provides: mmap a file (read or read-write), random access reads
//   and writes, sync, close. Plus POSIX shared-memory primitives.
// =====================================================

#cfile "../runtime/mmap_rt.c"

extern fn nuc_mmap_file(path: str, mode: i64) -> i64;
extern fn nuc_mmap_size(h: i64) -> i64;
extern fn nuc_mmap_read_f64(h: i64, offset: i64) -> i64;
extern fn nuc_mmap_write(h: i64, offset: i64, data: str, len: i64);
extern fn nuc_mmap_write_f64(h: i64, offset: i64, val: i64);
extern fn nuc_mmap_sync(h: i64);
extern fn nuc_mmap_close(h: i64);
extern fn nuc_shm_create(name: str, size: i64) -> i64;
extern fn nuc_shm_open(name: str) -> i64;
extern fn nuc_shm_close(h: i64);

fn mmap_open(path: str, mode: i64) -> i64 { return nuc_mmap_file(path, mode); }
fn mmap_size(h: i64) -> i64 { return nuc_mmap_size(h); }
fn mmap_read_f64(h: i64, offset: i64) -> i64 { return nuc_mmap_read_f64(h, offset); }
fn mmap_write(h: i64, offset: i64, data: str, len: i64) { nuc_mmap_write(h, offset, data, len); }
fn mmap_write_f64(h: i64, offset: i64, val: i64) { nuc_mmap_write_f64(h, offset, val); }
fn mmap_sync(h: i64) { nuc_mmap_sync(h); }
fn mmap_close(h: i64) { nuc_mmap_close(h); }
fn shm_create(name: str, size: i64) -> i64 { return nuc_shm_create(name, size); }
fn shm_open(name: str) -> i64 { return nuc_shm_open(name); }
fn shm_close(h: i64) { nuc_shm_close(h); }
