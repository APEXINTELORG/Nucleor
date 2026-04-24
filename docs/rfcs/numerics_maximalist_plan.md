# Nucleor T1.1 — Maximalist Narrow Numerics Refactor

**Locked:** 2026-04-24. Single maintainer execution (no cloud agent).
Shipped as sequential versioned tags (`v0.2.307+`) on `main`.
Robotics rod loop **paused** until this refactor is 100% complete.

## 1. Goal (operational, complete)

Every numeric type the compiler accepts in `parse_type()` is a
first-class type with width-correct semantics throughout the
entire toolchain — IR, codegen, FFI, memory layout, casts,
comparisons, overflow handling, formatting, and diagnostics.

Mix `u8`, `i32`, `f32`, `usize`, `f16` freely; compiler enforces
width correctness; the resulting binary uses the right widths
everywhere observable. No hidden i64 promotions in user-visible
behavior. Verify gate grows from 101 to ~250 tests covering the
new surface, all green.

We are rebuilding the type system, not patching it.

## 2. Locked design decisions (4)

1. **Overflow default:** wrap in release, trap in debug (Rust-style).
   Attribute `#[overflow(wrap | trap | saturate)]` on fns / modules.
2. **Cast operator `as`:** Rust semantics — saturating float→int,
   truncating int→narrow-int, sign-extend for signed widening,
   zero-extend for unsigned widening, `fpext`/`fptrunc` for float
   widths.
3. **Suffix literal syntax:** `255u8`, `1_000i32`, `3.14f32`,
   `0.5f16`, `42usize`, `1_000_000u64`. Underscore separators
   allowed anywhere in the digit run.
4. **`usize`/`isize`:** resolve to platform pointer width
   (64-bit on all currently supported targets).

## 3. Scope — IN (everything)

1. All integer widths native: `i8/i16/i32/i64/i128`, `u8/u16/u32/u64/u128`,
   `isize/usize`. Native arithmetic in IR at correct widths.
2. All float widths native: `f16`, `bf16`, `f32`, `f64`. Hardware
   ops (`fadd half/bfloat/float/double`); software emulation for
   `f8e4m3`/`f8e5m2`.
3. Three overflow modes: wrap / trap / saturate (see §2.1).
4. Full `as` cast matrix per §2.2.
5. Width-correct memory layout: `alloca`, struct fields (with
   `#[repr(Nucleor | C | packed)]`), `Vec<T>`, `[T; N]` all pack
   correctly.
6. FFI ABI overhaul: extern fn narrow types emit correct LLVM
   signatures, `uint8_t`/`int32_t`/etc.  Existing 165 `_rt.c` files
   continue to work unchanged (all use `long long`); new code may
   use narrow types directly. `nuc gen-headers` subcommand.
7. Comparisons signed- and unsigned-aware: `icmp slt`/`ult`,
   `fcmp olt`/`ult`.
8. Constant folding + literal inference + compile-time overflow
   errors.
9. Width-correct formatting (`fmt.nr` / polymorphic `print`).
10. Diagnostics with spans, snippets, suggestions, error codes
    `NUM-001` ... `NUM-020`.
11. Generic `Vec<T>` monomorphization (at least for every numeric
    primitive + `MyStruct`).
12. `HashMap<K, V>` width-correct keys/values for primitive K/V.
13. `String` / `&str` migrated to `Vec<u8>` storage once Phase 8
    lands.
14. Bitwise ops at correct width including `lshr` (unsigned) vs
    `ashr` (signed).
15. Mechanically generated test matrix: every (type × op ×
    overflow_mode × cast_target).
16. Audit + selective refit of all 204 rods for narrow-type
    public surface where it matters (`image_pyramid` → `Vec<u8>`
    images; `occgrid` → `i8` log-odds; `mlv` → packed `Vec<u8>`;
    `vec`, `bitwise`, `string`).
17. Runtime cleanup: `complex.nr`'s `f64_*`/`f32_*`/`bf16_*`/`f16_*`
    family stays as explicit-call backwards-compat, no longer the
    only path.
18. Documentation:
    - `docs/rfcs/numerics_v2.md` (full RFC).
    - `docs/rfcs/numerics_wrap.md` (overflow semantics).
    - `docs/rfcs/numerics_cast.md` (cast operator matrix).
    - `docs/rfcs/numerics_ffi.md` (extern fn ABI rules).
    - `docs/rfcs/numerics_repr.md` (struct layout / repr attributes).

## 4. Scope — OUT (deferred)

- Full `HashMap` monomorphization for arbitrary user types
  (T1.3 territory).
- `Box<T>` / heap-allocator refactor.
- SIMD types (`i32x4`, `f32x8`, etc.).
- Decimal / fixed-point types.
- Bit-fields in structs.

## 5. Phase plan (14 phases)

Each phase shippable independently with verify gate green. Each
phase is one tagged release on `main` starting at `v0.2.307`.

### Phase 0 — Test scaffolding (1 session, v0.2.307)

Build the test-matrix generator. Emit `tests/lang/numerics_matrix/*.nr`
covering every (type × op × overflow_mode × cast_target). ~150
generated tests, expected to FAIL at this phase. Pin the failure
baseline in a manifest file so each subsequent phase has a clear
contract on which failures it should now flip to green.

**Verify gate:** 101 pre-existing tests still green; ~150 new
tests in matrix directory documented as expected-fail.

### Phase 1 — Width-aware integer arithmetic + comparisons
(1–2 sessions, v0.2.308)

Touch: `emit_arith()`, `emit_cmp()`, `emit_inst()` in
`compiler/nucleor_s1_compiler.nr` (~lines 3189–3300).

Switch on `type_width(t)` and `type_signedness(t)`. Emit
`add iN`, `sub iN`, `mul iN`, `sdiv/udiv iN`, `srem/urem iN`,
`icmp s/u<>`. Trunc inputs from i64 register, op at narrow
width, sext/zext result back to i64 register (Phase 1 only;
Phase 3 fixes register width).

**Verify gate:** 101 pre-existing still green; ~30 matrix tests
flip to green.

### Phase 2 — Width-correct integer literals + suffix syntax
(1 session, v0.2.309)

Lexer accepts `255u8`, `1_000i32`. Parser emits type-tagged
literals. Codegen: literal in narrow context emits at narrow
width directly. Constant-folding pass detects overflow and
errors at compile time (`error[NUM-001]`).

**Verify gate:** ~50 more matrix tests flip to green.

### Phase 3 — `sizeof::<T>()` + struct layout machinery + stdlib audit
(2–3 sessions, v0.2.310)

**Re-scoped after Phase 1+2 lessons:** the original plan paired
alloca-at-width with struct layout. Splitting these because
alloca-at-width has gigantic blast radius (every load/store in
every program changes type). Alloca-at-width moves to Phase 8
where `Vec<T>` monomorphization makes it load-bearing. Phase 3
focuses on observable layout + the stdlib audit needed before
Phase 4+ can expand the narrow set safely.

**Sub-phases:**
- 3a. `sizeof::<T>()` builtin. Returns compile-time-computed
  byte size for primitives + structs. Lets tests verify struct
  layout without an FFI bridge.
- 3b. `#[repr(C)]` attribute plumbed end-to-end: parsed,
  stored on struct, used to compute field offsets that match
  C ABI alignment rules. `#[repr(packed)]` similar with
  alignment 1.
- 3c. **Stdlib audit** — walk every `let x: i32 = ...` and
  `let x: u32 = ...` in `compiler/`, `stdlib/`, `tools/`. For
  each, decide: (a) the value really is i32-range → safe to
  narrow, (b) the value is i64-range "loose" use → re-type to
  i64 or add explicit `as i32` cast. After audit, expand
  `narrow_via_as` to include i32 + u32.
- 3d. Add 8–12 stronger p3_layout matrix tests covering
  sizeof primitives, sizeof repr(C) struct, sizeof packed,
  sizeof nested struct.

**Production-readiness:** every audit decision documented.
The bootstrap-fixpoint gate (added in Phase 2) catches any
miscompile from the expanded narrow set immediately.

**Verify gate:** 329 still green; bootstrap fixpoint stable.
~10 more matrix tests flip.

**Defer to later phase:** alloca-at-width emit (move to Phase 8).

**Reordering note (locked 2026-04-24):** Phase 3b (`#[repr(C)]` /
`#[repr(packed)]` field-offset machinery + `sizeof_struct(<name>)`
for user types) ships AFTER Phase 5 native float arith because the
matrix has 4 immediate Phase 5 fails and 0 immediate Phase 3b fails
— Phase 5 yields more user-visible value first. Phase 3b is NOT
deferred from the maximalist plan; it ships at v0.2.313 (after
v0.2.312 Phase 5).

### Phase 4 — `as` cast operator (2 sessions, v0.2.311)

Full cast matrix per Rust semantics. Codegen: `trunc`, `sext`,
`zext`, `sitofp`, `uitofp`, `fptosi/fptoui` (saturating),
`fpext`, `fptrunc`. Test every pair in the matrix.

**Verify gate:** ~25 more matrix tests flip.

### Phase 5 — Native float arithmetic (1 session, v0.2.312)

Same `emit_arith` switch extended to `type_is_float`. `fadd
half / bfloat / float / double`. `f8e4m3`/`f8e5m2` keep
software emulation (call into runtime).

**Verify gate:** ~10 more matrix tests flip.

### Phase 6 — Bitwise + shift ops at width (1 session, v0.2.313)

`and`, `or`, `xor`, `shl`, `lshr` (unsigned) / `ashr` (signed)
at correct width. Shift-amount type rules documented.

**Verify gate:** ~15 more matrix tests flip.

### Phase 7 — Overflow modes (2–3 sessions, v0.2.314)

Implement `#[overflow(wrap | trap | saturate)]` attribute on fns
and modules. Default: wrap in release, trap in debug. Per-op
intrinsics: `wrapping_add`, `saturating_add`, `checked_add`
returning `(T, bool)` tuple (until T1.2 provides `Option<T>`).
Codegen: `llvm.uadd.sat.iN`, `llvm.uadd.with.overflow.iN`,
`llvm.trap`.

**Verify gate:** ~15 more matrix tests flip.

### Phase 8 — `Vec<T>` monomorphization (3 sessions, v0.2.315)

Rewrite `stdlib/runtime/vec_rt.c`: dispatch table by type tag.
Each `Vec<T>` instantiation gets concrete entry points emitted
by the compiler. Element load/store width-correct. Capacity in
bytes uses `sizeof(T)`. Migrate `stdlib/runtime/string_rt.c` to
use `Vec<u8>` underneath. Audit every rod using `Vec<i64>` — no
regression allowed.

**Verify gate:** 101 still green. New `Vec<u8>`, `Vec<i32>`,
`Vec<f32>`, `Vec<f16>` size + correctness tests pass.

### Phase 9 — FFI ABI overhaul + header generation
(2 sessions, v0.2.316)

Extern fn declarations with narrow types emit correct LLVM
signatures. Add `nuc gen-headers <project>` subcommand
emitting `.h`. Document migration: existing rods unchanged,
new code can use narrow types directly.

**Verify gate:** 101 still green. Cross-link test: hand-written
`.c` against Nucleor-compiled lib via generated header.

### Phase 10 — Diagnostics (2 sessions, v0.2.317)

All width-mismatch / sign-mismatch / overflow / cast-precision
errors get spans, line+col, source snippets, suggestions.
Error namespace `NUM-001 … NUM-020`.

**Verify gate:** error-message string-match tests added.

### Phase 11 — Formatting (1 session, v0.2.318)

Polymorphic `print` with type-class dispatch (preferred) or
explicit `print_u8`/`print_i32`/`print_f32`/etc. family. Rewrite
`stdlib/rods/fmt.nr` width-correct.

**Verify gate:** format-output string-match tests added.

### Phase 12 — Rod audit + selective refit (3–5 sessions, v0.2.319–v0.2.323)

Walk all 204 rods. For each, decide: keep i64-everywhere FFI
(default) or expose narrow types in the public Nucleor surface
(high-value cases: `image_pyramid`, `occgrid`, `mlv`, `string`,
`vec`, `bitwise`, `hashmap` — count roughly 20–30 rods).

Ship per-rod refit commits with their own version bumps.

**Verify gate:** 101 → ~150 rod-level tests added.

### Phase 13 — Documentation rollup + RFC freeze (1 session, v0.2.324)

Five RFC docs land on disk. Tutorial updated. Migration guide
for any user code. Update `CHANGELOG.md` with a consolidated
T1.1 summary pointing to each RFC.

**Verify gate:** docs build, no broken links, tutorial code
examples compile.

## 6. Totals

- **Sessions:** ~20–25 focused sessions.
- **Tag range:** `v0.2.307` (Phase 0) → ~`v0.2.324` (Phase 13).
- **Files touched:** `compiler/nucleor_s1_compiler.nr` (majority),
  `stdlib/runtime/vec_rt.c`, `stdlib/runtime/string_rt.c`,
  `stdlib/runtime/nucleor_llvm_rt.c`, select rod refits.
- **Tests added:** ~150 matrix + ~50 error-message + ~50 rod-level
  = ~250 new tests.
- **RFCs added:** 5.
- **Verify gate:** green at every commit.

## 7. Workflow

- Single-maintainer execution on `main`, no branch, no PR ceremony.
- One phase per session (some small phases can ship two in one).
- Each phase = one tagged release + `CHANGELOG.md` entry +
  `python tools/gen_releases_index.py` regen + push + tag push.
- Robotics rod ships **paused** until Phase 13 lands. Resume
  after.
- Loop aimed only at this plan; stops only at 100% complete.
- If verify gate goes red, stop the phase, fix, then continue —
  never carry a red gate into the next phase.

## 8. What "100% complete" means

All 14 phases shipped and tagged. All ~250 tests green. All 5
RFCs committed. CHANGELOG entry consolidating the T1.1 work.
Loop terminates and rod-ship loop resumes from `v0.2.325`.
