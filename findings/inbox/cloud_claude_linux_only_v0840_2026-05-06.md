# Cloud Claude Linux-Only Lane v0840 — Findings (2026-05-06)

Lane: `fix/cloud-claude-linux-only-v0840`
RFC: `docs/rfcs/CLOUD_CLAUDE_LINUX_ONLY_CONTINUATION_v0840_2026-05-06.md`
Audience: cloud Claude on a true native Linux host (no WSL / Wine / `.exe`).

## Branch state

| field        | value                                                                  |
| ------------ | ---------------------------------------------------------------------- |
| branch       | `fix/cloud-claude-linux-only-v0840`                                    |
| cloud proof base | `d5b8d611f34a68e55e830bb32a9a5ddc3e66fa38`                         |
| cloud report commit | `c18a2076` (`docs(findings): cloud Claude Linux-only v0840 proof bundle`) |
| integration base | `d3bbd9d4` after Helper2 Wave 4 assignment                          |
| previous tip | `dc61411a` (PKG-1 signed publish + R06 rust_bridge ownership; v0839)   |
| working tree | clean (no source files modified — only ignored build/target artifacts) |

`d5b8d611` is a docs-only commit on top of `dc61411a`. All proof on this lane
runs against the merged tip. Main-agent integration cherry-picked the report
onto current main as report-only evidence; it does not change source, tooling,
bootstrap, binaries, or baselines.

## Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```

True native Linux x86_64 (kernel 6.18.5). `/proc` present. No WSL / Wine /
copied Windows artifacts used as POSIX evidence.

### Tool inventory (paths + versions)

| tool         | path                          | version / note                                                |
| ------------ | ----------------------------- | ------------------------------------------------------------- |
| `clang`      | `/usr/bin/clang`              | Ubuntu clang version 18.1.3 (target `x86_64-pc-linux-gnu`)    |
| `cargo`      | `/root/.cargo/bin/cargo`      | cargo 1.94.1 (29ea6fb6a 2026-03-24)                           |
| `rustc`      | `/root/.cargo/bin/rustc`      | rustc 1.94.1 (e408947bf 2026-03-25)                           |
| `bash`       | `/usr/bin/bash`               | GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu)     |
| `python3`    | `/usr/local/bin/python3`      | Python 3.11.15                                                |
| `bin/nucleor`| `/home/user/Nucleor/bin/nucleor` | nucleor 0.8.323; ELF 64-bit LSB pie, x86-64, GNU/Linux 3.2.0 |
| `pwsh`       | NOT INSTALLED                 | hard prereq for full PKG-1 real-sign and verify legs          |
| `ssh-keygen` | NOT INSTALLED                 | hard prereq for `tools/native_release.ps1 keygen`             |

`pwsh` is not in the default Ubuntu apt index (`E: Unable to locate package
powershell`); it requires Microsoft's external apt repo. `openssh-client`
(which provides `ssh-keygen`) is in apt but not currently installed.

### `bin/nucleor` provenance for this lane

`bin/nucleor` was produced on this host from
`bootstrap/nucleor_s1_seed.ll` via `tools/bootstrap_linux.sh --seed-only`.

```
$ bash tools/bootstrap_linux.sh --seed-only
==> stage-1 link: clang bootstrap/nucleor_s1_seed.ll + runtime → bin/nucleor
    /usr/bin/ld: warning: -z stacksize=16777216 ignored
    stage-1 binary: 2160136 bytes
    stage-1 --version: nucleor 0.8.323 (self-hosted, llvm backend)
==> --seed-only: stopping after stage-1 (verify.sh handles self-rebuild)
real    0m4.246s
$ file bin/nucleor
bin/nucleor: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV),
  dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2,
  BuildID[sha1]=3465c903c37c03b1cb60fec53f1e8374c8f74a67,
  for GNU/Linux 3.2.0, not stripped
$ ./bin/nucleor --version
nucleor 0.8.323 (self-hosted, llvm backend)
```

This is a true POSIX ELF, not a copied Windows artifact. The tracked
`bin/nucleor.exe` (Windows) was not used and is not accepted by the doctors.

## Slice 1 — Native Linux cold/hot perf proof — PASS

Doctor:

```
$ bash tools/check_perf_regression.sh --doctor
doctor native-linux: OK - kernel=Linux osrelease=6.18.5
doctor linux-proc: OK - /proc is present
doctor required-shell-tools: OK - awk grep sed sort date mktemp rm tail bash setsid
doctor clang: OK - /usr/bin/clang
doctor run-capped: OK - /home/user/Nucleor/tools/run_capped.sh
doctor baseline-and-source: OK - baseline=tools/perf_baseline.json source=compiler/nucleor_s1_compiler.nr
doctor native-executable: OK - /home/user/Nucleor/bin/nucleor
doctor elf-proof: OK - /home/user/Nucleor/bin/nucleor: ELF 64-bit LSB pie ...
doctor result: ready for native POSIX perf evidence
rc=0
```

The script's default baseline (`tools/perf_baseline.json`) is the **Windows**
baseline (cold 3.73 s, max 4.0 s). Running against it on Linux produces a
spurious 2.4× "regression" (cold 9.09 s) — that is by design; Linux runners
must pass `--baseline tools/perf_baseline_linux.json`.

Run against the Linux baseline (`v0.8.323-rfc0063-phase1.3-linux-baseline`,
locked 2026-05-06, cold 9.05 s / 10.0 s ceiling, hot 0.47 s / 1.0 s ceiling,
350 MB cold / 64 MB hot process-tree RSS):

```
$ bash tools/check_perf_regression.sh --baseline tools/perf_baseline_linux.json --verbose
sample cold 1: 8.165s, process_tree=316MB, cache: miss -> stored (sha=abf9949307b0, 11 MB)
sample cold 2: 7.946s, process_tree=317MB, cache: miss -> stored
sample cold 3: 7.729s, process_tree=317MB, cache: miss -> stored
sample hot  1: 0.950s, process_tree= 56MB, cache: hit
sample hot  2: 0.959s, process_tree= 54MB, cache: hit
sample hot  3: 1.031s, process_tree= 52MB, cache: hit
OK POSIX perf: cold=7.95s (max 10.0s) | hot=0.96s (max 1.0s) |
  mem cold_tree=317/350MB cold_compiler=n/a hot_tree=56/64MB hot_compiler=n/a
  note: POSIX gate enforces Linux process-tree RSS via tools/run_capped.sh;
        compiler-only RSS split remains Windows-only in this prep branch.
real    0m26.946s
rc=0
```

Result: **PASS**. Cold is 7.95 s vs 9.05 s baseline (12% under, 21% under
ceiling). Hot is 0.96 s vs 0.47 s baseline (2.0× baseline) but still within
the 1.0 s ceiling. No regression vs the Linux locked baseline.

Note for whoever owns RFC-0063 Phase 4: the hot path is pressing right against
the 1.0 s ceiling on this host (sample 3 = 1.031 s would have failed; the
script keys off the median, so 0.959 s passed). Worth a fresh sample sweep
before tightening.

## Slice 2 — Native Linux package signed publish regression proof — PARTIAL

Dry-run leg — PASS. Real-sign + verify legs — BLOCKED by missing `pwsh` and
`ssh-keygen`. The dispatch contract from
`docs/rfcs/CLOUD_CLAUDE_PKG_R06_LINUX_PROOF_DISPATCH_v0839_2026-05-06.md`
Scope A requires both prerequisites; this lane is forbidden from broad
compiler changes, and installing `pwsh` requires adding the Microsoft apt
repo (not a "small Linux-only script/docs fix").

Tractable evidence captured:

```
$ ./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
  ...
  emitted: target/nucleor_tools.ll (7001940 bytes)
  compiled: target/nucleor_tools
real    0m4.328s

$ cp target/nucleor_tools bin/nucleor_tools   # see "operational note" below

$ tmp=$(mktemp -d); registry=$tmp/nucleor-registry; keydir=$tmp/nucleor-keys
$ mkdir -p "$registry" "$keydir"; export NUCLEOR_POLICY_ROOT="$keydir"

$ ./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
    --registry "$registry" --dry-run --sign --key-id throwaway-ci
publish dry-run: no files copied, no registry metadata written,
                  no checksums written, no signatures created
manifest: tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml
package: foo
version: 0.1.0
registry: /tmp/tmp.2BQTqbe9Hc/nucleor-registry
registry_package_dir: /tmp/tmp.2BQTqbe9Hc/nucleor-registry/foo/0.1.0
export_manifest_target: /tmp/tmp.../foo/0.1.0/Nucleor.exports.json
metadata_target:        /tmp/tmp.../foo/0.1.0/Nucleor.publish.json
checksum_target:        /tmp/tmp.../foo/0.1.0/Nucleor.package.sha256
signature_target:       /tmp/tmp.../foo/0.1.0/Nucleor.publish.signature.json
signing_key_id: throwaway-ci
rc=0

$ test ! -e "$registry/foo/0.1.0/Nucleor.publish.signature.json" && echo OK
OK
```

Proof: dry-run with `--sign --key-id throwaway-ci` exits 0, prints the
intended targets, and writes **no** signature file (no registry directory was
created at all). The previous PKG-1 dispatch's first contract bullet
("dry-run signed publish writes no signature") is satisfied on this Linux
host against `dc61411a` / `d5b8d611`.

Real-sign + verify legs are blocked. Exact missing commands:

```
$ command -v pwsh
$ command -v ssh-keygen
# both empty; both required by the dispatch's Scope A
```

Specifically blocked from running:
- `pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen throwaway-ci --json`
- second `./bin/nucleor publish ... --sign --key-id throwaway-ci` (real)
- `pwsh -NoProfile -File tools/native_release.ps1 -Root . package-sign-preflight ...`
- `pwsh -NoProfile -File tools/native_release.ps1 -Root . package-verify ...`

These four legs cannot complete without `pwsh` (PowerShell on Linux) and
`ssh-keygen`. Recommended environment fix (out of this branch's scope):

```bash
sudo apt-get install -y openssh-client                       # ssh-keygen
# pwsh:
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y powershell
```

### Operational note: `nucleor_tools` resolution bug on POSIX

To make even the dry-run leg work, `target/nucleor_tools` had to be copied to
`bin/nucleor_tools`. Root cause is in `compiler/nucleor_s1_compiler.nr`
inside `run_external_tool` (around line 37288):

```nucleor
let repo_tool_path: str =
    host_shell_path(str_concat(str_concat(".\\target", host_target_path_sep()), tool_name));
let repo_bin_tool_path: str =
    host_shell_path(str_concat(str_concat(".\\bin",    host_target_path_sep()), tool_name));
```

Both `repo_tool_path` and `repo_bin_tool_path` literal-concatenate `.\\` (a
Windows path prefix) **unconditionally**, even when `host_target_path_sep`
returns `/`. On Linux the lookup builds e.g. `.\target/nucleor_tools`, which
no `fs_exists` will match. The third candidate (`local_tool_path`) is gated
correctly with `if host_is_windows() == 1 { ".\\" } else { "./" }`, which is
why placing the binary at the repo root (or `./bin/`, since exe_dir is then
`./bin`) does work.

This is a real cross-platform bug, not a packaging quirk. It is not fixed on
this branch because the lane's RFC forbids broad compiler changes, the fix
requires re-bootstrapping (and is best paired with a seed refresh — see
Slice 4), and it is not a "small Linux-only script/docs fix". Recommend
filing as a follow-up on the next compiler-touching lane:

> `compiler/nucleor_s1_compiler.nr#run_external_tool`: replace the literal
> `.\\target` / `.\\bin` prefixes with `host_dot_prefix() + "target"` /
> `+ "bin"`, where `host_dot_prefix()` returns `".\\"` on Windows and `"./"`
> on POSIX (mirroring the existing `local_tool_path` pattern).

## Slice 3 — POSIX `rust_bridge` ownership repeat proof — PASS

Full evidence chain:

```
$ bash tools/check_rust_bridge_ownership.sh --doctor
doctor cargo: OK - /root/.cargo/bin/cargo
doctor bridge-crate: OK - stdlib/rods/rust_bridge
doctor release-artifact: OK - not present yet; normal run will build via cargo
doctor compiler-binary: OK - /home/user/Nucleor/bin/nucleor
doctor focused-fixture:string-free: OK - tests/features/rust_bridge_string_free_smoke.nr
doctor fixture-buildable: OK
doctor result: ready for POSIX rust_bridge ownership harness
rc=0

$ bash tools/check_rust_bridge_ownership.sh --doctor --json | jq .result_status
"ready"

$ bash tools/check_rust_bridge_ownership.sh --self-test
self-test selector:string-free: OK
self-test selector:hash:        OK
self-test selector:all:         OK
self-test selector:invalid:     OK
self-test json:required-keys:   OK
self-test fail-closed:cargo:            OK
self-test json:fail-closed:cargo:       OK
self-test fail-closed:compiler:         OK
self-test json:fail-closed:compiler:    OK
self-test fail-closed:bridge-artifact:  OK
self-test json:fail-closed:bridge-artifact: OK
self-test result: passed
rc=0

$ bash tools/check_rust_bridge_ownership.sh --self-test --json | jq .result_status
"passed"

$ bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
[builds nucleor_rust_bridge v0.1.0 release in 11.69s]
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr
building focused fixture: tests/features/rust_bridge_hash_determinism_smoke.nr
OK rust_bridge ownership: fixture_selector=all iterations=20
   fixture_executions=40 fixture_alloc_free_cycles=2040
   bridge_artifact=stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
   executable=target/_rust_bridge_ownership_check
real    0m13.568s
rc=0

$ bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json | jq .
{
  "schema_version": 1,
  "host_family": "posix",
  "mode": "run",
  "fixture_selector": "all",
  "iterations_requested": 5,
  "fixture_executions_completed": 10,
  "cargo": {"present": true, "native": true, "path": "/root/.cargo/bin/cargo"},
  "bridge_artifact": {"present": true, "path": ".../libnucleor_rust_bridge.a"},
  "compiler": {"present": true, "path": "/home/user/Nucleor/bin/nucleor"},
  "result_status": "passed",
  "fixtures": [
    {"key": "string-free", "rust_owned_free_cycles_per_execution": 100},
    {"key": "hash",        "rust_owned_free_cycles_per_execution": 2}
  ]
}

$ file stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
... current ar archive (Linux native, 26597926 bytes)
```

Result: **PASS**. Doctor + self-test + 20-iteration `all` fixture + 5-iteration
`all --json` all green. `libnucleor_rust_bridge.a` is a native Linux `ar`
archive (not a Windows `.lib`). The R06 dispatch contract for Scope B is
satisfied on this Linux host against `dc61411a` / `d5b8d611`.

## Slice 4 — Linux bootstrap / fixed-point — BLOCKED on stale seed

Per dispatch ("stop at precise blocker evidence if the stale seed is the
issue"). Full bootstrap (no `--seed-only`):

```
$ bash tools/bootstrap_linux.sh
==> stage-1 link: clang bootstrap/nucleor_s1_seed.ll + runtime → bin/nucleor
    stage-1 binary: 2160136 bytes
    stage-1 --version: nucleor 0.8.323 (self-hosted, llvm backend)
==> stage-2 self-rebuild: bin/nucleor build compiler/nucleor_s1_compiler.nr
==> fixed-point check: target/nucleor_s2.ll vs bootstrap/nucleor_s1_seed.ll
bootstrap_linux: fixed-point check FAILED
    seed sha256:    e0c534adb4a567efa59b6245847012671779c5456d297c4c6f9a30f8272c03fd
    stage-2 sha256: 2af30934f22078171d81d940d02c81b43b076ac39e4af559538cf6107759c9d6
    refresh the seed (bootstrap/README.md) and retry
real    0m2.836s
rc=1
```

Sizes: seed `bootstrap/nucleor_s1_seed.ll` = 11,472,180 B; stage-2
`target/nucleor_s2.ll` = 11,519,447 B (Δ +47,267 B / +0.41%). Stage-1
`bin/nucleor` reports the same `nucleor 0.8.323 (self-hosted, llvm backend)`
as the merged tip, so the seed is from the same advertised version but a
different snapshot of compiler source (or a different host's emission).

This is exactly the "stale seed" blocker the dispatch flags. Resolution path
is non-trivial and outside this lane:

- The seed is normally refreshed from a Windows build (per
  `bootstrap_linux.sh` header comment: "the IR seed [is] emitted by the
  Windows build, target-agnostic IR"). A fresh seed is therefore tied to a
  Windows ship, which this lane is forbidden from touching.
- A Linux-only path would require a known-good Linux stage-2 to seed itself,
  which presumes a working stage-2 — circular until either the source moves
  back to fixed-point against the existing seed, or a fresh seed is dropped
  in.
- See `bootstrap/README.md` for the canonical refresh procedure.

Stopping at this blocker, as instructed. Stage-1 still produces a working
0.8.323 binary that passes Slices 1 and 3, so this stale-seed blocker did not
gate the rest of the lane — but it does block any "promoted compiler" perf
sweep (which is why the Linux baseline is loosely dominated by stage-2 cost
right now).

## Outstanding Linux-only blockers (carry-forward)

1. **Stale `bootstrap/nucleor_s1_seed.ll`** (Slice 4). Refresh per
   `bootstrap/README.md` so `tools/bootstrap_linux.sh` (no flags) reaches
   step 6 (promote) on Linux. Until then, Linux CI must use
   `bootstrap_linux.sh --seed-only`.
2. **`pwsh` and `ssh-keygen` not installed** on cloud Linux runners (Slice 2).
   Required by `tools/native_release.ps1` (`keygen`, `package-sign-preflight`,
   `package-verify`). Real-sign + verify legs of PKG-1 cannot be proven on
   Linux until both are in the runner image.
3. **POSIX path bug in `run_external_tool`** (`compiler/nucleor_s1_compiler.nr`
   ~L37288). Hard-coded `.\\target` / `.\\bin` prefixes break the
   tools-suite resolution chain on POSIX so that only the cwd-local
   (`./<tool>`) candidate works. Workaround on Linux today: copy/symlink
   `target/nucleor_tools` → `bin/nucleor_tools` (or repo root). Real fix is
   a 2-line change paired with the next stage-2 promote.
4. **Hot self-build is at the ceiling** on this runner (Slice 1: hot p50
   0.96 s vs 1.0 s ceiling, individual sample 1.031 s). Linux baseline
   `v0.8.323-rfc0063-phase1.3-linux-baseline` was locked 2026-05-06 with
   hot p50 0.47 s. The doubling on this host is well under the ceiling but
   worth a fresh sample sweep before any tightening.
5. **Compiler drift warnings** (`tools/check_compiler_drift.sh`): three
   parser fns (`parse_match_stmt`, `parse_stmt`, `parse_expr`) diverge
   between `compiler/nucleor_s1_compiler.nr` and the tools-suite. Tracked
   as RFC-0063 Phase 2.0 (parser unification). Same script also reports
   `FAIL: promoted compiler binary version is stale` — this is the
   Windows-side `bin/nucleor.exe` check; out of this Linux-only lane.

## Files changed by this branch

No source files changed. The only committed file is this report. All evidence
is report-only; no Linux-only script/doc patches were required to make the proof
commands valid. The only operational adjustment was the
`cp target/nucleor_tools bin/nucleor_tools` workaround documented in Slice 2,
which is a runtime-side workaround for a tracked compiler bug, not a code
change.

## Index of raw transcripts (host-local; not committed)

| log                          | scope                                |
| ---------------------------- | ------------------------------------ |
| `/tmp/perf_run_linux.log`    | Slice 1 perf sweep                   |
| `/tmp/publish_dryrun.log`    | Slice 2 dry-run                      |
| `/tmp/rb_doctor.json`        | Slice 3 `--doctor --json`            |
| `/tmp/rb_selftest.json`      | Slice 3 `--self-test --json`         |
| `/tmp/rb_fixture20.log`      | Slice 3 `--fixture all --iterations 20` |
| `/tmp/rb_fixture5.json`      | Slice 3 `--fixture all --iterations 5 --json` |
| `/tmp/bootstrap_full.log`    | Slice 4 fixed-point failure          |
