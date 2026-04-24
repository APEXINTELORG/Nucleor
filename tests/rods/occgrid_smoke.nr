// rods/occgrid — verify rod wrapper compiles + links (v0.2.287 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (single ray decreases free-cell log-odds along path, increases
// occ log-odds at endpoint).
import "stdlib/rods/occgrid.nr"

fn main() -> i64 {
    print("OK occgrid_smoke");
    return 0;
}
