# Nucleor — Module System, Packaging, and Dependency Graph Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The packaging pillar

Module system + package manager + signed releases + dependency graph constitute the layer that determines whether Nucleor is **shippable as an open-source product**. A language without a working `nuc add`, semver resolution, or POSIX signing parity is not adoptable by a real ecosystem regardless of how good the type system is.

**Headline correction:** A previous governance audit (used in the governance rod spec) reported `tools/native_release.ps1` as missing. **That report was incorrect** — the file is fully present (1017 lines) and wired through `nuc_router.ps1`. The actual missing pieces are `tools/native_lsp.ps1` and `tools/native_fmt.ps1`.

**Headline finding:** Signing is Windows-exclusive by hard-coded shell commands. `invoke_native_package_sign` calls `powershell -ExecutionPolicy Bypass` directly with no host-OS check. POSIX users get silent signing failure.

---

# Part II — Gap Inventory

## PKG-1 — Linux/macOS `nuc publish --sign` is silently broken — **CRITICAL**
`invoke_native_package_sign` and `invoke_native_package_verify` unconditionally call `system("mkdir .nuc_cache 2>NUL")` (Windows mkdir syntax) and `powershell -ExecutionPolicy Bypass`. On Linux/macOS `powershell` not found; rc != 0; function returns error result. `nuc publish --sign` on Linux prints `ERROR: native package signing failed` and exits 1.

## PKG-2 — `tools/native_lsp.ps1` and `tools/native_fmt.ps1` missing — **HIGH**
`nuc_router.ps1` references both files (lines 625, 607). Neither exists. `nuc lsp` and `nuc fmt` throw "Cannot find path" on invocation. Separate from `native_release.ps1` which IS present.

## PKG-3 — Semver constraint resolution is exact-match or `latest` only — **CRITICAL**
`registry_resolve_version_native` handles `""` → latest and `selector == version` exact match only. **No `^`, `~`, `>=X <Y`, or caret-range semantics.** RFC-0019 §3.2 promises caret (default) and range syntax. A lockfile with `foo = "1.2"` (caret shorthand) will not resolve. **Documented dependency syntax other than exact strings produces "no matching version" errors.**

## PKG-4 — `nuc registry remote add/list/remove` unimplemented — **HIGH**
Consumer-side remote registry commands documented in RFC-0019 §5.4 and printed in `export-static` help, but `run_registry_command` has no `remote` branch. **Single blocker on community consumption of published packages.**

## PKG-5 — `@cfg(feature = "X")` conditional compilation not implemented — **HIGH**
`[features]` sections parsed and stored but no compiler path consumes them. No grep match for `cfg.*feature` or `feature_enabled`. `--features hardware` to `nuc build` does not gate any code.

## PKG-6 — `nuc install --git` is non-functional stub — **MEDIUM**
Prints "deferred to v0.5" and returns exit code 0 (success). Scripted callers will not detect failure.

## PKG-7 — `pub fn` visibility enforcement absent — **MEDIUM**
`pub` keyword parsed and stored. MOD-003 in registry but resolver enforcement deferred to RFC-0018 phase 2. Currently `pub fn` and private `fn` identical at IR/linker level.

## PKG-8 — `nuc deps graph` (RFC-0061 Tier 2) does not exist — **MEDIUM**
No `deps` subcommand in router or tools suite. RFC-0061 specifies as V1.17b. ~150-200 LOC for format renderers would close it.

## PKG-9 — Per-dependency lockfile checksums are directory-level — **MEDIUM**
`package_checksum_native(parent_dir(manifest_path))` produces single checksum per package directory. RFC-0019 §3.4 shows per-file checksums. Tamper detection at package level only, not file-level integrity.

## PKG-10 — Circular import detection missing from source-resolution path — **HIGH**
`resolve_source_with_records` tracks already-imported paths for dedup but **no cycle detection**. File A importing B importing A recurses until OS native stack overflow. `lock_build_graph_recursive` has proper cycle detection; that logic not ported to source-level resolver. MOD-005 exists but never emitted from import path.

## PKG-11 — `nuc add`/`nuc remove`/`nuc update`/`nuc tree` CLI verbs absent — **MEDIUM**
RFC-0019 §3.6 lists these. None in dispatch. Users expecting `nuc add serde` (Cargo idiom) get unrecognized-command error.

## Cross-cutting risks
- **Signing bridge Windows-exclusive by hard-coded commands.** Both invoke functions contain Windows-only `2>NUL`, `del /q`, `powershell` calls without `host_is_windows()` guard. Host-OS abstraction functions exist but were not applied.
- **Two referenced native wrapper scripts missing** — `nuc fmt`/`nuc lsp` broken regardless of platform.
- **Module import cycles cause runtime stack overflow rather than MOD-005.** Distinct from `lock_build_graph_recursive` cycle check (covers package dep graph only, not source import graph).
- **`nuc install --git` exits 0 on a stub** — scripted pipelines won't detect failure.

---

# Part III — RFC

## 3.1. Goals
1. Close PKG-1 and PKG-3 immediately — these are the launch blockers for non-Windows or non-trivial dependency users.
2. Restore `tools/native_lsp.ps1` and `tools/native_fmt.ps1` so the routing isn't broken.
3. Implement remote registry consumption + standard Cargo-style CLI verbs.
4. Cycle detection on source imports.

## 3.2. Closure plan

**Phase 1 (emergency):**
- PKG-1: rewrite `invoke_native_package_sign` and `invoke_native_package_verify` with `host_is_windows()` guard. POSIX path uses `bash tools/native_release.sh` (see PKG-1 P2 below). Windows path unchanged. Use existing `host_null_redirect`/`host_remove_file_quiet` abstractions instead of hard-coded `2>NUL`/`del /q`.
- PKG-2: restore `tools/native_lsp.ps1` (LSP server entrypoint) and `tools/native_fmt.ps1` (formatter entrypoint). Even stub implementations that print "(not yet implemented)" are better than missing files that crash the router.
- PKG-3 P1: emit clear diagnostic when caret/tilde/range syntax is encountered: "Semver constraint syntax `^1.2` not yet supported. Use exact version `1.2.0` or `latest`. Tracking in v0.5+."
- PKG-6: change `nuc install --git` stub to exit code 1 instead of 0, so scripted callers detect failure.
- PKG-10 P1: add cycle-detection to `resolve_source_with_records` using a stack identical to `lock_build_graph_recursive`. Emit MOD-005 with the cycle path.

**Phase 2 (short-term):**
- PKG-1 P2: `tools/native_release.sh` — POSIX equivalent using `openssl` or `ssh-keygen -Y sign/verify`. Same JSON output schema, same DSSE attestation format, identical semantics on both platforms.
- PKG-3 P2: implement caret semver (`^1.2.3` matches `>=1.2.3 <2.0.0`) and tilde semver (`~1.2.3` matches `>=1.2.3 <1.3.0`) in `registry_resolve_version_native`. Use simple version-vector comparison; no full PubGrub yet.
- PKG-4: implement `nuc registry remote add/list/remove`. Store remote registry URLs in `~/.nucleor/registries/<name>.toml`. `nuc install` first checks local registry, then walks remote registries in declared order.
- PKG-7: enforce `pub fn` cross-module visibility at import time. Resolver checks visibility flag when an import references a non-`pub` symbol from another module. Emit MOD-003.

**Phase 3 (medium-term):**
- PKG-5: implement `@cfg(feature = "X")` conditional compilation. Compiler reads `--features` flag, expands to set of enabled features, gates `@cfg` annotations.
- PKG-6 P2: real `nuc install --git <url>` via `git clone` + cache + lockfile entry.
- PKG-8: `nuc deps graph [--format=text|json|dot|mermaid]` per the graph remediation spec.
- PKG-9: per-file checksums in lockfile.
- PKG-11: implement `nuc add <pkg>`, `nuc remove <pkg>`, `nuc update [<pkg>]`, `nuc tree`. Standard Cargo-style ergonomics.

**Phase 4 (v1.0 gate):**
- Full PubGrub semver resolution (vs simple caret/tilde from Phase 2).
- Remote registry TLS download (depends on TLS rod — likely v0.5+).
- Workspace `nuc build` from root that selects and builds all members.

## 3.3. v1.0 release gate
Phases 1-2 minimum. Phase 3 strongly preferred for adoption. Phase 4 (PubGrub + TLS download) can ship as v1.x if simple semver + local registry covers initial adopters.

## 3.4. Open questions
1. POSIX signing: `openssl pkeyutl` or `ssh-keygen -Y sign/verify`? Recommendation: `ssh-keygen -Y` for parity with Windows path; widely available on Linux/macOS.
2. `nuc add` should it edit `Nucleor.toml` directly (Cargo-style) or print the line for user to paste? Recommendation: edit directly, with a confirmation prompt.
3. Should `nuc fmt` and `nuc lsp` ship as stubs in Phase 1 or be removed from the router until real implementations exist? Recommendation: stubs that print "(not yet implemented)" — preserves the CLI surface.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
