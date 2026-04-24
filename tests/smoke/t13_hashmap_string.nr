// T1.3 (v0.2.338) smoke: HashMap (string-keyed) + String (heap
// owned mutable UTF-8). Production-ready surfaces both ship via
// existing rods (string_type.nr / hashmap.nr / hashmap_str.nr).
// This fixture is the verify-gate guarantee that they continue
// to round-trip correctly.
import "stdlib/rods/string_type.nr"
import "stdlib/rods/hashmap.nr"
import "stdlib/rods/hashmap_str.nr"

#[test]
fn test_string_make_and_push() {
    let s: i64 = string_make();
    string_concat_str(s, "hello");
    string_concat_str(s, ", world");
    assert_eq(string_length(s), 12);
}

#[test]
fn test_string_from_str() {
    let s: i64 = string_of("nucleor");
    assert_eq(string_length(s), 7);
}

#[test]
fn test_hashmap_insert_get() {
    let m: i64 = map_new();
    map_set(m, "alpha", 1);
    map_set(m, "beta", 2);
    map_set(m, "gamma", 3);
    assert_eq(map_get(m, "alpha"), 1);
    assert_eq(map_get(m, "beta"), 2);
    assert_eq(map_get(m, "gamma"), 3);
    assert_eq(map_len(m), 3);
}

#[test]
fn test_hashmap_overwrite() {
    let m: i64 = map_new();
    map_set(m, "x", 10);
    map_set(m, "x", 99);
    assert_eq(map_get(m, "x"), 99);
    assert_eq(map_len(m), 1);
}

#[test]
fn test_hashmap_has_and_del() {
    let m: i64 = map_new();
    map_set(m, "k", 42);
    assert_eq(map_has(m, "k"), 1);
    assert_eq(map_has(m, "absent"), 0);
    map_del(m, "k");
    assert_eq(map_has(m, "k"), 0);
}

#[test]
fn test_hms_open_addressed() {
    let m: i64 = hms_new();
    hms_insert(m, "one", 1);
    hms_insert(m, "two", 2);
    hms_insert(m, "three", 3);
    assert_eq(hms_get(m, "one"), 1);
    assert_eq(hms_get(m, "two"), 2);
    assert_eq(hms_get(m, "three"), 3);
    assert_eq(hms_contains(m, "missing"), 0);
}

fn main() -> i64 { return 0; }
