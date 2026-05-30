// =====================================================
// COMPILER DRIVER
// =====================================================


#[manual_drop]
fn should_isolate_native_link(src_path: str) -> i64 {
    if str_contains(src_path, "compiler/nucleor_s1_compiler.nr") == 1 { return 1; };
    if str_contains(src_path, "compiler\\nucleor_s1_compiler.nr") == 1 { return 1; };
    if str_contains(src_path, "compiler/nucleor_tools_suite.nr") == 1 { return 1; };
    if str_contains(src_path, "compiler\\nucleor_tools_suite.nr") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn child_shell_quote(arg: str) -> str {
    return str_concat("\"", str_concat(arg, "\""));
}

#[manual_drop]
fn self_compiler_exe_for_child() -> str {
    let raw: str = args_get(0);
    if str_len(extract_dir(raw)) > 0 { return host_shell_path(sanitize(raw)); };
    if host_is_windows() == 1 {
        let win_dot_bin: str = ".\\bin\\nucleor.exe";
        if path_exists(win_dot_bin) == 1 { return win_dot_bin; };
        let win_bin: str = "bin\\nucleor.exe";
        if path_exists(win_bin) == 1 { return win_bin; };
    };
    let posix_bin: str = "bin/nucleor";
    if path_exists(posix_bin) == 1 { return posix_bin; };
    let posix_exe: str = "bin/nucleor.exe";
    if path_exists(posix_exe) == 1 { return posix_exe; };
    return raw;
}

#[manual_drop]
fn compile_file_mode_native_isolated(src_path: str, out_name: str, strict_mode: i64, use_cache: i64, time_passes: i64, link_native: i64) -> i64 {
    if link_native == 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, 0); };
    if strict_mode != 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, link_native); };
    if args_count() == 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, link_native); };
    if should_isolate_native_link(src_path) == 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, link_native); };
    let total_start: i64 = now_ms();
    let safe_out_name: str = normalize_output_name(out_name);
    if str_len(safe_out_name) == 0 {
        print(str_concat("ERROR: invalid output name: ", out_name));
        return 1;
    };
    let child_exe: str = self_compiler_exe_for_child();
    let mut child_cmd: str = "";
    if host_is_windows() == 1 {
        child_cmd = str_concat(child_exe, str_concat(" build ", host_shell_path(sanitize(src_path))));
        child_cmd = str_concat(child_cmd, str_concat(" -o ", safe_out_name));
    } else {
        child_cmd = str_concat(child_shell_quote(child_exe), str_concat(" build ", child_shell_quote(sanitize(src_path))));
        child_cmd = str_concat(child_cmd, str_concat(" -o ", child_shell_quote(safe_out_name)));
    };
    child_cmd = str_concat(child_cmd, " --no-link");
    if use_cache == 0 { child_cmd = str_concat(child_cmd, " --no-cache"); };
    if cache_v2_stats_enabled() == 1 { child_cmd = str_concat(child_cmd, " --cache-stats"); };
    if time_passes == 1 { child_cmd = str_concat(child_cmd, " --time-passes"); };
    let child_rc: i64 = system(child_cmd);
    if child_rc != 0 { return child_rc; };
    let ll_path: str = sanitize(str_concat("target/", str_concat(safe_out_name, ".ll")));
    if fs_exists(ll_path) == 0 || fs_size(ll_path) <= 0 {
        print(str_concat("ERROR: native link cannot read emitted IR ", ll_path));
        return 1;
    };
    let mut native_key_hint: str = "";
    if use_cache == 1 {
        let key_path: str = str_concat(ll_path, ".cachekey");
        if fs_exists(key_path) == 1 { native_key_hint = file_read_string(key_path); };
    };
    let imported: Vec<i32> = Vec::new();
    let rc: i64 = link_existing_native_module(ll_path, safe_out_name, imported, native_key_hint, time_passes);
    vec_free(imported);
    print_phase_time(time_passes, "total_native", now_ms() - total_start);
    return rc;
}



// ===== v0.3.0 (T3.1): #[deadline = N] runtime check rewrite =====
// Wraps fns annotated `#[deadline = N]` (microseconds) into a thin
// shim that captures the start time, calls the original body via
// a synthesized inner fn, then runs `deadline_check(start, N)`
// before returning. If the elapsed time exceeded N microseconds,
// the runtime aborts with `error[RT-004]`.
// Approach: rather than walking the body to find every `return`
// (which would need bracket-balanced + block-aware scanning), we
// rename the user's fn to `__nuc_dl_inner_<idx>` and synthesize a
// new outer fn with the original name that does:
//   let __nuc_dl_start: i64 = time_monotonic_us();
//   let __nuc_dl_r: <ret> = __nuc_dl_inner_<idx>(<args>);
//   deadline_check(__nuc_dl_start, N);
//   return __nuc_dl_r;
// The runtime check runs UNCONDITIONALLY at fn exit. Static WCET
// bounds (RT-004 at compile time) ship later in v0.3.1.



// scan resolved source for the
// literal `@differentiable` byte sequence and return the count.
// Adopters tag fns with `@differentiable` (RFC-0045 syntax); the
// lex-time skip silently accepts the attribute. This audit pass
// counts occurrences so the build emits a one-line "N fns
// tagged" summary — addressing the v0.7.93 Phase A "Discovery:
// no way to grep for all differentiable fns in a codebase"
// surface gap.
// Skips the count when compiling the compiler itself (the
// pattern appears in this comment + in expand_differentiable
// dispatcher source). Same self-host guard as the v0.7.98
// compile_error pre-pass.
#[manual_drop]
fn differentiable_audit_count(src: str) -> i64 {
    let mut count: i64 = 0;
    let needle: str = str_concat("@differen", "tiable");
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    if nlen <= 0 { return 0; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            count = count + 1;
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return count;
}

// generic substring-counter for
// attribute-audit passes. Sister to differentiable_audit_count;
// extracted for reuse across @energy / @thermal / future
// @authored / @policy / etc. discoveries.
#[manual_drop]
fn count_long_float_literals(src: str) -> i64 {
    let slen: i64 = str_len(src);
    let mut count: i64 = 0;
    let mut p: i64 = 0;
    while p + 8 < slen {
        let c0: i64 = str_char_at(src, p);
        if c0 >= 48 && c0 <= 57 {
            // walk past leading integer-part digits
            let mut q: i64 = p + 1;
            while q < slen && str_char_at(src, q) >= 48 && str_char_at(src, q) <= 57 {
                q = q + 1;
            };
            if q < slen && str_char_at(src, q) == 46 {
                // walk past dot, count fractional digits
                let mut r: i64 = q + 1;
                while r < slen && str_char_at(src, r) >= 48 && str_char_at(src, r) <= 57 {
                    r = r + 1;
                };
                let frac: i64 = r - q - 1;
                if frac >= 7 { count = count + 1; };
                p = r;
            } else {
                p = q;
            };
        } else {
            p = p + 1;
        };
    };
    return count;
}

#[manual_drop]
fn simple_attribute_audit_count(src: str, needle: str) -> i64 {
    let mut count: i64 = 0;
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    if nlen <= 0 { return 0; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            count = count + 1;
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return count;
}

// single-pass total counter for three-needle
// audits. Walks src once; at each position checks each needle
// in turn. Returns the sum of occurrences across all three.
// ~3x cheaper than three simple_attribute_audit_count calls
// when the caller only needs the combined total (e.g. BR-7
// lifetime audit).
#[manual_drop]
fn audit_count_three_needles_total(src: str, n1: str, n2: str, n3: str) -> i64 {
    let mut count: i64 = 0;
    let slen: i64 = str_len(src);
    let l1: i64 = str_len(n1);
    let l2: i64 = str_len(n2);
    let l3: i64 = str_len(n3);
    let mut p: i64 = 0;
    while p < slen {
        if l1 > 0 && p + l1 <= slen && str_eq_at_len(src, p, n1, l1) == 1 {
            count = count + 1;
            p = p + l1;
        } else {
            if l2 > 0 && p + l2 <= slen && str_eq_at_len(src, p, n2, l2) == 1 {
                count = count + 1;
                p = p + l2;
            } else {
                if l3 > 0 && p + l3 <= slen && str_eq_at_len(src, p, n3, l3) == 1 {
                    count = count + 1;
                    p = p + l3;
                } else {
                    p = p + 1;
                };
            };
        };
    };
    return count;
}

// capture the fn names tagged with a
// given attribute. Walks each `<needle>` occurrence, skips
// past attribute args + whitespace + newlines + nested
// attribute lines, then expects `fn NAME(...)` and captures
// NAME. Returns `; `-separated list.
// Used for the audit-channel "list of tagged fns" surface across
// the remaining 6 attribute families (@differentiable, @attested,
// @hot, @const_fn, #[max_depth], #[deadline]) plus any future
// addition with no key=val args to extract.
#[manual_drop]
fn attribute_audit_fn_names(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Walk past attribute args (paren or bracket form),
            // newlines, additional attribute lines, doc comments,
            // and `pub` to land on `fn`.
            let mut q: i64 = p + nlen;
            // Skip optional `(...)` or `[...]` arglist.
            if q < slen && (str_char_at(src, q) == 40 || str_char_at(src, q) == 91) {
                let close_ch: i64 = if str_char_at(src, q) == 40 { 41 } else { 93 };
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let ch: i64 = str_char_at(src, q);
                    if ch == 40 || ch == 91 { depth = depth + 1; };
                    if ch == close_ch { depth = depth - 1; };
                    q = q + 1;
                };
            };
            // Skip whitespace + newlines + further attribute lines.
            let mut tries: i64 = 0;
            while tries < 16 && q < slen {
                let ch: i64 = str_char_at(src, q);
                if ch == 32 || ch == 9 || ch == 10 || ch == 13 { q = q + 1; }
                else if ch == 64 || ch == 35 {
                    // Another attribute — skip its line.
                    while q < slen && str_char_at(src, q) != 10 { q = q + 1; };
                }
                else { tries = 16; };
                tries = tries + 1;
                if tries >= 1024 { tries = 16; };
            };
            // Optional `pub` modifier.
            if q + 4 <= slen && str_eq_at(src, q, "pub ") == 1 { q = q + 4; };
            while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) { q = q + 1; };
            // Expect `fn ` then capture ident.
            if q + 3 <= slen && str_eq_at(src, q, "fn ") == 1 {
                q = q + 3;
                while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) { q = q + 1; };
                let r0: i64 = q;
                while q < slen && is_alnum(str_char_at(src, q)) == 1 { q = q + 1; };
                if q > r0 {
                    if emitted == 1 { out = str_concat(out, "; "); };
                    out = str_concat(out, str_substring(src, r0, q));
                    emitted = 1;
                };
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract the device name from
// `@<attr>[device=<name>]` bracket-form attributes (RFC-0052
// `@photonic[device=lightmatter_x1]`, RFC-0053
// `@neuromorphic[device=loihi2]`). Captures the substring
// after `device=` up to `]`, with optional surrounding quotes
// stripped. Returns `; `-separated list across all matches.
#[manual_drop]
fn attribute_audit_bracket_device(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            let q: i64 = p + nlen;
            let dev_needle: str = str_concat("dev", "ice=");
            let dlen: i64 = str_len(dev_needle);
            // Find the closing `]` for this bracket.
            let mut close: i64 = q;
            while close < slen && str_char_at(src, close) != 93 && str_char_at(src, close) != 10 {
                close = close + 1;
            };
            // Scan q..close for `device=`.
            let mut k: i64 = q;
            let mut found: i64 = 0 - 1;
            while k + dlen <= close && found < 0 {
                if str_eq_at_len(src, k, dev_needle, dlen) == 1 { found = k + dlen; };
                k = k + 1;
            };
            if found >= 0 {
                let mut vs: i64 = found;
                while vs < close && (str_char_at(src, vs) == 32 || str_char_at(src, vs) == 9) {
                    vs = vs + 1;
                };
                let mut quoted: i64 = 0;
                if vs < close && str_char_at(src, vs) == 34 { quoted = 1; vs = vs + 1; };
                let mut ve: i64 = vs;
                while ve < close && str_char_at(src, ve) != 44 && (quoted == 0 || str_char_at(src, ve) != 34) {
                    ve = ve + 1;
                };
                if ve > vs {
                    if emitted == 1 { out = str_concat(out, "; "); };
                    out = str_concat(out, str_substring(src, vs, ve));
                    emitted = 1;
                };
            };
            p = close + 1;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// capture ALL `key=value` pairs from
// each `@<attr>(...)` invocation (multi-key form). Returns a
// `; `-separated list of `key=value` strings.
// `@thermal(min_temp=-40C, max_temp=85C)` -> "min_temp=-40C; max_temp=85C"
// `@energy(max=2mJ)` -> "max=2mJ"
// Captures everything from the first non-whitespace char after
// `(` up to the matching `)`, then walks through the captured
// arg-list character-by-character, splitting on `,` (depth-0)
// and emitting trimmed pieces.
#[manual_drop]
fn attribute_audit_all_kv_pairs(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            let q: i64 = p + nlen;
            // Walk to the matching close-paren (depth aware).
            let mut depth: i64 = 1;
            let mut close: i64 = q;
            while close < slen && depth > 0 {
                let ch: i64 = str_char_at(src, close);
                if ch == 40 { depth = depth + 1; };
                if ch == 41 { depth = depth - 1; };
                if depth > 0 { close = close + 1; };
            };
            // Walk q..close, splitting on top-level `,`.
            let mut piece_start: i64 = q;
            let mut i: i64 = q;
            let mut inner_depth: i64 = 0;
            while i <= close {
                let at_close: i64 = if i == close { 1 } else { 0 };
                let ch: i64 = if i < slen { str_char_at(src, i) } else { 0 };
                let is_split: i64 = if at_close == 1 { 1 } else if ch == 44 && inner_depth == 0 { 1 } else { 0 };
                if is_split == 1 {
                    let mut s0: i64 = piece_start;
                    let mut s1: i64 = i;
                    while s0 < s1 && (str_char_at(src, s0) == 32 || str_char_at(src, s0) == 9) { s0 = s0 + 1; };
                    while s1 > s0 && (str_char_at(src, s1 - 1) == 32 || str_char_at(src, s1 - 1) == 9) { s1 = s1 - 1; };
                    if s1 > s0 {
                        if emitted == 1 { out = str_concat(out, "; "); };
                        out = str_concat(out, str_substring(src, s0, s1));
                        emitted = 1;
                    };
                    piece_start = i + 1;
                };
                if i < close {
                    if ch == 40 { inner_depth = inner_depth + 1; };
                    if ch == 41 && inner_depth > 0 { inner_depth = inner_depth - 1; };
                };
                i = i + 1;
            };
            p = close + 1;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract numeric value+unit pairs from
// `@<attr>(<key>=<value>)` invocations like `@energy(max=2mJ)`,
// `@thermal(max_temp=85C)`, `@within(200ns)`. Captures the
// substring between `=` and the closing `)` or `,`, trimmed of
// surrounding whitespace. For `@within(200ns)` (no key=), it
// captures everything between `(` and `)`.
// Returns `; `-separated list of captured value-strings.
#[manual_drop]
fn attribute_audit_value_arg(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Find the start of the value: after `=` if present
            // before the close, otherwise immediately after `(`.
            let mut q: i64 = p + nlen;
            // Walk to either `=` or `)` or end-of-line.
            let mut value_start: i64 = q;
            let mut saw_eq: i64 = 0;
            let mut probe: i64 = q;
            while probe < slen && str_char_at(src, probe) != 41 && str_char_at(src, probe) != 10 {
                if str_char_at(src, probe) == 61 {
                    saw_eq = 1;
                    value_start = probe + 1;
                };
                probe = probe + 1;
            };
            if saw_eq == 0 { value_start = q; };
            // Skip leading whitespace.
            while value_start < slen && (str_char_at(src, value_start) == 32 || str_char_at(src, value_start) == 9) {
                value_start = value_start + 1;
            };
            // Capture until `,` or `)` or end-of-line.
            let mut value_end: i64 = value_start;
            while value_end < slen && str_char_at(src, value_end) != 44 && str_char_at(src, value_end) != 41 && str_char_at(src, value_end) != 10 {
                value_end = value_end + 1;
            };
            // Trim trailing whitespace.
            while value_end > value_start && (str_char_at(src, value_end - 1) == 32 || str_char_at(src, value_end - 1) == 9) {
                value_end = value_end - 1;
            };
            if value_end > value_start {
                if emitted == 1 { out = str_concat(out, "; "); };
                out = str_concat(out, str_substring(src, value_start, value_end));
                emitted = 1;
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract the first BARE-IDENTIFIER
// argument from each `@<attr>(...)` invocation. Used by attrs
// like `@enclave(tdx)` / `@enclave(sev_snp)` where the
// argument is a bare ident (no quotes).
#[manual_drop]
fn attribute_audit_first_ident_arg(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Walk forward past `(` then optional whitespace.
            let mut q: i64 = p + nlen;
            while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) {
                q = q + 1;
            };
            // Capture chars while is_alnum (ident class).
            let r0: i64 = q;
            while q < slen && is_alnum(str_char_at(src, q)) == 1 {
                q = q + 1;
            };
            if q > r0 {
                if emitted == 1 { out = str_concat(out, "; "); };
                out = str_concat(out, str_substring(src, r0, q));
                emitted = 1;
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract the first quoted string-literal
// argument from each `@<attr>(...)` invocation in the resolved
// source. Returns a `; `-separated list of the extracted names
// (or empty string when none). Used by the @authored audit to
// emit the actual list of authors at build time, going past the
// step-1 count-only summary. Generic shape — same scan reusable
// for @policy, @photonic[device=...], etc. as those settle into
// quoted-string-arg conventions.
#[manual_drop]
fn attribute_audit_first_str_arg(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Walk forward past `(`, optional whitespace, optional
            // `key=` or `device=` prefix, to the first `"`. Accept
            // chars until the next `"` or end-of-line.
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(src, q) != 34 && str_char_at(src, q) != 10 && str_char_at(src, q) != 41 {
                q = q + 1;
            };
            if q < slen && str_char_at(src, q) == 34 {
                let r0: i64 = q + 1;
                let mut r1: i64 = r0;
                while r1 < slen && str_char_at(src, r1) != 34 && str_char_at(src, r1) != 10 {
                    r1 = r1 + 1;
                };
                if r1 > r0 {
                    if emitted == 1 { out = str_concat(out, "; "); };
                    out = str_concat(out, str_substring(src, r0, r1));
                    emitted = 1;
                };
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}


// backward-scan helper for `#[max_depth = N]` impl-context.
// The wrapper-rewrite needs the enclosing impl-block's receiver type
// (e.g. "Node" for `impl Node { ... }` or `impl Trait for Node { ... }`)
// to emit `<Type>::<inner>(...)` for assoc-fn (no-self) recursion. We
// scan backwards from the attribute position, balancing braces, to find
// the most-recent unclosed `impl <Type> [for <Type2>]?\s*{`. Returns ""
// when not in an impl block (free fn at module top level).
#[manual_drop]
fn md_find_enclosing_impl_type(src: str, attr_pos: i64) -> str {
    let mut depth: i64 = 0;
    let mut p: i64 = attr_pos - 1;
    while p >= 0 {
        let c: i64 = str_char_at(src, p);
        if c == 125 { depth = depth + 1; };
        if c == 123 {
            if depth == 0 {
                let mut q: i64 = p - 1;
                while q >= 0 && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9 || str_char_at(src, q) == 10 || str_char_at(src, q) == 13) { q = q - 1; };
                let name_end: i64 = q + 1;
                while q >= 0 && (is_alnum(str_char_at(src, q)) == 1 || str_char_at(src, q) == 95) { q = q - 1; };
                let name_start: i64 = q + 1;
                if name_end <= name_start { return ""; };
                let cand_name: str = str_substring(src, name_start, name_end);
                let mut r: i64 = q;
                while r >= 0 && (str_char_at(src, r) == 32 || str_char_at(src, r) == 9 || str_char_at(src, r) == 10 || str_char_at(src, r) == 13) { r = r - 1; };
                let prev_end: i64 = r + 1;
                while r >= 0 && (is_alnum(str_char_at(src, r)) == 1 || str_char_at(src, r) == 95) { r = r - 1; };
                let prev_start: i64 = r + 1;
                let prev_word: str = if prev_end > prev_start { str_substring(src, prev_start, prev_end) } else { "" };
                if str_eq(prev_word, "impl") == 1 {
                    if prev_start == 0 || str_char_at(src, prev_start - 1) == 32 || str_char_at(src, prev_start - 1) == 9 || str_char_at(src, prev_start - 1) == 10 {
                        return cand_name;
                    };
                    return "";
                };
                if str_eq(prev_word, "for") == 1 {
                    let mut s: i64 = r;
                    while s >= 0 && (str_char_at(src, s) == 32 || str_char_at(src, s) == 9 || str_char_at(src, s) == 10 || str_char_at(src, s) == 13) { s = s - 1; };
                    while s >= 0 && (is_alnum(str_char_at(src, s)) == 1 || str_char_at(src, s) == 95) { s = s - 1; };
                    while s >= 0 && (str_char_at(src, s) == 32 || str_char_at(src, s) == 9 || str_char_at(src, s) == 10 || str_char_at(src, s) == 13) { s = s - 1; };
                    let il_end: i64 = s + 1;
                    while s >= 0 && (is_alnum(str_char_at(src, s)) == 1 || str_char_at(src, s) == 95) { s = s - 1; };
                    let il_start: i64 = s + 1;
                    if il_end > il_start {
                        let il_word: str = str_substring(src, il_start, il_end);
                        if str_eq(il_word, "impl") == 1 {
                            return cand_name;
                        };
                    };
                    return "";
                };
                return "";
            };
            depth = depth - 1;
        };
        p = p - 1;
    };
    return "";
}

#[manual_drop]
fn expand_max_depth(src: str) -> str {
    // Runtime half of RFC-0014. Valid `#[max_depth = N]` fns are
    // rewritten into an inner body plus a wrapper that increments and
    // decrements a per-function depth counter. Static validation runs
    // on the pre-rewrite source so invalid attrs stay visible there.
    if source_has_max_depth_attr_line(src) == 0 { return src; };
    let slen: i64 = str_len(src);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    let mut idx: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let compact_line: str = strip_spaces(line);
        if str_starts_with(compact_line, "#[max_depth") == 1 {
            let md_value: i64 = md_extract_int_value(line);
            if md_value > 0 {
                let mut probe: i64 = eol + 1;
                let mut found_fn: i64 = 0 - 1;
                let mut gave_up: i64 = 0;
                while probe < slen && found_fn < 0 && gave_up == 0 {
                    let mut peol: i64 = probe;
                    while peol < slen && str_char_at(src, peol) != 10 { peol = peol + 1; };
                    let pline: str = str_substring(src, probe, peol);
                    let mut lp: i64 = 0;
                    let llen: i64 = str_len(pline);
                    while lp < llen && (str_char_at(pline, lp) == 32 || str_char_at(pline, lp) == 9) { lp = lp + 1; };
                    let ptrim: str = strip_spaces(pline);
                    if str_len(ptrim) == 0 {
                        probe = peol + 1;
                    } else if str_starts_with(ptrim, "///") == 1 {
                        probe = peol + 1;
                    } else if str_eq_at(pline, lp, "fn ") == 1 {
                        found_fn = probe + lp;
                    } else if str_eq_at(pline, lp, "pub fn ") == 1 {
                        found_fn = probe + lp + 4;
                    } else if lp < llen && str_char_at(pline, lp) == 35 {
                        probe = peol + 1;
                    } else {
                        gave_up = 1;
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
                        let inner_name: str = str_concat("__nuc_md_inner_", str_concat(content_hash(fn_name), str_concat("_", str_from_int(idx))));
                        let counter_id: i64 = idx + 1;
                        idx = idx + 1;
                        sb_append(sb, str_substring(src, eol + 1, found_fn));
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
                        sb_append(sb, "    max_depth_enter(");
                        sb_append(sb, str_from_int(counter_id));
                        sb_append(sb, ", ");
                        sb_append(sb, str_from_int(md_value));
                        sb_append(sb, ");\n");
                        // when the rewritten fn is an impl method
                        // (first param is `self`), the wrapper must call
                        // the inner via method dispatch — `self.inner(rest)`
                        // — not free-fn dispatch `inner(self, rest)`. The
                        // inner declaration sits inside the same impl
                        // block, so it's resolved as an impl method.
                        // extends to the assoc-fn (no-self) form
                        // — the inner is registered as `Type::<inner>`,
                        // so the wrapper must emit `Type::<inner>(args)`.
                        // Detection: backward-scan from the #[max_depth]
                        // line position to find the enclosing
                        // `impl <Type> { ... }` (or `impl Trait for Type
                        // { ... }`). Empty enclosing-type means the fn is
                        // free, and the original free-fn dispatch shape
                        // is correct.
                        let mut is_impl_method: i64 = 0;
                        let mut rest_args: str = arg_names;
                        let an_len: i64 = str_len(arg_names);
                        if an_len >= 4 {
                            if str_eq_at(arg_names, 0, "self") == 1 {
                                if an_len == 4 {
                                    is_impl_method = 1;
                                    rest_args = "";
                                } else if str_char_at(arg_names, 4) == 44 {
                                    is_impl_method = 1;
                                    let mut rs: i64 = 5;
                                    while rs < an_len && (str_char_at(arg_names, rs) == 32 || str_char_at(arg_names, rs) == 9) { rs = rs + 1; };
                                    rest_args = str_substring(arg_names, rs, an_len);
                                };
                            };
                        };
                        let mut enclosing_type: str = "";
                        if is_impl_method == 0 {
                            enclosing_type = md_find_enclosing_impl_type(src, p);
                        };
                        if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 {
                            sb_append(sb, "    let __nuc_md_r: ");
                            sb_append(sb, ret_type);
                            sb_append(sb, " = ");
                            if is_impl_method == 1 {
                                sb_append(sb, "self.");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, rest_args);
                                sb_append(sb, ");\n");
                            } else if str_len(enclosing_type) > 0 {
                                sb_append(sb, enclosing_type);
                                sb_append(sb, "::");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            } else {
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            };
                            sb_append(sb, "    max_depth_exit(");
                            sb_append(sb, str_from_int(counter_id));
                            sb_append(sb, ");\n");
                            sb_append(sb, "    return __nuc_md_r;\n");
                        } else {
                            sb_append(sb, "    ");
                            if is_impl_method == 1 {
                                sb_append(sb, "self.");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, rest_args);
                                sb_append(sb, ");\n");
                            } else if str_len(enclosing_type) > 0 {
                                sb_append(sb, enclosing_type);
                                sb_append(sb, "::");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            } else {
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            };
                            sb_append(sb, "    max_depth_exit(");
                            sb_append(sb, str_from_int(counter_id));
                            sb_append(sb, ");\n");
                        };
                        sb_append(sb, "}\n");
                        p = body_end;
                        continue;
                    };
                };
            };
        };
        sb_append(sb, str_substring(src, p, eol));
        if eol < slen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    return sb_to_str(sb);
}
// Resolver-level rewrite of two pieces of async syntax:
//   `async fn name(...)`  → `fn name(...)` (keyword strip)
//   `<ident>.await`        → `async_await(<ident>)`
// The runtime is committed to threads-only (RFC-0027 phase 1):
// `async_spawn(fn_ptr, arg)` returns an opaque task handle that
// runs the fn on a real OS thread; `async_await(handle)` joins
// the thread + returns the captured i64 result. No green-thread
// scheduler, no future polling — every async fn is a thread.
// `.await` is restricted to the simple `<ident>.await` form
// today. Complex receivers (`call().await`, `arr[0].await`)
// require a let-binding first. T2.8b will lift that restriction
// once we have a depth-aware backwards-receiver scanner.




// ===== T2.3 (v0.2.349): closure literals (no-capture) =====
// Source-level rewriting of `|args| body` closure expressions in
// argument position. Each closure is lifted into a synthesized
// top-level fn (`__closure_<hash>_<idx>`), prepended to the merged
// source, and the closure expression is replaced with a bare
// identifier reference to that fn. The Vec iterator helpers
// (T2.2 dispatch) then receive a function-pointer value through
// the existing i64-cell convention — no runtime change required.
// Scope: NO-CAPTURE closures only (the body must not reference
// any name that would be undefined at the top-level scope).
// Closures with captures land in T2.3b once the runtime gains
// `(fn_ptr, env_ptr)` pair-call support.
// Disambiguation from bitwise `|`: closures are recognized only
// when `|` appears in an expression-arg position — immediately
// preceded (after whitespace) by `(`, `,`, `=`, `=>`, `[`, or
// the start of source. A `|` between values (e.g. `a | b`) stays
// a bitwise op.






// ===== T2.6 (v0.2.346): format-string macro expansion =====
// Source-level rewriting of `println!(fmt, args...)`,
// `print!(fmt, args...)`, and `format!(fmt, args...)` calls into
// the equivalent str_concat + print/print_raw expression chain.
// Runs in the resolver, AFTER all imports are inlined and BEFORE
// the source is cached / lexed.
// Format spec syntax:
//   {}    — int_to_str(arg)   (default; the most common case)
//   {:i}  — int_to_str(arg)   (explicit alias)
//   {:s}  — arg as-is         (caller-provided str)
//   {:f}  — f64_to_str(arg)
//   {:b}  — bool_to_str(arg)
//   {{ }} — literal `{` / `}` (Rust convention)
// Modes:
//   println!  — wraps result in `print(...)`  (adds trailing \n via runtime)
//   print!    — wraps result in `print_raw(...)` (no trailing \n)
//   format!   — bare expression, returns str
// The expander is identifier- and quote-aware: skips `// ...`
// line comments, `"..."` string literals, and `'X'` char literals.
// `name!` after a `.` (method call) is left alone.




// helper for the bare-`{}` heuristic. Scan src for ALL
// `let <name>: TYPE` and `let mut <name>: TYPE` declarations and
// return TYPE only if every declaration of <name> agrees. If the
// same name has conflicting types (e.g. `let x: str` in one fn and
// `let x: i64` in another), return "" so the heuristic falls back
// to the default int_to_str.
// Conservative-by-construction: if there's any ambiguity, do nothing.
// Worst case the adopter sees the original int-as-pointer output and
// switches to explicit `:s` / `:f` -- still a hazard but a less harmful
// one than the v0.3.152-rev1 bug where the scan picked the WRONG
// declaration and crashed (SIGSEGV when an i64 was passed to print_str).
// Also requires the matched `let` to be followed by a TYPE (not
// elision via `let x = ...;` without a type annotation) so we never
// invent a type out of thin air.
// pattern-binding type inference for user-defined enum
// variants (the existing infer_pattern_binding_type_from_source
// only handles built-in Some/Ok/Err). Scans source for arms of
// the form `<EnumName>::<VariantName>(<binding>, ...)` and locates
// `<binding>` by index. Looks up the variant's payload-i type via
// infer_enum_variant_payload_type. Conflict-detects across all
// occurrences of the same binding name.
// Conservative-by-construction: the variant-name pattern requires
// EnumName and VariantName both to start with uppercase letters,
// avoiding false-positive match on lowercase fn calls (e.g., a
// function call `foo(s, n)` is NOT misread as a variant pattern).
#[manual_drop]
fn infer_user_variant_binding_type(src: str, var_name: str) -> str {
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 || slen < 8 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    // bound the scan to the last 256 KB. The bundled
    // source has stdlib PREpended (~700 KB+), then user code at the
    // tail. format-macro args reference user-code declarations 99%
    // of the time; full-source scan was 1.6 BILLION str_char_at
    // calls per compile (cold +1.4s vs v0.4.17). Bounded scan reduces
    // that proportionally without changing observed correctness for
    // any adopter pattern.
    let mut i: i64 = if slen > 262144 { slen - 262144 } else { 0 };
    // Scan for `::<UpperVariant>(` -- the `::` anchors the user-variant
    // shape, eliminating most false positives (function-call form
    // `foo(...)` doesn't have `::`).
    while i + 4 < slen {
        if str_char_at(src, i) == 58 && str_char_at(src, i + 1) == 58 {
            // Walk back to find the EnumName (uppercase ident).
            let mut en_end: i64 = i;
            let mut en_start: i64 = i;
            let mut walked: i64 = 0;
            while en_start > 0 && walked < 64 {
                let c: i64 = str_char_at(src, en_start - 1);
                let id_cont: i64 = if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95 { 1 } else { 0 };
                if id_cont == 0 { walked = 64; }
                else { en_start = en_start - 1; walked = walked + 1; };
            };
            if en_start < en_end {
                let first_ch: i64 = str_char_at(src, en_start);
                if first_ch >= 65 && first_ch <= 90 {
                    // Read VariantName after `::`.
                    let mut vp: i64 = i + 2;
                    let var_start: i64 = vp;
                    let mut keep_v: i64 = 1;
                    while keep_v == 1 && vp < slen {
                        let c2: i64 = str_char_at(src, vp);
                        let id_cont2: i64 = if (c2 >= 65 && c2 <= 90) || (c2 >= 97 && c2 <= 122) || (c2 >= 48 && c2 <= 57) || c2 == 95 { 1 } else { 0 };
                        if id_cont2 == 1 { vp = vp + 1; } else { keep_v = 0; };
                    };
                    let var_end: i64 = vp;
                    if var_end > var_start {
                        let v_first: i64 = str_char_at(src, var_start);
                        if v_first >= 65 && v_first <= 90 && vp < slen && str_char_at(src, vp) == 40 {
                            // Parse binding list inside `(...)` and find var_name by index.
                            let enum_name: str = str_substring(src, en_start, en_end);
                            let variant_name: str = str_substring(src, var_start, var_end);
                            let mut bp: i64 = vp + 1;
                            let mut bind_idx: i64 = 0;
                            let mut depth_b: i64 = 0;
                            let mut bind_start: i64 = bp;
                            let mut hit_idx: i64 = 0 - 1;
                            while bp < slen {
                                let bc: i64 = str_char_at(src, bp);
                                if bc == 40 || bc == 60 { depth_b = depth_b + 1; }
                                else if bc == 62 { depth_b = depth_b - 1; }
                                else if (bc == 41 || bc == 44) && depth_b == 0 {
                                    let mut bs2: i64 = bind_start;
                                    while bs2 < bp && str_char_at(src, bs2) == 32 { bs2 = bs2 + 1; };
                                    let mut be2: i64 = bp;
                                    while be2 > bs2 && str_char_at(src, be2 - 1) == 32 { be2 = be2 - 1; };
                                    let cur_name: str = str_substring(src, bs2, be2);
                                    if str_eq(cur_name, var_name) == 1 { hit_idx = bind_idx; bp = slen; };
                                    if bc == 41 { bp = slen; }
                                    else { bind_idx = bind_idx + 1; bind_start = bp + 1; };
                                };
                                bp = bp + 1;
                            };
                            if hit_idx >= 0 {
                                let candidate: str = infer_enum_variant_payload_type(src, enum_name, variant_name, hit_idx);
                                if str_len(candidate) > 0 {
                                    if str_len(found_type) == 0 { found_type = candidate; }
                                    else { if str_eq(found_type, candidate) == 0 { conflict = 1; }; };
                                };
                            };
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

// parse user-defined enum variant payload type from source.
// For `pub enum MyErr { ... BadInput(str, i64), ... }`, returns the
// idx-th payload type ("str" for idx=0, "i64" for idx=1). Returns ""
// if not found. Conflict-detects across multiple enum decls with
// the same name (rare but possible across imports).
#[manual_drop]
fn infer_enum_variant_payload_type(src: str, enum_name: str, variant_name: str, idx: i64) -> str {
    let slen: i64 = str_len(src);
    let enlen: i64 = str_len(enum_name);
    let vnlen: i64 = str_len(variant_name);
    if enlen == 0 || vnlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    // bound to last 256 KB (user-code region). User
    // enum declarations live in user code; stdlib doesn't define
    // adopter-shape enums.
    let mut i: i64 = if slen > 262144 { slen - 262144 } else { 0 };
    while i + 5 < slen {
        // "enum " = 'e','n','u','m',' ' = 101,110,117,109,32
        if str_char_at(src, i) == 101
            && str_char_at(src, i + 1) == 110
            && str_char_at(src, i + 2) == 117
            && str_char_at(src, i + 3) == 109
            && str_char_at(src, i + 4) == 32 {
            let mut bdry_ok: i64 = 1;
            if i > 0 {
                let pc: i64 = str_char_at(src, i - 1);
                if (pc >= 65 && pc <= 90) || (pc >= 97 && pc <= 122) || (pc >= 48 && pc <= 57) || pc == 95 { bdry_ok = 0; };
            };
            if bdry_ok == 1 {
                let mut p: i64 = i + 5;
                let mut k: i64 = 0;
                let mut nm_ok: i64 = 1;
                while k < enlen {
                    if p + k >= slen { nm_ok = 0; k = enlen; }
                    else if str_char_at(src, p + k) != str_char_at(enum_name, k) { nm_ok = 0; k = enlen; };
                    k = k + 1;
                };
                if nm_ok == 1 {
                    let after: i64 = p + enlen;
                    if after < slen {
                        let nc: i64 = str_char_at(src, after);
                        let id_cont: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                        if id_cont == 0 {
                            // Skip ws + optional generics + ws, expect `{`.
                            let mut q: i64 = after;
                            while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                            if q < slen && str_char_at(src, q) == 60 {
                                let mut gd: i64 = 1; q = q + 1;
                                while q < slen && gd > 0 {
                                    let gc: i64 = str_char_at(src, q);
                                    if gc == 60 { gd = gd + 1; } else { if gc == 62 { gd = gd - 1; }; };
                                    q = q + 1;
                                };
                                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                            };
                            if q < slen && str_char_at(src, q) == 123 {
                                q = q + 1;
                                let body_start: i64 = q;
                                let mut bdepth: i64 = 1;
                                while q < slen && bdepth > 0 {
                                    let bc: i64 = str_char_at(src, q);
                                    if bc == 123 { bdepth = bdepth + 1; }
                                    else { if bc == 125 { bdepth = bdepth - 1; }; };
                                    if bdepth > 0 { q = q + 1; };
                                };
                                let body_end: i64 = q;
                                // Scan body for `<variant_name>(...)` token.
                                let mut bp: i64 = body_start;
                                while bp + vnlen < body_end {
                                    let prev_c: i64 = if bp == 0 { 32 } else { str_char_at(src, bp - 1) };
                                    let prev_ok: i64 = if prev_c == 32 || prev_c == 9 || prev_c == 10 || prev_c == 13 || prev_c == 44 || prev_c == 123 { 1 } else { 0 };
                                    if prev_ok == 1 {
                                        let mut vmatched: i64 = 1;
                                        let mut vk: i64 = 0;
                                        while vk < vnlen {
                                            if bp + vk >= body_end { vmatched = 0; vk = vnlen; }
                                            else if str_char_at(src, bp + vk) != str_char_at(variant_name, vk) { vmatched = 0; vk = vnlen; };
                                            vk = vk + 1;
                                        };
                                        if vmatched == 1 {
                                            let after_v: i64 = bp + vnlen;
                                            if after_v < body_end && str_char_at(src, after_v) == 40 {
                                                // Parse comma-separated payload types until `)`.
                                                let mut pp: i64 = after_v + 1;
                                                let mut payload_idx: i64 = 0;
                                                let mut payload_start: i64 = pp;
                                                let mut depth_p: i64 = 0;
                                                let mut found_this: str = "";
                                                while pp < body_end {
                                                    let pc2: i64 = str_char_at(src, pp);
                                                    if pc2 == 60 || pc2 == 40 { depth_p = depth_p + 1; }
                                                    else if pc2 == 62 { depth_p = depth_p - 1; }
                                                    else if pc2 == 41 && depth_p == 0 {
                                                        if payload_idx == idx {
                                                            let mut ps2: i64 = payload_start;
                                                            while ps2 < pp && str_char_at(src, ps2) == 32 { ps2 = ps2 + 1; };
                                                            let mut pe2: i64 = pp;
                                                            while pe2 > ps2 && str_char_at(src, pe2 - 1) == 32 { pe2 = pe2 - 1; };
                                                            found_this = type_base_name(str_substring(src, ps2, pe2));
                                                        };
                                                        pp = body_end;
                                                    }
                                                    else if pc2 == 44 && depth_p == 0 {
                                                        if payload_idx == idx {
                                                            let mut ps2: i64 = payload_start;
                                                            while ps2 < pp && str_char_at(src, ps2) == 32 { ps2 = ps2 + 1; };
                                                            let mut pe2: i64 = pp;
                                                            while pe2 > ps2 && str_char_at(src, pe2 - 1) == 32 { pe2 = pe2 - 1; };
                                                            found_this = type_base_name(str_substring(src, ps2, pe2));
                                                            pp = body_end;
                                                        };
                                                        payload_idx = payload_idx + 1;
                                                        payload_start = pp + 1;
                                                    };
                                                    pp = pp + 1;
                                                };
                                                if str_len(found_this) > 0 {
                                                    if str_len(found_type) == 0 { found_type = found_this; }
                                                    else { if str_eq(found_type, found_this) == 0 { conflict = 1; }; };
                                                };
                                                bp = body_end;
                                            };
                                        };
                                    };
                                    bp = bp + 1;
                                };
                            };
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

// bounded backward `let <name>: T = ...` scanner. When
// the source bundle has many `let <name>: T` declarations across
// imports, the global infer_var_type_from_source returns "" on
// conflict. This bounded variant scans BACKWARD from `match_pos`
// to find the most-recent `let <name>: T` -- the closest scope-
// local declaration, which is what shadowing semantics actually
// resolve to. Limited to ~2 KB scan back.
#[manual_drop]
fn infer_var_type_local_back(src: str, var_name: str, match_pos: i64) -> str {
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 || match_pos <= 4 { return ""; };
    // tighter bound, was 4 KB. 1 KB is enough for nearly
    // all match scrutinee declarations (let X: T = ...; match X { ... }).
    let scan_back_limit: i64 = if match_pos > 1024 { match_pos - 1024 } else { 0 };
    let mut j: i64 = match_pos - 1;
    while j >= scan_back_limit {
        // Look for "let " at j (with optional "let mut ").
        if j + 3 < slen
            && str_char_at(src, j) == 108
            && str_char_at(src, j + 1) == 101
            && str_char_at(src, j + 2) == 116
            && str_char_at(src, j + 3) == 32 {
            // Boundary: char before `let` must not be id-continue.
            let mut bdry_ok: i64 = 1;
            if j > 0 {
                let bpc: i64 = str_char_at(src, j - 1);
                if (bpc >= 65 && bpc <= 90) || (bpc >= 97 && bpc <= 122) || (bpc >= 48 && bpc <= 57) || bpc == 95 { bdry_ok = 0; };
            };
            if bdry_ok == 1 {
                let mut p: i64 = j + 4;
                // Optional "mut ".
                if p + 4 <= slen
                    && str_char_at(src, p) == 109
                    && str_char_at(src, p + 1) == 117
                    && str_char_at(src, p + 2) == 116
                    && str_char_at(src, p + 3) == 32 {
                    p = p + 4;
                };
                // Match var_name.
                let mut k: i64 = 0;
                let mut nm_ok: i64 = 1;
                while k < vlen {
                    if p + k >= slen { nm_ok = 0; k = vlen; }
                    else if str_char_at(src, p + k) != str_char_at(var_name, k) { nm_ok = 0; k = vlen; };
                    k = k + 1;
                };
                if nm_ok == 1 {
                    let after: i64 = p + vlen;
                    if after < slen {
                        let nc: i64 = str_char_at(src, after);
                        let id_cont: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                        if id_cont == 0 {
                            // Skip whitespace; expect ":".
                            let mut q: i64 = after;
                            while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                            if q < slen && str_char_at(src, q) == 58 {
                                q = q + 1;
                                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                                let ts: i64 = q;
                                let mut gd: i64 = 0;
                                while q < slen {
                                    let tc: i64 = str_char_at(src, q);
                                    if tc == 60 { gd = gd + 1; }
                                    else if tc == 62 { gd = gd - 1; };
                                    if gd == 0 && (tc == 32 || tc == 61 || tc == 59 || tc == 10 || tc == 13) {
                                        return str_substring(src, ts, q);
                                    };
                                    q = q + 1;
                                };
                            };
                        };
                    };
                };
            };
        };
        j = j - 1;
    };
    return "";
}

// companion to infer_var_type_from_source. Scans src for
// match-arm pattern bindings of the form `Some(<var_name>)`,
// `Ok(<var_name>)`, `Err(<var_name>)`. When found, walks back to
// the enclosing `match <scrutinee>`, infers the scrutinee's type
// via infer_var_type_from_source, and extracts the generic parameter
// (T from Option<T>, T from Result<T, E> for Ok, E for Err).
// Returns "" if no match or the scrutinee type isn't recognized.
// This closes the println!/format! gap for typed Option/Result
// payload bindings: `match x { Some(s) => println!("{}", s) }`
// where `x: Option<str>` previously printed the raw pointer
// integer because the source-scanner couldn't find `let s: T = ...`
// (s is bound by a pattern, not a let). The non-macro path
// (let-assign / str_eq / field access) was closed in v0.4.4.
#[manual_drop]
fn infer_pattern_binding_type_from_source(src: str, var_name: str) -> str {
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 || slen < 8 { return ""; };
    // scan ALL occurrences and conflict-detect. If the same
    // binding name appears in multiple match arms with different
    // scrutinee types, return "" -- safer than picking the first one
    // (which previously miscompiled `Some(v)` for both Option<i64>
    // and Option<f64> when `v` was reused). Adopters with the same-
    // name-multi-arm shape see the conservative int_to_str default,
    // not a wrong-type guess.
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    // Look for occurrences of "Some(<var_name>)" / "Ok(<var_name>)"
    // / "Err(<var_name>)". Identifier-aware: char before the first
    // letter must not be alpha/digit/underscore, and the closing `)`
    // must immediately follow var_name (no extra args).
    // bound to last 256 KB (user code region). Pattern
    // bindings live in user match arms; stdlib doesn't define them
    // in adopter-shape ways. 4x faster scan, no observed-correctness
    // change.
    let mut i: i64 = if slen > 262144 { slen - 262144 } else { 0 };
    while i + 6 < slen {
        let mut variant_len: i64 = 0;
        let mut variant: str = "";
        // "Some(" = 83,111,109,101,40
        if str_char_at(src, i) == 83 && str_char_at(src, i+1) == 111 && str_char_at(src, i+2) == 109 && str_char_at(src, i+3) == 101 && str_char_at(src, i+4) == 40 {
            variant = "Some"; variant_len = 5;
        };
        // "Ok(" = 79,107,40
        if variant_len == 0 && i + 3 < slen && str_char_at(src, i) == 79 && str_char_at(src, i+1) == 107 && str_char_at(src, i+2) == 40 {
            variant = "Ok"; variant_len = 3;
        };
        // "Err(" = 69,114,114,40
        if variant_len == 0 && i + 4 < slen && str_char_at(src, i) == 69 && str_char_at(src, i+1) == 114 && str_char_at(src, i+2) == 114 && str_char_at(src, i+3) == 40 {
            variant = "Err"; variant_len = 4;
        };
        if variant_len > 0 {
            // Boundary check: char before `Some/Ok/Err` must not be id-continue.
            let mut bdry_ok: i64 = 1;
            if i > 0 {
                let pc: i64 = str_char_at(src, i - 1);
                if (pc >= 65 && pc <= 90) || (pc >= 97 && pc <= 122) || (pc >= 48 && pc <= 57) || pc == 95 { bdry_ok = 0; };
            };
            if bdry_ok == 1 {
                let p: i64 = i + variant_len;
                // Match var_name immediately after `(`
                let mut k: i64 = 0;
                let mut nm_match: i64 = 1;
                while k < vlen {
                    if p + k >= slen || str_char_at(src, p + k) != str_char_at(var_name, k) { nm_match = 0; k = vlen; };
                    k = k + 1;
                };
                if nm_match == 1 {
                    // Must be followed immediately by `)` (so we know we
                    // matched the whole binding name, not a prefix of a
                    // longer one or a multi-arg pattern).
                    let after: i64 = p + vlen;
                    if after < slen && str_char_at(src, after) == 41 {
                        // Walk back to find the enclosing `match <expr> {`.
                        // Look for "match " keyword. This is a heuristic
                        // limited-by-design: if the source structure is
                        // weird (commented match, nested matches), we may
                        // pick the wrong scrutinee. False positives here
                        // produce a wrong type guess; the failure mode is
                        // a wrong format helper which prints differently
                        // than expected. Conservative bound: scan back
                        // at most 2KB; if no `match ` found, give up.
                        let scan_back_limit: i64 = if i > 2048 { i - 2048 } else { 0 };
                        let mut j: i64 = i - 1;
                        let mut match_at: i64 = 0 - 1;
                        while j >= scan_back_limit {
                            // "match " = 109,97,116,99,104,32
                            if j + 5 < slen && str_char_at(src, j) == 109 && str_char_at(src, j+1) == 97 && str_char_at(src, j+2) == 116 && str_char_at(src, j+3) == 99 && str_char_at(src, j+4) == 104 && str_char_at(src, j+5) == 32 {
                                // Boundary: char before `match` must not be id-continue.
                                let mut mb_ok: i64 = 1;
                                if j > 0 {
                                    let mpc: i64 = str_char_at(src, j - 1);
                                    if (mpc >= 65 && mpc <= 90) || (mpc >= 97 && mpc <= 122) || (mpc >= 48 && mpc <= 57) || mpc == 95 { mb_ok = 0; };
                                };
                                if mb_ok == 1 { match_at = j; j = scan_back_limit - 1; };
                            };
                            j = j - 1;
                        };
                        if match_at >= 0 {
                            // Read the scrutinee identifier after "match ".
                            let mut sp: i64 = match_at + 6;
                            // Skip whitespace.
                            while sp < slen && str_char_at(src, sp) == 32 { sp = sp + 1; };
                            // Read identifier (letters / digits / `_`). Field-access
                            // scrutinees (`x.alias`) are not handled in v1 -- bail.
                            let scrut_start: i64 = sp;
                            let mut scrut_end: i64 = sp;
                            let mut keep_scan: i64 = 1;
                            while keep_scan == 1 && scrut_end < slen {
                                let sc: i64 = str_char_at(src, scrut_end);
                                let id_cont: i64 = if (sc >= 65 && sc <= 90) || (sc >= 97 && sc <= 122) || (sc >= 48 && sc <= 57) || sc == 95 { 1 } else { 0 };
                                if id_cont == 1 { scrut_end = scrut_end + 1; }
                                else { keep_scan = 0; };
                            };
                            if scrut_end > scrut_start {
                                let scrut_name: str = str_substring(src, scrut_start, scrut_end);
                                // If next non-space char is `.`, this is field access -- bail
                                // (v1 doesn't handle struct-field scrutinees).
                                let mut tp: i64 = scrut_end;
                                while tp < slen && str_char_at(src, tp) == 32 { tp = tp + 1; };
                                // handle field-access scrutinee
                                // (`match s.gap_report { Some(g) => ... }`).
                                // Look up s's struct type, then walk the
                                // struct's field declarations to find
                                // gap_report's declared type. Single-level
                                // field access only (.a.b chains are deeper
                                // structural work; defer).
                                let mut scrut_full_type: str = "";
                                if tp < slen && str_char_at(src, tp) == 46 {
                                    let fp_start: i64 = tp + 1;
                                    let mut fp_end: i64 = fp_start;
                                    let mut fp_keep: i64 = 1;
                                    while fp_keep == 1 && fp_end < slen {
                                        let fc: i64 = str_char_at(src, fp_end);
                                        let fc_ok: i64 = if (fc >= 65 && fc <= 90) || (fc >= 97 && fc <= 122) || (fc >= 48 && fc <= 57) || fc == 95 { 1 } else { 0 };
                                        if fc_ok == 1 { fp_end = fp_end + 1; }
                                        else { fp_keep = 0; };
                                    };
                                    if fp_end > fp_start {
                                        let field_name: str = str_substring(src, fp_start, fp_end);
                                        // If next is another `.`, bail
                                        // (multi-level chain).
                                        let mut tp2: i64 = fp_end;
                                        while tp2 < slen && str_char_at(src, tp2) == 32 { tp2 = tp2 + 1; };
                                        if tp2 < slen && str_char_at(src, tp2) == 46 { return ""; };
                                        // try the bounded backward
                                        // scan first (handles common-name
                                        // conflicts in big bundles), then
                                        // fall back to global scan.
                                        let mut struct_full: str = infer_var_type_local_back(src, scrut_name, match_at);
                                        if str_len(struct_full) == 0 {
                                            struct_full = infer_var_type_from_source(src, scrut_name);
                                        };
                                        let struct_name: str = type_base_name(struct_full);
                                        if str_len(struct_name) > 0 {
                                            scrut_full_type = infer_struct_field_type_from_source(src, struct_name, field_name);
                                        };
                                    };
                                } else {
                                    // same bounded-then-global chain.
                                    scrut_full_type = infer_var_type_local_back(src, scrut_name, match_at);
                                    if str_len(scrut_full_type) == 0 {
                                        scrut_full_type = infer_var_type_from_source(src, scrut_name);
                                    };
                                };
                                if str_len(scrut_full_type) > 0 {
                                    // Extract generic parameter T from Option<T>
                                    // / Result<T, E>. We just want the FIRST type
                                    // parameter for Some/Ok, the SECOND for Err.
                                    let stl: i64 = str_len(scrut_full_type);
                                    let mut lt_at: i64 = 0 - 1;
                                    let mut sj: i64 = 0;
                                    while sj < stl {
                                        if str_char_at(scrut_full_type, sj) == 60 { lt_at = sj; sj = stl; };
                                        sj = sj + 1;
                                    };
                                    if lt_at >= 0 {
                                        let base: str = str_substring(scrut_full_type, 0, lt_at);
                                        let inside_start: i64 = lt_at + 1;
                                        let inside_end: i64 = if str_char_at(scrut_full_type, stl - 1) == 62 { stl - 1 } else { stl };
                                        let inside: str = str_substring(scrut_full_type, inside_start, inside_end);
                                        let mut candidate: str = "";
                                        if str_eq(base, "Option") == 1 && str_eq(variant, "Some") == 1 {
                                            candidate = type_base_name(inside);
                                        };
                                        if str_eq(base, "Result") == 1 {
                                            // Split inside on `,` to get T and E.
                                            let inlen: i64 = str_len(inside);
                                            let mut comma_at: i64 = 0 - 1;
                                            let mut depth_lt: i64 = 0;
                                            let mut ck: i64 = 0;
                                            while ck < inlen {
                                                let cc: i64 = str_char_at(inside, ck);
                                                if cc == 60 { depth_lt = depth_lt + 1; };
                                                if cc == 62 { depth_lt = depth_lt - 1; };
                                                if cc == 44 && depth_lt == 0 { comma_at = ck; ck = inlen; };
                                                ck = ck + 1;
                                            };
                                            if comma_at > 0 {
                                                let t_part_raw: str = str_substring(inside, 0, comma_at);
                                                let mut e_start: i64 = comma_at + 1;
                                                while e_start < inlen && str_char_at(inside, e_start) == 32 { e_start = e_start + 1; };
                                                let e_part_raw: str = str_substring(inside, e_start, inlen);
                                                if str_eq(variant, "Ok") == 1 { candidate = type_base_name(t_part_raw); };
                                                if str_eq(variant, "Err") == 1 { candidate = type_base_name(e_part_raw); };
                                            } else {
                                                if str_eq(variant, "Ok") == 1 { candidate = type_base_name(inside); };
                                            };
                                        };
                                        if str_len(candidate) > 0 {
                                            if str_len(found_type) == 0 { found_type = candidate; }
                                            else { if str_eq(found_type, candidate) == 0 { conflict = 1; }; };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

// companion to infer_var_type_from_source. Scans src for
// `fn <name>(...) -> TYPE` declarations and returns TYPE if every
// matching fn agrees. Same conflict-detection as the var version.
// Used by fmt_conversion_for_spec when arg_expr looks like a fn call
// (`<ident>(...)` shape) to dispatch the format type. Catches
// `println!("{}", make_str())` returning the pointer address pre-fix.
#[manual_drop]
fn infer_fn_return_type_from_source(src: str, fn_name: str) -> str {
    // same cached short-circuit as infer_var_type_from_source.
    let cached: str = infer_fn_return_type_cached(src, fn_name);
    if str_len(cached) > 0 { return cached; };
    let slen: i64 = str_len(src);
    let fnlen: i64 = str_len(fn_name);
    if fnlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    let mut i: i64 = 0;
    while i + 3 < slen {
        // "fn " = 'f','n',' ' = 102,110,32
        if str_char_at(src, i) == 102
            && str_char_at(src, i + 1) == 110
            && str_char_at(src, i + 2) == 32 {
            let mut p: i64 = i + 3;
            // Try to match fn_name
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < fnlen {
                if p + k >= slen { matched = 0; k = fnlen; }
                else if str_char_at(src, p + k) != str_char_at(fn_name, k) { matched = 0; k = fnlen; };
                k = k + 1;
            };
            // Identifier boundary: char after fn_name must not be alpha/digit/underscore
            if matched == 1 {
                let after: i64 = p + fnlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let after2: i64 = p + fnlen;
                let mut q: i64 = after2;
                // Skip whitespace then expect `(`
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                if q < slen && str_char_at(src, q) == 40 {
                    // Find matching `)` by depth
                    let mut depth: i64 = 1;
                    q = q + 1;
                    while q < slen && depth > 0 {
                        let dc: i64 = str_char_at(src, q);
                        if dc == 40 { depth = depth + 1; }
                        else if dc == 41 { depth = depth - 1; };
                        q = q + 1;
                    };
                    // Now look for ` -> TYPE`
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                    if q + 1 < slen && str_char_at(src, q) == 45 && str_char_at(src, q + 1) == 62 {
                        q = q + 2;
                        while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                        let ts: i64 = q;
                        while q < slen {
                            let tc: i64 = str_char_at(src, q);
                            if tc == 32 || tc == 123 || tc == 59 || tc == 60 || tc == 10 || tc == 13 {
                                let this_type: str = str_substring(src, ts, q);
                                if str_len(found_type) == 0 {
                                    found_type = this_type;
                                } else {
                                    if str_eq(found_type, this_type) == 0 {
                                        conflict = 1;
                                    };
                                };
                                q = slen;
                            };
                            q = q + 1;
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

#[manual_drop]
fn infer_var_type_from_source(src: str, var_name: str) -> str {
    // short-circuit to runtime cache. Pre-fix this
    // function re-walked the entire source for every println!/format
    // arg -- 1.26B str_char_at calls per compiler self-build. Cached
    // lookup is O(1) average; the cache is built once per source ptr.
    let cached: str = infer_var_type_cached(src, var_name);
    if str_len(cached) > 0 { return cached; };
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    let mut i: i64 = 0;
    while i + 4 < slen {
        // "let " = 'l','e','t',' ' = 108,101,116,32
        if str_char_at(src, i) == 108
            && str_char_at(src, i + 1) == 101
            && str_char_at(src, i + 2) == 116
            && str_char_at(src, i + 3) == 32 {
            let mut p: i64 = i + 4;
            // Skip optional "mut "
            if p + 4 < slen
                && str_char_at(src, p) == 109
                && str_char_at(src, p + 1) == 117
                && str_char_at(src, p + 2) == 116
                && str_char_at(src, p + 3) == 32 {
                p = p + 4;
            };
            // Try to match var_name
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < vlen {
                if p + k >= slen { matched = 0; k = vlen; }
                else if str_char_at(src, p + k) != str_char_at(var_name, k) { matched = 0; k = vlen; };
                k = k + 1;
            };
            // Also require the char after var_name to NOT be alpha/digit/underscore
            // -- so `foo` doesn't match `foobar`.
            if matched == 1 {
                let after: i64 = p + vlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let after2: i64 = p + vlen;
                let mut q: i64 = after2;
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                if q < slen && str_char_at(src, q) == 58 {
                    q = q + 1;
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                    let ts: i64 = q;
                    // track <> depth so `Vec<f64>` returns
                    // "Vec<f64>" (full type), not "Vec" truncated at `<`.
                    // Existing callers checking `str_eq(inferred, "f64")`
                    // etc. are unaffected -- a generic-bearing type
                    // still doesn't match a bare scalar name.
                    let mut gd: i64 = 0;
                    while q < slen {
                        let tc: i64 = str_char_at(src, q);
                        if tc == 60 { gd = gd + 1; q = q + 1; }
                        else if tc == 62 && gd > 0 { gd = gd - 1; q = q + 1; }
                        else if gd == 0 && (tc == 32 || tc == 61 || tc == 59 || tc == 44 || tc == 10 || tc == 13) {
                            let this_type: str = str_substring(src, ts, q);
                            if str_len(found_type) == 0 {
                                found_type = this_type;
                            } else {
                                if str_eq(found_type, this_type) == 0 {
                                    conflict = 1;
                                };
                            };
                            q = slen;
                        } else { q = q + 1; };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    if str_len(found_type) > 0 { return found_type; };
    // also check for for-loop bindings `for <var_name> in
    // <iter_expr>`. The element type is derived from the iter
    // expression: if iter_expr is `<ident>` or `<ident>.iter()`,
    // look up ident's type and strip the container layer.
    let mut i2: i64 = 0;
    while i2 + 4 < slen {
        // "for " = 'f','o','r',' ' = 102,111,114,32
        if str_char_at(src, i2) == 102
            && str_char_at(src, i2 + 1) == 111
            && str_char_at(src, i2 + 2) == 114
            && str_char_at(src, i2 + 3) == 32 {
            let mut p: i64 = i2 + 4;
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < vlen {
                if p + k >= slen { matched = 0; k = vlen; }
                else if str_char_at(src, p + k) != str_char_at(var_name, k) { matched = 0; k = vlen; };
                k = k + 1;
            };
            if matched == 1 {
                let after: i64 = p + vlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let mut q: i64 = p + vlen;
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                // expect "in "
                if q + 3 < slen
                    && str_char_at(src, q) == 105
                    && str_char_at(src, q + 1) == 110
                    && str_char_at(src, q + 2) == 32 {
                    q = q + 3;
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                    // Read iter expression up to '{' or '\n'
                    let iter_start: i64 = q;
                    while q < slen && str_char_at(src, q) != 123 && str_char_at(src, q) != 10 {
                        q = q + 1;
                    };
                    let iter_end: i64 = q;
                    let iter_expr: str = strip_spaces(str_substring(src, iter_start, iter_end));
                    // Strip trailing `.iter()` / `.into_iter()` / `.iter_mut()` if present.
                    let ielen: i64 = str_len(iter_expr);
                    let mut base_iter: str = iter_expr;
                    if ielen >= 7 && str_eq(str_substring(iter_expr, ielen - 7, ielen), ".iter()") == 1 {
                        base_iter = str_substring(iter_expr, 0, ielen - 7);
                    };
                    let belen: i64 = str_len(base_iter);
                    if belen >= 12 && str_eq(str_substring(base_iter, belen - 12, belen), ".into_iter()") == 1 {
                        base_iter = str_substring(base_iter, 0, belen - 12);
                    };
                    // Look up the receiver's full type via recursive call.
                    let recv_full: str = infer_var_type_from_source(src, base_iter);
                    if str_len(recv_full) > 0 {
                        let stripped: str = strip_container_one_level(recv_full);
                        if str_len(stripped) > 0 { return stripped; };
                    };
                };
            };
        };
        i2 = i2 + 1;
    };
    return "";
}

// companion to infer_var_type_from_source. Scans src for
// `struct STRUCT_NAME { ... field: TYPE, ... }` declarations and
// returns TYPE (with container generics intact) for the named
// field, "" if not found or conflict. Used by
// fmt_conversion_for_spec to dispatch println!("{}", p.field) for
// any field type. Conflict-detection mirrors the var/fn helpers.
#[manual_drop]
fn infer_struct_field_type_from_source(src: str, struct_name: str, field_name: str) -> str {
    let slen: i64 = str_len(src);
    let snlen: i64 = str_len(struct_name);
    let fnlen: i64 = str_len(field_name);
    if snlen == 0 || fnlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    let mut i: i64 = 0;
    while i + 7 < slen {
        // "struct " = 's','t','r','u','c','t',' ' = 115,116,114,117,99,116,32
        if str_char_at(src, i) == 115
            && str_char_at(src, i + 1) == 116
            && str_char_at(src, i + 2) == 114
            && str_char_at(src, i + 3) == 117
            && str_char_at(src, i + 4) == 99
            && str_char_at(src, i + 5) == 116
            && str_char_at(src, i + 6) == 32 {
            let mut p: i64 = i + 7;
            // Try to match struct_name
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < snlen {
                if p + k >= slen { matched = 0; k = snlen; }
                else if str_char_at(src, p + k) != str_char_at(struct_name, k) { matched = 0; k = snlen; };
                k = k + 1;
            };
            // Identifier boundary
            if matched == 1 {
                let after: i64 = p + snlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let after2: i64 = p + snlen;
                let mut q: i64 = after2;
                // Skip whitespace, optional generics, then expect `{`
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                // Skip generic params if any: `<...>` -- one nesting level
                if q < slen && str_char_at(src, q) == 60 {
                    let mut gd: i64 = 1; q = q + 1;
                    while q < slen && gd > 0 {
                        let gc: i64 = str_char_at(src, q);
                        if gc == 60 { gd = gd + 1; } else if gc == 62 { gd = gd - 1; };
                        q = q + 1;
                    };
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                };
                if q < slen && str_char_at(src, q) == 123 {
                    q = q + 1;
                    // Find matching `}` for the struct body
                    let body_start: i64 = q;
                    let mut bdepth: i64 = 1;
                    while q < slen && bdepth > 0 {
                        let bc: i64 = str_char_at(src, q);
                        if bc == 123 { bdepth = bdepth + 1; }
                        else if bc == 125 { bdepth = bdepth - 1; };
                        if bdepth > 0 { q = q + 1; };
                    };
                    let body_end: i64 = q;
                    // Scan body for `field_name : TYPE,` (allow whitespace)
                    let mut bp: i64 = body_start;
                    while bp + fnlen < body_end {
                        // Find start of identifier token: previous char is whitespace/comma/{
                        let prev_c: i64 = if bp == 0 { 32 } else { str_char_at(src, bp - 1) };
                        let prev_ok: i64 = if prev_c == 32 || prev_c == 9 || prev_c == 10 || prev_c == 13 || prev_c == 44 || prev_c == 123 { 1 } else { 0 };
                        if prev_ok == 1 {
                            let mut fmatched: i64 = 1;
                            let mut fk: i64 = 0;
                            while fk < fnlen {
                                if bp + fk >= body_end { fmatched = 0; fk = fnlen; }
                                else if str_char_at(src, bp + fk) != str_char_at(field_name, fk) { fmatched = 0; fk = fnlen; };
                                fk = fk + 1;
                            };
                            if fmatched == 1 {
                                let after_field: i64 = bp + fnlen;
                                if after_field < body_end {
                                    let nc2: i64 = str_char_at(src, after_field);
                                    let is_id_continue2: i64 = if (nc2 >= 65 && nc2 <= 90) || (nc2 >= 97 && nc2 <= 122) || (nc2 >= 48 && nc2 <= 57) || nc2 == 95 { 1 } else { 0 };
                                    if is_id_continue2 == 1 { fmatched = 0; };
                                };
                            };
                            if fmatched == 1 {
                                let mut fq: i64 = bp + fnlen;
                                while fq < body_end && str_char_at(src, fq) == 32 { fq = fq + 1; };
                                if fq < body_end && str_char_at(src, fq) == 58 {
                                    fq = fq + 1;
                                    while fq < body_end && str_char_at(src, fq) == 32 { fq = fq + 1; };
                                    let fts: i64 = fq;
                                    while fq < body_end {
                                        let ftc: i64 = str_char_at(src, fq);
                                        if ftc == 44 || ftc == 32 || ftc == 10 || ftc == 13 || ftc == 125 {
                                            let this_type: str = str_substring(src, fts, fq);
                                            if str_len(found_type) == 0 {
                                                found_type = this_type;
                                            } else {
                                                if str_eq(found_type, this_type) == 0 { conflict = 1; };
                                            };
                                            fq = body_end;
                                        };
                                        fq = fq + 1;
                                    };
                                };
                            };
                        };
                        bp = bp + 1;
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}




// nested format!() recursion needs the OUTER source for
// type inference, even when expanding a substring (`args_text`).
// Previously the recursive call passed args_text as both the text
// to process AND the type-inference src -- so an inner Format
// like `format!("nested:{}", inner_str)` couldn't find the
// `let inner_str: str = ...` declaration that lives in the outer
// scope, dispatched as int_to_str default, and printed the str
// pointer.

// ===== T1.5c (v0.2.342): resolver-layer name privatization =====
// Opt-in cross-module visibility enforcement. When the resolver
// inlines an imported file F, we scan F for `pub fn` declarations.
// If F has at least one `pub fn`, we identify all NON-pub `fn`
// declarations in F and rewrite their identifier occurrences within
// F's source to `__priv_<file_id>__<name>`. Cross-module callers
// (whose source is NOT rewritten) then find no symbol for the
// private name and fail with an unresolved-name error — which is
// exactly the behavior `pub` is supposed to gate.
// Files with ZERO `pub fn` declarations get NO rewriting (opt-out
// for back-compat with pre-T1.5 rod files that have no `pub`
// markers but whose fns are de-facto callable from any importer).
// The token rewriter is identifier-aware: it skips string literals,
// char literals, and `// ...` line comments, and it does NOT rewrite
// identifiers preceded by `.` (field/method access). Everything else
// is conservative — keywords and shadowed locals are not in the
// private_names list so they're never substituted.









#[manual_drop]
fn lift_undefined_fn_link_errors(clang_output: str, reg: Vec<i32>) -> i64 {
    // companion to priv_lift_link_errors. After MOD-003 has
    // claimed every privatization-related undefined symbol, this fn
    // scans the clang output for any REMAINING `use of undefined
    // value '@<name>'` matches and emits a clean TYP-005 error
    // for each true-undefined fn (typo, missing import, etc.).
    // Pre-fix v0.4.60 emitted TYP-005 at WARNING tier at type-check
    // time, then let clang fail with its cryptic
    //   target/foo.ll:850:23: error: use of undefined value '@bar'
    // line, leaving the user reading clang IR diagnostics. Now the
    // user gets a single readable line:
    //   error[TYP-005]: undefined function `bar()`. Check spelling
    //   or import the rod that defines it.
    // Skips compiler-generated names (`__closure_*`, `__vec_*`,
    // privatization-mangled `__priv_*`, etc.) and uppercase-leading
    // names (Type-prefixed variants — those go through their own
    // unresolved-type diagnostic path). Returns count emitted so
    // the caller can decide whether to suppress the raw clang dump.
    let needle: str = "use of undefined value '@";
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(clang_output);
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    let mut seen: Vec<i32> = Vec::new();
    while p + nlen <= slen {
        let mut matched: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && matched == 1 {
            if str_char_at(clang_output, p + k) != str_char_at(needle, k) { matched = 0; };
            k = k + 1;
        };
        if matched == 1 {
            let name_start: i64 = p + nlen;
            let mut name_end: i64 = name_start;
            while name_end < slen && str_char_at(clang_output, name_end) != 39 { name_end = name_end + 1; };
            let name: str = str_substring(clang_output, name_start, name_end);
            // Skip if MOD-003 already claimed it.
            let claimed_by_mod003: i64 = if str_len(priv_lookup_origin(reg, name)) > 0 { 1 } else { 0 };
            // Skip compiler-generated names (same filters as the
            // type-check warn path in type_expr kind 7).
            let clen: i64 = str_len(name);
            let mut suppress: i64 = 0;
            if claimed_by_mod003 == 1 { suppress = 1; };
            if suppress == 0 && clen >= 2 && str_char_at(name, 0) == 95 && str_char_at(name, 1) == 95 {
                suppress = 1;
            };
            if suppress == 0 && clen >= 1 {
                let c0: i64 = str_char_at(name, 0);
                if c0 >= 65 && c0 <= 90 { suppress = 1; };
            };
            if suppress == 0 && priv_string_vec_contains(seen, name) == 0 {
                seen.push(name);
                // detect synthetic `vec_<method>` names that
                // come from method-call dispatch fall-through (e.g.
                // user wrote `v.lenn()` for a Vec, the kind 8 catch-all
                // lowered to `vec_lenn(v)`). Show the user the actual
                // source-side method name with a Vec-method hint
                // instead of the confusing internal `vec_<method>`.
                if clen > 4 && str_char_at(name, 0) == 118
                    && str_char_at(name, 1) == 101
                    && str_char_at(name, 2) == 99
                    && str_char_at(name, 3) == 95 {
                    let user_method: str = str_substring(name, 4, clen);
                    //  if the user wrote fn-form
                    // `vec_<method>(&v, …)` AND `<method>` is one of the
                    // supported Vec method families, the existing diag
                    // misled — it said `no method .<method>()` even though
                    // the method DOES exist via the proper dispatch path.
                    // Detect the supported-method case and emit a fn-form-
                    // vs-method-form diag instead. The unsupported-method
                    // case still gets the original "no method" diag.
                    let mut um_supported: i64 = 0;
                    if str_eq(user_method, "contains") == 1 || str_eq(user_method, "push") == 1
                        || str_eq(user_method, "pop") == 1 || str_eq(user_method, "len") == 1
                        || str_eq(user_method, "get") == 1 || str_eq(user_method, "set") == 1
                        || str_eq(user_method, "first") == 1 || str_eq(user_method, "last") == 1
                        || str_eq(user_method, "is_empty") == 1 || str_eq(user_method, "insert_at") == 1
                        || str_eq(user_method, "remove_at") == 1 || str_eq(user_method, "iter") == 1
                        || str_eq(user_method, "map") == 1 || str_eq(user_method, "filter") == 1
                        || str_eq(user_method, "fold") == 1 || str_eq(user_method, "each") == 1
                        || str_eq(user_method, "sum") == 1 || str_eq(user_method, "min") == 1
                        || str_eq(user_method, "max") == 1 || str_eq(user_method, "index_of") == 1
                        || str_eq(user_method, "reverse") == 1 || str_eq(user_method, "sort") == 1
                        || str_eq(user_method, "clone") == 1 || str_eq(user_method, "clear") == 1 {
                        um_supported = 1;
                    };
                    if um_supported == 1 {
                        print(str_concat("error[TYP-005]: `vec_", str_concat(user_method, "(...)` is not a top-level fn — use the method form `vec.", str_concat(user_method, "(&value)` instead. The method-dispatch path resolves to the correct type-specific runtime helper (e.g. `__nucleor_vec_", str_concat(user_method, "_i64` for `Vec<i64>`); the bare fn-form bypasses that dispatch.")))));
                        print(str_concat("                Pre-v0.6.40 the diag said `no method .", str_concat(user_method, "()`, which was misleading — the method exists, only the fn-form does not.")));
                    } else {
                        print(str_concat("error[TYP-005]: receiver type `Vec<T>` has no method `.", str_concat(user_method, "()`. (Internal symbol: `vec_")));
                        print(str_concat("                ", str_concat(user_method, "`. The kind-8 method-dispatch catch-all lowered the call to a synthetic helper that doesn't exist.)")));
                        print("                Supported Vec method families: push, pop, len, get, set, first, last, is_empty, insert (insert_at), remove (remove_at), iter, map, filter, fold, each, sum, min, max, contains, index_of, reverse, sort, clone, clear, collect, count, take, skip, any, all, chain, position, product, step_by, nth, reduce.");
                    };
                } else {
                    // Lane 3 (F-DIAG-011): the pre-fix message tail
                    // claimed "type-checker emitted a TYP-005 warning
                    // earlier in this build" — false in v1.0 (the
                    // type-checker has no undefined-callee diagnostic;
                    // the only TYP-005 emit for unbound idents was
                    // this link-stage one, see F-DIAG-016). Drop the
                    // misleading parenthetical until the type-checker
                    // pre-link emit is wired (F-DIAG-016 owner).
                    print(str_concat("error[TYP-005]: undefined function `", str_concat(name, "()`. Check spelling, or import the rod that defines it. (raised at clang link.)")));
                };
                count = count + 1;
            };
            p = name_end + 1;
        } else {
            p = p + 1;
        };
    };
    return count;
}

#[manual_drop]
fn lift_no_main_link_error(clang_output: str) -> i64 {
    // companion to lift_undefined_fn_link_errors. Catches
    // the no-main-fn link error class. Pre-fix a `.nr` file with no
    // `fn main` failed at clang link with the cryptic Windows
    // `LINK : fatal error LNK1561: entry point must be defined` /
    // POSIX `undefined reference to ...main` lines that adopters
    // had to know meant "your program has no entry point". Emits a
    // single readable NR022 error before suppressing the raw clang
    // dump. Returns 1 if it lifted, 0 otherwise.
    let win_marker: str = "LNK1561";
    let win_marker_lld: str = "subsystem must be defined";
    let posix_marker_a: str = "undefined reference to `main'";
    let posix_marker_b: str = "undefined reference to `_main'";
    let posix_marker_c: str = "Undefined symbols for architecture";
    let mut hit: i64 = 0;
    if str_contains(clang_output, win_marker) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, win_marker_lld) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, posix_marker_a) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, posix_marker_b) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, posix_marker_c) == 1 && str_contains(clang_output, "_main") == 1 { hit = 1; };
    if hit == 0 { return 0; };
    print("error[NR022]: no `fn main()` defined in this build unit. Nucleor expects every binary build to have a `fn main() -> i32` entry point. Either add one (`fn main() -> i32 { 0 }`), or build the file as part of a larger program that already has main, or use `nuc check` if you only want to type-check without linking.");
    return 1;
}











#[manual_drop]
fn core_shell_quote(path: str) -> str {
    return str_concat("\"", str_concat(path, "\""));
}
#[manual_drop]
fn run_external_tool(argc: i64) -> i64 {
    let raw_exe_dir: str = trim_trailing_sep(extract_dir(posix_drive_to_windows(args_get(0))));
    let mut exe_dir: str = raw_exe_dir;
    if str_len(exe_dir) == 0 { exe_dir = "target"; };
    let tool_name: str = str_concat("nucleor_tools", host_exe_suffix());
    let tool_path: str = host_shell_path(sanitize(str_concat(str_concat(exe_dir, host_target_path_sep()), tool_name)));
    let repo_tool_path: str = host_shell_path(str_concat(str_concat(".\\target", host_target_path_sep()), tool_name));
    let repo_bin_tool_path: str = host_shell_path(str_concat(str_concat(".\\bin", host_target_path_sep()), tool_name));
    // prefix local fallback with `.\` (Windows) / `./` (POSIX)
    // so cmd.exe / sh resolve unambiguously against the current dir even
    // when the file isn't on PATH. Pre-fix on Windows, the bare quoted
    // `"nucleor_tools.exe"` failed cmd.exe's command-search and the
    // sandbox-local CLI smokes (nuc test/lock/doc) cmd.exe-error'd with
    // `'"nucleor_tools.exe"' is not recognized`.
    let local_tool_path: str = host_shell_path(str_concat(if host_is_windows() == 1 { ".\\" } else { "./" }, tool_name));
    let mut tool_args: str = "";
    let mut i: i64 = 1;
    while i < argc {
        tool_args = str_concat(tool_args, str_concat(" ", core_shell_quote(args_get(i))));
        i = i + 1;
    };
    let mut selected: str = tool_path;
    if fs_exists(repo_tool_path) == 1 { selected = repo_tool_path; }
    else if fs_exists(repo_bin_tool_path) == 1 { selected = repo_bin_tool_path; }
    else if fs_exists(local_tool_path) == 1 { selected = local_tool_path; };
    if fs_exists(selected) == 0 {
        print(str_concat("ERROR: cannot find required tools-suite binary: ", tool_name));
        print("       rebuild with: nuc build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache");
        return 1;
    };
    let selected_cmd: str = core_shell_quote(selected);
    let cmd: str = if host_is_windows() == 1 {
        let cwd_shell: str = host_shell_path(posix_drive_to_windows(getcwd()));
        str_concat("pushd ", str_concat(core_shell_quote(cwd_shell), str_concat(" && ", str_concat(selected_cmd, tool_args))))
    } else {
        str_concat(selected_cmd, tool_args)
    };
    return system(cmd);
}

#[manual_drop]
fn run_build_shared_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_fix_command(argc: i64) -> i64 { return run_external_tool(argc); }

// tools registry subcommand. Distinct from
// `nuc install` (which is RFC-0019 phase-4 package management for
// stdlib rods). `nuc tools install <url>` downloads a published
// Nucleor-distributed tool binary, extracts it under $NUC_HOME/tools/
// <name>/, and writes a shim script in $NUC_HOME/bin/.
// v1 minimal scope:
//   nuc tools install <github_release_url>  [--no-verify]
//   nuc tools uninstall <name>
//   nuc tools list
//   nuc tools home          (print resolved $NUC_HOME for diagnostics)
// Direct-URL install (no central registry yet -- that's v2). Cosign
// verify is opt-in for v1; required-by-default once we publish a
// registry. Network ops shell out to curl (ubiquitous on Windows
// since 1803 and on every Unix). Extraction shells out to tar (for
// .tar.gz) or PowerShell Expand-Archive (for .zip on Windows).
#[manual_drop]
fn nuc_home_path() -> str {
    let explicit: str = env_get_or("NUC_HOME", "");
    if str_len(explicit) > 0 { return explicit; };
    // Windows: %LOCALAPPDATA%\Nucleor
    let lad: str = env_get_or("LOCALAPPDATA", "");
    if str_len(lad) > 0 { return str_concat(lad, "\\Nucleor"); };
    // Unix: $HOME/.nucleor
    let home: str = env_get_or("HOME", "");
    if str_len(home) > 0 { return str_concat(home, "/.nucleor"); };
    // Last-resort fallback
    return ".nucleor";
}

#[manual_drop]
fn tools_home() -> str {
    let h: str = nuc_home_path();
    return str_concat(h, "/tools");
}

#[manual_drop]
fn tools_bin() -> str {
    let h: str = nuc_home_path();
    return str_concat(h, "/bin");
}

#[manual_drop]
fn tools_basename_from_url(url: str) -> str {
    // Strip everything from the first ? or # onward (URL query/fragment).
    let mut end: i64 = str_len(url);
    let mut q: i64 = 0;
    while q < end {
        let c: i64 = str_char_at(url, q);
        if c == 63 || c == 35 { end = q; q = end; };
        q = q + 1;
    };
    // Walk backward from `end` to find the last `/` or `\` -- the basename
    // starts at the next char after that separator (or at 0 if none).
    let mut start: i64 = 0;
    let mut k: i64 = end - 1;
    while k >= 0 {
        let c: i64 = str_char_at(url, k);
        if c == 47 || c == 92 { start = k + 1; k = 0 - 1; };
        k = k - 1;
    };
    let raw: str = str_substring(url, start, end);
    // Strip common archive suffixes (longest match first).
    if str_ends_with(raw, ".tar.gz") == 1 { return str_substring(raw, 0, str_len(raw) - 7); };
    if str_ends_with(raw, ".tgz") == 1 { return str_substring(raw, 0, str_len(raw) - 4); };
    if str_ends_with(raw, ".zip") == 1 { return str_substring(raw, 0, str_len(raw) - 4); };
    if str_ends_with(raw, ".exe") == 1 { return str_substring(raw, 0, str_len(raw) - 4); };
    return raw;
}

#[manual_drop]
fn tools_print_help() -> i64 {
    print("Usage: nuc tools <subcommand>");
    print("");
    print("Subcommands:");
    print("  install <url> [--no-verify]   Download + extract a tool from a release URL");
    print("  uninstall <name>              Remove an installed tool");
    print("  list                          List installed tools");
    print("  home                          Print resolved $NUC_HOME");
    print("");
    print("Tools install under $NUC_HOME/tools/<name>/ and a shim is written to");
    print("$NUC_HOME/bin/<name>.cmd (Windows) or $NUC_HOME/bin/<name> (Unix).");
    print("Add $NUC_HOME/bin to PATH once and any tool installed via this command");
    print("becomes invokable as <name> in any shell.");
    print("");
    print("Default $NUC_HOME: %LOCALAPPDATA%\\Nucleor (Windows) or $HOME/.nucleor (Unix).");
    print("Override via the NUC_HOME env var.");
    return 0;
}

#[manual_drop]
fn tools_install(url: str, verify: i64) -> i64 {
    if str_len(url) == 0 {
        print("ERROR: nuc tools install requires a URL");
        return 1;
    };
    let name: str = tools_basename_from_url(url);
    if str_len(name) == 0 {
        print(str_concat("ERROR: cannot derive a tool name from URL: ", url));
        return 1;
    };
    let home: str = nuc_home_path();
    let tdir: str = str_concat(tools_home(), str_concat("/", name));
    let bdir: str = tools_bin();
    print(str_concat("nuc tools install: name = ", name));
    print(str_concat("                   url  = ", url));
    print(str_concat("                   dest = ", tdir));
    // Make dirs (mkdir -p style; use Windows-compatible commands).
    system(str_concat("powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '", str_concat(tdir, "' | Out-Null\"")));
    system(str_concat("powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '", str_concat(bdir, "' | Out-Null\"")));
    // Download via curl. curl is bundled with Windows 1803+ and every Unix.
    let archive: str = str_concat(tdir, "/.download");
    let curl_cmd: str = str_concat("curl -fsSL -o \"", str_concat(archive, str_concat("\" \"", str_concat(url, "\""))));
    print(str_concat("  fetching: curl -fsSL ", url));
    let dl_rc: i64 = system(curl_cmd);
    if dl_rc != 0 {
        print(str_concat("ERROR: download failed (curl rc=", str_concat(str_from_int(dl_rc), ")")));
        return 1;
    };
    if verify == 1 {
        // v1: cosign optional. If cosign is on PATH, run it; if not, warn.
        print("  verifying: cosign verify-blob (production releases must add this)");
        print("  NOTE: v1 of `nuc tools install` is opt-in cosign. Skipping verify for now.");
        print("        See RFC-NRT-002 for the v2 mandatory-verify roadmap.");
    } else {
        print("  verifying: SKIPPED (--no-verify)");
    };
    // Extract: detect by suffix.
    if str_ends_with(url, ".zip") == 1 {
        print(str_concat("  extracting: Expand-Archive -> ", tdir));
        let ext_cmd: str = str_concat("powershell -NoProfile -Command \"Expand-Archive -Path '", str_concat(archive, str_concat("' -DestinationPath '", str_concat(tdir, "' -Force\""))));
        let ext_rc: i64 = system(ext_cmd);
        if ext_rc != 0 {
            print(str_concat("ERROR: extraction failed (rc=", str_concat(str_from_int(ext_rc), ")")));
            return 1;
        };
    } else {
        if str_ends_with(url, ".tar.gz") == 1 || str_ends_with(url, ".tgz") == 1 {
            print(str_concat("  extracting: tar -xzf -> ", tdir));
            let ext_cmd: str = str_concat("tar -xzf \"", str_concat(archive, str_concat("\" -C \"", str_concat(tdir, "\""))));
            let ext_rc: i64 = system(ext_cmd);
            if ext_rc != 0 {
                print(str_concat("ERROR: extraction failed (rc=", str_concat(str_from_int(ext_rc), ")")));
                return 1;
            };
        } else {
            // Single-file binary install (e.g., .exe). Move into place.
            print(str_concat("  installing: single-file binary -> ", tdir));
            let mv_cmd: str = str_concat("powershell -NoProfile -Command \"Move-Item -Force -Path '", str_concat(archive, str_concat("' -Destination '", str_concat(tdir, str_concat("/", str_concat(name, ".exe' \""))))));
            let mv_rc: i64 = system(mv_cmd);
            if mv_rc != 0 {
                print(str_concat("ERROR: install failed (rc=", str_concat(str_from_int(mv_rc), ")")));
                return 1;
            };
        };
    };
    // Write shim. Look for <name>.exe first under the tdir; fallback to plain <name>.
    let target_exe: str = str_concat(tdir, str_concat("/", str_concat(name, ".exe")));
    let target_bin: str = str_concat(tdir, str_concat("/", name));
    let mut shim_target: str = "";
    if str_len(file_read_string(target_exe)) > 0 || str_ends_with(url, ".exe") == 1 {
        shim_target = target_exe;
    } else {
        shim_target = target_bin;
    };
    let shim_path: str = str_concat(bdir, str_concat("/", str_concat(name, ".cmd")));
    let shim_body: str = str_concat("@echo off\r\n\"", str_concat(shim_target, "\" %*\r\n"));
    let wr_rc: i64 = file_write_string(shim_path, shim_body);
    if wr_rc < 0 {
        print(str_concat("ERROR: failed to write shim at ", shim_path));
        return 1;
    };
    print(str_concat("  shim:   ", shim_path));
    print(str_concat("  target: ", shim_target));
    print("");
    print(str_concat("Installed `", str_concat(name, "`.")));
    print(str_concat("Add `", str_concat(bdir, "` to PATH (once) and run `", str_concat(name, " --version` from any shell."))));
    return 0;
}

#[manual_drop]
fn tools_uninstall(name: str) -> i64 {
    if str_len(name) == 0 {
        print("ERROR: nuc tools uninstall requires a tool name");
        return 1;
    };
    let tdir: str = str_concat(tools_home(), str_concat("/", name));
    let shim: str = str_concat(tools_bin(), str_concat("/", str_concat(name, ".cmd")));
    print(str_concat("nuc tools uninstall: ", name));
    print(str_concat("  removing: ", tdir));
    system(str_concat("powershell -NoProfile -Command \"Remove-Item -Recurse -Force -Path '", str_concat(tdir, "' -ErrorAction SilentlyContinue\"")));
    print(str_concat("  removing: ", shim));
    system(str_concat("powershell -NoProfile -Command \"Remove-Item -Force -Path '", str_concat(shim, "' -ErrorAction SilentlyContinue\"")));
    print(str_concat("Uninstalled `", str_concat(name, "`.")));
    return 0;
}

#[manual_drop]
fn tools_list() -> i64 {
    let tdir: str = tools_home();
    print(str_concat("Tools installed under ", tdir));
    // PowerShell list: any subdirectory under tools/.
    let cmd: str = str_concat("powershell -NoProfile -Command \"if (Test-Path '", str_concat(tdir, "') { Get-ChildItem -Directory '"));
    let cmd2: str = str_concat(cmd, str_concat(tdir, "' | ForEach-Object { '  ' + $_.Name } } else { '  (none -- tools home does not exist yet)' }\""));
    system(cmd2);
    return 0;
}

#[manual_drop]
fn run_tools_command(argc: i64) -> i64 {
    if argc < 3 {
        return tools_print_help();
    };
    let sub: str = args_get(2);
    if str_eq(sub, "help") || str_eq(sub, "--help") || str_eq(sub, "-h") {
        return tools_print_help();
    };
    if str_eq(sub, "home") {
        print(nuc_home_path());
        return 0;
    };
    if str_eq(sub, "list") {
        return tools_list();
    };
    if str_eq(sub, "uninstall") {
        if argc < 4 {
            print("ERROR: nuc tools uninstall requires a tool name");
            return 1;
        };
        return tools_uninstall(args_get(3));
    };
    if str_eq(sub, "install") {
        if argc < 4 {
            print("ERROR: nuc tools install requires a URL");
            return 1;
        };
        let url: str = args_get(3);
        let mut verify: i64 = 1;
        let mut i: i64 = 4;
        while i < argc {
            if str_eq(args_get(i), "--no-verify") == 1 { verify = 0; };
            i = i + 1;
        };
        return tools_install(url, verify);
    };
    print(str_concat("ERROR: unknown nuc tools subcommand: ", sub));
    return tools_print_help();
}
#[manual_drop]
fn run_doc_command(argc: i64) -> i64 { return run_external_tool(argc); }

// T1.1 Phase 9: map a Nucleor type name to its C equivalent for
// header generation. Returns "" for types without a clear C
// mapping (caller skips those extern decls).
#[manual_drop]
fn nr_type_to_c(t: str) -> str {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 { return "int8_t"; };
    if str_eq(b, "i16") == 1 { return "int16_t"; };
    if str_eq(b, "i32") == 1 { return "int32_t"; };
    if str_eq(b, "i64") == 1 { return "int64_t"; };
    if str_eq(b, "isize") == 1 { return "intptr_t"; };
    if str_eq(b, "u8") == 1 { return "uint8_t"; };
    if str_eq(b, "u16") == 1 { return "uint16_t"; };
    if str_eq(b, "u32") == 1 { return "uint32_t"; };
    if str_eq(b, "u64") == 1 { return "uint64_t"; };
    if str_eq(b, "usize") == 1 { return "uintptr_t"; };
    if str_eq(b, "f32") == 1 { return "float"; };
    if str_eq(b, "f64") == 1 { return "double"; };
    if str_eq(b, "bool") == 1 { return "bool"; };
    if str_eq(b, "char") == 1 { return "uint32_t"; };
    if str_eq(b, "ptr") == 1 { return "void*"; };
    if str_eq(b, "str") == 1 { return "const char*"; };
    if str_eq(b, "void") == 1 { return "void"; };
    return "";
}

#[manual_drop]
fn nr_type_to_c_with_structs(t: str, repr_c_structs: Vec<i32>) -> str {
    // T1.6 (v0.2.345): C ABI struct-by-value support. If the type
    // name matches a known #[repr(C)] struct, emit the struct name
    // directly so callers get the typedef; otherwise fall through to
    // the primitive table. Returns "" for non-repr(C) struct names
    // (caller emits CXX-004 — types crossing the bridge must have a
    // C-stable layout).
    let primitive: str = nr_type_to_c(t);
    if str_len(primitive) > 0 { return primitive; };
    let b: str = type_base_name(t);
    let n: i64 = vec_len(repr_c_structs);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(repr_c_structs, i), b) == 1 { return b; };
        i = i + 1;
    };
    return "";
}

#[manual_drop]
fn collect_repr_c_structs(src: str) -> Vec<i32> {
    // T1.6 (v0.2.345): walk the source text identifying every
    // struct declaration whose IMMEDIATELY-preceding non-blank
    // line (skipping doc-comments and whitespace) is exactly
    // `#[repr(C)]`. Strict line-precedence rules out the
    // lookback false-positive in `struct_repr`, where a 200-char
    // window happily picked up the previous struct's attribute.
    // Returns a Vec<str> of struct names (no duplicates).
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    // Pre-pass: build line offsets so we can look at the previous
    // non-blank line cheaply.
    let mut line_starts: Vec<i32> = Vec::new();
    line_starts.push(0);
    let mut s: i64 = 0;
    while s < slen {
        if str_char_at(src, s) == 10 && s + 1 < slen { line_starts.push(s + 1); };
        s = s + 1;
    };
    let nlines: i64 = vec_len(line_starts);
    let mut li: i64 = 0;
    while li < nlines {
        let p: i64 = vec_get(line_starts, li);
        let next_p: i64 = if li + 1 < nlines { vec_get(line_starts, li + 1) - 1 } else { slen };
        let mut eol: i64 = if next_p < slen { next_p } else { slen };
        // strip trailing CR if present (CRLF tolerant)
        if eol > p && str_char_at(src, eol - 1) == 13 { eol = eol - 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        // Match `struct NAME` (optionally `pub struct NAME`)
        let mut after_kw: i64 = 0 - 1;
        if lp + 7 <= llen && str_eq_at(line, lp, "struct ") == 1 { after_kw = lp + 7; };
        if after_kw < 0 && lp + 11 <= llen && str_eq_at(line, lp, "pub struct ") == 1 { after_kw = lp + 11; };
        if after_kw >= 0 {
            let name_start: i64 = after_kw;
            let mut q: i64 = name_start;
            while q < llen && (is_alnum(str_char_at(line, q)) == 1 || str_char_at(line, q) == 95) { q = q + 1; };
            if q > name_start {
                let name: str = str_substring(line, name_start, q);
                // Look back at preceding non-blank, non-/// lines
                // until we either find an attribute or hit something
                // that decisively isn't an attribute (struct decl,
                // closing brace, source start).
                let mut prev_li: i64 = li - 1;
                let mut found: i64 = 0;
                while prev_li >= 0 && found == 0 {
                    let pp: i64 = vec_get(line_starts, prev_li);
                    let mut pend: i64 = if prev_li + 1 < nlines { vec_get(line_starts, prev_li + 1) - 1 } else { slen };
                    if pend > pp && str_char_at(src, pend - 1) == 13 { pend = pend - 1; };
                    let pline: str = str_substring(src, pp, pend);
                    let trimmed: str = strip_spaces(pline);
                    if str_len(trimmed) == 0 {
                        prev_li = prev_li - 1;
                    } else if str_len(trimmed) >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                        prev_li = prev_li - 1;
                    } else if str_eq(trimmed, "#[repr(C)]") == 1 {
                        found = 1;
                    } else {
                        // Anything else terminates the lookback —
                        // attribute didn't apply to this struct.
                        prev_li = 0 - 1;
                    };
                };
                if found == 1 {
                    let mut already: i64 = 0;
                    let mut k: i64 = 0;
                    while k < vec_len(out) {
                        if str_eq(vec_get(out, k), name) == 1 { already = 1; };
                        k = k + 1;
                    };
                    if already == 0 { out.push(name); };
                };
            };
        };
        li = li + 1;
    };
    return out;
}

#[manual_drop]
fn extract_struct_fields_native(src: str, struct_name: str) -> Vec<i32> {
    // T1.6 (v0.2.345): pull the field list of a struct as alternating
    // [name1, type1, name2, type2, ...]. Uses brace-balanced source
    // scanning starting at the `struct NAME {` declaration. Returns
    // empty Vec if the struct is missing or syntactically malformed.
    let mut out: Vec<i32> = Vec::new();
    let needle: str = str_concat("struct ", struct_name);
    let pos: i64 = source_find(src, needle);
    if pos < 0 { return out; };
    let slen: i64 = str_len(src);
    let mut p: i64 = pos + str_len(needle);
    while p < slen && str_char_at(src, p) != 123 { p = p + 1; };
    if p >= slen { return out; };
    p = p + 1;
    let mut depth: i64 = 1;
    let body_start: i64 = p;
    let mut body_end: i64 = p;
    while p < slen && depth > 0 {
        let ch: i64 = str_char_at(src, p);
        if ch == 123 { depth = depth + 1; }
        else if ch == 125 { depth = depth - 1; if depth == 0 { body_end = p; }; };
        p = p + 1;
    };
    if depth != 0 { return out; };
    // Walk fields: `name: type,` (commas optional after last)
    let body: str = str_substring(src, body_start, body_end);
    let blen: i64 = str_len(body);
    let mut q: i64 = 0;
    while q < blen {
        // skip whitespace
        while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9 || str_char_at(body, q) == 10 || str_char_at(body, q) == 13) { q = q + 1; };
        if q >= blen { q = blen + 1; }
        else {
            // skip optional `pub ` field-visibility prefix
            if q + 4 <= blen && str_eq_at(body, q, "pub ") == 1 { q = q + 4; };
            while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
            // field name
            let name_start: i64 = q;
            while q < blen && (is_alnum(str_char_at(body, q)) == 1 || str_char_at(body, q) == 95) { q = q + 1; };
            if q == name_start { q = blen + 1; }
            else {
                let fname: str = str_substring(body, name_start, q);
                while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
                if q >= blen || str_char_at(body, q) != 58 { q = blen + 1; }
                else {
                    q = q + 1;
                    while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
                    let type_start: i64 = q;
                    while q < blen && str_char_at(body, q) != 44 && str_char_at(body, q) != 10 { q = q + 1; };
                    let ftype: str = strip_spaces(str_substring(body, type_start, q));
                    if str_len(fname) > 0 && str_len(ftype) > 0 {
                        out.push(fname);
                        out.push(ftype);
                    };
                    if q < blen && str_char_at(body, q) == 44 { q = q + 1; };
                };
            };
        };
    };
    return out;
}

// T3.4 (v0.3.4): collect Nucleor fns marked `#[export]` so
// `nuc gen-headers` emits C forward declarations alongside the
// `extern fn` imports and `#[repr(C)]` typedefs. Lets external
// C/C++ code (robotics middleware, embedded firmware) call into
// Nucleor-compiled kernels through the unmangled symbol that
// the LLVM IR already emits.
// Returns alternating [fn_name, args_c_decl, c_rtype, ...].
// args_c_decl is the C-formatted parameter list ("int64_t a, double b")
// or "void" for no-args; c_rtype is "void" if the fn has no `-> ret`.
// Skips fns whose signature contains a non-FFI-safe type.
#[manual_drop]
fn collect_export_fns_and_sigs(src: str, repr_c: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut line_starts: Vec<i32> = Vec::new();
    line_starts.push(0);
    let mut s: i64 = 0;
    while s < slen {
        if str_char_at(src, s) == 10 && s + 1 < slen { line_starts.push(s + 1); };
        s = s + 1;
    };
    let nlines: i64 = vec_len(line_starts);
    let mut li: i64 = 0;
    while li < nlines {
        let p: i64 = vec_get(line_starts, li);
        let mut eol: i64 = if li + 1 < nlines { vec_get(line_starts, li + 1) - 1 } else { slen };
        if eol > p && str_char_at(src, eol - 1) == 13 { eol = eol - 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        let mut after_kw: i64 = 0 - 1;
        if lp + 3 <= llen && str_eq_at(line, lp, "fn ") == 1 { after_kw = lp + 3; };
        if after_kw < 0 && lp + 7 <= llen && str_eq_at(line, lp, "pub fn ") == 1 { after_kw = lp + 7; };
        if after_kw >= 0 {
            // Look back at preceding non-blank, non-/// lines for #[export].
            let mut prev_li: i64 = li - 1;
            let mut found: i64 = 0;
            while prev_li >= 0 && found == 0 {
                let pp: i64 = vec_get(line_starts, prev_li);
                let mut pend: i64 = if prev_li + 1 < nlines { vec_get(line_starts, prev_li + 1) - 1 } else { slen };
                if pend > pp && str_char_at(src, pend - 1) == 13 { pend = pend - 1; };
                let pline: str = str_substring(src, pp, pend);
                let trimmed: str = strip_spaces(pline);
                let tlen: i64 = str_len(trimmed);
                if tlen == 0 {
                    prev_li = prev_li - 1;
                } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                    prev_li = prev_li - 1;
                } else if str_eq(trimmed, "#[export]") == 1 {
                    found = 1;
                } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                    // Other #[...] attribute (e.g. #[no_alloc], #[deadline]) — skip
                    prev_li = prev_li - 1;
                } else {
                    prev_li = 0 - 1;
                };
            };
            if found == 1 {
                // Read fn name.
                let name_start: i64 = after_kw;
                let mut q: i64 = name_start;
                while q < llen && (is_alnum(str_char_at(line, q)) == 1 || str_char_at(line, q) == 95) { q = q + 1; };
                if q > name_start {
                    let fname: str = str_substring(line, name_start, q);
                    // Expect (
                    while q < llen && str_char_at(line, q) != 40 { q = q + 1; };
                    if q < llen {
                        q = q + 1;
                        // Collect args until ).
                        let mut args_buf: i64 = sb_new();
                        let mut narg: i64 = 0;
                        let mut bad: i64 = 0;
                        while q < llen && str_char_at(line, q) != 41 && bad == 0 {
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9 || str_char_at(line, q) == 44) { q = q + 1; };
                            if q >= llen || str_char_at(line, q) == 41 { continue; };
                            let an_start: i64 = q;
                            while q < llen && str_char_at(line, q) != 58 && str_char_at(line, q) != 41 { q = q + 1; };
                            let an_raw: str = str_substring(line, an_start, q);
                            if q >= llen || str_char_at(line, q) != 58 { bad = 1; continue; };
                            q = q + 1;
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                            let at_start: i64 = q;
                            while q < llen && str_char_at(line, q) != 44 && str_char_at(line, q) != 41 { q = q + 1; };
                            let at_raw: str = str_substring(line, at_start, q);
                            let arg_name: str = strip_spaces(an_raw);
                            let arg_type: str = strip_spaces(at_raw);
                            let c_type: str = nr_type_to_c_with_structs(arg_type, repr_c);
                            if str_len(c_type) == 0 { bad = 1; continue; };
                            if narg > 0 { sb_append(args_buf, ", "); };
                            sb_append(args_buf, c_type);
                            sb_append(args_buf, " ");
                            sb_append(args_buf, arg_name);
                            narg = narg + 1;
                        };
                        if bad == 0 {
                            if q < llen { q = q + 1; };
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                            let mut rtype: str = "void";
                            if q + 1 < llen && str_char_at(line, q) == 45 && str_char_at(line, q + 1) == 62 {
                                q = q + 2;
                                while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                                let rt_start: i64 = q;
                                while q < llen && str_char_at(line, q) != 32 && str_char_at(line, q) != 9 && str_char_at(line, q) != 123 { q = q + 1; };
                                rtype = str_substring(line, rt_start, q);
                            };
                            let c_rtype: str = nr_type_to_c_with_structs(rtype, repr_c);
                            if str_len(c_rtype) > 0 {
                                let args_str: str = if narg == 0 { "void" } else { sb_to_str(args_buf) };
                                out.push(fname);
                                out.push(args_str);
                                out.push(c_rtype);
                            };
                        };
                    };
                };
            };
        };
        li = li + 1;
    };
    return out;
}

// T1.1 Phase 9: nuc gen-headers <input.nr> [-o <out.h>]
// Scans an .nr source file for `extern fn` declarations and emits a
// matching C header. Useful for cross-language linking when an
// external C/C++ project wants to call Nucleor-compiled functions
// (or vice-versa) through a stable ABI.
// Implementation is a deliberate text-scan rather than a full
// parser invocation: keeps the subcommand standalone, lets it
// run on partial / not-yet-compilable .nr files, and matches
// the file-line convention used by the rest of the toolchain.
#[manual_drop]
fn run_gen_headers_command(argc: i64) -> i64 {
    if argc < 3 {
        print("usage: nuc gen-headers <input.nr> [-o <out.h>]");
        return 1;
    };
    let in_path: str = args_get(2);
    let mut out_path: str = "";
    let mut i: i64 = 3;
    while i < argc {
        let a: str = args_get(i);
        if str_eq(a, "-o") == 1 && (i + 1) < argc {
            out_path = args_get(i + 1);
            i = i + 2;
        } else {
            i = i + 1;
        };
    };
    if str_len(out_path) == 0 {
        // Default: replace .nr with .h
        let plen: i64 = str_len(in_path);
        if plen > 3 && str_eq_at(in_path, plen - 3, ".nr") == 1 {
            out_path = str_concat(str_substring(in_path, 0, plen - 3), ".h");
        } else {
            out_path = str_concat(in_path, ".h");
        };
    };
    let src: str = file_read_string(in_path);
    if str_len(src) == 0 {
        print(str_concat("nuc gen-headers: cannot read ", in_path));
        return 1;
    };
    let mut out: i64 = sb_new();
    sb_append(out, "// Generated by `nuc gen-headers` from ");
    sb_append(out, in_path);
    sb_append(out, "\n// Edits will be lost; regenerate after extern fn / #[repr(C)] struct changes.\n");
    sb_append(out, "#ifndef NUCLEOR_GEN_HEADERS_H\n");
    sb_append(out, "#define NUCLEOR_GEN_HEADERS_H\n");
    sb_append(out, "#include <stdint.h>\n");
    sb_append(out, "#include <stdbool.h>\n\n");
    sb_append(out, "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");

    // T1.6 (v0.2.345): emit C `typedef struct { ... } Name;`
    // declarations for every #[repr(C)] struct in the source.
    // Field types must be primitives or other repr(C) struct names —
    // otherwise we silently skip the offending field rather than
    // emit an invalid C declaration. CXX-004 fires elsewhere (in
    // strict-mode build) when a non-repr(C) struct appears in an
    // extern fn signature.
    let repr_c: Vec<i32> = collect_repr_c_structs(src);
    let mut emitted_structs: i64 = 0;
    let mut si: i64 = 0;
    while si < vec_len(repr_c) {
        let sname: str = vec_get(repr_c, si);
        let fields: Vec<i32> = extract_struct_fields_native(src, sname);
        let fc: i64 = vec_len(fields);
        if fc >= 2 {
            sb_append(out, "typedef struct ");
            sb_append(out, sname);
            sb_append(out, " {\n");
            let mut fi: i64 = 0;
            while fi + 1 < fc {
                let fname: str = vec_get(fields, fi);
                let ftype: str = vec_get(fields, fi + 1);
                let ftype_c: str = nr_type_to_c_with_structs(ftype, repr_c);
                if str_len(ftype_c) > 0 {
                    sb_append(out, "    ");
                    sb_append(out, ftype_c);
                    sb_append(out, " ");
                    sb_append(out, fname);
                    sb_append(out, ";\n");
                };
                fi = fi + 2;
            };
            sb_append(out, "} ");
            sb_append(out, sname);
            sb_append(out, ";\n\n");
            emitted_structs = emitted_structs + 1;
        };
        si = si + 1;
    };

    // Walk source line by line for `extern fn NAME(...) -> RT;`
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut emitted: i64 = 0;
    while p < slen {
        // Find end of line.
        let line_start: i64 = p;
        while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        let line: str = str_substring(src, line_start, p);
        if p < slen { p = p + 1; };
        // Skip leading whitespace for prefix check.
        let llen: i64 = str_len(line);
        let mut lstart: i64 = 0;
        while lstart < llen && (str_char_at(line, lstart) == 32 || str_char_at(line, lstart) == 9) {
            lstart = lstart + 1;
        };
        // Match prefix "extern fn ".
        if lstart + 10 > llen { continue; };
        if str_eq_at(line, lstart, "extern fn ") == 0 { continue; };
        // Parse the line.
        let mut q: i64 = lstart + 10;
        // name
        let name_start: i64 = q;
        while q < llen && (str_char_at(line, q) == 95 || is_alnum(str_char_at(line, q)) == 1) { q = q + 1; };
        let fname: str = str_substring(line, name_start, q);
        if str_len(fname) == 0 { continue; };
        // expect (
        while q < llen && str_char_at(line, q) != 40 { q = q + 1; };
        if q >= llen { continue; };
        q = q + 1; // past (
        // collect args until )
        let mut args_buf: i64 = sb_new();
        let mut narg: i64 = 0;
        let mut bad_arg: i64 = 0;
        while q < llen && str_char_at(line, q) != 41 {
            // skip whitespace, comma
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9 || str_char_at(line, q) == 44) { q = q + 1; };
            if q >= llen || str_char_at(line, q) == 41 { continue; };
            // arg name
            let an_start: i64 = q;
            while q < llen && str_char_at(line, q) != 58 && str_char_at(line, q) != 41 { q = q + 1; };
            let an_raw: str = str_substring(line, an_start, q);
            if q >= llen || str_char_at(line, q) != 58 { bad_arg = 1; q = llen; continue; };
            q = q + 1; // past :
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
            let at_start: i64 = q;
            while q < llen && str_char_at(line, q) != 44 && str_char_at(line, q) != 41 { q = q + 1; };
            let at_raw: str = str_substring(line, at_start, q);
            // trim trailing whitespace
            let arg_name: str = strip_spaces(an_raw);
            let arg_type: str = strip_spaces(at_raw);
            // T1.6 (v0.2.345): struct-by-value FFI — accept any
            // #[repr(C)] struct name (already collected above).
            let c_type: str = nr_type_to_c_with_structs(arg_type, repr_c);
            if str_len(c_type) == 0 { bad_arg = 1; continue; };
            if narg > 0 { sb_append(args_buf, ", "); };
            sb_append(args_buf, c_type);
            sb_append(args_buf, " ");
            sb_append(args_buf, arg_name);
            narg = narg + 1;
        };
        if bad_arg == 1 { continue; };
        if q < llen { q = q + 1; }; // past )
        // expect "-> RTYPE;"
        let mut rtype: str = "void";
        while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
        if q + 1 < llen && str_char_at(line, q) == 45 && str_char_at(line, q + 1) == 62 {
            q = q + 2;
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
            let rt_start: i64 = q;
            while q < llen && str_char_at(line, q) != 59 && str_char_at(line, q) != 32 && str_char_at(line, q) != 9 { q = q + 1; };
            rtype = str_substring(line, rt_start, q);
        };
        let c_rtype: str = nr_type_to_c_with_structs(rtype, repr_c);
        if str_len(c_rtype) == 0 { continue; };
        sb_append(out, c_rtype);
        sb_append(out, " ");
        sb_append(out, fname);
        sb_append(out, "(");
        if narg == 0 { sb_append(out, "void"); }
        else { sb_append(out, sb_to_str(args_buf)); };
        sb_append(out, ");\n");
        emitted = emitted + 1;
    };
    // T3.4 (v0.3.4): emit C decls for `#[export]`-marked Nucleor
    // fns. The LLVM IR already uses the unmangled symbol so the
    // header is the only missing piece for C-side callers.
    let exports: Vec<i32> = collect_export_fns_and_sigs(src, repr_c);
    let exn: i64 = vec_len(exports);
    let mut emitted_exports: i64 = 0;
    let mut ei: i64 = 0;
    if exn >= 3 {
        sb_append(out, "// === #[export] — Nucleor fns callable from C ===\n");
    };
    while ei + 2 < exn {
        let xn: str = vec_get(exports, ei);
        let xa: str = vec_get(exports, ei + 1);
        let xr: str = vec_get(exports, ei + 2);
        sb_append(out, xr);
        sb_append(out, " ");
        sb_append(out, xn);
        sb_append(out, "(");
        sb_append(out, xa);
        sb_append(out, ");\n");
        emitted_exports = emitted_exports + 1;
        ei = ei + 3;
    };
    sb_append(out, "\n#ifdef __cplusplus\n}\n#endif\n");
    sb_append(out, "#endif // NUCLEOR_GEN_HEADERS_H\n");
    let _ = file_write_string(out_path, sb_to_str(out));
    let extern_count: str = str_from_int(emitted);
    let export_count: str = str_from_int(emitted_exports);
    if emitted_structs > 0 {
        print(str_concat("nuc gen-headers: wrote ", str_concat(str_from_int(emitted_structs), str_concat(" #[repr(C)] struct(s), ", str_concat(extern_count, str_concat(" extern decl(s), ", str_concat(export_count, str_concat(" #[export] decl(s) to ", out_path))))))));
    } else {
        print(str_concat("nuc gen-headers: wrote ", str_concat(extern_count, str_concat(" extern decl(s), ", str_concat(export_count, str_concat(" #[export] decl(s) to ", out_path))))));
    };
    return 0;
}





// =====================================================
// RFC-NRT-004 §H: module-prefixed lowering — tools-suite copies.
// Mirror of the fns in compiler/s1/cli.nr that the resolver hook in
// compiler/s1/modules.nr calls. Tools-suite imports modules.nr but
// not cli.nr (per DUP-1), so the §H fns need to be visible here too
// for the link to resolve when tools-suite is built. Keep these
// byte-identical to the cli.nr definitions; the drift gate enforces.
// =====================================================

#[manual_drop]
fn mod_h_prefix_from_marker(src: str) -> str {
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut found: i64 = 0;
    let mut result: str = "";
    while p < slen && found == 0 {
        while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
        if p >= slen {
            found = 1;
        } else {
            let c: i64 = str_char_at(src, p);
            if c == 10 {
                p = p + 1;
            } else if c == 13 {
                p = p + 1;
            } else {
                let marker: str = "// nucleor:module-namespace";
                let mlen: i64 = str_len(marker);
                if p + mlen <= slen {
                    let mut i: i64 = 0;
                    let mut match_ok: i64 = 1;
                    while i < mlen && match_ok == 1 {
                        if str_char_at(src, p + i) != str_char_at(marker, i) { match_ok = 0; };
                        i = i + 1;
                    };
                    if match_ok == 1 {
                        let mut q: i64 = p + mlen;
                        while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) { q = q + 1; };
                        let start: i64 = q;
                        let mut id_done: i64 = 0;
                        while q < slen && id_done == 0 {
                            let ch: i64 = str_char_at(src, q);
                            if is_alnum(ch) == 1 || ch == 95 { q = q + 1; } else { id_done = 1; };
                        };
                        if q > start {
                            result = str_substring(src, start, q);
                        };
                    };
                };
                found = 1;
            };
        };
    };
    return result;
}

#[manual_drop]
fn mod_h_collect_top_level_fn_names(source: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let mut result: Vec<i32> = Vec::new();
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let name: str = vec_get(info, 0);
        if str_len(name) > 0 {
            if str_eq(name, "main") == 0 {
                priv_string_vec_push_unique(result, name);
            };
        };
        p = eol + 1;
    };
    return result;
}

#[manual_drop]
fn mod_h_mangle_module_fns(src: str, prefix: str, all_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            let comment_start: i64 = p;
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
            sb_append_range(sb, src, comment_start, p);
            last_non_ws = 10;
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
            last_non_ws = 34;
        } else if c == 39 {
            let char_start: i64 = p;
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    p = p + 2;
                } else {
                    p = p + 1;
                };
            };
            if p < slen { p = p + 1; };
            sb_append_range(sb, src, char_start, p);
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            let start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            if preceded_by_dot == 0 && priv_string_vec_contains_at(all_names, src, start, p) == 1 {
                sb_append(sb, prefix);
                sb_append(sb, "_");
                sb_append_range(sb, src, start, p);
            } else {
                sb_append_range(sb, src, start, p);
            };
            last_non_ws = str_char_at(src, p - 1);
        } else {
            sb_append_char_at(sb, src, p);
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}


// top-level entry point. Heap-backed locals
// are short-lived dispatch scratch. Annotated as safety guardrail.
