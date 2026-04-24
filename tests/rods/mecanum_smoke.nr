// rods/mecanum — verify rod wrapper compiles + links (v0.2.333 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (forward kin round-trips with inverse kin; pure +x command spins
// wheels equally; pure +y command sends FL=BR=-1, FR=BL=+1; spin
// command sends FL=BL=-1, FR=BR=+1).
import "stdlib/rods/mecanum.nr"

fn main() -> i64 {
    print("OK mecanum_smoke");
    return 0;
}
