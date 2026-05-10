// EXPECT: error[PARSE-IMPORT-LOCAL]
fn main() -> i64 {
    import "stdlib/rods/units.nr";
    return 0;
}
