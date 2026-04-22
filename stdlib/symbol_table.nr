// Nucleor stdlib: symbol_table
// Symbol table for the bootstrap type checker.
// Uses a flat Vec of entries with linear lookup (good enough for bootstrap).

// Symbol kinds
const SYM_VAR: i32 = 0;
const SYM_FN: i32 = 1;
const SYM_STRUCT: i32 = 2;
const SYM_ENUM: i32 = 3;
const SYM_CONST: i32 = 4;
const SYM_TYPE: i32 = 5;
const SYM_TRAIT: i32 = 6;

// Type tags (simplified for bootstrap)
const TY_I32: i32 = 0;
const TY_I64: i32 = 1;
const TY_F64: i32 = 2;
const TY_BOOL: i32 = 3;
const TY_STR: i32 = 4;
const TY_VOID: i32 = 5;
const TY_STRUCT: i32 = 10;
const TY_ENUM: i32 = 11;
const TY_VEC: i32 = 12;
const TY_OPTION: i32 = 13;
const TY_RESULT: i32 = 14;
const TY_REF: i32 = 15;
const TY_FN: i32 = 16;

// Symbol entry: name_hash + kind + type_tag + scope_depth
struct SymEntry {
    name_hash: i64,
    kind: i32,
    type_tag: i32,
    scope_depth: i32,
}

// Simple string hash for symbol lookup
fn hash_name(len: i32, c0: i32, c1: i32, c2: i32) -> i64 {
    let mut h: i64 = 0;
    h = h * 31 + c0;
    h = h * 31 + c1;
    h = h * 31 + c2;
    h = h * 31 + len;
    h
}

fn sym_entry(name_hash: i64, kind: i32, type_tag: i32, depth: i32) -> SymEntry {
    SymEntry { name_hash: name_hash, kind: kind, type_tag: type_tag, scope_depth: depth }
}

fn is_type_numeric(tag: i32) -> bool {
    tag == TY_I32 || tag == TY_I64 || tag == TY_F64
}

fn is_type_primitive(tag: i32) -> bool {
    tag >= TY_I32 && tag <= TY_VOID
}

fn main() -> i32 {
    // Test hash
    let h1: i64 = hash_name(3, 102, 111, 111);
    let h2: i64 = hash_name(3, 98, 97, 114);
    print_bool(h1 != h2);

    // Test symbol entries
    let s: SymEntry = sym_entry(h1, SYM_FN, TY_I32, 0);
    print_int(s.kind);
    print_int(s.type_tag);
    print_bool(is_type_numeric(s.type_tag));
    print_bool(is_type_primitive(TY_VOID));
    0
}
