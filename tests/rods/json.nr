// json.nr — round-trip JSON construction and serialize
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

    if fail == 0 { print("OK json"); return 0; };
    return 1;
}
