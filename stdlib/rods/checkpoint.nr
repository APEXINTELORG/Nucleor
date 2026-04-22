// rods/checkpoint — ML model checkpointing for gradient recomputation
#cfile "../runtime/checkpoint_rt.c"

extern fn nuc_ckpt_new(interval: i64) -> i64;
extern fn nuc_ckpt_save(cs: i64, layer_id: i64, data: i64, size: i64);
extern fn nuc_ckpt_restore(cs: i64, layer_id: i64) -> i64;
extern fn nuc_ckpt_nearest_before(cs: i64, layer_id: i64) -> i64;
extern fn nuc_ckpt_recompute_range(cs: i64, layer_id: i64) -> i64;
extern fn nuc_ckpt_clear(cs: i64);
extern fn nuc_ckpt_memory_used(cs: i64) -> i64;
extern fn nuc_ckpt_memory_saved(cs: i64) -> i64;
extern fn nuc_ckpt_n_stored(cs: i64) -> i64;
extern fn nuc_ckpt_free(cs: i64);

fn ckpt_new(interval: i64) -> i64 { return nuc_ckpt_new(interval); }
fn ckpt_save(cs: i64, layer: i64, data: i64, size: i64) { nuc_ckpt_save(cs, layer, data, size); }
fn ckpt_restore(cs: i64, layer: i64) -> i64 { return nuc_ckpt_restore(cs, layer); }
fn ckpt_nearest_before(cs: i64, layer: i64) -> i64 { return nuc_ckpt_nearest_before(cs, layer); }
fn ckpt_recompute_range(cs: i64, layer: i64) -> i64 { return nuc_ckpt_recompute_range(cs, layer); }
fn ckpt_clear(cs: i64) { nuc_ckpt_clear(cs); }
fn ckpt_memory_used(cs: i64) -> i64 { return nuc_ckpt_memory_used(cs); }
fn ckpt_memory_saved(cs: i64) -> i64 { return nuc_ckpt_memory_saved(cs); }
fn ckpt_n_stored(cs: i64) -> i64 { return nuc_ckpt_n_stored(cs); }
fn ckpt_free(cs: i64) { nuc_ckpt_free(cs); }
