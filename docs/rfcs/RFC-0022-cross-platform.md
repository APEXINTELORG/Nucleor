# RFC-0022 — Cross-Platform: Linux, macOS, cross-compilation

| Field | Value |
|---|---|
| **Number** | 0022 |
| **Title** | Cross-platform — Linux, macOS, cross-compile to ARM/RISC-V |
| **Status** | Implemented (partial) v0.1.30 — see `docs/milestones/v0.2.0.md`; v0.2 ships POSIX `nuc` shell wrapper + `_WIN32` audit, Linux/macOS native bins targeted v0.3.0, sysroots v0.5.0 |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 (POSIX `nuc` wrapper + `_WIN32` audit — shipped v0.1.30) → v0.3.0 (native Linux/macOS `bin/nucleor` binaries) → v0.5.0 (full cross-compilation + sysroots) |
| **Depends on** | RFC-0018 (modules — for path semantics) |

---

## 1. Summary

Make Nucleor build and run natively on Linux x86_64 and macOS
(arm64 + x86_64), in addition to the current Windows-only support.
Add cross-compilation: build from any host to any target.

```bash
nuc build                                 # native target
nuc build --target=aarch64-apple-darwin   # cross
nuc build --target=thumbv7em-none-eabihf  # embedded (v0.6)
```

Open-source language being Windows-only is a non-starter for ~80%
of the audience.

---

## 2. Motivation

Today: Windows-only. Reasons (all fixable):
- Verify gate is `verify.ps1` PowerShell.
- `nuc.bat` exists; `nuc` shell wrapper is stub.
- Some `_rt.c` files have unguarded `_WIN32` Windows API calls
  (mmap, sockets, serial).
- LLVM target triple defaults to host.

Linux / macOS users represent the majority of OSS systems-language
developers. v0.2 must remove this barrier.

---

## 3. Design

### 3.1 Tier-1 targets (v0.2)

| Triple | OS | Arch | Status |
|---|---|---|---|
| `x86_64-pc-windows-msvc` | Windows | x86_64 | existing |
| `x86_64-unknown-linux-gnu` | Linux (glibc) | x86_64 | NEW |
| `aarch64-unknown-linux-gnu` | Linux | ARM64 | NEW |
| `x86_64-apple-darwin` | macOS Intel | x86_64 | NEW |
| `aarch64-apple-darwin` | macOS Apple Silicon | ARM64 | NEW |

### 3.2 Tier-2 targets (v0.5)

- `x86_64-unknown-linux-musl` — static linking (Alpine, distro-less)
- `riscv64gc-unknown-linux-gnu` — RISC-V Linux (StarFive, Sipeed)
- `wasm32-unknown-unknown` — WebAssembly (host execution path; not
  Nucleor → WASM compiler — that's still N/A)

### 3.3 Tier-3 targets (v0.6+)

- `thumbv7em-none-eabihf` — Cortex-M4F
- `thumbv8m.main-none-eabihf` — Cortex-M33
- `riscv32imac-unknown-none-elf` — RV32 MCU
- `aarch64-unknown-none` — bare-metal ARM64 (e.g., Cortex-A on Pi)

### 3.4 Build wrappers

- `nuc` — POSIX shell script, replaces stub
- `nuc.bat` — Windows existing
- `nuc.ps1` — PowerShell existing
- `nuc-cargo`-style native binary, ships per-platform

### 3.5 Verify gate cross-platform

`tools/verify.sh` — Bash equivalent of `verify.ps1`. Same gates,
same exit codes. CI runs both.

After RFC-0021's test framework lands, retire both shell drivers in
favor of `nuc test`.

### 3.6 Runtime audit for cross-platform

| Module | Status |
|---|---|
| `socket_rt.c` | Already POSIX-leaning; add Windows Winsock guards |
| `mmap_rt.c` | Already POSIX; add Windows `MapViewOfFile` shim |
| `serial_rt.c` | Already cross-platform |
| `time_rt.c` | OK; needs `clock_gettime` on Linux |
| `process_rt.c` | New; abstract `posix_spawn` vs `CreateProcessW` |
| `fs_rt.c` | Needs path-separator handling; recommend always `/` internally, normalize on Windows boundary |

### 3.7 Cross-compilation

LLVM does the heavy lifting. Compiler emits `.ll` IR; clang with
`--target=<triple>` produces target object code.

For C runtime cross-compilation: ship a sysroot per Tier-1/Tier-2
target via `nuc install sysroot --target=<triple>` (downloads from
nucleor.dev/sysroots/).

### 3.8 Path handling

Nucleor source uses `/` as path separator everywhere. Compiler
normalizes to OS native at file-system boundary. Windows tests use
the `path::PathBuf` API which abstracts.

### 3.9 CI matrix

```yaml
strategy:
  matrix:
    os: [ubuntu-24.04, windows-latest, macos-14]
    arch: [x64, arm64]
    exclude:
      - os: ubuntu-24.04
        arch: arm64    # use ubuntu-22.04-arm64 if needed
```

Every PR runs all 5 host combinations. Cross targets tested via
QEMU.

### 3.10 Diagnostics

| Code | Meaning |
|---|---|
| TGT-001 | Unknown target triple |
| TGT-002 | Sysroot not installed for target — run `nuc install sysroot --target=...` |
| TGT-003 | Feature unsupported on target (e.g., `mmap` on bare-metal) |
| TGT-004 | Cross-link error — likely missing C library |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| `nuc` shell wrapper (POSIX) | Replace stub | ~150 |
| `tools/verify.sh` | Mirror verify.ps1 | ~300 |
| Runtime audit + Linux/macOS shims | Across ~15 `_rt.c` files | ~600 |
| Sysroot manager (`nuc install sysroot`) | Download + verify | ~400 |
| Cross-compile driver | Target triple plumbing | ~250 |
| CI workflows (GitHub Actions) | Multi-OS matrix | ~200 |
| Diagnostics | TGT-001…004 | ~100 |
| **Total** | | **~2000** |

---

## 5. Alternatives considered

- **Stay Windows-only** — non-starter for OSS.
- **Linux only initially** — macOS users are robotics researchers; ship
  both.
- **Use Rust's cross tool** — works but adds dep; ship native.

## 6. Open questions

1. macOS code signing — necessary for distribution? Recommend
   `nucleor.dev` ships notarized binaries; users can build local
   without signing.
2. Static vs dynamic linking on Linux — recommend dynamic for
   Tier-1, static-musl for Tier-2.
3. Windows ARM64 — defer; low demand currently.
4. FreeBSD / OpenBSD — community-maintained Tier-3.
5. Apple Silicon JIT codesign — only if we add a JIT (we don't, v0.x).

## 7. Definition of done

- [ ] `nuc build` works on all 5 Tier-1 host/arch combos
- [ ] `verify.sh` passes 101+ on Linux + macOS
- [ ] CI matrix green
- [ ] Cross-compilation to one Tier-2 target tested
- [ ] CHANGELOG documents

## 8. Future extensions

- BSDs (FreeBSD, OpenBSD)
- Solaris / illumos (community)
- Android / iOS (v0.7+ if user demand)
- WASI target

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2000 fits
- [ ] CI infrastructure ready
- [ ] Pitch survives ("Linux + macOS + Windows from day one")
