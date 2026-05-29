// =====================================================
// Nucleor Tools-Suite Compiler  (nucleor_tools)
// =====================================================
// The tooling driver (nuc test / check / bench / audit / explain /
// registry / lock / install / doc / abi / ...). RFC-0063 Phase 2.0:
// the compiler PIPELINE is no longer duplicated here — it is imported
// directly from the s1 single source of truth (compiler/s1/*.nr). This
// file + compiler/ts/*.nr now carry ONLY the tooling-specific layer
// (CLI commands, taint/review analyses, package/registry/doc tooling).
// The former duplicate parser/lowerer/emitter and the
// nucleor_rfc0063_shared_wave{1,2}.nr layer have been deleted.
// =====================================================
// file-wide PERF-3 suppression — same rationale as
// nucleor_s1_compiler.nr: the pipeline builds AST nodes per-iteration
// (bounded per-token allocation, not a per-iteration leak).
#[allow(PERF-3)]

// --- entry-level numeric/string helpers (mirror of s1 entry) --------
// s1's pipeline modules call these; s1 keeps them in its entry file
// (nucleor_s1_compiler.nr), which we do NOT import (it carries s1's
// build-driver main/cli). Keep byte-identical copies here.
#[manual_drop]
fn str_from_i64(n: i64) -> str {
    if n == 0 { return "0"; };
    if n == 1 { return "1"; } else if n == 2 { return "2"; } else if n == 3 { return "3"; }
    else if n == 4 { return "4"; } else if n == 5 { return "5"; } else if n == 6 { return "6"; }
    else if n == 7 { return "7"; } else if n == 8 { return "8"; } else if n == 9 { return "9"; };
    if n == (0 - 1) { return "-1"; } else if n == (0 - 2) { return "-2"; } else if n == (0 - 3) { return "-3"; }
    else if n == (0 - 4) { return "-4"; } else if n == (0 - 5) { return "-5"; } else if n == (0 - 6) { return "-6"; }
    else if n == (0 - 7) { return "-7"; } else if n == (0 - 8) { return "-8"; } else if n == (0 - 9) { return "-9"; };
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
fn str_from_int(n: i64) -> str {
    return str_from_i64(n);
}
#[manual_drop]
fn str_to_int(s: str) -> i64 {
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
fn str_is_digits(s: str) -> i64 {
    let slen: i64 = str_len(s);
    if slen == 0 { return 0; };
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c < 48 || c > 57 { return 0; };
        i = i + 1;
    };
    return 1;
}

// Kept in the main file (not in ts/cli.nr) so tools/check_compiler_drift.sh's
// grep-of-main-source still finds the version label. Mirrors the same
// constraint in compiler/nucleor_s1_compiler.nr.
#[manual_drop]
fn compiler_version_label() -> str {
    return "1.1.1";
}

// --- PIPELINE: single source of truth, imported from s1 -------------
// Tooling-side helper layer that s1 keeps in s1/cli.nr (which we do not
// import): privatization resolver helpers (content_hash,
// priv_mangle_private_fns, priv_collect_private_fn_names — required by
// s1/modules.nr), macro expansion, and CLI-arg helpers. Stripped of all
// pipeline duplicates; only the ~41 gap-filler helpers remain.
import "nucleor_rfc0063_shared_wave1.nr"
import "nucleor_rfc0063_shared_wave2.nr"

import "s1/lex.nr"
import "s1/parse.nr"
import "s1/ir.nr"
import "s1/optim.nr"
import "s1/builtins.nr"
import "s1/emit.nr"
import "s1/lower.nr"
import "s1/diag.nr"
import "s1/check_eff.nr"
import "s1/check_own.nr"
import "s1/check_type.nr"
import "s1/cache.nr"
import "s1/modules.nr"

// --- TOOLING LAYER: tools-suite-only code (ts/*.nr) -----------------
import "ts/optim.nr"
import "ts/emit.nr"
import "ts/lower.nr"
import "ts/diag.nr"
import "ts/check_eff.nr"
import "ts/check_own.nr"
import "ts/cache.nr"
import "ts/explain_error.gen.nr"
import "ts/modules.nr"
import "ts/check_taint.nr"
import "ts/review.nr"
import "ts/pipeline.nr"
// s1/cli.nr helper fns the imported pipeline depends on (attribute/effect
// audits, type inference, link-error lift), minus the build-driver fns
// (main/compile_file_mode/run_*) which ts/cli.nr provides. Copied rather
// than imported because s1/cli.nr's driver would collide with ts's.
import "ts/s1cli_helpers.nr"
import "ts/cli.nr"
