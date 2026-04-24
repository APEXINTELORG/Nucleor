// rods/pidc — verify rod wrapper compiles + links (v0.2.257 ship,
// renamed from pid in v0.2.259 to avoid collision with control.nr).
// Build-only smoke; correctness coverage in the direct C unit test.
import "stdlib/rods/pidc.nr"

fn main() -> i64 {
    print("OK pidc_smoke");
    return 0;
}
