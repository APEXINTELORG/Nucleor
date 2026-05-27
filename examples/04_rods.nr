// 04_rods.nr — Using stdlib rods (string utilities + JSON).
// Build: nuc build examples/04_rods.nr -o rods_demo
// Run:   ./rods_demo.exe

// `use std::*` would be the shorter form, but the use-std-* path has a
// known cfile-collection bug that drops rod-side C files from the clang
// link line. Explicit import composes the correct link set; tracked
// separately as a compiler issue.
import "stdlib/rods/strings.nr"
import "stdlib/rods/json.nr"

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
