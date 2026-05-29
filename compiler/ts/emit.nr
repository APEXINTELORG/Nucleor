// =====================================================
// LLVM STRING ESCAPING (NEW in T30)
// =====================================================

// =====================================================
// EMISSION (from T29, extended for builtins + strings)
// =====================================================




fn emit_module(fns: Vec<i32>, strtab: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, emit_externs());
    sb_append(sb, emit_str_constants(strtab));
    let mut empty_pool: Vec<i32> = Vec::new();
    let mut empty_ext: Vec<i32> = Vec::new();
    let mut fi: i64 = 0;
    while fi < vec_len(fns) { sb_append(sb, emit_fn(vec_get(fns, fi), empty_pool, empty_ext)); sb_append(sb, "\n"); fi = fi + 1; };
    return sb_to_str(sb);
}
