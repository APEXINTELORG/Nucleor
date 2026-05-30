// =====================================================
// V2 §1.4: PARALLEL FRONTEND
// =====================================================
// When compiling multi-file projects, files at the same dependency
// level can be lexed and parsed in parallel. The constraint is the
// dependency DAG: a file cannot type-check until the signatures of
// its imports are resolved.
// Within a single file, the pipeline is sequential (lex → parse →
// check → lower → emit) because each stage depends on the previous.
// Parallelism applies across independent files within a level.
// For single-file compilation (most common case), the parallel frontend
// has no effect. The incremental compilation cache (§1.3) provides the
// speed benefit for iterative development.
// Multi-file parallel compilation is enabled automatically when
// the import resolver detects multiple independent imports at the
// same depth level. Each is resolved via thread_spawn + thread_join.
// =====================================================

// =====================================================
// V2 §1.3: INCREMENTAL COMPILATION
// =====================================================
// Cache compiled function IR keyed by source hash.
// On rebuild: re-lex/parse the changed file, extract signatures,
// compare against cache. If no signature changed, only re-codegen
// changed function bodies. If a signature changed, invalidate
// all transitive dependents.
// Cache format: .nuc_cache/<source_hash>.sig  (signature file)
//               .nuc_cache/<fn_hash>.ll       (per-function LLVM IR)
// ALL safety checks (ownership, taint, effect) run on every
// recompiled function. The cache only avoids re-checking
// byte-identical unchanged code.
// =====================================================

#[manual_drop]
fn build_mode_name(strict_mode: i64) -> str {
    if strict_mode == 1 { return "strict"; };
    return "fast";
}

#[manual_drop]
fn print_phase_time(enabled: i64, label: str, elapsed_ms: i64) {
    if enabled == 1 {
        print(str_concat("  time ", str_concat(label, str_concat(": ", str_concat(str_from_int(elapsed_ms), " ms")))));
    };
}

#[manual_drop]
fn cache_v2_json_escape(s: str) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 34 {
            sb_append(sb, "\\\"");
        } else if c == 92 {
            sb_append(sb, "\\\\");
        } else if c == 10 {
            sb_append(sb, "\\n");
        } else if c == 13 {
            sb_append(sb, "\\r");
        } else if c == 9 {
            sb_append(sb, "\\t");
        } else {
            sb_append_char_at(sb, s, i);
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn cache_v2_strict_intrin_flag() -> str {
    let raw: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
    if str_eq(raw, "0") == 1 { return "0"; };
    return "1";
}

// Strict arithmetic cache key:
// `NUCLEOR_INT_STRICT_ARITH=1` flips integer +/-/* lowering between
// the legacy native path and the panic-on-overflow path (verified
// at lines 23322 + 23471). Pre-v0.8.296 the cache key did NOT
// include this env flag — flipping it between builds gave stale
// IR with the previous semantics. This is a real correctness bug:
// adopters who set NUCLEOR_INT_STRICT_ARITH=1 on a previously-
// cached build got the non-strict IR back from cache.
// Fix: parallel `cache_v2_strict_arith_flag()` + entry in
// `cache_v2_canonical_flags()`. Cache key now changes when the
// env flips → cache miss → fresh build with correct semantics.
#[manual_drop]
fn cache_v2_strict_arith_flag() -> str {
    let raw: str = env_get_or("NUCLEOR_INT_STRICT_ARITH", "");
    if str_eq(raw, "1") == 1 { return "1"; };
    return "0";
}

#[manual_drop]
fn cache_v2_dbc_flag() -> str {
    let raw: str = env_get_or("NUCLEOR_DBC_MODE", "debug");
    if str_len(raw) == 0 { return "debug"; };
    return raw;
}

#[manual_drop]
fn cache_v2_canonical_flags(strict_mode: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "dbc-mode=");
    sb_append(sb, cache_v2_dbc_flag());
    sb_append(sb, ";strict-intrin=");
    sb_append(sb, cache_v2_strict_intrin_flag());
    // R10-D4 Phase 1 (v0.8.296): include strict-arith env so cache
    // invalidates when NUCLEOR_INT_STRICT_ARITH flips.
    sb_append(sb, ";strict-arith=");
    sb_append(sb, cache_v2_strict_arith_flag());
    sb_append(sb, ";strict-mode=");
    sb_append(sb, build_mode_name(strict_mode));
    return sb_to_str(sb);
}

#[manual_drop]
fn cache_v2_prefix(key: str) -> str {
    if str_len(key) > 12 { return str_substring(key, 0, 12); };
    return key;
}

#[manual_drop]
fn cache_v2_dir(key: str) -> str {
    return sanitize(str_concat("target/.nuc_cache_v2/", cache_v2_prefix(key)));
}

#[manual_drop]
fn cache_v2_ll_path(key: str) -> str {
    return sanitize(str_concat(cache_v2_dir(key), str_concat("/", str_concat(key, ".ll"))));
}

#[manual_drop]
fn cache_v2_meta_dir(key: str) -> str {
    return sanitize(str_concat(cache_v2_dir(key), str_concat("/", key)));
}

#[manual_drop]
fn cache_v2_meta_path(key: str) -> str {
    return sanitize(str_concat(cache_v2_meta_dir(key), "/meta.json"));
}

#[manual_drop]
fn cache_v2_size_mb(ll: str) -> i64 {
    let n: i64 = str_len(ll);
    if n <= 0 { return 0; };
    return (n + 1048575) / 1048576;
}

#[manual_drop]
fn cache_v2_file_size_mb(path: str) -> i64 {
    let n: i64 = fs_size(path);
    if n <= 0 { return 0; };
    return (n + 1048575) / 1048576;
}

#[manual_drop]
#[manual_drop]
fn rt_o_cache_path(rt_arg: str, alloc_hdr: str, opt_flag: str) -> str {
    if str_eq(env_get_or("NUCLEOR_RT_O_CACHE", "1"), "0") == 1 { return ""; };
    let rt_hash: str = sha256_hex(file_read_string(rt_arg));
    let alloc_hash: str = sha256_hex(file_read_string(alloc_hdr));
    let opt_hash: str = sha256_hex(opt_flag);
    let clang_hash: str = sha256_hex(llvm_clang_path());
    let key: str = str_concat("rt-", str_concat(rt_hash, str_concat("-", str_concat(alloc_hash, str_concat("-", str_concat(opt_hash, str_concat("-", clang_hash)))))));
    return sanitize(str_concat(".nuc_rt_cache/", str_concat(key, host_obj_suffix())));
}

#[manual_drop]
fn host_obj_suffix() -> str {
    if host_is_windows() == 1 { return ".obj"; };
    return ".o";
}

#[manual_drop]
fn native_link_cache_dir(key: str) -> str {
    return sanitize(str_concat("target/.nuc_native_cache/", cache_v2_prefix(key)));
}

#[manual_drop]
fn native_link_cache_path(key: str) -> str {
    return sanitize(str_concat(native_link_cache_dir(key), str_concat("/", str_concat(key, host_exe_suffix()))));
}

#[manual_drop]
fn native_link_cache_allowed(link_flags: str, cfiles: str, libpath_flags: str) -> i64 {
    if str_eq(env_get_or("NUCLEOR_NATIVE_EXE_CACHE", "1"), "0") == 1 { return 0; };
    if str_len(link_flags) > 0 { return 0; };
    if str_len(cfiles) > 0 { return 0; };
    if str_len(libpath_flags) > 0 { return 0; };
    return 1;
}

#[manual_drop]
fn native_link_cache_key(ll: str, rt_arg: str, alloc_hdr: str, stack_flag: str, linker_flag: str) -> str {
    let ll_hash: str = sha256_hex(ll);
    let rt_hash: str = sha256_hex(file_read_string(rt_arg));
    let alloc_hash: str = sha256_hex(file_read_string(alloc_hdr));
    let opt_flag: str = env_get_or("NUCLEOR_LLVM_OPT", "-O0");
    let mut sb: i64 = sb_new();
    sb_append(sb, "native-link-v1|");
    sb_append(sb, compiler_identity());
    sb_append(sb, "|ll=");
    sb_append(sb, ll_hash);
    sb_append(sb, "|rt=");
    sb_append(sb, rt_hash);
    sb_append(sb, "|alloc=");
    sb_append(sb, alloc_hash);
    sb_append(sb, "|stack=");
    sb_append(sb, stack_flag);
    sb_append(sb, "|linker=");
    sb_append(sb, linker_flag);
    sb_append(sb, "|opt=");
    sb_append(sb, opt_flag);
    return sha256_hex(sb_to_str(sb));
}

#[manual_drop]
fn native_link_cache_key_from_compile_key(compile_key: str, rt_arg: str, alloc_hdr: str, stack_flag: str, linker_flag: str) -> str {
    if str_len(compile_key) == 0 { return ""; };
    let rt_hash: str = sha256_hex(file_read_string(rt_arg));
    let alloc_hash: str = sha256_hex(file_read_string(alloc_hdr));
    let opt_flag: str = env_get_or("NUCLEOR_LLVM_OPT", "-O0");
    let mut sb: i64 = sb_new();
    sb_append(sb, "native-link-v2|");
    sb_append(sb, compiler_identity());
    sb_append(sb, "|compile=");
    sb_append(sb, compile_key);
    sb_append(sb, "|rt=");
    sb_append(sb, rt_hash);
    sb_append(sb, "|alloc=");
    sb_append(sb, alloc_hash);
    sb_append(sb, "|stack=");
    sb_append(sb, stack_flag);
    sb_append(sb, "|linker=");
    sb_append(sb, linker_flag);
    sb_append(sb, "|opt=");
    sb_append(sb, opt_flag);
    return sha256_hex(sb_to_str(sb));
}

#[manual_drop]
fn native_link_cache_store(key: str, exe_path: str) -> i64 {
    if str_len(key) == 0 { return 0; };
    if fs_exists(exe_path) == 0 { return 0; };
    fs_create_dir_all(native_link_cache_dir(key));
    return fs_copy_file(exe_path, native_link_cache_path(key));
}

#[manual_drop]
fn cache_v2_stats_enabled() -> i64 {
    if str_eq(env_get_or("NUCLEOR_CACHE_STATS", "0"), "1") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn cache_v2_print_stats(hits: i64, misses: i64) {
    if cache_v2_stats_enabled() == 1 {
        print(str_concat("cache stats: hits=", str_concat(str_from_int(hits), str_concat(" misses=", str_from_int(misses)))));
    };
}

#[manual_drop]
fn cache_v2_meta_json(input_filename: str, flags: str, compiler_version: str, key: str, ll: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\n");
    sb_append(sb, "  \"schema\": \"nuc-cache-v2\",\n");
    sb_append(sb, "  \"input_filename\": \""); sb_append(sb, cache_v2_json_escape(input_filename)); sb_append(sb, "\",\n");
    sb_append(sb, "  \"flags\": \""); sb_append(sb, cache_v2_json_escape(flags)); sb_append(sb, "\",\n");
    sb_append(sb, "  \"compiler_version\": \""); sb_append(sb, cache_v2_json_escape(compiler_version)); sb_append(sb, "\",\n");
    sb_append(sb, "  \"sha256\": \""); sb_append(sb, key); sb_append(sb, "\",\n");
    sb_append(sb, "  \"timestamp\": \""); sb_append(sb, cache_v2_json_escape(time_iso_now())); sb_append(sb, "\",\n");
    sb_append(sb, "  \"ll_bytes\": "); sb_append(sb, str_from_int(str_len(ll))); sb_append(sb, "\n");
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

#[manual_drop]
fn cache_v2_store(key: str, input_filename: str, flags: str, ll: str, ll_artifact_path: str) -> i64 {
    let dir: str = cache_v2_dir(key);
    let meta_dir: str = cache_v2_meta_dir(key);
    fs_create_dir_all(dir);
    fs_create_dir_all(meta_dir);
    let ll_cache_path: str = cache_v2_ll_path(key);
    let copied: i64 = if str_len(ll_artifact_path) > 0 && fs_exists(ll_artifact_path) == 1 {
        fs_copy_file(ll_artifact_path, ll_cache_path)
    } else { 0 };
    if copied == 0 {
        file_write_string(ll_cache_path, ll);
    };
    let meta: str = cache_v2_meta_json(input_filename, flags, compiler_identity(), key, ll);
    file_write_string(cache_v2_meta_path(key), meta);
    file_write_string(sanitize(str_concat(dir, "/meta.json")), meta);
    return 0;
}

#[manual_drop]
fn build_cache_key(source: str, strict_mode: i64) -> str {
    let source_hash: str = sha256_hex(source);
    let mut sb: i64 = sb_new();
    sb_append(sb, "native-cache-v2|");
    sb_append(sb, compiler_identity());
    sb_append(sb, "|");
    sb_append(sb, cache_v2_canonical_flags(strict_mode));
    sb_append(sb, "|");
    sb_append(sb, source_hash);
    return sha256_hex(sb_to_str(sb));
}

#[manual_drop]
fn collect_native_directives(imported: Vec<i32>) -> Vec<i32> {
    let mut all_links: i64 = sb_new();
    let mut all_cfiles: i64 = sb_new();
    let mut all_libpaths: i64 = sb_new();
    let mut di: i64 = 0;
    while di < vec_len(imported) {
        let imp_path: str = vec_get(imported, di);
        let imp_raw: str = file_read_string(imp_path);
        let imp_dir: str = extract_dir(imp_path);
        let imp_d: Vec<i32> = extract_directives(imp_raw, imp_dir);
        sb_append(all_links, vec_get(imp_d, 0));
        sb_append(all_cfiles, vec_get(imp_d, 1));
        sb_append(all_libpaths, vec_get(imp_d, 2));
        di = di + 1;
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(sb_to_str(all_links));
    out.push(sb_to_str(all_cfiles));
    out.push(sb_to_str(all_libpaths));
    return out;
}

#[manual_drop]
fn path_exists(path: str) -> i64 {
    return fs_exists(sanitize(path));
}
#[manual_drop]
fn resolve_toolchain_path(raw_path: str) -> str {
    let from_cwd: str = sanitize(raw_path);
    if path_exists(from_cwd) == 1 { return from_cwd; };
    let env_root_raw: str = env_get_or("NUCLEOR_STDLIB", "");
    let env_root: str = posix_drive_to_windows(env_root_raw);
    if str_len(env_root) > 0 {
        let from_env: str = sanitize(str_concat(env_root, str_concat("/", raw_path)));
        if path_exists(from_env) == 1 { return from_env; };
    };
    if args_count() > 0 {
        let exe_path: str = posix_drive_to_windows(args_get(0));
        let exe_dir: str = extract_dir(exe_path);
        let from_exe_dir: str = sanitize(str_concat(exe_dir, raw_path));
        if path_exists(from_exe_dir) == 1 { return from_exe_dir; };
        let repo_dir: str = parent_dir(exe_dir);
        let from_repo_dir: str = sanitize(str_concat(repo_dir, raw_path));
        if path_exists(from_repo_dir) == 1 { return from_repo_dir; };
    };
    return from_cwd;
}

#[manual_drop]
fn llvm_clang_path() -> str {
    // NUC-FEEDBACK-003 toolchain detection. The launcher
    // scripts SHOULD set up PATH before invoking the compiler, but
    // when users invoke `nucleor.exe` directly (or run from a fresh
    // shell that hasn't sourced the launcher), the bare `clang` PATH
    // lookup fails with the unhelpful Windows error
    // `'clang' is not recognized as an internal or external command`.
    // Probe the canonical install paths in order and return an
    // absolute path when found. Falls back to bare `clang` (PATH
    // lookup) if none match — preserves prior behavior for users
    // with a custom install elsewhere.
    // Resolution order:
    //   1. NUCLEOR_CLANG env override (highest priority — explicit user wish)
    //   2. Windows: C:\Progra~1\LLVM\bin\clang.exe (short path avoids cmd quote overhead)
    //   3. Windows: C:\Program Files\LLVM\bin\clang.exe (default LLVM installer)
    //   4. Windows: C:\msys64\mingw64\bin\clang.exe (MSYS2)
    //   4. macOS: /opt/homebrew/opt/llvm/bin/clang (homebrew)
    //   5. macOS: /usr/local/opt/llvm/bin/clang (older homebrew)
    //   6. Linux: /usr/bin/clang, /usr/local/bin/clang
    //   7. Bare `clang` (PATH fallback)
    let envc: str = env_get_or("NUCLEOR_CLANG", "");
    if str_len(envc) > 0 { return envc; };
    if host_is_windows() == 1 {
        // Windows: probe canonical LLVM install paths. file_read_string
        // returns the binary contents (PE files start with `MZ` so
        // strlen > 0); empty string ⇒ file doesn't exist.
        let p0: str = "C:\\Progra~1\\LLVM\\bin\\clang.exe";
        if path_exists(p0) == 1 { return p0; };
        let p1: str = "C:\\Program Files\\LLVM\\bin\\clang.exe";
        if path_exists(p1) == 1 { return p1; };
        let p2: str = "C:\\msys64\\mingw64\\bin\\clang.exe";
        if path_exists(p2) == 1 { return p2; };
    };
    return "clang";
}

#[manual_drop]
fn host_is_windows() -> i64 {
    // Detects host OS via the path separator returned by the runtime.
    // Used by link_native_module to choose Windows-only flags (/STACK: linker
    // syntax, .exe suffix, 2>NUL stderr redirect) vs POSIX equivalents.
    let sep: str = path_separator();
    if str_len(sep) >= 1 && str_char_at(sep, 0) == 92 { return 1; };
    return 0;
}

#[manual_drop]
fn host_exe_suffix() -> str {
    if host_is_windows() == 1 { return ".exe"; };
    return "";
}

#[manual_drop]
fn host_target_path_sep() -> str {
    if host_is_windows() == 1 { return "\\"; };
    return "/";
}

#[manual_drop]
fn host_shell_path(path: str) -> str {
    if host_is_windows() != 1 { return path; };
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    let n: i64 = str_len(path);
    while i < n {
        let c: i64 = str_char_at(path, i);
        if c == 47 { sb_append_char(sb, 92); }
        else { sb_append_char(sb, c); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn host_null_redirect() -> str {
    if host_is_windows() == 1 { return " 2>NUL"; };
    return " 2>/dev/null";
}

#[manual_drop]
fn host_remove_file_quiet(path: str) -> i64 {
    if host_is_windows() == 1 {
        return system(str_concat("del /F /Q ", str_concat(path, " 2>NUL")));
    };
    return system(str_concat("rm -f ", str_concat(path, " 2>/dev/null")));
}

#[manual_drop]
fn host_remove_dir_quiet(path: str) -> i64 {
    // Recursive directory remove that respects the host shell. Pre-fix
    // the clean command shelled out to `rmdir /S /Q ... 2>nul` on every
    // platform: on Linux that left target/.nuc_cache_v2/ untouched
    // (R4 in the 8C transcript) and leaked a literal file named `nul`
    // into the working directory because `2>nul` is cmd.exe-only
    // syntax.
    if host_is_windows() == 1 {
        return system(str_concat("rmdir /S /Q ", str_concat(path, " 2>NUL")));
    };
    return system(str_concat("rm -rf ", str_concat(path, " 2>/dev/null")));
}

#[manual_drop]
fn host_stack_link_flag() -> str {
    // Windows: clang-cl-style flag passed through to MSVC link.exe / lld-link.
    // POSIX: GNU ld accepts -z stacksize=N (in bytes). Both expand the main
    // thread stack to 16 MiB so deep recursion in the compiler works.
    if host_is_windows() == 1 { return " -Wl,/STACK:16777216 -Wl,/Brepro"; };
    return " -Wl,-z,stacksize=16777216 -Wl,--build-id=none -lm -lpthread";
}

#[manual_drop]
fn host_fast_link_flag() -> str {
    if host_is_windows() == 1 {
        if fs_exists("C:\\Progra~1\\LLVM\\bin\\lld-link.exe") == 1 { return " -fuse-ld=lld"; };
        if fs_exists("C:\\Program Files\\LLVM\\bin\\lld-link.exe") == 1 { return " -fuse-ld=lld"; };
    };
    return "";
}

#[manual_drop]
fn write_ll_artifact_if_needed(ll_path: str, ll: str, cache_key: str) -> i64 {
    if str_len(cache_key) > 0 {
        let stamp_path: str = str_concat(ll_path, ".cachekey");
        if fs_exists(ll_path) == 1 && str_eq(file_read_string(stamp_path), cache_key) == 1 { return 0; };
        file_write_string(ll_path, ll);
        file_write_string(stamp_path, cache_key);
        return 1;
    };
    file_write_string(ll_path, ll);
    return 1;
}

#[manual_drop]
fn copy_ll_artifact_if_needed(src_ll_path: str, ll_path: str, cache_key: str) -> i64 {
    if str_len(cache_key) > 0 {
        let stamp_path: str = str_concat(ll_path, ".cachekey");
        if fs_exists(ll_path) == 1 && str_eq(file_read_string(stamp_path), cache_key) == 1 { return 0; };
        fs_copy_file(src_ll_path, ll_path);
        file_write_string(stamp_path, cache_key);
        return 1;
    };
    fs_copy_file(src_ll_path, ll_path);
    return 1;
}

// =====================================================
// PERF: parallel codegen — shard the emitted module
// =====================================================
// The single emitted `.ll` is ~95% function bodies (12.5 MB of 13 MB for
// the self-host). clang codegen of one translation unit is single-threaded
// and is the largest cold-build cost (~1.7 s). Split the module into N
// shards — each carrying the full (cheap, ~0.7 MB) preamble of `declare`s +
// private string constants plus a slice of the function definitions — and
// compile them with N concurrent clang processes, then link the objects in
// the existing final-link step.
//
// Correctness: the split only *redistributes* function definitions across
// object files; not one instruction changes, so the linked binary is
// behaviorally identical to the single-file build (verified: byte-identical
// self-emit IR). Cross-shard calls are satisfied by emitting a `declare`
// for every user fn a shard references but does not define; the closure-
// runtime fns (defined once, in shard 0) get the same treatment. The
// provenance globals stay in shard 0 only.
//
// Safety: POSIX-only (uses `&`/`wait`); on Windows, tiny modules, or any
// structural anomaly the helper returns "" and the caller falls back to the
// proven single-file compile. A shard that fails to produce its `.o` also
// triggers the fallback. Tunable / disable via NUCLEOR_CG_SHARDS (default 4).
#[manual_drop]
fn cg_match_at(s: str, slen: i64, i: i64, needle: str) -> i64 {
    let nl: i64 = str_len(needle);
    if i + nl > slen { return 0; };
    let mut k: i64 = 0;
    while k < nl {
        if str_char_at(s, i + k) != str_char_at(needle, k) { return 0; };
        k = k + 1;
    };
    return 1;
}

// "define i64 @f(i64 %x) {"  ->  "declare i64 @f(i64 %x)"
#[manual_drop]
fn cg_sig_to_decl(ll: str, start: i64, sigend: i64) -> str {
    let body_start: i64 = start + 7;   // strip leading "define "
    let mut e: i64 = sigend;
    // trim trailing " {" (space=32, '{'=123)
    while e > body_start && (str_char_at(ll, e - 1) == 32 || str_char_at(ll, e - 1) == 123) {
        e = e - 1;
    };
    return str_concat("declare ", str_substring(ll, body_start, e));
}

// Returns a space-joined list of object-file shell paths on success, or ""
// to signal the caller to fall back to a single-file compile of `ll`.
//
// Memory: this runs once per build, in the (low-memory) native-link parent
// after the emit child has exited, so the cold-build RSS peak (the child's
// type-check) is already past. Like the rest of the compiler's short-lived
// string scratch, the transient buffers here are left for process exit
// rather than hand-freed — manual frees of `str_from_int` / `str_concat` /
// `sb_to_str` results are not the codebase convention and risk the
// double-free class this project has been bitten by (MEM-3).
#[manual_drop]
fn cg_try_parallel(ll: str, ll_path: str, clang_quoted: str, opt_flag: str, null_redir: str) -> str {
    if host_is_windows() == 1 { return ""; };
    // Default 4: the link-time clang processes run after the emit child has
    // exited, so they trade transient peak RSS (~60-110 MB each) for codegen
    // wall time — the cold tree ceiling (512 MB) is sized for this. The
    // compiler-only RSS is unchanged. Set NUCLEOR_CG_SHARDS=1 to disable, or
    // =2 for a memory-neutral build on a constrained host.
    let shards: i64 = str_to_int(env_get_or("NUCLEOR_CG_SHARDS", "4"));
    if shards <= 1 { return ""; };
    let len: i64 = str_len(ll);
    if len < 2000000 { return ""; };   // small modules: single-file is already fast

    // --- one linear pass: collect every module-level `define ` line-start +
    // the offset of the '\n' ending its signature line, plus the provenance
    // global offset. Function bodies are indented, so only module-level
    // defines/globals sit at column 0.
    let mut def_start: Vec<i32> = Vec::new();
    let mut def_sigend: Vec<i32> = Vec::new();
    let mut prov_off: i64 = 0 - 1;
    let mut i: i64 = 0;
    let mut at_ls: i64 = 1;
    while i < len {
        let c: i64 = str_char_at(ll, i);
        if at_ls == 1 {
            if c == 100 && cg_match_at(ll, len, i, "define ") == 1 {
                def_start.push(i);
                def_sigend.push(0 - 1);
            } else if c == 64 && prov_off < 0 && cg_match_at(ll, len, i, "@.nucleor_provenance_data") == 1 {
                prov_off = i;
            };
        };
        if c == 10 {
            let dn0: i64 = vec_len(def_start);
            if dn0 > 0 && vec_get(def_sigend, dn0 - 1) == (0 - 1) {
                vec_set(def_sigend, dn0 - 1, i);
            };
            at_ls = 1;
        } else {
            at_ls = 0;
        };
        i = i + 1;
    };

    let dn: i64 = vec_len(def_start);
    if dn == 0 || prov_off < 0 { return ""; };
    // first user define = first define whose offset is past the provenance
    // global (closure-runtime defines come before it).
    let mut u: i64 = 0;
    while u < dn && vec_get(def_start, u) < prov_off { u = u + 1; };
    if u == 0 || u >= dn { return ""; };
    // defensive: every define must have a recorded signature end
    let mut vi: i64 = 0;
    while vi < dn {
        if vec_get(def_sigend, vi) < 0 { return ""; };
        vi = vi + 1;
    };
    let preamble_end: i64 = vec_get(def_start, 0);
    let first_user_off: i64 = vec_get(def_start, u);

    let pre: str = str_substring(ll, 0, preamble_end);
    // closure-runtime defines + provenance globals — shard 0 only
    let closure_prov: str = str_substring(ll, preamble_end, first_user_off);

    // closure-runtime declarations for shards 1..N
    let cd: i64 = sb_new();
    let mut ci: i64 = 0;
    while ci < u {
        sb_append(cd, cg_sig_to_decl(ll, vec_get(def_start, ci), vec_get(def_sigend, ci)));
        sb_append(cd, "\n");
        ci = ci + 1;
    };
    let closure_decls: str = sb_to_str(cd);

    let user_count: i64 = dn - u;
    // precompute every user fn's declaration line
    let mut user_decls: Vec<i32> = Vec::new();
    let mut j: i64 = 0;
    while j < user_count {
        user_decls.push(cg_sig_to_decl(ll, vec_get(def_start, u + j), vec_get(def_sigend, u + j)));
        j = j + 1;
    };

    let compile_cmd: i64 = sb_new();
    let obj_list: i64 = sb_new();
    let mut k: i64 = 0;
    while k < shards {
        let sb: i64 = sb_new_with_cap(4500000);
        sb_append(sb, pre);
        if k == 0 { sb_append(sb, closure_prov); } else { sb_append(sb, closure_decls); };
        // declarations for user fns not defined in this shard
        let mut dj: i64 = 0;
        while dj < user_count {
            if (dj % shards) != k {
                sb_append(sb, vec_get(user_decls, dj));
                sb_append(sb, "\n");
            };
            dj = dj + 1;
        };
        // definitions assigned to this shard (round-robin)
        let mut bj: i64 = 0;
        while bj < user_count {
            if (bj % shards) == k {
                let gi: i64 = u + bj;
                let bstart: i64 = vec_get(def_start, gi);
                let bend: i64 = if gi + 1 < dn { vec_get(def_start, gi + 1) } else { len };
                sb_append(sb, str_substring(ll, bstart, bend));
            };
            bj = bj + 1;
        };
        let kstr: str = str_from_int(k);
        let shard_ll: str = str_concat(ll_path, str_concat(".s", str_concat(kstr, ".ll")));
        let shard_obj: str = str_concat(ll_path, str_concat(".s", str_concat(kstr, ".o")));
        file_write_string(shard_ll, sb_to_str(sb));
        host_remove_file_quiet(shard_obj);
        sb_append(compile_cmd, clang_quoted);
        sb_append(compile_cmd, opt_flag);
        sb_append(compile_cmd, " -c ");
        sb_append(compile_cmd, host_shell_path(shard_ll));
        sb_append(compile_cmd, " -o ");
        sb_append(compile_cmd, host_shell_path(shard_obj));
        sb_append(compile_cmd, " -Wno-override-module");
        sb_append(compile_cmd, null_redir);
        sb_append(compile_cmd, " & ");
        sb_append(obj_list, " ");
        sb_append(obj_list, host_shell_path(shard_obj));
        k = k + 1;
    };
    sb_append(compile_cmd, " wait");
    system(sb_to_str(compile_cmd));

    // every shard object must exist, else fall back to single-file
    let objs: str = sb_to_str(obj_list);
    let mut vk: i64 = 0;
    let mut ok: i64 = 1;
    while vk < shards {
        let shard_obj2: str = str_concat(ll_path, str_concat(".s", str_concat(str_from_int(vk), ".o")));
        if fs_exists(shard_obj2) == 0 { ok = 0; };
        vk = vk + 1;
    };
    if ok == 0 { return ""; };
    return objs;
}

#[manual_drop]
fn link_native_module(ll: str, out_name: str, imported: Vec<i32>, native_key_hint: str, link_native: i64, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(str_concat("target/", str_concat(out_name, ".ll")));
    let exe_path: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(out_name, host_exe_suffix())));
    let null_redir: str = host_null_redirect();
    system(str_concat("mkdir target", null_redir));
    write_ll_artifact_if_needed(ll_path, ll, native_key_hint);
    print(str_concat("  emitted: ", str_concat(ll_path, str_concat(" (", str_concat(str_from_int(str_len(ll)), " bytes)")))));
    if link_native == 0 {
        print(str_concat("  native link: skipped (use ", str_concat(exe_path, " only after a linked build)")));
        return 0;
    };
    let native_d: Vec<i32> = collect_native_directives(imported);
    let link_flags: str = vec_get(native_d, 0);
    let cfiles: str = vec_get(native_d, 1);
    let libpath_flags: str = vec_get(native_d, 2);
    let rt_arg: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let ll_arg: str = host_shell_path(ll_path);
    let rt_arg_shell: str = host_shell_path(rt_arg);
    let cfiles_shell: str = host_shell_path(cfiles);
    let libpath_flags_shell: str = host_shell_path(libpath_flags);
    // force-include the shared OOM-aware allocator
    // header into every C TU clang sees so the whole-runtime malloc/
    // realloc/calloc surface routes through the panic-on-NULL
    // wrappers (honoring NUCLEOR_OOM_LENIENT=1). Without this,
    // pre-v0.3.234 the wrappers only covered nucleor_llvm_rt.c
    // and the ~150 other rt files were left with bare libc allocs.
    let alloc_hdr: str = resolve_toolchain_path("stdlib/runtime/nuc_alloc.h");
    // do NOT add quotes around the header path. The
    // surrounding system() call already wraps the whole clang
    // command in cmd.exe /c "...", and adding two more quotes
    // here flips the cmd.exe quote-parity rule that strips the
    // outer wrapper -- which then breaks the C:\Program Files\
    // clang path quoting elsewhere in the line. Keep it bare.
    let alloc_include_flag: str = str_concat(" -include ", host_shell_path(alloc_hdr));
    host_remove_file_quiet(exe_path);
    let stack_flag: str = host_stack_link_flag();
    let linker_flag: str = host_fast_link_flag();
    // T1.5d (v0.2.343): capture clang stderr to a log file so the
    // post-link MOD-003 diagnostic step can scan it for undefined-
    // symbol references that match privatized fn names. Without
    // capture, clang's output goes straight to the terminal and we
    // can't tell whether any of its errors are MOD-003-worthy.
    system(str_concat("mkdir .nuc_cache", null_redir));
    system(str_concat("mkdir .nuc_rt_cache", null_redir));
    // per-output clang_link log. Pre-fix this was a single
    // shared `.nuc_cache/clang_link.log` that every concurrent compile
    // raced on (parallel verify harness at -j 8 lost ~3 fixtures to
    // empty-log false-failures; -j 12 lost 125+). Concurrency-safe-
    // by-construction is a Nucleor design promise — the compiler
    // violating it on its own build cache was a self-inflicted
    // regression. Per-output suffix lets N concurrent compilers each
    // own their own log; the post-link MOD-003 scan and the empty-log
    // retry loop both keep working unchanged because they read the
    // same path this function wrote.
    let log_path: str = sanitize(str_concat(".nuc_cache/clang_link.", str_concat(out_name, ".log")));
    let log_arg: str = host_shell_path(log_path);
    let mut native_cache_key: str = "";
    if native_link_cache_allowed(link_flags, cfiles, libpath_flags) == 1 {
        native_cache_key = native_link_cache_key_from_compile_key(native_key_hint, rt_arg, alloc_hdr, stack_flag, linker_flag);
        if str_len(native_cache_key) == 0 {
            native_cache_key = native_link_cache_key(ll, rt_arg, alloc_hdr, stack_flag, linker_flag);
        };
        let cached_exe: str = native_link_cache_path(native_cache_key);
        if fs_exists(cached_exe) == 1 {
            let cache_copy_ok: i64 = fs_copy_file(cached_exe, exe_path);
            if cache_copy_ok == 1 {
                print(str_concat("  native link: cache hit (sha=", str_concat(cache_v2_prefix(native_cache_key), ")")));
                print_phase_time(time_passes, "clang", 0);
                return 0;
            };
        };
    };
    let clang_start: i64 = now_ms();
    // NUC-FEEDBACK-003 — quote the clang path so spaces
    // (e.g. `C:\Program Files\LLVM\bin\clang.exe`) survive the shell
    // command split. Without quoting, cmd.exe sees `C:\Program` as
    // the executable and the rest as args, failing with
    // `'C:\Program' is not recognized`.
    let clang_quoted: str = str_concat("\"", str_concat(llvm_clang_path(), "\""));
    // default -O level chosen
    // per `NUCLEOR_LLVM_OPT` (defaults to `-O0` to keep typical link fast;
    // bootstrap_linux.sh already pre-bakes -O2 into bin/nucleor itself so
    // the compiler runtime is optimized). Set `NUCLEOR_LLVM_OPT=-O2` for a
    // release-build of an output binary; the pre-fix code passed no -O at
    // all so adopters never had a way to reach the optimizer.
    let opt_flag_raw: str = env_get_or("NUCLEOR_LLVM_OPT", "-O0");
    let opt_flag: str = str_concat(" ", opt_flag_raw);
    // PERF: try sharded parallel codegen. On success `shard_objs` is the
    // space-joined list of object files to link instead of the single `.ll`;
    // on Windows / tiny modules / any anomaly it returns "" and we compile the
    // single `.ll` exactly as before. The remainder of the link command
    // (runtime, cfiles, flags, log capture, retries) is unchanged.
    let shard_objs: str = cg_try_parallel(ll, ll_path, clang_quoted, opt_flag, null_redir);
    let sharded: i64 = if str_len(shard_objs) > 0 { 1 } else { 0 };
    let compile_input: str = if sharded == 1 { shard_objs } else { ll_arg };
    if sharded == 1 {
        print(str_concat("  parallel codegen: ", str_concat(env_get_or("NUCLEOR_CG_SHARDS", "4"), " shards")));
    };
    let cmd: str = str_concat(clang_quoted, str_concat(opt_flag, str_concat(linker_flag, str_concat(" ", str_concat(compile_input, str_concat(" ", str_concat(rt_arg_shell, str_concat(cfiles_shell, str_concat(alloc_include_flag, str_concat(" -o ", str_concat(exe_path, str_concat(" -Wno-override-module", str_concat(stack_flag, str_concat(" ", str_concat(libpath_flags_shell, str_concat(link_flags, str_concat(" > ", str_concat(log_arg, " 2>&1"))))))))))))))))));
    let mut rc: i64 = system(cmd);
    // NUC-FEEDBACK-009 retry loop. ML adopters reported
    // intermittent post-LLVM-emit/no-compiled-line failures during
    // long verifier passes (rc=4294967295 = Windows spawn failure).
    // The agent added retry in their harness; mirror that at the
    // compiler level. Retry up to 2 more times when clang fails AND
    // the captured log is empty (process-spawn failure heuristic).
    // Real clang errors leave a non-empty log and won't be retried.
    if rc != 0 {
        let log_first: str = file_read_string(log_path);
        if str_len(log_first) == 0 {
            let mut retry_i: i64 = 0;
            while retry_i < 2 && rc != 0 {
                rc = system(cmd);
                if rc != 0 {
                    let log_check: str = file_read_string(log_path);
                    if str_len(log_check) > 0 { retry_i = 2; };
                };
                retry_i = retry_i + 1;
            };
        };
    };
    // NUC-FEEDBACK-009 follow-on #3 — also retry the
    // post-clang LOCKED-OUTPUT case. The empty-log retry above only
    // catches "clang never started"; if clang RAN but failed because
    // the output exe was held open (Windows AV scan, antivirus
    // dropper, prior orphan exe), the log is non-empty and contains
    // strings like "used by another process", "LNK1104", or
    // "could not open output file". Retry a couple of times with a
    // short sleep so the AV/file-handle window can close.
    if rc != 0 {
        let lock_log: str = file_read_string(log_path);
        if str_len(lock_log) > 0 {
            let lock_seen: i64 = if str_contains(lock_log, "used by another process") == 1
                || str_contains(lock_log, "LNK1104") == 1
                || str_contains(lock_log, "could not open output") == 1
                || str_contains(lock_log, "Permission denied") == 1 { 1 } else { 0 };
            if lock_seen == 1 {
                let mut lr: i64 = 0;
                while lr < 2 && rc != 0 {
                    sleep_ms(150);
                    rc = system(cmd);
                    if rc != 0 {
                        let chk: str = file_read_string(log_path);
                        let still_lock: i64 = if str_contains(chk, "used by another process") == 1
                            || str_contains(chk, "LNK1104") == 1
                            || str_contains(chk, "could not open output") == 1
                            || str_contains(chk, "Permission denied") == 1 { 1 } else { 0 };
                        if still_lock == 0 { lr = 2; };
                    };
                    lr = lr + 1;
                };
            };
        };
    };
    print_phase_time(time_passes, "clang", now_ms() - clang_start);
    let clang_log: str = file_read_string(log_path);
    if rc != 0 {
        // T1.5d: lift link-time undefined-symbol errors into MOD-003
        // diagnostics for any symbol that matches a registered
        // private fn name. Echo the raw clang output AFTER the
        // friendly diagnostic so users see both: the spec-aligned
        // diagnostic first (for tooling), then the underlying clang
        // detail (for power users).
        let priv_reg: Vec<i32> = priv_build_global_registry(imported);
        let lifted: i64 = priv_lift_link_errors(clang_log, priv_reg);
        // also lift true-undefined-fn errors (closes deferral
        // doc-#1 §_undef-fn-call). MOD-003 claims privatization
        // mismatches; this companion claims the rest. Together they
        // cover every `use of undefined value '@<name>'` clang
        // emits into a clean TYP-005/MOD-003 line.
        let lifted_undef: i64 = lift_undefined_fn_link_errors(clang_log, priv_reg);
        // lift the no-main-fn link error (Windows LNK1561 /
        // POSIX `undefined reference to main`) to a clean diagnostic.
        // Pre-fix a `.nr` file with no `fn main` failed at clang link
        // with `LINK : fatal error LNK1561: entry point must be
        // defined` and clang's `linker command failed with exit code
        // 1561` cryptic line — adopters had to know what LNK1561
        // means. Same lift pattern as the v0.4.106 undefined-fn lift.
        let lifted_main: i64 = lift_no_main_link_error(clang_log);
        if (lifted + lifted_undef + lifted_main) == 0 && str_len(clang_log) > 0 { print(clang_log); };
        let ll_check: str = file_read_string(ll_path);
        if str_len(ll_check) > 0 {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            if lifted > 0 {
                print(str_concat("  ", str_concat(str_from_int(lifted), " MOD-003 violation(s) — see error[MOD-003] above")));
            };
            if lifted_undef > 0 {
                print(str_concat("  ", str_concat(str_from_int(lifted_undef), " TYP-005 undefined-fn violation(s) — see error[TYP-005] above")));
            };
            if lifted_main > 0 {
                print("  no `fn main` defined — see error[NR022] above");
            };
            if (lifted + lifted_undef + lifted_main) == 0 {
                print("  note: LLVM IR was emitted; GPU/CUDA experiments may require manual link with CUDA libs");
            };
        } else {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
        };
        // NUC-FEEDBACK-009 -- always print the failing
        // command and a hint on what the captured log contains so
        // adopters can distinguish "clang errored" from "clang
        // never started" (process-spawn / file-lock / antivirus).
        // Pre-fix the post-emit failure path was opaque on Windows
        // -- adopters saw "emitted: ..." then a nonzero exit with
        // no COMMAND/STDERR signal to triage cache/file-lock vs
        // genuine clang errors.
        print("  link command:");
        print(str_concat("    ", cmd));
        if str_len(clang_log) == 0 {
            print("  note: clang_link.log is EMPTY -- clang likely never started (file lock, missing exe, antivirus, or process-spawn failure). Check that bin/nucleor.exe is not held open by an orphan process and retry.");
        };
        // NUC-FEEDBACK-009 follow-on #3 — locked-output
        // hint. If the link failure shows the well-known Windows
        // file-lock signature, print the locked path and a
        // path-specific cleanup command (PowerShell + cmd) so
        // adopters don't have to extract the basename themselves
        // from a long verbose link line.
        let lock_after: i64 = if str_len(clang_log) > 0 && (str_contains(clang_log, "used by another process") == 1
            || str_contains(clang_log, "LNK1104") == 1
            || str_contains(clang_log, "could not open output") == 1
            || str_contains(clang_log, "Permission denied") == 1) { 1 } else { 0 };
        if lock_after == 1 {
            print(str_concat("  locked output: ", exe_path));
            // Extract the basename (no dir, no .exe) for the
            // taskkill / Stop-Process command.
            let pl: i64 = str_len(exe_path);
            let mut bs: i64 = pl;
            let mut k: i64 = 0;
            while k < pl {
                let ch: i64 = str_char_at(exe_path, k);
                if ch == 47 || ch == 92 { bs = k + 1; };
                k = k + 1;
            };
            let mut be: i64 = pl;
            if pl >= 4 && str_eq(str_substring(exe_path, pl - 4, pl), ".exe") == 1 {
                be = pl - 4;
            };
            let base: str = if bs < be { str_substring(exe_path, bs, be) } else { exe_path };
            print(str_concat("  hint: Stop-Process -Name ", str_concat(base, " -Force -ErrorAction SilentlyContinue")));
            print(str_concat("  hint: taskkill /F /IM ", str_concat(base, ".exe 2> NUL")));
            print("  note: persistent lock after 3 internal retries (150ms apart) usually means an orphan instance of the output exe is still running, an AV scanner is mid-scan, or another build is touching the same target path.");
        };
        return 1;
    };
    if str_len(clang_log) > 0 { print(clang_log); };
    print(str_concat("  compiled: ", exe_path));
    native_link_cache_store(native_cache_key, exe_path);
    return 0;
}

#[manual_drop]
fn link_existing_native_module(ll_path_raw: str, out_name: str, imported: Vec<i32>, native_key_hint: str, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(ll_path_raw);
    if fs_exists(ll_path) == 0 {
        print(str_concat("ERROR: native link cannot read emitted IR ", ll_path));
        return 1;
    };
    let exe_path: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(out_name, host_exe_suffix())));
    let null_redir: str = host_null_redirect();
    system(str_concat("mkdir target", null_redir));
    let native_d: Vec<i32> = collect_native_directives(imported);
    let link_flags: str = vec_get(native_d, 0);
    let cfiles: str = vec_get(native_d, 1);
    let libpath_flags: str = vec_get(native_d, 2);
    let rt_arg: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let ll_arg: str = host_shell_path(ll_path);
    let rt_arg_shell: str = host_shell_path(rt_arg);
    let cfiles_shell: str = host_shell_path(cfiles);
    let libpath_flags_shell: str = host_shell_path(libpath_flags);
    let alloc_hdr: str = resolve_toolchain_path("stdlib/runtime/nuc_alloc.h");
    let alloc_include_flag: str = str_concat(" -include ", host_shell_path(alloc_hdr));
    host_remove_file_quiet(exe_path);
    let stack_flag: str = host_stack_link_flag();
    let linker_flag: str = host_fast_link_flag();
    system(str_concat("mkdir .nuc_cache", null_redir));
    system(str_concat("mkdir .nuc_rt_cache", null_redir));
    let log_path: str = sanitize(str_concat(".nuc_cache/clang_link.", str_concat(out_name, ".log")));
    let log_arg: str = host_shell_path(log_path);
    let mut native_cache_key: str = "";
    if native_link_cache_allowed(link_flags, cfiles, libpath_flags) == 1 && str_len(native_key_hint) > 0 {
        native_cache_key = native_link_cache_key_from_compile_key(native_key_hint, rt_arg, alloc_hdr, stack_flag, linker_flag);
        let cached_exe: str = native_link_cache_path(native_cache_key);
        if fs_exists(cached_exe) == 1 {
            let cache_copy_ok: i64 = fs_copy_file(cached_exe, exe_path);
            if cache_copy_ok == 1 {
                print(str_concat("  native link: cache hit (sha=", str_concat(cache_v2_prefix(native_cache_key), ")")));
                print_phase_time(time_passes, "clang", 0);
                return 0;
            };
        };
    };
    let clang_start: i64 = now_ms();
    let clang_quoted: str = str_concat("\"", str_concat(llvm_clang_path(), "\""));
    let opt_flag_raw_iso: str = env_get_or("NUCLEOR_LLVM_OPT", "-O0");
    // PERF: try sharded parallel codegen (this is the path the large
    // self-build takes). Only read the (large) `.ll` back when sharding can
    // actually run (POSIX + shards>1), so the disabled/Windows path pays no
    // extra read. The emit child already exited, so reading here costs memory
    // only after the child's peak is gone — no tree-RSS regression. On success
    // `cg_objs` is the object list to link in place of the single `.ll`.
    let mut cg_objs: str = "";
    if host_is_windows() == 0 && str_to_int(env_get_or("NUCLEOR_CG_SHARDS", "4")) > 1 {
        cg_objs = cg_try_parallel(file_read_string(ll_path), ll_path, clang_quoted, str_concat(" ", opt_flag_raw_iso), null_redir);
    };
    let cg_sharded: i64 = if str_len(cg_objs) > 0 { 1 } else { 0 };
    if cg_sharded == 1 {
        print(str_concat("  parallel codegen: ", str_concat(env_get_or("NUCLEOR_CG_SHARDS", "4"), " shards")));
    };
    let rt_o_path: str = rt_o_cache_path(rt_arg, alloc_hdr, opt_flag_raw_iso);
    let mut rt_link_arg: str = "";
    let mut alloc_include_use: str = "";
    if str_len(rt_o_path) > 0 && str_len(cfiles) == 0 {
        if fs_exists(rt_o_path) == 0 {
            let mut rt_compile_cmd: str = clang_quoted;
            rt_compile_cmd = str_concat(rt_compile_cmd, " ");
            rt_compile_cmd = str_concat(rt_compile_cmd, opt_flag_raw_iso);
            rt_compile_cmd = str_concat(rt_compile_cmd, " -c ");
            rt_compile_cmd = str_concat(rt_compile_cmd, rt_arg_shell);
            rt_compile_cmd = str_concat(rt_compile_cmd, alloc_include_flag);
            rt_compile_cmd = str_concat(rt_compile_cmd, " -o ");
            rt_compile_cmd = str_concat(rt_compile_cmd, host_shell_path(rt_o_path));
            rt_compile_cmd = str_concat(rt_compile_cmd, " > ");
            rt_compile_cmd = str_concat(rt_compile_cmd, log_arg);
            rt_compile_cmd = str_concat(rt_compile_cmd, " 2>&1");
            let rt_rc: i64 = system(rt_compile_cmd);
            if rt_rc != 0 {
                // Fall through to monolithic link
                rt_link_arg = rt_arg_shell;
                alloc_include_use = alloc_include_flag;
            } else {
                rt_link_arg = host_shell_path(rt_o_path);
            };
        } else {
            rt_link_arg = host_shell_path(rt_o_path);
        };
    } else {
        rt_link_arg = rt_arg_shell;
        alloc_include_use = alloc_include_flag;
    };
    let mut cmd: str = clang_quoted;
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, opt_flag_raw_iso);
    cmd = str_concat(cmd, linker_flag);
    cmd = str_concat(cmd, " ");
    if cg_sharded == 1 { cmd = str_concat(cmd, cg_objs); } else { cmd = str_concat(cmd, ll_arg); };
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, rt_link_arg);
    cmd = str_concat(cmd, cfiles_shell);
    cmd = str_concat(cmd, alloc_include_use);
    cmd = str_concat(cmd, " -o ");
    cmd = str_concat(cmd, exe_path);
    cmd = str_concat(cmd, " -Wno-override-module");
    cmd = str_concat(cmd, stack_flag);
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, libpath_flags_shell);
    cmd = str_concat(cmd, link_flags);
    cmd = str_concat(cmd, " > ");
    cmd = str_concat(cmd, log_arg);
    cmd = str_concat(cmd, " 2>&1");
    let rc: i64 = system(cmd);
    print_phase_time(time_passes, "clang", now_ms() - clang_start);
    if rc != 0 {
        let ll_bytes: str = file_read_string(ll_path);
        if str_len(ll_bytes) == 0 {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            return 1;
        };
        return link_native_module(ll_bytes, out_name, imported, native_key_hint, 1, time_passes);
    };
    let clang_log: str = file_read_string(log_path);
    if str_len(clang_log) > 0 { print(clang_log); };
    print(str_concat("  compiled: ", exe_path));
    native_link_cache_store(native_cache_key, exe_path);
    return 0;
}
