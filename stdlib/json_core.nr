// Nucleor stdlib: json_core
// Minimal JSON generation for bootstrap compiler output.
// The compiler needs JSON for --output json mode, stage dumps, and bootstrap status.
// This models JSON value construction without actual string building (which needs String type).

// JSON value kinds
const JSON_NULL: i32 = 0;
const JSON_BOOL: i32 = 1;
const JSON_INT: i32 = 2;
const JSON_FLOAT: i32 = 3;
const JSON_STRING: i32 = 4;
const JSON_ARRAY: i32 = 5;
const JSON_OBJECT: i32 = 6;

struct JsonValue {
    kind: i32,
    int_val: i64,
    bool_val: bool,
}

fn json_null() -> JsonValue {
    JsonValue { kind: JSON_NULL, int_val: 0, bool_val: false }
}

fn json_bool(v: bool) -> JsonValue {
    JsonValue { kind: JSON_BOOL, int_val: 0, bool_val: v }
}

fn json_int(v: i64) -> JsonValue {
    JsonValue { kind: JSON_INT, int_val: v, bool_val: false }
}

fn is_null(v: JsonValue) -> bool {
    v.kind == JSON_NULL
}

fn is_truthy(v: JsonValue) -> bool {
    if v.kind == JSON_NULL { false }
    else if v.kind == JSON_BOOL { v.bool_val }
    else if v.kind == JSON_INT { v.int_val != 0 }
    else { true }
}

// JSON key-value pair for object construction
struct JsonField {
    key_hash: i64,
    value_kind: i32,
    value_int: i64,
}

fn json_field_int(key_hash: i64, value: i64) -> JsonField {
    JsonField { key_hash: key_hash, value_kind: JSON_INT, value_int: value }
}

fn json_field_bool(key_hash: i64, value: bool) -> JsonField {
    let v: i64 = if value { 1 } else { 0 };
    JsonField { key_hash: key_hash, value_kind: JSON_BOOL, value_int: v }
}

fn main() -> i32 {
    let n: JsonValue = json_null();
    let b: JsonValue = json_bool(true);
    let i: JsonValue = json_int(42);

    print_bool(is_null(n));
    print_bool(is_truthy(b));
    print_bool(is_truthy(i));

    let f: JsonField = json_field_int(100, 42);
    print_int(f.value_int);
    print_int(f.value_kind);
    0
}
