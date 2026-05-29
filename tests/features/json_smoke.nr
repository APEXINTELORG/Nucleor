// v0.8.207 stdlib/rods/json.nr first test coverage.
//
// JSON parser + serializer (pure Nucleor, RFC-0017-style ADT
// over Vec<i32>). Pre-v0.8.207: zero coverage on the standalone
// rod.
//
// Locks four core JSON invariants:
//
//   1. Type tags — null=0, bool=1, int=2, str=3, array=4,
//      object=5, f64=6 (stable wire format).
//   2. Parse number — json_parse("42") → type=2, int=42;
//      json_parse("-7") → type=2, int=-7.
//   3. Parse + index array — json_parse("[10,20,30]") →
//      array_len=3, array_get(1).int = 20.
//   4. Stringify round-trip — stringify(parse("42")) == "42".
//
// Expected: rc=0.

import "stdlib/rods/json.nr"

fn check_type_tags() -> i64 {
    let n: Vec<i32> = json_null();
    if json_type(n) != 0 { return 1; };
    let b: Vec<i32> = json_from_bool(1);
    if json_type(b) != 1 { return 2; };
    let i: Vec<i32> = json_from_int(42);
    if json_type(i) != 2 { return 4; };
    let s: Vec<i32> = json_from_string("hi");
    if json_type(s) != 3 { return 8; };
    let a: Vec<i32> = json_array_new();
    if json_type(a) != 4 { return 16; };
    let o: Vec<i32> = json_object_new();
    if json_type(o) != 5 { return 32; };
    return 0;
}

fn check_parse_number() -> i64 {
    let pos: Vec<i32> = json_parse("42");
    if json_type(pos) != 2 { return 64; };
    if json_int(pos) != 42 { return 128; };
    let neg: Vec<i32> = json_parse("-7");
    if json_int(neg) != (0 - 7) { return 256; };
    return 0;
}

fn check_parse_array() -> i64 {
    let arr: Vec<i32> = json_parse("[10,20,30]");
    if json_type(arr) != 4 { return 512; };
    if json_array_len(arr) != 3 { return 1024; };
    let elt: Vec<i32> = json_array_get(arr, 1);
    if json_int(elt) != 20 { return 2048; };
    return 0;
}

fn check_stringify_round_trip() -> i64 {
    let parsed: Vec<i32> = json_parse("42");
    let s: str = json_stringify(parsed);
    if str_eq(s, "42") != 1 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_type_tags();
    fails = fails + check_parse_number();
    fails = fails + check_parse_array();
    fails = fails + check_stringify_round_trip();
    return fails;
}
