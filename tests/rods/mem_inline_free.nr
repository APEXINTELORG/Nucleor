// Regression: mem_rt.c must not free inline Vec storage.
import "stdlib/rods/mem.nr"

fn main() -> i64 {
    let v: Vec<i64> = Vec::new();
    v.push(1);
    v.push(2);
    if vec_mem_bytes(v) <= 0 { return 1; };
    nuc_vec_free(v);
    print("OK mem_inline_free");
    return 0;
}
