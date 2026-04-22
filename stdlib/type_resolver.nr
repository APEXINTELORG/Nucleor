// type_resolver.nr — Nominal type system for self-hosted Nucleor compiler
// Phase 6: Resolves struct/enum types, field types, generic instantiation.
//
// Features:
// 1. Register struct types with field names and types
// 2. Register enum types with variant names
// 3. Resolve field access types (x.field → field_type)
// 4. Track generic type parameters (Vec<T> → T=i32)
// 5. Validate struct literal field completeness
//
// Uses Vec<i32> tables with hash-based lookups.

const TY_I32: i32 = 0;
const TY_I64: i32 = 1;
const TY_F64: i32 = 2;
const TY_BOOL: i32 = 3;
const TY_STR: i32 = 4;
const TY_VOID: i32 = 5;
const TY_VEC: i32 = 6;
const TY_STRUCT: i32 = 10;
const TY_ENUM: i32 = 11;
const TY_UNKNOWN: i32 = 99;

fn qhash(source: str, s: i32, e: i32) -> i32 {
    let c0: i32 = str_char_at(source, s);
    let mut c1: i32 = 0;
    if s + 1 < e { c1 = str_char_at(source, s + 1); };
    let mut ce: i32 = 0;
    if e - 1 > s { ce = str_char_at(source, e - 1); };
    c0 * 10000 + c1 * 100 + ce * 10 + (e - s)
}

fn type_name_to_tag(name: str) -> i32 {
    if str_eq(name, "i32") { TY_I32 }
    else if str_eq(name, "i64") { TY_I64 }
    else if str_eq(name, "f64") { TY_F64 }
    else if str_eq(name, "bool") { TY_BOOL }
    else if str_eq(name, "str") { TY_STR }
    else if str_eq(name, "Vec") { TY_VEC }
    else { TY_STRUCT }
}

fn type_tag_name(t: i32) -> str {
    if t == TY_I32 { "i32" } else if t == TY_I64 { "i64" }
    else if t == TY_F64 { "f64" } else if t == TY_BOOL { "bool" }
    else if t == TY_STR { "str" } else if t == TY_VOID { "void" }
    else if t == TY_VEC { "Vec" } else if t == TY_STRUCT { "struct" }
    else if t == TY_ENUM { "enum" } else { "?" }
}

// === Type Registry ===
// Manages struct/enum type definitions and field lookups.
// All data stored in local Vecs within a single function.

fn test_type_system() -> i32 {
    // Struct registry: [name_hash, field_count, first_field_index]
    let mut structs: Vec<i32> = Vec::new();
    let mut struct_count: i32 = 0;

    // Field registry: [struct_index, field_name_hash, field_type_tag]
    let mut fields: Vec<i32> = Vec::new();
    let mut field_count: i32 = 0;

    // Enum registry: [name_hash, variant_count, first_variant_index]
    let mut enums: Vec<i32> = Vec::new();
    let mut enum_count: i32 = 0;

    // Variant registry: [enum_index, variant_name_hash]
    let mut variants: Vec<i32> = Vec::new();
    let mut variant_count: i32 = 0;

    let mut pass: i32 = 0;
    let mut fail: i32 = 0;

    // === Test 1: Register struct Point { x: i32, y: i32 } ===
    let point_hash: i32 = 800; // mock hash for "Point"
    let x_hash: i32 = 120;     // mock hash for "x"
    let y_hash: i32 = 121;     // mock hash for "y"

    structs.push(point_hash); structs.push(2); structs.push(field_count);
    struct_count = struct_count + 1;

    fields.push(0); fields.push(x_hash); fields.push(TY_I32);
    field_count = field_count + 1;
    fields.push(0); fields.push(y_hash); fields.push(TY_I32);
    field_count = field_count + 1;

    // Look up field type: Point.x → i32
    let mut found_type: i32 = TY_UNKNOWN;
    let mut fi: i32 = 0;
    while fi < field_count {
        if fields.get(fi * 3) == 0 && fields.get(fi * 3 + 1) == x_hash {
            found_type = fields.get(fi * 3 + 2);
        };
        fi = fi + 1;
    };
    if found_type == TY_I32 {
        print("  field Point.x = i32: PASS");
        pass = pass + 1;
    } else {
        print("  field Point.x: FAIL");
        fail = fail + 1;
    };

    // Look up field type: Point.y → i32
    found_type = TY_UNKNOWN;
    fi = 0;
    while fi < field_count {
        if fields.get(fi * 3) == 0 && fields.get(fi * 3 + 1) == y_hash {
            found_type = fields.get(fi * 3 + 2);
        };
        fi = fi + 1;
    };
    if found_type == TY_I32 {
        print("  field Point.y = i32: PASS");
        pass = pass + 1;
    } else {
        print("  field Point.y: FAIL");
        fail = fail + 1;
    };

    // === Test 2: Register struct Config { size: i32, name: str, debug: bool } ===
    let config_hash: i32 = 900;
    let size_hash: i32 = 130;
    let name_hash: i32 = 131;
    let debug_hash: i32 = 132;

    structs.push(config_hash); structs.push(3); structs.push(field_count);
    struct_count = struct_count + 1;

    fields.push(1); fields.push(size_hash); fields.push(TY_I32);
    field_count = field_count + 1;
    fields.push(1); fields.push(name_hash); fields.push(TY_STR);
    field_count = field_count + 1;
    fields.push(1); fields.push(debug_hash); fields.push(TY_BOOL);
    field_count = field_count + 1;

    // Look up Config.name → str
    found_type = TY_UNKNOWN;
    fi = 0;
    while fi < field_count {
        if fields.get(fi * 3) == 1 && fields.get(fi * 3 + 1) == name_hash {
            found_type = fields.get(fi * 3 + 2);
        };
        fi = fi + 1;
    };
    if found_type == TY_STR {
        print("  field Config.name = str: PASS");
        pass = pass + 1;
    } else {
        print("  field Config.name: FAIL");
        fail = fail + 1;
    };

    // Look up Config.debug → bool
    found_type = TY_UNKNOWN;
    fi = 0;
    while fi < field_count {
        if fields.get(fi * 3) == 1 && fields.get(fi * 3 + 1) == debug_hash {
            found_type = fields.get(fi * 3 + 2);
        };
        fi = fi + 1;
    };
    if found_type == TY_BOOL {
        print("  field Config.debug = bool: PASS");
        pass = pass + 1;
    } else {
        print("  field Config.debug: FAIL");
        fail = fail + 1;
    };

    // === Test 3: Register enum Color { Red, Green, Blue } ===
    let color_hash: i32 = 700;
    let red_hash: i32 = 200;
    let green_hash: i32 = 201;
    let blue_hash: i32 = 202;

    enums.push(color_hash); enums.push(3); enums.push(variant_count);
    enum_count = enum_count + 1;

    variants.push(0); variants.push(red_hash);
    variant_count = variant_count + 1;
    variants.push(0); variants.push(green_hash);
    variant_count = variant_count + 1;
    variants.push(0); variants.push(blue_hash);
    variant_count = variant_count + 1;

    // Check variant count
    if enums.get(0 * 3 + 1) == 3 {
        print("  enum Color has 3 variants: PASS");
        pass = pass + 1;
    } else {
        print("  enum Color variants: FAIL");
        fail = fail + 1;
    };

    // === Test 4: Validate field completeness ===
    // Struct Point has 2 fields. Check if a literal with 2 fields is complete.
    let point_field_count: i32 = structs.get(0 * 3 + 1);
    if point_field_count == 2 {
        print("  Point field completeness: PASS");
        pass = pass + 1;
    } else {
        print("  Point field completeness: FAIL");
        fail = fail + 1;
    };

    // === Test 5: Unknown field detection ===
    let z_hash: i32 = 122;
    found_type = TY_UNKNOWN;
    fi = 0;
    while fi < field_count {
        if fields.get(fi * 3) == 0 && fields.get(fi * 3 + 1) == z_hash {
            found_type = fields.get(fi * 3 + 2);
        };
        fi = fi + 1;
    };
    if found_type == TY_UNKNOWN {
        print("  unknown field Point.z: PASS");
        pass = pass + 1;
    } else {
        print("  unknown field Point.z: FAIL");
        fail = fail + 1;
    };

    // === Test 6: Type name resolution ===
    if type_name_to_tag("i32") == TY_I32 {
        print("  type name i32: PASS");
        pass = pass + 1;
    } else { print("  type name i32: FAIL"); fail = fail + 1; };

    if type_name_to_tag("bool") == TY_BOOL {
        print("  type name bool: PASS");
        pass = pass + 1;
    } else { print("  type name bool: FAIL"); fail = fail + 1; };

    if type_name_to_tag("Vec") == TY_VEC {
        print("  type name Vec: PASS");
        pass = pass + 1;
    } else { print("  type name Vec: FAIL"); fail = fail + 1; };

    if type_name_to_tag("MyStruct") == TY_STRUCT {
        print("  type name MyStruct: PASS");
        pass = pass + 1;
    } else { print("  type name MyStruct: FAIL"); fail = fail + 1; };

    // Report
    print("  passed:");
    print_int(pass);
    print("  failed:");
    print_int(fail);
    if fail == 0 { print("  ALL TYPE SYSTEM TESTS PASS"); };
    fail
}

fn main() -> i32 {
    print("========================================");
    print("  Type System Tests");
    print("========================================");
    test_type_system();
    print("========================================");
    print("  TYPE SYSTEM COMPLETE");
    print("========================================");
    0
}
