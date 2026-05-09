// =====================================================================
// RFC-0063 Wave 13-16 — Phase 3 parser/tools-suite duplicate retirement.
// Companion to nucleor_rfc0063_shared_wave1.nr. s1 canonical.
// Per CLOUD_AGENT_V1X_HARDENING_BRIEF_2026-05-08.md §R1.
//
// Excluded from move (must stay LOCAL in tools_suite — read directly
// by tools/check_compiler_drift.sh which doesn't follow imports):
//   get_rt_name, is_ptr_ret, is_ptr_arg, emit_externs,
//   compiler_version_label, emit_user_externs (contains a `declare `
//   sb_append the IR-declare drift gate enforces).
// match_bind_payloads_typed pairs with SIG_DIFFERS match_bind_payloads
// (wave 14 territory).
// Those are filed as Phase B residuals in
// findings/inbox/cloud_R1_rfc0063_waves_v0846_2026-05-08.md.
//
// Wave 13a (≤30-line) + 13b (30-100-line) + 13c (>100-line).
// All s1-only-helper-dep candidates filtered out.
// Imported by compiler/nucleor_tools_suite.nr alongside wave1.
// =====================================================================

#[manual_drop]
fn str_to_int(s: str) -> i64 {
    // v0.3.208: wrap arithmetic via wrapping_mul/add so that large
    // literals like u64::MAX (18446744073709551615) parse correctly
    // under strict-arithmetic mode without panicking. The accumulator
    // is intentionally allowed to wrap into the negative i64 range
    // (the resulting bit pattern is what u64 callers want anyway).
    //
    // v0.6.49: also use wrapping_sub for the final neg step. Pre-fix
    // `str_to_int("-9223372036854775808")` (canonical i64::MIN as a
    // negative-prefixed decimal string) panicked under strict-intrin
    // because the digit accumulator wrapped to i64::MIN and `0 - MIN`
    // overflowed. Surfaced by const-tracker round-trip on
    // `let x: i64 = -9223372036854775808;` (sister probe finding
    // gap-2; storing the canonical literal value triggered the
    // round-trip). wrapping_sub(0, result) preserves the i64::MIN bit
    // pattern (two's complement: -i64::MIN == i64::MIN) without
    // tripping the strict-intrin trap.
    let slen: i64 = str_len(s);
    let mut result: i64 = 0;
    let mut i: i64 = 0;
    let mut neg: i64 = 0;
    if slen > 0 && str_char_at(s, 0) == 45 { neg = 1; i = 1; };
    while i < slen {
        result = wrapping_add(wrapping_mul(result, 10), str_char_at(s, i) - 48);
        i = i + 1;
    };
    if neg == 1 { return wrapping_sub(0, result); };
    return result;
}

#[manual_drop]
fn ir_fn_new(name: str, pc: i64) -> Vec<i32> {
    let mut f: Vec<i32> = Vec::with_capacity(5); f.push(name); f.push(pc);
    let mut entry_allocas: Vec<i32> = Vec::new(); f.push(entry_allocas);
    let mut blocks: Vec<i32> = Vec::new(); f.push(blocks);
    // v0.4.209 RFC-0015 phase 3a-step-3 (Option F-light): per-fn
    // widths-by-reg table. Slot 4 stores a Vec<i32> indexed by
    // alloca-reg id; values are sign-encoded narrow widths
    // (positive=signed, negative=unsigned, 0=untyped/i64). Grows
    // on demand at set time. Read at every var-ref load + store
    // for typed-IR dispatch. Two vec_gets per read on the hot path
    // — no str_concat, no sym_get hash.
    let mut widths_by_reg: Vec<i32> = Vec::new(); f.push(widths_by_reg);
    return f;
}

#[manual_drop]
fn escape_llvm_str(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut esb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 92 { sb_append(esb, "\\5C"); }
        else if c == 34 { sb_append(esb, "\\22"); }
        else if c == 10 { sb_append(esb, "\\0A"); }
        else if c == 13 { sb_append(esb, "\\0D"); }
        else if c == 9 { sb_append(esb, "\\09"); }
        else if c == 0 { sb_append(esb, "\\00"); }
        else if c >= 32 && c <= 126 { sb_append_char(esb, c); }
        else { sb_append(esb, "\\"); sb_append(esb, hex_byte(c)); };
        i = i + 1;
    };
    return sb_to_str(esb);
}

#[manual_drop]
fn ctr_next(c: Vec<i32>) -> i64 { let v: i64 = vec_get(c, 0); vec_set(c, 0, v + 1); return v; }

#[manual_drop]
fn tok_to_ir(tok: i64) -> i64 {
    if tok == 20 { return 2; }; if tok == 21 { return 3; }; if tok == 22 { return 4; };
    if tok == 23 { return 5; }; if tok == 24 { return 6; }; if tok == 30 { return 7; };
    if tok == 31 { return 8; }; if tok == 32 { return 9; }; if tok == 33 { return 10; };
    if tok == 34 { return 11; }; if tok == 35 { return 12; };
    if tok == 36 { return 13; }; if tok == 37 { return 14; };
    // v0.3.103: bitwise ops. Map `&` (token 82) to LLVM `and i64`
    // (iop 13 — same as `&&` since both lower to bitwise AND of i64
    // operands), `|` (token 65) to `or i64` (iop 14), and `^`
    // (token 94) to a new `xor i64` (iop 15). The parse_bitwise
    // tier between parse_eq and parse_and_expr (logical &&) ensures
    // these operators actually reach the binop chain instead of
    // dying after the LHS with a diag.
    if tok == 82 { return 13; }; if tok == 65 { return 14; }; if tok == 94 { return 15; };
    // v0.3.104: shift ops. Token 115 = `<<` (lexer), 116 = synthetic
    // `>>` produced by parse_shift when it sees two adjacent `>`.
    // iops 16-17 are alloca/load — can't reuse. Use 23/24 (free).
    if tok == 115 { return 23; }; if tok == 116 { return 24; };
    return 0 - 1;
}

#[manual_drop]
fn type_base_name(t: str) -> str {
    // Hot path: this fn runs on every type comparison during type-
    // check. The prior implementation allocated 4-7 substrings per
    // call (one per prefix probe). Replaced with non-allocating
    // str_starts_with checks; the only remaining allocation is the
    // final substring(0, i) when the input contains a generic angle
    // bracket (e.g. "Vec<i32>" → "Vec"). Most calls return the input
    // unchanged or hit the early "fixed<" / scalar paths.
    let mut base: str = t;
    let tlen: i64 = str_len(base);
    if str_starts_with(base, "&mut ") == 1 { base = str_substring(base, 5, tlen); }
    else if tlen >= 1 && str_char_at(base, 0) == 38 { base = str_substring(base, 1, tlen); };
    let slen: i64 = str_len(base);
    if str_starts_with(base, "Box<") == 1 {
        let inner: str = str_substring(base, 4, slen - 1);
        let r: str = type_base_name(inner);
        return r;
    };
    if str_starts_with(base, "fixed<") == 1 { return "i64"; };
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(base, i) == 60 { return str_substring(base, 0, i); };
        i = i + 1;
    };
    return base;
}

#[manual_drop]
fn type_is_mut_ref(t: str) -> i64 {
    if str_starts_with(t, "&mut ") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn sendable_actor_decl_name_at(src: str, pos: i64) -> str {
    // v0.6.24 perf fix: original called `str_len(src)` (C `strlen`)
    // on the full 1.5MB source EVERY call. Called once per character
    // position from `sendable_source_has_actor_decl` → O(slen²) total.
    // Reuses the fast-fail at str_eq_at first; only computes slen when
    // we actually need to read past pos. Same v0.3.205 strlen-in-
    // substring pattern that's banned per
    // ~/.claude/projects/.../memory/feedback_perf_regression_pattern.md.
    if str_eq_at(src, pos, "actor") == 0 { return ""; };
    let slen: i64 = str_len(src);
    if pos + 5 > slen { return ""; };
    let prev_ok: i64 = if pos == 0 { 1 } else {
        let pc: i64 = str_char_at(src, pos - 1);
        if is_alnum(pc) == 0 { if pc != 95 { 1 } else { 0 } } else { 0 }
    };
    if prev_ok == 0 { return ""; };
    let mut q: i64 = pos + 5;
    if q >= slen || is_ws(str_char_at(src, q)) == 0 { return ""; };
    while q < slen && is_ws(str_char_at(src, q)) == 1 { q = q + 1; };
    let ns: i64 = q;
    while q < slen && (is_alnum(str_char_at(src, q)) == 1 || str_char_at(src, q) == 95) { q = q + 1; };
    if q <= ns { return ""; };
    let name: str = str_substring(src, ns, q);
    while q < slen && is_ws(str_char_at(src, q)) == 1 { q = q + 1; };
    if q < slen && str_char_at(src, q) == 123 { return name; };
    return "";
}

#[manual_drop]
fn own_put_i(o: Vec<i32>, key: str, val: i64) -> i64 {
    // v0.3.221 perf: scan backward and break on first match.
    // v0.4.3: sync the warm aux hashmap on in-place updates IF this
    // sym is currently warm. __nucleor_sym_aux_get returns the warm
    // handle if `o` matches, else -1; we only touch on match.
    let mut i: i64 = vec_len(o) - 2;
    while i >= 0 {
        if str_eq(vec_get(o, i), key) == 1 {
            vec_set(o, i + 1, val);
            let h: i64 = __nucleor_sym_aux_get(o);
            if h > 0 { __nucleor_hashmap_insert(h, key, val); };
            return 0;
        };
        i = i - 2;
    };
    o.push(key);
    o.push(val);
    return 0;
}

#[manual_drop]
fn own_put_s(o: Vec<i32>, key: str, val: str) -> i64 {
    // v0.3.221 perf: same backward-scan break-on-match optimization.
    // v0.4.3: same warm-aux sync as own_put_i. str values are stored
    // as i64-cast pointers under the i64-everywhere ABI.
    let mut i: i64 = vec_len(o) - 2;
    while i >= 0 {
        if str_eq(vec_get(o, i), key) == 1 {
            vec_set(o, i + 1, val);
            let h: i64 = __nucleor_sym_aux_get(o);
            if h > 0 { __nucleor_hashmap_insert(h, key, val); };
            return 0;
        };
        i = i - 2;
    };
    o.push(key);
    o.push(val);
    return 0;
}

#[manual_drop]
fn own_get_mutable(o: Vec<i32>, name: str) -> i64 {
    let key: str = str_concat("__oi_mutable_", name);
    let v: i64 = sym_get(o, key);
    if v >= 0 { return v; };
    // Correctness fallback for the only raw ownership metadata whose
    // stale warm-hash miss can become a false hard error: `let mut`.
    let mut i: i64 = vec_len(o) - 2;
    while i >= 0 {
        if str_eq(vec_get(o, i), key) == 1 { return vec_get(o, i + 1); };
        i = i - 2;
    };
    return 0;
}

#[manual_drop]
fn own_snapshot(o: Vec<i32>) -> Vec<i32> {
    let mut snap: Vec<i32> = Vec::with_capacity(vec_len(o));
    let mut i: i64 = 0;
    while i < vec_len(o) { snap.push(vec_get(o, i)); i = i + 1; };
    return snap;
}

#[manual_drop]
fn own_restore(o: Vec<i32>, snap: Vec<i32>) -> i64 {
    // Reset o to snap state without dropping the whole backing store.
    // Branch isolation calls this in hot ownership paths; pop-all then
    // push-all preserved semantics but churned the Vec on every branch.
    let target_len: i64 = vec_len(snap);
    while vec_len(o) > target_len { o.pop(); };
    let mut i: i64 = 0;
    while i < target_len {
        if i < vec_len(o) { vec_set(o, i, vec_get(snap, i)); }
        else { o.push(vec_get(snap, i)); };
        i = i + 1;
    };
    // v0.4.3: if this sym is the currently-warm one, the aux hashmap
    // holds stale entries from inside-the-branch own_put_i calls.
    // Clear it and reset built_at so the next sym_get rebuilds from
    // the post-restore vec. If it's not warm, the next sym_get will
    // rebuild anyway when it switches the warm slot.
    let h: i64 = __nucleor_sym_aux_get(o);
    if h > 0 {
        hashmap_clear(h);
        __nucleor_sym_aux_set_built_at(o, 0);
    };
    return 0;
}

#[manual_drop]
fn is_tainted_type(tstr: str) -> i64 {
    // Hot path: was allocating a 7-byte substring per call.
    if str_starts_with(tstr, "tainted") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn taint_inner_type(t: str) -> str {
    let slen: i64 = str_len(t);
    if str_starts_with(t, "tainted<") == 1 { return str_substring(t, 8, slen - 1); };
    return t;
}

#[manual_drop]
fn tprof_new(enabled: i64) -> Vec<i32> {
    let mut prof: Vec<i32> = Vec::new();
    if enabled == 0 { return prof; };
    let mut i: i64 = 0;
    prof.push(1);
    while i < 12 {
        prof.push(0);
        i = i + 1;
    };
    return prof;
}

#[manual_drop]
fn tprof_enabled(prof: Vec<i32>) -> i64 {
    if vec_len(prof) == 0 { return 0; };
    return 1;
}

#[manual_drop]
fn strip_spaces(s: str) -> str {
    // Fast path: most type strings (the dominant caller) have no
    // whitespace. Scan once to detect; if clean, return the input
    // unchanged — no allocation. Only allocate the SB when we
    // actually have characters to strip. The previous version
    // always allocated a SB and a 1-byte substring per non-space
    // character; for a 12-byte type name that was 12 separate
    // allocations even when no whitespace was present.
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    let mut has_ws: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 32 || c == 9 || c == 10 || c == 13 { has_ws = 1; break; };
        i = i + 1;
    };
    if has_ws == 0 { return s; };
    let mut sb: i64 = sb_new();
    let mut j: i64 = 0;
    while j < slen {
        let c2: i64 = str_char_at(s, j);
        if c2 != 32 && c2 != 9 && c2 != 10 && c2 != 13 { sb_append_char_at(sb, s, j); };
        j = j + 1;
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn type_is_unit(t: str) -> i64 {
    if str_starts_with(t, "unit<") == 1 { return 1; };
    return 0;
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
fn host_stack_link_flag() -> str {
    // Windows: clang-cl-style flag passed through to MSVC link.exe / lld-link.
    // POSIX: GNU ld accepts -z stacksize=N (in bytes). Both expand the main
    // thread stack to 16 MiB so deep recursion in the compiler works.
    //
    // v0.4.10 RFC-NRT-003 follow-on (Translate SPEC-2 Task 2 finding):
    // lld-link embeds wall-clock timestamps in the PE COFF header
    // (offset 0x108) by default, breaking byte-reproducible builds
    // even when the LLVM IR is byte-identical. This blocked SLSA-
    // Build-Level-3 attestation for the Translate team. /Brepro tells
    // lld-link to write a deterministic content-hash instead of a
    // timestamp, matching the SOURCE_DATE_EPOCH spirit.
    //
    // ELF: clang's lld can be deterministic, but the GNU `ld` that
    // ships on stock Debian/Ubuntu embeds a per-link build-id in the
    // ELF .note.gnu.build-id section by default. Two builds of
    // byte-identical IR therefore produce byte-different EXEs and
    // RFC-NRT-003 verify-reproducible (which compares EXE bytes)
    // fails. -Wl,--build-id=none drops the section entirely so the
    // EXE stays byte-deterministic across runs on the same machine.
    if host_is_windows() == 1 { return " -Wl,/STACK:16777216 -Wl,/Brepro"; };
    return " -Wl,-z,stacksize=16777216 -Wl,--build-id=none -lm -lpthread";
}

#[manual_drop]
fn module_graph_cache_id(src_path: str) -> str {
    // v0.3.135: NUC-FEEDBACK-007 — include compiler_version_label
    // so a binary upgrade invalidates the resolved-source cache
    // alongside the IR cache. Without this, a recompile after
    // a compiler bump would re-use cached resolved source from
    // before the lexer/parser fix landed.
    return content_hash(str_concat("module-graph-v2|", str_concat(compiler_version_label(), str_concat("|", sanitize(src_path)))));
}

#[manual_drop]
fn close_is_arg_position_char(c: i64) -> i64 {
    // v0.3.78 (T2.1/2/3 partial close): textual closure-hoisting is
    // now FULLY DISABLED. Pre-v0.3.78, this preprocessor hoisted
    // closures appearing after `(` or `,` into top-level fns, which
    // produced cryptic `@captured` link errors when the closure body
    // referenced any outer-scope variables (the textual layer has
    // no scope info to detect captures).
    //
    // The AST closure-literal path (kind 42 in lower_expr at line
    // ~9915) handles captures correctly via the v0.3.72 capture_set/
    // capture_get runtime infrastructure. Routing arg-position
    // closures through the AST path makes `v.map(|x| x * factor)`
    // work the same way as `let f = |x| x * factor; v.map(f)` —
    // the documented v1 boundary closes.
    //
    // The legacy comment about "indirect-call dispatch" no longer
    // applies — the AST kind 42 path correctly emits ir_fn_ptr +
    // capture_set sequence, which works in arg position because
    // kind 8 (trait method call) lowers each arg via lower_expr,
    // and lower_expr handles kind 42 by returning the fn pointer
    // register with capture_set already emitted into the current
    // block.
    return 0;
}

#[manual_drop]
fn cmd_accepts_source(cmd: str) -> i64 {
    if str_eq(cmd, "build") || str_eq(cmd, "build-fast") || str_eq(cmd, "build-strict") || str_eq(cmd, "build-shared") || str_eq(cmd, "run") || str_eq(cmd, "emit") || str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") || str_eq(cmd, "check") || str_eq(cmd, "audit") || str_eq(cmd, "policy") || str_eq(cmd, "certify") || str_eq(cmd, "translate") || str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "summary") || str_eq(cmd, "impact") || str_eq(cmd, "query") || str_eq(cmd, "graph") || str_eq(cmd, "perf") || str_eq(cmd, "evidence") || str_eq(cmd, "abi") || str_eq(cmd, "verify-reproducible") {
        return 1;
    };
    return 0;
}

#[manual_drop]
fn cmd_allows_output_name(cmd: str) -> i64 {
    if str_eq(cmd, "build") || str_eq(cmd, "build-fast") || str_eq(cmd, "build-strict") || str_eq(cmd, "build-shared") || str_eq(cmd, "run") || str_eq(cmd, "emit") || str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") || str_eq(cmd, "certify") || str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "verify-reproducible") {
        return 1;
    };
    return 0;
}

#[manual_drop]
fn run_clean_command(argc: i64) -> i64 {
    let mut cache_only: i64 = 0;
    let mut i: i64 = 2;
    while i < argc {
        if str_eq(args_get(i), "--cache") == 1 { cache_only = 1; };
        i = i + 1;
    };
    if cache_only == 1 {
        print("clean: removing compilation cache (target/.nuc_cache_v2/, .nuc_cache/)");
        host_remove_dir_quiet(str_concat("target", str_concat(host_target_path_sep(), ".nuc_cache_v2")));
        host_remove_dir_quiet(".nuc_cache");
        print("clean: done");
        return 0;
    };
    print("clean: removing build artifacts (target/, .nuc_cache/)");
    host_remove_dir_quiet("target");
    host_remove_dir_quiet(".nuc_cache");
    print("clean: done");
    return 0;
}

#[manual_drop]
fn str_from_i64(n: i64) -> str {
    if n == 0 { return "0"; };
    if n == 1 { return "1"; } else if n == 2 { return "2"; } else if n == 3 { return "3"; }
    else if n == 4 { return "4"; } else if n == 5 { return "5"; } else if n == 6 { return "6"; }
    else if n == 7 { return "7"; } else if n == 8 { return "8"; } else if n == 9 { return "9"; };
    if n == (0 - 1) { return "-1"; } else if n == (0 - 2) { return "-2"; } else if n == (0 - 3) { return "-3"; }
    else if n == (0 - 4) { return "-4"; } else if n == (0 - 5) { return "-5"; } else if n == (0 - 6) { return "-6"; }
    else if n == (0 - 7) { return "-7"; } else if n == (0 - 8) { return "-8"; } else if n == (0 - 9) { return "-9"; };
    // v0.3.146: handle i64::MIN specially. `0 - MIN_I64` overflows
    // back to MIN_I64 (because -MIN_I64 = MAX_I64 + 1, doesn't fit
    // in signed i64). Pre-fix, the `while val > 0` loop never executed
    // because val stayed negative — `s` ended as `""`, then the `n < 0`
    // branch prepended `"-"` and we returned just `"-"`. Any const-fold
    // that produced MIN_I64 (e.g. `i64::MAX + 1`) emitted invalid IR.
    // Detect MIN_I64 without using its literal: `n < -MAX_I64` is
    // only true when n == MIN_I64.
    let neg_max: i64 = 0 - 9223372036854775807;
    if n < neg_max { return "-9223372036854775808"; };
    let mut val: i64 = n;
    let mut is_neg: i64 = 0;
    if val < 0 { is_neg = 1; val = 0 - val; };
    let mut div: i64 = 1;
    let mut tmp: i64 = val;
    while tmp >= 10 {
        tmp = tmp / 10;
        div = div * 10;
    };
    let digits: str = "0123456789";
    let mut sb: i64 = sb_new_with_cap(21);
    if is_neg == 1 { sb_append(sb, "-"); };
    while div > 0 {
        let d: i64 = val / div;
        sb_append_char_at(sb, digits, d);
        val = val - d * div;
        div = div / 10;
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn parse_generic_params(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    // pos points at '<', returns (pos_after_>, list of param name strings).
    // T2.5 (v0.2.351): accepts lifetime parameters (`'a`, `'static`, etc.)
    // alongside type parameters. Lifetime params get prepended with `'`
    // in the returned list so downstream consumers can distinguish them
    // (today no consumer does, but the marker is preserved for T2.5b).
    let mut cp: i64 = pos + 1;
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 33 { break; };
        };
        if pk(tokens, cp) == 98 {
            // Lifetime param — store as `'<name>` for traceability.
            params.push(str_concat("'", pkv(tokens, cp)));
        } else if pk(tokens, cp) == 73 {
            // v0.7.10 (defensive halt): canonical Rust const-generic
            // params `<const N: usize>` (used in `struct Buf<const N:
            // usize> { data: [i64; N] }`, `fn id<const X: i32>() ->
            // i32 { X }`) pre-fix surfaced as wrong-class
            // `NR020: expected ',', got identifier` because
            // parse_generic_params treats `const` (token 73) as a
            // bare param name and then trips on the `:` + type that
            // follows. Halt cleanly with a workaround pointer
            // (use a regular fn-arg / a struct-decl-time const).
            print("ERROR: const-generic params `<const N: usize>` are not yet supported in Nucleor. Pre-v0.7.10 surfaced as wrong-class `NR020: expected ',', got identifier` because parse_generic_params treats `const` as a bare param name. Workaround: pass the value as a regular fn arg (`fn id(n: i32) -> i32 { n }`), or hard-code the value at the use site. For struct-level CT-params, see RFC-0034 first-pass (which uses `[N: usize]` syntax — different parser path, currently halted at v0.6.65). Tracked for forward-roadmap (full const-generic substrate is a v1.x ship needing const-eval + monomorphisation).");
            panic("nucleor: const-generic param `<const N: ...>` not yet supported (see ERROR diagnostic above)");
        } else {
            params.push(pkv(tokens, cp));
        };
        cp = cp + 1;
        // v0.4.103: trait-bound clause `<T: Addable>` / `<T: A + B>`.
        // Pre-fix this hit NR020 panic at the `:` token (42). Today
        // Nucleor's generics are type-passthrough — codegen emits one
        // monomorphic version regardless of bound — so the bound is
        // semantically a no-op at the IR level. Skip past `:` and
        // discard the bound expression up to the next `,` or `>`.
        // Closes audit doc-#1 §8 (parse-side). A future bound-enforcing
        // pass would consume + record these bounds; for now they parse
        // cleanly and the binary behaves as if the bound were omitted
        // (already validated: `<T>(a: T, b: T) -> T { a + b }` works).
        if pk(tokens, cp) == 42 {
            cp = cp + 1; // skip ':'
            // v0.4.130: capture each bound trait name as a `?<name>`
            // entry alongside the param name. Pre-v0.4.103 the bound
            // clause was an NR020 parse error; v0.4.103 parse-skipped
            // it (no signal); now we store it so a later type-check
            // pass can verify the trait exists / has at least one
            // impl. Multiple bounds (`<T: A + B>`) all get `?A`,
            // `?B` entries.
            //
            // v0.7.69 (defensive halt — Rust opt-out trait bound
            // `?Sized`, used to relax the implicit Sized bound on
            // generic params so they accept DSTs like `str`/`[T]`).
            // Pre-fix the `?` token (97) was consumed silently by the
            // bound walker and the trailing `Sized` was stored as a
            // regular `?Sized` marker — visually identical to the
            // already-prefixed v0.4.130 storage convention but
            // semantically wrong: adopters expect Nucleor to relax
            // its Sized requirement, not silently keep it. Nucleor
            // has no DST substrate yet, so silent acceptance is a
            // wrong-class hazard. Halt cleanly and tell users the
            // bound is a no-op for now (everything is Sized).
            if pk(tokens, cp) == 97 {
                print("ERROR: opt-out trait bounds `?Sized` (and `?Trait` in general) are not yet supported in Nucleor. Pre-v0.7.69 the `?` token was silently dropped at the bound parser and the trailing `Sized` was stored as a regular bound marker, so adopter intent — \"this generic accepts DSTs / unsized types\" — was lost without signal. Workaround: drop the `?Sized` bound; Nucleor's monomorphic / i64-everywhere ABI assumes every generic param is sized today, so the bound is a no-op. Tracked for forward-roadmap (RFC-0027 lifetime/quantifier substrate plus DST lowering).");
                panic("nucleor: opt-out trait bound `?Sized` not yet supported (see ERROR diagnostic above)");
            };
            while pk(tokens, cp) != 33 && pk(tokens, cp) != 44 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 1 {
                    let bname: str = pkv(tokens, cp);
                    if str_len(bname) > 0 { params.push(str_concat("?", bname)); };
                };
                cp = cp + 1;
            };
        };
    };
    cp = cp + 1; // skip >
    return pr(cp, params);
}

#[manual_drop]
fn parse_for_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos is after 'for', pointing at variable name
    // v0.6.59 (probe finding 2026-05-01-rust-syntax-translation-
    // fidelity-audit, tuple-destruct-in-for row): canonical Rust
    // `for (k, v) in &map { ... }` and `for (i, x) in items.iter()
    // .enumerate() { ... }` pre-fix saw `(` (token 50) where the
    // parser expected an identifier, then `in` where it expected
    // some other token, surfacing as `error[NR020]: parse error at
    // byte N: expected token 57, got identifier` — wrong-class.
    // Halt at parse with a clean diag pointing at the workaround
    // (use a tuple binding via let after destructuring inside the
    // body). Forward-roadmap: full tuple-pattern parse in for-head.
    if pk(tokens, pos) == 50 {
        print("ERROR: tuple-destructuring patterns in `for` loop heads (e.g. `for (k, v) in &map { ... }`) are not yet supported in Nucleor. Pre-v0.6.59 the parser rejected with `error[NR020]: parse error ... expected token 57, got identifier` — wrong-class. Workaround: bind a single name and destructure in the body — `for kv in &map { let k: KT = kv.0; let v: VT = kv.1; ... }`. Tracked for forward-roadmap (full tuple-pattern in for-head).");
        panic("nucleor: tuple-destructuring in `for` head not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.27 (defensive halt — Rust ref-pattern in for-loop binding
    // position: `for &x in &v { ... }`, `for &mut x in &mut v { ... }`).
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse error:
    // expected token 57 (`in`), got identifier` because parse_for_stmt
    // tried to read `&` as the binding name. Workaround: drop the `&`
    // — Nucleor's i64-everywhere ABI passes everything by value, so
    // `for x in &v` already binds the same observable shape.
    if pk(tokens, pos) == 82 {
        let mut ref_form_v727: str = "&";
        if pk(tokens, pos + 1) == 12 { ref_form_v727 = "&mut "; };
        print(str_concat("ERROR: ref-pattern `", str_concat(ref_form_v727, str_concat("<binding>` in a `for` loop binding position (e.g. `for ", str_concat(ref_form_v727, "x in &v { ... }`) is not yet supported in Nucleor. Pre-v0.7.27 surfaced as wrong-class `error[NR020]: expected token 57 (in), got identifier` because parse_for_stmt tried to read `&` as the binding name.")))));
        print(str_concat("       Workaround: drop the `", str_concat(ref_form_v727, "` — Nucleor's i64-everywhere ABI passes everything by value, so `for x in &v { ... }` already binds the same observable shape. Tracked for forward-roadmap (ref-pattern in for-head arrives with v1 borrow-checker).")));
        panic(str_concat("nucleor: ref-pattern `", str_concat(ref_form_v727, "<binding>` in `for` head not yet supported (see ERROR diagnostic above)")));
    };
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 57); // expect 'in'
    let mut sr: Vec<i32> = parse_expr(tokens, cp, pool);
    cp = pr_pos(sr);
    if pk(tokens, cp) == 58 {
        let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); // end expr
        cp = expect_tok(tokens, pr_pos(er), 52); // expect '{'
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53); // expect '}'
        return pr(cp, mk5(pool, 28, name, pr_val(sr), pr_val(er), pr_val(br)));
    };
    if pk(tokens, cp) == 96 {
        // ..= inclusive: synthesize end+1 expression so existing exclusive
        // for-loop codegen handles it. Wrap end in (end + 1).
        let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool);
        let one_node: i64 = mk2(pool, 1, 1);
        let plus_node: i64 = mk4(pool, 4, 20, pr_val(er), one_node);
        cp = expect_tok(tokens, pr_pos(er), 52);
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53);
        return pr(cp, mk5(pool, 28, name, pr_val(sr), plus_node, pr_val(br)));
    };
    cp = expect_tok(tokens, cp, 52); // expect '{'
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53); // expect '}'
    return pr(cp, mk4(pool, 49, name, pr_val(sr), pr_val(br)));
}

#[manual_drop]
fn parse_enum_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'enum', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: enum Name<T> { ... }
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    // v0.7.58: accept `where`-clause on enum decl, sister to v0.6.46
    // struct/fn where-clause acceptance. Pre-v0.7.57 this surfaced as
    // wrong-class NR020; v0.7.57 halted cleanly; v0.7.58 promotes the
    // halt to a feature acceptance — the bound is skipped (same as
    // struct/fn where-clauses do today; bounds aren't enforced anyway
    // until the v1 trait-checker substrate lands). Adopters porting
    // canonical Rust no longer need to hoist bounds into the inline
    // generic param list as a workaround.
    cp = skip_where_clause(tokens, cp);
    cp = expect_tok(tokens, cp, 52); // {
    let mut variants: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(variants) > 0 && pk(tokens, cp) == 44 { cp = cp + 1; };
        if pk(tokens, cp) == 53 || pk(tokens, cp) == 0 { break; };
        let vname: i64 = pkv(tokens, cp); cp = cp + 1;
        // v0.6.35 (probe finding 2026-05-01-enum-discriminant-segfaults-
        // compiler): pre-fix `enum X { A = 5 }` (canonical Rust explicit-
        // discriminant syntax) crashed the compiler with SEGFAULT inside
        // the type/ownership pass — the parser fell through `= 5` and
        // downstream passes dereferenced bad state. Halt at parse-time
        // with a clean error pointing at the workaround. Real explicit-
        // discriminant lowering is a separate ship (needs the enum AST
        // to carry per-variant i64 values + the IR-emit path to
        // propagate them to match-arm dispatch).
        if pk(tokens, cp) == 40 {
            print(str_concat("error[NR035]: explicit enum discriminants `enum ", str_concat(name, str_concat(" { ", str_concat(vname, " = N }")))));
            print("  not yet supported in v0.6 — pre-v0.6.35 this segfaulted the compiler with no diagnostic. Real explicit-discriminant lowering needs the enum AST to carry per-variant i64 values plus IR-emit propagation to match-arm dispatch (forward-roadmap).");
            print("  Workaround: drop the `= N` and rely on order-based discriminants. `enum Code { OK, WARN, ERR }` lowers to discriminants 0, 1, 2 in order (matching the most common Rust C-style enum pattern). If you need specific values for FFI / wire-protocol compatibility, build a separate const table (`const OK_CODE: i64 = 0;` etc.) until explicit-discriminant support lands.");
            panic(str_concat("nucleor: explicit enum discriminants not implemented; see ERROR diagnostic for workarounds: ", str_concat(name, str_concat("::", vname))));
        };
        let mut ptypes: Vec<i32> = Vec::new();
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
                if vec_len(ptypes) > 0 {
                    cp = expect_tok(tokens, cp, 44);
                    if pk(tokens, cp) == 51 { break; };
                };
                let mut tr: Vec<i32> = parse_type(tokens, cp); ptypes.push(pr_val(tr)); cp = pr_pos(tr);
            };
            cp = cp + 1;
        } else if pk(tokens, cp) == 52 {
            cp = cp + 1;
            while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
                if vec_len(ptypes) > 0 {
                    cp = expect_tok(tokens, cp, 44);
                    if pk(tokens, cp) == 53 { break; };
                };
                let _fname: str = pkv(tokens, cp);
                cp = expect_tok(tokens, cp + 1, 42);
                let mut tr: Vec<i32> = parse_type(tokens, cp);
                ptypes.push(pr_val(tr));
                cp = pr_pos(tr);
            };
            cp = expect_tok(tokens, cp, 53);
        };
        // v0.6.27 (probe finding 2026-05-02-enum-duplicate-variant-names-
        // silently-accepted): `enum E { A, A, A }` was silently accepted
        // with all 3 variants kept distinct, and MATCH-001 confirmed
        // "1 arms for enum with 3 variants" — Nucleor saw them as
        // separate. Same for data variants `enum E { Foo(i64),
        // Foo(str) }`. Mirror Rust E0428 ("the name `A` is defined
        // multiple times") at decl-time.
        let mut dup_v_v062: i64 = 0;
        while dup_v_v062 < vec_len(variants) {
            let prior_var_v062: i64 = vec_get(variants, dup_v_v062);
            let prior_vname_v062: str = node_field(pool, prior_var_v062, 1);
            if str_eq(prior_vname_v062, vname) == 1 {
                print(str_concat("error[TYP-040]: duplicate enum variant `", str_concat(vname, str_concat("` in `enum ", str_concat(name, "` (Rust E0428)."))))));
                print("  Pre-v0.6.27 Nucleor silently kept duplicate variants distinct, so `match` saw the enum as having more variants than the source written suggested (MATCH-001 fired with the wrong arm-count). Variant names must be unique within an enum.");
                print(str_concat("  Workaround: rename or remove the duplicate `", str_concat(vname, "`. If both shapes are needed (e.g. `Foo(i64)` and `Foo(str)`), give them distinct names (`FooInt`, `FooStr`) — Nucleor doesn't yet support trait-style overloaded variants.")));
                panic(str_concat("duplicate enum variant: ", str_concat(name, str_concat("::", vname))));
            };
            dup_v_v062 = dup_v_v062 + 1;
        };
        variants.push(mk3(pool, 37, vname, mk_list(pool, ptypes)));
    };
    cp = cp + 1;
    return pr(cp, mk4(pool, 36, name, mk_list(pool, variants), gparams));
}

#[manual_drop]
fn opt_dce_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic == 0 { return 0; };
    let last_op: i64 = ir_op(vec_get(insts, ic - 1));
    // This pass is block-local only. Once a block branches, its pure values may
    // still be consumed in successor blocks, so intra-block liveness is unsafe.
    if last_op == 21 || last_op == 22 { return 0; };
    // Build used-register set: scan all instructions for operand references
    let mut used: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        // Collect register operands that are used
        if op >= 2 && op <= 15 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 23 || op == 24 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        // Overflow-intrinsic arithmetic is side-effecting from the optimizer's
        // point of view because it emits a flag branch plus panic path.
        else if op == 35 || op == 36 || op == 37 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 17 { used.push(ir_op1(inst)); }
        else if op == 18 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        // v0.4.209: sext/zext/trunc ops use ir_op1 as source register.
        // Pre-fix DCE missed this and removed the source load when its
        // only consumer was a sext/zext, breaking typed-IR var-ref reads.
        else if op == 32 || op == 33 || op == 34 { used.push(ir_op1(inst)); }
        else if op == 20 { used.push(ir_op1(inst)); }
        else if op == 22 { used.push(ir_op1(inst)); }
        else if op == 28 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); used.push(ir_extra(inst)); }
        else if op == 30 { used.push(ir_op1(inst)); let cargs: Vec<i32> = vec_get(inst, 5); let mut ci: i64 = 0; while ci < vec_len(cargs) { used.push(vec_get(cargs, ci)); ci = ci + 1; }; }
        else if op == 19 || op == 31 {
            // Call: args are in the args Vec (index 5)
            let args: Vec<i32> = vec_get(inst, 5);
            let ac: i64 = vec_len(args);
            let mut ai: i64 = 0;
            while ai < ac { used.push(vec_get(args, ai)); ai = ai + 1; };
        };
        i = i + 1;
    };
    // Now remove dead instructions (rebuild insts list)
    let mut new_insts: Vec<i32> = Vec::new();
    let mut removed: i64 = 0;
    i = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        let mut keep: i64 = 1;
        // Only consider removing pure value-producing ops
        if op == 0 || (op >= 2 && op <= 15) || op == 17 || op == 23 || op == 24 || op == 26 || op == 27 || op == 28 || op == 29 || op == 32 || op == 33 || op == 34 {
            if d > 0 {
                // Check if d is in used set
                let mut found: i64 = 0;
                let uc: i64 = vec_len(used);
                let mut ui: i64 = 0;
                while ui < uc {
                    if vec_get(used, ui) == d { found = 1; ui = uc; };
                    ui = ui + 1;
                };
                if found == 0 { keep = 0; };
            };
        };
        if keep == 1 { new_insts.push(inst); }
        else { removed = removed + 1; };
        i = i + 1;
    };
    // Replace instruction list
    if removed > 0 { vec_set(blk, 1, new_insts); };
    return removed;
}

#[manual_drop]
fn opt_prop_block(blk: Vec<i32>) -> i64 {
    let mut cm: Vec<i32> = cmap_new();
    let mut sv: Vec<i32> = cmap_new();
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        if op == 0 { cmap_set(cm, d, ir_op1(inst)); }
        else if op == 18 {
            let val: i64 = ir_op1(inst);
            let ptr: i64 = ir_op2(inst);
            if cmap_has(cm, val) == 1 { cmap_set(sv, ptr, cmap_get(cm, val)); }
            else { cmap_set(sv, ptr, 0 - 9999999); };
        }
        else if op == 17 {
            let ptr: i64 = ir_op1(inst);
            if cmap_has(sv, ptr) == 1 {
                let cv: i64 = cmap_get(sv, ptr);
                if cv != 0 - 9999999 {
                    vec_set(inst, 0, 0);
                    vec_set(inst, 3, cv);
                    vec_set(inst, 4, 0);
                    vec_set(inst, 5, 0);
                    cmap_set(cm, d, cv);
                    count = count + 1;
                };
            };
        }
        else if op == 19 || op == 30 || op == 31 { sv = cmap_new(); };
        i = i + 1;
    };
    return count;
}

#[manual_drop]
fn opt_dead_store_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic == 0 { return 0; };
    let mut last_store: Vec<i32> = cmap_new();
    let mut dead: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        if op == 18 {
            let ptr: i64 = ir_op2(inst);
            if cmap_has(last_store, ptr) == 1 {
                let prev_idx: i64 = cmap_get(last_store, ptr);
                if prev_idx >= 0 { dead.push(prev_idx); };
            };
            cmap_set(last_store, ptr, i);
        }
        else if op == 17 {
            let ptr: i64 = ir_op1(inst);
            cmap_set(last_store, ptr, 0 - 1);
        }
        else if op == 19 || op == 20 || op == 21 || op == 22 || op == 30 || op == 31 {
            last_store = cmap_new();
        };
        i = i + 1;
    };
    if vec_len(dead) == 0 { return 0; };
    let mut new_insts: Vec<i32> = Vec::new();
    let mut removed: i64 = 0;
    i = 0;
    while i < ic {
        let mut is_dead: i64 = 0;
        let dc: i64 = vec_len(dead);
        let mut di: i64 = 0;
        while di < dc {
            if vec_get(dead, di) == i { is_dead = 1; di = dc; };
            di = di + 1;
        };
        if is_dead == 0 { new_insts.push(vec_get(insts, i)); }
        else { removed = removed + 1; };
        i = i + 1;
    };
    if removed > 0 { vec_set(blk, 1, new_insts); };
    return removed;
}

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
    // v0.4.90: Option/Result helpers all return i64 — NOT in is_void_ret.
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
fn emit_fn(f: Vec<i32>, pool: Vec<i32>, externs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let fname: str = ir_fn_name(f);
    let is_main: i64 = str_eq(fname, "main");
    if is_main == 1 {
        // main gets argc/argv and calls init_args before user body
        sb_append(sb, "define i64 @main(i32 %__argc, ptr %__argv) {\n");
        sb_append(sb, "bb.entry:\n");
        sb_append(sb, "  call void @__nucleor_init_args(i32 %__argc, ptr %__argv)\n");
    } else {
        sb_append(sb, "define i64 @"); sb_append(sb, fname); sb_append(sb, "(");
        let pc: i64 = ir_fn_param_count(f); let mut pi: i64 = 0;
        while pi < pc { if pi > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %p."); sb_append(sb, str_from_int(pi)); pi = pi + 1; };
        sb_append(sb, ") {\n");
    };
    // Emit entry-block allocas first (hoisted from loop/branch bodies)
    let ea: Vec<i32> = vec_get(f, 2);
    let eac: i64 = vec_len(ea);
    let bc: i64 = ir_fn_block_count(f); let mut bi: i64 = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        if bi == 0 {
            if is_main == 0 { sb_append(sb, "bb.entry:\n"); };
            // For main, bb.entry was already emitted above with init_args
            // Emit hoisted entry allocas before any other instructions
            let mut eai: i64 = 0;
            while eai < eac { emit_inst(vec_get(ea, eai), sb, pool, externs); eai = eai + 1; };
        }
        else { sb_append(sb, "L"); sb_append(sb, str_from_int(ir_block_label(blk))); sb_append(sb, ":\n"); };
        let ic: i64 = ir_block_inst_count(blk); let mut jj: i64 = 0;
        while jj < ic { emit_inst(ir_block_get_inst(blk, jj), sb, pool, externs); jj = jj + 1; };
        bi = bi + 1;
    };
    sb_append(sb, "}\n"); return sb_to_str(sb);
}

#[manual_drop]
fn nr_type_to_llvm(t: str) -> str {
    if str_eq(t, "str") { return "ptr"; };
    if str_eq(t, "ptr") { return "ptr"; };
    if str_eq(t, "void") { return "void"; };
    // Integer widths (RFC-0015 phase 2)
    if str_eq(t, "i8") { return "i8"; };
    if str_eq(t, "i16") { return "i16"; };
    if str_eq(t, "i32") { return "i32"; };
    if str_eq(t, "i64") { return "i64"; };
    if str_eq(t, "i128") { return "i128"; };
    if str_eq(t, "u8") { return "i8"; };
    if str_eq(t, "u16") { return "i16"; };
    if str_eq(t, "u32") { return "i32"; };
    if str_eq(t, "u64") { return "i64"; };
    if str_eq(t, "u128") { return "i128"; };
    // Pointer-width: 64-bit on x86_64/aarch64; treat as i64 for now,
    // RFC-0022 cross-compile will adjust per target triple.
    if str_eq(t, "isize") { return "i64"; };
    if str_eq(t, "usize") { return "i64"; };
    // Floats
    if str_eq(t, "f16") { return "half"; };
    if str_eq(t, "bf16") { return "bfloat"; };
    if str_eq(t, "f32") { return "float"; };
    if str_eq(t, "f64") { return "double"; };
    // FP8 — software-emulated; lower as i8 storage with conversion fns.
    if str_eq(t, "f8e4m3") { return "i8"; };
    if str_eq(t, "f8e5m2") { return "i8"; };
    // Char — Unicode scalar value, 32-bit
    if str_eq(t, "char") { return "i32"; };
    if str_eq(t, "bool") { return "i1"; };
    return "i64";
}

#[manual_drop]
fn iter_method_for_vec(mname: str) -> i64 {
    // T2.2 (v0.2.348): method names that map to the typed
    // `vec_<name>_i64` runtime helpers in
    // stdlib/runtime/nucleor_llvm_rt.c. Used by lower_expr's
    // method-dispatch path so `v.map(f)` lowers to
    // `vec_map_i64(v, f)` instead of the unwired `vec_map`.
    // Anything not in this set falls through to the existing
    // `vec_<method>` convention — preserves backward compat with
    // current `.push`, `.pop`, `.len`, `.get`, `.set`, etc.
    // v0.3.88: `.iter()` is an identity pass-through that lets users
    // write the Rust idiom `vec.iter().sum()`. Routes to vec_iter_i64
    // which returns the same Vec ptr. Without this, .iter() was
    // unwired and the chain failed at clang link.
    if str_eq(mname, "iter") == 1 { return 1; };
    if str_eq(mname, "map") == 1 { return 1; };
    if str_eq(mname, "filter") == 1 { return 1; };
    if str_eq(mname, "fold") == 1 { return 1; };
    if str_eq(mname, "each") == 1 { return 1; };
    if str_eq(mname, "sum") == 1 { return 1; };
    if str_eq(mname, "min") == 1 { return 1; };
    if str_eq(mname, "max") == 1 { return 1; };
    if str_eq(mname, "contains") == 1 { return 1; };
    if str_eq(mname, "index_of") == 1 { return 1; };
    if str_eq(mname, "reverse") == 1 { return 1; };
    if str_eq(mname, "sort") == 1 { return 1; };
    if str_eq(mname, "clone") == 1 { return 1; };
    if str_eq(mname, "clear") == 1 { return 1; };
    // v0.3.102: `.collect()` is the canonical Rust terminator for an
    // iterator chain (`v.iter().map(f).collect()`). It's an identity
    // pass-through here since the prior `.map` already returns a Vec.
    if str_eq(mname, "collect") == 1 { return 1; };
    // v0.3.108: `.count()` returns iterator length (mirrors Rust
    // Iterator::count). For Vec it's `v.len()` — runtime helper
    // is `__nucleor_vec_count_i64`, alias for vec_len in the C side.
    if str_eq(mname, "count") == 1 { return 1; };
    // v0.3.109: take/skip return fresh Vec views; any/all are
    // boolean predicate terminators. Each routes via iter_method_for_vec
    // → vec_<name>_i64 runtime helper.
    if str_eq(mname, "take") == 1 { return 1; };
    if str_eq(mname, "skip") == 1 { return 1; };
    if str_eq(mname, "any") == 1 { return 1; };
    if str_eq(mname, "all") == 1 { return 1; };
    // v0.4.101: `.chain` (audit doc-#1 §6 partial). Routes to
    // vec_chain_i64 runtime helper.
    if str_eq(mname, "chain") == 1 { return 1; };
    // v0.4.125: extended iter surface — position/product/step_by/
    // nth/reduce. Audit doc-#1 §6 closer (still partial, no full
    // Iterator trait — these are the most-reached-for methods).
    if str_eq(mname, "position") == 1 { return 1; };
    if str_eq(mname, "product") == 1 { return 1; };
    if str_eq(mname, "step_by") == 1 { return 1; };
    if str_eq(mname, "nth") == 1 { return 1; };
    if str_eq(mname, "reduce") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn enum_populate_sym(pool: Vec<i32>, enums: Vec<i32>, sym: Vec<i32>) -> i64 {
    let mut ei: i64 = 0;
    while ei < vec_len(enums) {
        let e_nid: i64 = vec_get(enums, ei);
        let ename: str = node_field(pool, e_nid, 1);
        let vlist: i64 = node_field(pool, e_nid, 2);
        let vcnt: i64 = list_len(pool, vlist);
        let mut vi: i64 = 0;
        while vi < vcnt {
            let v_nid: i64 = list_get(pool, vlist, vi);
            let vname: str = node_field(pool, v_nid, 1);
            let ptypes: i64 = node_field(pool, v_nid, 2);
            let pcount: i64 = list_len(pool, ptypes);
            sym_set(sym, str_concat("__etag_", str_concat(ename, str_concat("_", vname))), vi);
            sym_set(sym, str_concat("__eargs_", str_concat(ename, str_concat("_", vname))), pcount);
            // v0.3.185/186: store ALL payload types for variant-aware
            // print() dispatch. Catches `Msg::Text(s)` where Text(str)
            // and multi-payload `Variant(str, i64)` where each binding
            // gets its own type. Stored as __epayload<i>_<ename>_<vname>.
            // ptypes elements are TYPE STRINGS (per parse_enum_decl)
            // stored directly in the list -- not nodes. list_get
            // returns the string value; no node_field unwrap.
            let mut pi: i64 = 0;
            while pi < pcount {
                let pt: str = list_get(pool, ptypes, pi);
                if str_len(pt) > 0 {
                    sym_set(sym, str_concat("__epayload", str_concat(str_from_int(pi), str_concat("_", str_concat(ename, str_concat("_", vname))))), pt);
                };
                pi = pi + 1;
            };
            vi = vi + 1;
        };
        ei = ei + 1;
    };
    sym_set(sym, "__etag_Option_Some", 0);
    sym_set(sym, "__eargs_Option_Some", 1);
    sym_set(sym, "__etag_Option_None", 1);
    sym_set(sym, "__eargs_Option_None", 0);
    // v0.3.91 (revised): Result variant tags must match the stdlib
    // `result.nr` convention (Ok=1, Err=0) so the `?` operator works
    // for BOTH compiler-builtin Ok(x)/Err(x) AND
    // stdlib result_ok(x)/result_err(x) calls. Pre-revision had
    // Ok=0/Err=1, which conflicted with the stdlib (used by the
    // existing tests/lang/try_op.nr) — flipping etag tag values is
    // the correct fix; reverting the `?` lowering too. Both Result
    // construction shapes now produce Vec<i32> [tag, payload] with
    // tag=1 on Ok, tag=0 on Err.
    sym_set(sym, "__etag_Result_Ok", 1);
    sym_set(sym, "__eargs_Result_Ok", 1);
    sym_set(sym, "__etag_Result_Err", 0);
    sym_set(sym, "__eargs_Result_Err", 1);
    return 0;
}

#[manual_drop]
fn diag_add_ex(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, fn_name: str, line: i64, col: i64, related_id: str) -> i64 {
    // v0.6.38 (probe finding 2026-05-01-typ-006-triple-emit-on-call-
    // site, sister to MATCH-001/TYP-001 dual-emit closure in v0.5.18):
    // dedup at the emit site. Some type-check passes run their per-
    // call type-mismatch check more than once (call site visited
    // through multiple paths — postfix, direct-call dispatch, generic-
    // bound resolution). Each visit re-emitted the same diag; adopters
    // saw a triple error wall for one call.
    //
    // Walk existing diags; if a row already has identical (code, message,
    // fn_name, line, col), skip the emit. Severity and checker are
    // included in the comparison via code (codes are unique per checker).
    let dn_v064: i64 = vec_len(diags);
    let mut di_v064: i64 = 0;
    while di_v064 < dn_v064 {
        let prior_d: Vec<i32> = vec_get(diags, di_v064);
        let pcode: str = vec_get(prior_d, 2);
        if str_eq(pcode, code) == 1 {
            let pmsg: str = vec_get(prior_d, 3);
            let pfn: str = vec_get(prior_d, 4);
            let pline: i64 = vec_get(prior_d, 5);
            let pcol: i64 = vec_get(prior_d, 6);
            if pline == line && pcol == col && str_eq(pfn, fn_name) == 1 && str_eq(pmsg, message) == 1 {
                return vec_len(diags);
            };
        };
        di_v064 = di_v064 + 1;
    };
    let mut d: Vec<i32> = Vec::new();
    d.push(severity); d.push(checker); d.push(code); d.push(message); d.push(fn_name); d.push(line);
    d.push(col); d.push(related_id);
    // Auto-generate suggestions based on error code
    let mut sug_msg: str = "";
    let mut sug_app: str = "Unspecified";
    if str_eq(code, "OWN-001") { sug_msg = "Consider cloning the value before passing it, or restructure to avoid the second use"; sug_app = "MaybeIncorrect"; };
    if str_eq(code, "TNT-001") { sug_msg = "Sanitize the tainted data before passing to the sensitive function: sanitize(value)"; sug_app = "HasPlaceholders"; };
    if str_eq(code, "EFF-001") { sug_msg = "Declare the required effect in the caller row, or remove the side-effecting call"; sug_app = "MaybeIncorrect"; };
    d.push(sug_msg); // index 8
    d.push(sug_app); // index 9
    // Child note (for ownership: "moved here")
    d.push(""); // index 10: child_message
    d.push(0);  // index 11: child_line
    diags.push(d);
    return vec_len(diags);
}

#[manual_drop]
fn expand_actor_decl_keyword(src: str) -> str {
    if sendable_source_has_actor_decl(src) == 0 { return src; };
    let mut sb: i64 = sb_new();
    let mut actors: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
        } else {
            let actor_name: str = sendable_actor_decl_name_at(src, p);
            if str_len(actor_name) > 0 {
                sb_append(sb, "struct");
                actors.push(actor_name);
                p = p + 5;
            } else {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
        };
    };
    if vec_len(actors) > 0 {
        sb_append(sb, "\n");
        let mut i: i64 = 0;
        while i < vec_len(actors) {
            sb_append(sb, "//__NUC35A:");
            sb_append(sb, vec_get(actors, i));
            sb_append(sb, "\n");
            i = i + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn sendable_actor_vars(source: str, actor_name: str) -> Vec<i32> {
    // v0.6.24 perf fix: original loop allocated `str_substring(source, p, slen)`
    // per iteration before str_index_of — same O(slen²) class as
    // sendable_type_forced_not. Replaced with single linear scan using
    // str_eq_at to find each `let ` / `let mut ` position directly.
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i + 4 <= slen {
        if str_eq_at(source, i, "let ") == 1 {
            let mut q: i64 = i + 4;
            if q + 4 <= slen && str_eq_at(source, q, "mut ") == 1 { q = q + 4; };
            let ns: i64 = q;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
            if q > ns {
                let vname: str = str_substring(source, ns, q);
                while q < slen && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
                if q < slen && str_char_at(source, q) == 58 {
                    q = q + 1;
                    let ts: i64 = q;
                    while q < slen && str_char_at(source, q) != 61 && str_char_at(source, q) != 59 && str_char_at(source, q) != 10 { q = q + 1; };
                    let ty: str = type_base_name(str_trim(str_substring(source, ts, q)));
                    if str_eq(ty, actor_name) == 1 { out.push(vname); };
                };
            };
            i = q + 1;
        } else {
            i = i + 1;
        };
    };
    return out;
}

#[manual_drop]
fn builtin_rtype(name: str) -> str {
    if str_eq(name, "str_len") == 1 || str_eq(name, "str_char_at") == 1 || str_eq(name, "str_char_at_strict") == 1 { return "i64"; };
    if str_eq(name, "str_substring") == 1 || str_eq(name, "str_substring_strict") == 1 || str_eq(name, "str_trim") == 1 || str_eq(name, "str_trim_start") == 1 || str_eq(name, "str_trim_end") == 1 { return "str"; };
    if str_eq(name, "args_get") == 1 || str_eq(name, "file_read_string") == 1 || str_eq(name, "file_read_string_or_panic") == 1 { return "str"; };
    if str_eq(name, "args_count") == 1 || str_eq(name, "env_has") == 1 || str_eq(name, "process_id") == 1 || str_eq(name, "os_family") == 1 || str_eq(name, "os_pointer_width") == 1 || str_eq(name, "path_is_absolute") == 1 || str_eq(name, "fs_exists") == 1 || str_eq(name, "fs_is_file") == 1 || str_eq(name, "fs_is_dir") == 1 || str_eq(name, "fs_size") == 1 || str_eq(name, "fs_mtime") == 1 || str_eq(name, "file_bytes_equal") == 1 || str_eq(name, "system") == 1 { return "i64"; };
    if str_eq(name, "env_get") == 1 || str_eq(name, "env_get_or") == 1 || str_eq(name, "getcwd") == 1 || str_eq(name, "getenv") == 1 || str_eq(name, "chr") == 1 || str_eq(name, "fs_join") == 1 || str_eq(name, "fs_basename") == 1 || str_eq(name, "fs_dirname") == 1 || str_eq(name, "fs_extension") == 1 || str_eq(name, "fs_temp_dir") == 1 || str_eq(name, "fs_current_dir") == 1 || str_eq(name, "fs_canonicalize") == 1 || str_eq(name, "path_separator") == 1 || str_eq(name, "path_normalize") == 1 || str_eq(name, "path_with_extension") == 1 || str_eq(name, "path_strip_extension") == 1 { return "str"; };
    if str_eq(name, "sqrt") == 1 || str_eq(name, "sin") == 1 || str_eq(name, "cos") == 1 || str_eq(name, "pow") == 1 || str_eq(name, "floor") == 1 || str_eq(name, "ceil") == 1 || str_eq(name, "round") == 1 || str_eq(name, "exp") == 1 || str_eq(name, "log") == 1 || str_eq(name, "tanh") == 1 || str_eq(name, "tanh_act") == 1 || str_eq(name, "fabs") == 1 || str_eq(name, "fmod") == 1 || str_eq(name, "f64_from_bits") == 1 { return "f64"; };
    if str_eq(name, "f64_to_bits") == 1 { return "i64"; };
    if str_eq(name, "f64_to_i32") == 1 { return "i32"; };
    if str_eq(name, "now_ms") == 1 || str_eq(name, "sleep_ms") == 1 || str_eq(name, "sleep_us") == 1 || str_eq(name, "time_monotonic_ms") == 1 || str_eq(name, "time_monotonic_ns") == 1 || str_eq(name, "time_monotonic_us") == 1 || str_eq(name, "time_wall_ms") == 1 || str_eq(name, "time_wall_ns") == 1 || str_eq(name, "time_wall_seconds") == 1 || str_eq(name, "time_wall_us") == 1 || str_eq(name, "time_year") == 1 || str_eq(name, "time_month") == 1 || str_eq(name, "time_day") == 1 || str_eq(name, "time_hour") == 1 || str_eq(name, "time_minute") == 1 || str_eq(name, "time_second") == 1 || str_eq(name, "time_weekday") == 1 || str_eq(name, "time_day_of_year") == 1 || str_eq(name, "time_elapsed_ms") == 1 { return "i64"; };
    if str_eq(name, "ambient_scheduler") == 1 { return "SchedulerCap"; };
    if str_eq(name, "ambient_random") == 1 { return "RandomCap"; };
    if str_eq(name, "random_uniform") == 1 { return "f64"; };
    if str_eq(name, "random_normal") == 1 { return "f64"; };
    if str_eq(name, "arena_new") == 1 { return "Arena"; };
    if str_eq(name, "arena_alloc") == 1 { return "&i64"; };
    if str_eq(name, "device_alloc") == 1 { return "DeviceBuffer"; };
    if str_eq(name, "device_transfer") == 1 { return "DeviceBuffer"; };
    if str_eq(name, "tensor_view") == 1 { return "i64"; };
    if str_eq(name, "max_depth_enter") == 1 || str_eq(name, "max_depth_exit") == 1 { return "i64"; };
    if str_eq(name, "channel") == 1 { return "i64"; };
    if str_eq(name, "rwlock_new") == 1 || str_eq(name, "rwlock_read") == 1 || str_eq(name, "rwlock_write") == 1 || str_eq(name, "rwlock_unlock") == 1 { return "i64"; };
    if str_eq(name, "cancel_token_new") == 1 || str_eq(name, "cancel_token_cancel") == 1 { return "i64"; };
    if is_atomic_ordered_builtin(name) == 1 { return "i64"; };
    if str_eq(name, "print") == 1 || str_eq(name, "print_int") == 1 || str_eq(name, "print_f64") == 1 || str_eq(name, "print_bool") == 1 || str_eq(name, "putchar") == 1 { return "void"; };
    if str_eq(name, "rng_seed") == 1 || str_eq(name, "device_free") == 1 || str_eq(name, "arena_destroy") == 1 || str_eq(name, "arena_reset") == 1 { return "void"; };
    // v0.6.42 (probe finding 2026-04-30-vec-pop-void-coerce-to-zero):
    // vec_pop is a void-returning runtime helper (removes the last
    // element, returns nothing). Pre-fix builtin_rtype returned ""
    // for it, so `let x = vec_pop(v)` silently bound 0 (TYP-021
    // didn't fire because the rtype was unknown, not void). Adopters
    // got a 0 they couldn't distinguish from a popped 0. Naming
    // vec_pop here makes TYP-021 fire at the let-binding site with
    // the canonical "vec_pop returns void; use v.last() before pop()"
    // workaround.
    if str_eq(name, "vec_pop") == 1 { return "void"; };
    return "";
}

#[manual_drop]
fn type_dynamic_helper(name: str) -> i64 {
    // v0.6.54 (perf-slice integration from Nucleor_OSS_v631_perf_slice):
    // first-char dispatch — was 41-entry linear chain run per kind-7
    // call-site type-check.
    if str_len(name) == 0 { return 0; };
    let c0: i64 = str_char_at(name, 0);
    if c0 == 100 {
        if str_eq(name, "diag_get") == 1 { return 1; };
        return 0;
    };
    if c0 == 105 {
        if str_eq(name, "ir_op") == 1 { return 1; };
        if str_eq(name, "ir_dest") == 1 { return 1; };
        if str_eq(name, "ir_op1") == 1 { return 1; };
        if str_eq(name, "ir_op2") == 1 { return 1; };
        if str_eq(name, "ir_extra") == 1 { return 1; };
        if str_eq(name, "ir_block_label") == 1 { return 1; };
        if str_eq(name, "ir_block_get_inst") == 1 { return 1; };
        if str_eq(name, "ir_fn_name") == 1 { return 1; };
        if str_eq(name, "ir_fn_param_count") == 1 { return 1; };
        if str_eq(name, "ir_fn_get_block") == 1 { return 1; };
        if str_eq(name, "ir_const_int") == 1 { return 1; };
        return 0;
    };
    if c0 == 106 {
        if str_starts_with(name, "json_") == 1 { return 1; };
        return 0;
    };
    if c0 == 108 {
        if str_eq(name, "list_get") == 1 { return 1; };
        if str_eq(name, "lx_reg") == 1 { return 1; };
        if str_eq(name, "lx_blk") == 1 { return 1; };
        return 0;
    };
    if c0 == 109 {
        if str_eq(name, "mk2") == 1 { return 1; };
        if str_eq(name, "mk3") == 1 { return 1; };
        if str_eq(name, "mk4") == 1 { return 1; };
        if str_eq(name, "mk5") == 1 { return 1; };
        if str_eq(name, "mk6") == 1 { return 1; };
        if str_eq(name, "mk_list") == 1 { return 1; };
        if str_starts_with(name, "map_") == 1 { return 1; };
        return 0;
    };
    if c0 == 110 {
        if str_eq(name, "node_field") == 1 { return 1; };
        if str_starts_with(name, "nuc_json_") == 1 { return 1; };
        if str_starts_with(name, "nuc_graph_") == 1 { return 1; };
        if str_starts_with(name, "nuc_bm25_") == 1 { return 1; };
        if str_starts_with(name, "nuc_hnsw_") == 1 { return 1; };
        if str_starts_with(name, "nuc_emb_") == 1 { return 1; };
        if str_starts_with(name, "nuc_sym_") == 1 { return 1; };
        if str_starts_with(name, "nuc_stat_") == 1 { return 1; };
        return 0;
    };
    if c0 == 111 {
        if str_eq(name, "own_get_type") == 1 { return 1; };
        if str_eq(name, "own_set_type") == 1 { return 1; };
        if str_eq(name, "own_get_s") == 1 { return 1; };
        return 0;
    };
    if c0 == 112 {
        if str_eq(name, "pr") == 1 { return 1; };
        if str_eq(name, "pkv") == 1 { return 1; };
        if str_eq(name, "pr_pos") == 1 { return 1; };
        if str_eq(name, "pr_val") == 1 { return 1; };
        return 0;
    };
    if c0 == 115 {
        if str_eq(name, "sym_get") == 1 { return 1; };
        if str_eq(name, "sym_set") == 1 { return 1; };
        if str_eq(name, "smap_get") == 1 { return 1; };
        if str_eq(name, "smap_set") == 1 { return 1; };
        if str_eq(name, "sig_plist") == 1 { return 1; };
        if str_eq(name, "sig_add") == 1 { return 1; };
        if str_eq(name, "sig_rtype") == 1 { return 1; };
        if str_eq(name, "sig_is_extern") == 1 { return 1; };
        return 0;
    };
    if c0 == 116 {
        if str_eq(name, "tok_type") == 1 { return 1; };
        if str_eq(name, "tok_val") == 1 { return 1; };
        if str_eq(name, "tenv_get") == 1 { return 1; };
        if str_eq(name, "tenv_set") == 1 { return 1; };
        return 0;
    };
    if c0 == 118 {
        if str_starts_with(name, "vec_") == 1 { return 1; };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn closure_collect_capture_stmt(pool: Vec<i32>, nid: i64, sym: Vec<i32>, params: i64, caps: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 4), sym, params, caps);
        return 0;
    };
    if kind == 21 {
        // FnMut capture writeback: assignment to a captured outer
        // variable is allowed. The lowerer writes the local assignment
        // through to the capture table, and direct closure-variable
        // calls refresh the caller's slot from that table afterward.
        let lhs: i64 = node_field(pool, nid, 1);
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    if kind == 22 || kind == 25 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 23 {
        closure_collect_capture_expr(pool, nid, sym, params, caps);
        return 0;
    };
    if kind == 85 {
        // v0.8.33 — tuple-destructure-in-let capture walk.
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    // v0.3.72: bare-expression body fall-through. When a closure
    // literal's body is `|x| EXPR` (no braces), the parser stores
    // EXPR as the single body element — but EXPR has an expression
    // kind (binop/call/index/etc.), not a stmt kind. Pre-v0.3.72,
    // closure_collect_capture_stmt silently returned without walking,
    // missing every capture in inline closures (typically those
    // passed to .map / .filter / .fold). The let-bound case
    // (`let f = |x| x + outer;`) accidentally worked because the
    // outer let-stmt's RHS handler took a different path. Without
    // this, every `v.map(|x| x * factor)` lowered to a closure body
    // that referenced `@factor` as a missing global symbol —
    // unresolved external at link time.
    closure_collect_capture_expr(pool, nid, sym, params, caps);
    return 0;
}

#[manual_drop]
fn extract_directives(raw_source: str, base_dir: str) -> Vec<i32> {
    // Returns vec: [0] = link flags string, [1] = cfile list string, [2] = libpath flags string
    let mut links: i64 = sb_new();
    let mut cfiles: i64 = sb_new();
    let mut libpaths: i64 = sb_new();
    let slen: i64 = str_len(raw_source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw_source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(raw_source, lp) == 32 || str_char_at(raw_source, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        if line_len >= 6 && str_char_at(raw_source, lp) == 35 {
            if line_len >= 15 && str_eq_at(raw_source, lp, "#link_windows ") == 1 {
                // v0.8.323 PKG-1/R06 fix: Windows-only system library
                // dependency. Emitted only when targeting Windows so
                // POSIX hosts don't try to resolve -lws2_32 etc.
                let mut qp: i64 = lp + 14;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    if host_is_windows() == 1 {
                        sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                    };
                };
            } else if line_len >= 13 && str_eq_at(raw_source, lp, "#link_posix ") == 1 {
                // v0.8.323 PKG-1/R06 fix: POSIX-only system library
                // dependency. Symmetric counterpart to #link_windows.
                let mut qp: i64 = lp + 12;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    if host_is_windows() == 0 {
                        sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                    };
                };
            } else if line_len >= 7 && str_eq_at(raw_source, lp, "#link ") == 1 {
                let mut qp: i64 = lp + 6;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                };
            } else if line_len >= 8 && str_eq_at(raw_source, lp, "#cfile ") == 1 {
                let mut qp: i64 = lp + 7;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    let cf_path: str = str_substring(raw_source, ps, pe);
                    let cflen: i64 = str_len(cf_path);
                    let mut cf_abs: i64 = 0;
                    if cflen >= 1 && str_char_at(cf_path, 0) == 47 { cf_abs = 1; };
                    if cflen >= 2 && str_char_at(cf_path, 1) == 58 { cf_abs = 1; };
                    sb_append(cfiles, " ");
                    if cf_abs == 1 { sb_append(cfiles, cf_path); }
                    else { sb_append(cfiles, str_concat(base_dir, cf_path)); };
                };
            } else if line_len >= 10 && str_eq_at(raw_source, lp, "#libpath ") == 1 {
                let mut qp: i64 = lp + 9;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(libpaths, " -L"); sb_append(libpaths, str_concat(base_dir, str_substring(raw_source, ps, pe)));
                };
            };
        };
        p = eol + 1;
    };
    let mut result: Vec<i32> = Vec::new();
    result.push(sb_to_str(links));
    result.push(sb_to_str(cfiles));
    result.push(sb_to_str(libpaths));
    return result;
}

#[manual_drop]
fn expand_closures(src: str) -> str {
    return src;
    let mut prepend: i64 = sb_new();
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    let mut idx: i64 = 0;
    let src_id: str = content_hash(src);
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if c == 124 && close_is_arg_position_char(last_non_ws) == 1 {
            // Possible closure. Parse args between `|...|`.
            let arg_parse: Vec<i32> = close_parse_arg_list(src, p + 1, slen);
            let after_args: i64 = vec_get(arg_parse, 0);
            if after_args >= 0 {
                let mut args: Vec<i32> = Vec::new();
                let mut ai: i64 = 1;
                while ai < vec_len(arg_parse) {
                    args.push(vec_get(arg_parse, ai));
                    ai = ai + 1;
                };
                // Skip whitespace before body
                let mut bp: i64 = after_args;
                while bp < slen && (str_char_at(src, bp) == 32 || str_char_at(src, bp) == 9) { bp = bp + 1; };
                let body_end: i64 = close_parse_body_end(src, bp, slen);
                let body_text: str = str_substring(src, bp, body_end);
                // Synthesize fn name + emit
                let synth_name: str = str_concat("__closure_", str_concat(src_id, str_concat("_", str_from_int(idx))));
                idx = idx + 1;
                sb_append(prepend, close_synthesize_fn(synth_name, args, body_text));
                sb_append(sb, synth_name);
                p = body_end;
                last_non_ws = if p > 0 { str_char_at(src, p - 1) } else { 0 };
                continue;
            };
            // Not a closure — emit `|` as-is.
            sb_append(sb, "|");
            p = p + 1;
            last_non_ws = 124;
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            sb_append(sb, name);
            last_non_ws = str_char_at(name, str_len(name) - 1);
        } else {
            sb_append_char_at(sb, src, p);
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return str_concat(sb_to_str(prepend), sb_to_str(sb));
}

#[manual_drop]
fn priv_mangle_private_fns(src: str, file_id: str, private_names: Vec<i32>) -> str {
    // Token-aware identifier substitution. Walks src char-by-char,
    // identifies identifier tokens (alpha/_ followed by alnum/_),
    // and rewrites identifiers whose value is in private_names to
    // __priv_<file_id>__<name>. Skips: "..." string literals,
    // 'X' char literals, // ... line comments. Does NOT rewrite
    // identifiers preceded by `.` (field/method access).
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut priv_pos_v886: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while priv_pos_v886 < slen {
        let c: i64 = str_char_at(src, priv_pos_v886);
        if c == 47 && priv_pos_v886 + 1 < slen && str_char_at(src, priv_pos_v886 + 1) == 47 {
            // // line comment — copy through to newline
            let comment_start: i64 = priv_pos_v886;
            while priv_pos_v886 < slen && str_char_at(src, priv_pos_v886) != 10 { priv_pos_v886 = priv_pos_v886 + 1; };
            sb_append_range(sb, src, comment_start, priv_pos_v886);
            last_non_ws = 10;
        } else if c == 34 {
            // double-quoted string literal — copy with backslash escapes
            let str_start: i64 = priv_pos_v886;
            priv_pos_v886 = priv_pos_v886 + 1;
            while priv_pos_v886 < slen && str_char_at(src, priv_pos_v886) != 34 {
                if str_char_at(src, priv_pos_v886) == 92 && priv_pos_v886 + 1 < slen {
                    priv_pos_v886 = priv_pos_v886 + 2;
                } else {
                    priv_pos_v886 = priv_pos_v886 + 1;
                };
            };
            if priv_pos_v886 < slen { priv_pos_v886 = priv_pos_v886 + 1; };
            sb_append_range(sb, src, str_start, priv_pos_v886);
            last_non_ws = 34;
        } else if c == 39 {
            // single-quoted char literal
            let char_start: i64 = priv_pos_v886;
            priv_pos_v886 = priv_pos_v886 + 1;
            while priv_pos_v886 < slen && str_char_at(src, priv_pos_v886) != 39 {
                if str_char_at(src, priv_pos_v886) == 92 && priv_pos_v886 + 1 < slen {
                    priv_pos_v886 = priv_pos_v886 + 2;
                } else {
                    priv_pos_v886 = priv_pos_v886 + 1;
                };
            };
            if priv_pos_v886 < slen { priv_pos_v886 = priv_pos_v886 + 1; };
            sb_append_range(sb, src, char_start, priv_pos_v886);
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            // Identifier start — gather to the end and decide whether
            // to mangle. Also reject: numeric prefixes (handled
            // because is_alpha rejects digits; identifiers can't
            // start with digit) and identifiers preceded by `.`
            // (struct field / method access).
            let start: i64 = priv_pos_v886;
            let mut id_done: i64 = 0;
            while priv_pos_v886 < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, priv_pos_v886);
                if is_alnum(ch) == 1 || ch == 95 { priv_pos_v886 = priv_pos_v886 + 1; }
                else { id_done = 1; };
            };
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            if preceded_by_dot == 0 && priv_string_vec_contains_at(private_names, src, start, priv_pos_v886) == 1 {
                sb_append(sb, "__priv_");
                sb_append(sb, file_id);
                sb_append(sb, "__");
                sb_append_range(sb, src, start, priv_pos_v886);
            } else {
                sb_append_range(sb, src, start, priv_pos_v886);
            };
            last_non_ws = str_char_at(src, priv_pos_v886 - 1);
        } else {
            sb_append_char_at(sb, src, priv_pos_v886);
            // Track last non-whitespace so we can detect `.X` field
            // accesses through intervening whitespace too.
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            priv_pos_v886 = priv_pos_v886 + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn print_help() -> i64 {
    print(str_concat("Nucleor Compiler ", compiler_version_label()));
    print("The governance-native programming language");
    print("");
    print("Usage: nuc <command> [source.nr] [options]");
    print("");
    print("Build commands:");
    print("  init [name]            Scaffold a project with Nucleor.toml");
    print("  build [file]           Compile to native binary (ownership + type, cached)");
    print("  build-fast [file]      Alias of the fast core compile path");
    print("  build-strict [file]    Compile through the full delegated strict checker stack");
    print("  build-shared [file]    Compile a shared library (.dll/.lib) from `pub fn` exports");
    print("  run [file]             Compile and run");
    print("  emit [file]            Emit LLVM IR only (alias for --no-link)");
    print("  build-wasm [file]      Compile to WebAssembly (.wasm)");
    print("  build-ptx [file]       Compile to NVIDIA PTX (.ptx)");
    print("  verify-reproducible [file]  Build twice with --no-cache and assert byte-identical IR (RFC-NRT-003)");
    print("    --provenance <path>  Embed a SLSA JSON attestation in the .nucprov section (RFC-NRT-001)");
    print("    -o, --out <name>     Set output base name");
    print("    --emit llvm          Keep the LLVM IR artifact");
    print("    --no-link            Stop after writing target/<name>.ll");
    print("    --time-passes        Print per-phase compile timings");
    print("    --no-cache           Disable resolved-source and content-addressed LLVM caches");
    print("    --cache-stats        Print cache hit/miss counters for this build");
    print("");
    print("Developer commands:");
    print("  test [file]            Build and run @test / test_* functions");
    print("    --list               List discovered tests without running them");
    print("    --check-laws         Generate bounded checks for low-risk integer @law annotations");
    print("  bench [file]           Build once and benchmark repeated runs");
    print("    --iterations <n>     Number of measured runs (default 10)");
    print("    --warmup <n>         Number of warmup runs before timing (default 1)");
    print("  perf [file]            Compile-path performance analysis");
    print("    --json               Output machine-readable perf data");
    print("  bootstrap [subcmd]     Self-host bootstrap status / corpus report");
    print("    status               Report example and runtime readiness");
    print("    dump-corpus          List .nr corpus files");
    print("    --json               Output machine-readable bootstrap data");
    print("  stage-dump <stage>     Dump compiler stage summaries");
    print("    tokens|ast|typed|ir|all");
    print("  summary [file]         Compact module interface card");
    print("    --json               Output summary lines as JSON");
    print("  query [file]           Machine-readable module interface");
    print("  abi [file]             Inspect import/export ABI for C / Rust interop");
    print("    --exports            Inspect `pub fn` export ABI instead of imports");
    print("    --json               Output machine-readable ABI data");
    print("    --c-header           Emit C declarations for the selected ABI surface");
    print("    --rust-extern        Emit Rust unsafe extern declarations for the selected ABI surface");
    print("  evidence [file]        Governance evidence report");
    print("  impact [file] <fn>     Reverse call impact for a function");
    print("    --fn <name>          Specify the target function");
    print("  graph [file]           Source-level call/effect graph");
    print("    --json               Output machine-readable graph data");
    print("  doc [file]             Render /// + //! doc comments as Markdown or HTML (RFC-0029)");
    print("    --out <file>         Write to file instead of stdout");
    print("    --html               Emit standalone HTML (auto-detected from .html / .htm --out)");
    print("    --test-list          Enumerate ```nucleor code blocks for doc-test discoverability");
    print("  profile run <binary>   Timed binary execution profile");
    print("    --iterations <n>     Repeat the profile run N times");
    print("  lock [manifest]        Write Nucleor.lock for local/workspace manifests");
    print("    --json               Output machine-readable lock status");
    print("  install [alias] <pkg>  Add a path or registry dependency and refresh Nucleor.lock");
    print("  publish [manifest]     Copy a package into a local registry directory");
    print("    --registry <dir>     Registry root (default: .nucleor/registry)");
    print("  registry [subcmd]      List/search/inspect packages in a local registry");
    print("    list|search|versions|verify");
    print("  sage <subcmd> <file>   Sage_NS prove / certificate / gap checks");
    print("    prove|certificate|gaps");
    print("");
    print("Analysis commands:");
    print("  check [file] [flags]   Run all checkers and report diagnostics");
    print("    --json               Output JSONL diagnostics");
    print("    --sarif              Output SARIF v2.1.0");
    print("    --check=<checkers>   Run specific checkers (ownership,type,source,taint,effect)");
    print("    --review             Enable review surface (nucleor_review.jsonl)");
    print("    --review-filter=<f>  Filter: findings, function=<name>, <checker>");
    print("  explain <CODE>         Explain a compiler error code (e.g. NR031, OWN-G4-USE-AFTER-DROP)");
    print("    --json               Output a JSON explanation object");
    print("");
    print("Governance commands:");
    print("  audit [file]           Provenance and governance report");
    print("  policy [file] [level]  Policy compliance (default, no_extern, no_system, strict)");
    print("  certify [file]         Compile + produce certification manifest");
    print("  translate [file]       Parse, validate, and summarize source");
    print("");
    print("Project utilities:");
    print("  clean                  Remove target/ and .nuc_cache/ from the project");
    print("  clean --cache          Remove target/.nuc_cache_v2/ and .nuc_cache/ only");
    print("  scram                  Alias for `clean` (emergency shutdown of build state)");
    print("  fix [--imports|--numeric] [file]  Migration linters (RFC-0015 / RFC-0018)");
    print("  gen-headers <input.nr> [-o <out.h>]  Emit C decls for #[export] / #[repr(C)] (RFC-0011)");
    print("  zen                    The design principles of Nucleor");
    print("  mco                    Mars Climate Orbiter - why we ship dimensional analysis");
    print("");
    print("Project mode:");
    print("  If [file] is omitted and ./Nucleor.toml exists, [build].entry is used.");
    print("");
    print("Legacy: nuc <source.nr> <output_name>");
    return 0;
}

#[manual_drop]
fn lex(src: str) -> Vec<i32> {
    let mut tokens: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if is_ws(c) == 1 { p = p + 1; }
        else if c == 64 {
            // R14-D1 Phase 1 — preserve @law(...) annotations through
            // the lex skip path. The generic @attr skip below silently
            // consumes them; Phase 1 detects @law specifically and
            // emits a position + body-length record so future compiler
            // phases (and tests) can observe what was captured at lex
            // time. Phase 2b will replace this with a side-table store
            // + AST node attachment + optimizer law-rewrite pass.
            let law_at: i64 = p;
            let is_law: i64 = str_eq_at(src, p, "@law(");
            let law_body_start: i64 = if is_law == 1 { p + 5 } else { 0 };
            if p + 1 < slen && is_alnum(str_char_at(src, p + 1)) == 1 {
                // Skip attributes like @authored(...), @policy(...), @hot, @const_fn.
                p = p + 1;
                while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                if p < slen && str_char_at(src, p) == 40 {
                    let mut depth: i64 = 1;
                    p = p + 1;
                    while p < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, p);
                        if ch == 34 {
                            p = p + 1;
                            while p < slen && str_char_at(src, p) != 34 {
                                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                                else { p = p + 1; };
                            };
                            if p < slen { p = p + 1; };
                        } else {
                            if ch == 40 { depth = depth + 1; }
                            else if ch == 41 { depth = depth - 1; };
                            p = p + 1;
                        };
                    };
                };
            } else {
                tokens.push(tok_new(122, 0, p));
                p = p + 1;
            };
            // After the skip, p points just past the matching ')' for
            // parenthesized attrs. Emit the @law observation now.
            if is_law == 1 {
                let body_len: i64 = (p - 1) - law_body_start;
                print(str_concat(
                    str_concat("info[LAW-CAPTURE]: @law at position ", str_from_int(law_at)),
                    str_concat(", body length ", str_from_int(body_len))));
            };
        }
        else if c == 35 && p + 1 < slen && str_char_at(src, p + 1) == 91 {
            // Rust-style outer attribute: #[name], #[name(args)], #[name = val].
            // Lex-time skip with quoted-string + bracket-depth awareness.
            // Forward-compatible with RFC-0001/0021 attribute family; semantics
            // ship in later RFC implementation phases.
            //
            // v0.6.25 (probe finding 2026-05-01-cfg-attribute-silently-ignored):
            // detect `#[cfg(...)]` and `#[cfg_attr(...)]` BEFORE the silent
            // skip and halt with a clear workaround pointer. Pre-fix, paired
            // `#[cfg(target_os="X")] fn foo() ... #[cfg(not(...))] fn foo()`
            // produced a misleading "duplicate pub fn name across modules"
            // PANIC because both branches lowered. Single `#[cfg(test)]`
            // items leaked into release builds. Cross-platform Rust
            // translation produced unbuildable Nucleor with a wrong-error
            // diagnostic. Loud halt closes the silent-drop window until full
            // cfg-evaluation lands (post-v0.6 RFC).
            if p + 6 < slen && str_eq_at(src, p + 2, "cfg") == 1 {
                let after_cfg: i64 = str_char_at(src, p + 5);
                if after_cfg == 40 || after_cfg == 95 {
                    print("ERROR: `#[cfg(...)]` and `#[cfg_attr(...)]` attributes are not yet supported in Nucleor. Pre-v0.6.25 the attribute was silently dropped at lex time, leaving all branches of a `#[cfg(...)] fn foo() ... #[cfg(not(...))] fn foo()` pair LIVE — which produced a misleading 'duplicate pub fn name' PANIC, hiding the real cause. Single `#[cfg(test)]` items leaked into release builds. Workarounds: (a) for cross-platform code, manually delete the inactive branch before building; (b) for test-only code, gate it behind a runtime flag or move it to a separate `_test.nr` file that isn't imported in release; (c) wait for the future cfg-evaluation ship that will pick the matching branch at parse time.");
                    panic("nucleor: `#[cfg(...)]` attribute not yet supported (see ERROR diagnostic above)");
                };
            };
            if p + 8 < slen && str_eq_at(src, p + 2, "inline") == 1 {
                let after_inline_v718: i64 = str_char_at(src, p + 8);
                if after_inline_v718 == 93 || after_inline_v718 == 40 {
                    print("ERROR: `#[inline]` / `#[inline(always)]` attributes are not yet supported in Nucleor. Pre-v0.7.18 these attributes were silently dropped at lex time, so adopter intent about call overhead or code layout was lost without signal. Workaround: remove the attribute; Nucleor's current optimizer makes its own inline decisions. Tracked for forward-roadmap (attribute-driven inliner hints).");
                    panic("nucleor: inline attribute not yet supported (see ERROR diagnostic above)");
                };
            };
            if p + 6 < slen && str_eq_at(src, p + 2, "cold") == 1 {
                let after_cold_v718: i64 = str_char_at(src, p + 6);
                if after_cold_v718 == 93 || after_cold_v718 == 40 {
                    print("ERROR: `#[cold]` attribute is not yet supported in Nucleor. Pre-v0.7.18 this attribute was silently dropped at lex time, so rare-path layout intent was lost without signal. Workaround: remove the attribute; Nucleor does not yet feed cold-path hints to LLVM. Tracked for forward-roadmap (function section/layout attributes).");
                    panic("nucleor: cold attribute not yet supported (see ERROR diagnostic above)");
                };
            };
            // RFC-0021: `#[test]` is supported by `nuc test`.
            // Discovery happens in tools-suite; normal build/check paths
            // lexically consume this metadata below.
            // v0.6.26 (probe finding 2026-05-01-derive-attribute-partial-honor):
            // `#[derive(A, B, C)]` is silently dropped except for `Debug`
            // which is honored. Adopters writing `#[derive(PartialEq)]`
            // expect equality on field-wise values; Nucleor only honors
            // Debug, so `a == b` later falls through to TYP-011 ptr-compare
            // diag at the use site — a confusing distance from the derive
            // site. Print a one-line warning at lex time naming the whole
            // derive body so adopters know up front that anything other
            // than Debug is being silently dropped. Build continues
            // (warning, not error); TYP-011 still fires correctly at use
            // sites for the dropped derives.
            if p + 9 < slen && str_eq_at(src, p + 2, "derive(") == 1 {
                let derive_arg_start_v060: i64 = p + 9;
                let mut derive_arg_end_v060: i64 = derive_arg_start_v060;
                while derive_arg_end_v060 < slen && str_char_at(src, derive_arg_end_v060) != 41 {
                    derive_arg_end_v060 = derive_arg_end_v060 + 1;
                };
                if derive_arg_end_v060 < slen {
                    let derive_body_v060: str = str_substring(src, derive_arg_start_v060, derive_arg_end_v060);
                    let trimmed_v060: str = str_trim(derive_body_v060);
                    // v0.6.84 RFC V1.4: PartialEq is now auto-generated
                    // by `expand_derive_partialeq` as the helper fn
                    // `<TypeName>__derived_eq(a, b) -> i64` (returns 1
                    // when field-wise equal, 0 otherwise). Adopters call
                    // it manually; auto-dispatch of `==`/`!=` to the
                    // helper is deferred. Suppress the DERIVE-001 warning
                    // when the only derive in the list is PartialEq, and
                    // soften the wording when PartialEq is one of several.
                    // v0.7.64: Clone is now also auto-generated by
                    // `expand_derive_clone` as `<TypeName>__clone(a) -> <TypeName>`.
                    let mut v084_only_partial: i64 = 0;
                    if str_eq(trimmed_v060, "PartialEq") == 1 { v084_only_partial = 1; };
                    let mut v084_has_partial: i64 = 0;
                    if str_contains(trimmed_v060, "PartialEq") == 1 { v084_has_partial = 1; };
                    let mut v084_has_clone: i64 = 0;
                    if str_contains(trimmed_v060, "Clone") == 1 { v084_has_clone = 1; };
                    let mut v084_only_clone: i64 = 0;
                    if str_eq(trimmed_v060, "Clone") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "PartialEq, Clone") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Clone, PartialEq") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Clone, Debug") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Debug, Clone") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "PartialEq, Clone, Debug") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Clone, PartialEq, Debug") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Debug, Clone, PartialEq") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Debug, PartialEq, Clone") == 1 { v084_only_clone = 1; };
                    if v084_only_partial == 0 && v084_only_clone == 0 && str_eq(trimmed_v060, "Debug") == 0 {
                        let v084_intro: str = if v084_has_partial == 1 || v084_has_clone == 1 {
                            "warning[DERIVE-001]: only `Debug`, `PartialEq`, and `Clone` are honored from `#[derive("
                        } else {
                            "warning[DERIVE-001]: `#[derive("
                        };
                        let v084_body: str = if v084_has_partial == 1 || v084_has_clone == 1 {
                            ")]` — `PartialEq` generates `<Type>__derived_eq(a,b)->i64`; `Clone` (v0.7.64) generates `<Type>__clone(a)-><Type>`; the rest are silently dropped."
                        } else {
                            ")]` is silently dropped except for `Debug`, `PartialEq`, and `Clone` (v0.7.64). Nucleor doesn't auto-derive Eq / Hash / Default / Copy / Ord / PartialOrd / etc. — anything other than those listed above is a no-op. Use sites that depend on a dropped derive (`Default::default()`, `a.clone()`, etc.) will fail at the use site with TYP-011 / TYP-005 / TYP-006."
                        };
                        print(str_concat(v084_intro, str_concat(trimmed_v060, v084_body)));
                    };
                };
            };
            p = p + 2;
            let mut depth: i64 = 1;
            while p < slen && depth > 0 {
                let ch: i64 = str_char_at(src, p);
                if ch == 34 {
                    p = p + 1;
                    while p < slen && str_char_at(src, p) != 34 {
                        if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                        else { p = p + 1; };
                    };
                    if p < slen { p = p + 1; };
                } else {
                    if ch == 91 { depth = depth + 1; }
                    else if ch == 93 { depth = depth - 1; };
                    p = p + 1;
                };
            };
        }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if c == 92 && p + 1 < slen && str_char_at(src, p + 1) == 32 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if is_alpha(c) == 1 {
            // v0.6.58 (probe finding 2026-05-01-rust-syntax-translation-
            // fidelity-audit, raw-string and byte-string rows): canonical
            // Rust prefix-quoted string literals `r"..."` (raw string,
            // no escapes), `b"..."` (byte string), `c"..."` (C string),
            // `r#"..."#` (raw with hashes), `br"..."` (byte raw) all pre-fix lexed as the
            // bare prefix identifier (`r` / `b` / `br`) followed by a
            // string literal — the parser then read the prefix as a
            // fn-name + the string as the call's first arg, producing
            // confusing TYP-005 "undefined function 'r'" / "'b'" /
            // "'br'". Halt at lex with a clean diag pointing at the
            // workaround.
            if c == 114 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: raw string literals `r\"...\"` are not yet supported in Nucleor. Pre-v0.6.58 the `r` lexed as an identifier and the parser tried to call a fn named `r` on the trailing string literal, producing the wrong-class `error[TYP-005]: undefined function 'r'`. Workaround: write the canonical form `\"...\"` and escape backslashes / quotes manually (`\\\\`, `\\\"`, etc.). Tracked for forward-roadmap (lex-time r-prefix → no-escape string mode).");
                panic("nucleor: raw string `r\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            // v0.7.75 (defensive halt — Rust raw identifier prefix
            // `r#name`, used to write a binding whose spelling clashes
            // with a Rust keyword like `type`, `match`, `fn`, etc.).
            // Pre-fix the `r` lexed as an ident and `#` was emitted
            // as a separate punct token, leaving `name` to be lexed
            // as a fresh ident. The downstream parser then tripped
            // on whichever production saw three tokens (e.g. `r # type`
            // surfaced as v0.7.47's local-type-alias halt because
            // `type` got read as keyword token 74). Halt at lex with
            // a precise diag so adopters know the raw-identifier
            // surface itself isn't supported. Sister to v0.6.58 raw
            // string literal halt (same `r` prefix family).
            if c == 114 && p + 1 < slen && str_char_at(src, p + 1) == 35 {
                print("ERROR: raw identifier prefix `r#name` (used in Rust to bind a name that collides with a keyword, e.g. `let r#type: i64 = 42;`) is not yet supported in Nucleor. Pre-v0.7.75 the `r` lexed as an ident and `#` as a separate punct, so the trailing `name` was read as a fresh token — if the trailing name was a Nucleor keyword (e.g. `type`, `fn`, `match`) downstream parsers tripped wrong-class on the keyword's normal use site (e.g. v0.7.47 local-type-alias halt). Workaround: rename the binding to a non-keyword spelling — Nucleor's keyword set is small and renames are usually mechanical. Tracked for forward-roadmap (raw-identifier surface lands when the lexer gains a keyword-escape mode).");
                panic("nucleor: raw identifier `r#name` not yet supported (see ERROR diagnostic above)");
            };
            if c == 98 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: byte string literals `b\"...\"` are not yet supported in Nucleor. Pre-v0.6.58 the `b` lexed as an identifier and the parser tried to call a fn named `b` on the trailing string literal, producing the wrong-class `error[TYP-005]: undefined function 'b'`. Workaround: build a `Vec<u8>` explicitly via `let mut bs: Vec<u8> = Vec::new(); vec_u8_push(bs, 'h' as u8); ...`. Tracked for forward-roadmap (lex-time b-prefix → byte-buffer literal).");
                panic("nucleor: byte string `b\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            // v0.7.68 (defensive halt — C string literal `c"..."`, the
            // NUL-terminated FFI buffer form). Pre-fix the `c` lexed as
            // an ident and the parser tried to call fn `c` on the
            // trailing string literal, producing the wrong-class
            // `error[TYP-005]: undefined function 'c'`. Promoted from
            // probe finding 2026-05-03.
            if c == 99 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: C string literals `c\"...\"` are not yet supported in Nucleor. Pre-v0.7.68 the `c` lexed as an identifier and the parser tried to call a fn named `c` on the trailing string literal, producing wrong-class `error[TYP-005]: undefined function 'c'`. Workaround: use a normal string literal and handle the trailing NUL explicitly at the FFI boundary, e.g. `\"hello\\0\"` when the callee expects a NUL-terminated buffer. Tracked for forward-roadmap (lex-time c-prefix -> static NUL-terminated byte storage).");
                panic("nucleor: C string `c\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            // v0.7.28 (defensive halt — Rust byte literal `b'A'`, the u8
            // value of an ASCII char). Pre-fix the `b` lexed as an
            // identifier and the parser saw `b ('A')` — a fn call on a
            // char literal — surfacing as wrong-class `error[TYP-005]:
            // undefined function 'b()'`. Sister to v0.6.58 byte-string
            // halt and probe's c-string halt. Workaround: use a regular
            // char literal and cast — `'A' as i64` (or `as u8`).
            if c == 98 && p + 1 < slen && str_char_at(src, p + 1) == 39 {
                print("ERROR: byte literal `b'A'` (Rust u8 ASCII-value form) is not yet supported in Nucleor. Pre-v0.7.28 surfaced as wrong-class `error[TYP-005]: undefined function 'b()'` because the `b` lexed as an identifier and `('A')` looked like a fn call on a char literal. Sister to the existing `b\"...\"` (byte string) halt.");
                print("       Workaround: use a regular char literal and cast — `'A' as i64` or `'A' as u8`. Tracked for forward-roadmap (lex-time b-prefix on char-quote → u8 literal token).");
                panic("nucleor: byte literal `b'A'` not yet supported (see ERROR diagnostic above)");
            };
            if c == 99 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: C string literals `c\"...\"` are not yet supported in Nucleor. Pre-v0.7.18 the `c` lexed as an identifier and the parser tried to call a fn named `c` on the trailing string literal, producing wrong-class `error[TYP-005]: undefined function 'c'`. Workaround: use a normal string literal and handle the trailing NUL explicitly at the FFI boundary, e.g. `\"hello\\0\"` when the callee expects a NUL-terminated buffer. Tracked for forward-roadmap (lex-time c-prefix -> static NUL-terminated byte storage).");
                panic("nucleor: C string `c\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            let st: i64 = p;
            while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
            let w: str = str_substring(src, st, p);
            tokens.push(tok_new(classify_kw(w), w, st));
        }
        else if is_digit(c) == 1 {
            // RFC-0015 phase 1+5: integer/float lexer with hex/oct/bin literals,
            // underscores, and type suffixes.
            //   0x... = hex   (e.g., 0xAB, 0xFFFF_FFFF)
            //   0o... = octal (e.g., 0o777)
            //   0b... = binary (e.g., 0b1010_0001)
            //   Otherwise decimal.
            // Recognised suffixes: i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128
            // usize (lexed; full type-check arrives in later phases).
            let st: i64 = p;
            let mut int_value: i64 = 0;
            let mut handled_radix: i64 = 0;
            // Detect 0x / 0o / 0b prefix
            if c == 48 && p + 1 < slen {
                let nx: i64 = str_char_at(src, p + 1);
                if nx == 120 || nx == 88 {
                    // hex -- v0.3.208: wrapping_* lets 0xFFFFFFFFFFFFFFFF
                    // (and other 64-bit-MAX-aligned literals) parse under
                    // strict-arithmetic mode. The accumulator is meant to
                    // wrap; the resulting bit pattern is what callers want.
                    p = p + 2;
                    while p < slen {
                        let hc: i64 = str_char_at(src, p);
                        if hc == 95 { p = p + 1; }
                        else if hc >= 48 && hc <= 57 { int_value = wrapping_add(wrapping_mul(int_value, 16), hc - 48); p = p + 1; }
                        else if hc >= 97 && hc <= 102 { int_value = wrapping_add(wrapping_mul(int_value, 16), hc - 87); p = p + 1; }
                        else if hc >= 65 && hc <= 70 { int_value = wrapping_add(wrapping_mul(int_value, 16), hc - 55); p = p + 1; }
                        else { break; };
                    };
                    handled_radix = 1;
                } else if nx == 111 || nx == 79 {
                    // octal -- v0.3.208: wrapping_* (see hex path).
                    p = p + 2;
                    while p < slen {
                        let oc: i64 = str_char_at(src, p);
                        if oc == 95 { p = p + 1; }
                        else if oc >= 48 && oc <= 55 { int_value = wrapping_add(wrapping_mul(int_value, 8), oc - 48); p = p + 1; }
                        else { break; };
                    };
                    handled_radix = 1;
                } else if nx == 98 || nx == 66 {
                    // binary -- v0.3.208: wrapping_* (see hex path).
                    p = p + 2;
                    while p < slen {
                        let bc: i64 = str_char_at(src, p);
                        if bc == 95 { p = p + 1; }
                        else if bc == 48 { int_value = wrapping_mul(int_value, 2); p = p + 1; }
                        else if bc == 49 { int_value = wrapping_add(wrapping_mul(int_value, 2), 1); p = p + 1; }
                        else { break; };
                    };
                    handled_radix = 1;
                };
            };
            let mut digit_sb: i64 = sb_new();
            if handled_radix == 0 {
                while p < slen && (is_digit(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
                    if str_char_at(src, p) != 95 {
                        sb_append_char_at(digit_sb, src, p);
                    };
                    p = p + 1;
                };
            };
            // v0.5.24: digits-only e/E exponent (no fractional dot).
            // Closes part of probe finding 2026-05-01-float-to-int-cast-out-of-range-silent-ub
            // — probe's repro `let big: f64 = 1e20;` actually demonstrated
            // a LEXER bug, not the saturating-cast UB it claimed (the
            // saturating cast already works correctly per v0.3.208 et al.).
            // Pre-fix `1e20` lexed as int 1 + ident `e20`; the let-binding
            // type-coerced to f64 = 1.0. Now `<digits>e<digits>` lexes as a
            // float literal directly (Rust accepts both `1e20` and `1.0e20`).
            // The detection is gated on the CHARACTER AFTER digits being
            // 'e'/'E' followed by an optional sign + at least one digit;
            // identifier-shaped suffixes like `e_helper` still lex as
            // ident.
            let mut digits_only_exp: i64 = 0;
            if handled_radix == 0 && p < slen && (str_char_at(src, p) == 101 || str_char_at(src, p) == 69) {
                let mut probe_p: i64 = p + 1;
                if probe_p < slen {
                    let sign_ch_p: i64 = str_char_at(src, probe_p);
                    if sign_ch_p == 43 || sign_ch_p == 45 { probe_p = probe_p + 1; };
                };
                if probe_p < slen && is_digit(str_char_at(src, probe_p)) == 1 {
                    digits_only_exp = 1;
                };
            };
            if digits_only_exp == 1 {
                // Promote to f64 raw-bits path. Construct the literal text
                // as `<digits>e<+/->? <digits>` and let str_to_f64 (strtod)
                // parse it.
                let lit_st: i64 = st;
                let exp_st_p: i64 = p;
                let mut exp_p: i64 = p + 1;
                if exp_p < slen {
                    let sign_ch_e: i64 = str_char_at(src, exp_p);
                    if sign_ch_e == 43 || sign_ch_e == 45 { exp_p = exp_p + 1; };
                };
                while exp_p < slen && is_digit(str_char_at(src, exp_p)) == 1 { exp_p = exp_p + 1; };
                let lit_text: str = str_substring(src, lit_st, exp_p);
                let bits: i64 = str_to_f64(lit_text);
                tokens.push(tok_new(124, bits, lit_st));
                p = exp_p;
                continue;
            };
            // Check for f64 literal: digits DOT digits
            if p < slen && str_char_at(src, p) == 46 && p + 1 < slen && is_digit(str_char_at(src, p + 1)) == 1 {
                // f64 literal — parse integer.fraction, encode as bitcast i64
                let int_part: i64 = str_to_int(sb_to_str(digit_sb));
                p = p + 1; // skip dot
                let frac_st: i64 = p;
                let mut frac_sb: i64 = sb_new();
                while p < slen && (is_digit(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
                    if str_char_at(src, p) != 95 {
                        sb_append_char_at(frac_sb, src, p);
                    };
                    p = p + 1;
                };
                let raw_frac_str: str = sb_to_str(frac_sb);
                // v0.3.130: NUC-FEEDBACK-005 — truncate fractional digits to
                // the encoder's 6-digit (millionth) precision BEFORE
                // computing frac_div. The truncate path handles literals
                // where the first 6 frac digits carry meaningful value.
                //
                // v0.3.133: NUC-FEEDBACK-006 — for SUB-MICRO literals
                // (`0.00000001` = 1e-8 used as AdamW eps, etc.), the
                // first 6 frac digits are all '0' and truncation still
                // produces zero. Falling back to the runtime
                // `__nucleor_str_to_f64` parser via the str_to_f64
                // helper gives full IEEE-754 precision. The bit
                // pattern is stored as token kind 124 (raw-bits f64
                // literal); parse_primary emits AST kind 72 which
                // lower_expr emits as a direct const_int (no
                // f64_from_scaled divide needed since the value IS
                // already the f64 bit pattern).
                //
                // v0.3.197: NUC-FEEDBACK-005 corrected — the all-zero
                // gate was too narrow. Long literals with non-zero
                // first six digits like `0.7978845608028654` still
                // fell into the truncate-to-six path and silently lost
                // 10+ decimal digits of precision (the literal became
                // `0.797884` after divide-by-1e6). Promote ANY literal
                // with more than six fractional digits to the raw-bits
                // path. Short literals (≤ 6 frac digits) still use the
                // scaled-int path — frac_div is an exact power of ten,
                // so the runtime divide rounds once to the closest f64
                // (same precision an IEEE parser would give).
                // v0.4.220: scientific notation (e/E exponent). Pre-fix
                // `1.0e30` lexed as `1.0` then identifier-`e` then int-30,
                // silently truncating the value to 1.0 and surfacing as a
                // bizarre downstream type error or as `big as i32 = 1`
                // (the user's reported f64-out-of-range repro). Adopters
                // writing canonical Rust literals (`1.0e10`, `2.5e-3`, etc.)
                // got silent miscomputes.
                // Detect e/E after fractional digits, consume optional sign
                // + digits, append to literal text, and force the raw-bits
                // path so str_to_f64 (strtod) parses with full precision.
                let mut exp_str: str = "";
                if p < slen {
                    let exp_ch: i64 = str_char_at(src, p);
                    if exp_ch == 101 || exp_ch == 69 {
                        let exp_st: i64 = p;
                        let mut exp_p: i64 = p + 1;
                        if exp_p < slen {
                            let sign_ch: i64 = str_char_at(src, exp_p);
                            if sign_ch == 43 || sign_ch == 45 { exp_p = exp_p + 1; };
                        };
                        let mut has_exp_digits: i64 = 0;
                        while exp_p < slen && is_digit(str_char_at(src, exp_p)) == 1 {
                            has_exp_digits = 1;
                            exp_p = exp_p + 1;
                        };
                        if has_exp_digits == 1 {
                            exp_str = str_substring(src, exp_st, exp_p);
                            p = exp_p;
                        };
                    };
                };
                let raw_frac_len: i64 = str_len(raw_frac_str);
                let mut use_raw_bits: i64 = 0;
                if raw_frac_len > 6 { use_raw_bits = 1; };
                if str_len(exp_str) > 0 { use_raw_bits = 1; };
                if use_raw_bits == 1 {
                    let lit_text: str = str_concat(str_from_int(int_part), str_concat(".", str_concat(raw_frac_str, exp_str)));
                    let bits: i64 = str_to_f64(lit_text);
                    tokens.push(tok_new(124, bits, st));
                } else {
                    let frac_str: str = if raw_frac_len > 6 { str_substring(raw_frac_str, 0, 6) } else { raw_frac_str };
                    let frac_val: i64 = str_to_int(frac_str);
                    let frac_len: i64 = str_len(frac_str);
                    // Compute frac_divisor = 10^frac_len
                    let mut frac_div: i64 = 1;
                    let mut fi: i64 = 0;
                    while fi < frac_len { frac_div = frac_div * 10; fi = fi + 1; };
                    // Encode: store int_part and frac as token type 70 (f64 literal)
                    // Value = int_part * 1000000 + frac_val * (1000000 / frac_div)
                    let encoded: i64 = int_part * 1000000 + frac_val * (1000000 / frac_div);
                    tokens.push(tok_new(70, encoded, st));
                };
                // Consume optional float suffix: f32 or f64
                if p < slen && str_char_at(src, p) == 102 {
                    let suf_st: i64 = p;
                    while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                    let suf: str = str_substring(src, suf_st, p);
                    if str_eq(suf, "f32") == 0 && str_eq(suf, "f64") == 0 {
                        // Not actually a suffix; rewind.
                        p = suf_st;
                    } else if str_eq(suf, "f32") == 1 {
                        // v0.4.24 (NUC-FEEDBACK-002 fix): rewrite the just-
                        // emitted token type from 70 (generic float) to 125
                        // (f32-typed) so the parser/lowerer can route the
                        // literal through f32_from_scaled instead of
                        // f64_from_scaled. Pre-fix the f32 suffix was
                        // consumed and discarded -> 1.0f32 silently became
                        // 1.0f64 bits, which when read back as f32 = 0.0
                        // (silent miscompute on Vec<f32> push of literals).
                        let last_tok: Vec<i32> = vec_get(tokens, vec_len(tokens) - 1);
                        vec_set(last_tok, 0, 125);
                    };
                };
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            } else {
                // v0.4.119: NUM-021 — decimal literal too wide for u64.
                // Pre-fix `let x: i64 = 99999999999999999999;` (a 20-digit
                // value > u64::MAX) silently wrapped through str_to_int's
                // wrapping_mul/add accumulator, producing
                // 7766279631452241919 — a meaningless garbage bit pattern.
                // Single sb_to_str call (consumes digit_sb), use the
                // string both for the check AND the str_to_int call.
                // Hex/oct/bin literals (handled_radix == 1) keep the
                // existing wrap behavior since their bit pattern is
                // expected.
                let dig_str_v119: str = if handled_radix == 1 { "" } else { sb_to_str(digit_sb) };
                if handled_radix == 0 {
                    let dig_len_v119: i64 = str_len(dig_str_v119);
                    let mut overflow_v119: i64 = 0;
                    if dig_len_v119 > 20 { overflow_v119 = 1; };
                    if dig_len_v119 == 20 {
                        let u64_max_v119: str = "18446744073709551615";
                        let mut cmp_i_v119: i64 = 0;
                        while cmp_i_v119 < 20 {
                            let dc_v119: i64 = str_char_at(dig_str_v119, cmp_i_v119);
                            let mc_v119: i64 = str_char_at(u64_max_v119, cmp_i_v119);
                            if dc_v119 > mc_v119 { overflow_v119 = 1; cmp_i_v119 = 20; }
                            else if dc_v119 < mc_v119 { cmp_i_v119 = 20; }
                            else { cmp_i_v119 = cmp_i_v119 + 1; };
                        };
                    };
                    if overflow_v119 == 1 {
                        panic(str_concat("error[NUM-021]: integer literal `", str_concat(dig_str_v119, "` exceeds u64::MAX (18446744073709551615). Pre-v0.4.119 the value silently wrapped through the str_to_int accumulator and produced a meaningless bit pattern. Use a smaller literal, switch to a wide-int library, or write the value as a hex literal `0x...` if you intentionally want a specific bit pattern."))));
                    };
                    // v0.6.68 (probe finding 2026-05-01-match-arm-literal-
                    // exceeds-i64-silently-dead): also halt on decimal
                    // literals in (i64::MAX, u64::MAX] that lack an
                    // explicit unsigned suffix (`u8`/`u16`/`u32`/`u64`/
                    // `usize`/`u128`). Pre-fix these wrapped silently to
                    // i64::MIN-region bit patterns. The most common
                    // failure mode was `match x { 9223372036854775808
                    // => ... }` against an i64 scrutinee — the wrapped
                    // pattern never matched, producing a silent dead
                    // arm. Adopters who genuinely want the u64 bit
                    // pattern can either:
                    //   (a) add the `u64` suffix: `9223372036854775808u64`,
                    //   (b) use the hex form: `0x8000000000000000`,
                    //   (c) use the canonical signed form:
                    //       `(-9223372036854775807) - 1` for i64::MIN,
                    //       which is already supported by v0.6.49.
                    if overflow_v119 == 0 && dig_len_v119 == 19 {
                        let i64_max_v068: str = "9223372036854775807";
                        let mut over_i64_v068: i64 = 0;
                        let mut cmp_v068: i64 = 0;
                        while cmp_v068 < 19 {
                            let dc_v068: i64 = str_char_at(dig_str_v119, cmp_v068);
                            let mc_v068: i64 = str_char_at(i64_max_v068, cmp_v068);
                            if dc_v068 > mc_v068 { over_i64_v068 = 1; cmp_v068 = 19; }
                            else if dc_v068 < mc_v068 { cmp_v068 = 19; }
                            else { cmp_v068 = cmp_v068 + 1; };
                        };
                        if over_i64_v068 == 1 {
                            // Peek for an unsigned suffix immediately
                            // after the digit string. If present, the
                            // user is explicit about u-typed semantics
                            // — accept the bit pattern.
                            let mut suf_v068_ok: i64 = 0;
                            if p < slen {
                                let nx_v068: i64 = str_char_at(src, p);
                                if nx_v068 == 117 {
                                    // 'u' — check u8/u16/u32/u64/u128/usize
                                    let mut sk_v068: i64 = p + 1;
                                    while sk_v068 < slen && is_alnum(str_char_at(src, sk_v068)) == 1 { sk_v068 = sk_v068 + 1; };
                                    let suf_v068: str = str_substring(src, p, sk_v068);
                                    if str_eq(suf_v068, "u8") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u16") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u32") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u64") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u128") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "usize") == 1 { suf_v068_ok = 1; };
                                };
                            };
                            // v0.6.71: also accept when the previous
                            // token is unary-minus (token kind 21).
                            // `-9223372036854775808` is the canonical
                            // Rust i64::MIN form; v0.6.49 already wires
                            // const-fold + lower-time acceptance for
                            // this case. The v0.6.68 lex-time halt
                            // regressed v0.6.43 + v0.6.49 fixtures.
                            // Restore by pre-checking the previous
                            // token: if it's `-` (token 21), the user
                            // is writing the canonical signed form,
                            // accept the literal.
                            if suf_v068_ok == 0 {
                                let tcnt_v071: i64 = vec_len(tokens);
                                if tcnt_v071 > 0 {
                                    let prev_tok_v071: Vec<i32> = vec_get(tokens, tcnt_v071 - 1);
                                    if tok_type(prev_tok_v071) == 21 {
                                        suf_v068_ok = 1;
                                    };
                                };
                            };
                            if suf_v068_ok == 0 {
                                panic(str_concat("error[NUM-021]: decimal literal `", str_concat(dig_str_v119, "` exceeds i64::MAX (9223372036854775807) and lacks an explicit unsigned suffix. Pre-v0.6.68 the value silently wrapped to a negative i64 bit pattern, producing the most-common failure mode `match x { <this> => ... }` where the arm never matches against an i64 scrutinee (silent dead arm). Workarounds: (a) add a `u64` suffix (`9223372036854775808u64`); (b) use the hex form (`0x8000000000000000`); (c) for i64::MIN specifically, use the canonical signed form `(-9223372036854775807) - 1` (already accepted as a const since v0.6.49).")));
                            };
                        };
                    };
                };
                let int_lit_value: i64 = if handled_radix == 1 { int_value } else { str_to_int(dig_str_v119) };
                tokens.push(tok_new(2, int_lit_value, st));
                // Consume optional integer suffix: i8 i16 i32 i64 u8 u16 u32 u64 usize isize
                if p < slen && (str_char_at(src, p) == 105 || str_char_at(src, p) == 117) {
                    let suf_st: i64 = p;
                    while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                    let suf: str = str_substring(src, suf_st, p);
                    let mut is_known: i64 = 0;
                    if str_eq(suf, "i8") == 1 { is_known = 1; };
                    if str_eq(suf, "i16") == 1 { is_known = 1; };
                    if str_eq(suf, "i32") == 1 { is_known = 1; };
                    if str_eq(suf, "i64") == 1 { is_known = 1; };
                    if str_eq(suf, "i128") == 1 { is_known = 1; };
                    if str_eq(suf, "isize") == 1 { is_known = 1; };
                    if str_eq(suf, "u8") == 1 { is_known = 1; };
                    if str_eq(suf, "u16") == 1 { is_known = 1; };
                    if str_eq(suf, "u32") == 1 { is_known = 1; };
                    if str_eq(suf, "u64") == 1 { is_known = 1; };
                    if str_eq(suf, "u128") == 1 { is_known = 1; };
                    if str_eq(suf, "usize") == 1 { is_known = 1; };
                    if is_known == 0 {
                        // Not actually a suffix; rewind so it lexes as identifier.
                        p = suf_st;
                    };
                };
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            };
        }
        else if c == 34 {
            let st: i64 = p; p = p + 1;
            let mut sb: i64 = sb_new();
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    let nc: i64 = str_char_at(src, p + 1);
                    if nc == 110 { sb_append(sb, "\n"); } else if nc == 116 { sb_append(sb, "\t"); }
                    else if nc == 34 { sb_append(sb, "\""); } else if nc == 92 { sb_append(sb, "\\"); }
                    else if nc == 114 { sb_append_char(sb, 13); }                          // v0.5.20: \r → CR byte (ASCII 13)
                    else if nc == 48  { sb_append_char(sb, 0); }                           // v0.5.20: \0 → NUL byte (ASCII 0). Closes probe finding 2026-05-01-str-escape-null-byte-silently-literal.
                    else if nc == 39  { sb_append(sb, "'"); }                              // \' — single quote
                    else {
                        // v0.4.121: unknown escape sequence. Pre-fix the
                        // backslash was silently dropped and the next
                        // char emitted as-is — so `"a\zb"` became `"azb"`
                        // with no signal. Adopters typo'ing escapes (or
                        // pasting Rust raw-string content) got silent
                        // miscomputation. Halt cleanly. To opt out and
                        // get the literal next char, escape the
                        // backslash explicitly: `"a\\zb"`.
                        let bad_esc: str = str_substring(src, p, p + 2);
                        panic(str_concat("error[NR025]: unknown escape sequence `", str_concat(bad_esc, "` in string literal. Pre-v0.4.121 the backslash was silently dropped and the next char emitted as-is. Recognized escapes: `\\n`, `\\t`, `\\\"`, `\\\\`, `\\r`, `\\0`, `\\'`. To get a literal backslash + char, escape the backslash explicitly (e.g. `\\\\z`).")));
                    };
                    p = p + 2;
                } else { sb_append_char_at(sb, src, p); p = p + 1; };
            };
            if p < slen { p = p + 1; };
            tokens.push(tok_new(3, sb_to_str(sb), st));
        }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 62 { tokens.push(tok_new(41, 0, p)); p = p + 2; }
        else if c == 61 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(30, 0, p)); p = p + 2; }
        else if c == 61 && p + 1 < slen && str_char_at(src, p + 1) == 62 { tokens.push(tok_new(64, 0, p)); p = p + 2; }
        else if c == 33 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(31, 0, p)); p = p + 2; }
        else if c == 60 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(34, 0, p)); p = p + 2; }
        else if c == 62 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(35, 0, p)); p = p + 2; }
        else if c == 38 && p + 1 < slen && str_char_at(src, p + 1) == 38 { tokens.push(tok_new(36, 0, p)); p = p + 2; }
        // v0.3.105: bitwise compound assigns. `&=` → token 117,
        // `|=` → 118, `^=` → 119. Lexed BEFORE the bare `&`/`|`/`^`
        // single-token rules below so `&=` doesn't split as `&` `=`.
        // `<<=` and `>>=` follow the same pattern (120/121).
        else if c == 38 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(117, 0, p)); p = p + 2; }
        else if c == 38 { tokens.push(tok_new(82, 0, p)); p = p + 1; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 124 { tokens.push(tok_new(37, 0, p)); p = p + 2; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(118, 0, p)); p = p + 2; }
        else if c == 124 { tokens.push(tok_new(65, 0, p)); p = p + 1; }
        // v0.3.103: bitwise XOR `^` as token 94 — paired with the
        // `parse_bitwise` tier (tier between parse_eq and parse_and_expr)
        // and tok_to_ir mapping (94 → iop 15 = LLVM xor i64).
        else if c == 94 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(119, 0, p)); p = p + 2; }
        else if c == 94 { tokens.push(tok_new(94, 0, p)); p = p + 1; }
        // v0.3.104: shift-left `<<` as token 115. Shift-right `>>`
        // is intentionally NOT lexed as a single token — generic
        // syntax `Vec<Vec<i64>>` ends in `>>` and the seven angle-
        // group skips would all need updating to handle the merged
        // form. Instead, parse_shift detects two adjacent `>` tokens
        // and consumes both as shift-right at parse time. `<<` has
        // no such conflict so a single token is safe here.
        else if c == 60 && p + 2 < slen && str_char_at(src, p + 1) == 60 && str_char_at(src, p + 2) == 61 { tokens.push(tok_new(120, 0, p)); p = p + 3; }
        else if c == 60 && p + 1 < slen && str_char_at(src, p + 1) == 60 { tokens.push(tok_new(115, 0, p)); p = p + 2; }
        // v0.3.105: `>>=` lexed as a single token 121 — has no
        // conflict with generics because `>>=` (3 chars) doesn't
        // appear in any valid generic-position form.
        else if c == 62 && p + 2 < slen && str_char_at(src, p + 1) == 62 && str_char_at(src, p + 2) == 61 { tokens.push(tok_new(121, 0, p)); p = p + 3; }
        else if c == 58 && p + 1 < slen && str_char_at(src, p + 1) == 58 { tokens.push(tok_new(46, 0, p)); p = p + 2; }
        // v0.3.77: compound-assignment tokens (`+=`, `-=`, `*=`, `/=`, `%=`).
        // Lex as single tokens kind 110-114 so the parser can desugar
        // `LHS op= RHS` to `LHS = LHS op RHS` cleanly. Without this,
        // `x += 5;` lexed as separate `+` and `=` tokens which the parser
        // dropped silently. Token kinds 110/111/112/113/114 are reserved
        // for the five compound-op forms in op-token order.
        // v0.8.46: postfix `++` / `--` tokens (130 / 131). Must be checked
        // BEFORE the single-char `+` / `-` fallbacks. `x++` desugars to
        // `x = x + 1` in parse_stmt; same as `x += 1`. `x--` → `x = x - 1`.
        else if c == 43 && p + 1 < slen && str_char_at(src, p + 1) == 43 { tokens.push(tok_new(130, 0, p)); p = p + 2; }
        else if c == 43 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(110, 0, p)); p = p + 2; }
        else if c == 43 { tokens.push(tok_new(20, 0, p)); p = p + 1; }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 45 { tokens.push(tok_new(131, 0, p)); p = p + 2; }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(111, 0, p)); p = p + 2; }
        else if c == 45 { tokens.push(tok_new(21, 0, p)); p = p + 1; }
        else if c == 42 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(112, 0, p)); p = p + 2; }
        else if c == 42 { tokens.push(tok_new(22, 0, p)); p = p + 1; }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(113, 0, p)); p = p + 2; }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 42 {
            // v0.7.78 (defensive halt — Rust block comments
            // `/* ... */` and doc-block `/** ... */`). Pre-fix the
            // `/` lexed as token 23 and `*` as token 22; the parser
            // saw a stray `/` at expression start and emitted
            // wrong-class `error[NR020]: parse_primary cannot start
            // an expression at token kind 23`. Adopters porting
            // Rust code with block comments hit this constantly.
            // Halt at lex with a clear diag pointing at the line-
            // comment workaround. Sister to v0.6.58 raw-string
            // halt (same lex-time wrong-class family).
            print("ERROR: block comments `/* ... */` (and doc-block `/** ... */`) are not yet supported in Nucleor. Pre-v0.7.78 the `/` lexed as token kind 23 and `*` as token kind 22; the parser then saw a stray `/` at expression start and emitted wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 23`. Workaround: convert each line of the block comment to a line comment — replace `/* abc */` with `// abc`, and a multi-line block with a sequence of `// ...` lines. Tracked for forward-roadmap (block-comment lex skip is a small lex extension, sister to the line-comment skip already in place).");
            panic("nucleor: block comment `/* ... */` not yet supported (see ERROR diagnostic above)");
        }
        else if c == 47 { tokens.push(tok_new(23, 0, p)); p = p + 1; }
        else if c == 37 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(114, 0, p)); p = p + 2; }
        else if c == 37 { tokens.push(tok_new(24, 0, p)); p = p + 1; }
        else if c == 61 { tokens.push(tok_new(40, 0, p)); p = p + 1; }
        else if c == 60 { tokens.push(tok_new(32, 0, p)); p = p + 1; }
        else if c == 62 { tokens.push(tok_new(33, 0, p)); p = p + 1; }
        else if c == 33 { tokens.push(tok_new(38, 0, p)); p = p + 1; }
        else if c == 58 { tokens.push(tok_new(42, 0, p)); p = p + 1; }
        else if c == 59 { tokens.push(tok_new(43, 0, p)); p = p + 1; }
        else if c == 44 { tokens.push(tok_new(44, 0, p)); p = p + 1; }
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 && p + 2 < slen && str_char_at(src, p + 2) == 61 {
            // ..= inclusive range
            tokens.push(tok_new(96, 0, p));
            p = p + 3;
        }
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 { tokens.push(tok_new(58, 0, p)); p = p + 2; }
        else if c == 46 { tokens.push(tok_new(45, 0, p)); p = p + 1; }
        else if c == 40 { tokens.push(tok_new(50, 0, p)); p = p + 1; }
        else if c == 41 { tokens.push(tok_new(51, 0, p)); p = p + 1; }
        else if c == 123 { tokens.push(tok_new(52, 0, p)); p = p + 1; }
        else if c == 125 { tokens.push(tok_new(53, 0, p)); p = p + 1; }
        else if c == 91 { tokens.push(tok_new(54, 0, p)); p = p + 1; }
        else if c == 93 { tokens.push(tok_new(55, 0, p)); p = p + 1; }
        else if c == 63 { tokens.push(tok_new(97, 0, p)); p = p + 1; }
        else if c == 39 {
            // v0.3.105: char literals `'X'` and escape forms
            // `'\n'`/`'\t'`/`'\r'`/`'\0'`/`'\\'`/`'\''`. Emit as int
            // literal (token kind 2 with the codepoint as the value)
            // — matches Rust semantics where `'A' as i64 == 65` and
            // matches the convention documented at the prior
            // lifetime-only branch ("chars use u8/u32 via int literals").
            // Pre-v0.3.105, `'\n'` was lexed as a malformed lifetime
            // marker and silently produced 0 at runtime, a HIGH-blast
            // miscompute for any code using char escapes (parsers,
            // I/O, ASCII manipulation). Lifetime parsing is preserved
            // as the fallback when the pattern doesn't match
            // `'<one-char>'`.
            let st: i64 = p;
            // Try to recognize a char literal first.
            let mut handled: i64 = 0;
            if p + 2 < slen {
                let n1: i64 = str_char_at(src, p + 1);
                let n2: i64 = str_char_at(src, p + 2);
                // Plain `'X'` form — single non-backslash char.
                if n1 != 92 && n2 == 39 {
                    tokens.push(tok_new(2, n1, st));
                    p = p + 3;
                    handled = 1;
                };
            };
            if handled == 0 && p + 3 < slen && str_char_at(src, p + 1) == 92 && str_char_at(src, p + 3) == 39 {
                let esc: i64 = str_char_at(src, p + 2);
                let mut val: i64 = esc;
                if esc == 110 { val = 10; };       // \n
                if esc == 116 { val = 9; };        // \t
                if esc == 114 { val = 13; };       // \r
                if esc == 48  { val = 0; };        // \0
                if esc == 92  { val = 92; };       // \\
                if esc == 39  { val = 39; };       // \'
                if esc == 34  { val = 34; };       // \"
                tokens.push(tok_new(2, val, st));
                p = p + 4;
                handled = 1;
            };
            // v0.7.29 (defensive halt — Rust Unicode-escape char literal
            // `'\u{1F600}'`, `'\u{0041}'`, etc.). Pre-fix the char-lit
            // lexer matched only 1-char and 1-backslash-1-char forms;
            // the multi-char `\u{NNNN}` escape fell through to the
            // lifetime-token path (kind 98) and the v0.7.2 loop-label
            // halt fired with a wrong-class diagnostic talking about
            // labels, not Unicode escapes. Detect `'\u{` here and halt
            // with a hex-cast workaround pointer.
            if handled == 0 && p + 4 < slen && str_char_at(src, p + 1) == 92 && str_char_at(src, p + 2) == 117 && str_char_at(src, p + 3) == 123 {
                print("ERROR: Unicode-escape char literal `'\\u{NNNN}'` (e.g. `'\\u{0041}'`, `'\\u{1F600}'`) is not yet supported in Nucleor. Pre-v0.7.29 the char-lit lexer fell through to the lifetime-token path and the v0.7.2 loop-label halt fired with a wrong-class diagnostic about labels.");
                print("       Workaround: write the codepoint as an integer literal cast — `let c: i64 = 0x0041;` (for 'A') or `let c: i64 = 0x1F600;` (for an emoji codepoint). All Nucleor char-equivalent comparisons are integer-equivalent under the i64-everywhere ABI. Tracked for forward-roadmap (lex-time `\\u{...}` codepoint parsing → int-lit token).");
                panic("nucleor: Unicode-escape char literal `'\\u{...}'` not yet supported (see ERROR diagnostic above)");
            };
            if handled == 0 {
                // T2.5 (v0.2.351) fallback: apostrophe → lifetime token.
                p = p + 1;
                let id_st: i64 = p;
                while p < slen && (is_alnum(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) { p = p + 1; };
                let lt_name: str = str_substring(src, id_st, p);
                tokens.push(tok_new(98, lt_name, st));
            };
        }
        else { p = p + 1; };
    };
    tokens.push(tok_new(0, 0, slen));
    return tokens;
}

#[manual_drop]
fn parse_postfix(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_primary(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    // v0.7.7 (defensive halt): C/Java-idiom `x++` / `x--` post-
    // increment/decrement operators don't exist in Rust (or Nucleor).
    // Pre-fix surfaced as wrong-class `NR020: parse_primary cannot
    // start expression at token kind 20` (the second `+` after `x+`)
    // because the `+` after the primary parses as a binop, then
    // parse_primary fails on the second `+`. Detect the `++`/`--`
    // shape after a primary and halt cleanly with `x = x + 1`
    // workaround pointer.
    if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 20 {
        print("ERROR: post-increment `x++` is not supported in Nucleor (Rust doesn't have `++`/`--` operators). Pre-v0.7.7 surfaced as wrong-class `NR020: parse_primary cannot start expression at token kind 20` (the second `+`). Workaround: write the explicit assignment `x = x + 1;` (or `x += 1;` if `+=` is supported in your context). Tracked for forward-roadmap (no plans to add `++`/`--` — Rust-style explicit assignment is the canonical form).");
        panic("nucleor: `x++` post-increment not supported (see ERROR diagnostic above)");
    };
    if pk(tokens, cp) == 21 && pk(tokens, cp + 1) == 21 {
        print("ERROR: post-decrement `x--` is not supported in Nucleor (Rust doesn't have `++`/`--` operators). Pre-v0.7.7 surfaced as wrong-class `NR020: parse_primary cannot start expression at token kind 21` (the second `-`). Workaround: write the explicit assignment `x = x - 1;` (or `x -= 1;` if `-=` is supported in your context). Tracked for forward-roadmap (no plans to add `++`/`--` — Rust-style explicit assignment is the canonical form).");
        panic("nucleor: `x--` post-decrement not supported (see ERROR diagnostic above)");
    };
    while pk(tokens, cp) == 45 || pk(tokens, cp) == 54 || pk(tokens, cp) == 97 {
        if pk(tokens, cp) == 97 {
            // RFC-0016 phase 1: `?` postfix — desugars at lower-time into
            // err-check + early return on Err / None. Inner expression is
            // expected to be Result<T, E> or Option<T> (compiler trusts the
            // layout: cell 0 = tag, cell 1 = payload; tag 0 = Err/None).
            cp = cp + 1;
            node = mk2(pool, 122, node);
        } else {
        if pk(tokens, cp) == 45 {
            let mut fname: str = "";
            // v0.6.74 RFC V1.1 step 3: tuple-struct positional access.
            // `p.0` / `p.1` lex as `.` + int-literal token. Synthesize
            // the synthetic field name `__<digit>` at parse time so
            // the existing field-access type-check + lower paths
            // resolve to the matching `__<digit>` field declared in
            // parse_struct_decl's paren-form path.
            if pk(tokens, cp + 1) == 2 { fname = str_concat("__", str_from_int(pkv(tokens, cp + 1))); }
            else { fname = pkv(tokens, cp + 1); };
            let p2: i64 = cp + 2;
            let mut tname: str = "";
            let mut ctor_like: i64 = 0;
            if node_kind(pool, node) == 3 {
                tname = node_field(pool, node, 1);
                if str_len(tname) > 0 && str_len(fname) > 0 && str_char_at(tname, 0) >= 65 && str_char_at(tname, 0) <= 90 && str_char_at(fname, 0) >= 65 && str_char_at(fname, 0) <= 90 {
                    ctor_like = 1;
                };
            };
            if ctor_like == 1 && pk(tokens, p2) == 52 {
                let mut qp: i64 = p2 + 1;
                let mut qargs: Vec<i32> = Vec::new();
                while pk(tokens, qp) != 53 && pk(tokens, qp) != 0 {
                    if vec_len(qargs) > 0 {
                        qp = expect_tok(tokens, qp, 44);
                        if pk(tokens, qp) == 53 { break; };
                    };
                    let _field_name: str = pkv(tokens, qp);
                    qp = expect_tok(tokens, qp + 1, 42);
                    let mut er: Vec<i32> = parse_expr(tokens, qp, pool);
                    qargs.push(pr_val(er));
                    qp = pr_pos(er);
                };
                qp = expect_tok(tokens, qp, 53);
                cp = qp;
                node = mk4(pool, 12, tname, fname, mk_list(pool, qargs));
            } else if pk(tokens, p2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, p2 + 1, pool);
                cp = pr_pos(ar); node = mk4(pool, 8, node, fname, pr_val(ar));
            } else if pk(tokens, p2) == 46 && pk(tokens, p2 + 1) == 32 {
                // v0.6.98 RFC V1.7-ext: turbofish syntax
                // `.method::<TypeArgs>(args)`. Pre-fix surfaced as
                // wrong-class `error[NR020]: parse_primary cannot
                // start expression at token kind 46` because the
                // postfix parser had no `::<` branch. Now: skip the
                // balanced `<...>` type-args (advisory under today's
                // mangling — Nucleor monomorphises by parameter, not
                // by call-site turbofish) and parse the trailing
                // `(args)` as a regular method call.
                let v098_after_args: i64 = skip_angle_group(tokens, p2 + 1);
                if pk(tokens, v098_after_args) == 50 {
                    let mut v098_ar: Vec<i32> = parse_args(tokens, v098_after_args + 1, pool);
                    cp = pr_pos(v098_ar); node = mk4(pool, 8, node, fname, pr_val(v098_ar));
                } else {
                    print(str_concat("ERROR: turbofish form `.", str_concat(fname, "::<...>` without trailing call `(...)` is not yet supported in Nucleor. Pre-v0.6.98 surfaced as wrong-class `NR020: parse_primary cannot start expression at token kind 46`. Workaround: ensure the turbofish is followed by call args (`.collect::<Vec<i64>>()`), or drop the turbofish and let inference resolve (`let v: Vec<i64> = it.collect();`).")));
                    panic("nucleor: turbofish without call args not yet supported (see ERROR diagnostic above)");
                };
            } else if ctor_like == 1 {
                let mut empty: Vec<i32> = Vec::new();
                cp = p2;
                node = mk4(pool, 12, tname, fname, mk_list(pool, empty));
            } else { cp = p2; node = mk3(pool, 9, node, fname); };
        } else {
            let mut ir: Vec<i32> = parse_expr(tokens, cp + 1, pool);
            // v0.4.55: NUC-FEEDBACK silent-segfault guard for str/Vec
            // slice syntax. Pre-fix `s[0..5]` printed "Parse error
            // ... expected token 55 got 58" but the build silently
            // continued, producing broken IR that SIGSEGVed at runtime.
            // Slice expressions aren't yet supported in the indexer
            // surface; halt cleanly with a workaround pointing at
            // `str_substring(s, lo, hi)` (or vec_slice when shipped).
            let after_idx_tok: i64 = pk(tokens, pr_pos(ir));
            if after_idx_tok == 58 || after_idx_tok == 96 {
                print("ERROR: slice syntax `expr[lo..hi]` is not yet supported (was a silent SIGSEGV pre-v0.4.55). Workarounds: for `str` use `str_substring(s, lo, hi)`; for `Vec<T>` use an explicit element-wise loop or build a new Vec via `vec_push` over the desired range.");
                panic("nucleor: slice expression `expr[lo..hi]` not supported");
            };
            // v0.6.63 (probe finding 2026-05-02-rfc0034-ct-param-first-
            // pass-residual-edges, gap 1): canonical RFC-0034 explicit
            // CT-arg call form `ct_inc[42](x)` pre-fix parsed as
            // `name[index_expr]` (kind-10 indexer) followed by `(args)`
            // call — the call lowered to invoke the indexed value as
            // a fn pointer, which produced INVALID IR and SEGFAULTed
            // at runtime (rc=139). Detect the bracket-then-paren shape
            // when the indexer's BASE is a kind-3 var-ref (typical fn-
            // name shape) and halt with a clean diag pointing at the
            // workaround (omit the `[N]` from the call site — the
            // default erases anyway in RFC-0034 first-pass).
            let idx_end_v063: i64 = pr_pos(ir);
            let base_kind_v063: i64 = node_kind(pool, node);
            cp = expect_tok(tokens, idx_end_v063, 55); node = mk3(pool, 10, node, pr_val(ir));
            if pk(tokens, cp) == 50 && base_kind_v063 == 3 {
                print("ERROR: RFC-0034 explicit compile-time argument call form `name[ARGS](args)` is not yet supported in Nucleor's first-pass `[]` parser. Pre-v0.6.63 the form parsed as `name[index]` followed by `(args)` call — the call lowered to an invalid IR and SEGFAULTed at runtime (rc=139). Workaround: omit the `[N]` from the call site — RFC-0034 first-pass erases the CT-args at lower-time, so `f(args)` is observably equivalent to `f[N](args)` for the unspecialized version. Tracked for forward-roadmap (call-site CT-arg specialization is the v1 RFC-0034 ship).");
                panic("nucleor: RFC-0034 explicit CT-arg call form not yet supported (see ERROR diagnostic above)");
            };
        };
        };
    };
    return pr(cp, node);
}

#[manual_drop]
fn parse_if(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // RFC-0016 sugar: `if let PATTERN = EXPR { THEN } else { ELSE }`
    // desugars to `match EXPR { PATTERN => { THEN }, _ => { ELSE } }`.
    // Supported patterns: Some(x), None, Ok(v), Err(e), EnumName::Variant[(b)].
    if pk(tokens, pos) == 11 {
        let mut ip: i64 = pos + 1;
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        // v0.7.60 (defensive halt — paren-wrapped pattern in `if let` /
        // `while let`: `if let (Some(x)) = opt { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: parse_primary cannot
        // start an expression at token kind 11`. Sister to v0.7.54
        // paren-wrapped variant-payload halt.
        if pk(tokens, ip) == 50 {
            print("ERROR: paren-wrapped pattern in `if let` / `while let` (e.g. `if let (Some(x)) = opt { ... }`) is not yet supported in Nucleor. Pre-v0.7.60 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 11` because the pattern dispatcher had no `(` branch.");
            print("       Workaround: drop the extra parens — `if let Some(x) = opt { ... }` is the canonical shape. Sister to v0.7.54 paren-wrapped variant-payload halt.");
            panic("nucleor: paren-wrapped pattern in if-let/while-let not yet supported (see ERROR diagnostic above)");
        };
        let pat_tt: i64 = pk(tokens, ip);
        if pat_tt == 1 && (str_eq(pkv(tokens, ip), "Some") == 1 || str_eq(pkv(tokens, ip), "None") == 1 || str_eq(pkv(tokens, ip), "Ok") == 1 || str_eq(pkv(tokens, ip), "Err") == 1) {
            vname = pkv(tokens, ip);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 {
                    binding = pkv(tokens, ip);
                    ip = ip + 1;
                    // v0.6.90 (defensive halt): nested pattern
                    // `if/while let Some(Some(v)) = opt` pre-fix
                    // surfaced as wrong-class `NR020: expected ')',
                    // got '('` because the parser reads the binding
                    // slot as a single ident.
                    if pk(tokens, ip) == 50 {
                        print(str_concat("ERROR: nested patterns in `if let` / `while let` (e.g. `if let ", str_concat(vname, str_concat("(Some(v)) = opt`) are not yet supported in Nucleor. Pre-v0.6.90 the inner `(` after the binding name surfaced as wrong-class `error[NR020]: expected ')', got '('` because the parser reads the binding slot as a single ident. Workaround: destructure in two steps — `if let ", str_concat(vname, "(inner) = outer { if let Some(v) = inner { ... } }`. Tracked for forward-roadmap (recursive pattern parser).")))));
                        panic(str_concat("nucleor: nested ctor pattern `", str_concat(vname, "(Some(...))` not yet supported (see ERROR diagnostic above)")));
                    };
                };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && pk(tokens, ip + 1) == 46 {
            ename = pkv(tokens, ip);
            ip = expect_tok(tokens, ip + 1, 46);
            vname = pkv(tokens, ip); ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && str_eq(pkv(tokens, ip), "_") == 1 && pk(tokens, ip + 1) == 40 {
            // v0.7.80 (defensive halt — Rust wildcard pattern `_` in
            // `if let _ = expr` / `while let _ = expr`). Pre-fix the
            // `_` ident didn't match any of the recognized
            // pattern shapes (Some/None/Ok/Err, Type::Variant), the
            // if-let parser fell through with `ename` empty, and the
            // outer parser then hit `let` (token 11) at expression
            // start, surfacing as wrong-class
            // `error[NR020]: parse_primary cannot start an expression
            // at token kind 11`. Halt cleanly with a workaround
            // pointer (`let _ = expr;` already works as a discard;
            // the if-let `_` form is rare and equivalent to a plain
            // boolean `if true { ... }`). Sister to v0.7.50
            // or-pattern halt — same if-let pattern-shape family.
            print("ERROR: wildcard pattern `_` in `if let` / `while let` (e.g. `if let _ = expr { ... }`) is not yet supported in Nucleor. Pre-v0.7.80 the if-let pattern dispatcher had no `_` branch and fell through with no recognized pattern, so the outer parser then hit `let` (token 11) at expression start and emitted wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 11`.");
            print("       Workaround: this form is rare and equivalent to a plain `if true { ... }` (or `while true { ... }`); evaluate the expression on its own line via `let _ = expr;` (already supported as a discard) and then run the body unconditionally. Tracked for forward-roadmap (wildcard-pattern in if-let is a small parser extension).");
            panic("nucleor: wildcard pattern `_` in if-let / while-let not yet supported (see ERROR diagnostic above)");
        };
        if str_len(ename) > 0 {
            // v0.7.50 (defensive halt — Rust or-pattern in `if let` /
            // `while let`: `if let Some(1) | Some(2) = opt`). Pre-fix
            // this surfaced as wrong-class `error[NR020]: expected '=',
            // got token 65` (token 65 = `|`) because the if-let parser
            // expects `=` immediately after the first pattern. Halt
            // cleanly with a separate-arm workaround for if-let, or use
            // a match for true or-pattern semantics.
            if pk(tokens, ip) == 65 {
                print("ERROR: or-patterns in `if let` / `while let` (e.g. `if let Some(1) | Some(2) = opt { ... }`) are not yet supported in Nucleor. Pre-v0.7.50 surfaced as wrong-class `error[NR020]: expected '=', got token 65` (token 65 = `|`). Match-arm or-patterns (`match x { 1 | 2 => ... }`) already work — only the if-let / while-let form is missing.");
                print("       Workaround: use a `match` for true or-pattern semantics — `match opt { Some(1) | Some(2) => { /* hit */ }, _ => { /* miss */ } }`. Or check each variant separately — `if let Some(x) = opt { if x == 1 || x == 2 { ... } }`. Tracked for forward-roadmap (or-pattern in if-let / while-let is a small parser extension; sister to the existing match-arm or-pattern work).");
                panic("nucleor: or-pattern in `if let` / `while let` not yet supported (see ERROR diagnostic above)");
            };
            // We have a pattern; parse `= EXPR { BODY } [else { BODY }]`
            ip = expect_tok(tokens, ip, 40); // `=`
            let v772_expr_start: i64 = ip;
            let mut sr: Vec<i32> = parse_expr(tokens, ip, pool);
            // v0.7.72 (defensive halt — Rust 2024 if-let chain:
            // `if let Some(x) = opt && cond { ... }`). Pre-fix
            // parse_expr greedily consumed `opt && cond` as a single
            // boolean expression and the desugared match scrutinee
            // referenced the pattern binding (`x`) in the chained
            // condition BEFORE the match-arm bound it — emitting an
            // undefined-name call that clang linked as wrong-class
            // `error[TYP-005]: undefined function 'x()'`. Detect by
            // scanning the consumed scrutinee tokens for `&&`
            // (token 36) — Rust 2024 if-let chains require pattern
            // + guard composition that Nucleor's desugar does not
            // yet model. Sister to v0.7.50 or-pattern halt (same
            // family of "Rust syntax tighter than Nucleor's if-let
            // desugar").
            let mut v772_scan: i64 = v772_expr_start;
            let v772_end: i64 = pr_pos(sr);
            let mut v772_has_chain: i64 = 0;
            while v772_scan < v772_end {
                if pk(tokens, v772_scan) == 36 { v772_has_chain = 1; v772_scan = v772_end; }
                else { v772_scan = v772_scan + 1; };
            };
            if v772_has_chain == 1 {
                print("ERROR: if-let / while-let chains (`if let PATTERN = EXPR && cond { ... }`) are not yet supported in Nucleor. Pre-v0.7.72 surfaced as wrong-class `error[TYP-005]: undefined function '<binding>()'` at clang link because parse_expr greedily consumed `EXPR && cond` as a single boolean scrutinee that referenced the pattern binding before the match-arm could bind it.");
                print("       Workaround: split the chain — `if let Some(x) = opt { if cond { ... } }` — or pull the condition into the existing match-arm form with a guard. Tracked for forward-roadmap (Rust 2024 if-let chains require pattern + guard composition; sister to v0.7.50 or-pattern halt).");
                panic("nucleor: if-let chain (`if let ... = ... && cond`) not yet supported (see ERROR diagnostic above)");
            };
            let mut sp: i64 = expect_tok(tokens, pr_pos(sr), 52); // `{`
            let mut br: Vec<i32> = parse_stmts(tokens, sp, pool);
            sp = expect_tok(tokens, pr_pos(br), 53); // `}`
            let mut else_body: i64 = 0;
            if pk(tokens, sp) == 14 {
                sp = sp + 1;
                // v0.7.46 (defensive halt — `if let` chained `else if let`
                // / `else if`). Pre-fix `if let Some(x) = a { ... } else if
                // let Some(y) = b { ... }` surfaced as wrong-class
                // `error[NR020]: expected '{', got token 13` (token 13 =
                // `if`) because the if-let parser only knows the bare
                // `else { ... }` form. Halt cleanly with a nested-else
                // workaround pointer.
                if pk(tokens, sp) == 13 {
                    print("ERROR: `else if` (or `else if let`) chained after an `if let` is not yet supported in Nucleor. Pre-v0.7.46 surfaced as wrong-class `error[NR020]: expected '{', got token 13` (token 13 = `if`) because the if-let parser only knows the bare `else { ... }` form.");
                    print("       Workaround: nest the second `if`/`if let` inside the `else` block — `if let Some(x) = a { ... } else { if let Some(y) = b { ... } else { ... } }`. Each layer of nesting adds one `{ ... }` pair. Tracked for forward-roadmap (else-if-chain support is a small if-let parser extension; sister to the existing `if cond { ... } else if cond { ... }` shape that already works).");
                    panic("nucleor: `else if` after `if let` not yet supported (see ERROR diagnostic above)");
                };
                sp = expect_tok(tokens, sp, 52);
                let mut er: Vec<i32> = parse_stmts(tokens, sp, pool);
                sp = expect_tok(tokens, pr_pos(er), 53);
                else_body = pr_val(er);
            } else {
                let mut empty_stmts: Vec<i32> = Vec::new();
                else_body = mk_list(pool, empty_stmts);
            };
            // v0.4.50: NUC-FEEDBACK silent-segfault guard.
            // Pre-fix `if let Some(x) = v.first()` (and .last() / .pop() /
            // vec_first / vec_last / vec_pop) silently segfaulted at
            // runtime: the helper returns a bare i64 (not Option<T>), the
            // match-arm dispatcher then called vec_get on the i64 value
            // treating it as an Option pointer, dereferencing garbage.
            // Adopters writing the canonical Rust idiom got a SIGSEGV
            // with no compile-time signal.
            //
            // Real fix is to wrap these helpers in Option<T> at the
            // stdlib level (RFC-0024 Phase 4 territory). Until then,
            // halt the build with a clear diagnostic that names the
            // call and points to the workaround.
            if str_eq(ename, "Option") == 1 {
                let src_nid: i64 = pr_val(sr);
                let src_kind: i64 = node_kind(pool, src_nid);
                let mut bad_call: str = "";
                if src_kind == 8 {
                    let mname: str = node_field(pool, src_nid, 2);
                    if str_eq(mname, "first") == 1 || str_eq(mname, "last") == 1 || str_eq(mname, "pop") == 1 {
                        bad_call = str_concat(".", mname);
                    };
                };
                if src_kind == 7 {
                    let cname: str = node_field(pool, src_nid, 1);
                    if str_eq(cname, "vec_first") == 1 || str_eq(cname, "vec_last") == 1 || str_eq(cname, "vec_pop") == 1 {
                        bad_call = cname;
                    };
                };
                if str_len(bad_call) > 0 {
                    print(str_concat("ERROR: `if let Some(...) = ", str_concat(bad_call, "(...)` silently segfaults — the helper returns a bare i64, not Option<T>. Workaround: branch on length explicitly: `if vec_len(v) > 0 { let x: i64 = v[0]; ... } else { ... }`. Pinned for a future Option<T> wrapper ship (RFC-0024 Phase 4).")));
                    panic(str_concat("nucleor: if-let on non-Option-returning helper ", bad_call));
                };
            };
            // Build match arms: [PATTERN => then_body, _ => else_body]
            let mut arms: Vec<i32> = Vec::new();
            arms.push(mk6(pool, 39, ename, vname, binding, pr_val(br), 0));
            arms.push(mk6(pool, 39, "__wild", "", "", else_body, 0));
            return pr(sp, mk3(pool, 38, pr_val(sr), mk_list(pool, arms)));
        };
        // `let` not followed by a recognized pattern — fall through to plain if.
    };
    let mut cr: Vec<i32> = parse_expr(tokens, pos, pool);
    // v0.4.69: same `=` vs `==` typo guard as parse_while_stmt.
    if pk(tokens, pr_pos(cr)) == 40 {
        print("ERROR: condition position has `=` (assignment) where `==` (equality) was expected. Pre-v0.4.69 the parser printed a parse error and silently continued. Did you mean `if x == y { ... }` instead of `if x = y { ... }`?");
        panic("nucleor: `=` in if-condition position (probably `==` typo)");
    };
    let mut cp: i64 = expect_tok(tokens, pr_pos(cr), 52);
    let mut tr: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(tr), 53);
    let mut else_id: i64 = 0 - 1;
    if pk(tokens, cp) == 14 {
        cp = cp + 1;
        if pk(tokens, cp) == 13 { cp = cp + 1;
            let mut elif: Vec<i32> = parse_if(tokens, cp, pool);
            let mut els: Vec<i32> = Vec::new(); els.push(pr_val(elif));
            else_id = mk_list(pool, els); cp = pr_pos(elif);
        } else {
            cp = expect_tok(tokens, cp, 52);
            let mut er: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(er), 53); else_id = pr_val(er);
        };
    };
    return pr(cp, mk4(pool, 23, pr_val(cr), pr_val(tr), else_id));
}

#[manual_drop]
fn parse_while_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // RFC-0016 sugar: `while let PATTERN = EXPR { BODY }` desugars to
    // `loop { match EXPR { PATTERN => { BODY }, _ => break } }`.
    // For v0.1.16: implement as a while-true with an embedded match
    // that breaks on wildcard arm.
    if pk(tokens, pos) == 11 {
        let mut ip: i64 = pos + 1;
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        // v0.7.60 (defensive halt — paren-wrapped pattern in `if let` /
        // `while let`: `if let (Some(x)) = opt { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: parse_primary cannot
        // start an expression at token kind 11`. Sister to v0.7.54
        // paren-wrapped variant-payload halt.
        if pk(tokens, ip) == 50 {
            print("ERROR: paren-wrapped pattern in `if let` / `while let` (e.g. `if let (Some(x)) = opt { ... }`) is not yet supported in Nucleor. Pre-v0.7.60 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 11` because the pattern dispatcher had no `(` branch.");
            print("       Workaround: drop the extra parens — `if let Some(x) = opt { ... }` is the canonical shape. Sister to v0.7.54 paren-wrapped variant-payload halt.");
            panic("nucleor: paren-wrapped pattern in if-let/while-let not yet supported (see ERROR diagnostic above)");
        };
        let pat_tt: i64 = pk(tokens, ip);
        if pat_tt == 1 && (str_eq(pkv(tokens, ip), "Some") == 1 || str_eq(pkv(tokens, ip), "None") == 1 || str_eq(pkv(tokens, ip), "Ok") == 1 || str_eq(pkv(tokens, ip), "Err") == 1) {
            vname = pkv(tokens, ip);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 {
                    binding = pkv(tokens, ip);
                    ip = ip + 1;
                    // v0.6.90 (defensive halt): nested pattern
                    // `if/while let Some(Some(v)) = opt` pre-fix
                    // surfaced as wrong-class `NR020: expected ')',
                    // got '('` because the parser reads the binding
                    // slot as a single ident.
                    if pk(tokens, ip) == 50 {
                        print(str_concat("ERROR: nested patterns in `if let` / `while let` (e.g. `if let ", str_concat(vname, str_concat("(Some(v)) = opt`) are not yet supported in Nucleor. Pre-v0.6.90 the inner `(` after the binding name surfaced as wrong-class `error[NR020]: expected ')', got '('` because the parser reads the binding slot as a single ident. Workaround: destructure in two steps — `if let ", str_concat(vname, "(inner) = outer { if let Some(v) = inner { ... } }`. Tracked for forward-roadmap (recursive pattern parser).")))));
                        panic(str_concat("nucleor: nested ctor pattern `", str_concat(vname, "(Some(...))` not yet supported (see ERROR diagnostic above)")));
                    };
                };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && pk(tokens, ip + 1) == 46 {
            ename = pkv(tokens, ip);
            ip = expect_tok(tokens, ip + 1, 46);
            vname = pkv(tokens, ip); ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        };
        if str_len(ename) > 0 {
            ip = expect_tok(tokens, ip, 40); // `=`
            let mut sr: Vec<i32> = parse_expr(tokens, ip, pool);
            let mut sp: i64 = expect_tok(tokens, pr_pos(sr), 52); // `{`
            let mut br: Vec<i32> = parse_stmts(tokens, sp, pool);
            sp = expect_tok(tokens, pr_pos(br), 53); // `}`
            // v0.4.50: NUC-FEEDBACK silent-infinite-loop guard.
            // Pre-fix `while let Some(x) = stack.pop()` did NOT
            // segfault but DID infinite-loop printing 0s — pop()
            // returns a bare i64 (not Option), the match-arm
            // dispatcher's "Some" path always succeeded and the
            // loop never terminated. Mirrors the if-let guard at
            // line 1487+.
            if str_eq(ename, "Option") == 1 {
                let wsrc_nid: i64 = pr_val(sr);
                let wsrc_kind: i64 = node_kind(pool, wsrc_nid);
                let mut wbad: str = "";
                if wsrc_kind == 8 {
                    let wmname: str = node_field(pool, wsrc_nid, 2);
                    if str_eq(wmname, "first") == 1 || str_eq(wmname, "last") == 1 || str_eq(wmname, "pop") == 1 {
                        wbad = str_concat(".", wmname);
                    };
                };
                if wsrc_kind == 7 {
                    let wcname: str = node_field(pool, wsrc_nid, 1);
                    if str_eq(wcname, "vec_first") == 1 || str_eq(wcname, "vec_last") == 1 || str_eq(wcname, "vec_pop") == 1 {
                        wbad = wcname;
                    };
                };
                if str_len(wbad) > 0 {
                    print(str_concat("ERROR: `while let Some(...) = ", str_concat(wbad, "(...)` silently infinite-loops — the helper returns a bare i64, not Option<T>, so the Some arm always matches and the loop never terminates. Workaround: use a `while vec_len(v) > 0 { ... v.pop(); ... }` pattern. Pinned for a future Option<T> wrapper ship (RFC-0024 Phase 4).")));
                    panic(str_concat("nucleor: while-let on non-Option-returning helper ", wbad));
                };
            };
            // Build break statement (node kind 26)
            let break_stmt: i64 = mk2(pool, 26, 0);
            let mut break_stmts: Vec<i32> = Vec::new();
            break_stmts.push(break_stmt);
            // Match arms: [PATTERN => body, _ => break]
            let mut arms: Vec<i32> = Vec::new();
            arms.push(mk6(pool, 39, ename, vname, binding, pr_val(br), 0));
            arms.push(mk6(pool, 39, "__wild", "", "", mk_list(pool, break_stmts), 0));
            let match_node: i64 = mk3(pool, 38, pr_val(sr), mk_list(pool, arms));
            // Wrap match in a stmt list to be the loop body
            let mut loop_body: Vec<i32> = Vec::new();
            loop_body.push(mk3(pool, 25, match_node, 0));
            // True condition: literal 1
            let true_node: i64 = mk2(pool, 1, 1);
            return pr(sp, mk3(pool, 24, true_node, mk_list(pool, loop_body)));
        };
    };
    let mut cr: Vec<i32> = parse_expr(tokens, pos, pool);
    // v0.4.69: NUC-FEEDBACK silent-miscompute close — detect `=` vs
    // `==` typo. Pre-fix `while x = 0 { ... }` printed a parse error
    // but silently continued, building a binary with broken IR.
    // Halt cleanly at parse time with a clear hint.
    if pk(tokens, pr_pos(cr)) == 40 {
        print("ERROR: condition position has `=` (assignment) where `==` (equality) was expected. Pre-v0.4.69 the parser printed a parse error and silently continued, building broken IR. Did you mean `while x == y { ... }` instead of `while x = y { ... }`?");
        panic("nucleor: `=` in while-condition position (probably `==` typo)");
    };
    let mut cp: i64 = expect_tok(tokens, pr_pos(cr), 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk3(pool, 24, pr_val(cr), pr_val(br)));
}

#[manual_drop]
fn parse_struct_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'struct', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // v0.6.65 (probe finding 2026-05-02-rfc0034-ct-param-first-pass-
    // residual-edges, gap 3): canonical RFC-0034 form `struct Buf[N:
    // usize] { data: Vec<i64> }` (CT-param on a struct decl) pre-fix
    // saw `[` (token 54) where the parser expected `{` or `<`,
    // surfacing as wrong-class `error[NR020]: parse error at byte
    // 10: expected '{', got '['`. The fn-decl precedent at line ~970
    // (`skip_compile_time_params`) ships, but parse_struct_decl is on
    // the legacy skipper. Halt at parse_struct_decl with a clean diag
    // pointing at the workaround (drop the `[N]` from the struct decl
    // — RFC-0034 first-pass erases CT-args at lower-time, so the
    // param has no observable effect on the unspecialized struct).
    if pk(tokens, cp) == 54 {
        print("ERROR: RFC-0034 compile-time `[]` parameters on struct declarations (e.g. `struct Buf[N: usize] { data: Vec<i64> }`) are not yet supported in Nucleor's first-pass `[]` parser. Pre-v0.6.65 the parser rejected with `error[NR020]: parse error ... expected '{', got '['` — wrong-class. Workaround: drop the `[N]` from the struct decl (RFC-0034 first-pass erases CT-args at lower-time anyway, so the param has no observable effect on the unspecialized struct). Tracked for forward-roadmap (struct-side CT-param substrate is the v1 RFC-0034 ship).");
        panic("nucleor: struct CT-params not yet supported (see ERROR diagnostic above)");
    };
    // Optional generic params: struct Name<T, U> { ... }
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    // v0.5.28: canonical Rust unit-struct syntax `struct U;` (probe finding
    // 2026-05-01-unit-struct-semicolon-form-parse-fail). Pre-fix expected
    // `{` and panicked NR020 on `;` — translators porting Rust hit this
    // constantly because `struct Marker;` is the canonical form. Now both
    // `struct U;` and `struct U {}` lower to the same empty-fields decl
    // (kind 33 with empty fields list). Construction still requires
    // `U {}` value form; a follow-up will let `U` (bare ident) resolve
    // to the zero-field constructor.
    // v0.6.46 (probe finding 2026-05-02-where-clause-struct-and-impl-
    // still-NR020): pre-fix `struct Wrapper<T> where T: A { … }` panicked
    // with NR020 because `expect_tok(cp, 52)` saw `where` (an ident, not
    // `{`) after the gparams. v0.6.11 wired where-clauses for fn decls
    // but explicitly noted parse_struct_decl was left on the legacy
    // skipper. Skip the where-clause here so canonical Rust struct
    // declarations parse cleanly. Bounds aren't yet wired into the
    // struct AST (forward-roadmap); skipping unblocks adopters.
    cp = skip_where_clause(tokens, cp);
    if pk(tokens, cp) == 43 {
        let unit_nid: i64 = mk4(pool, 33, name, mk_list(pool, Vec::new()), gparams);
        return pr(cp + 1, unit_nid);
    };
    // v0.6.53 (probe finding 2026-05-02-nested-struct-pattern-and-
    // tuple-struct-decl-NR020 sub-case 2): tuple-struct declaration
    // `struct P(i64, i64);` (positional-field shape) is a canonical
    // Rust form. Pre-fix the next-token check below saw `(` (token
    // 50) instead of `{` and panicked NR020 with "expected '{', got
    // '('" — adopter sees the wrong-class error pointing at the
    // open-paren without naming the unsupported feature. Now halt
    // with a clean diag at the decl naming the workaround (named-
    // field form). Tuple-struct support is a parse-extension forward-
    // roadmap (positional field synthesis + `p.0` / `p.1` access path).
    // v0.6.73 RFC V1.1 (probe finding 2026-05-02-nested-struct-pattern-
    // and-tuple-struct-decl-NR020 sub-case 2): tuple-struct positional-
    // field synthesis. Pre-fix `struct P(T1, T2);` halted at parse with
    // a workaround diagnostic. Now: parse the paren-form, synthesize
    // field names `__0`, `__1`, ..., `__N` (matching Rust's positional
    // accessor naming where `p.0` resolves to the 0-th field). Struct
    // value retains kind-33 — downstream type-check + lowering use the
    // synthetic field names; constructor `P(a, b)` and field access
    // `p.0` / `p.1` are wired in subsequent commits.
    //
    // Tuple-struct shape detection: structs with all field names
    // matching `__<digit>+` are tuple-style (used by constructor
    // detection + `.<digit>` access lowering downstream).
    let mut fields: Vec<i32> = Vec::new();
    if pk(tokens, cp) == 50 {
        cp = cp + 1; // past `(`
        let mut tup_idx_v073: i64 = 0;
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if vec_len(fields) > 0 {
                cp = expect_tok(tokens, cp, 44);
                if pk(tokens, cp) == 51 { break; };
            };
            // Optional `pub` field-vis qualifier (matching Rust shape).
            if pk(tokens, cp) == 72 { cp = cp + 1; };
            let mut tup_tr_v073: Vec<i32> = parse_type(tokens, cp);
            cp = pr_pos(tup_tr_v073);
            let synth_name_v073: str = str_concat("__", str_from_int(tup_idx_v073));
            fields.push(mk3(pool, 41, synth_name_v073, pr_val(tup_tr_v073)));
            tup_idx_v073 = tup_idx_v073 + 1;
        };
        cp = expect_tok(tokens, cp, 51); // past `)`
        // Tuple structs end with `;`. Optional — accept brace-form
        // tail too in case adopters write `struct P(T1, T2) {}`.
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        return pr(cp, mk4(pool, 33, name, mk_list(pool, fields), gparams));
    };
    cp = expect_tok(tokens, cp, 52); // {
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(fields) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
        };
        // v0.4.1 RFC-NRT-004 §D: optional `pub` field-visibility
        // qualifier. Pre-fix the parser misread `pub x: i64` as a
        // top-level `pub` item nested inside the struct body and
        // crashed with cascading "statement-level keyword at module
        // scope" errors followed by AST corruption (segfault on
        // some hosts). Nucleor's current visibility model treats
        // all struct fields as accessible from importing modules
        // regardless of field-level pub, so the qualifier is parsed
        // and discarded for now (matching Rust shape; field-private
        // enforcement can land later without breaking existing
        // sources).
        if pk(tokens, cp) == 72 { cp = cp + 1; };
        // v0.4.16: optional `mut` field qualifier. Nucleor's current
        // model treats fields as mutable if the owning binding is
        // `let mut`, so the field-level mut is informational only.
        // Pre-fix: `mut value: i64` was parsed as field name = "mut",
        // value field index slipped to -1, runtime vec_set panicked.
        if pk(tokens, cp) == 12 { cp = cp + 1; };
        let fn2: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        // v0.6.36 (probe finding 2026-05-01-self-recursive-struct-infinite-
        // size-accepted): pre-fix `struct Node { val: i64, next: Node }`
        // (recursive type without Box/&) was accepted at parse + type-check
        // and crashed at runtime with STATUS_STACK_OVERFLOW (Windows
        // exception 0xC00000FD) on instantiation — the struct contains
        // itself directly so the size is infinite. Rust statically
        // rejects this with E0072 ("recursive type `Node` has infinite
        // size"). Mirror that at parse-time. The field type is the bare
        // struct name; reject. Fields wrapping the recursive type in
        // Box / & / & mut / Vec / Option<Box<…>> all carry distinct
        // type strings ("Box<Node>", "&Node", "Vec<Node>", "Option<Box<Node>>")
        // so the equality check below only fires on the direct-recursion
        // case.
        let field_type_v063: str = pr_val(tr);
        if str_eq(field_type_v063, name) == 1 {
            print(str_concat("error[NR036]: recursive type `", str_concat(name, str_concat("` has infinite size — field `", str_concat(fn2, str_concat("` is itself a `", str_concat(name, "` (containing itself directly).")))))));
            print("  Rust E0072: a struct that contains itself directly cannot be sized at compile time. Pre-v0.6.36 Nucleor accepted the declaration and crashed at instantiation with STATUS_STACK_OVERFLOW (Windows exception 0xC00000FD). v0.6.36 catches the recursion at parse-time.");
            print(str_concat("  Workaround: wrap the recursive field in `Box<", str_concat(name, str_concat(">` (heap-indirection, single-element list shape), or `Option<Box<", str_concat(name, str_concat(">>` (linked-list / tree shape with terminator), or `&", str_concat(name, "` (advisory until borrow lowering of recursive structs lands).")))))));
            panic(str_concat("nucleor: recursive struct ", str_concat(name, str_concat(" contains itself directly via field ", fn2))));
        };
        // v0.6.27 (probe finding 2026-05-02-duplicate-struct-decl-silently-
        // accepted, repro 3): duplicate field name in a struct decl was
        // silently accepted at decl-time; TYP-017 only fired at the init
        // site `P { x: 1, x: 2 }`. Adopters writing typo'd decls
        // (`struct Date { day: i64, day: i64 }`) got no signal until
        // construction. Mirror Rust E0124 ("field is already declared")
        // at decl-time.
        let mut dup_chk_v062: i64 = 0;
        while dup_chk_v062 < vec_len(fields) {
            let prior_v062: i64 = vec_get(fields, dup_chk_v062);
            let prior_name_v062: str = node_field(pool, prior_v062, 1);
            if str_eq(prior_name_v062, fn2) == 1 {
                print(str_concat("error[TYP-039]: field `", str_concat(fn2, str_concat("` is already declared in this struct (Rust E0124). Each field name must be unique within the decl."))));
                print(str_concat("  Two `", str_concat(fn2, "` fields parsed; the first one wins for offset / type, the second is unreachable but consumes the comma-list slot. TYP-017 catches the same family at init-site (`P { x: 1, x: 2 }`); v0.6.27 catches it earlier at the struct-decl site so adopters writing typo'd decls (`struct Date { day: i64, day: i64, month: i64 }`) get the signal at the decl, not at the first construction.")));
                print("  Workaround: rename or remove the duplicate field. If both names are wanted (different physical fields with the same logical role), pick one (`x` and `x_alt`).");
                panic(str_concat("duplicate field in struct decl: ", fn2));
            };
            dup_chk_v062 = dup_chk_v062 + 1;
        };
        fields.push(mk3(pool, 41, fn2, pr_val(tr)));
    };
    cp = cp + 1;
    return pr(cp, mk4(pool, 33, name, mk_list(pool, fields), gparams));
}

#[manual_drop]
fn parse_program(tokens: Vec<i32>, pool: Vec<i32>) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new(); let mut cp: i64 = 0;
    // T1.5b (v0.2.341): track `pub` keyword on top-level items.
    // Previously the `pub` token was silently swallowed. Now: when
    // we see `pub`, we set `pending_pub = 1` and re-enter the loop
    // without consuming any item. The next item we successfully
    // parse gets a marker node (kind 76 = pub_marker) emitted into
    // `items` immediately before the item itself, mirroring the
    // pattern already established for `pure fn` (kind 46). The
    // marker carries the item's name so downstream tools (the
    // visibility surface in `nuc summary`, the `nuc abi --exports`
    // walker, and T1.5c's resolver-layer enforcement) can identify
    // pub items without re-walking the source text.
    let mut pending_pub: i64 = 0;
    while pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 72 {
            pending_pub = 1;
            cp = cp + 1;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 10 {
            // extern fn — never carries `pub` (extern is its own visibility).
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 2, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 3 && pk(tokens, cp + 2) == 52 {
            // v0.7.26 (defensive halt — Rust FFI extern block form
            // `extern "C" { fn cfn(x: i64) -> i64; ... }`). Pre-fix
            // surfaced as wrong-class `error[NR020]: expected '{', got
            // ';'` because the parser only knows the single-line form
            // `extern "C" fn name(...);` (one decl, no surrounding
            // block). Halt cleanly with a workaround pointing to the
            // bare-decl form.
            print("ERROR: Rust FFI extern block form `extern \"C\" { fn cfn(x: i64) -> i64; ... }` is not yet supported in Nucleor. Pre-v0.7.26 surfaced as wrong-class `error[NR020]: expected '{', got ';'`.");
            print("       Workaround: drop the surrounding block — declare each FFI fn with the supported single-line form `extern \"C\" fn cfn(x: i64) -> i64;` (one decl per line, no `{` / `}`). Tracked for forward-roadmap (block-form support is a small parser extension; sister to v0.3.112 single-line acceptance).");
            panic("nucleor: extern block form `extern \"C\" { ... }` not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 3 && pk(tokens, cp + 2) == 10 {
            // v0.3.112: `extern "C" fn name(...)` (or any ABI string).
            // Pre-v0.3.112, the parser only recognized bare `extern fn`,
            // so the canonical Rust form `extern "C" fn abs(x: i64) -> i64;`
            // cascaded into 4+ parse errors. The ABI string is accepted
            // and discarded — Nucleor's only ABI today is the C calling
            // convention used by all extern declarations, so the explicit
            // marker is informational. Skip ABI literal then call into
            // parse_extern_fn at the `fn` token.
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 3, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 73 {
            // v0.6.55 (probe finding 2026-05-01-rust-syntax-translation-
            // fidelity-audit, const-fn row): canonical Rust form
            // `const fn double(x: i64) -> i64 { return x * 2; }` was
            // pre-fix rejected with `error[NR020]: parse error at byte
            // 9: expected ':', got identifier` because parse_const_decl
            // (called below for the const-decl path) expects a name +
            // `:` + type after `const`. The `fn` keyword (token 10)
            // tripped the `:`-expector. Wrong-class diagnostic — adopter
            // doesn't see "const fn not yet supported" but a confusing
            // parse error pointing at byte 9. Halt at parse with a clean
            // diag.
            if pk(tokens, cp + 1) == 10 {
                print("ERROR: `const fn` declarations are not yet supported in Nucleor. Pre-v0.6.55 the parser saw `fn` after `const` and rejected with the wrong-class diagnostic `error[NR020]: parse error at byte 9: expected ':', got identifier`. Workaround: drop the `const` qualifier — Nucleor v0.6 does not yet evaluate fn bodies at compile time, so a `const fn` is informationally equivalent to a regular `fn` in this version. Tracked for forward-roadmap (full const-eval substrate is the v1 const-fn ship).");
                panic("nucleor: `const fn` decl not yet supported (see ERROR diagnostic above)");
            };
            let mut r: Vec<i32> = parse_const_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 74 {
            let mut r: Vec<i32> = parse_type_alias_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 17 {
            let mut r: Vec<i32> = parse_struct_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 62 {
            let mut r: Vec<i32> = parse_enum_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 66 {
            let mut r: Vec<i32> = parse_trait_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 67 {
            // impl blocks don't carry pub (the items inside do).
            let mut r: Vec<i32> = parse_impl_block(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "pure") == 1 && pk(tokens, cp + 1) == 10 {
            // pure fn — parse as fn_decl, mark name with __pure_ prefix internally
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 2, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            // Tag function as pure by storing a marker node (kind 46).
            items.push(mk2(pool, 46, node_field(pool, fn_nid, 1)));
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, fn_nid, 1))); pending_pub = 0; };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 10 {
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 1, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, fn_nid, 1))); pending_pub = 0; };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "async") == 1 && pk(tokens, cp + 1) == 10 {
            // v0.7.71 (defensive halt — Rust `async fn name() -> T { ... }`).
            // Pre-fix the `async` ident was silently skipped at the
            // module-item dispatch and the fn parsed normally as a
            // sync fn. Adopters writing `let r = fetch();` got the
            // value directly (rc=42 in our probe), expecting a
            // `Future<Output = i64>` to `.await`. Silent acceptance
            // is wrong-class — the Future protocol is missing entirely
            // (no executor, no `.await`, no state-machine lowering).
            // Halt cleanly at the decl. Sister to v0.6.53 `unsafe fn`
            // halt (same shape, same dispatch lookahead).
            print("ERROR: `async fn` is not yet supported in Nucleor. Pre-v0.7.71 the `async` keyword was silently stripped and the fn parsed as a regular synchronous fn — call sites got the inner value directly instead of a `Future<Output = T>` to `.await`. Workaround: drop the `async` qualifier and call the fn synchronously; for genuinely-concurrent work, use the existing thread/queue substrate (RFC-0007 SPSC/MPSC queues or Track G atomics) until the v1.x `async`/Future/executor substrate lands.");
            panic("nucleor: `async fn` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "unsafe") == 1 && pk(tokens, cp + 1) == 10 {
            // v0.6.53 (probe finding 2026-05-01-keyword-silent-strip-
            // audit, sub-case 1): `unsafe fn dangerous() -> i64 { ... }`
            // pre-fix had the `unsafe` keyword silently stripped at
            // parse — the fn decl parsed normally without the marker.
            // Visible-as-noop for adopters auditing translated Rust
            // code. Halt at the decl with a clean diag naming the
            // forward-roadmap status (Nucleor v0.6 has no checked
            // operations to opt out of, so `unsafe fn` is informational
            // only; the silent-strip removed the visual signal).
            print("ERROR: `unsafe fn` is not yet supported in Nucleor. Pre-v0.6.53 the `unsafe` keyword was silently stripped, leaving the fn body indistinguishable from a regular fn — adopters auditing Rust translation lost the visual marker. Workaround: drop the `unsafe` qualifier (Nucleor v0.6 has no checked operations to opt out of, so the qualifier is informational-only). Tracked for forward-roadmap (when v1 ships any checked-arith opt-out semantics, `unsafe` will gain meaning).");
            panic("nucleor: `unsafe fn` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "unsafe") == 1 && (pk(tokens, cp + 1) == 66 || pk(tokens, cp + 1) == 67) {
            // v0.7.61: sister halt to v0.6.53 — `unsafe trait T { ... }`
            // (token 66) and `unsafe impl T for S { ... }` (token 67)
            // were ALSO silent-stripped pre-fix (the `unsafe` ident was
            // just skipped in the dispatch). Same audit-loss as v0.6.53.
            // Halt cleanly with the same drop-qualifier workaround.
            let v761_kw: str = if pk(tokens, cp + 1) == 66 { "trait" } else { "impl" };
            print(str_concat("ERROR: `unsafe ", str_concat(v761_kw, "` (e.g. `unsafe ", str_concat(v761_kw, " T { ... }`) is not yet supported in Nucleor. Pre-v0.7.61 the `unsafe` keyword was silently stripped at parse — the decl parsed normally without the marker. Visible-as-noop for adopters auditing translated Rust code. Sister to v0.6.53 `unsafe fn` halt.")))));
            print("       Workaround: drop the `unsafe` qualifier — Nucleor v0.7 has no `unsafe`-gated operations to opt out of, so the qualifier is informational-only at the decl level (the v1 trait/impl-soundness substrate may give it meaning later). Tracked for forward-roadmap.");
            panic(str_concat("nucleor: `unsafe ", str_concat(v761_kw, "` decl not yet supported (see ERROR diagnostic above)")));
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "extern") == 1 && pk(tokens, cp + 1) == 1 && str_eq(pkv(tokens, cp + 1), "crate") == 1 {
            // v0.7.73 (defensive halt — `extern crate <name>;`).
            // Pre-fix this was silently dropped at module-item
            // dispatch — the `extern` ident matched no branch, the
            // dispatcher fell through, and the trailing tokens
            // (`crate`, `<name>`, `;`) were skipped. Adopters
            // translating Rust 2015-style or workspace-style code
            // got NO signal that the dependency wasn't actually
            // pulled in; later `crate_name::path` use sites failed
            // opaquely. Halt cleanly. Sister to v0.7.71 `async fn`
            // and v0.6.53 `unsafe fn` halts (same module-item
            // silent-strip class).
            print("ERROR: `extern crate <name>;` declarations are not yet supported in Nucleor. Pre-v0.7.73 these were silently dropped at module-item dispatch with no signal — adopter intent that the named crate be pulled in was lost, and later `<name>::path` use sites failed opaquely as undefined idents. Workaround: Nucleor's current substrate uses the `import \"path\"` form for cross-file inclusion (RFC-0018 phase 1); there is no Cargo-style external-crate dependency manager yet. Tracked for forward-roadmap (RFC-0018 phase 3 — package/registry resolution).");
            panic("nucleor: `extern crate ...` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "macro_rules") == 1 && pk(tokens, cp + 1) == 38 {
            // v0.7.73 (defensive halt — `macro_rules! name { ... }`).
            // v0.8.28: corrected token check from 97 (`?`) to 38 (`!`).
            // Pre-v0.8.28 the check used token kind 97 (which is `?`,
            // not `!`), so the halt NEVER fired — the `macro_rules! name
            // { ... }` block was silently swallowed at module scope as
            // before v0.7.73. v0.8.28 fixes the token constant so the
            // halt properly fires on `macro_rules` + `!` (token 38).
            print("ERROR: `macro_rules!` declarative-macro definitions are not yet supported in Nucleor. Pre-v0.7.73 the entire `macro_rules! name { ... }` block was silently dropped at module-item dispatch — adopter intent that the macro be defined was lost, and call sites either failed late at expand-time as undefined idents or silently produced no expansion. Pre-v0.8.28 the v0.7.73 halt also silently dropped (wrong token constant 97 vs 38). Workaround: rewrite the macro body as a regular fn (Nucleor's metaprogramming substrate is fn-call + the small set of built-in macros — `print!`, `println!`, `format!`, `vec!`, `panic!`). Tracked for forward-roadmap (full declarative-macro substrate is a v1.x ship).");
            panic("nucleor: `macro_rules!` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "union") == 1 {
            // v0.6.50 (probe finding 2026-05-02-module-scope-decl-silent-
            // noop-gaps-type-mod-union-use): pre-fix `union U { a: i64,
            // b: f64 }` was silently swallowed at parse time then
            // `U { a: 42 }` at use site emitted "unknown struct U" —
            // confusing late error pointing at the use site, not the
            // unsupported decl. Now halt at the decl with a clean
            // diagnostic naming the v0.6 boundary.
            print("ERROR: `union` items are not yet supported in Nucleor. Pre-v0.6.50 the declaration was silently dropped at parse time and use sites failed opaquely with `unknown struct <NAME>`. Workaround: model the union shape with an `enum` (Rust-canonical for tagged unions) or a `struct` whose fields cover the largest variant if you need the raw bit-pattern reuse. Tracked for forward-roadmap.");
            panic("nucleor: `union` decl at module scope not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "static") == 1 {
            // v0.6.21 (probe finding 2026-05-01-static-decl-accepted-but-not-lowered):
            // `static NAME: T = VALUE;` at module scope was silently
            // dropped — the module-item parser skipped the unknown
            // `static` token then advanced past `NAME: T = VALUE;`
            // token-by-token. Use sites of `NAME` lowered as `@NAME`
            // global references and clang link failed with the opaque
            // `error: use of undefined value '@NAME'`. Surface a clean
            // error at parse time pointing at the `const` workaround
            // (literal init) or fn-wrap (computed init).
            print("ERROR: `static` items are not yet supported in Nucleor. Pre-v0.6.21 the declaration silently dropped at parse time and any use site failed late at clang link with `error: use of undefined value '@<NAME>'`. Workarounds: for a literal value use `const NAME: T = VALUE;` (module-scope constant, evaluated at compile time); for a computed value wrap in a fn that returns it (`fn name() -> T { return VALUE; }`).");
            panic("nucleor: `static` decl at module scope not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 11 {
            // v0.3.73: `let` is a statement-level binding — it cannot
            // appear at module scope. Pre-v0.3.73, the parser silently
            // skipped the entire `let NAME: T = EXPR;` token-by-token
            // and downstream codegen emitted `@NAME` references that
            // failed at clang link with "use of undefined value '@NAME'"
            // when main referenced the binding. Surface a clear
            // diagnostic with the canonical workaround (`const`) and
            // skip the let-stmt cleanly so the rest of the program
            // still parses for any other diagnostics the user needs.
            // v0.4.79: was print + skip to `;` — silent miscompute,
            // the `let` binding was dropped from the module surface
            // and any downstream reference produced broken IR.
            print("ERROR: `let` is not allowed at module scope. Use `const NAME: T = VALUE;` for module-scope constants. (`let` is statement-only — the parser previously dropped this declaration silently and emitted broken IR.)");
            panic("nucleor: `let` at module scope not allowed (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 13 || pk(tokens, cp) == 15 || pk(tokens, cp) == 16 || pk(tokens, cp) == 18 || pk(tokens, cp) == 19 || pk(tokens, cp) == 56 || pk(tokens, cp) == 63 {
            // v0.3.75: catch other statement-level keywords at module
            // scope. `if` (13), `while` (15), `return` (16), `break` (18),
            // `continue` (19), `for` (56), `match` (63) all belong inside
            // fn bodies — at module scope they have no
            // (v0.3.141: `loop` removed from this list since it became
            // a contextual identifier-keyword; the contextual form is
            // already caught at parse_stmts level. Top-level `loop {`
            // would now silently skip — accepted limitation since the
            // top-level form has zero usage in the codebase.)
            // meaning and the pre-v0.3.75 silent fall-through dropped
            // them token-by-token. Surface a clear diagnostic so the
            // user sees their malformed top-level construct named
            // explicitly. Recovery: skip to the next semicolon (43)
            // OR the next opening brace (40) — whichever comes first
            // — so block-form constructs (`if/while/loop { ... }`)
            // get cleaned up in one go rather than dribbling broken
            // body tokens through the rest of the program.
            // v0.4.79: was print + skip-block recover — silent
            // miscompute, the stmt at module scope was dropped and
            // any reference to its bindings produced broken IR.
            print("ERROR: statement-level keyword at module scope. Only `fn`, `extern fn`, `pure fn`, `const`, `type`, `struct`, `enum`, `trait`, `impl`, and `pub` (with the above) are allowed as top-level items. Move statement-level constructs into a fn body.");
            panic("nucleor: statement-level keyword at module scope (see ERROR diagnostic above)");
        }
        else { cp = cp + 1; pending_pub = 0; };
    };
    return pr(cp, mk_list(pool, items));
}

#[manual_drop]
fn opt_fold_block(blk: Vec<i32>) -> i64 {
    let mut cm: Vec<i32> = cmap_new();
    let ic: i64 = ir_block_inst_count(blk);
    let insts: Vec<i32> = vec_get(blk, 1);
    let mut folded: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        // Track const_int values
        if op == 0 {
            cmap_set(cm, d, ir_op1(inst));
        }
        // Fold arithmetic: add(2), sub(3), mul(4), div(5), mod(6).
        // v0.3.145: div/mod by zero must NOT fold. Pre-v0.3.145, the
        // `else { i = i + 1; }` branch on `vb == 0` pre-incremented `i`
        // (so the outer `i = i + 1` at the bottom of the loop skipped
        // the next instruction entirely) AND fell through to the
        // vec_set lines that replaced the divide with `const_int 0`.
        // Two compounding bugs: (a) silent miscompute — `100 / 0` became
        // const 0 instead of trapping at runtime, (b) the very next
        // IR instruction silently disappeared from the block. Adopters
        // who wrote any literal `x / 0` (typically as a deliberate
        // panic test or a bug introduced during refactoring) saw the
        // program return 0 and silently skip whatever statement
        // followed.
        //
        // Fix: when divisor is zero, skip the fold entirely (leave the
        // div/mod instruction in place — at runtime LLVM `sdiv i64 X, 0`
        // is undefined behavior, typically SIGFPE, which is a loud
        // failure the adopter actually sees). Do NOT touch `i`.
        else if op >= 2 && op <= 6 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut do_fold: i64 = 1;
                let mut result: i64 = 0;
                // v0.3.208: use wrapping_* in the fold so the
                // compiler's own constant-folding pass doesn't
                // panic when both operands are known and the
                // result overflows. Strict-mode runtime emit will
                // still panic at runtime; the fold matches that
                // bit-pattern (so folded == unfolded for any
                // computable constant pair).
                if op == 2 { result = wrapping_add(va, vb); }
                else if op == 3 { result = wrapping_sub(va, vb); }
                else if op == 4 { result = wrapping_mul(va, vb); }
                else if op == 5 {
                    if vb != 0 { result = va / vb; } else { do_fold = 0; };
                }
                else if op == 6 {
                    if vb != 0 { result = va - (va / vb) * vb; } else { do_fold = 0; };
                };
                if do_fold == 1 {
                    vec_set(inst, 0, 0);
                    vec_set(inst, 3, result);
                    vec_set(inst, 4, 0);
                    vec_set(inst, 5, 0);
                    cmap_set(cm, d, result);
                    folded = folded + 1;
                };
            };
        }
        // Fold comparisons: eq(7), ne(8), slt(9), sgt(10), sle(11), sge(12)
        else if op >= 7 && op <= 12 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                if op == 7 { if va == vb { result = 1; }; }
                else if op == 8 { if va != vb { result = 1; }; }
                else if op == 9 { if va < vb { result = 1; }; }
                else if op == 10 { if va > vb { result = 1; }; }
                else if op == 11 { if va <= vb { result = 1; }; }
                else if op == 12 { if va >= vb { result = 1; }; };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        }
        // v0.3.103: Fold bitwise: and(13), or(14), xor(15). Pre-v0.3.103
        // ops 13/14 were folded with LOGICAL semantics (`va != 0 && vb != 0`
        // → 1 or 0), which matched the historical interpretation of
        // these iops as `&&`/`||`. But the runtime LLVM emit for these
        // iops is `and i64`/`or i64` — pure bitwise — so the const-fold
        // was diverging from what the un-folded code would compute. With
        // bitwise `&` `|` `^` now wired through these iops too, fold
        // bitwise so both paths produce identical answers for constant
        // inputs (e.g. 255 & 15 → 15, not 1 from "both truthy").
        //
        // v0.3.103: Fold bitwise: and(13), or(14), xor(15).
        //
        // v0.3.147: skip the bitwise fold when either operand is negative.
        // The while-shift bit-extraction below uses
        // `ra - (ra/2)*2 == 1` to detect a set LSB. For negative odd ra,
        // C-style integer division (Nucleor's semantics) rounds toward
        // zero so `ra/2` underflows: `-1/2 == 0` and `-1 - 0*2 == -1`,
        // not `1`. The `== 1` check fails, the bit is never recorded as
        // set, and the entire fold collapses high-bit operands to ~0.
        // `255 & -1` const-folded to `0` instead of `255`. Adopters
        // using bitmasks against `-1` (all-ones sentinel) silently
        // computed wrong values. The runtime LLVM `and i64` is correct
        // on signed-i64-as-bits — the bug is purely the s1-emulated fold.
        // Safe fallback: don't fold negative operands; let runtime LLVM
        // compute it. (The same fold-skip pattern as v0.3.145 div/mod
        // by zero, using a do_fold flag so the loop counter isn't
        // touched.)
        else if op == 13 || op == 14 || op == 15 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut do_bit_fold: i64 = 1;
                if va < 0 { do_bit_fold = 0; };
                if vb < 0 { do_bit_fold = 0; };
                if do_bit_fold == 1 {
                let mut result: i64 = 0;
                // Use sym_get's hash-style int-pair AND emulation: Nucleor
                // doesn't expose a `&` operator at this self-host level
                // either (chicken-and-egg), so do it via while-shift.
                if op == 13 {
                    let mut acc: i64 = 0;
                    let mut bit: i64 = 1;
                    let mut ra: i64 = va;
                    let mut rb: i64 = vb;
                    let mut k: i64 = 0;
                    while k < 64 {
                        if ra - (ra / 2) * 2 == 1 && rb - (rb / 2) * 2 == 1 { acc = wrapping_add(acc, bit); };
                        ra = ra / 2; rb = rb / 2; bit = wrapping_add(bit, bit);
                        k = k + 1;
                    };
                    result = acc;
                } else if op == 14 {
                    let mut acc: i64 = 0;
                    let mut bit: i64 = 1;
                    let mut ra: i64 = va;
                    let mut rb: i64 = vb;
                    let mut k: i64 = 0;
                    while k < 64 {
                        if ra - (ra / 2) * 2 == 1 || rb - (rb / 2) * 2 == 1 { acc = wrapping_add(acc, bit); };
                        ra = ra / 2; rb = rb / 2; bit = wrapping_add(bit, bit);
                        k = k + 1;
                    };
                    result = acc;
                } else {
                    let mut acc: i64 = 0;
                    let mut bit: i64 = 1;
                    let mut ra: i64 = va;
                    let mut rb: i64 = vb;
                    let mut k: i64 = 0;
                    while k < 64 {
                        let bita: i64 = ra - (ra / 2) * 2;
                        let bitb: i64 = rb - (rb / 2) * 2;
                        if bita != bitb { acc = wrapping_add(acc, bit); };
                        ra = ra / 2; rb = rb / 2; bit = wrapping_add(bit, bit);
                        k = k + 1;
                    };
                    result = acc;
                };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
                };
            };
        };
        i = i + 1;
    };
    return folded;
}

#[manual_drop]
fn closure_collect_capture_expr(pool: Vec<i32>, nid: i64, sym: Vec<i32>, params: i64, caps: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if sym_get(sym, name) >= 0 && capture_param_has(pool, params, name) == 0 && capture_has_name(caps, name) == 0 {
            caps.push(name);
        };
        return 0;
    };
    if kind == 4 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 3), sym, params, caps);
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 7 || kind == 12 {
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            closure_collect_capture_expr(pool, list_get(pool, args, ai), sym, params, caps);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 8 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            closure_collect_capture_expr(pool, list_get(pool, args, ai), sym, params, caps);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 9 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 10 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    if kind == 23 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        let tb: i64 = node_field(pool, nid, 2);
        let tc: i64 = list_len(pool, tb);
        let mut ti: i64 = 0;
        while ti < tc {
            closure_collect_capture_stmt(pool, list_get(pool, tb, ti), sym, params, caps);
            ti = ti + 1;
        };
        let eb: i64 = node_field(pool, nid, 3);
        if eb >= 0 {
            let ec: i64 = list_len(pool, eb);
            let mut ei: i64 = 0;
            while ei < ec {
                closure_collect_capture_stmt(pool, list_get(pool, eb, ei), sym, params, caps);
                ei = ei + 1;
            };
        };
        return 0;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            closure_collect_capture_expr(pool, list_get(pool, items, ii), sym, params, caps);
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 34 {
        let init_list: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, init_list);
        let mut ii: i64 = 0;
        while ii < ic {
            closure_collect_capture_expr(pool, node_field(pool, list_get(pool, init_list, ii), 2), sym, params, caps);
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        let bc: i64 = list_len(pool, body);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body, bi), sym, params, caps);
            bi = bi + 1;
        };
        return 0;
    };
    // v0.3.113: nested closure literal (kind 42). Pre-v0.3.113, the
    // outer closure's capture-collect ignored inner closure literals
    // entirely (no kind-42 case). Outer never captured names that
    // ONLY the inner closure referenced — so when inner's lowering
    // queried outer's clo_sym for those names, they weren't there,
    // inner emitted `@<name>` global refs, and clang link failed
    // (`use of undefined value '@n'`). Walk the inner's body and
    // bubble up any var-refs that resolve in OUTER's sym AND are
    // NOT inner's params (those are inner-local and shouldn't
    // propagate to outer's capture set).
    if kind == 42 {
        let inner_params: i64 = node_field(pool, nid, 1);
        let inner_body: i64 = node_field(pool, nid, 2);
        let ibc: i64 = list_len(pool, inner_body);
        let mut ibi: i64 = 0;
        while ibi < ibc {
            // Use inner's params as the "shadow" param list so a name
            // that's an inner-param is treated as bound (skipped).
            // Otherwise the existing capture-collect rules apply.
            closure_collect_capture_stmt(pool, list_get(pool, inner_body, ibi), sym, inner_params, caps);
            ibi = ibi + 1;
        };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn dl_parse_fn_signature(src: str, fn_pos: i64, slen: i64) -> Vec<i32> {
    // Given `fn ` at fn_pos, extract:
    //   [0] = fn name (str)
    //   [1] = full param decl text "a: T1, b: T2" (str)
    //   [2] = return type "i64" or "" if void
    //   [3] = comma-separated arg names "a, b" (str)
    //   [4] = position of the `{` opening the body (i64)
    //   [5] = position one past the matching `}` (i64)
    // On parse failure, returns Vec with vec_len == 0.
    let mut out: Vec<i32> = Vec::new();
    let mut p: i64 = fn_pos + 3;  // skip past "fn "
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    let name_start: i64 = p;
    let mut name_done: i64 = 0;
    while p < slen && name_done == 0 {
        let c: i64 = str_char_at(src, p);
        if is_alnum(c) == 1 || c == 95 { p = p + 1; }
        else { name_done = 1; };
    };
    if p == name_start { return out; };
    let fn_name: str = str_substring(src, name_start, p);
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    if p >= slen || str_char_at(src, p) != 40 { return out; };
    let params_start: i64 = p + 1;
    let mut depth: i64 = 1;
    p = params_start;
    while p < slen && depth > 0 {
        let c: i64 = str_char_at(src, p);
        if c == 40 { depth = depth + 1; }
        else if c == 41 { depth = depth - 1; };
        if depth > 0 { p = p + 1; };
    };
    if p >= slen { return out; };
    let params_text: str = str_substring(src, params_start, p);
    p = p + 1;
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    let mut ret_type: str = "";
    if p + 1 < slen && str_char_at(src, p) == 45 && str_char_at(src, p + 1) == 62 {
        p = p + 2;
        while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
        let rt_start: i64 = p;
        while p < slen && str_char_at(src, p) != 32 && str_char_at(src, p) != 9 && str_char_at(src, p) != 123 { p = p + 1; };
        ret_type = str_substring(src, rt_start, p);
    };
    while p < slen && str_char_at(src, p) != 123 { p = p + 1; };
    if p >= slen { return out; };
    let body_open: i64 = p;
    let mut q: i64 = p + 1;
    let mut body_depth: i64 = 1;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while q < slen && body_depth > 0 {
        let c2: i64 = str_char_at(src, q);
        if in_dq == 1 {
            if c2 == 92 && q + 1 < slen { q = q + 1; }
            else if c2 == 34 { in_dq = 0; };
        } else if in_sq == 1 {
            if c2 == 92 && q + 1 < slen { q = q + 1; }
            else if c2 == 39 { in_sq = 0; };
        } else if c2 == 47 && q + 1 < slen && str_char_at(src, q + 1) == 47 {
            while q < slen && str_char_at(src, q) != 10 { q = q + 1; };
        } else if c2 == 34 { in_dq = 1; }
        else if c2 == 39 { in_sq = 1; }
        else if c2 == 123 { body_depth = body_depth + 1; }
        else if c2 == 125 { body_depth = body_depth - 1; };
        q = q + 1;
    };
    if body_depth != 0 { return out; };
    // Extract arg names from params_text
    let mut arg_names: str = "";
    let plen: i64 = str_len(params_text);
    let mut sp: i64 = 0;
    let mut first_arg: i64 = 1;
    while sp < plen {
        while sp < plen && (str_char_at(params_text, sp) == 32 || str_char_at(params_text, sp) == 9 || str_char_at(params_text, sp) == 44 || str_char_at(params_text, sp) == 10) { sp = sp + 1; };
        if sp >= plen { sp = plen + 1; }
        else {
            while sp + 1 < plen && str_char_at(params_text, sp) == 35 && str_char_at(params_text, sp + 1) == 91 {
                sp = sp + 2;
                let mut attr_depth: i64 = 1;
                while sp < plen && attr_depth > 0 {
                    let ac: i64 = str_char_at(params_text, sp);
                    if ac == 91 { attr_depth = attr_depth + 1; }
                    else if ac == 93 { attr_depth = attr_depth - 1; };
                    sp = sp + 1;
                };
                while sp < plen && (str_char_at(params_text, sp) == 32 || str_char_at(params_text, sp) == 9 || str_char_at(params_text, sp) == 10) { sp = sp + 1; };
            };
            let an_start: i64 = sp;
            while sp < plen && (is_alnum(str_char_at(params_text, sp)) == 1 || str_char_at(params_text, sp) == 95) { sp = sp + 1; };
            if sp == an_start { sp = sp + 1; }
            else {
                let arg_name: str = str_substring(params_text, an_start, sp);
                if first_arg == 0 { arg_names = str_concat(arg_names, ", "); };
                arg_names = str_concat(arg_names, arg_name);
                first_arg = 0;
                // Skip until next comma at depth 0
                let mut adepth: i64 = 0;
                let mut at_comma: i64 = 0;
                while sp < plen && at_comma == 0 {
                    let cc: i64 = str_char_at(params_text, sp);
                    if cc == 40 || cc == 60 || cc == 91 { adepth = adepth + 1; sp = sp + 1; }
                    else if cc == 41 || cc == 62 || cc == 93 { adepth = adepth - 1; sp = sp + 1; }
                    else if cc == 44 && adepth == 0 { at_comma = 1; }
                    else { sp = sp + 1; };
                };
            };
        };
    };
    out.push(fn_name);
    out.push(params_text);
    out.push(ret_type);
    out.push(arg_names);
    out.push(body_open);
    out.push(q);
    return out;
}

#[manual_drop]
fn expand_deadline(src: str) -> str {
    // Walk source line-by-line. When we see `#[deadline = N]` (after
    // optional doc comments), find the next `fn ...` declaration and
    // wrap it. Each rewrite replaces the original fn with two fns:
    //   __nuc_dl_inner_<idx>  — the original body
    //   <name>                — the wrapper that does start-cap +
    //                           inner-call + deadline_check + return
    let slen: i64 = str_len(src);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    let mut idx: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        // Skip `//` line comments — `#[deadline = N]` text inside a
        // comment must not trigger wrapping (and previously caused an
        // infinite probe loop in the give-up branch below).
        let trimmed_line: str = strip_spaces(line);
        let tllen: i64 = str_len(trimmed_line);
        if tllen >= 2 && str_char_at(trimmed_line, 0) == 47 && str_char_at(trimmed_line, 1) == 47 {
            sb_append(sb, str_substring(src, p, eol));
            if eol < slen { sb_append(sb, "\n"); };
            p = eol + 1;
            continue;
        };
        let dl_value: i64 = dl_extract_int_value(line);
        if dl_value >= 0 {
            // Scan forward past blank lines + doc comments + other
            // attribute lines for the actual fn start. Use sentinel
            // -1 = still searching, >= 0 = found, -2 = give up; only
            // -1 keeps the loop going (older `< 0` form spun forever
            // on the give-up branch since -2 is also `< 0`).
            let mut probe: i64 = eol + 1;
            let mut found_fn: i64 = 0 - 1;
            while probe < slen && found_fn == 0 - 1 {
                let mut peol: i64 = probe;
                while peol < slen && str_char_at(src, peol) != 10 { peol = peol + 1; };
                let pline: str = str_substring(src, probe, peol);
                let trimmed: str = strip_spaces(pline);
                let tlen: i64 = str_len(trimmed);
                if tlen == 0 {
                    probe = peol + 1;
                } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                    probe = peol + 1;
                } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                    // Other #[...] attribute — skip
                    probe = peol + 1;
                } else if tlen >= 2 && str_eq(str_substring(trimmed, 0, 2), "fn") == 1 {
                    let mut fnpos: i64 = probe;
                    while fnpos < peol && (str_char_at(src, fnpos) == 32 || str_char_at(src, fnpos) == 9) { fnpos = fnpos + 1; };
                    found_fn = fnpos;
                } else if tlen >= 5 && str_eq(str_substring(trimmed, 0, 5), "pub f") == 1 {
                    let mut fnpos: i64 = probe;
                    while fnpos < peol && (str_char_at(src, fnpos) == 32 || str_char_at(src, fnpos) == 9) { fnpos = fnpos + 1; };
                    if fnpos + 4 <= peol && str_eq(str_substring(src, fnpos, fnpos + 4), "pub ") == 1 {
                        fnpos = fnpos + 4;
                    };
                    found_fn = fnpos;
                } else {
                    // Anything else — give up; emit original line.
                    found_fn = 0 - 2;
                };
            };
            if found_fn >= 0 {
                let info: Vec<i32> = dl_parse_fn_signature(src, found_fn, slen);
                if vec_len(info) > 0 {
                    let fn_name: str = vec_get(info, 0);
                    let params_text: str = vec_get(info, 1);
                    let ret_type: str = vec_get(info, 2);
                    let arg_names: str = vec_get(info, 3);
                    let body_open: i64 = vec_get(info, 4);
                    let body_end: i64 = vec_get(info, 5);
                    let inner_name: str = str_concat("__nuc_dl_inner_", str_concat(content_hash(fn_name), str_concat("_", str_from_int(idx))));
                    idx = idx + 1;
                    // Drop the #[deadline = N] line itself (do nothing for it).
                    // Emit everything between the line after the attribute
                    // and the start of the fn (which is empty/doc/other attrs)
                    // verbatim — preserves doc comments and other attributes.
                    sb_append(sb, str_substring(src, eol + 1, found_fn));
                    // Emit inner fn (original body, renamed).
                    sb_append(sb, "fn ");
                    sb_append(sb, inner_name);
                    sb_append(sb, "(");
                    sb_append(sb, params_text);
                    sb_append(sb, ") ");
                    if str_len(ret_type) > 0 {
                        sb_append(sb, "-> ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " ");
                    };
                    sb_append(sb, str_substring(src, body_open, body_end));
                    sb_append(sb, "\n\n");
                    // Emit outer wrapper fn with original name.
                    sb_append(sb, "fn ");
                    sb_append(sb, fn_name);
                    sb_append(sb, "(");
                    sb_append(sb, params_text);
                    sb_append(sb, ") ");
                    if str_len(ret_type) > 0 {
                        sb_append(sb, "-> ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " ");
                    };
                    sb_append(sb, "{\n");
                    sb_append(sb, "    let __nuc_dl_start: i64 = time_monotonic_us();\n");
                    if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 {
                        sb_append(sb, "    let __nuc_dl_r: ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " = ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_check(__nuc_dl_start, ");
                        sb_append(sb, str_from_int(dl_value));
                        sb_append(sb, ");\n");
                        sb_append(sb, "    return __nuc_dl_r;\n");
                    } else {
                        sb_append(sb, "    ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_check(__nuc_dl_start, ");
                        sb_append(sb, str_from_int(dl_value));
                        sb_append(sb, ");\n");
                    };
                    sb_append(sb, "}\n");
                    p = body_end;
                    continue;
                };
            };
        };
        // Default: emit the line as-is.
        sb_append(sb, str_substring(src, p, eol));
        if eol < slen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn expand_async_strip_keyword(src: str) -> str {
    // Identifier-aware walk. When we find an `async` identifier
    // followed by whitespace and `fn`, we drop the `async` keyword
    // (and the whitespace between it and `fn`). Anywhere else,
    // `async` passes through as a regular identifier.
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            let comment_start: i64 = p;
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
            sb_append_range(sb, src, comment_start, p);
        } else if c == 34 {
            let str_start: i64 = p;
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    p = p + 2;
                } else {
                    p = p + 1;
                };
            };
            if p < slen { p = p + 1; };
            sb_append_range(sb, src, str_start, p);
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let id_len: i64 = p - id_start;
            if id_len == 5 && str_eq_at(src, id_start, "async") == 1 {
                // v0.7.9 (defensive halt): canonical Rust `async { ... }`
                // block expression pre-fix surfaced as wrong-class
                // `error[TYP-005]: undefined function async()` because
                // expand_async_strip_keyword only handles `async fn`,
                // and parse_primary then treats `async` as a fn call.
                // Halt cleanly with a workaround pointer (drop the
                // `async` — Nucleor's runtime is single-threaded, the
                // block runs synchronously).
                let mut blk_peek: i64 = p;
                while blk_peek < slen && (str_char_at(src, blk_peek) == 32 || str_char_at(src, blk_peek) == 9 || str_char_at(src, blk_peek) == 10 || str_char_at(src, blk_peek) == 13) { blk_peek = blk_peek + 1; };
                if blk_peek < slen && str_char_at(src, blk_peek) == 123 {
                    print("ERROR: `async { ... }` block expression is not yet supported in Nucleor. Pre-v0.7.9 surfaced as wrong-class `error[TYP-005]: undefined function async()` because expand_async_strip_keyword only handles `async fn` (not `async {`), and parse_primary then treats `async` as a fn call. Workaround: drop the `async` keyword — Nucleor's runtime is single-threaded by default, so the block already runs synchronously. For threaded execution use `async_spawn(fn_ptr, arg)` (RFC-0027 phase 1, see stdlib/rods/async.nr) which returns a handle. Tracked for forward-roadmap (full Future-trait async-block lowering is sister to V1.x async/Future infrastructure).");
                    panic("nucleor: `async { ... }` block expression not yet supported (see ERROR diagnostic above)");
                };
                // Look ahead past whitespace for `fn`.
                let mut peek: i64 = p;
                while peek < slen && (str_char_at(src, peek) == 32 || str_char_at(src, peek) == 9) { peek = peek + 1; };
                if peek + 2 <= slen && str_eq_at(src, peek, "fn") == 1 {
                    let after_fn: i64 = peek + 2;
                    let next_after_fn: i64 = if after_fn < slen { str_char_at(src, after_fn) } else { 0 };
                    if next_after_fn == 32 || next_after_fn == 9 || next_after_fn == 10 {
                        // T3.8 (v0.3.7): RT-006 — async + RT attribute is
                        // rejected. Look back from `async` for a `#[no_alloc]`,
                        // `#[no_panic]`, `#[no_dyn]`, or `#[deadline...]`
                        // attribute on a preceding line (skipping blanks +
                        // doc comments). If found, emit a marker comment
                        // the diag pass picks up after expansion strips
                        // the `async` keyword for good.
                        let mut lb: i64 = id_start - 1;
                        let mut prev_attr_found: i64 = 0;
                        let mut stop: i64 = 0;
                        while lb >= 0 && stop == 0 && prev_attr_found == 0 {
                            let mut line_start: i64 = lb;
                            while line_start > 0 && str_char_at(src, line_start - 1) != 10 {
                                line_start = line_start - 1;
                            };
                            let line_end: i64 = lb + 1;
                            let line: str = str_substring(src, line_start, line_end);
                            let trimmed: str = strip_spaces(line);
                            let tlen: i64 = str_len(trimmed);
                            if tlen == 0 {
                                lb = line_start - 2;
                            } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                                lb = line_start - 2;
                            } else if str_eq(trimmed, "#[no_alloc]") == 1
                                  || str_eq(trimmed, "#[no_panic]") == 1
                                  || str_eq(trimmed, "#[no_dyn]") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 11 && str_eq(str_substring(trimmed, 0, 11), "#[deadline ") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 11 && str_eq(str_substring(trimmed, 0, 11), "#[deadline=") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                                // Different #[...] attribute — keep looking.
                                lb = line_start - 2;
                            } else {
                                stop = 1;
                            };
                        };
                        // Read the fn name for the marker / diag.
                        let mut np: i64 = after_fn;
                        while np < slen && (str_char_at(src, np) == 32 || str_char_at(src, np) == 9) { np = np + 1; };
                        let nn_start: i64 = np;
                        while np < slen && (is_alnum(str_char_at(src, np)) == 1 || str_char_at(src, np) == 95) { np = np + 1; };
                        let async_fn_name: str = if np > nn_start { str_substring(src, nn_start, np) } else { "<unknown>" };
                        if prev_attr_found == 1 {
                            // RT-006 path: RT attribute + async → hard error.
                            // Prefix with `\n` so the marker always starts
                            // at column 0 — the diag scanner matches on the
                            // exact byte sequence "\n//__NUC6T:" which never
                            // appears mid-line in the s1 compiler source
                            // (the literal mentions in this file are either
                            // inside string literals or mid-line in prose).
                            sb_append(sb, "\n//__NUC6T:");
                            sb_append(sb, async_fn_name);
                            sb_append(sb, "\n");
                        } else {
                            // v0.5.19 closes probe finding
                            // 2026-05-01-async-keyword-silently-stripped.
                            // Plain `async fn foo()` (no RT attribute) was
                            // silently stripped pre-fix — adopter wrote the
                            // canonical Rust async pattern, the keyword
                            // dropped, the fn ran sync, no signal. Now we
                            // emit an ASYNC-001 warning marker that the
                            // scanner picks up post-strip. Marker shape
                            // mirrors RT-006's `//__NUC6T:` for symmetry.
                            // Note: the runtime DOES support threading via
                            // async_spawn / async_await (RFC-0027 phase 1) —
                            // the warning points adopters at that, rather
                            // than halting cleanly.
                            sb_append(sb, "\n//__NUC6X:");
                            sb_append(sb, async_fn_name);
                            sb_append(sb, "\n");
                        };
                        // Drop `async ` — emit nothing for the keyword
                        // and fast-forward past the trailing whitespace.
                        p = peek;
                        continue;
                    };
                };
                // Not `async fn` — keep `async` as a regular identifier.
                sb_append(sb, "async");
            } else {
                sb_append_range(sb, src, id_start, p);
            };
        } else {
            sb_append_char_at(sb, src, p);
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn fmt_build_expansion(args_text: str, mode: i64, src: str) -> str {
    // mode: 0 = println!  → print(...)
    //       1 = format!   → bare str expression
    //       2 = print!    → print_raw(...)
    //       3 = eprintln! → eprint(...)        v0.5.22
    //       4 = eprint!   → eprint_raw(...)    v0.5.22
    let parts: Vec<i32> = fmt_split_args(args_text);
    // v0.7.43 (defensive halt — Rust named format-arg `format!("{x}",
    // x = 5)`). Pre-fix this surfaced as wrong-class `error[TYP-005]:
    // undefined function 'x()'` because the expander used the literal
    // expression `x = 5` as the value to format, parsed it as an
    // assignment, and `x` was undefined. Detect any arg part matching
    // `<ident>\s*=\s*<expr>` and halt cleanly. (Does NOT fire on `==`
    // / `!=` / `<=` / `>=` because those have a non-`=` second char.)
    let mut v743_idx: i64 = 1;
    while v743_idx < vec_len(parts) {
        let v743_arg: str = vec_get(parts, v743_idx);
        let v743_alen: i64 = str_len(v743_arg);
        let mut v743_ident_start: i64 = 0;
        while v743_ident_start < v743_alen && (str_char_at(v743_arg, v743_ident_start) == 32 || str_char_at(v743_arg, v743_ident_start) == 9) {
            v743_ident_start = v743_ident_start + 1;
        };
        let mut v743_ident_end: i64 = v743_ident_start;
        let mut v743_has_ident: i64 = 0;
        if v743_ident_end < v743_alen {
            let v743_c0: i64 = str_char_at(v743_arg, v743_ident_end);
            if (v743_c0 >= 65 && v743_c0 <= 90) || (v743_c0 >= 97 && v743_c0 <= 122) || v743_c0 == 95 {
                v743_has_ident = 1;
                v743_ident_end = v743_ident_end + 1;
                let mut v743_walk: i64 = 1;
                while v743_walk == 1 && v743_ident_end < v743_alen {
                    let v743_cn: i64 = str_char_at(v743_arg, v743_ident_end);
                    if (v743_cn >= 65 && v743_cn <= 90) || (v743_cn >= 97 && v743_cn <= 122) || (v743_cn >= 48 && v743_cn <= 57) || v743_cn == 95 {
                        v743_ident_end = v743_ident_end + 1;
                    } else {
                        v743_walk = 0;
                    };
                };
            };
        };
        if v743_has_ident == 1 {
            let mut v743_eq_p: i64 = v743_ident_end;
            while v743_eq_p < v743_alen && (str_char_at(v743_arg, v743_eq_p) == 32 || str_char_at(v743_arg, v743_eq_p) == 9) {
                v743_eq_p = v743_eq_p + 1;
            };
            if v743_eq_p < v743_alen && str_char_at(v743_arg, v743_eq_p) == 61 && (v743_eq_p + 1 >= v743_alen || str_char_at(v743_arg, v743_eq_p + 1) != 61) {
                let v743_name: str = str_substring(v743_arg, v743_ident_start, v743_ident_end);
                print(str_concat("ERROR: Rust named format-arg `", str_concat(v743_name, " = <expr>` (e.g. `format!(\"{x}\", x = 5)`) is not yet supported in Nucleor's textual macro layer. Pre-v0.7.43 surfaced as wrong-class `error[TYP-005]: undefined function '<name>()'` because the expander used `x = 5` as the value to format and parsed `x` as an unbound identifier.")));
                print(str_concat("       Workaround: use the explicit-positional form — `format!(\"{}\", ", str_concat(v743_name, ")` (drop the named binding; the value already has a name in the calling scope). Tracked for forward-roadmap (named-arg substrate is part of the same RFC 2795 work as inline + positional args).")));
                panic(str_concat("nucleor: named format-arg `", str_concat(v743_name, " = ...` not yet supported (see ERROR diagnostic above)")));
            };
        };
        v743_idx = v743_idx + 1;
    };
    if vec_len(parts) == 0 {
        if mode == 0 { return "print(\"\")"; };
        if mode == 1 { return "\"\""; };
        if mode == 3 { return "eprint(\"\")"; };
        if mode == 4 { return "eprint_raw(\"\")"; };
        return "print_raw(\"\")";
    };
    let fmt_lit: str = vec_get(parts, 0);
    let body: str = fmt_strip_outer_quotes(fmt_lit);
    let blen: i64 = str_len(body);
    let n_args: i64 = vec_len(parts) - 1;
    let mut segments: Vec<i32> = Vec::new();
    let mut parities: Vec<i32> = Vec::new();
    let mut current: i64 = sb_new();
    let mut i: i64 = 0;
    let mut arg_idx: i64 = 0;
    while i < blen {
        let c: i64 = str_char_at(body, i);
        if c == 123 && i + 1 < blen && str_char_at(body, i + 1) == 123 {
            sb_append(current, "{");
            i = i + 2;
        } else if c == 125 && i + 1 < blen && str_char_at(body, i + 1) == 125 {
            sb_append(current, "}");
            i = i + 2;
        } else if c == 123 {
            let mut spec_end: i64 = i + 1;
            while spec_end < blen && str_char_at(body, spec_end) != 125 { spec_end = spec_end + 1; };
            if spec_end >= blen {
                sb_append_char_at(current, body, i);
                i = i + 1;
            } else {
                let spec: str = str_substring(body, i + 1, spec_end);
                segments.push(sb_to_str(current));
                parities.push(0);
                current = sb_new();
                if arg_idx < n_args {
                    let arg_expr: str = vec_get(parts, arg_idx + 1);
                    segments.push(fmt_conversion_for_spec(spec, arg_expr, src));
                    parities.push(1);
                    arg_idx = arg_idx + 1;
                } else {
                    // v0.7.41 (defensive halt — Rust 1.58+ inline format-arg
                    // placeholders `{name}` where `name` is an identifier
                    // bound in the caller's scope). Pre-fix this surfaced
                    // as the v0.4.70 generic "more `{}` than args" error
                    // even though the args ARE inline in the format string.
                    // Detect the spec being a bare identifier (no format-
                    // spec colons / dots / commas) and halt with a clear
                    // explicit-arg workaround.
                    // v0.7.42: require the first char to be alpha or `_` so
                    // `{0}` / `{1}` (positional-arg refs, a separate Rust
                    // feature) don't collide with the v0.7.41 inline-arg
                    // halt. Digits-only specs are positional references and
                    // get a different diagnostic just below.
                    let mut v741_inline_ident: i64 = 0;
                    if str_len(spec) > 0 {
                        let v741_c0: i64 = str_char_at(spec, 0);
                        if (v741_c0 >= 65 && v741_c0 <= 90) || (v741_c0 >= 97 && v741_c0 <= 122) || v741_c0 == 95 {
                            v741_inline_ident = 1;
                            let mut v741_si: i64 = 1;
                            while v741_si < str_len(spec) && v741_inline_ident == 1 {
                                let v741_c: i64 = str_char_at(spec, v741_si);
                                let v741_is_id_char: i64 = if (v741_c >= 65 && v741_c <= 90) || (v741_c >= 97 && v741_c <= 122) || (v741_c >= 48 && v741_c <= 57) || v741_c == 95 { 1 } else { 0 };
                                if v741_is_id_char == 0 { v741_inline_ident = 0; };
                                v741_si = v741_si + 1;
                            };
                        };
                    };
                    if v741_inline_ident == 1 {
                        print(str_concat("ERROR: Rust 1.58+ inline format-arg `{", str_concat(spec, "}` (where `<name>` resolves to a binding in the calling scope) is not yet supported in Nucleor's textual macro layer. Pre-v0.7.41 surfaced as wrong-class \"format string has more `{}` placeholders than args supplied\".")));
                        print(str_concat("       Workaround: use the explicit-arg form — `format!(\"{}\", ", str_concat(spec, ")` (or `println!`/`print!`/etc.). For multiple inline args, list each as a separate trailing arg in the same order they appear in the format string. Tracked for forward-roadmap (lex-time inline-arg rewrite at `{name}` → `{}` + appended `name` arg, per Rust RFC 2795).")));
                        panic(str_concat("nucleor: inline format-arg `{", str_concat(spec, "}` not yet supported (see ERROR diagnostic above)")));
                    };
                    // v0.7.42 (defensive halt — Rust positional format-arg
                    // `{0}` / `{1}` / etc.). Detect digits-only spec and
                    // halt with an explicit `{}`-only workaround pointer.
                    let mut v742_pos_arg: i64 = if str_len(spec) > 0 { 1 } else { 0 };
                    let mut v742_pi: i64 = 0;
                    while v742_pi < str_len(spec) && v742_pos_arg == 1 {
                        let v742_c: i64 = str_char_at(spec, v742_pi);
                        if v742_c < 48 || v742_c > 57 { v742_pos_arg = 0; };
                        v742_pi = v742_pi + 1;
                    };
                    if v742_pos_arg == 1 {
                        print(str_concat("ERROR: Rust positional format-arg `{", str_concat(spec, "}` (referencing arg #", str_concat(spec, " by index, allowing reuse like `{0} {1} {0}`) is not yet supported in Nucleor's textual macro layer."))));
                        print("       Workaround: write the args linearly in `{}` order — `format!(\"{} {}\", a, b)` instead of `format!(\"{0} {1}\", a, b)`. For repeated refs, write the value once and bind it: `let r = a; format!(\"{} {} {}\", r, b, r)`. Tracked for forward-roadmap (positional-arg substrate is part of the same RFC 2795 work as inline args).");
                        panic(str_concat("nucleor: positional format-arg `{", str_concat(spec, "}` not yet supported (see ERROR diagnostic above)")));
                    };
                    // v0.4.70: NUC-FEEDBACK silent-MISSING close (audit
                    // section 10). Pre-fix `println!("{} and {}", 42)`
                    // emitted "42 and <MISSING>" at runtime — silent
                    // wrong output. Halt at preprocess with a clear
                    // hint naming the placeholder count vs arg count.
                    print(str_concat("ERROR: format string has more `{}` placeholders than args supplied. Format body: `", str_concat(body, str_concat("`. Args supplied: ", str_concat(str_from_int(n_args), ". Pre-v0.4.70 missing args were rendered as the literal text `<MISSING>` at runtime.")))));
                    panic("nucleor: format placeholder count > arg count");
                };
                i = spec_end + 1;
            };
        } else {
            sb_append_char_at(current, body, i);
            i = i + 1;
        };
    };
    segments.push(sb_to_str(current));
    parities.push(0);
    // v0.5.11: probe-agent finding 2026-05-01-format-extra-args-silently-dropped.
    // Mirror direction of the v0.4.70 placeholder>args check: if the
    // adopter supplied MORE args than `{}` placeholders, the extras
    // would be silently dropped (their evaluation may even have side
    // effects). Halt cleanly with FMT-003 naming the dropped count
    // and the format body.
    if arg_idx < n_args {
        let dropped: i64 = n_args - arg_idx;
        print(str_concat("ERROR: error[FMT-003]: format string has ", str_concat(str_from_int(arg_idx), str_concat(" `{}` placeholder(s) but ", str_concat(str_from_int(n_args), str_concat(" argument(s) supplied; ", str_concat(str_from_int(dropped), str_concat(" extra argument(s) would be silently dropped. Format body: `", str_concat(body, "`. Either add `{}` placeholders for the extras or remove them from the call.")))))))));
        panic("nucleor: FMT-003 format args > placeholders (extras would be silently dropped)");
    };
    let chain: str = fmt_build_concat_chain(segments, parities);
    if mode == 0 { return str_concat("print(", str_concat(chain, ")")); };
    if mode == 1 { return chain; };
    if mode == 3 { return str_concat("eprint(", str_concat(chain, ")")); };
    if mode == 4 { return str_concat("eprint_raw(", str_concat(chain, ")")); };
    // v0.6.39 (probe finding 2026-05-01-panic-assert-macros-drop-format-
    // args): mode 5 = panic! — pre-fix the textual rewrite stripped `!`
    // and the `panic("got {}", x)` call dropped the args at the runtime
    // helper boundary (panic helper takes a single str). Now route
    // through the same fmt-expansion path as println — the format chain
    // becomes the single str arg to panic().
    if mode == 5 { return str_concat("panic(", str_concat(chain, ")")); };
    return str_concat("print_raw(", str_concat(chain, ")"));
}

#[manual_drop]
fn expand_format_macros_with_src(src: str, type_src: str) -> str {
    // Top-level T2.6 entry. Walks the merged source and replaces every
    // `<name>!(...)` macro call (where name is `println`/`print`/`format`)
    // with the desugared expression. Identifier- and quote-aware so a
    // `!` inside a string literal is left alone, and `obj.println!()`
    // (method-call form, currently unsupported anyway) doesn't trip.
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            let mut handled: i64 = 0;
            // v0.3.94: strip `!` from `panic!` and `assert!` macro
            // calls. Pre-v0.3.94, `panic!("msg")` was parsed as
            // `panic` (ident) `!` (negate) `("msg")` and the runtime
            // call to __nucleor_panic was never emitted, failing at
            // clang link with `@panic undefined`. Same for assert!.
            // The textual rewrite drops the `!` so the existing fn
            // call dispatch handles them via the regular runtime
            // helpers (already registered as panic / assert at
            // line 2706 / 2635).
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 40 {
                // v0.6.39: `panic!` no longer falls through here — it's
                // handled below as mode=5 with format-arg expansion.
                // v0.6.56: `unreachable` removed from this strip-and-
                // continue list — the mode-5 path below now expands it
                // to `panic("internal error: entered unreachable code")`.
                // v0.6.76 RFC V1.9 (probe finding 2026-05-01-rust-syntax-
                // translation-fidelity-audit, assert-format-args row):
                // canonical Rust `assert!(cond, "fmt {}", arg)` pre-fix
                // stripped `!` and emitted `assert(cond, "fmt {}", arg)`
                // — a 3-arg call to the 1-arg `__nucleor_assert(i64)`
                // helper. Format args dropped, `{}` stayed literal, and
                // assert(cond_truthy=1) silently passed even with broken
                // format args. v0.6.73 attempt regressed cold +1.7s due
                // to per-call comma walking; this ship limits the walk
                // to assert/assert_eq/assert_ne calls only (cheap name
                // gate), and only when 2+ (assert) / 3+ (assert_eq/ne)
                // top-level commas are present (format-arg shape).
                //
                // Rewrite shape:
                //   assert!(c, "fmt", args)   →  if !(c) { panic("fmt-built"); };
                //   assert_eq!(a, b, "fmt", args) →  if !((a) == (b)) { panic("fmt-built"); };
                //   assert_ne!(a, b, "fmt", args) →  if !((a) != (b)) { panic("fmt-built"); };
                // The `panic("fmt-built")` part is built via mode-5
                // fmt_build_expansion — same path panic! mode-5 uses.
                let mut v076_assert_kind: i64 = 0; // 0=not, 1=assert, 2=assert_eq, 3=assert_ne
                if str_eq(name, "assert") == 1 { v076_assert_kind = 1; };
                if str_eq(name, "assert_eq") == 1 { v076_assert_kind = 2; };
                if str_eq(name, "assert_ne") == 1 { v076_assert_kind = 3; };
                if v076_assert_kind > 0 {
                    let v076_probe_start: i64 = p + 2;
                    let mut v076_probe_q: i64 = v076_probe_start;
                    let mut v076_probe_depth: i64 = 1;
                    let mut v076_probe_dq: i64 = 0;
                    let mut v076_probe_sq: i64 = 0;
                    let mut v076_comma1: i64 = 0 - 1;
                    let mut v076_comma2: i64 = 0 - 1;
                    let mut v076_comma3: i64 = 0 - 1;
                    while v076_probe_q < slen && v076_probe_depth > 0 {
                        let v076_pc: i64 = str_char_at(src, v076_probe_q);
                        if v076_probe_dq == 1 {
                            if v076_pc == 92 && v076_probe_q + 1 < slen { v076_probe_q = v076_probe_q + 1; }
                            else if v076_pc == 34 { v076_probe_dq = 0; };
                        } else if v076_probe_sq == 1 {
                            if v076_pc == 92 && v076_probe_q + 1 < slen { v076_probe_q = v076_probe_q + 1; }
                            else if v076_pc == 39 { v076_probe_sq = 0; };
                        } else if v076_pc == 34 { v076_probe_dq = 1; }
                        else if v076_pc == 39 { v076_probe_sq = 1; }
                        else if v076_pc == 40 || v076_pc == 91 || v076_pc == 123 { v076_probe_depth = v076_probe_depth + 1; }
                        else if v076_pc == 41 || v076_pc == 93 || v076_pc == 125 { v076_probe_depth = v076_probe_depth - 1; }
                        else if v076_pc == 44 && v076_probe_depth == 1 {
                            if v076_comma1 < 0 { v076_comma1 = v076_probe_q; }
                            else if v076_comma2 < 0 { v076_comma2 = v076_probe_q; }
                            else if v076_comma3 < 0 { v076_comma3 = v076_probe_q; };
                        };
                        v076_probe_q = v076_probe_q + 1;
                    };
                    let v076_close_paren: i64 = v076_probe_q - 1;
                    let mut v076_have_fmt: i64 = 0;
                    let mut v076_split_pos: i64 = 0 - 1;
                    if v076_assert_kind == 1 && v076_comma2 >= 0 { v076_split_pos = v076_comma1; };
                    if v076_assert_kind > 1 && v076_comma3 >= 0 { v076_split_pos = v076_comma2; };
                    if v076_split_pos > 0 {
                        let mut v076_sk: i64 = v076_split_pos + 1;
                        let mut v076_first_after: i64 = 0;
                        while v076_sk < v076_close_paren && v076_first_after == 0 {
                            let v076_sc: i64 = str_char_at(src, v076_sk);
                            if v076_sc == 32 || v076_sc == 9 || v076_sc == 10 || v076_sc == 13 { v076_sk = v076_sk + 1; }
                            else { v076_first_after = v076_sc; };
                        };
                        if v076_first_after == 34 { v076_have_fmt = 1; };
                    };
                    if v076_have_fmt == 1 && v076_probe_depth == 0 {
                        let v076_fmt_args: str = str_substring(src, v076_split_pos + 1, v076_close_paren);
                        let v076_inner: str = expand_format_macros_with_src(v076_fmt_args, type_src);
                        let v076_panic_call: str = fmt_build_expansion(v076_inner, 5, type_src);
                        if v076_assert_kind == 1 {
                            let v076_cond: str = str_substring(src, v076_probe_start, v076_comma1);
                            sb_append(sb, "if !(");
                            sb_append(sb, v076_cond);
                            sb_append(sb, ") { ");
                            sb_append(sb, v076_panic_call);
                            sb_append(sb, "; }");
                        } else {
                            let v076_lhs: str = str_substring(src, v076_probe_start, v076_comma1);
                            let v076_rhs: str = str_substring(src, v076_comma1 + 1, v076_comma2);
                            let v076_op: str = if v076_assert_kind == 2 { "==" } else { "!=" };
                            sb_append(sb, "if !((");
                            sb_append(sb, v076_lhs);
                            sb_append(sb, ") ");
                            sb_append(sb, v076_op);
                            sb_append(sb, " (");
                            sb_append(sb, v076_rhs);
                            sb_append(sb, ")) { ");
                            sb_append(sb, v076_panic_call);
                            sb_append(sb, "; }");
                        };
                        p = v076_probe_q;
                        last_non_ws = 125;
                        continue;
                    };
                    // v0.6.88 (probe finding 2026-05-02-assert-eq-ne-pointer-
                    // compare-extends-to-vec-struct-hashmap): canonical Rust
                    // `assert_eq!(a, b)` / `assert_ne!(a, b)` (no format
                    // args) lower to `__nucleor_assert_eq(i64, i64)` which
                    // does pointer comparison. For str / String / derived-
                    // PartialEq struct values, this silently miscomputes —
                    // equal-content values at different heap addresses
                    // fail/pass incorrectly.
                    //
                    // Rewrite the no-fmt case to `if !((a) <op> (b)) {
                    // panic!("assertion failed: ..."); };` so the
                    // existing v0.6.85+v0.6.87 binop kind-4 auto-dispatch
                    // (which routes ==/!= for str/String/derived structs
                    // to the right runtime helper) handles correctness
                    // transparently.
                    if v076_assert_kind > 1 && v076_comma1 >= 0 && v076_comma2 < 0 && v076_probe_depth == 0 {
                        let v088_lhs: str = str_substring(src, v076_probe_start, v076_comma1);
                        let v088_rhs: str = str_substring(src, v076_comma1 + 1, v076_close_paren);
                        let v088_op: str = if v076_assert_kind == 2 { "==" } else { "!=" };
                        let v088_op_word: str = if v076_assert_kind == 2 { "assert_eq" } else { "assert_ne" };
                        sb_append(sb, "if !((");
                        sb_append(sb, v088_lhs);
                        sb_append(sb, ") ");
                        sb_append(sb, v088_op);
                        sb_append(sb, " (");
                        sb_append(sb, v088_rhs);
                        sb_append(sb, ")) { panic(\"");
                        sb_append(sb, v088_op_word);
                        sb_append(sb, "! failed\"); }");
                        p = v076_probe_q;
                        last_non_ws = 125;
                        continue;
                    };
                };
                if str_eq(name, "assert") == 1
                   || str_eq(name, "assert_eq") == 1 || str_eq(name, "assert_ne") == 1
                   || str_eq(name, "dbg") == 1 {
                    sb_append(sb, name);
                    p = p + 1;
                    continue;
                };
                // v0.7.36: `todo` and `unimplemented` removed from the
                // strip-and-continue list — they now fall through to mode 5
                // (panic-like) below, which synthesizes the canonical Rust-
                // stdlib messages "not yet implemented" / "not implemented"
                // when called with no args. Pre-fix the strip path produced
                // a `todo()` / `unimplemented()` fn call that failed late
                // with TYP-005 "undefined function" or TYP-026 "missing
                // tail expr" depending on context — both wrong-class.
            };
            // v0.3.99: vec![…] macro. Pre-v0.3.99 the lexer split
            // `vec![a, b, c]` as `vec` (ident) + `!` (logical-NOT) +
            // `[a, b, c]` (array-literal). The let-init bound `vec`
            // (an undefined global → clang link error `@vec undefined`)
            // and the array-literal payload became dead code. Rewrite
            // textually to a block expression that constructs a Vec
            // and pushes each element. Empty `vec![]` collapses to
            // `Vec::new()` for cleaner IR. Top-level commas split the
            // arg list; nested (), [], {}, and "/'/' string literals
            // are tracked so `vec![(1,2), [3,4]]` works.
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 91 {
                if str_eq(name, "vec") == 1 {
                    p = p + 2;
                    let lit_start: i64 = p;
                    let mut depth: i64 = 1;
                    let mut q: i64 = lit_start;
                    let mut in_dq: i64 = 0;
                    let mut in_sq: i64 = 0;
                    while q < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, q);
                        if in_dq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 34 { in_dq = 0; };
                        } else if in_sq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 39 { in_sq = 0; };
                        } else if ch == 34 { in_dq = 1; }
                        else if ch == 39 { in_sq = 1; }
                        else if ch == 91 { depth = depth + 1; }
                        else if ch == 93 { depth = depth - 1; };
                        q = q + 1;
                    };
                    if depth == 0 {
                        let lit_end: i64 = q - 1;
                        let inner: str = str_substring(src, lit_start, lit_end);
                        // v0.4.16: pass type_src so nested fmt_conversion
                        // type-inference still sees outer-scope declarations.
                        let inner_expanded: str = expand_format_macros_with_src(inner, type_src);
                        let mut all_ws: i64 = 1;
                        let il: i64 = str_len(inner_expanded);
                        let mut ic: i64 = 0;
                        while ic < il {
                            let cw: i64 = str_char_at(inner_expanded, ic);
                            if cw != 32 && cw != 9 && cw != 10 && cw != 13 { all_ws = 0; ic = il; };
                            ic = ic + 1;
                        };
                        if all_ws == 1 {
                            sb_append(sb, "Vec::new()");
                        } else {
                            // v0.6.41 (probe finding 2026-05-01-vec-repeat-
                            // syntax-ignores-count): scan for top-level `;`
                            // first — if present, this is the Rust repeat
                            // syntax `vec![X; N]` — emit a while-loop that
                            // pushes X N times. Pre-fix the `;` was treated
                            // as part of the value expression and the count
                            // was silently dropped (`vec![7; 5]` produced a
                            // 1-element vec with value `7;5` parsed weirdly).
                            let mut semi_pos_v064: i64 = 0 - 1;
                            let mut sd_chk_v064: i64 = 0;
                            let mut s_dq_chk_v064: i64 = 0;
                            let mut s_sq_chk_v064: i64 = 0;
                            let mut chk_idx_v064: i64 = 0;
                            while chk_idx_v064 < il {
                                let cc_v064: i64 = str_char_at(inner_expanded, chk_idx_v064);
                                if s_dq_chk_v064 == 1 {
                                    if cc_v064 == 92 && chk_idx_v064 + 1 < il { chk_idx_v064 = chk_idx_v064 + 1; }
                                    else if cc_v064 == 34 { s_dq_chk_v064 = 0; };
                                } else if s_sq_chk_v064 == 1 {
                                    if cc_v064 == 92 && chk_idx_v064 + 1 < il { chk_idx_v064 = chk_idx_v064 + 1; }
                                    else if cc_v064 == 39 { s_sq_chk_v064 = 0; };
                                } else if cc_v064 == 34 { s_dq_chk_v064 = 1; }
                                else if cc_v064 == 39 { s_sq_chk_v064 = 1; }
                                else if cc_v064 == 40 || cc_v064 == 91 || cc_v064 == 123 { sd_chk_v064 = sd_chk_v064 + 1; }
                                else if cc_v064 == 41 || cc_v064 == 93 || cc_v064 == 125 { sd_chk_v064 = sd_chk_v064 - 1; }
                                else if cc_v064 == 59 && sd_chk_v064 == 0 {
                                    semi_pos_v064 = chk_idx_v064;
                                    chk_idx_v064 = il;
                                };
                                chk_idx_v064 = chk_idx_v064 + 1;
                            };
                            if semi_pos_v064 >= 0 {
                                let val_text_v064: str = str_substring(inner_expanded, 0, semi_pos_v064);
                                let cnt_text_v064: str = str_substring(inner_expanded, semi_pos_v064 + 1, il);
                                sb_append(sb, "{ let mut __nuc_vec: Vec<i64> = Vec::new(); let mut __nuc_repeat_i: i64 = 0; let __nuc_repeat_n: i64 = (");
                                sb_append(sb, cnt_text_v064);
                                sb_append(sb, ") as i64; while __nuc_repeat_i < __nuc_repeat_n { __nuc_vec.push(");
                                sb_append(sb, val_text_v064);
                                sb_append(sb, "); __nuc_repeat_i = __nuc_repeat_i + 1; }; __nuc_vec }");
                            } else {
                            sb_append(sb, "{ let mut __nuc_vec: Vec<i64> = Vec::new(); ");
                            let mut sd: i64 = 0;
                            let mut s_dq: i64 = 0;
                            let mut s_sq: i64 = 0;
                            let mut item_start: i64 = 0;
                            let mut idx: i64 = 0;
                            while idx < il {
                                let ch2: i64 = str_char_at(inner_expanded, idx);
                                if s_dq == 1 {
                                    if ch2 == 92 && idx + 1 < il { idx = idx + 1; }
                                    else if ch2 == 34 { s_dq = 0; };
                                } else if s_sq == 1 {
                                    if ch2 == 92 && idx + 1 < il { idx = idx + 1; }
                                    else if ch2 == 39 { s_sq = 0; };
                                } else if ch2 == 34 { s_dq = 1; }
                                else if ch2 == 39 { s_sq = 1; }
                                else if ch2 == 40 || ch2 == 91 || ch2 == 123 { sd = sd + 1; }
                                else if ch2 == 41 || ch2 == 93 || ch2 == 125 { sd = sd - 1; }
                                else if ch2 == 44 && sd == 0 {
                                    let it: str = str_substring(inner_expanded, item_start, idx);
                                    sb_append(sb, "__nuc_vec.push(");
                                    sb_append(sb, it);
                                    sb_append(sb, "); ");
                                    item_start = idx + 1;
                                };
                                idx = idx + 1;
                            };
                            let last_it: str = str_substring(inner_expanded, item_start, il);
                            let lil: i64 = str_len(last_it);
                            let mut last_ws: i64 = 1;
                            let mut lic: i64 = 0;
                            while lic < lil {
                                let cw2: i64 = str_char_at(last_it, lic);
                                if cw2 != 32 && cw2 != 9 && cw2 != 10 && cw2 != 13 { last_ws = 0; lic = lil; };
                                lic = lic + 1;
                            };
                            if last_ws == 0 {
                                sb_append(sb, "__nuc_vec.push(");
                                sb_append(sb, last_it);
                                sb_append(sb, "); ");
                            };
                            sb_append(sb, "__nuc_vec }");
                            };
                        };
                        p = q;
                        last_non_ws = 41;
                        continue;
                    };
                };
            };
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 40 {
                let mut mode: i64 = 0 - 1;
                if str_eq(name, "println") == 1 { mode = 0; };
                if str_eq(name, "format") == 1 { mode = 1; };
                if str_eq(name, "print") == 1 { mode = 2; };
                // v0.5.22: eprintln!/eprint! macro forms (probe finding
                // 2026-05-01-eprintln-eprint-macro-falls-through-to-unary-not).
                // Pre-fix these fell through to unary-NOT parsing (`eprintln`
                // ident + `!` + `("...")` — `!` on str failed TYP-002).
                // Now route to eprint(...) / eprint_raw(...) — stderr-bound
                // siblings of println / print.
                if str_eq(name, "eprintln") == 1 { mode = 3; };
                if str_eq(name, "eprint") == 1 { mode = 4; };
                // v0.6.39 (probe finding 2026-05-01-panic-assert-macros-
                // drop-format-args): mode 5 = panic! — route format args
                // through the same expansion path as println so
                // `panic!("got {}", x)` produces `PANIC: got 7` instead of
                // pre-fix `PANIC: got {}`.
                if str_eq(name, "panic") == 1 { mode = 5; };
                // v0.6.56 (probe finding 2026-05-01-rust-syntax-translation-
                // fidelity-audit, unreachable!() row): canonical Rust
                // `unreachable!()` macro pre-fix fell through to the
                // identifier-then-unary-NOT path and emitted `error[TYP-005]:
                // undefined function 'unreachable()'` — wrong-class. Now
                // expand to `panic("internal error: entered unreachable
                // code")` matching Rust's std::macros::unreachable!()
                // implementation. With args (`unreachable!("got: {}", x)`),
                // route through the panic! mode 5 expansion so format
                // args work; without args, synthesize the canonical
                // Rust-stdlib message.
                if str_eq(name, "unreachable") == 1 { mode = 5; };
                // v0.7.36: `todo!()` and `unimplemented!()` route through
                // the panic-mode expansion just like `unreachable!()`. The
                // Rust stdlib defines them as panics with canonical messages
                // ("not yet implemented" / "not implemented"). Pre-fix the
                // `!` was stripped silently, the parser saw `todo()` /
                // `unimplemented()` as a fn call, and the user got either
                // wrong-class TYP-005 (undefined fn) or — when the call sat
                // as the last stmt of a non-void fn — wrong-class TYP-026
                // about the missing tail expression.
                if str_eq(name, "todo") == 1 { mode = 5; };
                if str_eq(name, "unimplemented") == 1 { mode = 5; };
                // v0.7.20 (defensive halt — Rust built-in macros NOT supported
                // in Nucleor's textual macro layer: file!/line!/column!/
                // module_path!/stringify!/concat!/env!/option_env!/include_str!/
                // include_bytes!). These need a const-eval pass which Nucleor
                // doesn't have yet. Pre-fix: wrong-class NR020 (zero-arg) or
                // TYP-005 (arg-bearing). v0.7.25: tightened to a single token-
                // boundary string-contains scan + one multi-line message.
                if mode == 0 - 1 && (str_eq(name, "file") == 1 || str_eq(name, "line") == 1 || str_eq(name, "column") == 1 || str_eq(name, "module_path") == 1 || str_eq(name, "stringify") == 1 || str_eq(name, "concat") == 1 || str_eq(name, "env") == 1 || str_eq(name, "option_env") == 1 || str_eq(name, "include_str") == 1 || str_eq(name, "include_bytes") == 1) {
                    print(str_concat("ERROR: Rust built-in macro `", str_concat(name, "!(...)` is not yet supported in Nucleor. Pre-v0.7.20 surfaced as wrong-class NR020 / TYP-005. These macros need a compile-time evaluation pass that Nucleor doesn't have yet (forward-roadmap).")));
                    print("       Workarounds: file!/line!/column!/module_path!/stringify! → hard-coded literal; concat! → str_concat at runtime or single literal; env!/option_env! → args_get / wrapper script; include_str!/include_bytes! → file_read_string at runtime.");
                    panic(str_concat("nucleor: built-in macro `", str_concat(name, "!(...)` not yet supported (see ERROR diagnostic above)")));
                };
                // v0.8.28 (defensive halt — user-defined / unknown macro
                // invocation `name!(args)` in expression position).
                // Pre-v0.8.28 any unrecognized `name!(args)` fell through
                // the macro expansion pass with the `!` preserved in the
                // output. The token-level parser then saw `name` (identifier)
                // followed by `!` (token 38, unary NOT) applied to `(args)`
                // (i32 / str expression) — producing wrong-class
                // `error[TYP-002]: unary \`!\` requires a \`bool\` operand
                // (got i32)`. This was the observable failure for code like
                // `square!(5)` when `macro_rules! square { ... }` had been
                // declared (but silently dropped — see the companion fix in
                // the module-level macro_rules halt above).
                if mode == 0 - 1 {
                    print(str_concat("ERROR: user-defined or unrecognized macro invocation `", str_concat(name, "!(...)` is not supported in Nucleor. Pre-v0.8.28 surfaced as wrong-class `error[TYP-002]: unary \\`!\\` requires a \\`bool\\` operand (got i32)` because the unrecognized macro name was left in the expanded output with the `!` preserved, and the expression parser then read `!` as unary NOT applied to the following argument. Workaround: rewrite the macro body as a regular fn — replace `name!(arg)` with `name(arg)` and declare `fn name(x: T) -> R { ... }` at module scope. For zero-arg macros like `name!()`, `fn name() -> R { ... }` works directly. Nucleor's metaprogramming substrate is fn-call + the built-in macros (`print!`, `println!`, `format!`, `vec!`, `panic!`, `assert!`, etc.). Tracked for forward-roadmap (declarative `macro_rules!` substrate is a v1.x ship).")));
                    panic(str_concat("nucleor: unknown macro `", str_concat(name, "!(...)` not supported (see ERROR diagnostic above)")));
                };
                if mode >= 0 {
                    p = p + 2;
                    let args_start: i64 = p;
                    let mut depth: i64 = 1;
                    let mut q: i64 = args_start;
                    let mut in_dq: i64 = 0;
                    let mut in_sq: i64 = 0;
                    while q < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, q);
                        if in_dq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 34 { in_dq = 0; };
                        } else if in_sq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 39 { in_sq = 0; };
                        } else if ch == 34 { in_dq = 1; }
                        else if ch == 39 { in_sq = 1; }
                        else if ch == 40 { depth = depth + 1; }
                        else if ch == 41 { depth = depth - 1; };
                        q = q + 1;
                    };
                    if depth == 0 {
                        let args_end: i64 = q - 1;
                        let mut args_text: str = str_substring(src, args_start, args_end);
                        // v0.6.56: empty `unreachable!()` (no args) gets
                        // the canonical Rust-stdlib message. With args
                        // (`unreachable!("...")`) the args pass through
                        // panic-mode expansion as-is.
                        if str_eq(name, "unreachable") == 1 && str_len(args_text) == 0 {
                            args_text = "\"internal error: entered unreachable code\"";
                        };
                        // v0.7.36: canonical Rust-stdlib messages for
                        // `todo!()` / `unimplemented!()` when called with
                        // no args (matches std::macros::todo / unimplemented).
                        if str_eq(name, "todo") == 1 && str_len(args_text) == 0 {
                            args_text = "\"not yet implemented\"";
                        };
                        if str_eq(name, "unimplemented") == 1 && str_len(args_text) == 0 {
                            args_text = "\"not implemented\"";
                        };
                        // v0.4.16: pass type_src so nested fmt_conversion
                        // type-inference still sees outer-scope declarations.
                        let inner_expanded: str = expand_format_macros_with_src(args_text, type_src);
                        let expansion: str = fmt_build_expansion(inner_expanded, mode, type_src);
                        sb_append(sb, expansion);
                        p = q;
                        last_non_ws = 41;
                        handled = 1;
                    };
                };
            };
            if handled == 0 {
                sb_append(sb, name);
                last_non_ws = str_char_at(name, str_len(name) - 1);
            };
        } else {
            sb_append_char_at(sb, src, p);
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

