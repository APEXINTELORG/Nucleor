// =====================================================================
// RFC-0063 Wave 13-16 — Phase 3 parser/tools-suite duplicate retirement.
// Companion to nucleor_rfc0063_shared_wave1.nr. s1 canonical.
// Shared parser helpers for RFC-0063 hardening.
//
// Excluded from move (must stay LOCAL in tools_suite — read directly
// by tools/check_compiler_drift.sh which doesn't follow imports):
//   get_rt_name, is_ptr_ret, is_ptr_arg, emit_externs,
//   compiler_version_label, emit_user_externs (contains a `declare `
//   sb_append the IR-declare drift gate enforces).
// match_bind_payloads_typed pairs with SIG_DIFFERS match_bind_payloads
// (wave 14 territory).
// Those are filed as Phase B residuals in
// Keep these helpers source-compatible with the s1 compiler mirror.
//
// Wave 13a (≤30-line) + 13b (30-100-line) + 13c (>100-line).
// All s1-only-helper-dep candidates filtered out.
// Imported by compiler/nucleor_tools_suite.nr alongside wave1.
// =====================================================================
























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
                    sb_append(sb, "    deadline_enter(__nuc_dl_start, ");
                    sb_append(sb, str_from_int(dl_value));
                    sb_append(sb, ");\n");
                    if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 {
                        sb_append(sb, "    let __nuc_dl_r: ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " = ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_exit();\n");
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
                        sb_append(sb, "    deadline_exit();\n");
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
    // v0.5.11: format extra args cannot be silently dropped.
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
