// 04_rods.nr — Using stdlib rods (string utilities + JSON).
// Build: nuc build examples/04_rods.nr -o rods_demo
// Run:   ./rods_demo.exe

use std::strings;
use std::json;

fn main() -> i64 {
    // String utilities from stdlib/rods/strings.nr
    let greeting: str = "Hello, Nucleor!";
    if strings_contains(greeting, "Nucleor") == 1 {
        print("found 'Nucleor' in the greeting");
    };
    if strings_starts_with(greeting, "Hello") == 1 {
        print("starts with 'Hello'");
    };

    // JSON construction and stringify from stdlib/rods/json.nr
    let obj: i64 = json_object_new();
    json_object_set(obj, "language", json_from_string("Nucleor"));
    json_object_set(obj, "version", json_from_int(1));
    json_object_set(obj, "self_hosted", json_from_bool(1));
    print(str_concat("json: ", json_stringify(obj)));

    return 0;
}
