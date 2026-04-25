// v0.3.14 RFC-0028 phase 3 — float-mixing format3 combos:
// iif (counter+counter+timing), iff (index+xy), sff (label+coord
// pair). f64 args carry as i64 bits; the runtime decodes via
// __nucleor_format_f64. Same wiring shape as the prior
// format3_* additions.

fn main() -> i32 {
    let dt: f64 = 0.033;
    let s1: str = format3_iif("iter {} of {} ({} sec)", 3, 10, dt);
    print(s1);

    let x: f64 = 1.25;
    let y: f64 = 0.75;
    let s2: str = format3_iff("{}: x={} y={}", 7, x, y);
    print(s2);

    let s3: str = format3_sff("{} at ({}, {})", "origin", x, y);
    print(s3);

    print("OK format3_float_mix");
    return 0;
}
