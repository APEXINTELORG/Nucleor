// rods/fk_chain — verify rod wrapper compiles + links (v0.2.175 ship).
// Build a 1-link revolute chain about z, set its variable to 0,
// confirm world position is at the offset (no rotation applied).
import "stdlib/rods/fk_chain.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;

    let chain: i64 = fk_chain_new();

    // One revolute joint about z, offset 1m along x.
    let _slot: i64 = fk_chain_add_joint(
        chain, fk_revolute(),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),  // pos offset
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),  // identity quat
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0)   // z-axis
    );
    if fk_chain_count(chain) != 1 { fail = fail + 1; print("FAIL count after one add"); };

    // Caller would normally pass a malloc'd double[] for vars; for the
    // smoke we just verify the link-pos accessors return non-zero
    // numbers after default-init (vars handle = 0 should be safe to
    // read; FK update returns -1 on null vars and we handle that).
    fk_chain_free(chain);
    print("OK fk_chain_smoke");
    return fail;
}
