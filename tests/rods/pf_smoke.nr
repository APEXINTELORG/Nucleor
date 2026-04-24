// rods/pf — verify rod wrapper compiles + links (v0.2.235 ship).
// Build-only smoke; functional filtering needs dynamics + likelihood
// callbacks + initialization buffers, non-trivial in a single test
// file. Correctness coverage in the direct C unit test (1D global
// localization with uniform initialization).
import "stdlib/rods/pf.nr"

fn main() -> i64 {
    let p: i64 = pf_new(1, 1, 100, 42);
    if p == 0 { print("FAIL pf_new"); return 1; };
    if pf_particle_count(p) != 100 {
        print("FAIL pf particle count");
        return 1;
    };
    pf_free(p);
    print("OK pf_smoke");
    return 0;
}
