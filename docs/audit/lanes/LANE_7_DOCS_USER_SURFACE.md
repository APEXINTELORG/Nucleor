# Lane 7 — Docs + User Surface

**Branch:** `fix/audit-lane-7-docs-user-surface-2026-05-08`
**Theme:** Mass mechanical cleanup of documentation drift, dead CLI dispatch, version stamps, install path. Layer 10 + cross-layer doc-related Lows.

## In-scope findings

### Critical (2)
- **Layer 10** — `nuc help` lists `add | remove | update` as `install` aliases — all return "Unknown command." Missing dispatch wire.
- **Layer 10** — README claims `nuc explain` works for every G-series diagnostic (11 codes); actually returns "unknown error code" for all of them. Database only knows legacy `OWN-001/TYP-00X/NUM-001/NR0XX`.

### High (4)
- **Layer 10** — `docs/language-reference.md` self-identifies as v0.2.0-v2; corrigenda describe pre-v1.0 audits
- **Layer 10** — `examples/README.md` install snippet says `./hello.exe` but binary lands in `target/hello.exe`
- **Layer 10** — README claims `--release` flag, `architecture.md` claims `--tier <0|1|2>` — both silently swallowed
- **Layer 10** — `docs/g1-default-flip-adopter-guide.md` documents `NUC_AUTO_DROP_DEFAULT=1` toggle as if experimental — README says it's the v1.0 default

### Medium / Low (mass)
- `docs/benchmarks.md` numbers all pre-v1.0 (v0.2.128/87/84 stamps)
- `nuc check --sarif` reports driver `version":"0.1.0"`
- `nuc gen-headers` works but isn't in `nuc help`
- Build subcommand silently swallows unknown flags
- `tools/verify.sh` header still says "203 steps total as of v0.2.111"
- `nuc explain NR031` returns generic prose for legacy code modern compiler doesn't emit
- `architecture.md` hard-codes a v0.2.129 line number for `get_rt_name`
- `getting-started.md` troubleshooting row L84 advises `-o bin\nucleor.exe`, but `-o` always lands in `target/`
- README L46 launcher fallback Windows-pathed despite covering POSIX
- Showcase output 256-color escapes (renders in Windows Terminal, raw in cmd.exe)
- `tools/examples.list` doesn't include showcases

## Source-of-truth findings doc
- `docs/audit/findings/audit_recon_pass1_examples_docs_2026-05-08.md`

Plus drift observations from other layers' findings (especially Layer 1 documentation-drift Lows).

## Strategy

### Critical fixes (CLI dispatch + explain database)
1. **`nuc add | remove | update` dispatch.** Either (a) wire up the actual `install` aliasing logic, OR (b) remove the aliases from `nuc help` if they're not implemented. **Recommend (b) — remove from help. Implementation is a v1.x feature.**
2. **`nuc explain` G-series codes.** Add database entries for every G-series code (G-1 through G-11 plus their sub-codes: ALIAS-G3-*, SEND-G6-*, EFFECT-G10-*, etc.). Coordinate with Lane 3 (Lane 3 has the diagnostic-code inventory).

### High fixes
3. **`docs/language-reference.md`** — bump to v1.0; rewrite §13 corrigenda to reflect post-v1.0 state (or drop pre-v1.0 corrigenda).
4. **`examples/README.md`** — fix path: `target/hello.exe` not `./hello.exe`.
5. **`--release` / `--tier` flags.** Either implement them or remove the README/architecture mentions. **Recommend remove the mentions** — implementation is post-v1.0. Also: add **strict-flag-checking** to build subcommand (rejects unknown flags with `nuc build: unknown flag '--foo'`). The strict flag checking is a small compiler change but yields a real UX win.
6. **`docs/g1-default-flip-adopter-guide.md`** — update wording: "as of v1.0, auto-drop is the default; the `NUC_AUTO_DROP_DEFAULT=0` env var disables it (legacy mode for adopter migration)."

### Medium / Low cleanup
7. **`docs/benchmarks.md`** — re-run benchmarks on v1.0 OR mark page "PRE-V1.0; refresh pending."
8. **SARIF driver version** — bump to current `nucleor --version` output (1.0.0).
9. **`nuc gen-headers` in help** — add to `nuc help` output.
10. **`tools/verify.sh` header** — update to "1518 steps as of v1.0.0" (or current).
11. **`nuc explain NR031`** — either re-emit code path OR document as deprecated alias for the modern code.
12. **`architecture.md`** — replace hardcoded line number with a stable section reference (search-friendly).
13. **`getting-started.md` L84** — fix `-o` example.
14. **README L46** — POSIX-path the launcher fallback.
15. **Showcase color escapes** — gate 256-color output behind a `--no-color` / `NO_COLOR` env detection.
16. **`tools/examples.list`** — include showcases (or document why they're separate).

### Cross-layer doc drift
17. From Layer 1 Low findings: `language-reference.md` keyword set vs actual lexer keyword set — reconcile.

## Test mandate

- Smoke test for every CLI subcommand: `bin/nucleor.exe <subcmd>` (or with `--help`) prints reasonable output and exits 0
- Doc-link integrity check (script): every `[link](path)` in `*.md` resolves to an existing file
- `nuc explain <CODE>` for every emitted diagnostic code returns a non-empty explanation

## Verify policy

Run `bash tools/verify.sh` ONCE at end. Some changes (`nuc explain` database) touch the compiler; re-bootstrap if needed.

## Hard constraints

- Strictly mechanical; no semantic feature additions.
- For "remove vs implement" decisions: default to **remove the doc/help reference** when the feature isn't implemented. Better to have the docs match reality than to make promises the binary doesn't keep.

## Output

- Branch + report `docs/audit/lanes/LANE_7_REPORT.md`.
