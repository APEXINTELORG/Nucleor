# Nucleor OSS — v0.3 / v0.4 Punchlist Handoff

**Date:** 2026-04-23
**Repo:** `C:\Users\JoeWe\Desktop\Nucleor_OSS` (GitHub: `APEXINTELORG/Nucleor`)
**Current HEAD:** v0.2.153 (222 total releases)
**Compiler binary:** `bin/nucleor.exe` self-host LLVM IR fixed point preserved at every promotion
**Verify gate:** `bash tools/verify.sh` — currently **240/240 PASS, 0 SKIP**

---

## Why this handoff exists

The Claude Code session driving this work has been disconnecting
mid-task. This document captures everything a fresh session needs
to pick up where this one left off, so cron-triggered iterations
of the punchlist don't lose context to disconnects.

---

## The punchlist (verbatim from the cron prompt)

1. v0.3.0 native Linux/macOS bootstrap binaries
2. RFC-0001 RT attributes (`#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, `#[deadline]`)
3. RFC-0002 allocator types (`Box<T, A>`, Arena/Pool/TLSF)
4. `#[allow]` / `#[deny]` actual implementation
5. Wrap the 11 orphan runtime C files into rods (v0.2.123 finding)
6. Add importers/smokes for the 22 orphan rod wrappers (v0.2.124 finding)
7. RFC-0023 rich patterns, RFC-0024 full iterators, RFC-0025
   closures, RFC-0026 trait objects, RFC-0027 lifetimes, RFC-0028
   format-string variadics

## Punchlist status as of 2026-04-23

| # | Item | Status | Ship | Notes |
|---|---|---|---|---|
| 1 | Linux/macOS bootstrap binaries | **BLOCKED** | — | Needs Linux/macOS host; not doable from this Windows session |
| 2 | RFC-0001 RT attributes | **OPEN** | — | Lexer skips `#[no_alloc]` etc. silently; checker logic doesn't exist yet |
| 3 | RFC-0002 allocator types | **OPEN** | — | Needs generic types `Box<T, A>` which Nucleor doesn't have. **v0.2.150 found dangling `__nucleor_arena_*` builtin stubs** that this RFC must wire to `stdlib/rods/allocator.nr`'s shipped runtime instead of building parallel impls |
| 4 | `#[allow]` / `#[deny]` | ✅ **CLOSED** | v0.2.151 (allow) + v0.2.152 (deny) | File-wide scope only; per-fn scoping deferred to v0.4 |
| 5 | Wrap 11 orphan runtime C files | ✅ **CLOSED** | v0.2.150 | All 11 wrapped: `mem.nr`, `pqueue.nr`, `allocator.nr`, `thread.nr`, `tokenizer.nr`, `csv_table.nr`, `activation2.nr`, `transformer.nr`, `attention2.nr`, `diff_sim.nr`, `rod_helpers.nr`. Rod count 121→132 |
| 6 | Smokes for 22 orphan rod wrappers | ✅ **CLOSED** | v0.2.149 | All 22 have `tests/rods/<name>_smoke.nr`; gate 204→226 |
| 7 | RFC-0023..0028 v0.4 features | **PARTIAL** | v0.2.153 (RFC-0028 phase 2) | Added 3 new `format2_*` builtins (`ss`, `is`, `ff`). Full variadic, RFC-0023..0027 still open |

---

## What got shipped this session (v0.2.149 → v0.2.153, in order)

### v0.2.149 — Item 6 closed
- Added 22 `tests/rods/<name>_smoke.nr` files for the orphan rod wrappers
- One bug caught: `str_kmp` returns a handle (savec of matches), not a position; smoke fixed
- Gate: 204 → 226

### v0.2.150 — Item 5 closed
- 11 new rod files in `stdlib/rods/`, each wrapping a previously-orphan `*_rt.c`
- Two bugs caught:
  - **RFC-0002 dangling builtins**: s1 pre-declares `arena_new`, `arena_alloc`, `arena_reset`, `arena_destroy` mapped to `__nucleor_arena_*` symbols that exist in NO runtime. Rods using those bare names link-fail. Worked around by prefixing the rod surface with `allocator_*`. **v0.4 RFC-0002 must wire the dangling builtins to `allocator_rt.c` instead of building a parallel runtime.**
  - `tok_char_level` returns a `TKVec*` not a `BPETokenizer*`; calling `tok_free` on its result segfaults. Smoke fixed; rod docs deserve a clarifier
- Rod count 121 → 132, gate 226 → 237

### v0.2.151 — Item 4 partial (`#[allow]`)
- **First compiler-source change since v0.2.87** (65 ships of pure binary stability)
- New fns: `collect_allowed_codes(source: str) -> Vec<i32>` and
  `filter_allow_suppressed(diags: Vec<i32>, source: str) -> Vec<i32>`
- Wired into both diag-emit sites (preflight + main pipeline)
- **Bug fix in `resolve_source_with_records`**: was stripping ALL `#`-prefixed lines (intended for `#cfile`/`#link`), also swallowed `#[...]` Rust-style attributes. Tightened condition: only strip when the second char is NOT `[`. Same fix benefits future `#[deny]`, `#[assume]`, `#[max_depth]`, etc.
- Self-host LLVM IR fixed point: 2-iter byte-identical at 2,615,215 bytes
- New test: `tests/lang/allow_suppress_warning.nr` (positive)
- Gate: 237 → 238

### v0.2.152 — Item 4 closed (`#[deny]`)
- Sibling of v0.2.151
- New fns: `collect_denied_codes` + `promote_denied_to_errors`
- Mutates diag severity slot in place via `vec_set(d, 0, "error")`
- Wired after `filter_allow_suppressed` in both emit sites — allow runs first so a deny on a previously-allowed code is a no-op
- Errors are never suppressible by either attribute (Rust model)
- Self-host LLVM IR fixed point: 2-iter byte-identical at 2,625,247 bytes
- New test: `tests/err/err_deny_promotes_warning.nr` (negative; expects NUM-003)
- Gate: 238 → 239

### v0.2.153 — Item 7 partial (RFC-0028 phase 2)
- 3 new `format2_*` builtins: `ss` (two strs), `is` (i64 then str), `ff` (two f64-bits)
- 4 ABI-table sites in s1 + 4 mirrored in tools_suite (drift gate enforces parity)
- 3 new C runtime impls in `nucleor_llvm_rt.c`; forward-declared `__nucleor_format_f64` so `format2_ff` can reference it without reordering
- Self-host LLVM IR fixed point: held at iteration 2 (2,631,996 bytes); iteration 1 legitimately differed by exactly the 3 new `declare` lines because the old v0.2.152 compiler didn't know them yet
- New test: `tests/lang/format2_combos.nr` (positive; asserts all 3 combos)
- Gate: 239 → 240

---

## Critical workflow — read before touching the s1 compiler

Every change to `compiler/nucleor_s1_compiler.nr` MUST follow
this sequence. The repo's CLAUDE-style instructions make this
non-negotiable.

```bash
cd /c/Users/JoeWe/Desktop/Nucleor_OSS
export PATH="/c/Program Files/LLVM/bin:$PATH"

# 1. Edit compiler/nucleor_s1_compiler.nr (and tools_suite if ABI changed)

# 2. Build new compiler with current bin/nucleor.exe (iteration N+1)
rm -rf .nuc_cache 2>/dev/null
bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_NEW --no-cache

# 3. Promote the new build to a temp slot and rebuild itself (iteration N+2)
cp target/nucleor_NEW.exe bin/nucleor_NEW.exe
rm -rf .nuc_cache 2>/dev/null
bin/nucleor_NEW.exe build compiler/nucleor_s1_compiler.nr -o nucleor_NEWb --no-cache

# 4. Compare the two .ll files — MUST be byte-identical
diff -q target/nucleor_NEW.ll target/nucleor_NEWb.ll && echo "FIXED-POINT OK"

# 5. ONLY if fixed point holds: promote
cp target/nucleor_NEW.exe bin/nucleor.exe
rm -f bin/nucleor_NEW*.exe

# 6. Run the full gate (must pass before commit)
bash tools/verify.sh
```

### Important gotcha discovered in v0.2.153

When the change adds new ABI surface (new builtin, new
extern declare), the **first** iteration of the fixed-point
check legitimately differs from the second — because the OLD
compiler doesn't know the new builtin and won't emit its
declare line. The fixed-point invariant is: **iteration N+2
must equal iteration N+1**, both built with the new compiler.
If iteration N+1 (built by old compiler) differs from N+2
(built by new compiler), inspect the diff: if it is exactly
the new declares / new symbols you intended to add, that's
fine. If it includes anything else, you have a real bug.

---

## Build & verify reference

| Command | What it does |
|---|---|
| `bash tools/verify.sh` | Full gate (build, lex, parse, type, ownership, taint; tests/lang, tests/err, tests/rods, examples; self-host rebuild closure). Currently 240 steps. |
| `bash tools/check_compiler_drift.sh` | ABI-table parity between s1 and tools_suite, helper/rod manifest staleness, RELEASES.md / CHANGELOG.md coverage |
| `python tools/gen_helper_manifest.py` | Regen `docs/rfcs/helper_manifest.toml` after adding/removing runtime helpers |
| `python tools/gen_rod_manifest.py` | Regen `docs/rfcs/rod_manifest.toml` after adding/removing rods |
| `python tools/gen_releases_index.py` | Regen `RELEASES.md` from git tags + `CHANGELOG.md` |

### Required after every ship

1. `python tools/gen_releases_index.py`
2. `bash tools/check_compiler_drift.sh` — must be green; if any manifest is stale, regen and re-add to commit
3. `git add` the touched files (do NOT use `git add -A`)
4. `git commit -m "v0.2.NNN: <punchlist item>: <terse summary>; ..."`
5. `git tag -a v0.2.NNN -m "v0.2.NNN — <slogan>"`
6. `git push origin main --tags`

---

## Items still open — concrete starting points

### Item 2 — RFC-0001 RT attributes

**State**: lexer at line ~121 of `nucleor_s1_compiler.nr` skips
all `#[...]` attributes silently. The skip preserves the line
for the resolver (per the v0.2.151 fix). No checker exists.

**Tractable v1 scope** (one ship): `#[no_alloc]` only. Detection
strategy that fits the existing diag pipeline:

1. `collect_no_alloc_fns(source: str) -> Vec<str>` — scan for
   `#[no_alloc]\nfn <name>` patterns; return list of fn names.
2. In the type-check pass, when entering a fn whose name is in
   that list, mark the env. When the body calls any builtin in
   the alloc-set (`vec_new`, `vec_push`, `sb_new`, `Vec::new`,
   `str_concat`, `str_substring`, …), fire a diag with code
   `RT-001`.
3. Test: `tests/err/err_no_alloc_violation.nr` (negative).

Same model extends to `#[no_panic]` (no `panic!` / array
out-of-bounds calls), `#[no_dyn]` (no `dyn Trait` — needs trait
objects from RFC-0026 first), `#[deadline]` (instrument loop
counts; needs cycle/instruction estimate per builtin — major).

### Item 3 — RFC-0002 allocator types

**State**: `Box<T, A>` requires generic types in s1 — Nucleor
doesn't have them. v0.2.150 found dangling builtin stubs.

**Tractable v1 scope**: not "one ship". Genuinely needs the v0.4
generics surface from RFC-0023..RFC-0027. Defer until those
land.

**Quick win available now**: wire the dangling `arena_*`
builtins (s1 lines ~5970, ~6080) to call into
`stdlib/rods/allocator.nr`'s already-shipped runtime
(`__nucleor_arena_new` → `nuc_arena_new` symbol rename, OR add
runtime aliases). Removes the link-fail trap that bit v0.2.150.
~30 LOC compiler change + 2-iter fixed point.

### Item 7 — RFC-0023..0028

**RFC-0028 (format-string variadics)** is the most tractable.
Phase 2 (v0.2.153) added 3 new combos. Possible phase 3 ships
(each ~100 LOC across compiler + runtime + test):

- `format3_*` family: `format3_sii`, `format3_iss`, `format3_sss`
- `format4_*` for the 1-2 most common 4-arg combos
- Investigate parser-level `format!()` macro that auto-picks the
  right `format<N>_<types>` (much harder; needs new AST node)

**RFC-0023..0027** are major v0.4 work — each is multi-week.

---

## Files of importance

### Compiler & runtime
- `compiler/nucleor_s1_compiler.nr` — the s1 self-host compiler (~9000 LOC, 367 fns)
- `compiler/nucleor_tools_suite.nr` — sibling compiler used by tools; **MUST stay ABI-parallel with s1** (drift gate enforces)
- `stdlib/runtime/nucleor_llvm_rt.c` — main LLVM runtime
- `stdlib/runtime/<name>_rt.c` — feature-specific runtimes (132 of them as of v0.2.150)
- `stdlib/rods/<name>.nr` — Nucleor-source wrappers over the above runtimes (132 rods)

### Status & punchlist references
- `docs/status/v0.2-shipped-and-deferred.md` — running audit of what shipped vs deferred (closed v0.2.123 + v0.2.124 findings here)
- `docs/spec/Nucleor_Error_Codes.md` — error-code registry; contains `#[allow]` / `#[deny]` documentation in the Suppression section
- `CHANGELOG.md` — v0.2.NNN entries; each ship documents files, why, fixed-point status, gate count
- `RELEASES.md` — generated from `tools/gen_releases_index.py`; do NOT hand-edit

### Tests
- `tests/lang/<name>.nr` — positive tests; expected to compile + run
- `tests/err/err_<name>.nr` — negative tests; expected to **fail** to compile, with `// EXPECT: CODE [text]` header (gate enforces format since v0.2.118)
- `tests/rods/<name>_smoke.nr` — rod link/build smokes (added v0.2.149/v0.2.150)

### Build artifacts
- `target/*.ll` — emitted LLVM IR (used in fixed-point checks)
- `target/*.exe` — compiled binaries
- `bin/nucleor.exe` — the canonical self-host compiler; updated only via the workflow above

---

## Known-good cron prompt

If the user wants to keep iterating via `/loop`, the prompt
that's been driving this is:

```
Continue working through the v0.3/v0.4 punchlist. Active items:
1. v0.3.0 native Linux/macOS bootstrap binaries
2. RFC-0001 RT attributes (#[no_alloc], #[no_panic], #[no_dyn], #[deadline])
3. RFC-0002 allocator types (Box<T, A>, Arena/Pool/TLSF)
4. #[allow] / #[deny] actual implementation
5. Wrap the 11 orphan runtime C files into rods (v0.2.123 finding)
6. Add importers/smokes for the 22 orphan rod wrappers (v0.2.124 finding)
7. RFC-0023 rich patterns, RFC-0024 full iterators, RFC-0025 closures, RFC-0026 trait objects, RFC-0027 lifetimes, RFC-0028 format-string variadics

Pick the next tractable chunk based on session state. Ship incrementally green; preserve self-host LLVM IR fixed point on every promotion that touches the s1 compiler; tag every release; push every commit; update CHANGELOG + milestone tracker after each ship. Repo at C:\Users\JoeWe\Desktop\Nucleor_OSS.
```

---

## Honest assessment of what's left

**Tractable in /loop iterations** (1–2 cron cycles each):
- More `format_*` builtins (RFC-0028 incremental)
- Wire dangling `arena_*` builtins to allocator.nr runtime
- `#[no_alloc]` attribute checker (v1, single-rule)
- Per-fn scoping for `#[allow]` / `#[deny]` (extends v0.2.151/152)
- More functional content for the v0.2.150 build-only rod smokes (`activation2`, `attention2`, `rod_helpers`)

**Multi-day RFC implementations** (NOT cron-friendly):
- RFC-0001 full RT attribute family
- RFC-0023 rich patterns
- RFC-0024 full iterators
- RFC-0025 closures with capture
- RFC-0026 trait objects + vtables
- RFC-0027 lifetimes
- Item 1 needs Linux/macOS hardware
- Item 3 (`Box<T, A>`) needs generics from RFC-0023..0027

The cron has been productive on items 4, 5, 6, and parts of 7.
Items 1, 2 (full), 3, and most of 7 need dedicated focus
sessions. Worth either (a) cancelling the cron and tackling
those one at a time as standalone work, or (b) letting the
cron continue chipping at incremental wins (more format
combos, the arena wiring, the `#[no_alloc]` v1).

---

## Compiler-source ship chain

For posterity — the `bin/nucleor.exe` file has been touched
exactly 4 times across the v0.2.x line:

| Tag | Reason |
|---|---|
| v0.2.84 | `nuc help` doc/fix |
| v0.2.87 | `-V` / `version` aliases |
| v0.2.151 | `#[allow]` filter + `resolve_source_with_records` `#[...]` preservation |
| v0.2.152 | `#[deny]` warning→error promotion |
| v0.2.153 | RFC-0028 phase 2 (3 new format2_* builtins) |

That's 5 binary commits across 153 ships. The goal of "every
ship compiles itself" has been preserved by the
2-iteration LLVM IR fixed-point check at every compiler change.

---

*End of handoff. Update this file at the bottom of any future
ship that meaningfully changes the picture.*
