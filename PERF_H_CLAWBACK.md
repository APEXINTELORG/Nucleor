# §H Perf Clawback — FIXED

**Branch:** `review/h-perf-clawback`
**Parent:** `review/v1.1.1-TZ8Qc` @ `2dc3cfc1` (§H Phase A landed)
**Status:** Closed. **Cold compile 4.69 s → 3.30 s** — beats the OLD
v1.1.1-era baseline (3.55 s) while keeping §H and all post-v1.1.1
correctness landings.

## Final numbers (Windows, this machine, Defender exclusions in place)

| State | Cold | Hot | Bin size |
|---|---|---|---|
| Pre-§H, OLD committed bin (v1.1.1 era) | 3.548 s | 0.159 s | 1.55 MB |
| Post-§H, NEW bin, default link (no LTO) | **4.69 s** ❌ | 0.252 s | 2.67 MB |
| **Post-§H, NEW bin, LTO + ICF + REF** | **3.30 s** ✓ | 0.26 s | **1.18 MB** |

vs the user-stated <4.0 s target: **✓ comfortably under, by 700 ms**.

## What didn't work (and why)

Initial dig-in chased compiler-side optimizations:
- MEM-3 escape-analysis tightening: ruled out — A/B showed 0 drop calls
  in type_expr's IR in either bin.
- Hot-path str_eq dispatch: ruled out — both bins emit byte-identical
  IR for type_expr (19,764 LLVM lines, 127 str_eq calls in both).
- Source-level changes: ruled out — type_expr is *smaller* today (680
  lines in kind==7) than at v1.1.0 (744 lines).

The cumulative finding: **same source + same compiler emit = byte-identical
IR (md5 `fb63619530d074cdeee1da716fecbbb4` in both bins)**. The
regression was not at the IR level; it was in how Windows executed the
larger compiled binary.

## What worked

**Link-time optimization on the bootstrap link.** The OLD committed
bin and the NEW rebuilt bin had both been linked at `-O0` (default
clang for the bootstrap-style link). The OLD bin happened to be small
because it was built from smaller v1.1.1-era source; the NEW bin was
big because current source is ~25% larger.

Re-linking the NEW bin with `-O2 -flto -Wl,/OPT:ICF -Wl,/OPT:REF`:
- **Bin shrinks 2.67 MB → 1.18 MB (−56%)** — smaller than the OLD bin
- **Cold compile 4.69 s → 3.30 s (−30%)** — faster than the OLD bin
- **IR output unchanged** (md5 identical to non-LTO bin's output)
- **Bootstrap fixed point holds** trivially (`check_self_host_md5.sh`
  passes byte-identical)

LTO doesn't change the compiler's *behavior* — it just lets the linker
do whole-program optimization, fold identical code blocks, and strip
unreferenced symbols across the 9,597-line runtime + the s1 IR.

## Changes shipped on this branch

1. `bin/nucleor.exe` replaced with LTO/ICF/REF-linked version (1.18 MB).
2. `tools/bootstrap_windows.ps1` updated to add `-flto`,
   `-Wl,/OPT:ICF`, `-Wl,/OPT:REF` to the bootstrap clang invocation so
   future seed regens produce the optimized bin automatically.
3. `tools/perf_baseline.json` cold ceilings tightened back down:
   `cold_self_build_seconds` 3.73 → 3.30 (measured), `cold_max_allowed_seconds`
   4.25 → 4.00 (the user's stated target as the new gate).
4. This document.

## Constraints honored

- §H stays. No reverting RFC-NRT-004.
- Self-host fixed point intact (`fb63619530d074cdeee1da716fecbbb4`).
- Zero correctness regressions: no source change to compiler/, runtime/,
  or stdlib/ — only the link flags + bin binary + baseline.
- Linux unaffected (the per-compile clang link there is governed by
  `tools/bootstrap_linux.sh`, not touched here; the regression
  investigated was Windows-specific).

## Future work (not required)

- Linux equivalent: `tools/bootstrap_linux.sh` could also adopt
  `-flto -Wl,--icf=all -Wl,--gc-sections`. Linux didn't see the
  Windows-style regression so it's lower priority, but the binary
  size win (~50%) is real on either platform.
- `compiler/s1/cache.nr` general-build link path also defaults to
  `-O0` for user programs. A `--release` flag that opts user programs
  into the same LTO pipeline would be a clean follow-up RFC (not
  scoped here).
