// =====================================================
// rods/hashmap — String-keyed hash map
// =====================================================
// Import: import "stdlib/rods/hashmap.nr"
// Provides: string-keyed map with i64 or f64 (bitcast i64) values,
//   plus key/value enumeration and removal.
// =====================================================

#cfile "../runtime/hashmap_rt.c"

extern fn nuc_map_new() -> i64;
extern fn nuc_map_set(h: i64, key: str, val: i64);
extern fn nuc_map_get(h: i64, key: str) -> i64;
extern fn nuc_map_has(h: i64, key: str) -> i64;
extern fn nuc_map_del(h: i64, key: str);
extern fn nuc_map_len(h: i64) -> i64;
extern fn nuc_map_keys(h: i64) -> i64;
extern fn nuc_map_val_at(h: i64, pos: i64) -> i64;
extern fn nuc_map_set_f64(h: i64, key: str, val: i64);
extern fn nuc_map_free(h: i64);

fn map_new() -> i64 { return nuc_map_new(); }
fn map_set(h: i64, key: str, val: i64) { nuc_map_set(h, key, val); }
fn map_set_f64(h: i64, key: str, val: i64) { nuc_map_set_f64(h, key, val); }
fn map_get(h: i64, key: str) -> i64 { return nuc_map_get(h, key); }
fn map_has(h: i64, key: str) -> i64 { return nuc_map_has(h, key); }
fn map_del(h: i64, key: str) { nuc_map_del(h, key); }
fn map_len(h: i64) -> i64 { return nuc_map_len(h); }
fn map_keys(h: i64) -> i64 { return nuc_map_keys(h); }
fn map_val_at(h: i64, pos: i64) -> i64 { return nuc_map_val_at(h, pos); }
fn map_free(h: i64) { nuc_map_free(h); }
