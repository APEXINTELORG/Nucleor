// G9-FN-1 / G10-Cliff: unannotated files with extern surfaces must
// disclose that the effect framework is inactive instead of silently
// looking protected.
extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;

fn main() -> i32 {
    let n: i64 = nuc_rng_int(0, 100);
    print_int(n as i32);
    0
}
