---
title: `str_char_at(s, i)` for `i >= strlen(s)` silently OOB-reads past source
severity: silent-miscompute (memory-safety class)
probe_file: probes/_sweep/p30_str_index_oob.nr
diagnostic_actual: silent — returns the byte at memory address `s + i` regardless of whether i is within strlen(s). `s = "hi"; str_char_at(s, 100)` reads heap memory at offset 100 past the source's NUL terminator.
diagnostic_expected: either (a) strict-by-default panic (matching v0.3.205+Ship 41's `str_substring` close + `vec_get` convention), OR (b) bounded silent return 0 (NUL byte) when `i >= strlen(s)`, matching some lexer adoption patterns
discovered_against: probe/exploration tip after ship 42 (commit dd48f0f) on top of v0.4.237 main work-in-progress
commit: dd48f0f
---

## Repro

```nr
fn main() -> i32 {
    let s: str = "hi";   // 2 bytes + NUL = 3 bytes of source storage
    let c: i64 = str_char_at(s, 100);   // reads s[100] — 97 bytes past NUL
    print_int(c as i32);
    0
}
```

## Actual

Prints `0` (or whatever heap byte happens to be at that offset; here
the page is zero-filled, but the result is undefined). No diagnostic.

```c
// stdlib/runtime/nucleor_llvm_rt.c:1660+
long long __nucleor_str_char_at(const char *s, long long i) {
    g_p_str_char_at++; _profile_init_once();
    if (!s) return 0;
    if (i < 0) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: str_char_at OOB: negative index %lld...");
        exit(1);
    }
    return (unsigned char)s[(int)i];   // ← unchecked read past strlen(s)
}
```

The check is **negative-index-only**. There's NO `i >= strlen(s)`
guard, so any positive `i` past the source dereferences whatever
heap/stack/data-segment memory follows the source pointer.

## Hazard tier

**Memory-safety class.** Same shape as the v0.3.205 `str_substring`
default OOB-read hazard that Ship 41 closed in this probe cycle.

Three real-world vectors (all mirror Ship 41's analysis):

1. **Information disclosure** — adopter writes `let last = str_char_at(s, expected_len - 1);` for a wrong-by-one `expected_len`; the leaked byte gets used in a hash, comparison, or dispatch keyed on it.

2. **Heap-page-boundary segfault** — if the source pointer is near a heap-page boundary, the OOB read crosses unmapped memory and SIGSEGVs nondeterministically.

3. **Untrusted-input amplifier** — any code path where `i` derives from user input (parsing, network, file): a one-character probe by an attacker walks the heap byte-by-byte.

## Asymmetric guarantee

The Nucleor runtime is currently inconsistent on bounds enforcement:

| Helper | OOB behavior pre-Ship-41 | Post-Ship-41 default |
|---|---|---|
| `vec_get` | strict (panic) | strict (panic) |
| `str_substring` | silent OOB-read 98 bytes | strict (panic) — Ship 41 |
| `str_char_at` | silent 1-byte OOB-read | **still silent** (this finding) |

The Ship 41 split (`str_substring` strict-by-default, `_unchecked`
opt-in for hot paths) is the canonical pattern. Same fix shape would
apply here:

- `str_char_at` → strict-by-default (panic if `i >= strlen(s)`)
- `str_char_at_unchecked` → opt-in fast path (current behavior)

## Self-host dependence (perf concern)

`str_char_at` has **686 call sites in `compiler/nucleor_s1_compiler.nr`** — heavy use. Most lexer/parser sites guard against OOB before calling (e.g. `if p + 1 < slen && is_alnum(str_char_at(src, p + 1)) == 1 {`), so they'd correctly stay on `_unchecked`.

A naive strict-by-default that adds `strlen(s)` per call would:
- O(N) cost per call → matches the v0.3.205 `str_substring` hot-path regression that lost 13× perf
- 686 sites × per-call strlen = catastrophic for self-host build time

The Ship 39+40+41 multi-tick migration template applies directly:

- **Tick 1 (foundation):** register `str_char_at_unchecked` as alias of `__nucleor_str_char_at` (no behavior change).
- **Tick 2 (rename callers):** sed-migrate the 686 self-host callsites to `str_char_at_unchecked`. All lexer/parser sites already validate `i < slen`, so unchecked stays correct.
- **Tick 3 (flip default):** change `str_char_at` user-space mapping in `get_rt_name` to a new `__nucleor_str_char_at_strict` runtime helper that panics on `i >= strlen(s)`. Adopter-facing code gets the safe default; self-host stays fast.

## Memory-blow-up note

Not memory-blowup (one-byte read). But memory-SAFETY hazard with a
clean migration template proven by Ship 41.

## Cross-ref

- `2026-04-30-str-substring-default-no-end-bounds-check.md` — closed by Ships 39+40+41. Same migration shape applies here.
- `__nucleor_vec_get` runtime — strict OOB panic by default with NUCLEOR_VEC_OOB_LENIENT escape. Asymmetric guarantee currently broken by str_char_at.

## Probe

`probes/_sweep/p30_str_index_oob.nr` — minimal repro.


## Promoted

- Fixture (positive): `tests/features/str_char_at_strict_basic.nr` — in-bounds reads return same byte values as default `str_char_at`.
- Fixture (negative): `tests/err/err_str_char_at_strict_oob.nr` — `str_char_at_strict("hi", 100)` panics with `str_char_at_strict OOB: index 100 len 2`.
- Verify gate steps: `t_str_char_at_strict_basic` + `t_str_char_at_strict_oob`.
- Fix shipped: v0.4.279 — opt-in `str_char_at_strict(s, i)` runtime helper that pays the strlen check + panics on OOB. Default `str_char_at` keeps its v0.3.220 cheap-default semantics (negative-only check; strlen-per-call is a 75x perf killer in lexer hot paths per the v0.3.220 retrospective). Mirrors the v0.3.220 `str_substring` / `str_substring_strict` opt-in pattern.
- The probe-finding asked for strict-by-default; v0.3.220 retrospective rules that out for perf reasons. Opt-in strict variant gives adopters the safety they want without breaking lexers.
- Wired in: `__nucleor_str_char_at_strict` runtime helper (stdlib/runtime/nucleor_llvm_rt.c), `str_char_at_strict` builtin name → llvm helper map (compiler/nucleor_s1_compiler.nr + tools-suite mirror), is_runtime_helper allowlist, IR `declare` blocks (both compilers), helper_manifest.toml (auto-generated).
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit dd48f0f vintage)
