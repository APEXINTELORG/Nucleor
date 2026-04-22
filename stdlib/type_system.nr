// Nucleor stdlib: type_system
// Full type representation for bootstrap type checker.
// Models the complete Nucleor type hierarchy.

// Type kind tags (comprehensive)
const TK_I32: i32 = 0;
const TK_I64: i32 = 1;
const TK_U32: i32 = 2;
const TK_U64: i32 = 3;
const TK_F64: i32 = 4;
const TK_BOOL: i32 = 5;
const TK_STR: i32 = 6;
const TK_VOID: i32 = 7;
const TK_STRUCT: i32 = 10;
const TK_ENUM: i32 = 11;
const TK_ARRAY: i32 = 12;
const TK_TUPLE: i32 = 13;
const TK_VEC: i32 = 14;
const TK_OPTION: i32 = 15;
const TK_RESULT: i32 = 16;
const TK_REF: i32 = 17;
const TK_MUT_REF: i32 = 18;
const TK_BOX: i32 = 19;
const TK_TENSOR: i32 = 20;
const TK_STRING: i32 = 21;
const TK_FN_PTR: i32 = 22;
const TK_INTN: i32 = 23;
const TK_FIXED: i32 = 24;
const TK_UNIT: i32 = 25;
const TK_TAINTED: i32 = 26;
const TK_CHANNEL: i32 = 27;
const TK_ARENA: i32 = 30;
const TK_RINGBUF: i32 = 31;
const TK_HASHMAP: i32 = 32;
const TK_DATASET: i32 = 33;
const TK_ARENAVEC: i32 = 34;
const TK_KVCACHE: i32 = 35;
const TK_DEVICE_BUF: i32 = 36;

fn is_primitive(tk: i32) -> bool {
    tk >= TK_I32 && tk <= TK_VOID
}

fn is_integer(tk: i32) -> bool {
    tk == TK_I32 || tk == TK_I64 || tk == TK_U32 || tk == TK_U64 || tk == TK_INTN
}

fn is_numeric(tk: i32) -> bool {
    is_integer(tk) || tk == TK_F64 || tk == TK_FIXED
}

fn is_copy(tk: i32) -> bool {
    is_primitive(tk) || tk == TK_REF || tk == TK_INTN || tk == TK_FIXED || tk == TK_UNIT
}

fn is_resource(tk: i32) -> bool {
    tk >= TK_ARENA && tk <= TK_DEVICE_BUF
}

fn is_generic_container(tk: i32) -> bool {
    tk == TK_VEC || tk == TK_OPTION || tk == TK_RESULT || tk == TK_TENSOR || tk == TK_BOX
}

fn is_reference(tk: i32) -> bool {
    tk == TK_REF || tk == TK_MUT_REF
}

// Send/Share trait derivation
fn is_send(tk: i32) -> bool {
    if is_primitive(tk) { true }
    else if is_resource(tk) { false }
    else if tk == TK_FN_PTR { false }
    else { true }
}

fn is_share(tk: i32) -> bool {
    if is_primitive(tk) { true }
    else if tk == TK_MUT_REF { false }
    else if is_resource(tk) { false }
    else if tk == TK_FN_PTR { false }
    else { true }
}

fn main() -> i32 {
    // Primitive checks
    print_bool(is_primitive(TK_I32));
    print_bool(is_primitive(TK_STRUCT));
    print_bool(is_integer(TK_U64));
    print_bool(is_numeric(TK_F64));
    print_bool(is_numeric(TK_BOOL));

    // Copy semantics
    print_bool(is_copy(TK_STR));
    print_bool(is_copy(TK_VEC));

    // Resource types
    print_bool(is_resource(TK_ARENA));
    print_bool(is_resource(TK_I32));

    // Send/Share
    print_bool(is_send(TK_I32));
    print_bool(is_send(TK_ARENA));
    print_bool(is_share(TK_REF));
    print_bool(is_share(TK_MUT_REF));
    0
}
