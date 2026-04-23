// rods/color — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/color.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    let hsv: i64 = color_rgb_to_hsv(255, 0, 0);
    if hsv == 0 { fail = fail + 1; print("FAIL rgb_to_hsv"); };
    let pal: i64 = color_palette(8);
    if pal == 0 { fail = fail + 1; print("FAIL palette"); };
    if fail == 0 { print("OK color_smoke"); };
    return fail;
}
