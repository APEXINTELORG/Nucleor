// parse_stringify — RFC-0017 stdlib enrichment.
//
//   str_to_i64(s)    -> i64
//   str_to_f64(s)    -> i64 (f64 bits)
//   str_to_bool(s)   -> i64
//   int_to_str(v)    -> str
//   f64_to_str(v)    -> str
//   bool_to_str(v)   -> str

fn main() -> i64 {
    let mut fail: i64 = 0;

    // str_to_i64: positive, negative, leading-whitespace, sign prefix
    if str_to_i64("42") != 42         { fail = fail + 1; print("FAIL str_to_i64 42"); };
    if str_to_i64("-7") != -7         { fail = fail + 1; print("FAIL str_to_i64 -7"); };
    if str_to_i64("  100") != 100     { fail = fail + 1; print("FAIL str_to_i64 ws"); };
    if str_to_i64("+9") != 9          { fail = fail + 1; print("FAIL str_to_i64 +"); };
    if str_to_i64("garbage") != 0     { fail = fail + 1; print("FAIL str_to_i64 bad"); };
    if str_to_i64("") != 0            { fail = fail + 1; print("FAIL str_to_i64 empty"); };

    // str_to_f64: parse, then re-encode to verify
    let pi: i64 = str_to_f64("3.14159");
    let re: str = f64_to_str(pi);
    // f64 round-trip: re-parse re and compare bits
    let pi2: i64 = str_to_f64(re);
    if pi != pi2 { fail = fail + 1; print("FAIL f64 round-trip"); };

    // str_to_bool: case + numeric tolerance
    if str_to_bool("true") != 1       { fail = fail + 1; print("FAIL bool true"); };
    if str_to_bool("TRUE") != 1       { fail = fail + 1; print("FAIL bool TRUE"); };
    if str_to_bool("false") != 0      { fail = fail + 1; print("FAIL bool false"); };
    if str_to_bool("1") != 1          { fail = fail + 1; print("FAIL bool 1"); };
    if str_to_bool("0") != 0          { fail = fail + 1; print("FAIL bool 0"); };
    if str_to_bool("nope") != 0       { fail = fail + 1; print("FAIL bool nope"); };

    // int_to_str round-trip
    if !str_eq(int_to_str(42), "42")     { fail = fail + 1; print("FAIL int_to_str"); };
    if !str_eq(int_to_str(-7), "-7")     { fail = fail + 1; print("FAIL int_to_str -7"); };
    if !str_eq(int_to_str(0), "0")       { fail = fail + 1; print("FAIL int_to_str 0"); };

    // bool_to_str
    if !str_eq(bool_to_str(1), "true")   { fail = fail + 1; print("FAIL bool_to_str true"); };
    if !str_eq(bool_to_str(0), "false")  { fail = fail + 1; print("FAIL bool_to_str false"); };
    if !str_eq(bool_to_str(99), "true")  { fail = fail + 1; print("FAIL bool_to_str truthy"); };

    // Round trip int <-> str
    let v: i64 = 12345;
    if str_to_i64(int_to_str(v)) != v {
        fail = fail + 1; print("FAIL int round-trip");
    };

    if fail == 0 { print("OK parse_stringify"); return 0; };
    return 1;
}
