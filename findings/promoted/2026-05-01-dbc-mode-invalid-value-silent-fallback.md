---
title: `NUCLEOR_DBC_MODE=<unrecognized>` silently falls back to `debug` — adopter writes `=off` thinking they strip checks, gets contract checks running in production
severity: silent-misconfig (wrong-error class — the error doesn't fire when the user expects)
probe_file: probes/_sweep/dbc_mode_invalid.nr (will be filed)
diagnostic_actual: build succeeds with debug-mode contracts active; require/ensure run at runtime
diagnostic_expected: either (a) compile-time WARNING ("unrecognized NUCLEOR_DBC_MODE='off' — recognized values: debug | release | cert; using debug as fallback"), OR (b) hard-error halt with the same message
discovered_against: main v0.4.252 RFC-0006 DbC build-mode strip ship
commit: probe 099767e + main 02752c1
---

## Repro

Build a function with `#[require]`:

```nr
#[require(x > 0)]
fn pos(x: i64) -> i64 { x }

fn main() -> i32 { print_int(pos(0 - 5) as i32); 0 }
```

Compile with each NUCLEOR_DBC_MODE value:

| Value | Behavior | Adopter expectation |
|---|---|---|
| (unset) | debug — require fires | ✓ matches default |
| `debug` | require fires | ✓ matches doc |
| `release` | require stripped — prints `-5` | ✓ matches doc |
| `cert` | require stripped — prints `-5` | ✓ matches doc |
| `off` | **require FIRES** — adopter expected stripped | ❌ silent fallback |
| `disabled` | **require FIRES** | ❌ silent fallback |
| `0` | **require FIRES** | ❌ silent fallback |
| `none` | **require FIRES** | ❌ silent fallback |
| `garbage` | **require FIRES** | (correct fallback, but no signal) |

## Root cause

`compiler/nucleor_s1_compiler.nr:20284-20286`:

```nr
let dbc_mode: str = env_get_or("NUCLEOR_DBC_MODE", "debug");
let dbc_emit_require: i64 = if str_eq(dbc_mode, "release") == 1 || str_eq(dbc_mode, "cert") == 1 { 0 } else { 1 };
let dbc_emit_ensure_inv: i64 = if str_eq(dbc_mode, "debug") == 1 || str_len(dbc_mode) == 0 { 1 } else { 0 };
```

The flags treat ANY non-{`release`, `cert`} value as "emit require", and ANY value other than {`debug`, ""} as "do NOT emit ensure/inv". So:
- `NUCLEOR_DBC_MODE=off` → emit_require=1 (because `off` ≠ release/cert), emit_ensure_inv=0 (because `off` ≠ debug)
- This is INCONSISTENT: require runs but ensure/inv don't. Adopter probably wanted both stripped.

Worse: the user has no signal that their value was unrecognized.

## Hazard tier

**Silent-misconfig.** Production builds where adopter intended to strip contracts but typo'd the env var keep running them — performance and panic-on-violation surprises in production.

The inverse hazard: setting `NUCLEOR_DBC_MODE=debug` for testing, then accidentally typing `=Debug` (capital D) → ensure/inv stripped silently in test runs, miscalibrated test results.

## Suspected fix

In `compiler/nucleor_s1_compiler.nr` near line 20284, validate the env var:

```nr
let dbc_mode_raw: str = env_get_or("NUCLEOR_DBC_MODE", "debug");
let dbc_mode: str = if str_eq(dbc_mode_raw, "debug") == 1
    || str_eq(dbc_mode_raw, "release") == 1
    || str_eq(dbc_mode_raw, "cert") == 1
    || str_len(dbc_mode_raw) == 0 { dbc_mode_raw } else {
    print(str_concat("warning: unrecognized NUCLEOR_DBC_MODE='", str_concat(dbc_mode_raw, "' — recognized values: debug | release | cert. Using 'debug' as fallback.")));
    "debug"
};
let dbc_emit_require: i64 = if str_eq(dbc_mode, "release") == 1 || str_eq(dbc_mode, "cert") == 1 { 0 } else { 1 };
let dbc_emit_ensure_inv: i64 = if str_eq(dbc_mode, "release") == 1 || str_eq(dbc_mode, "cert") == 1 { 0 } else { 1 };
```

Also fix the inconsistent `emit_ensure_inv` logic — line 20286 currently checks `str_eq(dbc_mode, "debug")` which excludes the empty-string default-to-debug case. Better: emit-on iff NOT release/cert. Mirrors the require flag.

## Memory-blow-up note

Not memory-related.

## Cross-ref

- v0.4.252 — NUCLEOR_DBC_MODE build-mode strip ship; this is the validation gap.

## Probe

Filed alongside this finding.


## Promoted

- Fixture: `tests/err/err_dbc_mode_invalid.nr`
- Verify gate step: `t_rfc0006_dbc_mode_invalid_reject` (positive: NUCLEOR_DBC_MODE=off → exit 1 + CONTRACT-009; sanity: NUCLEOR_DBC_MODE=release → exit 0)
- Fix shipped: v0.4.275 — at compile entry, validate `dbc_mode` against the recognized set `{ "" / "debug" / "safe-release" / "release" / "cert" }`. Halt with CONTRACT-009 naming the bad value and the recognized set.
- Diag code: probe finding suggested an unspecified slot; reserved CONTRACT-009 (next free in CONTRACT series after CONTRACT-008 from v0.4.272) in spec doc + is_known_diag_code + verify scripts.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit ed85843)
