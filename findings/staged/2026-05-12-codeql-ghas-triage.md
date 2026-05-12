# CodeQL GHAS Triage and Fix Report

## Scope

- Repository: `APEXINTELORG/Nucleor`
- Baseline HEAD: `57e9ad109dec9cd2d209681838d576a233193c90`
- CodeQL CLI: `2.25.4`
- Query packs: `codeql/cpp-queries@1.6.2`, `codeql/actions-queries@0.6.27`
- Full C/C++ extraction command: `codeql database create ... --language=cpp --command "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...\codeql_full_c_extract.ps1"`
- Project-build extraction note: the normal project build database scanned only 4 of 203 C/C++ files, so the full extraction database was used for assessment-equivalent coverage.

## Results

| Rule | Baseline local count | Final local count | Disposition |
|---|---:|---:|---|
| `cpp/integer-multiplication-cast-to-long` / assessment `cpp/integer-multiplication-cast-to-larger` | 345 | 0 | Fixed |
| `cpp/overflowing-snprintf` | 1 | 0 | Fixed |
| `cpp/toctou-race-condition` / `TOCTOUFilesystemRace` | 0 | 0 | No local SARIF finding; adjacent copy-file race hardened |
| `actions/missing-workflow-permissions` | 3 | 0 | Fixed |

## Accounting

- Total local SARIF findings in target classes: 349.
- Fixed local SARIF findings: 349.
- Dismissed as false positive: 0.
- Deferred local SARIF findings: 0.
- Assessment mismatch: the current CodeQL pack emitted 0 C/C++ TOCTOU findings. Manual review found and hardened the adjacent `stat(from)` then `chmod(to, mode)` copy-file pattern by taking the source mode from `fstat(fileno(fi))` after opening the source stream.

## Fix Strategy

- Integer multiplication: cast one multiplicand to `size_t` or the destination arithmetic type before the multiply. This keeps behavior surgical and avoids changing hot-loop variable types.
- `snprintf`: track the remaining buffer length, clamp the consumed length to the bytes actually available, and leave room for the trailing terminator.
- TOCTOU hardening: replace the post-copy `stat(from)` check with `fstat` on the already-open source stream before the source can be swapped between check and use.
- GitHub Actions: add a top-level `permissions: contents: read` block because the workflow only needs repository checkout/read access.

## Multiplication Root Patterns

The 345 integer multiplication findings reduce to 28 normalized syntactic root patterns in the reproduced SARIF. The full per-location CSV remains at `C:\Users\JoeWe\Desktop\Nucleor_GHAS_CodeQL_Artifacts_20260512\integer_multiplication_locations.csv`.

| Group | Count | Pattern |
|---|---:|---|
| MUL-01 | 147 | `malloc` allocation: `DIM * DIM` elements of `double` |
| MUL-02 | 93 | `calloc` allocation: `DIM * DIM` elements of `double` |
| MUL-03 | 32 | `memcpy` byte count: `DIM * DIM` elements of `double` |
| MUL-04 | 15 | `memset` byte count: `DIM * DIM` elements of `double` |
| MUL-05 | 9 | `malloc` allocation: `(DIM + N) * DIM` elements of `double` |
| MUL-06 | 9 | `malloc` allocation: `DIM * DIM * DIM` elements of `double` |
| MUL-07 | 5 | `realloc` allocation: `DIM * DIM` elements of `double` |
| MUL-08 | 3 | `calloc` allocation: `(DIM + N) * DIM` elements of `double` |
| MUL-09 | 3 | `malloc` allocation: `DIM * DIM * N` elements of `unsigned char` |
| MUL-10 | 3 | `memcpy` byte count: `(DIM + N) * DIM` elements of `double` |
| MUL-11 | 2 | `calloc` allocation: `DIM * DIM` elements of `char *` |
| MUL-12 | 2 | `calloc` allocation: `DIM * DIM` elements of `int` |
| MUL-13 | 2 | `calloc` allocation: `DIM * DIM * N` elements of `unsigned char` |
| MUL-14 | 2 | `malloc` allocation: `DIM * DIM` elements of `Cand` |
| MUL-15 | 2 | `malloc` allocation: `DIM * DIM * N` elements of `double` |
| MUL-16 | 2 | `malloc` allocation: `DIM * DIM` elements of `long long` |
| MUL-17 | 2 | offset/byte arithmetic: `(DIM - N) * DIM` |
| MUL-18 | 2 | offset/byte arithmetic: `DIM * DIM` |
| MUL-19 | 1 | `calloc` allocation: `DIM * N * DIM` elements of `double` |
| MUL-20 | 1 | `calloc` allocation: `(DIM + N) * (DIM + N)` elements of `int` |
| MUL-21 | 1 | `malloc` allocation: `(DIM + N) * (DIM + N)` elements of `double` |
| MUL-22 | 1 | `malloc` allocation: `(DIM - N) * DIM` elements of `double` |
| MUL-23 | 1 | `malloc` allocation: `DIM * N * DIM` elements of `double` |
| MUL-24 | 1 | `malloc` allocation: `DIM * DIM` elements of `signed char` |
| MUL-25 | 1 | `memset` byte count: `DIM * DIM * N` elements of `double` |
| MUL-26 | 1 | offset/byte arithmetic: `DIM * DIM * DIM` |
| MUL-27 | 1 | float-to-double arithmetic before `_qz_f2i` |
| MUL-28 | 1 | other double arithmetic before `_qz_f2i` |

## Validation

- Full C/C++ syntax sweep: `TOTAL=201 FAIL=0`.
- CodeQL C/C++ final analysis: scanned 203 of 203 C/C++ files.
- CodeQL target C/C++ final counts: integer multiplication 0, overflowing snprintf 0, TOCTOU 0.
- CodeQL Actions final analysis: scanned 1 of 1 workflow files.
- CodeQL Actions final count: missing workflow permissions 0.
- Smoke build: `bin\nucleor.exe build examples\01_hello.nr -o codeql_hello --no-cache`, output executable printed `Hello, Nucleor!`.
- Self-host cold compile samples for `compiler\nucleor_s1_compiler.nr --no-cache`: 3.696s, 3.219s, 3.416s.
- Perf gate: `tools\check_perf_regression.ps1 -Quiet` exited 0.
- Whitespace gate: `git diff --check` exited 0.

## Performance Risk

The multiplication fixes widen allocation and byte-count arithmetic before multiplication. They do not change loop bounds, data layout, algorithm choice, or compiler source. The only runtime behavior change is avoiding pre-widen overflow in sizing math. The measured self-host compile path stayed within the historical 3.5-4.0 second cold-compile envelope on this host.
