// =====================================================
// Nucleor Stage 1 Compiler
// =====================================================
// A complete Nucleor compiler written in Nucleor.
// Reads a .nr source file, compiles it through:
//   source -> lex -> parse -> lower -> emit LLVM IR -> clang -> native exe
// Usage: nucleor_s1 <source.nr> <output_name>
// =====================================================
// file-wide PERF-3 suppression — same rationale as
// nucleor_s1_compiler.nr v0.8.302. Tools-suite shares lex / parse
// helpers from s1; 26 sites are intentional bounded per-token
// allocation.
#[allow(PERF-3)]

import "nucleor_rfc0063_shared_wave1.nr"
import "nucleor_rfc0063_shared_wave2.nr"

// T1.1 Phase 3c (v0.2.310): widened internal arithmetic to i64
// (parallel to compiler/nucleor_s1_compiler.nr:str_from_int) so
// large IR constants format correctly under Phase 1's narrow-as
// hook.
// doc-#2 §5 P1 mirror — see nucleor_s1_compiler.nr.

// v0.5 (v0.4.233 integration) — mirror of compiler-side cleanup.
// Param widened i32 → i64 to match runtime ABI.

// Kept in the main file (not in ts/cli.nr) so tools/check_compiler_drift.sh's
// grep-of-main-source still finds the version label. Mirrors the same
// constraint in compiler/nucleor_s1_compiler.nr.
fn compiler_version_label() -> str {
    return "1.1.1";
    // Mirrors s1. History: 0.4.180 (caught up from stale 0.2.0-v2) →
    // 0.8.323 (RFC-0063 Phase 1 follow-on) → 1.0.0 (RFC-0062 closure +
    // RFC-0063 unification) → 1.0.1 (hardening sweep) →
    // 1.0.2 → 1.0.3 (cold-compile str_substring regression fix) → 1.1.0.
}

// =====================================================
// LEXER (from T29, unchanged)
// =====================================================


// =====================================================
// PARSER (extracted to compiler/ts/parse.nr)
// =====================================================
import "ts/parse.nr"

// =====================================================
// OPTIMIZER PASSES (extracted to compiler/ts/optim.nr;
// includes the one-fn IR DATA STRUCTURES section)
// =====================================================
import "ts/optim.nr"

// =====================================================
// BUILTIN MAPPING (extracted to compiler/ts/builtins.nr)
// =====================================================
import "ts/builtins.nr"

// =====================================================
// EMISSION (extracted to compiler/ts/emit.nr; includes
// the LLVM STRING ESCAPING header)
// =====================================================
import "ts/emit.nr"

// =====================================================
// LOWERING (extracted to compiler/ts/lower.nr)
// =====================================================
import "ts/lower.nr"

// =====================================================
// DIAGNOSTICS (extracted to compiler/ts/diag.nr)
// =====================================================
import "ts/diag.nr"

// =====================================================
// REVIEW HOOKS (extracted to compiler/ts/review.nr)
// =====================================================
import "ts/review.nr"

// =====================================================
// OWNERSHIP CHECKER (extracted to compiler/ts/check_own.nr)
// =====================================================
import "ts/check_own.nr"

// =====================================================
// EFFECT CHECKER (extracted to compiler/ts/check_eff.nr)
// =====================================================
import "ts/check_eff.nr"

// =====================================================
// TAINT CHECKER (extracted to compiler/ts/check_taint.nr)
// =====================================================
import "ts/check_taint.nr"

// =====================================================
// PARALLEL FRONTEND + INCREMENTAL CACHE
// (extracted to compiler/ts/cache.nr)
// =====================================================
import "ts/cache.nr"

// =====================================================
// PIPELINE (extracted to compiler/ts/pipeline.nr)
// =====================================================
import "ts/pipeline.nr"

// =====================================================
// MODULE SYSTEM (extracted to compiler/ts/modules.nr)
// =====================================================
import "ts/modules.nr"

// =====================================================
// COMPILER DRIVER (extracted to compiler/ts/cli.nr)
// =====================================================
import "ts/cli.nr"
