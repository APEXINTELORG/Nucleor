---
title: T-3 — char ↔ int silent compatibility confirmed; `as char` accepts surrogates, codepoints > U+10FFFF, and negatives without Unicode validation
severity: silent-miscompute
probe_file: probes/types/t_3_char_int_silent_compat.nr
diagnostic_actual: build success, rc=0, char/int interop accepted silently in both directions
diagnostic_expected: TYP-005/TYP-006 type mismatch on char↔i64 flow; new TYP-026 (per RFC T-3 Phase 2) on invalid Unicode codepoint
discovered_against: v0.4.180
commit: 53af3b53
status: NEW (main shipped v0.8.46 char-cast audit-pass info AFTER probe checkout — see notes)
---

## Repro

```nr
fn want_char(c: char) -> i64 { return 1; }
fn want_i64(n: i64) -> i64 { return 1; }

fn main() -> i32 {
    // (1) i64 flows into char parameter — accepted silently
    let n: i64 = 65;
    let r1: i64 = want_char(n);
    print_int(r1);

    // (2) char binding receives integer literal — accepted silently
    let c: char = 65;
    if c == 65 { print("char silently == i64"); }

    // (3) char flows into i64 parameter — accepted silently
    let r2: i64 = want_i64(c);

    // (4) `as char` accepts invalid Unicode without diagnostic
    let surrogate: char = 0xD800 as char;     // surrogate, RFC 3629 reserved
    let too_high:  char = 0x110000 as char;   // > U+10FFFF max
    let negative:  char = (-1) as char;       // negative codepoint
    print_int(surrogate as i64);
    print_int(too_high as i64);
    print_int(negative as i64);
    return 0;
}
```

## Actual

```
$ bin/nucleor.exe build probes/types/t_3_char_int_silent_compat.nr
  ...
  compiled: target\t_3_char_int_silent_compat.exe
$ ./target/t_3_char_int_silent_compat.exe
r1 (want_char(i64)):
1
c == 65 ?
yes - char silently == i64
r2 (want_i64(char)):
1
surrogate as i64:
55296
too_high as i64:
1114112
negative as i64:
4294967295
rc=0
```

Every char/int boundary collapsed silently. No TYP-* diagnostic. The `as char` cast accepts surrogate-range, above-`U+10FFFF`, and negative inputs and stores them as if they were valid codepoints. `(-1) as char` produces `0xFFFFFFFF` — the i64→u32 reinterpretation hides the negative.

## Expected

Per RFC T-3 (`docs/rfcs/gap-analyses/Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md`):

- Phase 1 (immediate): remove the `char`-to-any-integer wildcard in `types_compatible`. Flow (1)/(2)/(3) above each become **TYP-005/TYP-006** type mismatches at compile time.
- Phase 2: validate `as char` source for valid Unicode scalar value. Reject `0xD800..=0xDFFF` (surrogates), `> 0x10FFFF` (out of range), and negative source (i64). New diagnostic **TYP-026** (invalid char codepoint).
- Phase 3 (v1.0 gate): `char` is a distinct IR type (4-byte / u32 slot). Mixing with i64 without explicit cast is a compile error.

## Severity

**silent-miscompute** — same class as RFC. A char binding can hold any 64-bit value with no signal to the user. UTF-8 emission downstream produces invalid byte sequences, which various filesystems / TTYs / network protocols then reject in adopter-visible ways downstream of the original miscompute. Adopter trust impact: high (Rust/C# adopters expect `char` to be honest).

## Cross-ref

- `compiler/nucleor_s1_compiler.nr` — `types_compatible(...)` (search for the `char` wildcard branch)
- `as_u32` cast helper — current target of `as char` per RFC
- T-4 sister finding (empty-type compat hole) — same structural shape: `types_compatible` short-circuits true on certain inputs that should be hard rejections
- RFC: §T-3 in the type-system gap analysis

## Notes for main agent

- **`origin/main` v0.8.46** (commit `75d18ebc` "Wave 1 — T-3 Phase 1 char-cast audit-pass info") just shipped a Phase 1 audit-pass info diagnostic. My probe binary is v0.4.180 so the audit-pass output above is pre-fix. Recommend re-running this fixture against an `origin/main` HEAD bin/nucleor.exe to confirm the diagnostic now fires, and to identify which of the 6 hazards above the audit-pass actually catches.
- The 4 distinct hazards in this fixture (i64→char param, integer→char binding, char→i64 param, `as char` invalid Unicode) likely each need a separate audit-pass scanner heuristic. A single "warn on `as char`" pass misses #1/#2/#3.
- Recommendation for Phase 2: don't trust source-text scanners for type-compatibility audits — these are exactly the kind of bugs that `types_compatible` already SHOULD reject. The cleaner path is to remove the `char`-wildcard from `types_compatible` and let the existing TYP-005/006 machinery fire. That single-line edit closes hazards 1/2/3. Hazard 4 (`as char` validation) is the only one that needs new diagnostic infrastructure.
