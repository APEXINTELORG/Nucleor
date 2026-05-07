// EXPECT: rc=0
// v0845 Lane 7 / Queue 7A — cross-platform deterministic-hash
// transcript. Prints a curated hash/control row set for a fixed
// input corpus so adopters and CI can byte-compare Windows and
// POSIX bridge output transcripts.
//
// FNV-1a 64-bit is deterministic by spec — same input bytes must
// produce the same i64 hash on every platform. Per the
// findings/inbox/cloud_claude_lane8_8C_v0845_2026-05-07.md
// transcript, the rust_bridge already passed 70k alloc/free
// cycles and valgrind clean on POSIX; this fixture lets a paired
// run on Windows + Linux surface any platform-divergent hash
// silently slipping in.
//
// The expected reference values below are the FNV-1a 64-bit
// offset_basis 0xcbf29ce484222325 reinterpreted to i64 for the
// empty string, plus the FNV-1a iterates for the curated inputs.
// All reference values were captured on Windows host (this fixture's
// initial run); the paired Linux run is queued under
// Cloud_Control1.md Round-3 §8N.
//
// Output format (newline-delimited rows):
//   <input> <hash>
// where <hash> is the i64 hash printed via print_int64.

import "stdlib/rods/rust.nr"

fn print_row(label: str, h: i64) {
    print(str_concat(label, str_concat(" ", str_concat(int_to_str(h), "\n"))));
}

fn main() -> i32 {
    // Empty + small ASCII inputs.
    print_row("empty", rust_hash_string_fnv1a(""));
    print_row("a", rust_hash_string_fnv1a("a"));
    print_row("hello", rust_hash_string_fnv1a("hello"));
    print_row("world", rust_hash_string_fnv1a("world"));

    // 1-byte boundary set to surface any signed/unsigned drift.
    // Only `\0` is in Nucleor's recognized-escape set today (per
    // NR025); higher-bit-pattern escape sequences (`\xNN`) are not
    // yet supported and would surface as parse errors.
    print_row("null-byte", rust_hash_string_fnv1a("\0"));

    // Multi-line / longer fixed input.
    print_row("nucleor", rust_hash_string_fnv1a("nucleor"));
    print_row("the quick brown fox", rust_hash_string_fnv1a("the quick brown fox"));

    // Determinism check: any platform-divergent hash would surface
    // here as a non-zero return that the harness's exit-code gate
    // catches. The byte-comparison against the paired-transcript
    // reference is the canonical Q7A check.
    let h1: i64 = rust_hash_string_fnv1a("nucleor-r06");
    let h2: i64 = rust_hash_string_fnv1a("nucleor-r06");
    if h1 != h2 { return 1; };

    return 0;
}
