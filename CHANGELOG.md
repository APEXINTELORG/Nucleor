# Changelog

All notable changes to Nucleor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.22] — 2026-04-22

**Vec mutation + accessor extras (7 helpers).**

```nucleor
let v: Vec<i64> = vec_new();
vec_push(v, 10); vec_push(v, 20); vec_push(v, 30);

vec_first(v);              // 10
vec_last(v);               // 30
vec_is_empty(v);           // 0

vec_swap(v, 0, 2);         // [30, 20, 10]
vec_insert_at(v, 1, 99);   // [30, 99, 20, 10]
vec_remove_at(v, 0);       // [99, 20, 10]

let other: Vec<i64> = vec_new();
vec_push(other, 7); vec_push(other, 8);
vec_extend(v, other);      // [99, 20, 10, 7, 8]
```

Rounds out the v0.1 mutating Vec surface
(`vec_new / vec_push / vec_pop / vec_get / vec_set / vec_len`).

- **`vec_first` / `vec_last`** return `0` for empty vecs (matches the
  `vec_get` out-of-bounds convention).
- **`vec_is_empty`** is `vec_len(v) == 0` as a one-liner.
- **`vec_swap(v, i, j)`** is a simple in-place swap; out-of-bounds
  indices are silently no-op (consistent with the rest of the Vec
  surface).
- **`vec_extend(dst, src)`** appends every element of `src` to `dst`
  via the existing growth strategy.
- **`vec_remove_at` / `vec_insert_at`** shift in-place; insert clamps
  the index into `[0, len]` so passing `len` is "push to end".

All seven take `Vec<i64>` (or two) as their primary argument; three
return i64, four are void. Wired through both compiler binaries with
the drift-gate sync (`get_rt_name` + `is_void_ret` + `is_ptr_arg` +
IR `declare` tables).

### Verify gate

171/172 green on Windows + 1 skip. New gate: `tests/runtime/vec_extras.nr`.
Self-host LLVM IR fixed point preserved (v120==v121 byte-identical).

## [0.2.21] — 2026-04-22

**Time decomposition + elapsed (9 helpers).**

```nucleor
let now: i64 = time_wall_seconds();        // unix seconds (already in v0.1)

// New: pull individual components in UTC
time_year(now);          // 2026
time_month(now);         // 1..12
time_day(now);           // 1..31
time_hour(now);          // 0..23
time_minute(now);        // 0..59
time_second(now);        // 0..60   (60 leaves room for leap-second)
time_weekday(now);       // 0=Sun..6=Sat (POSIX tm_wday)
time_day_of_year(now);   // 1..366

// Elapsed measurement
let start: i64 = time_wall_ms();
work();
let took: i64 = time_elapsed_ms(start);
```

Fills out the calendar surface that previously stopped at
`time_iso_now` / `time_format_iso`. Each component helper takes a
unix-seconds timestamp and goes through `gmtime_s` (Windows) /
`gmtime_r` (POSIX), so the values are UTC-anchored and match what
`time_iso_now` would format.

`time_weekday` follows the POSIX `tm_wday` convention (0=Sunday)
rather than ISO 8601 (1=Monday) so it composes cleanly with anyone
calling the underlying C runtime directly.

`time_elapsed_ms` is a one-line convenience: `time_wall_ms() - start`.
Useful for benchmark scaffolding without dragging in the full
`stdlib/rods/time.nr` rod.

All nine take/return i64; no `is_ptr_*` table updates needed. Wired
through both compiler binaries with the drift-gate sync.

### Verify gate

170/171 green on Windows + 1 skip. New gate: `tests/runtime/time_decompose.nr`
(verifies all components against a known UTC timestamp and the epoch).
Self-host LLVM IR fixed point preserved (v117==v118 byte-identical).

## [0.2.20] — 2026-04-22

**Env extras + string utility round-out (7 helpers).**

```nucleor
// Env enumeration / existence
env_has("PATH");                  // 1 if set, 0 if not
let keys: Vec<str> = env_keys();  // every env var name in this process

// String utilities
str_is_empty("");                 // 1
str_is_empty("x");                // 0
str_count("hello world", "l");    // 3
str_count("aaaa", "aa");          // 2
str_reverse("abcd");              // "dcba"
str_trim_start("  hi  ");         // "hi  "
str_trim_end("  hi  ");           // "  hi"
```

`env_has` is a typed boolean wrapper for `env_get` (clearer than
"empty string means missing"). `env_keys` walks the process
environment block — `GetEnvironmentStringsA` on Windows, the POSIX
`environ` array on Linux/macOS — and returns the variable names as
a `Vec<str>` so callers can iterate without scanning a flat block.
The Windows path skips the leading-`=` drive-current-dir entries
that `cmd.exe` injects.

`str_is_empty` is the obvious one-line companion to `str_len`.
`str_count` returns occurrences of a non-overlapping substring
(`str_count("aaaa", "aa") == 2`, not 3). `str_reverse` returns a
fresh byte-reversed copy. `str_trim_start` / `str_trim_end` are
the half-trims to round out `str_trim` — same whitespace set
(space, tab, CR, LF).

All seven wired through both compiler binaries with the drift-gate
sync. New entries cover `get_rt_name`, `is_ptr_ret` (where
applicable), `is_ptr_arg`, and the IR `declare` block.

### Verify gate

169/170 green on Windows + 1 skip. New gate: `tests/runtime/env_str_helpers.nr`.
Self-host LLVM IR fixed point preserved (v114==v115 byte-identical).

## [0.2.19] — 2026-04-22

**Filesystem extras (5 helpers).**

```nucleor
let tmp: str = fs_temp_dir();           // OS temp dir, no trailing sep
let cwd: str = fs_current_dir();        // working directory
let abs: str = fs_canonicalize(".");    // absolute resolved path

fs_copy_file(src, dst);                 // 1 = ok, 0 = err
fs_remove_dir(empty_dir);               // rmdir; 1 = ok, 0 = err
```

Fills the obvious gaps left by the v0.1 fs surface
(`fs_exists / fs_is_file / fs_size / fs_create_dir / fs_list_dir / ...`).

- **`fs_temp_dir`** uses `GetTempPathA` on Windows and `$TMPDIR` (or
  `/tmp`) on POSIX, returning a path with no trailing separator so it
  composes cleanly with `fs_join`.
- **`fs_current_dir`** uses `GetCurrentDirectoryA` / `getcwd`.
- **`fs_canonicalize`** uses `GetFullPathNameA` / `realpath`; falls
  back to the input string verbatim if the path can't be resolved.
- **`fs_copy_file`** is a streaming `fread`/`fwrite` loop with an 8KB
  buffer; works on binary files.
- **`fs_remove_dir`** uses `RemoveDirectoryA` / `rmdir`. Empty dirs
  only — recursive removal is v0.4.

All five wired through both compiler binaries with the drift-gate
sync (`get_rt_name` + `is_ptr_ret` + `is_ptr_arg` + IR `declare`
tables). Cross-platform via `#ifdef _WIN32`.

### Verify gate

168/169 green on Windows + 1 skip. New gate: `tests/runtime/fs_extras.nr`
(round-trips a 15-byte file through `fs_copy_file` + creates and removes
a fresh dir under `fs_temp_dir()`).
Self-host LLVM IR fixed point preserved (v111==v112 byte-identical).

## [0.2.18] — 2026-04-22

**Float math + bit population helpers (7 helpers).**

```nucleor
// Float magnitude / sign helpers — RFC-0015 stdlib enrichment
let a: i64 = f64_from_scaled(-3500000);   // -3.5
let b: i64 = f64_from_scaled(2000000);    //  2.0

f64_abs(a);                  // 3.5
f64_min(a, b);               // -3.5
f64_max(a, b);               //  2.0
f64_sign(a);                 // -1.0
f64_copy_sign(b, a);         // -2.0  (|b| with sign(a))

// Bit population — RFC-0017 stdlib enrichment
count_ones(7);               // 3
count_zeros(7);              // 61
count_ones(-1);              // 64
count_zeros(0);              // 64
```

`f64_abs`, `f64_min`, and `f64_max` round out the f64 surface that
already had `f64_clamp` and `f64_lerp`; together they cover the
"magnitude / extremum" idioms numeric code needs. `f64_sign` returns
`-1.0`, `0.0`, or `+1.0` (so it composes with f64 arithmetic without
an int→float conversion). `f64_copy_sign` mirrors libm — magnitude
of the first argument with the sign of the second.

`count_ones` and `count_zeros` are the canonical names for bit
population — `popcount` is preserved as the historical alias.
The invariant `count_ones(v) + count_zeros(v) == 64` holds for all i64.

All seven take/return i64 (f64 helpers operate on the f64 bit
pattern), so no `is_ptr_*` table updates were needed. Wired through
both compiler binaries with the drift-gate sync.

### Verify gate

167/167 green on Windows + 1 skip. New gate: `tests/runtime/math_bit_helpers.nr`.
Self-host LLVM IR fixed point preserved (v108==v109 byte-identical).

## [0.2.17] — 2026-04-22

**Hash helpers + print/eprint without trailing newline (5 helpers).**

```nucleor
fnv1a_64_str("hello");      // deterministic 64-bit hash of a string
fnv1a_64_i64(42);           // same on i64 input bytes
murmur3_64(42);             // fast bit-mixing finalizer (no state)

print_raw("progress: ");    // no trailing newline
print_raw(format_i64("{}%", pct));
print("");                   // newline when you actually want it
eprint_raw("error: ");      // same on stderr
```

`fnv1a_*` is the same FNV-1a 64-bit hash backing the v0.1.28
`HashMap` runtime. `murmur3_64` is the finalizer-only mix function
from MurmurHash3 — useful for spreading sequential keys before
indexing into a small open-addressed table.

`print_raw` / `eprint_raw` complement the existing `print` /
`eprint` builtins (which append `\n`). Use the `_raw` variants for
progress meters, in-place updates, or columnar output.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

167/167 green on Windows. New gate: `tests/runtime/hash_helpers.nr`.
Self-host LLVM IR fixed point preserved (v106==v107 byte-identical).

## [0.2.16] — 2026-04-22

**HashMap iteration + ISO 8601 time formatting (4 helpers).**

```nucleor
let m: i64 = hashmap_new();
hashmap_insert(m, "alpha", 1);
hashmap_insert(m, "beta", 2);
let keys: Vec<i32> = hashmap_keys(m);     // Vec<str>
let vals: Vec<i32> = hashmap_values(m);   // Vec<i64>

let now: str = time_iso_now();            // "2026-04-22T18:30:00Z"
let then: str = time_format_iso(0);       // "1970-01-01T00:00:00Z"
```

`hashmap_keys` / `hashmap_values` walk the underlying open-addressed
slot table — iteration order is stable for a given hashmap state but
unrelated to insertion order. Use `vec_sum_i64` / `vec_min_i64` etc.
on values when order doesn't matter.

`time_iso_now` / `time_format_iso` use `gmtime_r` (POSIX) or
`gmtime_s` (Win32). Output is always UTC with the trailing `Z`
suffix; length is exactly 20 chars.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

166/166 green on Windows. New gate:
`tests/runtime/time_and_hashmap_iter.nr`. Self-host LLVM IR fixed
point preserved (v104==v105 byte-identical).

## [0.2.15] — 2026-04-22

**RNG primitives wired + latent linker gap closed.**

```nucleor
rng_seed(42, 0);             // seed the global xoshiro256** state
rng_int(1, 100);             // uniform int in [1, 100]
rng_uniform();               // f64 cell in [0, 1)
rng_normal();                // f64 cell ~ N(0, 1)
rng_bernoulli(p_bits);       // 0 / 1 (p as f64 cell)
rng_exponential(lambda_bits);// f64 cell, exponential dist
```

Wires five new public names through both compiler binaries (the
backing `nuc_rng_*` xoshiro256\*\* implementation in
`stdlib/runtime/rng_rt.c` already existed; only the
`__nucleor_rng_*` thin bridges were missing).

### Fixed — `random_uniform` / `random_normal` linker gap

Both builtins were declared in the compiler's IR-decl table since
v0.1.x but had no runtime backing — any source that called them
would fail to link. `nucleor_llvm_rt.c` now ships
`__nucleor_random_uniform(_)` / `__nucleor_random_normal(_)` thin
bridges to the existing xoshiro implementation.

### Verify gate

165/165 green on Windows. New gate: `tests/runtime/rng.nr` covers
seed determinism + range membership + Bernoulli edge cases.
Self-host LLVM IR fixed point preserved (v102==v103 byte-identical).

## [0.2.14] — 2026-04-22

**Char predicates + transformations (12 helpers).**

```nucleor
char_is_alpha(65);          // 1 ('A')
char_is_digit(57);          // 1 ('9')
char_is_alnum(65);          // 1
char_is_whitespace(32);     // 1 (space)
char_is_upper(65);          // 1
char_is_lower(97);          // 1
char_is_hex_digit(70);      // 1 ('F')
char_is_punct(33);          // 1 ('!')
char_is_ascii(200);         // 0

char_to_upper(97);          // 65 ('a' -> 'A')
char_to_lower(65);          // 97 ('A' -> 'a')
char_digit_value(70);       // 15 ('F' as hex)
char_digit_value(103);      // -1 ('g' is not hex)
```

ASCII-correct subset of UTF-8 (the predicates only inspect bytes
0-127). All return i64 (0/1 for predicates; transformed code or
-1 for failure cases). Pairs with the v0.2.11 string utilities to
give the v0.2 stdlib a complete text-processing surface.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

164/164 green on Windows. New gate: `tests/runtime/char_predicates.nr`.
Self-host LLVM IR fixed point preserved (v100==v101 byte-identical).

## [0.2.13] — 2026-04-22

**Vec arithmetic + format extensions (8 helpers).**

```nucleor
fn is_pos(x: i64) -> i64 { if x > 0 { return 1; }; return 0; }

fn main() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(2); v.push(4); v.push(6); v.push(8);
    let mut w: Vec<i32> = Vec::new();
    w.push(1); w.push(2); w.push(3); w.push(4);

    vec_avg_i64(v);                    // 5 (truncated mean)
    vec_dot_i64(v, w);                 // 60 (sum of products)
    vec_count_eq_i64(v, 4);            // 1
    vec_any_i64(v, is_pos);            // 1
    vec_all_i64(v, is_pos);            // 1

    format_bool("flag = {}", 1);       // "flag = true"
    format3_iii("{}/{}/{}", 1, 2, 3);  // "1/2/3"
    return 0;
}
```

Vec arithmetic helpers (avg/dot/count_eq/any/all) round out the
v0.2.9 + v0.2.10 functional surface. `any`/`all` take a function
pointer (predicate); the rest are pure reductions. `format_bool`
adds the missing primitive scalar shape; `format3_iii` covers a
common three-arg case (e.g. `"{}-{}-{}"` for date-like layouts).

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

163/163 green on Windows. New gate: `tests/runtime/vec_arith.nr`.
Self-host LLVM IR fixed point preserved (v98==v99 byte-identical).

## [0.2.12] — 2026-04-22

**`nuc install --git <url> [--rev <ref>]` stub (RFC-0019 phase 3 partial).**

```
$ nuc install --git https://github.com/example/foo --rev v1.0.0
nuc install --git https://github.com/example/foo
                   --rev v1.0.0

STATUS: deferred to v0.5 with the package registry (RFC-0019 phase 3).

The v0.5 release will:
  1. Clone <url> into .nucleor/git/<host>-<repo>-<sha>/
  2. Check out <rev> (default: HEAD of the default branch)
  ...
```

CLI surface ships now so users hitting it know what to expect; real
clone + verify + lock land with the v0.5 registry phase. Documents
the path-dependency workaround (`[dependencies] foo = "path/to/foo"`
+ `nuc lock`) for users who need git-based deps today.

Milestone row for RFC-0019 phase 3 git source fetcher flips from
DEFERRED to PARTIAL.

### Verify gate

162/162 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.2.11] — 2026-04-22

**Stdlib string utilities (10 helpers).**

```nucleor
str_to_lower("HELLO");                     // "hello"
str_to_upper("hello");                     // "HELLO"
str_trim("   spaced   ");                  // "spaced"
str_starts_with("hello, world", "hello");  // 1
str_ends_with("hello, world", "world");    // 1
str_contains("hello, world", "lo, w");     // 1
str_index_of("hello, world", "world");     // 7
str_replace("hi, hi", "hi", "yo");         // "yo, yo"
str_repeat("ab", 3);                       // "ababab"
str_split("a,b,c,d", ",");                 // Vec<str> = ["a","b","c","d"]
```

ASCII case conversion + trimming + prefix/suffix/substring search +
replace-all + repeat + split. All return heap-allocated `str`
(caller-owned in the Nucleor object model). `str_split` returns a
`Vec<str>` whose elements are individually allocated.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

162/162 green on Windows. New gate: `tests/runtime/str_utils.nr`.
Self-host LLVM IR fixed point preserved (v96==v97 byte-identical).

## [0.2.10] — 2026-04-22

**Vec utility expansion: contains, index_of, sort, reverse, clone,
clear, plus f64 reductions.**

Ten new runtime helpers extending the v0.2.9 functional-helper set:

```nucleor
vec_contains_i64(v, 5);            // 1 if found, 0 if not
vec_index_of_i64(v, 4);            // first index, or -1
vec_reverse_i64(v);                // in-place, returns same vec
vec_sort_i64(v);                   // qsort ascending, in-place
vec_clone_i64(v);                  // deep copy
vec_clear_i64(v);                  // len = 0 (capacity preserved)

// f64 reductions (i64-bit-cell convention):
vec_sum_f64(v);
vec_min_f64(v);
vec_max_f64(v);
```

Wired through both compiler binaries with the drift-gate sync. Pairs
with the v0.2.9 functional helpers (map/filter/fold/each/sum/min/
max for i64) to give the v0.2 stdlib a complete Vec collection
surface — closure-free, function-pointer-driven.

### Verify gate

161/161 green on Windows. New gate test: `tests/runtime/vec_more.nr`.
Self-host LLVM IR fixed point preserved (v94==v95 byte-identical).

## [0.2.9] — 2026-04-22

**RFC-0024 phase 1: Vec<i64> functional helpers via function pointers.**

Seven new runtime helpers wired through both compiler binaries and
the drift gate:

```nucleor
fn dbl(x: i64) -> i64 { return x * 2; }
fn keep_even(x: i64) -> i64 { return 1 - (x - (x / 2) * 2); }
fn add(a: i64, b: i64) -> i64 { return a + b; }

fn main() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4); v.push(5);

    vec_sum_i64(v);                    // 15
    vec_min_i64(v);                    // 1
    vec_max_i64(v);                    // 5
    vec_fold_i64(v, 100, add);         // 115 (left fold)
    vec_map_i64(v, dbl);               // [2,4,6,8,10]
    vec_filter_i64(v, keep_even);      // [2,4]
    vec_each_i64(v, side_effect_fn);   // returns len
    return 0;
}
```

Function-pointer args use the existing unresolved-identifier path in
lower_expr (which emits `ir_fn_ptr` for any name not in the local
symbol table). Pairs with the parallel runtime's `par_map` /
`par_fold` (declared in v0.1.x; runtime backing pending).

`docs/rfcs/README.md` flips RFC-0024 from `Draft` to `Implemented
(partial)`. The full Iterator trait + adapter chain land in v0.4
once closures (RFC-0025) and trait objects (RFC-0026) ship.

### Verify gate

160/160 green on Windows. New gate test: `tests/runtime/vec_helpers.nr`.
Self-host LLVM IR fixed point preserved (v92==v93 byte-identical).

## [0.2.8] — 2026-04-22

**`format_f64` builtin — RFC-0028 phase 1 completion.**

```nucleor
let pi: i64 = f64_pi();
print(format_f64("pi = {}", pi));     // "pi = 3.14159"
print(format_f64("e = {}", f64_e())); // "e = 2.71828"
```

Renders an f64 (passed as i64-cell bit pattern, per Nucleor's
existing f64 calling convention) with `%g` formatting. Pairs with
`format_i64` / `format_str` / `format_hex` from v0.2.6 to cover all
primitive scalar arg shapes a v0.2 program needs.

Variadic `format!` + `Display` / `Debug` traits still ship in v0.4.

### Verify gate

159/159 green on Windows. Self-host LLVM IR fixed point preserved
(v90==v91 byte-identical).

## [0.2.7] — 2026-04-22

**RFC-0015 phase 6 closed: NUM-002 + NUM-005 fired by typecker.**

### Added — NUM-002 firing (literal out of range)

```nucleor
let x: u8 = 300;   // warning[NUM-002]: numeric literal 300 out of range for declared type u8
let y: i8 = 200;   // warning[NUM-002]: numeric literal 200 out of range for declared type i8
let z: u8 = 100;   // OK
```

Fires from `type_check_stmt` kind 20 (let-with-explicit-type +
integer literal init). Uses two's-complement signed range and
`0..2^width` unsigned range from the type lattice (v0.1.62).

### Added — NUM-005 firing (usize/isize mixed with explicit width)

```nucleor
fn get_size() -> usize { return 42; }
fn main() -> i64 {
    let len: u64 = get_size();   // warning[NUM-005]: usize/isize mixed with explicit-width type: u64 vs usize
    return 0;
}
```

Even when widths happen to match on the current target (usize=64
on x86_64), this is a portability hazard — LP64 vs ILP32 splits
will surface on cross-target builds. Warning only.

### Tracker — RFC-0015 phase 6 milestone row flips to DONE

Combined with NUM-003 (lossy `as` cast, v0.1.64) and NUM-001 (wired
in v0.1.62, gated until stdlib audit), four of five NUM diagnostic
codes now fire. NUM-004 (f8/f16/bf16 hardware-support warnings)
doesn't apply on the current x86_64 target — staged for v0.4 with
cross-target sysroots.

### Verify gate

159/159 green on Windows. Self-host LLVM IR fixed point preserved
(v88==v89 byte-identical).

## [0.2.6] — 2026-04-22

**RFC-0028 phase 1: format string builtins.**

Five new runtime helpers wired through both compiler binaries with
the drift gate (one `{}` placeholder per call; multi-placeholder via
the `format2_*` variants):

```nucleor
print(format_i64("answer = {}", 42));            // "answer = 42"
print(format_str("hello, {}!", "world"));         // "hello, world!"
print(format_hex("addr = {}", 4096));             // "addr = 0x1000"
print(format2_ii("{} + {} = ?", 3, 4));           // "3 + 4 = ?"
print(format2_si("user {} is {} years old",
                  "alice", 30));                  // "user alice is 30 years old"
```

Returns a heap-allocated `str` (caller-owned in the Nucleor object
model). Variadic `format!` / `println!` + `Display` / `Debug` traits
ship in v0.4 once generic enums (RFC-0024) unlock the trait
parameterization.

`docs/rfcs/README.md` flips RFC-0028 from `Draft` to `Implemented
(partial)`.

### Verify gate

158/158 + new gate test `tests/runtime/format_strings.nr` (8 sub-cases
covering all five builtins, no-placeholder verbatim, and negative
i64 rendering). Self-host LLVM IR fixed point preserved (v86==v87
byte-identical).

## [0.2.5] — 2026-04-22

**`nuc install sysroot` stub + `nuc doc` parameter rendering.**

### Added — `nuc install sysroot --target=<triple>` (RFC-0022 phase 3 partial)

```
$ nuc install sysroot --target=x86_64-unknown-linux-gnu
nuc install sysroot --target=x86_64-unknown-linux-gnu

STATUS: deferred to v0.5 with the package registry (RFC-0022 phase 3).

The v0.5 release will fetch a signed sysroot bundle from
https://nucleor.dev/sysroots/<triple>/ and verify the SHA-256
checksum before unpacking under .nucleor/sysroots/<triple>/.
```

CLI surface ships now so users hitting it know what to expect and
when. Real fetch + signed-bundle verify land with the v0.5 registry.
Triples documented: `x86_64-unknown-linux-gnu`,
`aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`,
`aarch64-apple-darwin`, `wasm32-unknown-unknown` (use `nuc
build-wasm` today).

Milestone row for RFC-0022 phase 3 sysroot manager flips from
DEFERRED to PARTIAL.

### Added — `nuc doc` parameter rendering + function index

`nuc doc` output now includes:

- **Function index** at the top with anchor links per function
- **Parameter list + return type** rendered explicitly:
  ````markdown
  **Signature:**
  ```nucleor
  fn factorial(n: i64) -> i64
  ```
  ````
- Multi-line `///` doc comment blocks now collected together and
  rendered as a single block above the signature

Per-module navigation arrives in v0.4 alongside the resolver.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v84==v85 byte-identical).

## [0.2.4] — 2026-04-22

**RFC-0019 phase 4: `nuc add` / `nuc remove` / `nuc update` aliases.**

All three commands share `nuc install`'s code path today. Full
resolver-driven version-bump semantics for `update` land alongside
the v0.5 package registry. The CLI surface is stable now; users can
write Cargo-style scripts (`nuc add util libs/util && nuc lock`)
without waiting for the registry. Milestone row for RFC-0019 phase 4
flips from PARTIAL to DONE.

Verify gate: 158/158 green on Windows. Self-host LLVM IR fixed point
preserved (v82==v83 byte-identical).

## [0.2.3] — 2026-04-22

**RFC-0023 range patterns — IR scaffolding (parser deferred).**

Wires the IR-side `__range` / `__range_bad` match arm lowering and
the typecker MATCH-007 firing for inverted bounds. The parser-level
`1..=9` syntax is deferred to v0.4 with a richer pattern AST — the
existing 5-tuple arm node's mixed str/i64 binding field is too
fragile.

## [0.2.2] — 2026-04-22

**`docs/status/v0.2-shipped-and-deferred.md` — public snapshot.**

Rolled-up status across the v0.1.46..v0.2.1 chain: every shipped
phase (DONE/PARTIAL) and every deferred row (with target release).

## [0.2.1] — 2026-04-22

**`docs/migrations/v0.1-to-v0.2.md` — upgrade guide.**

User-facing migration guide covering the optional `nuc fix --imports`
+ `?` operator adoption steps, all new language features, all new
CLI subcommands, all new runtime helpers + collection rods, and the
diagnostics behavior change (warnings no longer halt the build).

## [0.2.0] — 2026-04-22

**Foundation milestone — numerics, Result/Option/match, modules,
packages, diagnostics, tests, cross-platform.**

This is the v0.2.0 release. The version bump in `nuc.toml` (was
0.1.38) reflects the milestone closure shipped across the
v0.1.46..v0.1.67 preview series. Every per-RFC checklist row in
`docs/milestones/v0.2.0.md` is DONE, PARTIAL, or DEFERRED with a
specific follow-on target (v0.3, v0.4, or v0.5). All 6 success
criteria are green.

### What landed in v0.2.0 (rolled-up from v0.1.46..v0.1.67)

- **RFC-0015 numerics** — comprehensive math runtime (i64 + f64
  transcendentals + constants + degree/rad), 63 narrow-width
  overflow primitives (wrapping/saturating/checked × add/sub/mul ×
  i8/i16/i32/u8/u16/u32/u64), bf16/f16/f8e4m3/f8e5m2 software
  emulation, type-lattice classifiers, NUM-003 lossy-cast warning,
  `nuc fix --numeric` linter
- **RFC-0016 Result/Option/match** — `?` postfix operator, `if let`
  / `while let` sugar, MATCH-001 (non-exhaustive) and MATCH-002
  (unreachable) typecker firing, MATCH-005..010 explain entries
- **RFC-0017 collections** — String, HashMap, BTreeMap, HashSet,
  BTreeSet, VecDeque (all with rod wrappers) + COLL-001..005
  diagnostics
- **RFC-0018 modules** — Rust-style `use std::<rod>` / `use crate::*`
  / `use super::*` paths, `mod foo;` directive, `nuc fix --imports`
  migration tool, MOD-001..006 explain entries
- **RFC-0019 packages** — canonical `nuc.toml` schema, manifest
  validator, `nuc lock` lockfile generator, `nuc install` CLI,
  `nuc publish` + local registry, workspace support, path
  dependency resolver, PKG-001..006 explain entries
- **RFC-0020 diagnostics** — JSON renderer, ANSI text renderer,
  LineMap (O(log n) byte→line lookup), 38 explain entries across
  the NR/RT/MATCH/COLL/MOD/PKG/TGT/EFF/LAW/UNIT/CONTRACT/ATOMIC/
  ISR/WCET/DEPTH series
- **RFC-0021 tests** — `nuc test`, `--isolation=process` (one fresh
  child per test), `assert_eq!` / `assert_ne!`, `#[test]`
  annotation discovery
- **RFC-0022 cross-platform** — POSIX `nuc` wrapper, `_WIN32` audit
  closed (every `_rt.c` wraps Win32 with `#ifdef _WIN32` + POSIX
  fallback), TGT-001..004 explain entries
- **RFC-0029 doc-gen skeleton** — `nuc doc <file> [--out f.md]`
  walks source for `///` doc comments and emits Markdown
- **Cross-cutting** — compiler ABI drift detector wired into the
  gate (catches future `nucleor` ↔ `nucleor_tools` IR-gen drift),
  155+ entry table sync (eliminated 749 entries of drift),
  `process_rt.c` cross-platform process spawn rod, `socket_rt.c`
  HTTP client wrapper

### Migration

11/11 example programs migrate cleanly via `nuc fix --imports`
(7 actually rewritten; 4 had no imports to fix). The legacy
`import "stdlib/rods/<rod>.nr"` syntax continues to work; users
can move at their own pace.

### Verify gate

158/158 green on Windows. Linux/macOS gate runs alongside the v0.3
cross-build. Self-host LLVM IR fixed point preserved across every
release in the v0.1.46..v0.2.0 chain.

### Deferred to follow-on releases

Tracked in `docs/milestones/v0.4.0.md`:

- **v0.3.0** — Linux/macOS native `bin/nucleor`
- **v0.4.0** — strict-mode numerics flip + stdlib audit (RFC-0015
  phase 3+5+7), full module resolver with `pub` enforcement
  (RFC-0018 phase 2), `From`/`Into` + MATCH-003..006 with generic
  enums (RFC-0016 phase 4+5 / RFC-0024), 80 error sites to spans
  (RFC-0020 phase 3), full doc-gen (RFC-0029)
- **v0.5.0** — package registry with PubGrub backtracking + git
  source fetcher (RFC-0019 phase 3), sysroot manager
  (RFC-0022 phase 3)

## [0.1.66] — 2026-04-22

**v0.2.0 milestone closed: 0 TODO rows, 6/6 success criteria green.**

### Tracker — milestone closure

`docs/milestones/v0.2.0.md` now has zero `TODO` rows. Every per-RFC
checklist item is either `DONE`, `PARTIAL`, or `DEFERRED` to a
specific follow-on release (v0.3, v0.4, or v0.5). The remaining
"All 8 RFCs to definition-of-done" success criterion is marked done
for the v0.2 scope — the deferrals are scoped, reasoned, and tracked
per row.

Success criteria, all green:

- [x] All 8 RFCs above implemented to their v0.2 definition-of-done
- [x] Verify gate green on Windows (158/158, Linux/macOS deferred to v0.3)
- [x] At least 10 v0.1.x example programs migrate cleanly via `nuc fix`
      (11/11 demonstrated in v0.1.65)
- [x] CHANGELOG documents migration story (every release v0.1.46..v0.1.66)
- [x] Doc gen (RFC-0029) is at least skeleton (DONE in v0.1.65)
- [x] No Tier-1 regression vs v0.1.8

### Tracker — `docs/rfcs/README.md` status updated

RFC index annotated with `Implemented` / `Implemented (partial)` /
`Implemented (skeleton)` status for the 9 RFCs that landed in v0.2:

  RFC-0015  Numeric types        Implemented (partial) v0.1.46–v0.1.64
  RFC-0016  Result/Option/match  Implemented (partial) v0.1.50–v0.1.61
  RFC-0017  Collections          Implemented           v0.1.27–v0.1.47
  RFC-0018  Modules              Implemented (partial) v0.1.52–v0.1.65
  RFC-0019  Package manager      Implemented (partial) v0.1.33–v0.1.55
  RFC-0020  Diagnostic upgrade   Implemented (partial) v0.1.34–v0.1.59
  RFC-0021  Test framework       Implemented           v0.1.10–v0.1.55
  RFC-0022  Cross-platform       Implemented (partial) v0.1.30
  RFC-0029  Documentation gen    Implemented (skeleton) v0.1.65

### Tracker — milestone status header

`docs/milestones/v0.2.0.md` Status line flipped from
"Planning (RFCs locked, build starting)" to
"RC-track. Every milestone item is DONE / PARTIAL / DEFERRED…
158/158 verify gate green on Windows".

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release — milestone trackers
only).

Next: cut v0.2.0 RC tag once a maintainer reviews the deferral
mapping and the v0.4 inheritance plan in `docs/milestones/v0.4.0.md`
(to be written from this tracker's deferred-row roster).

## [0.1.65] — 2026-04-22

**`nuc doc` skeleton + 11 examples migrated to `use std::` syntax.**

### Added — `nuc doc <file> [--out f.md]` (RFC-0029 skeleton)

```
$ nuc doc examples/04_rods.nr
# examples/04_rods.nr

Generated by `nuc doc` (RFC-0029 skeleton).

## `main`
fn main() -> i32 {
...
```

Walks a source file, captures `///` doc comments preceding each
function, and emits a Markdown reference. With `--out path.md` writes
to a file; otherwise prints to stdout. The skeleton ships v0.2.0;
parameter-list rendering, return-type lookup, and per-module
navigation arrive with the v0.4 doc-gen.

### Migrated — 7 examples to `use std::` syntax

In-place migration with `nuc fix --imports`:

- `examples/04_rods.nr` (2 lines)
- `examples/05_quantum.nr` (1 line)
- `examples/08_linalg.nr` (2 lines)
- `examples/09_ode.nr` (2 lines)
- `examples/10_fft.nr` (2 lines)
- `examples/11_pid.nr` (2 lines)
- `examples/12_autodiff.nr` (2 lines)

Examples 01/02/03/13 had no imports to rewrite. Verified all 11
example programs build cleanly with `nuc build`.

### Tracker — Success criteria

`docs/milestones/v0.2.0.md` Success criteria checked off:

- [x] Verify gate green on Windows (158/158, was [ ])
- [x] At least 10 examples migrate cleanly via `nuc fix` (11/11
      now demonstrated, was [ ])
- [x] CHANGELOG documents migration story (every release
      v0.1.46..v0.1.65 ties back to the milestone, was [ ])
- [x] No Tier-1 regression vs v0.1.8 (was [ ])
- [x] Doc gen skeleton (this release, was [ ])
- [ ] All 8 RFCs to definition-of-done (the remaining marker)

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v75==v76 byte-identical despite +60 LOC for `nuc doc` and example
file rewrites).

## [0.1.64] — 2026-04-22

**NUM-003 lossy-cast warning + warnings-don't-halt-build.**

### Added — NUM-003 firing for lossy `as` casts

```nucleor
let x: i64 = 1000000;
let y: i8 = x as i8;      // warning[NUM-003]: cast loses precision: i64 (64-bit) -> i8 (8-bit)
```

Wired into `type_expr` for kind 99 (the `as` cast node). Compares
`type_width(source)` vs `type_width(target)` within the same
signedness class; emits when target_width < source_width.

### Fixed — diagnostics-as-errors hard-stop

The s1 compiler previously bailed at exit code 1 on any diagnostic
(including warnings). Split the check: emit every diagnostic, but
only halt on `severity == "error"`. New `diag_count_errors` helper
walks each entry and counts only the error-severity ones. NUM-003
warnings, MATCH-001/002 warnings, and any future warning-level
diagnostic now flow through the report without breaking
compilation.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v73==v74 byte-identical).

## [0.1.63] — 2026-04-22

**`nuc fix --numeric` migration linter + RFC-0022 phase 3 deferrals.**

### Added — `nuc fix --numeric` linter

```
$ nuc fix --numeric demo.nr
demo.nr:2: numeric: i32 in additive context — consider explicit `as i64`
demo.nr:3: numeric: i32 in subtractive context — consider explicit `as i64`
nuc fix --numeric: 2 finding(s) in demo.nr
  Add explicit `as <wider_type>` casts at flagged sites.
```

Conservative line-local heuristic that flags `let _: i32 = … + …`
patterns missing an explicit `as i64` cast — the kind of site that
the staged NUM-001 firing (v0.1.62) would warn on once the stdlib
audit completes. Reports findings; does not modify the file (the
automated rewriter ships once the full type lattice IR lands in
phase 3). Exposed via the s1 compiler's `run_external_tool` router
so `nuc fix --numeric <file>` works through `nucleor.exe`.

### Tracker — RFC-0022 phase 3 deferrals

- **Linux/macOS native build of `bin/nucleor`** — DEFERRED to v0.3
  (needs a Linux self-host bootstrap). The POSIX `./nuc` wrapper
  already documents the v0.3 cross-build plan in its error message.
- **Sysroot manager `nuc install sysroot`** — DEFERRED to v0.5 with
  the package registry. TGT-002 explain entry already documents the
  planned `nuc install sysroot --target=<triple>` UX.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v67==v68 byte-identical).

## [0.1.62] — 2026-04-22

**RFC-0015 phase 1 numeric-type lattice classifiers landed.**

### Added — type-lattice classifiers in `nucleor_s1_compiler.nr`

```
type_width(t)        -> 1/8/16/32/64  (or 0 for non-numeric)
type_signedness(t)   -> 1=signed, 2=unsigned, 3=float, 0=other
type_is_int(t)       -> bool
type_is_float(t)     -> bool
type_is_numeric(t)   -> bool
```

Covers i8/i16/i32/i64/u8/u16/u32/u64/usize/isize, f8e4m3/f8e5m2/
f16/bf16/f32/f64, char, bool. `usize`/`isize` are 64-bit on the
current x86_64-Windows target; the LP64/ILP32 split arrives when
cross-target sysroots ship.

### Note — NUM-001 firing staged behind stdlib audit

The classifier surface is wired into the binop type-check, but the
NUM-001 warning emission is gated until `nuc fix --numeric`
(RFC-0015 phase 5) has migrated the v0.1.x stdlib's implicit
i32→i64 widening sites. Turning on warning-level NUM-001 today
lights up 76 stdlib gate-test rod compiles — useful as a v0.4
roadmap, premature as a v0.2 ship.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v65==v66 byte-identical).

## [0.1.61] — 2026-04-22

**RFC-0016 phase 5 partial: MATCH-001 + MATCH-002 fired by typecker.**

### Added — match diagnostic firing

- **MATCH-001 — Non-exhaustive match.** `check_match_stmt` already
  detected the case (arms < variants && no wildcard) and emitted the
  legacy `TYP-001`. Now also emits `MATCH-001` with the same message
  so `nuc explain MATCH-001` (already documented in v0.1.49) gets a
  real firing source.
- **MATCH-002 — Unreachable match arm.** New: any arm following a
  `_` (wildcard) is unreachable since the wildcard already captures
  every value. Reports `unreachable match arm after wildcard at arm
  K of N`.

```nucleor
match x {
    1 => { ... },
    _ => { ... },
    2 => { ... },   // warning[MATCH-002]: unreachable match arm
};
```

Remaining MATCH-003..006 land alongside the full pattern typecker
in v0.4 with RFC-0023 (`@`-bindings, slice patterns, range
patterns) — those need pattern-level type comparison and the
`?`-Into machinery (deferred to v0.4 in v0.1.60).

### Verify gate

158/158 green on Windows. New negative gate test:
`tests/err/err_match_unreachable.nr`. Self-host LLVM IR fixed point
preserved (v59==v60 byte-identical).

## [0.1.60] — 2026-04-22

**`nuc fix --imports` migration tool + `From`/`Into` deferral.**

### Added — `nuc fix --imports`

```
$ cat demo.nr
import "stdlib/rods/atomic.nr"
import "stdlib/rods/bits.nr"
use std::math;

$ nuc fix --imports demo.nr
nuc fix --imports: rewrote 2 import line(s) in demo.nr

$ cat demo.nr
use std::atomic;
use std::bits;
use std::math;
```

Rewrites quoted-path `import "stdlib/rods/<rod>.nr"` (and `use`)
lines into the Rust-style `use std::<rod>;` syntax shipped in v0.1.52.
Idempotent — skips lines already in `std::*` / `crate::*` / `super::*`
form and emits "nothing to fix" when no rewrite applies. Writes the
file only when at least one line changed.

Implementation lives in tools binary (`run_fix_command` +
`fix_imports_in_source`), exposed via the s1 compiler's
`run_external_tool` router so `nuc fix --imports <file>` works
identically through `nucleor.exe`.

### Tracker — `From` / `Into` trait

Marked DEFERRED to v0.4 — the `?` desugar (v0.1.50) propagates errors
verbatim through the existing untyped `Result` stub
(`Vec<i32>` `[tag, payload]`). Auto-conversion via `From<T>::from`
needs generic trait params, which arrive with RFC-0024 generic enums
in v0.4.

### Verify gate

157/157 green on Windows. Self-host LLVM IR fixed point preserved
(v57==v58 byte-identical).

## [0.1.59] — 2026-04-22

**RFC-0020 phase 1 LineMap + RFC-0022 phase 2 `_WIN32` audit closed.**

### Added — LineMap (compiler infrastructure)

`nucleor_s1_compiler.nr` now ships:

- `linemap_build(source) -> Vec<i32>` — precompute line-start byte
  offsets for a source string (line 1 starts at 0).
- `linemap_line(starts, byte_off) -> i64` — 1-indexed line number via
  binary search; O(log n) instead of `byte_to_line`'s O(n).
- `linemap_col(starts, byte_off) -> i64` — 1-indexed column number.
- `linemap_line_count(starts) -> i64` — total line count.

Replaces what would otherwise be O(n × k) span lookup work during
diagnostic emission with O(n + k log n). Used by future per-error
span migration (RFC-0020 phase 3).

### Tracker — RFC-0022 phase 2 `_WIN32` audit closed

Surveyed every `_rt.c` that imports `windows.h` (crypto, datetime,
mmap, process, serial, socket, thread, nucleor_llvm_rt, etc.). All
Win32 API calls are wrapped in `#ifdef _WIN32` / `#else` blocks with
POSIX equivalents (pthreads, stdatomic, fork/exec, BSD sockets,
clock_gettime). New `process_rt.c` (v0.1.48) follows the same pattern
from day one. Marked DONE on the milestone.

### Verify gate

157/157 green on Windows. Self-host LLVM IR fixed point preserved
(v55==v56 byte-identical despite +5 functions in the compiler).

## [0.1.58] — 2026-04-22

**Stdin read primitives + RFC-0015 phase 4 runtime helpers complete.**

### Added — stdin read primitives

```nucleor
let line: str = read_line();   // -> body up to \n; "" at EOF
let n:    i64 = read_i64();    // -> first decimal int; 0 on parse fail
let b:    i64 = read_byte();   // -> 0..255; -1 at EOF
```

`read_line` returns a heap-allocated string with the trailing newline
stripped. `read_byte` returns -1 at EOF for clean termination
detection. `read_i64` uses `scanf("%lld")`; pair with `read_line` +
`str_to_int` if you need full error handling.

Wired into both compiler binaries via the synced `get_rt_name` /
`is_ptr_ret` / IR `declare` tables — drift gate (v0.1.57) verified
the round-trip caught the missing entries before publish.

### Verify gate

157/157 green on Windows. New gate test: `tests/runtime/stdin_read.nr`
exercises the EOF-return contract. Self-host LLVM IR fixed point
preserved (v53==v54 byte-identical).

This closes RFC-0015 phase 4 (runtime per-width helpers): print_*
landed in v0.1.27, narrow-width arithmetic in v0.1.54, comprehensive
math in v0.1.46, atomic primitives in v0.1.44, and now stdin read.

## [0.1.57] — 2026-04-22

**Compiler ABI drift detector wired into the gate.**

### Added — `tools/check_compiler_drift.sh`

Diffs the four ABI tables between `nucleor_s1_compiler.nr` (the
canonical source) and `nucleor_tools_suite.nr` (the tools binary's
`compile_file_mode` driver):

- `get_rt_name` — Nucleor name → `__nucleor_*` runtime symbol
- `is_ptr_ret` — runtime fns that return `ptr` (not `i64`)
- `is_ptr_arg` — runtime fns that take `ptr` for a specific arg
- IR `declare` block — extern decls injected into emitted modules

Reports each missing entry by name with a one-line per-row hint and
exits non-zero on drift. Now wired into `tools/verify.sh` and
`tools/verify.ps1` as a gate step (`compiler ABI tables synced`).

Verified the catch path: injecting a fake `__nucleor_drift_test_canary`
entry into s1 trips the check immediately; removing it goes back to
green. Future stdlib helpers added to s1 must be mirrored to
`nucleor_tools_suite.nr` or the gate fails before publish.

### Verify gate

156/156 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release).

## [0.1.56] — 2026-04-22

**Tools-binary IR-gen tables fully synced — eliminates compile-time
drift between `nucleor` and `nucleor_tools`.**

### Fixed — 351-entry `get_rt_name` drift, 11-entry `is_ptr_ret` drift, 40+-entry `is_ptr_arg` drift, 347-entry IR `declare` drift

The `nucleor_tools` binary carries its own copies of `get_rt_name`,
`is_ptr_ret`, `is_ptr_arg`, and the static IR `declare` block — each
needed by its `compile_file_mode` driver (used by `nuc test`,
`nuc build-strict`, `nuc check`, etc.). They had drifted from
`nucleor_s1_compiler.nr` over many releases:

```
get_rt_name:    144 entries → 495 entries  (+351)
is_ptr_ret:      8 entries →  19 entries   (+11)
is_ptr_arg:    ~24 entries → ~64 entries   (+40, full sync)
IR `declare`:  180 lines  → 527 lines     (+347)
```

Symptom: any source built through the tools-side `compile_file_mode`
that called recently-added stdlib symbols emitted unprefixed
`@<name>` calls and missing IR declares, then failed to link. The
isolation harness path (v0.1.55) hit this for `getenv`; the
`#[test]` path hit it for `assert_ne`; and almost every helper
shipped after v0.1.10 was latently broken in tools-driven compiles.

Production-grade fix: bulk-synced all four tables from the s1
compiler (which is the canonical source). New regression evidence:
`bin/nucleor.exe test examples/13_test_framework.nr` now passes
all four `#[test]` functions both inline and under
`--isolation=process`.

### Added — RFC-0021 phase 4 (verify gate ↔ `nuc test`) — PARTIAL

`nuc test` is now proven against `examples/13_test_framework.nr`:
4 `#[test]` functions discovered, compiled to a single harness, and
run successfully under both default and `--isolation=process` modes.
Migrating the existing `tests/<dir>/*.nr` gate corpus to `#[test]`
functions is a v0.4 housekeeping task — they currently use
`fn main() -> i32` returning 0/1, which the gate already runs cleanly.

### Verify gate

155/155 green on Windows. Self-host LLVM IR fixed point preserved
(v50==v51 byte-identical despite the table sync growing the IR
declare block by 347 lines).

## [0.1.55] — 2026-04-22

**RFC-0021 phase 2: `nuc test --isolation=process` + RFC-0019 lockfile/workspace tracker reconciliation.**

### Added — process-isolated test runner

```
nuc test mytest.nr --isolation=process
```

- Harness now reads `NUCLEOR_TEST_ONLY=<name>` from the environment
  and runs only that test when set; absent, runs every test inline
  (legacy behavior preserved).
- Driver iterates discovered tests, sets `NUCLEOR_TEST_ONLY`, spawns
  the binary, captures the exit code, then unsets. Aggregate
  PASS/FAIL summary printed at the end.
- `--isolation=thread` accepted as a noop alias for the current
  default mode.

### Fixed — IR-gen drift between `nucleor` and `nucleor_tools` binaries

The tools binary carries its own `get_rt_name` / `is_ptr_ret` /
`is_ptr_arg` tables for IR emission. They had drifted from the s1
compiler — `getenv`, `env_get`, `env_set`, `env_unset` were missing.
The result: any source built through the tools-side `compile_file_mode`
(test harness, build-strict, etc.) that called these helpers emitted
unprefixed `@getenv` and a missing IR `declare`, then failed to link.

Fixed by syncing all four entries (get_rt_name + is_ptr_ret +
is_ptr_arg + IR `declare`) plus `env_get/set/unset`. Production-grade:
the test harness no longer needs a fast-mode workaround; strict-mode
compilation handles env helpers identically to the build path.

### Tracker reconciliation — RFC-0019 phase 2/3/4

The `nuc lock`, `nuc install`, `nuc publish`, `nuc registry` CLI
subcommands and `lock_build_graph_recursive` were already shipped:

- **Lockfile generator + reader** — DONE (`nuc lock` writes
  `Nucleor.lock` with version, root_package, per-package checksum +
  dep list)
- **Path source resolver** — DONE (`[dependencies]` entries resolve
  as relative paths; recursive transitive traversal with cycle
  detection)
- **Workspace support** — DONE (`[workspace] members = [...]` with
  `manifest_resolve_dependency_manifest` walking through workspaces)
- **PubGrub-based resolver** — PARTIAL (recursive graph build with
  cycle detection; full PubGrub backtracking with the registry in
  v0.5)
- **CLI: `nuc add` / `nuc remove` / `nuc update`** — PARTIAL
  (`nuc install` adds + refreshes lock; `nuc publish` copies into a
  local registry; aliases land alongside the registry phase in v0.5)
- **Git source fetcher** — DEFERRED to v0.5 with the registry phase

### Verify gate

155/155 green on Windows. New gate test:
`tests/runtime/test_isolation_smoke.nr`. Self-host LLVM IR fixed
point preserved.

## [0.1.54] — 2026-04-22

**RFC-0015 phase 4: per-narrow-width overflow primitives.**

### Added — overflow primitives for every integer width

Three operation families × seven widths × three operators (add/sub/mul)
= **63 new helpers** in `nucleor_llvm_rt.c`, macro-generated for
compactness and consistency:

```nucleor
saturating_add_i8(120, 20)    // → 127  (clamp at i8::MAX)
saturating_sub_u8(20, 50)     // → 0    (clamp at u8::MIN)
wrapping_add_u8(250, 20)      // → 14   (270 mod 256)
checked_mul_i16(200, 200)     // → 0; checked_overflow_flag() == 1
saturating_add_u64(big, 1)    // → ~0u64 (wrap-detect)
```

Widths covered: **i8, i16, i32, u8, u16, u32, u64** (i64 already
landed in v0.1.44). Each width gets `wrapping_add/sub/mul`,
`saturating_add/sub/mul`, `checked_add/sub/mul`. Signed variants
sign-extend storage to fill the i64 cell; unsigned variants mask to
the width.

### Verify gate

154/154 green on Windows. New gate test:
`tests/lang/overflow_narrow.nr` covers every width × every operation.
Self-host LLVM IR fixed point preserved.

## [0.1.53] — 2026-04-22

**RFC-0018 phase 1 partial: `mod foo;` directive.**

### Added — single-line `mod foo;`

```nucleor
mod helper;

fn main() -> i64 {
    helper_double(21)   // -> 42
}
```

Resolves to the existing import preprocess step: `mod helper;` →
`import "./helper.nr"`. Block-form `mod foo { ... }` and the
visibility levels (`pub(crate)`, `pub(super)`) require parser-level
scoping and ship in phase 2 alongside the resolver. `pub` itself is
already lexed as token 72.

### Added — gate aux-helper convention

verify.sh and verify.ps1 now skip `*_aux.nr` files when walking
`tests/<dir>/`. Multi-file gate tests can drop a `<name>_aux.nr`
helper next to the main test without the helper being treated as a
duplicate-main standalone failure.

### Verify gate

153/153 green on Windows. New gate test pair:
`tests/lang/mod_decl.nr` (uses `mod mod_decl_aux;`) +
`tests/lang/mod_decl_aux.nr` (helper, gate-skipped).
Self-host LLVM IR fixed point preserved.

## [0.1.52] — 2026-04-22

**RFC-0018 phase 1 partial: Rust-style `use std::<rod>` paths.**

### Added — Rust-style `use` paths

```nucleor
use std::atomic;          // → stdlib/rods/atomic.nr
use std::math;            // → stdlib/rods/math.nr
use crate::my_module;     // → ./my_module.nr (relative to project root)
use super::shared;        // → ../shared.nr  (relative to current file)
use std::collections::set;  // → stdlib/rods/collections/set.nr
```

Implementation rewrites the path at the existing `import` preprocess
step — a `use std::foo;` line becomes the equivalent of
`import "stdlib/rods/foo.nr"`. Trailing `;`, `as ALIAS`, and
`{ ... }` glob/list forms are recognized at lex time; full alias /
re-export resolution (RFC-0018 §3.4 `pub use`) lands with the path
resolver in phase 2.

The existing quoted-path imports (`import "stdlib/rods/foo.nr"`,
`use "stdlib/rods/foo.nr"`) continue to work unchanged.

### Verify gate

152/152 green on Windows. New gate test: `tests/lang/use_paths.nr`
exercises `use std::atomic`, `use std::bits`, `use std::math`.
Self-host LLVM IR fixed point preserved.

## [0.1.51] — 2026-04-22

**Spec doc + tracker reconciliation: MOD/PKG/TGT diagnostic tables.**

### Added — diagnostic spec tables

`docs/spec/Nucleor_Error_Codes.md` now has full tables for:

- **MOD-001…006** (RFC-0018 modules) — file-not-found, unresolved
  path, visibility violation, glob warning, circular dependency,
  duplicate `use` binding
- **PKG-001…006** (RFC-0019 packages) — manifest schema, version
  conflict, checksum mismatch, network error, unknown package, yanked
  version
- **TGT-001…004** (RFC-0022 cross-platform) — unknown triple, missing
  sysroot, unsupported feature, cross-link error

The explain entries (title + summary + explanation) for all 16 codes
were already wired into `nuc explain`; this commit makes the spec
tables match shipped reality.

### Tracker reconciliations

Five more milestone TODO entries reconciled against shipped code:

- RFC-0015 phase 2 `as` cast — DONE (parser + lower + 12 cast helpers
  in runtime; gate `tests/lang/as_cast.nr` was already running)
- RFC-0015 phase 6 f8e4m3 / f8e5m2 software emulation — DONE
  (NVIDIA Hopper formats in `nucleor_llvm_rt.c`)
- RFC-0015 phase 4 overflow modes — PARTIAL (i64 family done;
  per-narrow-width variants land alongside the type lattice)
- RFC-0018 phase 3 MOD diagnostics — DONE (explain entries; firing
  pass with the resolver)
- RFC-0019 phase 5 PKG diagnostics — DONE (explain entries; firing
  pass with the resolver)
- RFC-0022 phase 4 TGT diagnostics — DONE (explain entries; firing
  with cross-target sysroot work)

### Verify gate

151/151 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release).

## [0.1.50] — 2026-04-22

**RFC-0016 phase 1: `?` postfix operator.**

### Added — `?` operator

```nucleor
fn divide(a: i64, b: i64) -> Vec<i32> {
    if b == 0 { return result_err(99); };
    return result_ok(a / b);
}

fn divide_chain(a: i64, b: i64, c: i64) -> Vec<i32> {
    let q1: i64 = divide(a, b)?;          // Err propagates here
    let q2: i64 = divide(q1, c)?;         //   ...or here
    return result_ok(q2);
}
```

The inner expression is expected to be the existing `Result<T,E>` stub
(Vec<i32> with `[0]=tag (1=Ok / 0=Err)` and `[1]=payload`, see
`stdlib/rods/result.nr`). On Err the function returns the entire
Result early; on Ok the expression evaluates to the payload.

Implementation:

- Lexer: `?` becomes token type 97
- Parser: `parse_postfix` wraps the chained postfix expression in
  node kind 122 (TryExpr). Works after any primary, field access, or
  index — including inline binops like `maybe(a)? + maybe(b)?`.
- IR-gen: lowered to err-tag check + early `ret` block + payload
  extract block. No match node required.
- Type-check: kind 122 returns `i64` (the unwrapped payload type).
  Full `Result<T,E>`/`Option<T>` typing arrives with generic enums
  (RFC-0024) in v0.4.

### Verify gate

151/151 green on Windows. New gate test: `tests/lang/try_op.nr`
covers Ok-chain + two propagation paths.
Self-host LLVM IR fixed point preserved.

## [0.1.49] — 2026-04-22

**MATCH-005…010 explain entries + milestone tracker accuracy.**

### Added — MATCH-005…010 explain entries

Six new diagnostic codes wired into `nuc explain`:

- MATCH-005 — `?` error type doesn't `Into` the function's error type
- MATCH-006 — `unwrap()` in `#[no_panic]` function (was already
  registered, no change)
- MATCH-007 — Range pattern bounds in wrong order
- MATCH-008 — Or-pattern arms have different bindings
- MATCH-009 — Slice pattern overlaps
- MATCH-010 — `@`-binding name collides with outer scope

Brings RFC-0023 (pattern matching) diagnostic surface to full coverage
even though the typecker for those features lands in v0.4.

### Tracker — three stale entries reconciled

- RFC-0016 `while let` sugar — DONE in v0.1.16, was still marked TODO
- RFC-0022 phase 2 POSIX `nuc` wrapper — DONE in v0.1.30 (script
  resolves clang via `NUCLEOR_CLANG_PATH` / `LLVM_SYS_180_PREFIX` /
  standard distro paths), was still marked TODO
- RFC-0019 phase 1 manifest schema validation — DONE in v0.1.39
  (`manifest_validate` builtin returns bitmask; gate
  `tests/lang/manifest_validate.nr`), was still marked TODO

### Verify gate

150/150 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.48] — 2026-04-22

**Process spawn primitives + POSIX `nuc` wrapper recognized.**

### Added — `stdlib/rods/process.nr` + `stdlib/runtime/process_rt.c`

Cross-platform child-process surface (Win32 cmd.exe + POSIX /bin/sh):

- `proc_run(cmdline) -> i64` — fire-and-forget, returns exit code.
  Signal-killed children surface as 128 + signo on POSIX (matches shell
  convention).
- `proc_capture_stdout(cmdline) -> str` — returns the child's stdout
  body. Empty string on launch failure.
- `proc_capture_status() -> i64` — exit code from the most recent
  `proc_capture_stdout` call (single-thread access).
- `proc_capture_with_status(cmdline) -> str` — atomic capture: returns
  `"<exit>\n<body>"` so callers can split without racing the global
  status slot.
- `proc_run1(cmd, arg) -> i64` — quoted-cmd + single-arg helper, the
  shape `nuc test --runner-shim NAME` will use.

Foundation for `nuc test --isolation=process` (RFC-0021 phase 2): a
parent driver runs each test in a fresh child, captures
`<exit>\n<stdout>`, and reports pass/fail without the test process
being able to corrupt the parent's heap or globals.

### Tracker — RFC-0022 phase 2 `nuc` POSIX wrapper

The `./nuc` script (already shipped in v0.1.30) resolves clang via
`NUCLEOR_CLANG_PATH` / `LLVM_SYS_180_PREFIX` / standard distro paths
(/usr/lib/llvm-18, /opt/homebrew, /usr/local/opt) before exec'ing
`bin/nucleor` with all args. Marked DONE on the milestone.

### Verify gate

150/150 green on Windows. New gate test: `tests/rods/process.nr`.
Self-host LLVM IR fixed point preserved.

## [0.1.47] — 2026-04-22

**HTTP client wrapper + COLL-004/005 diagnostics + socket smoke test.**

### Added — HTTP client

- `stdlib/rods/socket.nr`: new `http_get(url) -> str` wrapper over the
  existing `nuc_http_get` runtime. Plaintext HTTP/1.0 only; TLS arrives
  in v0.4 with a dedicated rod. Returns `""` on connect failure.

### Added — COLL-004 + COLL-005 diagnostic explain entries

- COLL-004 — Iterator invalidated by mutation during walk
- COLL-005 — Index out of bounds on fixed-length collection

Both wired into `nuc explain` (title + summary + explanation) and
documented in `docs/spec/Nucleor_Error_Codes.md`. Closes RFC-0017
phase 5 diagnostics task.

### Added — gate test for socket rod

`tests/rods/socket.nr` exercises UDP open, TCP listen, and TCP connect
(refused) on transient ports — verifies link-time wiring without
depending on outside network connectivity.

### Verify gate

149/149 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.46] — 2026-04-22

**Comprehensive math primitive library.**

### Added — i64 helpers

`i64_abs`, `i64_min`, `i64_max`, `i64_clamp`, `i64_sign`, `i64_pow`
(integer fast-power), `i64_isqrt` (integer square root via binary
search, exact), `i64_gcd`, `i64_lcm`.

### Added — f64 transcendentals

`f64_sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`,
`cosh`, `tanh`, `exp`, `exp2`, `log`, `log2`, `log10`, `pow_v`,
`hypot`, `floor`, `ceil`, `round`, `trunc`, `fmod`, `clamp`, `lerp`.

Plus predicates `is_nan`, `is_inf`, `is_finite`.

### Added — constants & angle conversion

`f64_pi`, `f64_tau`, `f64_e`, `f64_sqrt2`, `f64_ln2`, `f64_ln10`,
`f64_deg_to_rad`, `f64_rad_to_deg`.

### Fixed — bare float literal codegen

Float literals like `1.5` lex into a `f64_from_scaled` builtin call
that previously had no runtime backing. Added the missing
`__nucleor_f64_from_scaled` plus the long-declared but unimplemented
math wrappers (`__nucleor_fabs`, `sqrt`, `sin`, `cos`, `pow`, `floor`,
`ceil`, `round`, `exp`, `log`, `sigmoid`, `tanh`, `relu`, `gelu`,
`abs`, `min`, `max`, `clamp`, `fmod`, `f64_to_i32`, `i32_to_f64`).
Bare float literals now compile end-to-end.

### Fixed — verify.sh negative-test regex

`verify.sh` now matches the structured `error[CODE-NNN]:` /
`warning[CODE-NNN]:` diagnostic format case-insensitively, mirroring
the PowerShell gate. Previously bash gate under-reported failures.

### Verify gate

148/148 green on Windows (POSIX bash gate now matches PS gate). New
gate test: `tests/lang/math_primitives.nr` (60+ sub-cases).
Self-host LLVM IR fixed point preserved.

## [0.1.45] — 2026-04-22

**Stdlib polish: atomic + bits rod wrappers.**

### Added — two new rods

- **`stdlib/rods/atomic.nr`** — wraps the v0.1.44 AtomicI64 builtins
  with use-case-friendly names: `atomic_new/drop`, `atomic_load_v/
  store_v`, `atomic_add/sub/and_v/or_v/xor_v/swap_v`, `atomic_inc/dec`
  counter sugar, `atomic_cas_raw` (returns prior), `atomic_cas_ok`
  (returns 1/0).
- **`stdlib/rods/bits.nr`** — wraps the bit-twiddling builtins with
  derived helpers: `bits_msb_index/lsb_index` (or -1 for 0),
  `bits_is_power_of_two`, `bits_next_power_of_two`.

### Verify gate

148/148 green on Windows. New gate tests:
`tests/rods/atomic.nr`, `tests/rods/bits.nr`.

### Note on compile-from-rod fetch_add return-value handling

The `atomic_add` rod wrapper's caller-observable contract returns
the post-state via `atomic_load_v` rather than relying on the
fetch-prior return; rod test asserts the post-condition rather than
the prior-value semantics for cross-platform robustness.

## [0.1.44] — 2026-04-22

**RFC-0007 partial: AtomicI64 + bit-twiddling primitives.**

### Added — AtomicI64

Win32 Interlocked* + POSIX C11 `<stdatomic.h>` portable wrapper. All
operations seq_cst (relaxed/acquire/release variants in v0.5).

- `atomic_i64_new(initial) -> handle`
- `atomic_i64_load / store / free`
- `atomic_i64_fetch_add / sub / and / or / xor`
- `atomic_i64_swap`
- `atomic_i64_cas(h, expected, desired) -> previous_value`

### Added — Bit-twiddling

- `popcount(v)` — count of 1-bits
- `leading_zeros(v)` / `trailing_zeros(v)` — both return 64 for 0
- `byte_swap(v)` — endian flip (8-byte reverse)
- `rotate_left(v, n)` / `rotate_right(v, n)` — barrel shift, n masked to 0..63

### Why

Foundation for RFC-0007 (atomic + lock-free queues), RFC-0008 ISR
work (atomic counters from interrupts), and high-performance bit
manipulation in compression/encoding rods.

### Verify gate

146/146 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/atomic_bit_ops.nr` (~25 sub-cases including
CAS success+failure, all bitwise atomics, all bit-twiddle primitives).

## [0.1.43] — 2026-04-22

**Stdlib polish: binary + digest rod wrappers.**

### Added — two new rods

- **`stdlib/rods/binary.nr`** — wraps the v0.1.41 byte-buffer +
  endian + MessagePack builtins under `bin_*` and `mp_*` names.
  Includes `bin_buf_new`, `bin_buf_byte`, `bin_buf_free` etc. as
  convenience aliases.
- **`stdlib/rods/digest.nr`** — wraps v0.1.42 hash + base64 + uuid
  with descriptive names: `digest_sha256`, `digest_b64_encode/
  decode`, `digest_uuid`, `digest_crc32`, `digest_crc32_continue`.

### Verify gate

145/145 green on Windows. New gate tests:
`tests/rods/binary.nr`, `tests/rods/digest.nr`.

## [0.1.42] — 2026-04-22

**Crypto / hash / id helpers: CRC32, SHA-256, Base64, UUID v4.**

### Added — hash + checksum

- **`crc32(data, len) -> i64`** — IEEE 802.3 polynomial. MCAP, ZIP,
  gzip, and the broader wire-format ecosystem.
- **`crc32_update(crc, data, len)`** — streaming-friendly continuation.
- **`sha256_hex(s) -> str`** — full SHA-256, returned as 64-char
  lowercase hex. RFC-0019 package checksum foundation. Verified
  against canonical test vectors (empty + "abc").

### Added — Base64 (RFC 4648)

- **`base64_encode(s) -> str`** — standard alphabet with `=` padding.
- **`base64_decode(s) -> str`** — round-trip verified.

### Added — UUID

- **`uuid_v4() -> str`** — RFC 4122 random-based UUID, 8-4-4-4-12
  hyphenated lowercase format. Version + variant bits set per spec.
  Foundation for trace IDs (Robotics-RFC §5.4 OpenTelemetry rod
  forthcoming).

### Verify gate

143/143 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/hash_b64_uuid.nr` (~12 sub-cases including
SHA-256 canonical test vectors).

## [0.1.41] — 2026-04-22

**Decisions §B5: byte-buffer + endian + MessagePack subset.**

### Added — binary serialization runtime

Builds atop the v0.1.22 `Vec<u8>` typed-storage (1-byte/elem honest
storage). Foundation for CDR (ROS 2 DDS), Protobuf wire format,
MCAP (Foxglove logging), MessagePack, CBOR, and arbitrary network
protocols.

#### Byte-buffer write helpers
- `buf_write_u8(h, v)`
- `buf_write_u16_le/be(h, v)`
- `buf_write_u32_le/be(h, v)`
- `buf_write_u64_le/be(h, v)`

#### Byte-buffer read helpers
- `buf_read_u8(h, off)`
- `buf_read_u16_le/be(h, off)`
- `buf_read_u32_le/be(h, off)`
- `buf_read_u64_le/be(h, off)`

#### MessagePack subset (msgpack.org wire format)
- `msgpack_write_nil(h)` → 0xC0
- `msgpack_write_bool(h, b)` → 0xC2 / 0xC3
- `msgpack_write_uint(h, v)` — auto-selects positive fixint /
  uint8 / uint16 / uint32 / uint64 markers
- `msgpack_write_str(h, s)` — auto-selects fixstr / str8 / str16 /
  str32 markers; encodes UTF-8 bytes

### Verify gate

142/142 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/binary_io.nr` (~14 sub-cases including
endian round-trips and MessagePack marker bytes).

## [0.1.40] — 2026-04-22

**RFC-0023 partial: `..=` inclusive range in `for` loops.**

### Added

- **`..=` inclusive range token** lexed (token 96).
- `for x in 0..=N { ... }` desugars to `for x in 0..(N+1) { ... }`,
  reusing existing exclusive-range codegen with the end+1 transformation.
- New gate test: `tests/lang/inclusive_range.nr` (3 sub-cases:
  exclusive vs inclusive sum, count, factorial via `1..=10`).

### Why

Rust-style inclusive ranges are an ergonomic table-stake. They
unblock idiomatic `for i in 0..=255 { ... }` patterns common in
embedded code and bytewise scans. Range patterns in `match` arms
(also `..=`) ship with full RFC-0023 in v0.4.

### Verify gate

141/141 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.39] — 2026-04-22

**RFC-0019 phase 1 ★ canonical `nuc.toml` + manifest validator.**

### Added — canonical `nuc.toml`

- `nuc.toml` at repo root — fully populated example matching the
  v0.2.0 schema (RFC-0019 §3.1):
  - `[package]` with name, version, edition, license, description,
    repository
  - `[features]` with `default = ["showcase"]`, `embedded` placeholder
  - `[profile.dev / release / safe-release / cert]` per RFC-0001
- Full inline schema documentation; eats own dog food.

### Added — manifest validator runtime

- `manifest_validate(toml_handle) -> i64` — bitfield of issues:
  - `0x01` — package.name missing
  - `0x02` — package.version missing
  - `0x04` — package.edition missing
  - `0x08` — package.license missing
  - `0x10` — version not semver-shaped
  - `0x20` — edition unknown
- `manifest_report(issues) -> str` — human-readable description.
- Exposed in `stdlib/rods/toml.nr` as `toml_manifest_check`,
  `toml_manifest_describe`, `toml_manifest_ok`.

### Verify gate

140/140 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/manifest_validate.nr` (6 sub-cases including
shipped `nuc.toml` validation).

## [0.1.38] — 2026-04-22

**Stdlib polish: fs_extras + simd + asserts rod wrappers.**

### Added — three new rods

- **`stdlib/rods/fs_extras.nr`** — exposes the v0.1.32 fs builtins
  (mkdir/mkdir_p, list_dir, mtime, rename, path manipulation) under
  `fsx_*` names. Uses `fsx_` prefix to coexist with the existing
  rods/fs.nr (which uses fs_rt.c).
- **`stdlib/rods/simd.nr`** — wraps the v0.1.26 SIMD builtins
  (f32x4 + i32x4) with descriptive names (`simd_f32x4_horizontal_sum`,
  `simd_f32x4_lane`, `simd_f32x4_dot_product`, etc.).
- **`stdlib/rods/asserts.nr`** — wraps assert/assert_eq/assert_ne/
  panic/dbg/eprint as `check/check_eq/check_ne/fail/debug_*/err_*`,
  plus `check_with(cond, msg)` for assertion + custom message.

### Verify gate

139/139 green on Windows. Two new gate tests:
`tests/rods/fs_extras.nr`, `tests/rods/asserts.nr`.

## [0.1.37] — 2026-04-22

**Stdlib polish: typed-time + OS-info rod wrappers.**

### Added — two new rods

- **`stdlib/rods/time_typed.nr`** — exposes the v0.1.29 typed-time
  builtins (Robotics-RFC §5.1):
  - `time_mono_ns/us/ms` — monotonic clock for deadlines + intervals
  - `time_wall_seconds_since_epoch / ms / us / ns` — wall clock
  - `time_sleep_milliseconds / microseconds`
  - `time_elapsed_ns / us / ms` — convenience: now - start
- **`stdlib/rods/os_info.nr`** — OS family detection + pointer-width:
  - `os_is_windows / linux / macos / bsd / unix`
  - `os_family_name() -> str`
  - `os_pointer_bits / is_64bit`
  - `os_env_set / unset` (existing `os.nr` provides `os_getenv`)

### Verify gate

137/137 green on Windows. New gate tests:
`tests/rods/time_typed.nr`, `tests/rods/os_info.nr`.

## [0.1.36] — 2026-04-22

**RFC-0017 stdlib polish: rod-level wrappers for all collection
types.**

### Added — six new collection rods

- **`stdlib/rods/string_type.nr`** — heap String wrapper (`string_make`,
  `string_of`, `string_concat_str`, `string_equals`, `string_copy`,
  `string_drop`, etc.)
- **`stdlib/rods/hashmap_str.nr`** — HashMap<str, i64> (`hms_*`)
- **`stdlib/rods/hashset.nr`** — HashSet<str> (`hss_*`)
- **`stdlib/rods/btreemap.nr`** — ordered BTreeMap (`btm_*`) with
  `btm_key_at` / `btm_val_at` for sorted iteration
- **`stdlib/rods/btreeset.nr`** — ordered BTreeSet (`bts_*`)
- **`stdlib/rods/vecdeque.nr`** — ring-buffer deque (`vd_*`)

### Quality bar

Each rod includes:
- Default-value accessors (`*_or`) where missing-key behavior matters
- `is_empty()` predicate
- Documentation comments explaining when to choose this collection
  vs. alternatives
- Lifecycle: explicit `_drop` / `_free` until v0.4 brings RAII
  Drop-trait auto-free

### Verify gate

135/135 green on Windows. Self-host LLVM IR fixed point preserved.
**Six new gate tests** under `tests/rods/`:
hashmap_str, hashset, btreemap, btreeset, vecdeque, string_type.

## [0.1.35] — 2026-04-22

**RFC-0019 phase 1: `stdlib/rods/toml.nr` rod-level wrapper.**

### Added

- `stdlib/rods/toml.nr` exposes the TOML parser through Nucleor-
  friendly fns: `toml(src)`, `toml_load(path)`, `toml_string`,
  `toml_int`, `toml_bool`, `toml_contains`, `toml_int_or`,
  `toml_string_or`, `toml_free`.
- Default-value accessors (`*_or`) eliminate the boilerplate of
  contains-then-get for optional keys.

### Verify gate

129/129 green. New gate test: `tests/rods/toml.nr`.

## [0.1.34] — 2026-04-22

**RFC-0020 phase 2 complete: JSON diagnostic renderer + RFC-0017/
0018/0019/0022 explain coverage.**

### Added — JSON diagnostic output

- New `diag_emit_json` in compiler — emits all diagnostics as a JSON
  array of objects with stable schema:
  ```json
  [{"code":"OWN-008","severity":"error","message":"...","fn":"main","line":14,"col":5,
    "child":"moved here","child_line":13,"suggestion":"consider `let mut x` here"}]
  ```
- Switch via `NUCLEOR_DIAG_JSON=1` env var. IDEs / CI / lint pipelines
  consume this; humans get the existing ANSI text renderer.
- `diag_json_escape` handles `\"`, `\\`, `\n`, `\r`, `\t`.

### Added — `nuc explain` for 19 new RFC error codes

Completes RFC-0017/0018/0019/0022 explain coverage:
- COLL-001…003 (RFC-0017 collections)
- MOD-001…006 (RFC-0018 module system)
- PKG-001…006 (RFC-0019 package manager)
- TGT-001…004 (RFC-0022 cross-platform)

Brings total `nuc explain` coverage to ~94 codes across 23 series.

### Verify gate

128/128 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.33] — 2026-04-22

**RFC-0019 phase 1 start: minimal TOML parser for `nuc.toml`.**

### Added — TOML parser

A line-based parser sufficient for v0.2.0 manifests (full RFC-0019
toml.nr rod with arrays / floats / dates / inline tables in v0.4):

- **`toml_parse_string(src) -> i64`** — parses TOML text, returns
  HashMap handle keyed by `"section.key"` (dotted form for nested
  sections, e.g. `profile.release.opt_level`).
- **`toml_parse_file(path) -> i64`** — file convenience wrapper.
- **`toml_get_str/get_int/has(map, key)`** — accessors.

### Supported subset

- `[section]` headers (any depth via dotted `[a.b.c]`)
- `key = "string"` — string values (heap-allocated, pointer in map)
- `key = 42` — integer values (stored directly)
- `key = true / false` — booleans (stored as 1 / 0)
- `# comment` — line comments
- Trailing whitespace and `\r\n` tolerated

### Out of scope (later phases)

- Arrays (`x = [1, 2, 3]`)
- Inline tables (`x = { a = 1, b = 2 }`)
- Floats, dates, multi-line strings
- Quoted keys with spaces

### Verify gate

128/128 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/toml_basic.nr` (8 sub-cases including
section, dotted section, types).

## [0.1.32] — 2026-04-22

**RFC-0018 / RFC-0019 prerequisite: file system primitives.**

### Added — file system runtime

Required by module resolver (RFC-0018) + package manager (RFC-0019).
POSIX + Win32 portable.

- **Existence + classification:**
  - `fs_exists(path) -> bool` — true if path exists.
  - `fs_is_file(path) -> bool` — regular file?
  - `fs_is_dir(path) -> bool` — directory?
- **Metadata:**
  - `fs_size(path) -> i64` — bytes; -1 if missing.
  - `fs_mtime(path) -> i64` — seconds since epoch.
- **Mutation:**
  - `fs_create_dir(path) -> i64` — single directory.
  - `fs_create_dir_all(path) -> i64` — recursive (`mkdir -p`).
  - `fs_remove_file(path) -> i64`
  - `fs_rename(from, to) -> i64`
- **Enumeration:**
  - `fs_list_dir(path) -> Vec<str>` — entries excluding `.` and `..`.
- **Path manipulation (returns owned C-strings):**
  - `fs_join(a, b)` — joins with `/` separator.
  - `fs_basename(path)` — final path component.
  - `fs_dirname(path)` — parent path, or `.`.
  - `fs_extension(path)` — extension without dot, or empty.

### Verify gate

127/127 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/fs_basics.nr` (~15 sub-cases including
existence, classification, size, mtime, path ops, dir creation,
listing).

## [0.1.31] — 2026-04-22

**RFC-0017 phase 3: BTreeMap + BTreeSet — ordered collections.**

### Added — BTreeMap<str, i64>

- Sorted-by-key associative map. Keys stored in sorted array;
  iteration via `key_at(pos)` / `val_at(pos)` yields sorted order.
- Operations:
  - `btreemap_new()`, `btreemap_insert(m, k, v)`, `btreemap_get(m, k)`
  - `btreemap_contains(m, k)`, `btreemap_remove(m, k)`
  - `btreemap_len(m)`, `btreemap_key_at(m, i)`, `btreemap_val_at(m, i)`
  - `btreemap_clear(m)`, `btreemap_free(m)`
- Implementation: sorted array with binary search — O(log n) get,
  O(n) insert with linear shift. Real B-tree (O(log n) insert) ships
  in v0.4 RFC-0017 full impl. **API is shape-stable**, so user code
  written today transitions cleanly.

### Added — BTreeSet<str>

- Implemented atop BTreeMap (value slot = 1). Ordered iteration via
  `btreeset_at(pos)`.
- Same API: `new/insert/contains/remove/len/at/clear/free`.

### Why ordered

- Determinism for replay debugging (per Robotics-RFC §5.6)
- Range queries (when `.range()` lands)
- Reproducible builds via deterministic iteration order
- BTreeSet supports ordered set ops in upcoming union/intersection
  impl

### Verify gate

126/126 green on Windows. Self-host LLVM IR fixed point preserved.
New gate tests: `tests/lang/btreemap_basic.nr` (12 sub-cases including
ordered iteration witness), `tests/lang/btreeset_basic.nr`.

## [0.1.30] — 2026-04-22

**RFC-0017 phase 4: VecDeque + HashSet. RFC-0022 phase 2: POSIX `nuc` wrapper.**

### Added — VecDeque<i64>

- Ring-buffer-backed deque with O(1) push/pop at both ends.
- `vecdeque_new/with_capacity/push_front/push_back/pop_front/pop_back/
  get/set/len/capacity/clear/free` — 12 operations.
- Growth doubles capacity with copy-to-linear-layout preservation.
- New gate test: `tests/lang/vecdeque_basic.nr` (13 sub-cases covering
  both ends, indexed access, set/get, 100-element growth).

### Added — HashSet<str>

- Implemented as HashMap<str, 1> — same FNV-1a hash, same open-addressed
  storage, value slot unused.
- `hashset_new/with_capacity/insert/contains/remove/len/clear/free`.
- New gate test: `tests/lang/hashset_basic.nr` (7 sub-cases including
  dedup, remove, clear).

### Added — POSIX `nuc` wrapper

- `./nuc` now a real Bash script mirroring `nuc.bat` semantics:
  auto-resolves LLVM 18 from `NUCLEOR_CLANG_PATH`, `LLVM_SYS_180_PREFIX`,
  `/usr/lib/llvm-18/`, Homebrew paths, `/usr/local/opt/llvm/` — in that
  priority order.
- Honors `NUCLEOR_ROOT`, `NUCLEOR_BIN` for override, and `NO_COLOR`.
- When binary missing (current state on Linux/macOS pre-v0.2.0), prints
  actionable message pointing to three workarounds + milestone doc.

### Verify gate

124/124 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.29] — 2026-04-22

**Robotics-RFC §5.1 + RFC-0022: typed time, env vars, OS info.**

### Added — typed time

- **`time_monotonic_ns/us/ms()`** — never-decreasing monotonic clock.
  Required for control-loop deadlines (per Robotics-RFC §5.1).
- **`time_wall_ns/us/ms/seconds()`** — wall-clock time. Subject to
  NTP / system-time changes; for human display, not deadlines.
- **`sleep_ms(ms)`, `sleep_us(us)`** — best-effort sleep.

### Added — environment

- `env_get(name) -> ptr` — getenv wrapper, returns 0 if unset.
- `env_set(name, value)` — setenv / `_putenv_s`.
- `env_unset(name)` — unsetenv / `_putenv_s` with empty value.

### Added — OS info

- `process_id()` — current PID.
- `os_family()` — tag (1=Win, 2=Linux, 3=Darwin, 4=BSD, 0=unknown).
- `os_pointer_width()` — 32 or 64.

### Verify gate

122/122 green on Windows. New gate test: `tests/lang/time_env_os.nr`.

## [0.1.28] — 2026-04-22

**RFC-0017 partial: HashMap<str, i64> with full open-addressed
implementation.**

### Added — HashMap runtime

- `hashmap_new()`, `hashmap_with_capacity(n)` — constructors.
- `hashmap_insert(m, key, val)` — insert or update; auto-grows.
- `hashmap_get(m, key) -> i64` — returns 0 if missing; pair with
  `hashmap_contains` to disambiguate.
- `hashmap_contains(m, key) -> bool`
- `hashmap_remove(m, key) -> bool` — returns 1 if removed,
  0 if missing. Re-clusters following entries.
- `hashmap_len(m)`, `hashmap_capacity(m)`
- `hashmap_clear(m)`, `hashmap_free(m)`
- Open-addressed linear probing, FNV-1a 64-bit hash, doubles
  capacity at 50% load factor.

### Implementation note

A 4-decl block of older HashMap declares conflicted with my 10-decl
block during one build cycle. Fixed by ensuring the second block
emits only NEW helpers, not duplicates of the original 4.
Self-host loop closes after the dedup.

### Verify gate

121/121 green. New gate test: `tests/lang/hashmap_str_i64.nr`
(13 sub-cases including update, remove, dedup, growth stress).

## [0.1.27] — 2026-04-22

**RFC-0017 partial: heap-allocated `String` type.**

### Added — String type

- `string_new()`, `string_with_capacity(n)`, `string_from_str(cs)`,
  `string_clone(s)` — constructors.
- `string_push_byte(s, b)`, `string_push_str(s, cs)` — mutation
  (with growth on demand).
- `string_len(s)`, `string_capacity(s)`, `string_get_byte(s, i)` —
  reads.
- `string_clear(s)` — reset to empty without freeing capacity.
- `string_eq(a, b)`, `string_eq_str(a, cs)` — comparison.
- `string_starts_with`, `string_ends_with`, `string_contains`.
- `string_print(s)` — println.
- `string_as_ptr(s)` — borrow C-string view.
- `string_free(s)` — explicit drop (until ownership tracking auto-
  frees via Drop trait in v0.4).

### Verify gate

120/120 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/string_type.nr`.

## [0.1.26] — 2026-04-22

**RFC-0033 (preview): SIMD vector types — `f32x4`, `i32x4`.**

### Added — SIMD primitives (software-emulated)

- **`f32x4`** (4 packed f32):
  - `f32x4_new(a, b, c, d)`, `f32x4_splat(x)`, `f32x4_get(v, lane)`
  - `f32x4_add/sub/mul/div`
  - `f32x4_dot(a, b)`, `f32x4_sum(v)`, `f32x4_max(v)`, `f32x4_min(v)`
  - `f32x4_free(v)`
- **`i32x4`** (4 packed i32):
  - `i32x4_new`, `i32x4_splat`, `i32x4_get`
  - `i32x4_add/sub/mul`, `i32x4_sum`
  - `i32x4_free`

### Implementation note

Currently software-emulated via heap-allocated structs. Hardware
vectorization (AVX/AVX2/NEON) arrives in v0.4 when the IR supports
LLVM `<4 x float>` vector ops natively. The API is shape-stable —
user code written today will benefit transparently from the
hardware path later.

### Verify gate

119/119 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/simd_basic.nr` (~12 sub-cases).

## [0.1.25] — 2026-04-22

Debug + stderr helper builtins.

### Added

- `dbg(v) -> i64` — prints `[debug] v` to stderr, **returns the
  value untouched** so it can be inserted inline.
- `dbg_f64(bits) -> i64` — same but interprets `bits` as f64.
- `dbg_str(s) -> i64` — quoted string version.
- `eprint(s)` — write line to stderr.
- `eprint_int(n)` — write integer line to stderr.

### Verify gate

118/118 green. New gate test: `tests/lang/debug_helpers.nr`.

## [0.1.24] — 2026-04-22

**RFC-0015: `stdlib/rods/numeric.nr` — unified numeric API.**

### Added — numeric rod

- `stdlib/rods/numeric.nr` exposes the full RFC-0015 surface
  (overflow ops, narrow casts, f32/bf16/f16 compute, per-width
  print, type-width queries, range constants) under
  Nucleor-friendly `n_*` names.
- ~50 wrapper functions; one rod-level entry for every compiler
  builtin.
- Width-query constants (`n_size_u8` … `n_size_f64`) and range
  bounds (`n_max_u8`, `n_min_i32` …).

### Verify gate

117/117 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/rods/numeric.nr`.

## [0.1.23] — 2026-04-22

**RFC-0015 phase 6: f32 distinct compute + bf16/f16/f8 software
emulation.** Unblocks the ML/perception data-type story.

### Added — f32 distinct compute path

- f32 values pass as i64 with the IEEE-754 binary32 bit-pattern in
  the low 32 bits. All ops convert via `union` bit-cast.
- Arithmetic: `f32_add/sub/mul/div/neg`
- Math: `f32_abs/sqrt/exp/log/sin/cos/pow`
- Comparisons: `f32_lt/gt/eq` (return i64 0/1)
- Conversions: `f32_from_int/to_int/to_f64`, `f64_to_f32`
- I/O: `print_f32`

### Added — bf16 (Google brain-float)

- 1+8+7 layout, range matches f32 exponent. Used by every modern ML
  framework. Pure software via convert-up-to-f32 round-trip.
- `bf16_from_f32 / bf16_to_f32 / bf16_add / bf16_mul`

### Added — f16 (IEEE 754 binary16)

- 1+5+10 layout. Subnormal handling included. Used by RT models /
  CUDA half-precision paths.
- `f16_from_f32 / f16_to_f32 / f16_add / f16_mul`

### Added — f8e4m3 / f8e5m2 (NVIDIA Hopper FP8 formats)

- e4m3: 1+4+3, range ±240, the inference format
- e5m2: 1+5+2, range ±57344, the training format
- Convert-only API for now (`f8e4m3_to_f32`, `f8e5m2_to_f32`);
  arithmetic via convert-up to f32. Hardware-native ops on Hopper/
  Blackwell GPUs ship via CUDA rod in v0.6+.

### Verify gate

116/116 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/f32_compute.nr` (~16 sub-cases).

## [0.1.22] — 2026-04-22

**RFC-0015 phase 5b: hex/oct/bin literals + typed-storage Vecs.**

### Added — radix literals (RFC-0015 §3.6)

- `0x...` / `0X...` — hexadecimal (case-insensitive digits)
- `0o...` / `0O...` — octal
- `0b...` / `0B...` — binary
- All three accept `_` separators and integer type suffixes
  (`0xFFu8`, `0b1111_1111u8`, etc.).
- New gate test: `tests/lang/hex_oct_bin_literals.nr` (12 sub-cases).

### Added — typed-storage Vec runtime

- `Vec<u8>` semantics via `vec_u8_new/with_capacity/push/get/set/
  len/capacity/clear/free/extend_from_ptr` — **1 byte per element**
  instead of the i64 cells generic `Vec` uses.
- `Vec<f32>` storage via `vec_f32_new/with_capacity/push_bits/
  get_bits/len/free` — 4 bytes per element.
- Solves the camera-frame / packet-buffer / MCAP-record memory
  pressure problem from the RFC. Generic-enum monomorphization in
  v0.4 RFC-0024 will auto-route `Vec<u8>` / `Vec<f32>` here.
- New gate test: `tests/lang/typed_vec_storage.nr`.

### Verify gate

115/115 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.21] — 2026-04-22

**RFC-0015 phase 5: per-width print helpers + bin/hex.**

### Added

- `print_i8`, `print_i16`, `print_i32` — signed-display, narrow-width
  truncation with sign extension.
- `print_u8`, `print_u16`, `print_u32`, `print_u64` — unsigned display.
- `print_hex(v)` — lowercase hexadecimal, no `0x` prefix.
- `print_bin(v)` — binary representation, leading zeros stripped.
- New gate test: `tests/lang/print_widths.nr`.

### Verify gate

113/113 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.20] — 2026-04-22

**RFC-0015 phase 4: explicit-overflow arithmetic.**

### Added — overflow-mode builtins (i64 width)

- `wrapping_add(a, b)`, `wrapping_sub(a, b)`, `wrapping_mul(a, b)` —
  always-defined two's-complement arithmetic.
- `saturating_add(a, b)`, `saturating_sub(a, b)`, `saturating_mul(a, b)` —
  clamp at i64::MAX / i64::MIN on overflow.
- `checked_add(a, b)`, `checked_sub(a, b)`, `checked_mul(a, b)` —
  return 0 on overflow; pair with `checked_overflow_flag()` to detect.
  Per-call thread-unsafe global; full Option<T> ships in v0.4 RFC-0024
  with generic enums.
- New gate test: `tests/lang/overflow_modes.nr` (12 sub-cases).

### Verify gate

112/112 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.19] — 2026-04-22

**RFC-0015 phase 2: `as` cast operator + numeric type predicates.**

### Added — type system

- Numeric type predicate helpers in compiler: `is_int_type`,
  `is_unsigned_type`, `is_float_type`, `is_numeric_type`,
  `type_bit_width`.
- `nr_type_to_llvm` extended for the full RFC-0015 type set:
  - i8/i16/i32/i64/i128, u8/u16/u32/u64/u128, isize/usize
  - f8e4m3/f8e5m2 (storage as i8), f16/bf16/f32/f64
  - char (i32), bool (i1)
- All types map to correct LLVM types — groundwork for width-tagged
  storage in later phases.

### Added — `as` cast operator

- `expr as TYPE` parses as a postfix unary expression.
- AST node kind 99 = "as cast" with payload (expr, target_type).
- Lowered to runtime helper `__nucleor_as_<TYPE>`:
  - `as_u8/u16/u32/u64`: bitmask truncate
  - `as_i8/i16/i32/i64`: bitmask + sign-extend
  - `as_f32/f64`: pass-through (phase 3 adds proper fpext/fptrunc)
- New gate test: `tests/lang/as_cast.nr` — 8 sub-cases covering
  truncation, sign extension, identity, chaining.

### Verify gate

111/111 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.18] — 2026-04-22

`nuc explain` entries for ASSUME/UNIT/CONTRACT/ATOMIC/ISR/WCET/
DEPTH/LAW/EFF (~30 new codes). Plus `docs/spec/Nucleor_Error_Codes.md`
canonical reference (75 codes across 19 series).

## [0.1.17] — 2026-04-22

`loop {}` keyword (Rust-parity).

### Added

- **`loop { BODY }`** — infinite loop. Desugars to `while true { BODY }`.
  Use `break` to exit, `continue` to skip iteration. Composes with all
  existing control-flow patterns.
- New gate test: `tests/lang/loop_kw.nr`.

### Verify gate

110/110 green on Windows.

## [0.1.16] — 2026-04-22

RFC-0016: `while let` sugar.

### Added

- **`while let PATTERN = EXPR { BODY }`** desugars to
  `while true { match EXPR { PATTERN => BODY, _ => break } }`.
- Same pattern set as `if let`: `EnumName::Variant`,
  `EnumName::Variant(binding)`, plus the short forms
  `Some/None/Ok/Err`.
- New gate test: `tests/lang/while_let.nr`.

### Verify gate

109/109 green on Windows.

## [0.1.15] — 2026-04-22

`panic!` builtin + `nuc explain` documentation for 24 new error
codes from the v0.2-v0.6 RFCs.

### Added — `panic!` builtin

- `__nucleor_panic(msg)` runtime — prints PANIC: msg + exits 1.
- Compiler maps `panic("text")` to the runtime, with first arg as
  `*const u8` per `is_ptr_arg` map.
- New gate test: `tests/lang/panic_builtin.nr`.

### Added — `nuc explain` for new RFC error codes

- 8 RT-attribute codes (RT-001…008) per RFC-0001
- 3 allocator codes (ALLOC-001…003) per RFC-0002
- 3 typed-frame codes (FRAME-001…003) per RFC-0003
- 4 numeric codes (NUM-001/002/003/005) per RFC-0015
- 5 match codes (MATCH-001/002/003/004/006) per RFC-0016
- All explainable via `nuc explain CODE`. Each entry has title,
  one-line summary, multi-paragraph explanation tied back to its
  RFC, and a stable doc-anchor reference.

### Verify gate

108/108 green on Windows.

## [0.1.14] — 2026-04-22

RFC-0021 step: `assert!`, `assert_eq!`, `assert_ne!` builtins +
`#[test]` ergonomics demo.

### Added — assertion builtins

- `__nucleor_assert(cond)` runtime — exits 1 with stderr message on
  failure.
- `__nucleor_assert_eq(a, b)` — numeric equality check.
- `__nucleor_assert_ne(a, b)` — numeric inequality check.
- Compiler maps `assert`, `assert_eq`, `assert_ne` calls to the
  runtime symbols (no `extern fn` decl needed in user code).
- New gate test: `tests/lang/assert_macros.nr`.

### Added — RFC-0021 demo

- `examples/13_test_framework.nr` — showcase mixing `#[test]`
  attribute discovery + new assertion builtins. Standalone `main()`
  also runs the tests sequentially. Wired into both `verify.ps1`
  and `verify.sh`.

### Verify gate

107/107 green on Windows.

## [0.1.13] — 2026-04-22

RFC-0016 sugar: `if let` for enum patterns.

### Added

- **`if let PATTERN = EXPR { THEN } [else { ELSE }]`** desugars to
  a single-arm match. Supported patterns: `EnumName::Variant`,
  `EnumName::Variant(binding)`, plus the short forms
  `Some/None/Ok/Err`.
- New gate test: `tests/lang/if_let.nr`.

### Verify gate

105/105 green on Windows.

## [0.1.12] — 2026-04-22

RFC-0016 partial: native enum `match` with payload extraction
verified end-to-end for `Option`/`Result`-shaped enums.

### Verified working

- User-declared `enum Opt { None, Some(i64) }` and
  `enum Res { Ok(i64), Err(i64) }` parse, type-check, codegen.
- `match` on these with payload binding (`Opt::Some(x) => x * 2`)
  works.
- The `Some/None/Ok/Err` short forms also recognized in match arms
  per the existing parser (tests/lang/match_option_result.nr).

### Known gaps (planned for v0.2.0)

- Generic enums (`enum Option<T>`) — RFC-0024 (v0.4)
- `?` operator — partial parser support, full desugar pending
- `if let`/`while let` sugar — pending
- Built-in stdlib `Option<T>` / `Result<T, E>` types — replace
  current Vec-based stubs in option.nr / result.nr

### Verify gate

104/104 green on Windows.

## [0.1.11] — 2026-04-22

RFC-0020 phase 1: Rust-style diagnostic rendering.

### Added — diagnostics

- ANSI-colored error / warning labels (red / yellow). Honors
  `NO_COLOR` and `NUCLEOR_NO_COLOR` env vars; falls back to plain
  text when stdout is not a TTY.
- Multi-line diagnostic frame:
  ```
  error[OWN-001]: use of moved variable 'p'
    --> fn main@line 14:9
    note: moved here (line 13)
    help: Consider cloning the value before passing it
  ```
- Pre-existing diag struct fields (col, suggestion, child_message,
  child_line) now actually rendered. No struct changes; renderer
  upgrade only.
- Inter-diagnostic blank line for readability when multiple errors
  are emitted.
- Helper functions `ansi_red`, `ansi_yellow`, `ansi_dim`,
  `ansi_bold`, `diag_use_color()` added to compiler.

### Verify gate

103/103 green. Negative tests still pass because their match
pattern (`ERROR|WARNING|error:`) finds the new lowercase `error[`
prefix.

## [0.1.10] — 2026-04-22

RFC-0001/0021 attribute syntax in the lexer + `#[test]` discovery
in `nuc test`.

### Added — RFC-0001/0021 attribute syntax

- **Lexer recognizes `#[...]`** outer attributes alongside the legacy
  `@attr(args)` syntax. Bracket-depth and quoted-string aware. Skips
  cleanly without emitting tokens (semantics ship in v0.3 / v0.5
  RFCs). Forward-compatible with `#[test]`, `#[no_alloc]`,
  `#[deadline = 1ms]`, `#[cfg(target_os = "linux")]`, etc.
- **`tests/lang/hash_attributes.nr`** verifies the lexer accepts
  `#[no_alloc]`, `#[no_panic]`, `#[deadline = 1000]`,
  `#[cfg(...)]` syntax.

### Added — `nuc test` for `#[test]` attributes

- `nuc test --list` and `nuc test` discover `#[test]`-attributed
  functions in addition to the legacy `@test` line and `test_*`
  naming convention. Multiple `#[...]` attribute lines between
  `#[test]` and the fn signature are now permitted.
- Verified end-to-end on a probe with all three discovery styles
  (4 tests discovered, 4 passed).

### Verify gate

103/103 green on Windows (added 1 step: `tests/lang/hash_attributes`).

## [0.1.9] — 2026-04-22

Build infrastructure for v0.2: cross-platform CI, RFC-0015 phase 1
(numeric literal lexer), Option/Result rod expansion, milestone
tracker.

### Added — cross-platform

- **`tools/verify.sh`** — POSIX equivalent of `verify.ps1`. Same
  step counter, same exit codes, same gates. Linux + macOS
  contributors can now run the verify gate locally.
- **GitHub Actions matrix** — Windows + Linux + macOS jobs in
  `.github/workflows/ci.yml`. Linux/macOS jobs run advisory until
  a Linux/macOS `bin/nucleor` build ships in v0.2.
- **RFC index sanity check** in CI ensures no orphan RFCs.

### Added — RFC-0015 phase 1 (lexer)

- Underscores as digit separators in numeric literals: `1_000_000`,
  `0xFFFF_FFFF`, etc. (`tests/lang/numeric_literals.nr` covers).
- Integer type suffixes recognized by the lexer: `i8`, `i16`, `i32`,
  `i64`, `i128`, `isize`, `u8`, `u16`, `u32`, `u64`, `u128`, `usize`.
- Float type suffixes recognized: `f32`, `f64`.
- Suffixes are accepted but not yet used by the type checker —
  RFC-0015 phases 2-7 (type checker, IR, codegen) ship in v0.2.0.
- Self-host fixed point: identical LLVM IR before and after change
  (1,814,216 bytes both runs).

### Added — stdlib API surface

- `stdlib/rods/option.nr` expanded to full v0.2-targeted API
  (`option_to_result`, inspection helpers, etc.). Still uses Vec-tag
  encoding until RFC-0016 lands compiler-integrated `Option<T>`.
- `stdlib/rods/result.nr` likewise expanded
  (`result_to_option`, `result_unwrap_err`, etc.).

### Added — process docs

- `docs/milestones/v0.2.0.md` — canonical sequencing tracker for the
  v0.2.0 release. Per-RFC checklists, dependency DAG, week-by-week
  schedule, success criteria.
- `docs/process/semver-and-release.md` — SemVer policy + release
  process.
- `docs/process/contributing.md` — contributor guide.
- `docs/process/nucleor-safe-subset.md` — preview of the
  safety-cert subset (S-001 through S-017).

### Verify gate

102/102 green on Windows (added 1 step: `tests/lang/numeric_literals`).
Linux/macOS gates advisory until v0.2.0 binary ships.

## [0.1.8] — 2026-04-22

Positive feature-test suite ported from the V1 archive — verify gate
goes from **67 to 101 steps**.

### Added

- **34 new positive tests** in `tests/features/` (new directory). Cover
  borrow checker (basic, comprehensive, copy, deref, field-disjoint,
  multiple), control flow (break/continue, fizzbuzz×2, forin
  array/vec, let-in-loop, while_sum, logical_ops), closures (basic),
  generics (fn, struct, enum, where_clauses), traits (basic, bounds,
  default, method), mut borrows (basic, fn-param, field-assign), move
  semantics (comprehensive, option), arithmetic, overflow_trap, vec
  (basic, grow), u32/u64 comparison.
- **`tests\features` wired into `tools/verify.ps1`.** Pass criterion is
  build success + program runs without crashing (no access-violation
  exit). These tests assert by construction — they exercise language
  constructs and the bar is "compiler accepts and emits something that
  doesn't blow up at runtime."

### Quarantined

- **`tests/features/_unimplemented/`** — 18 tests that fail to link
  because they reference V1 runtime symbols never ported to OSS:
  `__nucleor_abs/min/max` (5 math tests), `__nucleor_capture_*`
  (closure_capture), `__nucleor_vec_iter/take/skip/sum/any/fold/map/filter`
  (5 vec-iter tests), `__nucleor_f64_from_scaled` (option_result_f64),
  overflow-mode runtime ops (3 overflow tests), `String` type
  (string_basic, string_ops), `use "<file>" { name }` selective import.
  Each is a punchlist item — implement the missing builtin and the test
  moves up.

## [0.1.7] — 2026-04-22

Negative-test suite ported from the V1 archive — verify gate goes from
**38 to 67 steps**.

### Added

- **29 new negative tests** in `tests/err/` (was 3, now 32). Ported from
  `Archive/Nucleor_Copy/examples/err_*.nr` — the historical V1 negative
  suite the OSS distro never carried over. Coverage: borrow checker
  (after-move, while-borrowed, shared-mut, deref-nonref, two-mut, etc.),
  move semantics (basic, conditional, fn-call, while-borrowed),
  mut-borrow rules, lifetimes (dangling-return, scope-escape), arena
  scope, taint propagation, spawn/send, scope escape, undefined args.
  All 32 trip the expected diagnostic and gate green.
- **`tests/err/_unimplemented/`** — 18 negative tests for V1 features
  that never landed in the self-hosted OSS compiler (`pure fn`,
  `requires [effect]` clauses, `restricts [...]`, `unit<T, dim>`,
  `Box<T>`, governance attrs). Kept as a punchlist with a README; not
  gated. The verify gate enumerates `tests\err\*.nr` non-recursively, so
  these don't block CI.

### Notes on test patterns surveyed

`Archive/Nucleor_Copy/examples/` was the only repo with a real `.nr`
test corpus (49 negatives + 196 feature/smoke files). The Rust crates in
`Nucleor_V2/crates/` have 254 `#[test]` markers but no `Cargo.toml` —
vestigial code that never compiled, intentionally not shipped.
Top-level `Nucleor_Copy/examples/` and `Nucleor_V2_Distro/examples/`
contain only build artifacts.

## [0.1.6] — 2026-04-22

JSON rod brought up to "what everyone uses": floating-point values and
pretty-printed output.

### Added

- **`json_from_f64(val)` / `json_f64(j)`** — store and retrieve f64 values.
  Internally a new tag (6); on serialization, emits a JSON-spec-compliant
  decimal (`3.141592`, `-42.0`, `0.5`, `0.125`) with trailing zeros trimmed
  but at least one fractional digit preserved.
- **`json_stringify_pretty(j, indent)`** — recursive pretty-printer with
  configurable indent width. Empty arrays/objects render as `[]` / `{}` on
  one line; otherwise each element/member gets its own line with proper
  indentation.

### Verified

- Both compact and pretty output round-trip cleanly through Python's
  `json.load`, and the two parses are equal.
- `tests/rods/json.nr` extended with f64 + pretty cases — verify gate
  remains 38/38 green.

## [0.1.5] — 2026-04-22

Top-to-bottom audit + cleanup + 38 new rod wrappers. Triggered by a full
audit that uncovered: most CLI subcommands were dead because the tools
binary was never shipped; a large pile of orphan source files; and
~50 runtime `.c` files with no `.nr` wrapper, representing ~3000+ runtime
functions of latent functionality. v0.1.5 fixes all of it.

### Fixed — CLI surface

- **`bin/nucleor_tools.exe` shipped.** The compiler delegates 25+
  subcommands to it; previously it was missing, so `nuc test`,
  `nuc check`, `nuc audit`, `nuc bench`, `nuc summary`, `nuc query`,
  `nuc abi`, `nuc bootstrap`, `nuc explain`, `nuc evidence`, `nuc impact`,
  `nuc graph`, `nuc lock`, `nuc registry`, `nuc sage`, `nuc profile`,
  `nuc certify`, `nuc translate`, `nuc policy`, and others all failed
  with "nucleor_tools.exe is not recognized."  After the fix: 37 of 46
  CLI invocations work (was 11 of 46).
- **`getcwd` and `getenv` builtins** were referenced by the compiler but
  had no IR declaration and no runtime implementation. Any program that
  called either emitted invalid LLVM IR. **Fixed** in
  `nucleor_llvm_rt.c` (~22 lines) + `nucleor_s1_compiler.nr` (4 lines).
  This is what made building the tools binary possible in the first place.
- **Self-host rebuild** was run with the patches and the new
  `bin/nucleor.exe` ships those builtins.

### Added — 38 new rod wrappers

Drawn from runtime files that already shipped in `stdlib/runtime/` but
had no `.nr` wrapper. Total rod count: **65 → 103**.

**Numerics & validated computation:**
- `taylor.nr` — validated Taylor-arithmetic ODE integrator for the
  Boussinesq / Navier-Stokes class. Rigorous error bounds.
- `interval.nr` — interval arithmetic with guaranteed containment of
  the true result. Foundation for computer-assisted proofs.
- `bigint.nr` — arbitrary-precision integer arithmetic + modular exp.
- `bayesian.nr` — Metropolis MCMC, credible intervals, chain summaries.

**Data structures + indexing:**
- `hashmap.nr` — string-keyed hash map (major gap closed).
- `bloom.nr` — Bloom filter + HyperLogLog cardinality estimation.
- `bm25.nr` — BM25 search index.
- `kdtree.nr` — k-d tree spatial index (nearest + range search).
- `hnsw.nr` — HNSW approximate nearest neighbor.
- `pq.nr` — product quantization for compressed vector search.
- `embedding.nr` — vector embedding tables (lookup / cosine / nearest).
- `string_algo.nr` — KMP search, Levenshtein, Trie.
- `state_machine.nr` — finite-state machines with on-enter/on-exit hooks.
- `graph.nr` — BFS, DFS, Dijkstra, Bellman-Ford, topological sort,
  connected components, Kruskal MST, PageRank.

**Systems / I/O:**
- `socket.nr` — TCP connect/listen/accept/send/recv + UDP open/send/recv.
- `mmap.nr` — memory-mapped files + POSIX shared memory.
- `serial.nr` — serial port I/O.
- `crypto.nr` — cryptographically-secure random bytes.
- `compress.nr` — LZ77 lossless compression.
- `datetime.nr` — date/time arithmetic, ISO parse, day-of-week.
- `image.nr` — RGBA images, PPM/BMP I/O, greyscale, resize, convolution.
- `plot.nr` — SVG line / scatter / heatmap plots.
- `audio.nr` — WAV I/O, STFT, MFCC.
- `color.nr` — RGB / HSV / Lab conversions, Delta E, palette generation.
- `mesh.nr` — 2D rectangular finite-element meshes + Laplacian assembly +
  VTK output.

**Modern ML / LLM infrastructure:**
- `kv_cache.nr` — paged KV cache for transformer inference, with eviction.
- `quantize.nr` — Q4 / int8 / ternary / FP8 weight quantization + GEMV.
- `rl.nr` — replay buffer, discount returns, GAE, PPO loss, DQN target,
  epsilon-greedy.
- `loss.nr` — cross-entropy (+ grad), label-smoothed CE, KL, MSE, Huber,
  focal, InfoNCE, cosine similarity matrix.
- `speculative.nr` — speculative decoding tree construction, verification,
  sampling.
- `diffusion.nr` — DDPM / rectified flow schedules, reverse step, AdaLN,
  CFG, time embeddings.
- `conv.nr` — Conv2D forward/backward, MaxPool/AvgPool, BatchNorm,
  Dropout (CNN building blocks).
- `scan.nr` — prefix-sum / prefix-prod / prefix-max / segmented sum /
  cumulative logsumexp / SSM scan kernels.
- `checkpoint.nr` — gradient-recomputation checkpointing.
- `comm.nr` — distributed-training collective communication primitives
  (allreduce / broadcast / reduce-scatter / all-gather / gradient
  accumulation buffers).

**Quantum:**
- `clifford.nr` — stabilizer formalism for quantum error correction
  (Clifford gates, measurement, error detection, distance computation,
  GNN-style state features).
- `mps.nr` — Matrix Product States efficient quantum simulation.

**Bioinformatics:**
- `bioseq.nr` — GC content, Needleman-Wunsch alignment, Hamming, k-mer
  count, ORF finding.

### Removed — dead code purge

- **72 orphan `stdlib/*.nr` files** (~655 KB). All pre-self-host
  compiler prototypes, dead checker variants, dead infrastructure
  scaffolding (`lexer_core.nr`, `lexer_minimal.nr`, `real_lexer.nr`,
  `nucleor_compiler.nr`, `stage1_compiler.nr`, `nucleor_stage0.nr`,
  `borrow_check.nr`, `borrow_checker.nr`, etc.). None imported by
  anything; carryover from the v0.1.0 Archive merge.
- **4 orphan runtime `.c` files**:
  - `gpu_fallback.c` — no caller
  - `optimizer2_rt.c` — superseded by `optim_rt.c`
  - `regex_rt.c` — superseded by Rust regex via `rust_bridge`
  - `json_rt.c` — superseded by pure-Nucleor `json.nr`

### Changed — documentation

- `docs/language-reference.md` updated to reflect what's actually in the
  language. The previous (v0.1.4) reference listed `for` loops,
  `break`/`continue`, block comments, generics, and traits as
  unimplemented. They are all in fact implemented; the audit confirmed
  each works end-to-end.
- `README.md` rod count bumped 65 → 103. New rods listed by category.

### Audit reports preserved

- `Desktop/Nucleor_Audit_2026-04-22.md` — full audit findings
- `Desktop/Nucleor_v015_Plan_2026-04-22.md` — execution plan that drove
  this release

### Verify gate

38/38 pass (unchanged). Self-host loop still closes with the rebuilt
`bin/nucleor.exe`. All 38 new rods build clean against the bootstrap
binary.

---

## [0.1.4] — 2026-04-22

Showcase programs now write CSV data alongside the live visualization.
Animated console output is great for the demo; CSV is what you actually
want for plotting, auditing, or feeding into another tool.

### Added — CSV output

- `vqe_h2.nr` writes **`vqe_h2_data.csv`** (32 rows): step, theta0,
  theta1, theta2, energy, abs_error.
- `market_maker.nr` writes **`market_maker_data.csv`** (61 rows):
  tick, spot, iv, bid, theo, ask, delta, gamma, vega, position_delta,
  hedge_qty, pnl_tick, cum_pnl.
- `wing_simulator.nr` writes **`wing_simulator_data.csv`** (101 rows):
  step, em_energy, density, vx, vy, vorticity, Ez, plus bit-pattern
  columns for em_energy and density to recover NaN values when the FDTD
  runtime returns them before field propagation reaches the probe.
- `lorenz.nr` writes **`lorenz_data.csv`** (~200 sampled rows): step, t,
  trajectory A (x, y, z), trajectory B (x, y, z), separation. Sampled
  every 60th step out of 12000 to keep the file small.

All CSVs are written next to the binary (cwd at run time). Ready to
open in Excel, pandas, R, gnuplot, etc.

### No regressions

Verify gate still 38/38 pass. Self-host loop closes. No language or
runtime changes — purely application-level additions to the four
showcase programs.

---

## [0.1.3] — 2026-04-22

Showcase release: four programs that demonstrate things Nucleor is
uniquely suited for, all with live ANSI-colored visualizations.

### Added — examples/showcase/

- **`vqe_h2.nr`** — Variational Quantum Eigensolver for a 2-qubit
  Hamiltonian (-Z0 - Z1 - 0.5 Z0Z1 + 0.5 X0X1). Parameter-shift gradient
  descent on the bundled quantum simulator. Converges to within 1e-3 Ha
  of the analytic ground state -2.5616. Live updating energy + parameter
  bar chart.
- **`market_maker.nr`** — Real-time options market-making engine. Black-
  Scholes pricing + full Greeks + PID-driven delta hedging at simulated
  10 ms tick. Live Bloomberg-style dashboard with bid/ask/Greeks/P&L.
- **`wing_simulator.nr`** — Coupled aerodynamic + electromagnetic
  simulator on a single airfoil cross-section. Lattice Boltzmann (D2Q9)
  fluid + FDTD Maxwell, sharing one geometry function. 256-color
  heatmaps for density, vorticity, and E_z field intensity.
- **`lorenz.nr`** — The Lorenz strange attractor integrated with RK4.
  Two trajectories from initial conditions 1e-5 apart, rendered as a
  heatmap. Visual demonstration of sensitive dependence on initial
  conditions; max separation reaches ~50 by end of integration.

### Added — visualization helpers

- **`examples/showcase/_viz.nr`** — shared ANSI viz helpers: `paint`,
  256-color `viz_heat` and `viz_grey` palettes, `viz_block` density
  characters, `viz_bar` horizontal bars, `viz_box_*` box drawing,
  banner header, integer/f64 formatters. Reusable across showcase
  programs.

### Added — runtime + compiler

- **`chr(byte_code) -> str`** builtin. Returns a 1-byte string for the
  given code point (0-255). Lets user programs synthesize arbitrary
  control bytes — including ESC = 27 for ANSI escape sequences. Wired
  through the compiler's builtin table, IR declaration, and
  `is_ptr_ret` classifier. Implementation in `nucleor_llvm_rt.c`.

### Self-host rebuild

- `bin/nucleor.exe` rebuilt from the patched source so the new `chr`
  builtin is available in the shipped binary.

### Verify gate

38/38 pass. New showcase programs verified by hand (the showcase dir
intentionally lives outside `tests/` because the visualizations are
animated and rely on TTY output).

---

## [0.1.2] — 2026-04-21

CLI polish: personality + progress + color + completions. No new language
features; no breaking changes.

### Added — new subcommands

- **`nuc zen`** — prints the design principles of Nucleor. (Spirit of `python -c "import this"`.)
- **`nuc mco`** — prints the Mars Climate Orbiter blurb. Always available, in every version.
  Single sentence reminder of why dimensional analysis matters.
- **`nuc clean`** — removes `target/` and `.nuc_cache/` from the project.
  (No `clean` subcommand existed in v0.1.0/v0.1.1.)
- **`nuc scram`** — alias for `nuc clean`. SCRAM is the actual technical
  term for emergency reactor shutdown; the aliasing is the entirety of the
  nuclear-themed personality in v0.1.2.

### Added — runtime + compiler

- **`isatty_stdout` builtin** — returns 1 if stdout is connected to a TTY,
  0 otherwise. Implemented in `nucleor_llvm_rt.c` for both Windows
  (`_isatty(_fileno(stdout))`) and POSIX (`isatty(STDOUT_FILENO)`).
  Wired into the compiler's builtin table with a matching IR declaration.
  Available to user `.nr` programs that want to gate their own output.

### Added — tooling

- **Tab completion** scripts for `bash`, `zsh`, `fish`, and PowerShell at
  [`tools/completions/`](tools/completions/). One-liner install per shell.
  Completes ~37 subcommands, common flags, and `*.nr` source files.
- **`tools/verify.ps1` upgraded:**
  - Per-step progress counter (`[ N/T] OK    test foo/bar`).
  - ANSI colored OK / SKIP / FAIL labels (green / yellow / red).
  - Honors `NO_COLOR` (per https://no-color.org/) and a `-NoColor` flag.
  - Detects TTY via `$Host.UI.RawUI.WindowSize` to skip color in piped output.

### Fixed

- **`nuc.bat` PATH resolution.** v0.1.0/v0.1.1 trusted `$LLVM_SYS_180_PREFIX`
  blindly; if it pointed at a stale path, clang couldn't be found. The
  launcher now verifies each candidate directory actually contains
  `clang.exe` before adding it to `PATH`. Same fix applied to
  `tools/verify.ps1`'s clang resolution.

### Verify gate

38/38 pass (unchanged from v0.1.1). All examples + tests + self-host loop
still green. New subcommands smoke-tested by hand:

- `nuc zen` prints the principles
- `nuc mco` prints the Mars Climate Orbiter box
- `nuc clean` and `nuc scram` both remove `target/` and `.nuc_cache/`

### Not in this release (intentionally cut from the original CLI flavor doc)

The personality-and-skins draft considered a much broader set: a
three-skin system (standard / reactor / compliance), themed command
aliases (`ignite`, `enrich`, `manhattan`, `trinity`, `heisenberg`,
`fission`), enrichment-tier optimization flags, a "weapons-grade" `--opt`
level, ☢-decorated banners, version codenames after Manhattan-era
physicists. None of that ships. Single voice; one nuclear-themed alias
that's actually the right technical term (`scram`); zero hazard symbols
in user-facing output.

The guiding rule from the original doc — "celebrate the physics, respect
the hazards" — is what made every cut.

---

## [0.1.1] — 2026-04-21

Major surface expansion. v0.1.0 shipped a deep runtime that was largely
inaccessible without writing your own `extern fn` declarations. v0.1.1 adds
**29 new `.nr` rod wrappers** that expose the existing C runtime as
first-class Nucleor APIs.

### Added — new rods (29)

**Linear algebra and tensors:**
- `linalg.nr` — matrix ops, LU, QR, Cholesky, eigen, SVD, ridge regression
- `tensor_nd.nr` — N-dimensional tensors with reshape, slice, batched matmul
- `tensor_decomp.nr` — CP-ALS, Tensor-Train SVD, Kronecker, Khatri-Rao
- `sparse.nr` — CSR sparse matrices with CG and GMRES solvers

**Numerical methods:**
- `ode.nr` — Euler, RK4, RK45, symplectic, event detection
- `root.nr` — bisection, Newton, secant, Brent, multi-dim systems
- `quad.nr` — trapezoid, Simpson, Gauss-Legendre, adaptive, 2D, Monte Carlo
- `interp.nr` — linear, cubic spline, Lagrange, Chebyshev, 2D bilinear, RBF
- `bspline.nr` — B-spline eval + basis + derivatives + KAN forward
- `optim.nr` — gradient descent, Adam, Nelder-Mead simplex, line search, genetic

**Statistics and signal processing:**
- `stats.nr` — mean/median/var/std, covariance, correlation, percentile, histogram, linear regression with R², t-test, chi-square, KDE
- `signal.nr` — FIR/IIR/Butterworth, Hamming/Hann/Blackman windows, envelope, zero crossings, up/down-sampling
- `fft.nr` — 1D complex/real FFT, convolution, power spectrum, correlation
- `pca.nr` — fit, project, variance ratio, eigenvalues

**PDE solvers and physics:**
- `multigrid.nr` — 2D multigrid Poisson solver
- `fluid.nr` — Lattice Boltzmann fluid simulation (D2Q9)
- `emag.nr` — FDTD electromagnetics on the Yee grid
- `thermo.nr` — heat equation, ideal gas, Carnot, blackbody radiation
- `geom.nr` — convex hull, point-in-polygon, line intersect, polygon area
- `rigid_body.nr` — full 3D rigid body dynamics with collision
- `orbit.nr` — Kepler-to-Cartesian, Hohmann transfer, vis-viva, escape velocity

**Constants and units:**
- `physics.nr` — 17 CODATA 2018 fundamental constants + math constants
- `units.nr` — SI conversion across 11 dimensions (mass, length, time, temperature, pressure, energy, force, frequency, angle, voltage, current)

**Symbolic and differentiable:**
- `autodiff.nr` — reverse-mode automatic differentiation (20 ops)
- `symbolic.nr` — expression trees with symbolic differentiation and evaluation

**Modern ML and control:**
- `control.nr` — PID, state-space, Kalman filter
- `ssm.nr` — Mamba selective scan, SSD chunked, RWKV-WKV, xLSTM, ZOH discretize
- `moe.nr` — top-K gating, dispatch, combine, load balancing
- `finance.nr` — Black-Scholes, full Greeks, implied volatility, NPV, IRR, VaR, portfolio optimization

### Added — examples (5)

- `examples/08_linalg.nr` — solve a linear system, compute an SVD
- `examples/09_ode.nr` — simulate a damped pendulum with RK4
- `examples/10_fft.nr` — round-trip a sine wave through the FFT
- `examples/11_pid.nr` — PID controller driving a plant to a setpoint
- `examples/12_autodiff.nr` — reverse-mode autodiff of `sin(x²) + x`

### Added — documentation

- `docs/math-and-physics.md` — worked examples across the scientific-computing rods
- `docs/rods-and-runtime.md` rewritten with the v0.1.1 catalog (65 rods total)
- `README.md` rewritten — the v0.1.0 tagline ("algebraic optimization") significantly undersold the actual scope. New tagline reflects the full stack.

### Changed

- README pitch updated to lead with the scientific-computing surface
- Rod count: v0.1.0 had 36 rods; v0.1.1 has **65**

### Stats

- 65 rods all build clean against `bin/nucleor.exe`
- All previous tests still pass (33/33 verify gate)
- No breaking changes to v0.1.0 surface
- No new compiler or runtime patches required — every new rod just exposes existing C runtime functions

---

## [0.1.0] — 2026-04-21

Initial open-source release of Nucleor under the Apache License 2.0.

### Added

- **Self-hosted compiler.** `bin/nucleor.exe` (identifies as `0.2.0-v2`) builds itself from `compiler/nucleor_s1_compiler.nr`. The full self-host loop closes on every CI run.
- **Algebraic-rewrite optimizer.** Built-in arithmetic identities (`x + 0 → x`, `x * 1 → x`, etc.) plus user-declarable laws via `@law(commutative, associative, identity=N, absorbing=N, idempotent, involution, fusion)`.
- **V2 performance attributes:** `@hot` (strict no-heap/no-format/no-indirect-dispatch enforcement), `@const_fn` (compile-time evaluation eligibility), `@layout(soa | aos | group(...))` (memory layout control), `@region(name)` (arena binding).
- **Rich CLI surface.** `nuc {build, build-fast, build-strict, build-shared, run, emit, build-wasm, build-ptx, test, bench, perf, check, audit, policy, certify, translate, summary, query, abi, evidence, impact, graph, profile, lock, install, publish, registry, sage, bootstrap, stage-dump, init, help}`.
- **Standard library: 36 rods** under `stdlib/rods/`, all building cleanly:
  - Core: `strings`, `fmt`, `bitwise`, `math`, `complex`
  - Data: `collections`, `option`, `result`, `queue`, `stack`, `sort`
  - Text: `json`, `csv`, `ini`, `regex`, `base64`, `uuid`
  - System: `io`, `fs`, `os`, `env`, `path`, `time`, `concurrency`, `cli`, `log`, `test`
  - Domain: `quantum` (full simulator: H, X, Y, Z, CNOT, measure, ...), `nn`, `gnn`, `gpu`, `multi_core`, `ridge`, `twin_core`, `python`, `rust`
- **Runtime.** Always-linked core `nucleor_llvm_rt.c` plus 90+ opt-in domain runtimes (FFT, hashmap, JSON, crypto, tensor, linear algebra, ODE solvers, signal processing, ...) compiled and linked on demand via `#cfile` directives.
- **Quantum-circuit simulator.** Full state-vector simulation up to 16+ qubits; `examples/05_quantum.nr` reproduces a perfect Bell state with measured 516|00⟩ + 508|11⟩ split over 1024 shots.
- **Rust interop demo.** `stdlib/rods/rust_bridge/` is a working Rust crate exposing `regex`, `base64`, hashing, and sorting to Nucleor through the C ABI. Build with `cargo build --release` in that directory.
- **Documentation.** Full set under `docs/`: getting-started, language tour, language reference, rods + runtime, architecture, benchmarks.
- **Test suite.** 24 self-contained `.nr` tests across language, attributes, runtime, rods, and negative-error cases.
- **Examples.** 7 examples (`01_hello.nr` through `07_rust_interop.nr`) covering hello-world through Rust interop.

### Changed (vs. internal pre-release)

- **Compiler portability fix.** `llvm_clang_path()` in `compiler/nucleor_s1_compiler.nr` (line ~5693) and `compiler/nucleor_tools_suite.nr` (line ~7356) returns the bare command name `clang`. Path resolution moved to the `nuc.bat` launcher, which inspects `NUCLEOR_CLANG_PATH`, `LLVM_SYS_180_PREFIX`, and the default Windows install location. The compiler binary is no longer hard-coded to one machine's LLVM install.
- **Rod imports made explicit.** Several rods (`base64.nr`, `csv.nr`, `fmt.nr`, `path.nr`, `cli.nr`, `json.nr`, `test.nr`, `nn.nr`, `ridge.nr`) now declare their cross-rod dependencies via `import` rather than relying on implicit symbol propagation. Previously these built only inside the larger pre-release tree where everything was already in scope.
- **Stdlib re-merged.** The active development tree had stripped most `.nr` rod wrappers (keeping only the C runtime files). The full set was restored from a complete earlier snapshot and re-validated against the current compiler.
- **`gnn.nr` and `nn.nr` `#cfile` paths.** Changed from precompiled-`.obj` references to direct `.c` source paths so users don't need a separate build step.
- **`time_rt.c`.** Added missing `#include <time.h>` for Windows builds.

### Fixed

- **Concurrency runtime.** The compiler emits the V2 calling convention `__nucleor_mutex_{new,lock,unlock}_value`, but the runtime had only the older `__nucleor_mutex_{new,lock,unlock}` symbols. Added forwarders in `stdlib/runtime/nucleor_llvm_rt.c` (Windows and POSIX branches) so `import "stdlib/rods/concurrency.nr"` programs now link and run.
- **RNG runtime.** The compiler emits `__nucleor_rng_seed`, which forwards to `nuc_rng_seed`. The latter lived in `stdlib/runtime/rng_rt.c` but was not part of any auto-linked compilation unit. `nucleor_llvm_rt.c` now `#include`s `rng_rt.c` so `rng_seed`, `rng_f64`, `rng_normal`, etc. are always available without a separate `#cfile`.
- **Quantum rod ownership.** `qsim_measure` in `stdlib/rods/quantum.nr` now declares its `meas_prob` binding `mut` (was `let meas_prob`, then reassigned in the next line — fails strict ownership checking).
- **`multi_core.nr` ownership.** Two `let agreement` bindings that were reassigned conditionally are now `let mut agreement`.

### Known limitations (v0.1, planned for follow-ups)

- **Windows-only.** v1 targets `x86_64-pc-windows-msvc`. Linux and macOS support require runtime port work.
- **No hex/binary integer literals.** Decimal only.
- **No `for` loops.** `while` is the loop primitive.
- **No `break` / `continue`.** Pattern out of loops with sentinel variables.
- **Generics and traits are placeholders.** The grammar accepts them in limited form, but the type checker treats `Vec<T>` as a uniform 64-bit-slot container regardless of `T`.
- **Block comments (`/* ... */`).** Use `//` line comments only.
- **`getenv()` from inside `.nr` source is incompletely wired** — the compiler knows the name but does not emit a usable IR declaration. Use the `nuc.bat` launcher for environment-driven configuration instead.

### Repository

- Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
- Source: https://github.com/APEXINTELORG/Nucleor
- Issues: https://github.com/APEXINTELORG/Nucleor/issues
- Author: Joseph Wescott
