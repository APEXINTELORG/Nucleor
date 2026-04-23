// rods/mem — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/mem.nr"

fn main() -> i64 {
    let v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    let bytes_before: i64 = vec_mem_bytes(v);
    if bytes_before <= 0 { print("FAIL mem_bytes"); return 1; };
    vec_clear(v);
    if v.len() != 0 { print("FAIL clear"); return 1; };
    // vec_free would invalidate the handle; skip on the smoke since the
    // Vec is still owned by the local scope.
    print("OK mem_smoke");
    return 0;
}
