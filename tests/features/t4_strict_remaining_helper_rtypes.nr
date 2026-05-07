// T-4 strict inference positive lock for direct numeric/f64 helper returns.
// These runtime helpers are callable without rod imports, so strict mode must
// know their scalar return types instead of using the empty sentinel.

fn main() -> i64 {
    let bits: i64 = f64_to_bits(4.0);
    let from_bits: f64 = f64_from_bits(bits);
    let s: f64 = sqrt(16.0);
    let sn: f64 = sin(0.0);
    let cs: f64 = cos(0.0);
    let p: f64 = pow(2.0, 3.0);
    let fl: f64 = floor(3.7);
    let ce: f64 = ceil(3.2);
    let rd: f64 = round(2.4);
    let ex: f64 = exp(0.0);
    let lg: f64 = log(1.0);
    let th: f64 = tanh(0.0);
    let ab: f64 = fabs(0.0);
    let rem: f64 = fmod(7.0, 3.0);
    let si: i32 = f64_to_i32(s);

    if from_bits != 4.0 { return 1; };
    if s != 4.0 { return 2; };
    if sn != 0.0 { return 4; };
    if cs != 1.0 { return 8; };
    if p != 8.0 { return 16; };
    if fl != 3.0 { return 32; };
    if ce != 4.0 { return 64; };
    if rd != 2.0 { return 128; };
    if ex != 1.0 { return 256; };
    if lg != 0.0 { return 512; };
    if th != 0.0 { return 1024; };
    if ab != 0.0 { return 2048; };
    if rem != 1.0 { return 4096; };
    return 0;
}
