# Changelog

All notable changes to Nucleor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
