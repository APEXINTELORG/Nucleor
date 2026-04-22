// json.nr — round-trip JSON construction, f64 values, and pretty-print
import "stdlib/rods/json.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let obj: i64 = json_object_new();
    json_object_set(obj, "name", json_from_string("Nucleor"));
    json_object_set(obj, "version", json_from_int(1));

    let s: str = json_stringify(obj);
    if str_eq(s, "{\"name\":\"Nucleor\",\"version\":1}") != 1 {
        print(str_concat("FAIL json: stringify mismatch: ", s));
        fail = fail + 1;
    };

    // f64 values
    let half: i64 = f64_div(f64_from_int(1), f64_from_int(2));
    let neg_int: i64 = f64_from_int(0 - 7);
    let mut obj2: i64 = json_object_new();
    json_object_set(obj2, "half", json_from_f64(half));
    json_object_set(obj2, "neg", json_from_f64(neg_int));
    let s2: str = json_stringify(obj2);
    if str_eq(s2, "{\"half\":0.5,\"neg\":-7.0}") != 1 {
        print(str_concat("FAIL json: f64 stringify mismatch: ", s2));
        fail = fail + 1;
    };

    // Pretty-print: nested object with 2-space indent
    let mut nested: i64 = json_object_new();
    let mut arr: i64 = json_array_new();
    json_array_push(arr, json_from_int(1));
    json_array_push(arr, json_from_int(2));
    json_object_set(nested, "xs", arr);
    let pp: str = json_stringify_pretty(nested, 2);
    let want: str = "{\n  \"xs\": [\n    1,\n    2\n  ]\n}";
    if str_eq(pp, want) != 1 {
        print(str_concat("FAIL json: pretty mismatch: ", pp));
        fail = fail + 1;
    };

    if fail == 0 { print("OK json"); return 0; };
    return 1;
}
