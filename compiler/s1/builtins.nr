// =====================================================
// BUILTIN MAPPING (NEW in T30)
// =====================================================
// get_rt_name fn lives in compiler/s1/get_rt_name.gen.nr — auto-generated
// from compiler/s1/get_rt_name.tsv by tools/gen_rt_name_fn.nr. Edit the
// TSV (not the .gen.nr) to add/remove builtin → runtime symbol entries;
// re-run the generator and commit both files. Drift between TSV and
// .gen.nr is enforced by tools/check_rt_name_table.sh in verify.sh.
import "s1/get_rt_name.gen.nr"
#[manual_drop]
fn is_void_ret(name: str) -> i64 {
    if str_eq(name, "print") { return 1; };
    if str_eq(name, "str_free") { return 1; };
    if str_eq(name, "str_arena_free") { return 1; };
    if str_eq(name, "print_raw") { return 1; };
    if str_eq(name, "eprint_raw") { return 1; };
    if str_eq(name, "file_write_string") { return 1; };
    if str_eq(name, "sb_append") { return 1; };
    if str_eq(name, "sb_append_char") { return 1; };
    if str_eq(name, "sb_append_char_at") { return 1; };
    if str_eq(name, "sb_append_range") { return 1; };
    if str_eq(name, "sb_new_with_cap") { return 0; };
    if str_eq(name, "vec_push") { return 1; };
    if str_eq(name, "vec_pop") { return 1; };
    if str_eq(name, "vec_free") { return 1; };
    if str_eq(name, "vec_set") { return 1; };
    if str_eq(name, "vec_swap") { return 1; };
    if str_eq(name, "vec_extend") { return 1; };
    if str_eq(name, "vec_remove_at") { return 1; };
    if str_eq(name, "vec_insert_at") { return 1; };
    // Option/Result helpers all return i64 — NOT in is_void_ret.
    // (Their existence-table entries are below in the runtime-helper-
    // exists fn around line 4196; this table is for void-returning fns.)
    if str_eq(name, "vec_shuffle") { return 1; };
    if str_eq(name, "random_fill") { return 1; };
    if str_eq(name, "print_bool") { return 1; };
    if str_eq(name, "print_f64") { return 1; };
    if str_eq(name, "__nucleor_tensor_set") { return 1; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "sb_free") { return 1; };
    if str_eq(name, "pipe_write") { return 1; };
    if str_eq(name, "pipe_close") { return 1; };
    if str_eq(name, "thread_join") { return 1; };
    if str_eq(name, "mutex_unlock") { return 1; };
    if str_eq(name, "channel_send") { return 1; };
    if str_eq(name, "chan_send") { return 1; };
    if str_eq(name, "cancel_token_cancel") { return 1; };
    if str_eq(name, "rwlock_unlock") { return 1; };
    if str_eq(name, "vec_shuffle") { return 1; };
    if str_eq(name, "random_fill") { return 1; };
    return 0;
}
#[manual_drop]
fn is_ptr_ret(name: str) -> i64 {
    // vec_chain_i64 returns NVec*.
    if str_eq(name, "vec_chain_i64") { return 1; };
    // vec_step_by_i64 returns NVec* (new vec).
    if str_eq(name, "vec_step_by_i64") { return 1; };
    // Option/Result helpers that return NVec* (ptr).
    if str_eq(name, "option_map") { return 1; };
    if str_eq(name, "option_and_then") { return 1; };
    if str_eq(name, "result_map") { return 1; };
    if str_eq(name, "result_and_then") { return 1; };
    if str_eq(name, "result_or_else") { return 1; };
    if str_eq(name, "str_concat") { return 1; };
    if str_eq(name, "str_intern") { return 1; };
    if str_eq(name, "str_arena_concat") { return 1; };
    if str_eq(name, "str_arena_substring") { return 1; };
    if str_eq(name, "str_substring") { return 1; };
    if str_eq(name, "file_read_string") { return 1; };
    if str_eq(name, "file_read_string_or_panic") { return 1; };
    if str_eq(name, "sb_to_str") { return 1; };
    if str_eq(name, "vec_new") { return 1; };
    if str_eq(name, "vec_with_capacity") { return 1; };
    if str_eq(name, "args_get") { return 1; };
    if str_eq(name, "read_line") { return 1; };
    if str_eq(name, "format_i64") { return 1; };
    if str_eq(name, "int_to_str") { return 1; };
    // recursive Debug formatters return ptr (heap str).
    if str_eq(name, "vec_to_debug_str_i64") { return 1; };
    if str_eq(name, "vec_to_debug_str_str") { return 1; };
    if str_eq(name, "vec_to_debug_str_option_i64") { return 1; };
    if str_eq(name, "option_to_debug_str_i64") { return 1; };
    if str_eq(name, "result_to_debug_str_i64") { return 1; };
    if str_eq(name, "str_from_int") { return 1; };
    if str_eq(name, "f64_to_str") { return 1; };
    if str_eq(name, "f32_to_str") { return 1; };
    if str_eq(name, "f64_to_str_prec") { return 1; };
    if str_eq(name, "f32_to_str_prec") { return 1; };
    if str_eq(name, "f16_to_str") { return 1; };
    if str_eq(name, "bf16_to_str") { return 1; };
    if str_eq(name, "f8e4m3_to_str") { return 1; };
    if str_eq(name, "f8e5m2_to_str") { return 1; };
    if str_eq(name, "bool_to_str") { return 1; };
    if str_eq(name, "int_to_hex") { return 1; };
    if str_eq(name, "int_to_bin") { return 1; };
    if str_eq(name, "int_to_oct") { return 1; };
    // v0.4.30 force-sign helper returns ptr (str)
    if str_eq(name, "int_to_str_force_sign") { return 1; };
    if str_eq(name, "int_to_hex_upper") { return 1; };
    if str_eq(name, "f64_to_str_sci") { return 1; };
    if str_eq(name, "f64_to_str_sci_upper") { return 1; };
    if str_eq(name, "f64_to_str_sci_prec") { return 1; };
    if str_eq(name, "f64_to_str_sci_prec_upper") { return 1; };
    if str_eq(name, "str_pad_left") { return 1; };
    if str_eq(name, "str_pad_right") { return 1; };
    if str_eq(name, "str_center") { return 1; };
    if str_eq(name, "str_join") { return 1; };
    if str_eq(name, "str_lines") { return 1; };
    if str_eq(name, "str_chars") { return 1; };
    if str_eq(name, "format_str") { return 1; };
    if str_eq(name, "format_hex") { return 1; };
    if str_eq(name, "format2_ii") { return 1; };
    if str_eq(name, "format2_si") { return 1; };
    if str_eq(name, "format2_ss") { return 1; };
    if str_eq(name, "format2_is") { return 1; };
    if str_eq(name, "format2_ff") { return 1; };
    if str_eq(name, "format2_fi") { return 1; };
    if str_eq(name, "format2_if") { return 1; };
    if str_eq(name, "format3_fff") { return 1; };
    if str_eq(name, "format_f64") { return 1; };
    if str_eq(name, "format_bool") { return 1; };
    if str_eq(name, "format3_iii") { return 1; };
    if str_eq(name, "format3_sii") { return 1; };
    if str_eq(name, "format3_iss") { return 1; };
    if str_eq(name, "format3_sss") { return 1; };
    if str_eq(name, "format3_ssi") { return 1; };
    if str_eq(name, "format3_sis") { return 1; };
    if str_eq(name, "format3_iis") { return 1; };
    if str_eq(name, "format3_isi") { return 1; };
    if str_eq(name, "format3_iif") { return 1; };
    if str_eq(name, "format3_iff") { return 1; };
    if str_eq(name, "format3_sff") { return 1; };
    if str_eq(name, "format3_ssf") { return 1; };
    if str_eq(name, "format3_sif") { return 1; };
    if str_eq(name, "format3_isf") { return 1; };
    if str_eq(name, "dyn_box_make") { return 1; };
    if str_eq(name, "dyn_box_type") { return 1; };
    if str_eq(name, "dyn_box_data") { return 1; };
    if str_eq(name, "dyn_box_free") { return 1; };
    if str_eq(name, "vec_iter_i64") { return 1; };
    if str_eq(name, "vec_collect_i64") { return 1; };
    if str_eq(name, "vec_count_i64") { return 0; };
    if str_eq(name, "vec_take_i64") { return 1; };
    if str_eq(name, "vec_chain_i64") { return 1; };
    // extended iter — only step_by returns ptr; rest are i64.
    if str_eq(name, "vec_step_by_i64") { return 1; };
    if str_eq(name, "vec_position_i64") { return 0; };
    if str_eq(name, "vec_product_i64") { return 0; };
    if str_eq(name, "vec_nth_i64") { return 0; };
    if str_eq(name, "vec_reduce_i64") { return 0; };
    if str_eq(name, "vec_skip_i64") { return 1; };
    if str_eq(name, "vec_map_i64") { return 1; };
    if str_eq(name, "vec_filter_i64") { return 1; };
    if str_eq(name, "vec_reverse_i64") { return 1; };
    if str_eq(name, "vec_sort_i64") { return 1; };
    if str_eq(name, "vec_clone_i64") { return 1; };
    if str_eq(name, "str_to_lower") { return 1; };
    if str_eq(name, "str_to_upper") { return 1; };
    if str_eq(name, "str_trim") { return 1; };
    if str_eq(name, "str_trim_start") { return 1; };
    if str_eq(name, "str_trim_end") { return 1; };
    if str_eq(name, "str_replace") { return 1; };
    if str_eq(name, "str_repeat") { return 1; };
    if str_eq(name, "str_split") { return 1; };
    if str_eq(name, "str_reverse") { return 1; };
    if str_eq(name, "env_keys") { return 1; };
    if str_eq(name, "sha256") { return 1; };
    if str_eq(name, "py_eval") { return 1; };
    if str_eq(name, "chr") { return 1; };
    if str_eq(name, "getcwd") { return 1; };
    if str_eq(name, "getenv") { return 1; };
    if str_eq(name, "fs_join") { return 1; };
    if str_eq(name, "fs_basename") { return 1; };
    if str_eq(name, "fs_dirname") { return 1; };
    if str_eq(name, "fs_extension") { return 1; };
    if str_eq(name, "fs_temp_dir") { return 1; };
    if str_eq(name, "fs_current_dir") { return 1; };
    if str_eq(name, "fs_canonicalize") { return 1; };
    if str_eq(name, "path_separator") { return 1; };
    if str_eq(name, "path_normalize") { return 1; };
    if str_eq(name, "path_with_extension") { return 1; };
    if str_eq(name, "path_strip_extension") { return 1; };
    if str_eq(name, "path_components") { return 1; };
    if str_eq(name, "manifest_report") { return 1; };
    if str_eq(name, "sha256_hex") { return 1; };
    if str_eq(name, "base64_encode") { return 1; };
    if str_eq(name, "base64_decode") { return 1; };
    if str_eq(name, "uuid_v4") { return 1; };
    if str_eq(name, "hashmap_keys") { return 1; };
    if str_eq(name, "hashmap_values") { return 1; };
    if str_eq(name, "time_iso_now") { return 1; };
    if str_eq(name, "time_format_iso") { return 1; };
    return 0;
}
#[manual_drop]
fn is_ptr_arg(name: str, idx: i64) -> i64 {
    if str_eq(name, "print") { return 1; };
    if str_eq(name, "print_raw") { return 1; };
    if str_eq(name, "eprint_raw") { return 1; };
    if str_eq(name, "panic") { return 1; };
    if str_eq(name, "dbg_str") { return 1; };
    if str_eq(name, "eprint") { return 1; };
    if str_eq(name, "fnv1a_64_str") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "string_from_str") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "string_push_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_eq_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_starts_with") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_ends_with") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_contains") { if idx == 1 { return 1; }; return 0; };
    // extended String surface — find takes a needle ptr at idx 1.
    if str_eq(name, "string_find") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_get") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_get_or") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "env_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get_or") { return 1; };
    if str_eq(name, "env_set") { return 1; };
    if str_eq(name, "env_unset") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "hashset_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashset_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashset_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_get") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreeset_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreeset_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreeset_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "fs_exists") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_is_file") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_is_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_size") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_mtime") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_create_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_create_dir_all") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_remove_file") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_rename") { return 1; };
    if str_eq(name, "fs_list_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_join") { return 1; };
    if str_eq(name, "fs_basename") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_dirname") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_extension") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_remove_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_copy_file") { return 1; };
    if str_eq(name, "fs_canonicalize") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_is_absolute") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_normalize") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_with_extension") { return 1; };
    if str_eq(name, "path_strip_extension") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_components") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "toml_parse_string") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "toml_parse_file") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "toml_get_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "toml_get_int") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "toml_has") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "msgpack_write_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "crc32") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "crc32_update") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sha256_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "base64_encode") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "base64_decode") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_len") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_eq") { return 1; };
    if str_eq(name, "str_char_at") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_char_at_strict") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_substring") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_concat") { return 1; };
    if str_eq(name, "str_intern") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_free") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_arena_concat") { if idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "str_arena_substring") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "file_read_string") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_read_string_or_panic") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_write_string") { return 1; };
    if str_eq(name, "file_bytes_equal") { return 1; };
    if str_eq(name, "system") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "sb_append") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sb_append_char") { return 0; };
    if str_eq(name, "sb_append_char_at") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sb_append_range") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sb_new_with_cap") { return 0; };
    if str_eq(name, "vec_push") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_len") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_pop") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_free") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_set") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_first") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_last") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_is_empty") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_swap") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_extend") { return 1; };
    if str_eq(name, "vec_remove_at") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_insert_at") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "random_choice") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_shuffle") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sample") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "random_fill") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_mean_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_median_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_variance_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_stddev_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_range_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_percentile_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "pipe_create") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "pipe_write") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sha256") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "profile_start") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "profile_end") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "py_eval") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "getenv") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get_or") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "env_unset") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_int") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_int_strict") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_bool") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_i64_radix") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "parse_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "parse_bin") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_pad_left") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_pad_right") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_center") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_join") { return 1; };
    if str_eq(name, "str_lines") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_chars") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_str") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_ii") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_si") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format2_ss") { if idx == 0 || idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format2_is") { if idx == 0 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format2_ff") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_fi") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_if") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_fff") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_iter_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_collect_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_count_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_take_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_chain_i64") { if idx == 0 { return 1; }; if idx == 1 { return 1; }; return 0; };
    // extended iter — Vec arg is at idx 0 for all five.
    if str_eq(name, "vec_position_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_product_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_step_by_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_nth_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_reduce_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_skip_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_map_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_filter_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_fold_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_each_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sum_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_min_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_max_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_contains_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_index_of_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_reverse_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sort_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_clone_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_clear_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sum_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_min_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_max_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_lower") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_upper") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_trim") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_trim_start") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_trim_end") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_is_empty") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_count") { return 1; };
    if str_eq(name, "str_reverse") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_starts_with") { return 1; };
    if str_eq(name, "str_ends_with") { return 1; };
    if str_eq(name, "str_index_of") { return 1; };
    if str_eq(name, "str_contains") { return 1; };
    if str_eq(name, "str_replace") { return 1; };
    if str_eq(name, "str_repeat") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_split") { return 1; };
    if str_eq(name, "env_has") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_bool") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_iii") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_sii") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format3_iss") { if idx == 0 || idx == 2 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_sss") { if idx == 0 || idx == 1 || idx == 2 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_ssi") { if idx == 0 || idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format3_sis") { if idx == 0 || idx == 1 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_iis") { if idx == 0 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_isi") { if idx == 0 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format3_iif") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_iff") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_sff") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format3_ssf") { if idx == 0 || idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format3_sif") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format3_isf") { if idx == 0 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "vec_avg_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_dot_i64") { return 1; };
    if str_eq(name, "vec_count_eq_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_any_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_all_i64") { if idx == 0 { return 1; }; return 0; };
    return 0;
}

#[manual_drop]
fn emit_builtin_call(sb: i64, name: str, rn: str, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let ds: str = str_from_int(d);
    // inline str_char_at as GEP+load to eliminate the
    // function-call overhead. Cold self-host compile makes 1.6 BILLION
    // str_char_at calls; each runtime call adds ~3-5ns of linkage on top
    // of the actual byte load. Inlining drops to 4 IR instructions = ~1ns
    // each. Net: cold self-host 8.33s -> 4.82s (-42%, sub-5s achieved).
    // Trade-off: NULL str now segfaults instead of returning 0. Compiler
    // internal callers all source `s` from non-null strings; adopters who
    // rely on the null-returns-0 behavior should null-check before calling.
    if str_eq(name, "str_char_at") == 1 && argc == 2 {
        let s_reg: str = str_from_int(vec_get(args, 0));
        let i_reg: str = str_from_int(vec_get(args, 1));
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".sca.ptr = inttoptr i64 %r.");
        sb_append(sb, s_reg); sb_append(sb, " to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".sca.gep = getelementptr i8, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".sca.ptr, i64 %r."); sb_append(sb, i_reg); sb_append(sb, "\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".sca.byte = load i8, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".sca.gep\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = zext i8 %r.");
        sb_append(sb, ds); sb_append(sb, ".sca.byte to i64\n");
        return 0;
    };
    // Step 1: inttoptr for ptr args
    let mut ai: i64 = 0;
    while ai < argc {
        if is_ptr_arg(name, ai) == 1 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
            sb_append(sb, " = inttoptr i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to ptr\n");
        };
        ai = ai + 1;
    };
    // Step 2: emit call with correct return type
    let vr: i64 = is_void_ret(name);
    let pret: i64 = is_ptr_ret(name);
    if vr == 1 {
        sb_append(sb, "  call void @"); sb_append(sb, rn); sb_append(sb, "(");
    } else if pret == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".rv = call ptr @"); sb_append(sb, rn); sb_append(sb, "(");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = call i64 @"); sb_append(sb, rn); sb_append(sb, "(");
    };
    // Step 3: emit args with correct types
    ai = 0;
    while ai < argc {
        if ai > 0 { sb_append(sb, ", "); };
        if is_ptr_arg(name, ai) == 1 {
            sb_append(sb, "ptr %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
        } else {
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
        };
        ai = ai + 1;
    };
    sb_append(sb, ")\n");
    // Step 4: handle return conversion
    if vr == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    } else if pret == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    };
    return 0;
}

