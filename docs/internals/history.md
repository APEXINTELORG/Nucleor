# Source-Comment History Archive

Auto-extracted from `compiler/s1/*.nr` and `compiler/ts/*.nr`
by `tools/strip_version_stamps.py`. The triage / fix notes that
used to live inline are preserved here so a reader can still
trace the why of a given defensive halt back to the original
version pin. The compiler source itself no longer carries the
per-fix narrative; behavior is documented by the inline
`print(...)` / `panic(...)` calls and by the surrounding code.

## `compiler/s1/builtins.nr`

### `compiler/s1/builtins.nr:98`

```
    // v0.4.30 force-sign helper returns ptr (str)
```

## `compiler/s1/cache.nr`

### `compiler/s1/cache.nr:161`

```
// v1.1.x perf: precompiled-rt.o cache key/path. Returns "" if caching
// is disabled (env opt-out). The .o is keyed on the rt.c content,
// alloc.h content, opt level, and clang version proxy (toolchain
// path). Cache lives outside .nuc_cache so source-cache cold checks
// still avoid recompiling the unchanged runtime C translation unit.
```

### `compiler/s1/cache.nr:474`

```
    // v0.4.10 RFC-NRT-003 follow-on (Translate SPEC-2 Task 2 finding):
    // lld-link embeds wall-clock timestamps in the PE COFF header
    // (offset 0x108) by default, breaking byte-reproducible builds
    // even when the LLVM IR is byte-identical. This blocked SLSA-
    // Build-Level-3 attestation for the Translate team. /Brepro tells
    // lld-link to write a deterministic content-hash instead of a
    // timestamp, matching the SOURCE_DATE_EPOCH spirit.
    // ELF: clang's lld can be deterministic, but the GNU `ld` that
    // ships on stock Debian/Ubuntu embeds a per-link build-id in the
    // ELF .note.gnu.build-id section by default. Two builds of
    // byte-identical IR therefore produce byte-different EXEs and
    // RFC-NRT-003 verify-reproducible (which compares EXE bytes)
    // fails. -Wl,--build-id=none drops the section entirely so the
    // EXE stays byte-deterministic across runs on the same machine.
```

### `compiler/s1/cache.nr:811`

```
    // v1.1.x perf: precompile rt.c -> rt.o once per (rt content, alloc
    // hdr content, opt level). Saves ~1.2s per cold build because clang
    // skips re-compiling the 8 KLOC runtime each time. Cache disabled
    // when extra cfiles are imported (their content isn't keyed) or
    // when env opt-out is set.
```

## `compiler/s1/check_eff.nr`

### `compiler/s1/check_eff.nr:620`

```
    // v1.0" was structurally honest only for files that opted in.
    // Now: when no opt-in attribute exists BUT the source has at
    // least one extern fn or unsafe block, surface a warning-level
    // disclosure that the framework is inactive for this TU. This
    // is the Phase A remediation from the audit (info diag), at
    // warning severity so adopters cannot miss it; Phase B is the
    // `#[file_effects(default_on)]` outer-attribute opt-in for
    // file-level enable, scheduled post-v1.0.
```

### `compiler/s1/check_eff.nr:1396`

```
// v0.4.244 RFC-0006 substrate — `#[require(EXPR)]` source-text
// scanner. Mirrors `collect_no_alloc_fns` shape: scans the source
// for the literal pattern, walks paren-balanced expression text,
// captures the next `fn NAME` identifier, and stores a flat
// (fn_name, expr_text) pair in the result Vec. Lex-time the `#[
// require(...)]` is discarded as an unknown attribute, so the
// parser never sees it; this side-channel scanner recovers the
// information.
// Returns a flat Vec of alternating (fn_name, expr_text) entries:
//   [name0, expr0, name1, expr1, ...]
// String-literal and `//` comment skipping mirror the no_alloc
// pattern so the s1 compiler doesn't false-positive on the literal
// pattern strings inside its own scanner code.
```

### `compiler/s1/check_eff.nr:1511`

```
// v0.4.246 RFC-0006 substrate — `#[ensure(EXPR)]` source-text
// scanner. Mirror of collect_fn_requires but for the ensure
// attribute (postcondition checked at fn exit).
```

### `compiler/s1/check_eff.nr:1595`

```
// v0.4.251 RFC-0006 — `old(expr)` snapshot text rewriter.
// Walks the ensure expression's TEXT, finds every `old(...)`
// pattern (paren-balanced, string-literal aware), and rewrites
// each to a synthesized binding name `__old_<fn_name>_<idx>`.
// The inner expression text per `old(...)` is captured separately.
// Returns a flat Vec encoding [rewritten_text, n, synth0, inner0,
// synth1, inner1, ...] where n is the number of olds.
// At lower-time, the pre-pass lex+parses each inner into the AST
// pool, and lower_fn pre-evaluates each inner at fn entry storing
// to an alloca. The rewritten ensure expression's `__old_*`
// var-refs then resolve to loads from those allocas.
```

### `compiler/s1/check_eff.nr:1698`

```
// v0.4.248 RFC-0006 substrate — `#[invariant(EXPR)]` source-text
// scanner. Matches inherent impl blocks: `#[invariant(EXPR)] impl
// <Type> { ... }`. Trait-impl form (`impl Trait for Type`) is
// recognized by walking past the trait identifier and the `for`
// keyword to find the receiver type. Returns flat (type_name,
// expr_text) pairs.
```

### `compiler/s1/check_eff.nr:1815`

```
// v0.4.258 RFC-0006 — `#[no_check]` per-fn opt-out scanner.
// Returns flat Vec of fn names that carry the `#[no_check]`
// attribute; the require/ensure pre-passes skip these so the
// contract emit-sites produce no runtime checks. Useful for
// hot-path fns where the contract is documentation-only.
// `#[no_check]` does NOT take an expression — marker attr only.
// Pattern: `#[no_check]` followed by whitespace and `fn NAME`.
```

### `compiler/s1/check_eff.nr:1963`

```
    // v0.8.75 RFC-0062 G-1 Phase 2b-3 FINAL — unconditional
    // default-flip. Auto-drop is now ON BY DEFAULT for every fn.
    // Safe path validated:
    //   - v0.8.31/32  #[manual_drop] suppress mechanism
    //   - v0.8.35     safety audit (89 candidates classified)
    //   - v0.8.41/42  13 fns annotated #[manual_drop]
    //   - v0.8.64     cache-key correctness fix
    //   - v0.8.68/69  sentinel double-free guard (opt-in)
    //   - v0.8.73     handoff-risk warning under flip
    //   - v0.8.74     proper dataflow handoff suppression at
    //                 ExprStmt lowering (catches vec_push /
    //                 vec_set / hashmap_insert patterns and
    //                 suppresses auto-drop on the local that
    //                 was handed off)
    // v0.8.65 ATTEMPTED unconditional flip and segfaulted on
    // attention2.nr import because the static heuristic missed
    // rod-side handoffs. v0.8.74 closes that gap by detecting
    // handoffs at lowering time and suppressing immediately.
    // Re-test confirmed v0.8.75 ready: attention2.nr import
    // compiles cleanly under flip ON. The dataflow detection
    // is conservative (over-suppresses some local-only cases
    // → leaks instead of dropping; never dangling pointer).
    // Phase 2c will refine via receiver-locality + alias
    // tracking for tighter coverage. Phase 3 deny-by-default
    // for misuse. Phase 4 hard-error promotion at v1.0 cut.
```

### `compiler/s1/check_eff.nr:1991`

```
// v0.8.32 RFC-0062 G-1 Phase 2b-2 — collect `#[manual_drop]`
// fn names. Sister of collect_auto_drop_fns. Phase 2b-2: when
// a fn is in BOTH lists, manual_drop suppresses the auto-drop.
// Phase 2b-3 (default-flip): every fn gets auto-drop unless
// in this list.
```

### `compiler/s1/check_eff.nr:2067`

```
// v0.4.271 RFC-0006 — heap-aliased type detection for `old()` reject.
// The i64-everywhere ABI represents Vec/String/HashMap/HashSet/
// BTreeMap/BTreeSet/VecDeque/Box as a single i64 pointer to heap
// storage. Snapshotting the i64 captures the POINTER, not the
// buffer contents — so `old(v)` for `v: Vec<T>` aliases the post-
// mutation pointer and gives wrong ensure semantics. Reject at
// compile time with CONTRACT-006.
```

### `compiler/s1/check_eff.nr:2088`

```
// v0.4.271 RFC-0006 — text-level lookup of a fn's named param type.
// Finds `fn FNAME(...)`, scans the param list with paren/angle-
// bracket depth tracking so `Vec<HashMap<i64, str>>` parses correctly,
// and returns the type-text of the param matching PNAME. Returns ""
// on miss. Used by the old() heap-aliased reject; matching pattern
// shape with the no_check / require / ensure scanners (text-level
// pre-pass before the AST is built).
```

### `compiler/s1/check_eff.nr:2275`

```
// v0.4.272 RFC-0006 — text-level lookup of a fn's return type.
// Finds `fn FNAME(...)`, walks past the param list with paren
// depth tracking, then returns the text between `->` and `{`
// trimmed. Returns "" if the fn has no return arrow (i.e. void
// return type). Used by the void-fn-result-ref reject.
```

### `compiler/s1/check_eff.nr:2758`

```
// v0.6.84 RFC V1.4
//  row): canonical Rust
// `#[derive(PartialEq)] struct Point { x: i64, y: i64 }` pre-fix
// emitted only the v0.6.26 `warning[DERIVE-001]` and the derive was
// silently a no-op. Adopters writing `if a == b { ... }` later got
// the v0.4.147 TYP-011 ptr-compare diag with workaround pointer
// "write a helper fn that does the field walk" — but the helper
// wasn't auto-generated.
// This pass walks the source, finds `#[derive(...PartialEq...)]`
// attribute lines followed by a `struct NAME { ... }` or `struct
// NAME(...);` decl, and APPENDS a generated helper fn at end of
// source: `fn <NAME>__derived_eq(a: <NAME>, b: <NAME>) -> i64 {
//     if a.<f1> != b.<f1> { return 0; };
//     ...
//     return 1;
// }`. Adopters can call the generated fn directly; auto-dispatch
// of `==`/`!=` to the helper is deferred to a follow-on V1.4 ship
// (needs lower_expr binop kind-4 routing + side-table threading).
// Conservative scope: skip generic structs (`struct Pair<T>`),
// skip where-clauses, skip empty unit structs. For named struct
// fields, walk to the next top-level comma or `}` (depth-tracked
// for `<>`/`()`/`[]` so generic field types parse correctly). For
// tuple structs, count types and synthesize `__0`/`__1` names
// matching the V1.1 (v0.6.74) tuple-struct positional-field
// synthesis.
// `!=` on a struct field today does pointer-compare for nested
// structs (silent miscompute); the per-field helper still works
// for primitive-typed fields. Document the limitation in CHANGELOG.
```

### `compiler/s1/check_eff.nr:3835`

```
// v0.4.277 RFC-0006 — scan a contract-predicate text for `old(`
// pseudo-call. Same word-boundary technique as
// `ensure_text_uses_result`: `old` must be preceded by start-of-
// text or non-ident char (so `older` / `bold(...)` don't match)
// and followed by `(`. Used to reject `#[require(old(...) ...)]`
// at compile time.
```

### `compiler/s1/check_eff.nr:3864`

```
// v0.4.283 RFC-0006 — scan a contract-predicate text for any
// identifier that doesn't resolve to a fn parameter, a DbC
// keyword (result / old / self / true / false / None / Some /
// Ok / Err / null), a CamelCase type or enum variant (first
// char uppercase), an ALL_CAPS const (all chars uppercase /
// digits / underscores), or a fn-call site (followed by `(`).
// Returns the unbound ident name on first match, or "" if all
// idents resolve. Conservative: we'd rather miss a real
// undefined-ident (false negative — adopter sees the existing
// clang-link error) than reject a valid identifier.
// Regression fixed in v0.4.283: pre-fix,
// `#[require(undefined_var > 0)]` surfaced a misleading clang-
// link "undefined function `undefined_var()`" error. CONTRACT-011
// halts at parse time with the actual unbound ident named.
```

### `compiler/s1/check_eff.nr:3958`

```
// v0.4.272 RFC-0006 — scan an ensure-predicate text for a bare
// `result` identifier reference. Walks the text, tracking word
// boundaries: a hit must be preceded by start-of-text or non-
// ident char, and followed by end-of-text or non-ident char.
// Used to reject `#[ensure(result ...)]` on void fns.
```

### `compiler/s1/check_eff.nr:3991`

```
// v0.4.271 RFC-0006 — quick check whether `text` is a bare identifier
// (only `[A-Za-z_][A-Za-z0-9_]*`, no whitespace / punctuation /
// operators). Conservative: complex `old()` expressions like
// `old(self.field)` or `old(get_vec())` skip the heap-aliased
// reject (false negative is preferred over false positive — the
// runtime panic still surfaces in those edge cases).
```

### `compiler/s1/check_eff.nr:4019`

```
// v0.4.257 RFC-0006 Liskov substrate — count #[require] and
// #[ensure] attributes per trait method declaration. Returns flat
// Vec of (trait_name, method_name, req_count, ens_count) tuples
// where the count fields are stored as decimal strings (the flat
// Vec<i32> representation forces all entries to be the same shape).
// Walking heuristic: scan source for `trait NAME {` blocks; track
// brace depth so nested decls don't escape; within the trait,
// scan for `fn METHOD(`; before each fn, scan back/forward for
// preceding `#[require(...)]` / `#[ensure(...)]` attributes
// (those that fall between the previous statement boundary and
// the fn keyword).
```

### `compiler/s1/check_eff.nr:4168`

```
// v0.4.257 RFC-0006 Liskov substrate — count #[require] and
// #[ensure] attributes per impl-trait method definition. Returns
// flat Vec of (trait_name, type_name, method_name, req_count,
// ens_count) tuples. Only trait impls (the `impl Trait for Type`
// form) are captured; inherent impls (`impl Type`) are skipped.
```

## `compiler/s1/check_own.nr`

### `compiler/s1/check_own.nr:8`

```
    // v1.1.x perf: full body in C. Pre-fix this paid 3-5 FFI calls
    // per put (lookup + vec_set + sym_aux_get + maybe hashmap_insert
    // OR two vec_push). Now one FFI call.
```

### `compiler/s1/check_own.nr:15`

```
    // v1.1.x perf: same full-body hoist. str values are stored as
    // i64-cast pointers under the i64-everywhere ABI, so the same C
    // helper works.
```

### `compiler/s1/check_own.nr:507`

```
    // v1.1.x perf: dispatch on
    // str_char_at(key, 2) instead of testing every prefix sequentially.
    // Pure source refactor — no new externs, no compiler registration
    // changes, no runtime/seed change. Same semantics, fewer per-call
    // str_starts_with lookups.
```

### `compiler/s1/check_own.nr:617`

```
    // v1.1.x perf: pre-build a
    // hashmap of `a`'s keys for the second loop's "is this key in
    // a?" check. Only when nA is large enough that the linear sym_get
    // cost (per b-key × nA) exceeds the hashmap setup overhead.
    // Threshold 128 (= 64 pairs) matches the existing warm-aux
    // gate, where hashmap O(1) becomes worth the setup cost vs
    // linear backward scan.
```

### `compiler/s1/check_own.nr:1304`

```
            // v0.5 ship 7 final: span-aware caret. Pre-fix, the OWN-001
            // line/col came from `find_in_source` / `find_column_in_source`
            // which scan the function body for the FIRST textual
            // occurrence of `vname` — wrong-caret bug for any variable
            // used multiple times in the same fn (the fix points at the
            // first use, not the actual use-after-move site). With var-
            // ref nids now spanned in parse_primary, we read the use
            // site directly.
```

### `compiler/s1/check_own.nr:1326`

```
            // v1.0 enforcement. The other ownership-family codes (OWN-G4,
            // OWN-G8, BORROW-G2, INIT-G11, ALIAS-G3-*, SEND-G6-*) all emit
            // at "error" severity via own_diag; OWN-001 was the lone
            // outlier. Now consistent.
```

### `compiler/s1/check_own.nr:1880`

```
            // v0.4.59 enum match-as-expr close, but the existing
            // exhaustiveness check explicitly excluded __int/__str
            // (lines 9760/10060) so int/str matches escaped MATCH-001
            // entirely. Now: any int/str match-as-expr without an
            // `_` arm is MATCH-001.
```

### `compiler/s1/check_own.nr:2293`

```
                // v0.4.43 (RFC-0020 Phase 3, v0.2 deferred row #8):
                // span migration — use line + col instead of line-only.
```

## `compiler/s1/check_type.nr`

### `compiler/s1/check_type.nr:188`

```
    // v0.6.75 RFC V1.2
    //  canonical Rust `let b: Box<i64> = Box::new(5);`
    // pre-fix failed TYP-008 because `Box::new(5)` types as `Box<i32>`
    // (i32 is the literal-default for unsuffixed int literals) and
    // `types_compatible(Box<i64>, Box<i32>)` returned 0 (no Box<T>
    // recursion or literal-widening path).
    // Note: `type_base_name("Box<T>")` strips the Box wrapper and
    // returns the inner type's base, so we must dispatch the Box<T>
    // shape BEFORE the type_base_name call below — using
    // str_starts_with directly. The literal-default widening rule
    // accepts i32 actual into any wider/narrower int-typed expected
    // (i32 is the canonical default for unsuffixed int literals).
    // Cheap first-char gate: skip the str_starts_with calls unless both
    // expected and actual begin with 'B' (ASCII 66). Box<T> compares are
    // a vanishingly small fraction of types_compatible calls and the hot
    // path must remain a few char compares.
```

### `compiler/s1/check_type.nr:1607`

```
            // v0.5 ship 7: span-aware caret. Use the cast nid's span
            // (set in parse_unary at the `as` token) when available;
            // fall back to the legacy fn-name scan otherwise. This
            // makes NUM-003 caret at the cast site instead of the
            // function declaration.
```

### `compiler/s1/check_type.nr:1653`

```
        // v0.4.72 NOT enforcing `str as <numeric>` — Nucleor's
        // i64-everywhere ABI makes str pointers castable to i64 by
        // convention (used by intern/hash code in tools_suite + s1).
        // Rust errors here but Nucleor does not. Documented as a
        // Nucleor design choice, not a silent miscompute.
        // NUM-023 — float / bool as-cast to `str`. Pre-fix
        // `let s: str = x as str` for `x: f64` lowered to a no-op
        // (the i64-cell holding the f64 bit pattern was reinterpreted
        // as a char ptr) and SIGSEGV'd at print time when the bit
        // pattern was dereferenced. Same hazard for bool — `true as
        // str` produced a str ptr equal to 1, segfault on print. The
        // i*/u* -> str direction stays allowed (the v0.4.72
        // i64-everywhere convention covers heap-pointer pun); only
        // f* and bool sources halt because their i64 cells are
        // never legitimate heap pointers.
```

### `compiler/s1/check_type.nr:1737`

```
                    // v0.5 ship 7: span-aware caret. The kind-99 cast nid
                    // carries the `as` token's byte offset (set in
                    // parse_unary), so this lands at the cast site.
```

### `compiler/s1/check_type.nr:2013`

```
        // v0.4.147 (struct ==). String is a heap-allocated buffer
        // (NOT a user-defined struct, so v0.4.147's struct_find_type
        // check skipped it). Pre-fix `s == s2` for `s, s2: String`
        // returned FALSE for two String values at different heap
        // addresses even when their bytes matched. The runtime helper
        // `__nucleor_string_eq` exists; this is the missing
        // surface-level dispatch from `==` to it.
        // String ==/!= now auto-dispatches to string_eq at
        // lower-time (paired lower_expr edit). Suppress TYP-011 — adopters
        // can write canonical `if s1 == s2 { ... }` directly.
        // NUC-FEEDBACK silent-miscompute close for str
        // ordering ops `<`, `<=`, `>`, `>=`. Pre-fix `a < b` for two
        // str values did integer pointer compare — wholly disconnected
        // from lexicographic byte order. Adopters writing canonical
        // Rust (which does lex compare via PartialOrd) got a quiet
        // wrong result.
        //  the original v0.4.67 workaround text recommended
        // `str_cmp(a, b) <op> 0` — but `str_cmp` was never wired to a
        // runtime helper, so adopters following the recommendation hit
        // TYP-005 / clang link `error: undefined function 'str_cmp()'`.
        // The diag now points at a manual element-wise loop using
        // `str_char_at(s, i)` and `str_len(s)` — both ARE in the
        // runtime. A future ship may add a real `str_cmp` helper, at
        // which point this diag can be reverted to the simpler form.
```

### `compiler/s1/check_type.nr:2049`

```
        // v0.4.61 (Vec ==). Catches when both sides resolve to the
        // SAME user-defined struct type — cross-struct cmp is a
        // type error caught elsewhere; struct cmp against
        // non-struct goes through the existing TYP-008 machinery.
```

### `compiler/s1/check_type.nr:2056`

```
                // v0.6.85 RFC V1.4 (auto-dispatch): if the textual pre-pass
                // (v0.6.84 expand_derive_partialeq) generated a derived-eq
                // helper for this struct, suppress TYP-011 — the lower_expr
                // kind-4 branch (sister edit) routes the binop to the
                // helper instead of the silent ptr-compare.
                // base-name for generic instantiations (Pair<i64>
                // dispatches through Pair__derived_eq).
```

### `compiler/s1/check_type.nr:2155`

```
        // v0.4.72 NOT enforcing && / || bool-only — Nucleor's
        // i64-everywhere ABI accepts integer truthiness in logical
        // ops by convention (used pervasively in tools_suite + s1).
        // Rust errors here but Nucleor does not. Documented as a
        // Nucleor design choice, not a silent miscompute.
```

### `compiler/s1/check_type.nr:2494`

```
                // v0.5 (v0.4.228 integration) phase 3c.1 — cross-width
                // call-site audit. Compatibility passes for i64-into-iN-
                // param via Nucleor's i64-everywhere ABI, but the
                // narrowing is implicit. NUM-024 is OPT-IN via
                // NUCLEOR_AUDIT_NUM024=1 — every narrow-typed param
                // call is technically cross-width under the i64 ABI
                // (literals default to i64), so default-on would be
                // too noisy. v0.4.230's str_from_int widening dropped
                // the audit surface to 0/0; the verify gate ratchets
                // that as a regression floor.
```

### `compiler/s1/check_type.nr:2684`

```
                    // v0.6.80 (probe finding 2026-04-30 String-passed-to-str-
                    // helper): adopters porting Rust code commonly pass a
                    // `String` value to `print` / `str_eq` / `str_concat` /
                    // etc. and pre-fix saw the bare TYP-006 "must be str"
                    // diag without learning that Nucleor's String is a
                    // distinct heap-buffer struct (`{ data, len, cap }`)
                    // from str (NUL-terminated borrowed view), and that the
                    // safe coercion is `string_as_str(s)`. Append a hint
                    // when the actual type is String / &String.
```

### `compiler/s1/check_type.nr:2700`

```
            // v0.3.159/160 ROLLED BACK in v0.3.161: Nucleor's
            // i64-everywhere ABI treats f64_to_str(i64), f32_to_int(i64),
            // etc. as bit-pattern conversions (the i64 IS the f-value's
            // bit representation). Adopters who store f32/f64 values in
            // i64 (the canonical pattern -- see tests/rods/numeric.nr)
            // pass the i64 directly. Strict type checking on these
            // helpers breaks the round-trip pattern.
            // The ADOPTER HAZARD (calling f64_to_str(100) thinking 100
            // is a numeric value -> garbage subnormal output) is real
            // but the fix needs a different approach: deprecate the
            // bit-pattern semantics and add explicit
            // f64_value_to_str(f: f64) helpers, OR add a compile-time
            // warning (not error) when arg looks like an int literal.
            // Deferred for proper design.
            // literal-only diagnostic for f64_to_str /
            // f32_to_str when arg 0 is an INT LITERAL (kind 1). Catches
            // the specific adopter mistake `f64_to_str(100)` -- where
            // the user means "print the number 100" but the i64-everywhere
            // ABI reinterprets 100 as a subnormal f64 bit pattern,
            // printing "4.94066e-322". Variables (which might
            // legitimately hold f64 bit patterns per the rods/numeric
            // pattern) are NOT flagged. This is the conservative middle
            // ground between the rolled-back v0.3.159/160 (too strict)
            // and pre-fix (no diagnostic at all).
            // Diagnostic is INFORMATIONAL (uses print, not type_diag) so
            // the build doesn't halt. Adopters who genuinely want the
            // bit-pattern behavior can suppress by calling via a variable
            // (e.g. `let b: i64 = 100; f64_to_str(b);`).
```

### `compiler/s1/check_type.nr:2826`

```
            // v0.6.74 RFC V1.1 step 2: tuple-struct constructor routing.
            // When the callee resolves to a tuple-style struct (all
            // fields named `__<digit>+`), accept the call as struct
            // construction with positional args mapped to `__0`,
            // `__1`, ... synthetic fields. Type-check each arg
            // against the corresponding declared field type.
            // Non-tuple structs still emit TYP-022 (must use brace-
            // init syntax).
```

### `compiler/s1/check_type.nr:2894`

```
            // v0.4.132 TYP-020 (binop with void closure result), etc.
```

### `compiler/s1/check_type.nr:3428`

```
            // v0.4.132 (binop void). The annotated form
            // `let x: i64 = print_int(5);` already halts with TYP-008
            // (type mismatch); the bare-let case sailed through every
            // check because tstr is empty so the str_len(tstr) > 0
            // branch below is skipped. Detect init_t == void here.
```

### `compiler/s1/check_type.nr:3591`

```
                // v0.2.319 expansion) but never wired. Catches the
                // literal float (kind 71) in integer-typed binding.
```

### `compiler/s1/check_type.nr:5322`

```
// v0.4.213 RFC-0015 phase 3b extension — detect narrow expression
// chains (var-ref + literal + nested binop) at any depth so kind-4
// can dispatch to a width-correct narrow-emit path. Returns the
// sign-encoded narrow width if `nid`'s value resolves at one
// consistent narrow width, else 0. Tree-recursive but fast-exits
// on non-narrow nodes (kind != 1/3/4) — most expressions in
// real code are non-narrow and bail in O(1).
```

### `compiler/s1/check_type.nr:5822`

```
            // v0.6.85 RFC V1.4 (auto-dispatch): when both sides resolve
            // to the same struct type AND the textual pre-pass
            // `expand_derive_partialeq` (v0.6.84) generated the helper
            // fn `<Type>__derived_eq(a, b) -> i64`, route the binop to
            // that helper instead of the silent ptr-compare. The helper-
            // existence probe is `sym_get(sym, "__fnret_<Type>__derived_eq")`
            // — populated by populate_fn_returns_in_sym at lower_fn entry.
            // For `!=`: emit `1 - <eq>` so the result is canonical 0/1.
            // Closes V1.4 (paired with v0.6.84 helper-fn generation).
            // The TYP-011 ptr-compare diag at line ~17027 still fires at
            // type-check time for non-derived structs (pre-existing
            // behavior); for derived structs it would be misleading, so
            // type_expr's TYP-011 path also suppresses when the helper
            // exists (sister edit below).
```

### `compiler/s1/check_type.nr:5873`

```
            // v0.6.87 (probe finding 2026-04-30 str/String == silent
            // miscompute): canonical Rust `a == b` for two `str` or two
            // `String` values pre-fix lowered to integer pointer
            // compare — TYP-011 fires as a WARNING but the build
            // succeeds with silently broken IR (two equal-bytes values
            // at different addresses return FALSE). The runtime helpers
            // `__nucleor_str_eq` and `__nucleor_string_eq` already
            // exist; this is the missing surface-level dispatch from
            // `==`/`!=` to them.
            // Now: auto-route to the right runtime helper for both
            // forms. For `==`: helper(a, b). For `!=`: 1 - helper(a, b).
            // Sister to v0.6.85's struct ==/!= auto-dispatch via
            // derive(PartialEq) — same architectural pattern.
```

### `compiler/s1/check_type.nr:5940`

```
        // v0.3.148 hoists allocas to the entry block via
        // `ir_fn_add_entry_alloca` — the same pattern the while/loop
        // lowering already uses for its loop-counter alloca.
```

### `compiler/s1/check_type.nr:6296`

```
        // v0.6.74 RFC V1.1 step 2: tuple-struct constructor lowering.
        // When fn_name resolves to a tuple-style struct, emit struct
        // construction IR instead of fn call. Fast-fail on shape: only
        // uppercase-starting identifiers can be struct names per Rust
        // convention. Skips the struct-table scan for the dominant
        // case (lowercase fn names = regular fns).
```

### `compiler/s1/check_type.nr:6425`

```
            // v0.3.143 print(int) SIGSEGV: silent data loss with no
            // error. Direct adopters to println!/print! macros for
            // multi-arg formatting.
```

### `compiler/s1/check_type.nr:6505`

```
                        // v0.3.181 Vec<str> fix -- pre-fix
                        // print(hashmap_get(h, k)) for HashMap<K, str>
                        // printed the str pointer as int. Parse the
                        // receiver's full type to extract V (the second
                        // generic parameter).
```

### `compiler/s1/check_type.nr:6598`

```
                        // v0.3.182 superseded hashmap_get/hashmap_get_or/
                        // hashmap_remove/btreemap_get -- those are now
                        // handled by the value-type lookup above. Only
                        // *_len/*_capacity (always i64) remain here.
```

### `compiler/s1/check_type.nr:6861`

```
                            // v0.3.181 and the Vec-only lookup didn't match.
```

### `compiler/s1/check_type.nr:7159`

```
                        // v0.6.83 sister halt for Result methods not in
                        // the runtime surface yet.
```

### `compiler/s1/check_type.nr:7309`

```
                            // v0.6.91 (defensive halt — Box<dyn Trait>
                            // receiver method dispatch): canonical Rust
                            // `let d: Box<dyn Animal> = Box::new(Dog{});
                            // d.speak();` pre-fix fell through every
                            // typed-receiver branch and the kind-8
                            // catch-all synthesized `vec_speak(d)` —
                            // surfacing as wrong-class TYP-005 'Vec<T>
                            // has no method'. Trait-object dispatch
                            // requires a vtable; Nucleor's i64-everywhere
                            // ABI doesn't yet have one. The Box wrapper
                            // strip in `type_base_name` (line ~8378)
                            // leaves `dyn Trait` as the visible base.
                            // Halt cleanly with workaround pointer (use
                            // concrete type — `let d: Dog = Dog {}; ...`
                            // — and call the trait method directly).
```

### `compiler/s1/check_type.nr:7885`

```
        // v0.7.12 (defensive halt — Rust stdlib smart-pointer types):
        // canonical Rust `Cell::new(v)`, `RefCell::new(v)`, `Rc::new(v)`,
        // `Arc::new(v)`, `Mutex::new(v)`, `RwLock::new(v)`,
        // `RefCell::borrow_mut()`, `Rc::clone(&r)` etc. pre-fix
        // surfaced via the generic v0.3.71 "unsupported associated-fn
        // call" diag mentioning Vec/String/etc. — not adopter-actionable.
        // None of these wrappers are needed in Nucleor's i64-everywhere
        // ABI (no borrow-checker enforcement, no shared-ownership
        // requirement under single-threaded default). Halt cleanly with
        // type-specific workaround pointers.
```

### `compiler/s1/check_type.nr:8330`

```
            // v0.7.95 (defensive halt — `Self { ... }` struct
            // constructor inside `impl` blocks). Pre-fix the
            // `Self` ident reached the kind-34 lowering as a
            // literal struct-name lookup that failed with the
            // generic "unknown struct Self" diag — adopters
            // writing `impl Counter { fn make(x: i64) -> Self
            // { return Self { n: x }; } }` got wrong-class
            // error pointing at "Self" instead of the real
            // missing feature (Self-as-type-alias inside impl
            // blocks). Halt with a precise diag + workaround.
            // Sister to v0.6.91 trait-object dispatch halt
            // family.
```

### `compiler/s1/check_type.nr:9446`

```
// v0.8.74 RFC-0062 G-3 Phase 2b — proper dataflow handoff
// detection. If an ExprStmt is a Call to vec_push / vec_set /
// hashmap_insert and the VALUE argument is an identifier
// referencing a registered auto-drop binding, return that
// binding's name. Caller then calls auto_drop_set_state(sym,
// name, 0) to suppress the auto-drop emit at fn return.
// vec_push(receiver, value)        — value is arg index 1
// vec_set(receiver, idx, value)    — value is arg index 2
// hashmap_insert(map, key, value)  — value is arg index 2
// Conservative: fires for ANY identifier-typed value arg whose
// name is in the auto-drop set, regardless of receiver locality.
// Over-suppresses (might leave a leak instead of correctly
// dropping a never-handed-off Vec) but never produces a
// dangling pointer. Phase 2c adds receiver-locality refinement.
```

### `compiler/s1/check_type.nr:9662`

```
        // v0.4.209 RFC-0015 phase 3a-step-3 (Option D): inline narrow-
        // width detection. Sign-encoded same as type_expr kind-3:
        // positive=signed, negative=unsigned, 0=untyped (i64).
        // Trunc/store don't care about sign — only abs width matters
        // for memory-shape — so we extract abs(w) for the IR ops.
        // expanded to i32/u32 — completes the
        // i8/i16/i32/u8/u16/u32 narrow set for typed memory ops.
        // i64/u64 stays at the i64 ABI (untyped, w=0).
```

### `compiler/s1/check_type.nr:9944`

```
        // v0.4.247 RFC-0006 — `#[ensure(EXPR)]` at explicit
        // mid-body `return X;` sites. lower_fn stashed the fn's
        // ensure expr nid in sym["__current_fn_ensure_nid"] before
        // body lowering. Read it here and emit the check before
        // the ret. Mirror of the tail-return path in lower_fn.
```

### `compiler/s1/check_type.nr:9991`

```
            // v0.4.249 RFC-0006 — invariant exit-emit at mid-body return.
```

### `compiler/s1/check_type.nr:10058`

```
            // v0.4.249 RFC-0006 — invariant exit-emit at bare return;.
```

### `compiler/s1/check_type.nr:10586`

```
        // v0.4.221 ship that introduced typed-iN allocas for narrow
        // params + trunc-on-entry broke the compiler's own self-build
        // because the compiler abuses Nucleor's i64-everywhere ABI:
        // e.g. `fn str_from_int(n: i32)` is called with i64 values
        // relying on the historical alloca-i64-for-all-params
        // behavior. Trunc-on-i32-entry collapsed those i64 values to
        // -1, breaking ~34 verify tests on fresh self-build. v0.5
        // work is needed to make phase 3c safe — likely call-site
        // type-info propagation that detects cross-width abuse and
        // emits explicit `as` casts at call boundaries. For v0.4
        // closeout, params stay alloca-i64 (the pre-3c convention).
        // Adopter narrow-typed fn bodies still benefit from phase
        // 3a/3b (typed allocas for let-stmts + narrow arith chains).
        // v0.5 (v0.4.233 integration) phase 3c.3 — typed param alloca
        // RESTORED. v0.4.221 originally landed this and v0.4.224 reverted
        // it because `str_from_int(n: i32)` was being called with i64
        // magnitudes. With v0.4.230's i32→i64 widening above, the
        // cross-width abuse is gone and trunc-on-entry is a no-op for
        // in-range values. Numeric-heavy adopter code regains phase
        // 3b's narrow-arith dispatch on fn params.
```

### `compiler/s1/check_type.nr:10667`

```
    // v0.4.251 RFC-0006 — pre-evaluate `old(EXPR)` snapshots at
    // fn entry. The pre-pass collected (fn_name, synth_name,
    // inner_nid) triples in old_snapshots; for each match with
    // the current fn name, allocate a slot, lower the inner
    // expression now (when input args are still in their entry
    // state), store the result, and bind synth_name → alloca in
    // sym. The rewritten ensure predicate's `__old_*` var-refs
    // resolve via this binding to a load from the snapshot slot
    // when the predicate is evaluated at fn exit.
```

### `compiler/s1/check_type.nr:10692`

```
    // v0.4.247 RFC-0006 — stash this fn's ensure expr nids in sym
    // so lower_stmt's kind-22 explicit `return X;` handler can
    // emit the ensure check at mid-body return sites.
    // v0.4.254 RFC-0006 — multi-ensure support at mid-body returns.
    // Pre-fix only the FIRST ensure attribute fired at mid-body
    // return (sym holds a single i64 nid). Now: walk all matches,
    // sym_set "__current_fn_ensure_count" = N, then "__current_fn_
    // ensure_nid_0" .. "__current_fn_ensure_nid_<N-1>". lower_stmt
    // reads the count and loops emitting contract_ensure per nid.
```

### `compiler/s1/check_type.nr:10717`

```
    // v0.4.245 RFC-0006 Design by Contract — `#[require(EXPR)]`
    // runtime check at fn entry. The substrate scanner ran in the
    // main pipeline (collect_fn_requires + lex+parse pre-pass);
    // require_exprs is a flat (fn_name, expr_nid) Vec. If this fn
    // has a require, lower the expr into ebb0, then call the
    // runtime helper __nucleor_contract_require(result) — the
    // helper prints CONTRACT-001 + exits on a 0 result. The fn's
    // body lowering follows on a fresh ebb0 (ebb0 may have been
    // updated by the require expression's own block-control if
    // the predicate is non-trivial — e.g. a chain of && that
    // short-circuits into multiple basic blocks).
    // v0.4.250 RFC-0006 — multiple #[require(...)] attributes per
    // fn. Walk ALL matching entries (the pre-pass pushes one entry
    // per attribute, so a fn with two `#[require(a > 0)]
    // #[require(b > 0)]` headers yields two entries with the same
    // fn_name). Each match emits its own contract_require call —
    // the predicates are conjuncted by short-circuit: a violation of
    // any one panics. Pre-fix only the first match emitted; later
    // requires were silently ignored.
```

### `compiler/s1/check_type.nr:10752`

```
    // v0.4.248 RFC-0006 — `#[invariant(EXPR)]` runtime check at
    // method entry. Method names get mangled to `Type__method` at
    // parse time (see line 19629 area). Extract the type prefix
    // by splitting on `__`. If the type has an invariant, lower
    // it in ebb0 (after params + require) and emit the helper
    // call. Predicate references `self.field` which resolves via
    // the existing kind-3 var-ref + kind-* field-access lowering;
    // `self` is bound in sym from the param walk above.
```

### `compiler/s1/check_type.nr:10800`

```
                // v0.4.253 RFC-0006 — constructor path: fn returns
                // the parent type but takes no `self`. Per spec §3.4,
                // invariants fire on exit from constructors (no
                // entry-emit possible — self doesn't exist yet). At
                // exit-emit time, the existing tail-return code
                // checks `__current_method_is_ctor` and binds `self`
                // to the rv before lowering the predicate.
```

### `compiler/s1/check_type.nr:10851`

```
            // v0.4.246 RFC-0006 — `#[ensure(EXPR)]` runtime check at
            // tail return.
            // multiple #[ensure(...)] attributes per fn.
            // Count matching entries; if any present, bind `result`
            // ONCE to a fresh alloca holding rv; then loop over all
            // matches lowering each predicate and emitting one
            // contract_ensure call per attribute.
```

### `compiler/s1/check_type.nr:10887`

```
            // v0.4.249 RFC-0006 — invariant exit-emit at tail return.
            // if this fn is a constructor (returns the
            // parent type, no self param), bind `self` to rv before
            // lowering the predicate so `self.field` resolves.
```

### `compiler/s1/check_type.nr:10931`

```
        // v0.4.246/250 RFC-0006 — multiple ensure checks at
        // implicit-zero return.
```

### `compiler/s1/check_type.nr:10962`

```
        // v0.4.249 RFC-0006 — invariant exit-emit at implicit-zero
        // return (no explicit body tail expression).
```

## `compiler/s1/cli.nr`

### `compiler/s1/cli.nr:396`

```
    // v0.4.257 RFC-0006 Liskov compile-time check.
    // For each `impl Trait for Type { fn METHOD ... }` method,
    // compare its #[require] / #[ensure] count against the trait
    // declaration's count for the same method name. Liskov:
    // - impl precondition COUNT must NOT exceed trait's
    //   (CONTRACT-004 — strengthened pre).
    // - impl postcondition COUNT must NOT be below trait's
    //   (CONTRACT-005 — weakened post).
    // Count-based comparison is conservative — if the predicates
    // are textually different but semantically equivalent, this
    // check still passes. Strict semantic equality would require
    // a separate analysis pass (deferred). Accuracy: catches the
    // canonical violation classes (impl adds a require, impl
    // drops an ensure) without expensive AST equality.
```

### `compiler/s1/cli.nr:558`

```
    // v0.4.245 RFC-0006 — pre-process #[require(EXPR)] attributes.
    // Source-text scanner produces (fn_name, expr_text) pairs. For
    // each, lex+parse the expression text into the existing pool;
    // store (fn_name, expr_nid) for lower_fn to look up. The lex
    // and parse_expr functions are reentrant — they take a fresh
    // token stream and return an AST nid in the supplied pool.
    // v0.4.252 RFC-0006 — build-mode strip-out via NUCLEOR_DBC_MODE.
    // Per spec section 1 — "Build modes":
    //   debug (default) | unset → all contracts active
    //   safe-release → require active; ensure / invariant elided
    //   release → all contracts elided
    //   cert → all elided (statically proven elsewhere — that
    //          analysis pass is a future ship; until then cert
    //          behaves like release for runtime emit)
    // Implementation: skip the relevant pre-pass populations.
    // Empty Vecs flow through to lower_fn; the existing walk-all
    // lookups find no matches; no contract IR emits.
```

### `compiler/s1/cli.nr:595`

```
    // v0.4.258 RFC-0006 — `#[no_check]` per-fn opt-out. Scanner
    // populates a list of fn names whose contracts should be
    // skipped (e.g. hot-path fns). Pre-passes filter their entries
    // out of require_exprs / ensure_exprs.
```

### `compiler/s1/cli.nr:645`

```
    // v0.4.246 RFC-0006 — pre-process #[ensure(EXPR)] attributes.
    // also rewrite `old(EXPR)` patterns inside the
    // ensure expression to synthesized binding names, lex+parse
    // each inner separately, and store (fn_name, synth_name,
    // inner_nid) triples in old_snapshots for fn-entry pre-eval.
```

### `compiler/s1/cli.nr:721`

```
    // v0.4.248 RFC-0006 — pre-process #[invariant(EXPR)] attributes
    // on inherent + trait impl blocks. Stored by TYPE name; lower_fn
    // splits the mangled method name (`Type__method`) on `__` and
    // looks up the type's invariant.
```

### `compiler/s1/cli.nr:1121`

```
// v0.8.44 NUM-G1 — count source-level float literals with >6
// fractional digits. Walks src once; on each digit, scans forward
// to find a dot, then counts fractional digits. If >=7, increments
// counter. Self-host safe: comments and strings are scanned too,
// but most legit content doesn't have long-decimal float literals
// outside of test fixtures. Comment-text mentions like
// "3.14159265" in this file's own diagnostic message would trip
// this — kept in this file via str_concat construction below.
```

### `compiler/s1/cli.nr:2064`

```
                            // v0.5.19 closes probe finding
                            // 2026-05-01-async-keyword-silently-stripped.
                            // Plain `async fn foo()` (no RT attribute) was
                            // silently stripped pre-fix — adopter wrote the
                            // canonical Rust async pattern, the keyword
                            // dropped, the fn ran sync, no signal. Now we
                            // emit an ASYNC-001 warning marker that the
                            // scanner picks up post-strip. Marker shape
                            // mirrors RT-006's `//__NUC6T:` for symmetry.
                            // Note: the runtime DOES support threading via
                            // async_spawn / async_await (RFC-0027 phase 1) —
                            // the warning points adopters at that, rather
                            // than halting cleanly.
```

### `compiler/s1/cli.nr:4373`

```
    // v0.7.43 (defensive halt — Rust named format-arg `format!("{x}",
    // x = 5)`). Pre-fix this surfaced as wrong-class `error[TYP-005]:
    // undefined function 'x()'` because the expander used the literal
    // expression `x = 5` as the value to format, parsed it as an
    // assignment, and `x` was undefined. Detect any arg part matching
    // `<ident>\s*=\s*<expr>` and halt cleanly. (Does NOT fire on `==`
    // / `!=` / `<=` / `>=` because those have a non-`=` second char.)
```

### `compiler/s1/cli.nr:4461`

```
                    // v0.7.41 (defensive halt — Rust 1.58+ inline format-arg
                    // placeholders `{name}` where `name` is an identifier
                    // bound in the caller's scope). Pre-fix this surfaced
                    // as the v0.4.70 generic "more `{}` than args" error
                    // even though the args ARE inline in the format string.
                    // Detect the spec being a bare identifier (no format-
                    // spec colons / dots / commas) and halt with a clear
                    // explicit-arg workaround.
                    // require the first char to be alpha or `_` so
                    // `{0}` / `{1}` (positional-arg refs, a separate Rust
                    // feature) don't collide with the v0.7.41 inline-arg
                    // halt. Digits-only specs are positional references and
                    // get a different diagnostic just below.
```

### `compiler/s1/cli.nr:4493`

```
                    // v0.7.42 (defensive halt — Rust positional format-arg
                    // `{0}` / `{1}` / etc.). Detect digits-only spec and
                    // halt with an explicit `{}`-only workaround pointer.
```

### `compiler/s1/cli.nr:4637`

```
                // v0.6.76 RFC V1.9
                // canonical Rust `assert!(cond, "fmt {}", arg)` pre-fix
                // stripped `!` and emitted `assert(cond, "fmt {}", arg)`
                // — a 3-arg call to the 1-arg `__nucleor_assert(i64)`
                // helper. Format args dropped, `{}` stayed literal, and
                // assert(cond_truthy=1) silently passed even with broken
                // format args. v0.6.73 attempt regressed cold +1.7s due
                // to per-call comma walking; this ship limits the walk
                // to assert/assert_eq/assert_ne calls only (cheap name
                // gate), and only when 2+ (assert) / 3+ (assert_eq/ne)
                // top-level commas are present (format-arg shape).
                // Rewrite shape:
                //   assert!(c, "fmt", args)   →  if !(c) { panic("fmt-built"); };
                //   assert_eq!(a, b, "fmt", args) →  if !((a) == (b)) { panic("fmt-built"); };
                //   assert_ne!(a, b, "fmt", args) →  if !((a) != (b)) { panic("fmt-built"); };
                // The `panic("fmt-built")` part is built via mode-5
                // fmt_build_expansion — same path panic! mode-5 uses.
```

### `compiler/s1/cli.nr:4956`

```
                // v0.7.20 (defensive halt — Rust built-in macros NOT supported
                // in Nucleor's textual macro layer: file!/line!/column!/
                // module_path!/stringify!/concat!/env!/option_env!/include_str!/
                // include_bytes!). These need a const-eval pass which Nucleor
                // doesn't have yet. Pre-fix: wrong-class NR020 (zero-arg) or
                // TYP-005 (arg-bearing). v0.7.25: tightened to a single token-
                // boundary string-contains scan + one multi-line message.
```

### `compiler/s1/cli.nr:4968`

```
                // v0.8.28 (defensive halt — user-defined / unknown macro
                // invocation `name!(args)` in expression position).
                // Pre-v0.8.28 any unrecognized `name!(args)` fell through
                // the macro expansion pass with the `!` preserved in the
                // output. The token-level parser then saw `name` (identifier)
                // followed by `!` (token 38, unary NOT) applied to `(args)`
                // (i32 / str expression) — producing wrong-class
                // `error[TYP-002]: unary \`!\` requires a \`bool\` operand
                // (got i32)`. This was the observable failure for code like
                // `square!(5)` when `macro_rules! square { ... }` had been
                // declared (but silently dropped — see the companion fix in
                // the module-level macro_rules halt above).
```

### `compiler/s1/cli.nr:6614`

```
    // v0.8.150 V1.16 Phase A0 — `--lsp-mode` flag stub.
    // SPEC-LSP-server.md calls for ~600 LOC subprocess-mode LSP
    // daemon. Phase A0 wires the flag and emits the server-
    // capabilities advertisement as JSON-on-stdout so editor
    // extensions can probe what's supported. Phase A1 (real LSP
    // base protocol with Content-Length-framed JSON-RPC) is the
    // follow-on ship — needs raw stdin byte reads added to the
    // io_rt surface first.
```

## `compiler/s1/emit.nr`

### `compiler/s1/emit.nr:722`

```
    // v0.3.236 Phase A — sym-aux side hashmap helpers
```

### `compiler/s1/emit.nr:730`

```
    // v0.4.10 Phase A — compile-source side table
```

### `compiler/s1/emit.nr:1445`

```
// v0.6.70 perf-slice extension (string constant pool
// dedup): when adding a string literal to strtab, return the existing
// index if the string was already added. Significantly shrinks the
// .ll output and reduces clang link time on programs with repeated
// diagnostic strings, IR opcode strings, and rod-helper names.
// the warm-hashmap
// substrate is contended with sym_get (every sym_get on a different
// vec clears the hashmap, causing strtab_intern to re-catchup from 0
// each call). Net cost was +1s cold (worse than linear).
// Linear-scan cost on self-host: ~9400 inserts × ~3500 avg scan
// length = ~33M str_eq compares. With first-byte-fail on most
// uniques, ~80ms total. Acceptable.
// v0.7.x P2: keep the tiny-table linear path, then switch to a
// dedicated strtab-only hashmap threaded alongside the strtab. This
// avoids the shared warm-cache contention that killed the v0.6.72
// attempt while preserving low overhead for small adopter programs.
// Backward-scan optimization: many string literals are emitted in
// blocks (e.g. emit_externs declarations, repeated diagnostic
// substrings) where recent inserts are likely to match. Scan from
// the END toward the start to hit those fast.
```

## `compiler/s1/get_rt_name.gen.nr`

### `compiler/s1/get_rt_name.gen.nr:957`

```
    // v0.3.236 Phase A — sym-aux side hashmap helpers (hash-backed
    // sym_get refactor). Mappings ship in Phase A so that Phase B
    // source migration can be compiled by a Phase-A binary.
```

### `compiler/s1/get_rt_name.gen.nr:964`

```
    // v0.4.10 Phase A — compile-source side table for deep helpers
```

## `compiler/s1/ir.nr`

### `compiler/s1/ir.nr:275`

```
// v0.5 3e.1 spike: signed LLVM overflow-intrinsic arithmetic.
// Opcodes 35/36/37 mirror add/sub/mul. tid carries width (0 => i64),
// extra carries the trap label; the continuation label is trap + 1.
```

### `compiler/s1/ir.nr:363`

```
    // v0.4.209 RFC-0015 phase 3a-step-3 (Option F-light): per-fn
    // widths-by-reg table. Slot 4 stores a Vec<i32> indexed by
    // alloca-reg id; values are sign-encoded narrow widths
    // (positive=signed, negative=unsigned, 0=untyped/i64). Grows
    // on demand at set time. Read at every var-ref load + store
    // for typed-IR dispatch. Two vec_gets per read on the hot path
    // — no str_concat, no sym_get hash.
```

## `compiler/s1/lex.nr`

### `compiler/s1/lex.nr:184`

```
    // v0.3.139 `requires` / v0.3.140 `restricts` / v0.3.141 `loop`
    // fixes — `parse_primary` had no branch for token 86 so any user
    // fn or call site named `as` collapsed to silent `int_lit 0` in
    // the IR with no diagnostic. The cast operator's parse_postfix_cast
    // check is rewritten to use pkv lookahead.
```

### `compiler/s1/lex.nr:458`

```
            // v0.7.75 (defensive halt — Rust raw identifier prefix
            // `r#name`, used to write a binding whose spelling clashes
            // with a Rust keyword like `type`, `match`, `fn`, etc.).
            // Pre-fix the `r` lexed as an ident and `#` was emitted
            // as a separate punct token, leaving `name` to be lexed
            // as a fresh ident. The downstream parser then tripped
            // on whichever production saw three tokens (e.g. `r # type`
            // surfaced as v0.7.47's local-type-alias halt because
            // `type` got read as keyword token 74). Halt at lex with
            // a precise diag so adopters know the raw-identifier
            // surface itself isn't supported. Sister to v0.6.58 raw
            // string literal halt (same `r` prefix family).
```

### `compiler/s1/lex.nr:478`

```
            // v0.7.68 (defensive halt — C string literal `c"..."`, the
            // NUL-terminated FFI buffer form). Pre-fix the `c` lexed as
            // an ident and the parser tried to call fn `c` on the
            // trailing string literal, producing the wrong-class
            // `error[TYP-005]: undefined function 'c'`. Promoted from
            // probe finding 2026-05-03.
```

### `compiler/s1/lex.nr:488`

```
            // v0.7.28 (defensive halt — Rust byte literal `b'A'`, the u8
            // value of an ASCII char). Pre-fix the `b` lexed as an
            // identifier and the parser saw `b ('A')` — a fn call on a
            // char literal — surfacing as wrong-class `error[TYP-005]:
            // undefined function 'b()'`. Sister to v0.6.58 byte-string
            // halt and probe's c-string halt. Workaround: use a regular
            // char literal and cast — `'A' as i64` (or `as u8`).
```

### `compiler/s1/lex.nr:1110`

```
            // v0.7.78 (defensive halt — Rust block comments
            // `/* ... */` and doc-block `/** ... */`). Pre-fix the
            // `/` lexed as token 23 and `*` as token 22; the parser
            // saw a stray `/` at expression start and emitted
            // wrong-class `error[NR020]: parse_primary cannot start
            // an expression at token kind 23`. Adopters porting
            // Rust code with block comments hit this constantly.
            // Halt at lex with a clear diag pointing at the line-
            // comment workaround. Sister to v0.6.58 raw-string
            // halt (same lex-time wrong-class family).
```

### `compiler/s1/lex.nr:1196`

```
            // v0.7.29 (defensive halt — Rust Unicode-escape char literal
            // `'\u{1F600}'`, `'\u{0041}'`, etc.). Pre-fix the char-lit
            // lexer matched only 1-char and 1-backslash-1-char forms;
            // the multi-char `\u{NNNN}` escape fell through to the
            // lifetime-token path (kind 98) and the v0.7.2 loop-label
            // halt fired with a wrong-class diagnostic talking about
            // labels, not Unicode escapes. Detect `'\u{` here and halt
            // with a hex-cast workaround pointer.
```

## `compiler/s1/lower.nr`

### `compiler/s1/lower.nr:19`

```
// v0.7.x P2: store the shared table in a dedicated runtime hashmap.
// The original shared Vec removed the N^2 sym_set cost but still did a
// backward linear scan for every fallback lookup; caller attribution
// showed ~48M vec_get + ~48M str_eq calls here in one self-host build.
```

### `compiler/s1/lower.nr:30`

```
// v0.4.3 Phase B redo — hash-backed sym_get on a single warm-cache
// hashmap (one allocation total in the runtime; see nucleor_llvm_rt.c
// __nucleor_sym_aux_create comment for the design rationale).
// v0.3.237's per-sym aux model failed because sym_clone -> new aux
// per clone -> 1.8x peak-memory regression. The warm cache fixes
// that: ONE NHashMap exists in the runtime; when sym_get is called
// on a different handle than the cached one, the hashmap is cleared
// and rebuilt from the new sym. Memory cost is bounded by the size
// of the largest single sym ever cached.
// Size threshold: for small syms (< 128 pairs / 256 vec entries),
// the linear backward scan is competitive (cache-friendly, no
// hashmap touch) AND avoids warm-cache thrash on the many small
// clones that branch isolation creates. The hash path only fires
// for syms above the threshold -- in practice, the long-lived
// outer module-scope sym that linear scan was actually slow on.
// Most-recent-entry vec fast path is preserved -- the just-set
// lookup never touches the hashmap or the threshold check.
// Correctness invariants (validated by the bootstrap fixed-point
// gate -- if any of these are wrong, stage_b != stage_c IR diff
// fires):
//   sym_set: appends to vec only. Catchup loop in sym_get re-inserts;
//     hashmap_insert overwrites on duplicate key, so last-write-wins
//     gives the same answer the backward scan would.
//   own_put_i / own_put_s: in-place vec_set + hashmap_insert sync
//     IF this sym is currently the warm one. Without the sync the
//     hash would return the stale pre-update value.
//   own_restore: clears the hash if this sym is warm + resets
//     built_at = 0 so the next sym_get rebuilds from the post-
//     restore vec.
//   sym_clone: copies vec contents only. The new sym_handle is
//     different; on first sym_get against the clone, the warm
//     cache will reset and rebuild from the clone's vec.
```

### `compiler/s1/lower.nr:65`

```
    // v1.1.x perf: collapse the n>=2 tail check + n<64 linear scan
    // into a single C call. Helper scans backward from tail anyway,
    // so the explicit tail check was redundant. Saves one FFI call
    // per sym_get (~9M / build).
```

### `compiler/s1/lower.nr:1076`

```
// v0.6.74 RFC V1.1 step 2: tuple-struct shape detection. A struct is
// tuple-style if all field names match `__<digit>+` pattern (synthesized
// by parse_struct_decl when the decl uses paren-form). Used by
// constructor routing (kind-7 → struct ctor when callee is tuple-style)
// and field-access lowering (`p.0` → `p.__0`).
```

## `compiler/s1/modules.nr`

### `compiler/s1/modules.nr:633`

```
    // v0.7.88 (defensive halt — Rust compile_error ! macro invocation).
    // Pre-fix the macro-call shape compile_error ! (...) was
    // silently dropped by the parser (Nucleor's `!`-after-ident
    // handling treats it as a logical-not on the args, which
    // then gets DCE'd as a discarded value), so adopters writing
    // compile_error ! ("required feature missing") got a
    // successful build instead of the explicit compile-time
    // failure they wrote to force. Detect the literal
    // compile_error+!( byte sequence in the resolved source
    // and halt cleanly (the macro is now honored as the canonical
    // build-failure trigger).
    // skip when compiling the compiler itself (self-host
    // fixed-point path). The compiler source contains the search
    // pattern in string literals and comments; the textual pre-pass
    // would fire on self-compilation — a Linux-bootstrap false-positive.
    // str_concat avoids the literal pattern appearing in source text
    // so the search string is constructed at runtime.
    // RFC-0063 Phase 2.0.3 prep: also exempt
    // nucleor_tools_suite.nr — same rationale (compiler source contains
    // the pattern in error-message strings) and the parser-unification
    // ship needs tools_suite to be able to `import "...nucleor_s1_compiler.nr"`
    // without the detector tripping on s1's strings.
```

### `compiler/s1/modules.nr:688`

```
    // v0.8.5 (RFC-0045 Phase B step-1) — `@differentiable` audit.
    // The lex-time `@`-attribute skip (line ~247) already accepts
    // the attribute silently. Phase B-step-1 adds a build-time
    // count + one-line audit print so adopters get the
    // "Discovery: no way to grep for all differentiable fns in
    // a codebase" surface that v0.7.93 Phase A's runtime
    // registry was paired with. Phase B-step-2 (deferred) does
    // the symbol-alias emit for autodiff dispatch.
```

### `compiler/s1/modules.nr:705`

```
    // v0.8.6 (RFC-0050 Phase B step-1) — `@energy(max=...)` and
    // `@thermal(max_temp=...)` audit. Same shape as v0.8.5
    // @differentiable: lex-time `@`-attribute skip already accepts
    // these silently; this audit pass counts annotated fns and
    // emits a one-line build summary. Phase A (v0.7.89) added the
    // runtime budget registry; Phase B step-2 (deferred) parses
    // the literal value + unit and stores as fn metadata.
```

### `compiler/s1/modules.nr:734`

```
    // v0.8.7 (RFC-0052/53/57/60 Phase B step-1) — extended
    // attribute audit. Same shape as v0.8.5 / v0.8.6: count
    // annotated fns, emit one-line summary per attribute kind.
```

### `compiler/s1/modules.nr:810`

```
    // v0.8.143 (RFC-0043 Phase B step-1, V1.12 drift restoration)
    // — `fixed<I, F>` + `ufixed<I, F>` audit. The type still
    // collapses to i64 storage at line ~9902 (Phase B step-2
    // deferred — true IrTypeFixed width tracking is the ~300 LOC
    // ship). This Phase B step-1 surfaces adopter usage by
    // counting type-position occurrences and emitting a one-line
    // build summary, matching the @differentiable / @energy /
    // @thermal pattern. Position-aware needles (`: ` and `-> `
    // prefix) avoid false positives on identifiers ending in
    // "fixed" or "ufixed".
    // gate the per-needle scans behind a single
    // cheap probe. Most builds don't contain `fixed<` or `ufixed<`
    // — without the gate this block ran 4 full-source scans
    // unconditionally on every compile. Same shape applied to the
    // other audit families below.
```

### `compiler/s1/modules.nr:835`

```
    // v0.8.173 (RFC-0044 Phase B step-1, V1.13 drift restoration)
    // — per-BinOp `OverflowMode` audit. RFC-0044 calls for two
    // surface forms:
    //   - block: `wrapping { ... }` / `saturating { ... }` / `checked { ... }`
    //   - inline-suffix: `*#wrap`, `+#sat`, `/#trap`, `as#sat`, etc.
    // V2 carried `OverflowMode` as a per-BinOp IR field; OSS retained
    // only the block form (and even that may not be implemented yet
    // in current main). Phase B step-1 (this audit) surfaces adopter
    // usage of either form so future ships can lock the block-form
    // wiring + add the inline-suffix lex extension. Phase B step-2
    // (real per-BinOp lowering) is the larger ~150 LOC compiler ship.
```

### `compiler/s1/modules.nr:858`

```
    // v0.8.145 (RFC-0046 Phase B step-1, V2.1 frontier easy-win)
    // — `Pose<F>` + `Frame_*` marker audit. The `kinematics_frame`
    // rod already ships zero-cost marker structs (`Frame_World`,
    // `Frame_Base`, `Frame_Camera`, `Frame_Lidar`, `Frame_IMU`).
    // Adopters using these as phantom frame tags get a build-time
    // discovery counter from this audit pass. Phase B step-2 —
    // true phantom-type checking, `types_compatible(Pose<Camera>,
    // Pose<Base>) == 0` with a FRAME-001 diagnostic at let-binding
    // site — shipped v0838 (ROBO-7); see `frame_mismatch_visible`
    // and the FRAME-001 emit at the let-binding TYP-008 site.
    // Architectural pattern matches RFC-0043 fixed<I,F>.
```

### `compiler/s1/modules.nr:881`

```
    // v0.8.146 (RFC-0047 Phase B step-1, V2.2 frontier easy-win)
    // — typed dimensional units `unit<T, [kg, m, s, A, K, mol,
    // cd]>` audit. Same architectural pattern as RFC-0046
    // Pose<F>: phantom dimensional type parameter, zero runtime
    // cost. Phase B step-2 (real dim-vector arithmetic in
    // type-check) is the ~400 LOC compiler ship per the RFC.
    // This Phase B step-1 surfaces type-position usage of
    // unit<T, [...]> + the existing dimension-aliased `Mass<>`
    // / `Length<>` / `Force<>` / `Acceleration<>` shapes that
    // adopters might already be drafting.
```

### `compiler/s1/modules.nr:903`

```
    // v0.8.147 (RFC-0048 Phase B step-1, V2.3 frontier easy-win)
    // — hardware capability query audit. Adopters use
    // `target.has(FP4)` / `target.has(AVX512)` / `target.os(...)`
    // for compile-time-resolved kernel selection. Phase B step-2
    // (real compile-time evaluation that prunes non-target
    // branches via DCE before lowering) is the larger ship.
    // This Phase B step-1 surfaces usage by counting `target.has(`
    // and `target.os(` occurrences.
```

### `compiler/s1/modules.nr:919`

```
    // v0.8.148 (RFC-0049 Phase B step-1, V2.4 frontier easy-win)
    // — memory-space type-tag audit. Same architectural pattern
    // as RFC-0046 Pose<F>: phantom Space parameter on Tensor.
    // Surfaces adopter usage of `Tensor<f32, MemSpace_HBM>` etc.
    // Phase B step-2 (types_compatible enforcement on Space) is
    // the real ship.
```

### `compiler/s1/modules.nr:933`

```
    // v0.8.149 (RFC-0051 Phase B step-1, V2.6 frontier easy-win)
    // — Model<Arch, ...> provenance audit. Surfaces adopter
    // usage of typed foundation-model wrappers carrying
    // weights_hash / dataset_lineage / license / safety_eval /
    // quantization at the type level. Phase B step-2 (real
    // type-checked Model<...> with SPDX-validated license arg
    // etc.) is the larger ship.
```

### `compiler/s1/modules.nr:948`

```
    // v0.8.8 (Phase B step-1, core-attr audit) — extend the
    // discovery surface to existing core Nucleor attributes that
    // adopters use today: @hot (strict perf), @const_fn (compile-
    // time eligible), @max_depth (RFC-0014 / Track I), @deadline
    // (RT-004). The expansions for @max_depth + @deadline DO
    // produce metadata; the audit count adds a plain-language
    // build summary alongside.
```

### `compiler/s1/modules.nr:991`

```
    // v0.8.17 RFC-0062 G-2 Phase 1 — BR-7 lifetime parameter
    // diagnostic-only mode. Per the gap RFC §3.3 G-2 P1: emit a
    // build-time warning for every `<'a>` lifetime annotation
    // present in user code, surfacing the gap that lifetime
    // annotations parse but the borrow checker does not yet
    // enforce them. Phase 4 promotes the warning to error.
    // Detection: count occurrences of `<'` (lifetime-param-list
    // open) preceded by `fn ` or by `struct ` or by `impl `.
    // Per the gap RFC §2.2 BR-7: "the syntax `fn f<'a>(x: &'a str)
    // -> &'a str` parses cleanly. The lexer accepts the lifetime
    // tokens, the parser builds the AST, the function compiles.
    // The borrow checker does NOT actually enforce the lifetime
    // annotation."
    // collapsed 3 separate scans into 1 single-pass scan.
```

### `compiler/s1/modules.nr:1065`

```
    // v0.8.62 QM-8/9 + ROBO-8 Phase 1 — Wave 3 final Tier C
    // closure. v0828 closes the high-level qsim wrapper half of
    // QM-8/QM-9: qsim_cnot/CZ/CRK/CCX now update qsim_graph
    // entanglement and gate-DAG records through checked wrappers.
    // Raw runtime tracker unification remains open. QM-9: the raw
    // gate-influence DAG still caps at 4096 gates, but Nucleor callers
    // now have checked status/preflight helpers. ROBO-8: CHOMP uses approximated pre-conditioning
    // (clamp-magnitude vs full covariant A⁻¹∇F).
```

### `compiler/s1/modules.nr:1086`

```
    // v0.8.61 ML-2/3/5/6/10 Phase 1 — Tensor/ML/Autodiff surface
    // info. Detects adopter use of tensor_nd or transformer rods
    // — surfaces have multiple HIGH-severity gaps: ML-2 missing
    // 2D matmul, ML-3 missing transpose, ML-5 SSM no backward,
    // ML-6 no FP8 gemv / grouped quantization, ML-10 transformer
    // no causal mask / no encoder-decoder. Phase 2b adds the
    // missing primitives.
```

### `compiler/s1/modules.nr:1106`

```
    // v0.8.60 NUM-G2/8/9 Phase 1 — additional numeric-correctness
    // audit. Detects adopter use of math_abs (NUM-G2 i64::MIN
    // wrap), checked_* family (NUM-G8 thread-unsafe global flag),
    // @const_fn (NUM-G9 silently ignored). Phase 2b: panic-on-
    // saturate for math_abs, thread-local checked flag, real
    // comptime evaluation for @const_fn.
```

### `compiler/s1/modules.nr:1125`

```
    // v0.8.59 QM-7 / ROBO-7 Phase 1 — Tier C correctness audit-
    // pass info. Detects adopter use of the Clifford-stabilizer
    // rod (coverage still bounded; QM-7) and frame-typed
    // robotics rod. v0838 (ROBO-7 Phase B): the compiler-side
    // FRAME-001 frame-mismatch check at let-binding sites is now
    // live for `Pose<Frame_*>`-style phantom-tag annotations;
    // Frame_Unknown remains the documented migration sentinel.
    // Untagged kinematics surface (plain i64 handles, untagged
    // Pose) still bypasses the check by construction — adopter
    // opt-in via the typed annotation is the trigger.
```

### `compiler/s1/modules.nr:1148`

```
    // v0.8.58 LAW-1/2/3 Phase 1, refreshed after R14
    // `--check-laws` wiring. @law(...) is captured and reported;
    // the main compiler still does not attach it to AST/IR rewrite
    // metadata. The tools-suite test driver can generate bounded
    // integer checks for low-risk forms under `nuc test --check-laws`.
```

### `compiler/s1/modules.nr:1199`

```
    // v0.8.57 PKG-5 Phase 1 — `@cfg(feature = "...")` gating
    // info. Today `[features]` sections in nucleor.toml parse +
    // store but no compiler path consumes them; `--features X`
    // to `nuc build` does not gate any code. Adopter using
    // @cfg(feature = "...") gets the body included regardless.
    // Phase 2b adds proper feature-gating in lower_fn.
```

### `compiler/s1/modules.nr:1213`

```
    // v0.8.54 RT Phase 1 — real-time/determinism partial-enforcement
    // info. Detects #[deadline], #[no_alloc], #[no_panic], #[isr]
    // annotations and warns adopters about known gaps in enforcement
    // (RT-G1 transitive callee, RT-G3 panic-check incomplete, RT-G5
    // deadline marketing-claim unbacked, RT-G6 no embedded sysroots).
```

### `compiler/s1/modules.nr:1233`

```
    // v0.8.50 C-1/C-2 Phase 1 — Linux concurrency surface info.
    // The concurrency.nr rod's cancel_token (C-1) and POSIX channel
    // (C-2) helpers are silently broken on Linux: cancel_token is a
    // linker bomb (extern fn declared, body absent), POSIX channel
    // is a no-op stub. Detect adopter use of the concurrency rod
    // or its functions and surface the Linux platform risk.
```

### `compiler/s1/modules.nr:1252`

```
    // v0.8.48 E-1/E-2/E-3 Phase 1 — effect/capability build-summary info.
    // v0.8.307/v0.8.309 later closed the direct `pure fn` build-path
    // no-signal class with EFF-001 for print/alloc/ambient capability use.
    // v0829/v0831 add bounded same-file pure-call checking for user helpers
    // whose bodies contain direct side effects, requires-row surfaces, and
    // builtin print-family I/O.
    // The remaining trust gap is the effect-row surface:
    // `requires [...]`, real block-form `restricts [...]` enforcement,
    // transitive requires-row propagation, and cross-module propagation
    // are not fully enforced by s1. Block-form `restricts [...] { ... }` now
    // fails closed with EFF-003 until that enforcement lands.
    // Phase 2b moves effect-row enforcement into the main build path.
    // Shared gate: skip if none of the three keywords are textually
    // present (most adopter code doesn't use these keywords).
```

### `compiler/s1/modules.nr:1283`

```
    // v0.8.46 T-3 Phase 1 — char-cast build-summary info. Counts
    // `as char` cast occurrences in source. Today, casting an int
    // to char silently accepts any value including out-of-range
    // codepoints (>0x10FFFF) and surrogate range (0xD800-0xDFFF),
    // producing invalid UTF-8 downstream. Phase 2b will add
    // codepoint validation at the cast site. Phase 4 promotes to
    // hard error for invalid codepoints.
```

### `compiler/s1/modules.nr:1308`

```
    // v0.8.34 Q2 — slice-pattern diagnostic refinement.
    // Pre-existing behavior: slice match with rest element hit
    // parse_primary's token-58 panic and emitted the range-
    // expression diagnostic, wrong-class. Pre-detect the
    // textual shape (rest at slice-pattern closing bracket and
    // related sites — rare in prose) and halt cleanly.
    // Self-host safe: needles constructed via str_concat AND
    // the diagnostic message + comments avoid the literal
    // detected sequences (use spaced forms throughout).
```

### `compiler/s1/modules.nr:1363`

```
    // v1.0 RFC-0062 G-7 Phase 3 — `unsafe { }` block audit. The
    // OSS compiler self-host source contains zero unsafe blocks;
    // adopter code introducing unsafe blocks gets surfaced here
    // so reviewers can audit the surface. Phase 3 is a warning
    // (not an error) — unsafe is a legitimate language feature.
    // Phase 4 promotion (post-v1.0): require `#[allow(unsafe)]`
    // attribute on the enclosing fn.
```

### `compiler/s1/modules.nr:1375`

```
    // v0.8.38 G-1 Phase 2b-3 — env-gated default-flip status
    // diagnostic. Reads NUC_AUTO_DROP_DEFAULT env var. When set
    // to "1", the compiler treats auto-drop as enabled by
    // default for all fns. Adopters can opt in to test the
    // future Phase 2b-3 semantics. Default-off remains opt-in
    // via #[auto_drop].
```

### `compiler/s1/modules.nr:1385`

```
        // v0.8.73 G-3 Phase 2b — strong warning when flip is on
        // and source contains handoff patterns. Catches the gap
        // identified in v0.8.71 testing: vec_push(<param>, local)
        // patterns that auto-drop would dangle.
```

## `compiler/s1/parse.nr`

### `compiler/s1/parse.nr:142`

```
        // v0.4.78 NR020 — was a `print()` warning that returned `pos + 1`
        // and continued parsing. The parser produced a likely-broken AST,
        // type-check + lower happily consumed it, and codegen emitted a
        // silently-wrong binary. Triaged via the `@` binding pattern
        // probe (`x @ 1..=10`) which printed a parse error AND ran to
        // exit=0 with no output. Promoted to a hard panic — adopters
        // who hit this previously shipped broken binaries.
        // emit token-name table output instead of raw IDs.
        // Pre-fix message: "expected token 52 got 50" — opaque.
        // Post-fix: "expected `{` got `(`" — actionable.
```

### `compiler/s1/parse.nr:559`

```
            // v0.4.163 MATCH-012 — pre-fix `Point { x: 0, y: 0 } => ...` fed the
            // raw int-literal value into pkv (which returns i64) and bound it as
            // a str to `bname`, producing garbage that crashed codegen with an
            // ACCESS VIOLATION. Now: require an identifier after `:` and emit a
            // clean diagnostic if anything else appears. Field-equality literal
            // patterns (`{ field: <literal> }`) are deferred to v0.5+.
```

### `compiler/s1/parse.nr:635`

```
    // v0.7.35 (defensive halt — Rust top-level `ref` / `ref mut` binding
    // mode in a match arm pattern: `match x { ref n => ... }`,
    // `match x { ref mut n => ... }`). Pre-fix this surfaced as wrong-
    // class `error[NR020]: expected '=>', got identifier` because the
    // pattern parser swallowed `ref` as the wildcard binding name then
    // saw the actual binding `n` where `=>` was expected. Sister to
    // v0.7.23 (`ref` inside a variant pattern). Workaround: drop `ref` —
    // Nucleor's i64-everywhere ABI already passes by value.
```

### `compiler/s1/parse.nr:684`

```
        // v0.7.22 (defensive halt — bare negative-literal pattern in
        // match arm: `match x { -5 => ..., _ => ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: expected '=>', got
        // integer literal` because the pattern parser had no `-` (token
        // 21) entry — the `-` was consumed as a no-op, then `5` was
        // read as the standalone int-lit pattern, leaving the trailing
        // `=>` to land where the parser expected an expression
        // continuation. Halt cleanly with a guard workaround.
```

### `compiler/s1/parse.nr:785`

```
            // v0.7.54 (defensive halt — paren-wrapped payload inside a
            // variant pattern: `Some((1))`, `Ok((x, y))`). Pre-fix this
            // surfaced as wrong-class `error[NR020]: expected ')', got
            // integer literal` because the parser fell through to
            // pkv-on-`(` (garbage binding), advanced past the inner `(`,
            // then tried to expect `)` at the inner-payload position.
            // Halt cleanly with a drop-the-extra-parens workaround.
```

### `compiler/s1/parse.nr:797`

```
            // v0.7.24 (defensive halt — bare negative-literal payload inside
            // a variant pattern: `Some(-5)`, `Ok(-1)`, `Err(-9)`). Pre-fix
            // this surfaced as wrong-class `error[NR020]: expected ')', got
            // integer literal` because the variant-pattern parser swallowed
            // `-` (token 21) as the binding name, then `5` landed where the
            // parser expected `)`. Sister to v0.7.22 MATCH-015 (bare negative
            // literal at outer pattern level). Workaround: use a guard.
```

### `compiler/s1/parse.nr:810`

```
            // v0.7.51 (CRITICAL — bare integer-literal payload inside a
            // variant pattern: `Some(1)`, `Ok(0)`, `Err(42)`). Pre-fix
            // this SEGFAULTED the compiler at IR-emit time because the
            // variant-pattern parser captured the int literal's i64
            // value as the binding-name string, then downstream codegen
            // tried to emit a variable named "1" — invalid LLVM ident
            // → SIGSEGV (rc 139, no diagnostic). Sister to v0.7.22 /
            // v0.7.24 (negative-literal halts) but for the segfault
            // class. Halt cleanly with a guard workaround.
```

### `compiler/s1/parse.nr:825`

```
            // v0.7.53 (CRITICAL — bare float-literal payload inside a
            // variant pattern: `Some(1.5)`, `Ok(2.0)`, etc.). Same
            // SEGFAULT class as v0.7.51 (int) — different lexer tokens.
            // Token 70 = f-suffix-typed lit, 124 = f64 raw-bits, 125 = f32.
            // Pre-fix this also crashed the compiler at IR-emit (rc=139,
            // no diagnostic). Sister to v0.7.51 (int-lit) and the
            // pre-existing v0.4.206 outer-level float-literal halt
            // (MATCH-013) which only fires at the outer match scrutinee
            // pattern level. Add a tailored MATCH-013-style message
            // pointing at float-equality fragility and offering a guard
            // workaround.
```

### `compiler/s1/parse.nr:844`

```
                // v0.6.90 (defensive halt — canonical Rust nested
                // pattern `Some(Some(v))` / `Ok(Some(v))` / etc.):
                // pre-fix the inner `(` after the binding name surfaced
                // as the wrong-class `error[NR020]: expected ')', got
                // '('` because the pattern parser treats the binding
                // slot as a single ident and then expects `)`. Halt
                // cleanly with a 2-step destructure workaround pointer.
                // Forward-roadmap: recursive pattern parser (sister to
                // nested struct patterns at line 1364).
```

### `compiler/s1/parse.nr:858`

```
                // v0.7.19 (defensive halt — Rust `@` binding inside a
                // variant pattern: `Some(n @ 1..=10)`, `Ok(s @ "a")`,
                // etc.). Pre-fix this surfaced as wrong-class `error
                // [NR020]: expected ')', got token 122` (token 122 = `@`).
                // Workaround: hoist the `@` to the top-level pattern
                // (`n @ Some(_)`) or split the guard
                // (`Some(n) if (1..=10).contains(&n)`).
```

### `compiler/s1/parse.nr:870`

```
                // v0.7.23 (defensive halt — Rust `ref` / `ref mut` binding
                // mode inside a variant pattern: `Some(ref v)`, `Ok(ref mut
                // s)`, etc.). The pre-Q binding-name capture above swallowed
                // `ref` as if it were the binding identifier; the next
                // token (the actual binding name) then landed where the
                // parser expected `)`, surfacing as wrong-class `error
                // [NR020]: expected ')', got identifier`. Workaround:
                // Nucleor's i64-everywhere ABI passes everything by value
                // already, so `ref` is a no-op semantically — just drop it.
```

### `compiler/s1/parse.nr:899`

```
        // v0.7.45 (defensive halt — tuple-struct pattern in match arm:
        // `match p { P(a, b) => ... }`). Pre-fix this surfaced as wrong-
        // class `error[NR020]: expected '=>', got '('` because the
        // wildcard fallback at the end of pattern dispatch consumed `P`
        // as a binding name and left `(` for the arrow expector. Detect
        // identifier-followed-by-`(` here and halt cleanly with a
        // field-access workaround pointer (V1.1 tuple-struct decl
        // shipped v0.6.74; ctor + positional access works, only the
        // pattern-position destructure is missing).
```

### `compiler/s1/parse.nr:969`

```
        // v0.6.81 RFC V1.7 — UFCS dispatch `<Type as Trait>::method(args)`.
        // Pre-fix the `<` at expression start panicked with the v0.6.60
        // halt + workaround pointer. Now parse the canonical Rust UFCS
        // form and emit a regular kind-7 call to the type-mangled name
        // `<Type>__<method>` — Nucleor's trait-impl mangling already
        // produces this name regardless of which trait the impl came
        // through (the trait_impl_register path at ~line 25478). UFCS
        // therefore acts as a verbose surface-level alias that adopters
        // porting Rust code can paste in directly.
        // Note: when two traits provide the same method on the same
        // type, both impls register the SAME mangled name and Nucleor
        // emits the duplicate-fn-name diag at struct-emit time
        // (line ~7958, "ambiguous method") — the ambiguity is rejected
        // there, so UFCS-as-disambiguator is moot under today's
        // mangling. Per-trait mangling is the v1.x trait-dispatch
        // ship; until then UFCS is purely a translation-fidelity
        // surface. Fall through to the v0.6.60 halt for any shape we
        // can't recognise so adopter code with an unsupported UFCS
        // shape still gets a clean diag with workaround pointer.
```

### `compiler/s1/parse.nr:1121`

```
        // v0.7.21 (defensive halt — parenthesized range expression
        // `(start..end)` / `(start..=end)`). Pre-fix this surfaced as
        // wrong-class `error[NR020]: parse error: expected ')', got
        // token 58` (token 58 = `..`, token 96 = `..=`) because Nucleor's
        // range parser is hardcoded inside `parse_for_stmt` only —
        // ranges are NOT valid expressions in `parse_expr`. Halt cleanly
        // with a workaround pointer (use the bare for-iter form, or
        // build the iteration manually).
```

### `compiler/s1/parse.nr:1160`

```
                // v0.6.12 halt to three more inner-expression shapes
                // that *also* silently miscomputed (returned the inner
                // expression's *value*, e.g. fn-pointer address, instead
                // of CALLING it):
                //   - kind 42 (closure literal — IIFE: `(|x| x*2)(21)`)
                //   - kind 7 (call result — `(get_handler())(21)`)
                //   - kind 99 (`as` cast — `(p as fn(i64)->i64)(21)`)
                // Same workaround pattern (extract to a local first)
                // works for all three. Full indirect-call lowering
                // remains the multi-ship real fix.
```

### `compiler/s1/parse.nr:1200`

```
            // v0.6.77 RFC V1.11
            //  canonical
            // Rust `[VAL; N]` (e.g. `let buf: Vec<i64> = [0; 4];`)
            // pre-fix rejected at parse time with `error[NR020]: parse
            // error at byte K: expected ',', got ';'` — the `[V, V, ...]`
            // parser had no `;` branch and the `vec![V; N]` macro
            // (closed v0.6.41) requires the `vec!` prefix.
            // Now after parsing the first item, peek for `;` — if
            // present, parse N (must be a literal int) and expand to
            // an N-item kind-47 array literal (same lowering as
            // `[V, V, ..., V]` — vec_new + N pushes). Hard-cap N at
            // 1024 to keep the parse-time expansion bounded; for
            // larger / runtime-evaluated N the existing `vec![V; N]`
            // form is the path.
```

### `compiler/s1/parse.nr:1277`

```
    // v0.3.148) to safely guard the pkv dereference.
```

### `compiler/s1/parse.nr:1281`

```
    // v0.7.76 (defensive halt — Rust `const { ... }` inline-const
    // block expression, used to force compile-time evaluation of
    // the body even in non-const contexts). Pre-fix `const` lexed
    // as keyword token 73 and parse_primary had no branch for it
    // at expression start, surfacing as wrong-class
    // `error[NR020]: parse_primary cannot start an expression at
    // token kind 73`. Halt cleanly when `const` is immediately
    // followed by `{`. Sister to v0.7.74 `try { ... }` halt
    // (same expr-position-block-not-supported family).
```

### `compiler/s1/parse.nr:1295`

```
    // v0.7.74 (defensive halt — Rust experimental `try { ... }` block
    // expression, used to wrap fallible computation and yield a
    // `Result<T, E>` with `?` short-circuiting). Pre-fix `try` lexed
    // as an identifier and the `{ ... }` that followed parsed as
    // some other production, with the surface treating `try` as a
    // fn name and downstream emit producing a clang-link wrong-class
    // `error[TYP-005]: undefined function 'try()'`. Halt cleanly at
    // parse_primary when we see `try` immediately followed by `{`.
    // Sister to the `unsafe { ... }` / `wrapping { ... }` /
    // `saturating { ... }` block-expr branches just below; same
    // ident-then-`{` lookahead shape, but no semantic substrate yet
    // for the Result-wrapping rewrite.
```

### `compiler/s1/parse.nr:1327`

```
        // v0.4.238's NUCLEOR_INT_STRICT_INTRIN=1 default, every
        // `wrapping { a + b }` block emitted the strict-intrinsic
        // trap path and panicked at runtime on real overflow —
        // the exact opposite of the user's intent. The wrap_i32
        // tail clamp (kind-52 mode==1 in lower_expr) was the only
        // thing keeping the block's final value pinned to i32
        // range; per-op behavior was broken pre-v0.4.238 too,
        // just invisibly because nsw doesn't trap.
```

### `compiler/s1/parse.nr:1353`

```
        // v0.5 ship 7 — capture identifier byte offset for spanning
        // call expressions (kind 7) and the var-ref fallback.
```

### `compiler/s1/parse.nr:1357`

```
        // v0.7.87 (defensive halt — Rust prelude `drop(value)`).
        // Pre-fix `drop(v)` parsed as a call to undefined fn `drop`,
        // surfacing first as warning[TYP-005] and then clang-link
        // hard-fail wrong-class `error[TYP-005]: undefined function
        // 'drop'`. Adopters expect Rust's prelude `drop` (which
        // forces ownership transfer / RAII destructor); Nucleor's
        // i64-everywhere ABI manages heap via reference-tracking,
        // so `drop(v)` is informational (Nucleor frees when the
        // last reference goes out of scope). Halt cleanly with a
        // workaround pointer (just remove the `drop(v)` call —
        // the heap manages itself; for explicit Vec clear use
        // `vec_clear(v)`). Sister to v0.6.82 idiom-method halt
        // family (same Rust-prelude-not-yet-supported class).
```

### `compiler/s1/parse.nr:1501`

```
        // v0.4.209 RFC-0015 phase 3a-step-3 (Option D): kind-3 var-ref
        // promoted from mk2 to mk3. Slot 2 is the width-tag for narrow-
        // typed bindings (i8/i16/u8/u16). Default 0 = untyped (i64 ABI
        // back-compat). Type-check fills it in for narrow types; codegen
        // reads it via a single node_field call (no str_concat, no
        // sym_get hash hit — the perf failure mode of v0.4.199's retry).
        // v0.5 ship 7 final: span the var-ref nid at the identifier
        // byte offset so OWN-001 (use-after-move) and other identifier-
        // anchored diagnostics caret precisely at the use site instead
        // of scanning the source text by name (which hits the FIRST
        // occurrence, not the actual use site).
```

### `compiler/s1/parse.nr:1576`

```
    // v0.4.72 / v0.4.81 attempts to panic unconditionally broke
    // tests/rods/pgs_smoke (token 51 = `)` legitimately reached
    // here from macro-expanded code at byte 6571). Per change-map
    // §9 the proper fix is a `parse_primary_or_recover(allow_recovery)`
    // two-arg API — but that requires finding every recovery
    // context call site of parse_primary. For now: keep silent
    // fallback ONLY for tokens that mark expression-end /
    // recovery-context (`)` `,` `;` `}` `]` `=` `EOF`). For ANY
    // OTHER unhandled token (including `@`, raw `:`, etc.), halt
    // with NR020. This catches the silent-miscompute class while
    // preserving pgs_smoke's legit recovery.
```

### `compiler/s1/parse.nr:1663`

```
            // v0.6.74 RFC V1.1 step 3: tuple-struct positional access.
            // `p.0` / `p.1` lex as `.` + int-literal token. Synthesize
            // the synthetic field name `__<digit>` at parse time so
            // the existing field-access type-check + lower paths
            // resolve to the matching `__<digit>` field declared in
            // parse_struct_decl's paren-form path.
```

### `compiler/s1/parse.nr:1701`

```
                // v0.6.98 RFC V1.7-ext: turbofish syntax
                // `.method::<TypeArgs>(args)`. Pre-fix surfaced as
                // wrong-class `error[NR020]: parse_primary cannot
                // start expression at token kind 46` because the
                // postfix parser had no `::<` branch. Now: skip the
                // balanced `<...>` type-args (advisory under today's
                // mangling — Nucleor monomorphises by parameter, not
                // by call-site turbofish) and parse the trailing
                // `(args)` as a regular method call.
```

### `compiler/s1/parse.nr:1801`

```
        // v0.5 ship 7 — capture the `as` token's byte offset as the
        // cast nid's span so NUM-003 (narrowing) and NUM-006 (narrow-
        // float vec read) carets land at the cast site instead of
        // the function name fallback.
```

### `compiler/s1/parse.nr:2030`

```
        // v0.6.78 RFC V1.11
        //  canonical Rust slice type `&[T]` as fn-param type
        // pre-fix rejected with the wrong-class `error[NR020]: parse
        // error at byte K: expected ';', got ']'` because the array-
        // type parser only knew the `[T; N]` shape. Now accept the
        // bare `[T]` shape (no length) and resolve to `Vec<T>` —
        // Nucleor arrays are Vec internally, and `&[T]` thus resolves
        // to `&Vec<T>` which the type system already accepts. Slice
        // ABI (length-tagged base+len pair) is the v1 V1.5 ship; v0.6.78
        // is a translation-fidelity surface bridge.
```

### `compiler/s1/parse.nr:2071`

```
    // v0.7.3 (defensive halt — raw pointer types `*const T` /
    // `*mut T`): canonical Rust raw-pointer type position
    // (`let p: *const i64 = ...;`, `fn read(p: *const i64)`)
    // pre-fix surfaced as wrong-class `NR020: parse_primary cannot
    // start expression at token kind 73` (the `const` keyword
    // following `*`) because parse_type had no `*` branch — the
    // outer parser saw `*` as the multiplication operator (token
    // 22) at type position. Halt cleanly with a workaround pointer
    // (use `&T` / `&mut T` borrow-references for safe code, or
    // store as i64 for FFI / unsafe-style transit).
```

### `compiler/s1/parse.nr:2099`

```
    // v0.3.92/v0.4.112: trait object syntax `dyn Trait`.
    // Preserve the `dyn` marker so Box<dyn Trait> can be distinguished
    // from Box<Trait> during type checking.
    // consume any `+ Bound` / `+ 'lifetime` suffixes
    // (e.g. `dyn Write + Send`, `dyn Trait + Sync + 'static`).
    // Additional bounds are accepted and silently stripped — vtable dispatch
    // and Send/Sync enforcement are deferred to the v1.x trait-object ship.
    // Pre-fix: `&dyn Trait + Send` failed with NR020 "expected `,` got `+`".
```

### `compiler/s1/parse.nr:2336`

```
            // v0.7.69 (defensive halt — Rust opt-out trait bound
            // `?Sized`, used to relax the implicit Sized bound on
            // generic params so they accept DSTs like `str`/`[T]`).
            // Pre-fix the `?` token (97) was consumed silently by the
            // bound walker and the trailing `Sized` was stored as a
            // regular `?Sized` marker — visually identical to the
            // already-prefixed v0.4.130 storage convention but
            // semantically wrong: adopters expect Nucleor to relax
            // its Sized requirement, not silently keep it. Nucleor
            // has no DST substrate yet, so silent acceptance is a
            // wrong-class hazard. Halt cleanly and tell users the
            // bound is a no-op for now (everything is Sized).
```

### `compiler/s1/parse.nr:2400`

```
    // v0.7.81 (defensive halt — Rust array-destructure-in-let
    // `let [a, b, c] = [1, 2, 3];`). Pre-fix the parser read `[`
    // (token 54) as the binding name and the `,`-separated names
    // followed by `] = [...]` got partially recognized as an
    // assign-to-array-LHS expression. The LHS validator printed
    // "assignment to this LHS form is not supported" but the
    // build CONTINUED, emitted broken IR, and clang link failed
    // wrong-class `error[TYP-005]: undefined function 'a()'`
    // (the first array element became a phantom fn call). Halt
    // cleanly at parse-let with a workaround pointer. Sister to
    // v0.6.61 struct-destructure-in-let and v0.3.81 tuple-
    // destructure-in-let halts (same pattern-in-let family).
```

### `compiler/s1/parse.nr:2517`

```
    // v0.3.97 diag-only stub is no longer needed — parse_expr
    // consumes the full bitwise expression, so there's nothing
    // left for next_after_rhs to detect.
```

### `compiler/s1/parse.nr:2570`

```
        // v0.7.60 (defensive halt — paren-wrapped pattern in `if let` /
        // `while let`: `if let (Some(x)) = opt { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: parse_primary cannot
        // start an expression at token kind 11`. Sister to v0.7.54
        // paren-wrapped variant-payload halt.
```

### `compiler/s1/parse.nr:2613`

```
            // v0.7.80 (defensive halt — Rust wildcard pattern `_` in
            // `if let _ = expr` / `while let _ = expr`). Pre-fix the
            // `_` ident didn't match any of the recognized
            // pattern shapes (Some/None/Ok/Err, Type::Variant), the
            // if-let parser fell through with `ename` empty, and the
            // outer parser then hit `let` (token 11) at expression
            // start, surfacing as wrong-class
            // `error[NR020]: parse_primary cannot start an expression
            // at token kind 11`. Halt cleanly with a workaround
            // pointer (`let _ = expr;` already works as a discard;
            // the if-let `_` form is rare and equivalent to a plain
            // boolean `if true { ... }`). Sister to v0.7.50
            // or-pattern halt — same if-let pattern-shape family.
```

### `compiler/s1/parse.nr:2631`

```
            // v0.7.50 (defensive halt — Rust or-pattern in `if let` /
            // `while let`: `if let Some(1) | Some(2) = opt`). Pre-fix
            // this surfaced as wrong-class `error[NR020]: expected '=',
            // got token 65` (token 65 = `|`) because the if-let parser
            // expects `=` immediately after the first pattern. Halt
            // cleanly with a separate-arm workaround for if-let, or use
            // a match for true or-pattern semantics.
```

### `compiler/s1/parse.nr:2647`

```
            // v0.7.72 (defensive halt — Rust 2024 if-let chain:
            // `if let Some(x) = opt && cond { ... }`). Pre-fix
            // parse_expr greedily consumed `opt && cond` as a single
            // boolean expression and the desugared match scrutinee
            // referenced the pattern binding (`x`) in the chained
            // condition BEFORE the match-arm bound it — emitting an
            // undefined-name call that clang linked as wrong-class
            // `error[TYP-005]: undefined function 'x()'`. Detect by
            // scanning the consumed scrutinee tokens for `&&`
            // (token 36) — Rust 2024 if-let chains require pattern
            // + guard composition that Nucleor's desugar does not
            // yet model. Sister to v0.7.50 or-pattern halt (same
            // family of "Rust syntax tighter than Nucleor's if-let
            // desugar").
```

### `compiler/s1/parse.nr:2679`

```
                // v0.7.46 (defensive halt — `if let` chained `else if let`
                // / `else if`). Pre-fix `if let Some(x) = a { ... } else if
                // let Some(y) = b { ... }` surfaced as wrong-class
                // `error[NR020]: expected '{', got token 13` (token 13 =
                // `if`) because the if-let parser only knows the bare
                // `else { ... }` form. Halt cleanly with a nested-else
                // workaround pointer.
```

### `compiler/s1/parse.nr:2776`

```
        // v0.7.60 (defensive halt — paren-wrapped pattern in `if let` /
        // `while let`: `if let (Some(x)) = opt { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: parse_primary cannot
        // start an expression at token kind 11`. Sister to v0.7.54
        // paren-wrapped variant-payload halt.
```

### `compiler/s1/parse.nr:2901`

```
    // v0.7.27 (defensive halt — Rust ref-pattern in for-loop binding
    // position: `for &x in &v { ... }`, `for &mut x in &mut v { ... }`).
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse error:
    // expected token 57 (`in`), got identifier` because parse_for_stmt
    // tried to read `&` as the binding name. Workaround: drop the `&`
    // — Nucleor's i64-everywhere ABI passes everything by value, so
    // `for x in &v` already binds the same observable shape.
```

### `compiler/s1/parse.nr:2981`

```
    // v0.7.77 (defensive halt — Rust 1.59+ destructuring assignment
    // `(a, b) = (1, 2);` / `[a, b] = [1, 2];` to already-bound
    // bindings). Pre-fix `(a, b) = (1, 2);` parsed `(a, b)` as a
    // parenthesized tuple expression, then expected `;` or an op
    // and got `=`. The current parser silently treated this as a
    // tail expression with no-op semantics — `a` and `b` remained
    // their previous values, producing a SILENT MISCOMPUTE (probe
    // verified: rc=0 instead of expected 1020). Detect by scanning
    // ahead for `)` then `=` immediately after a `(ident, ident, ...)`
    // shape and halt with a workaround pointer (assign each binding
    // separately).
```

### `compiler/s1/parse.nr:3017`

```
        // v0.7.77 (defensive halt — Rust unstable `yield <expr>;`,
        // used in nightly generators / coroutines). Pre-fix `yield`
        // lexed as a regular ident and was parsed as a fn call to
        // `yield(<expr>)`, surfacing as wrong-class
        // `error[TYP-005]: undefined function 'yield()'` at clang
        // link. Halt cleanly when `yield` appears at statement
        // start. Sister to v0.7.71 `async fn` halt — same nightly /
        // unstable surface, same silent-strip-then-late-fail audit
        // class. Token 1 (ident) lookahead, restricted by pkv name
        // so user fns named `yield` keep working only via raw-ident
        // (which is itself halted at v0.7.75).
```

### `compiler/s1/parse.nr:3094`

```
    // v0.7.47 (defensive halt — Rust local type alias `type Foo = Bar;`
    // inside a fn body). Pre-fix this surfaced as wrong-class
    // `error[NR020]: parse_primary cannot start an expression at token
    // kind 74` because parse_stmt fell through to parse_expr which has
    // no `type` branch. Nucleor supports module-level type aliases fine
    // (parse_program dispatches kind-74 to parse_type_alias_decl) but
    // the fn-body statement parser never saw the keyword.
    // Workaround: hoist the type alias to module scope (just outside
    // any fn body) — module-level `type Foo = Bar;` works cleanly.
```

### `compiler/s1/parse.nr:3109`

```
    // v0.7.55 (defensive halt — Rust local `const`/`static` inside a fn
    // body). Pre-fix `fn h() { const N: i64 = 5; ... }` surfaced as
    // wrong-class `error[NR020]: parse_primary cannot start an
    // expression at token kind 73` (or token 42 for static — different
    // tokenization paths). Module-level const/static work — Nucleor's
    // const ships, static is forward-roadmap (see v0.6.21 halt). Sister
    // to v0.7.47 local-type-alias halt.
```

### `compiler/s1/parse.nr:3122`

```
    // v0.7.56 (defensive halt — Rust local `static` inside a fn body).
    // The lexer emits `static` as a plain identifier (token 1), so this
    // catches the form `static NAME: TYPE = ...;` at stmt-start by
    // checking ident "static" followed by another ident + `:`.
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse_primary
    // cannot start an expression at token kind 42` (the `:` after the
    // name) because parse_expr's identifier branch consumed `static`,
    // then saw `NAME` and tried to keep parsing. Sister to v0.7.55
    // local-const halt and v0.6.21 module-scope static halt.
```

### `compiler/s1/parse.nr:3137`

```
    // v0.7.59 (defensive halt — Rust local fn declaration inside a fn
    // body / match arm block: `fn outer() { fn inner() { ... } ... }`).
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse_primary
    // cannot start an expression at token kind 10` because parse_stmt
    // had no `fn` branch and parse_expr also has no `fn` branch.
    // Rust supports nested fn declarations (no closure-capture; just
    // a name-scoped fn), but Nucleor's parser dispatches `fn` only at
    // module scope. Sister to v0.7.47/55/56 (local-type-alias / -const
    // / -static halts).
```

### `compiler/s1/parse.nr:3260`

```
        // v0.7.39 (defensive halt — Rust pattern-destructure in fn
        // parameter: `fn h((a, b): (i64, i64))`, `fn h(P { x, y }: P)`).
        // Pre-fix this surfaced as wrong-class `error[NR020]: expected
        // ':', got identifier` because the param parser tried to read
        // `(` (token 50) or `{` (52) as the binding name. Workaround:
        // bind a single name and destructure inside the body — sister
        // to v0.6.59 tuple-destructure-in-for-head halt.
```

### `compiler/s1/parse.nr:3272`

```
        // v0.7.75 (defensive halt — Rust `fn f(mut x: T)` mut-binding
        // in fn parameter). Pre-fix the `mut` ident landed in the
        // pn-binding slot and the `x` that followed pushed `:` to a
        // position where `parse_type` expected one — surfacing as
        // wrong-class `error[NR020]: expected ':', got identifier`.
        // The shape is common in adopter Rust code (rebinding the
        // parameter for in-place mutation in the body); Nucleor's
        // existing `let mut x: T = arg;` body-form is the canonical
        // workaround. Caught BEFORE the binding name is read so the
        // diag is precise rather than the generic NR020.
```

### `compiler/s1/parse.nr:3288`

```
        // v0.7.49 (defensive halt — typeless default-arg form
        // `fn h(x: i64, y = 5)`). Sister to v0.7.38 (typed
        // default-arg `n: i64 = 1`); this catches the no-type variant
        // before the colon expector fires. Pre-fix this surfaced as
        // wrong-class `error[NR020]: expected ':', got '='`.
```

### `compiler/s1/parse.nr:3359`

```
        // v0.7.38 (defensive halt — Rust default-arg-style fn parameter
        // `fn f(n: i64 = 1)`). Rust does NOT support default fn args
        // (Python/C++ feature), but C++/Python adopters often try this
        // syntax. Pre-fix surfaced as wrong-class `error[NR020]: parse
        // error: expected ',', got '='` because the next-iter expect_tok
        // for the param-list comma got `=` instead. Halt cleanly with
        // an overload/explicit-args workaround pointer.
```

### `compiler/s1/parse.nr:3384`

```
    // v0.7.52 (defensive halt — Rust forward declaration `fn h() -> i64;`
    // at module scope without a body). Pre-fix this surfaced as wrong-
    // class `error[NR020]: expected '{', got ';'`. In Rust, a body-less
    // fn signature is valid only inside `trait { ... }` (where Nucleor
    // already supports it — `trait T { fn m(self) -> i64; }` works) or
    // inside `extern "C" { ... }` (which is also forward-roadmap, see
    // v0.7.26 halt). At module scope, the user almost always wants
    // either a body or an `extern fn` declaration.
```

### `compiler/s1/parse.nr:3415`

```
        // v0.7.47 (defensive halt — Rust C-FFI variadic syntax: `extern
        // "C" fn printf(fmt: str, ...);`). The lexer emits `...` as
        // token 58 (`..`) followed by token 45 (`.`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: expected ':', got
        // token 45` because the param parser tried to read `.` as the
        // binding name. Halt cleanly with a wrapper-fn workaround
        // pointer.
```

### `compiler/s1/parse.nr:3509`

```
    // v0.6.73 RFC V1.1
    //  tuple-struct positional-
    // field synthesis. Pre-fix `struct P(T1, T2);` halted at parse with
    // a workaround diagnostic. Now: parse the paren-form, synthesize
    // field names `__0`, `__1`, ..., `__N` (matching Rust's positional
    // accessor naming where `p.0` resolves to the 0-th field). Struct
    // value retains kind-33 — downstream type-check + lowering use the
    // synthetic field names; constructor `P(a, b)` and field access
    // `p.0` / `p.1` are wired in subsequent commits.
    // Tuple-struct shape detection: structs with all field names
    // matching `__<digit>+` are tuple-style (used by constructor
    // detection + `.<digit>` access lowering downstream).
```

### `compiler/s1/parse.nr:3621`

```
    // v0.5 (v0.4.237) — capture struct-name token byte offset for
    // span-aware diagnostics (TYP-008/012/013/017 struct-init field
    // diags). Each field-init nid (kind 35) also gets the field-
    // name token's offset so per-field diags caret to the offending
    // field, not the function name.
```

### `compiler/s1/parse.nr:3792`

```
        // v0.7.62 (defensive halt — qualified path supertrait:
        // `trait Sub: super::Iterator { ... }`,
        // `trait Sub: std::fmt::Display { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: expected '{', got
        // token 46` because the supertrait parser reads only a bare
        // ident, leaving `::Path` unconsumed. Halt cleanly with a
        // drop-the-namespace workaround.
```

### `compiler/s1/parse.nr:3951`

```
        // v0.7.44 (defensive halt — impl-target type with lifetime in
        // generic args: `impl<'a> R<'a> { ... }`). The parse_type call
        // below doesn't handle lifetime tokens (98) in type-arg position;
        // pre-fix this surfaced as wrong-class `error[NR020]: expected
        // '{', got token 98`. Detect a lifetime inside the angle-bracket
        // group and halt cleanly with a drop-the-lifetime workaround.
```

### `compiler/s1/parse.nr:4031`

```
                    // v0.6.93 RFC V1.7-sister: substitute `Self` in
                    // the EXPLICIT param type form (`self: &Self`,
                    // `other: &Self`, etc.) with the impl's concrete
                    // type_name. Pre-fix only the shorthand `&self` /
                    // `self` form got Self → type_name; explicit
                    // `self: &Self` left "Self" in the param type
                    // string, so downstream `self.field` field access
                    // failed to resolve (`expr_struct_type` couldn't
                    // map "Self" to a known struct).
```

### `compiler/s1/parse.nr:4286`

```
            // v0.7.26 (defensive halt — Rust FFI extern block form
            // `extern "C" { fn cfn(x: i64) -> i64; ... }`). Pre-fix
            // surfaced as wrong-class `error[NR020]: expected '{', got
            // ';'` because the parser only knows the single-line form
            // `extern "C" fn name(...);` (one decl, no surrounding
            // block). Halt cleanly with a workaround pointing to the
            // bare-decl form.
```

### `compiler/s1/parse.nr:4378`

```
            // v0.7.71 (defensive halt — Rust `async fn name() -> T { ... }`).
            // Pre-fix the `async` ident was silently skipped at the
            // module-item dispatch and the fn parsed normally as a
            // sync fn. Adopters writing `let r = fetch();` got the
            // value directly (rc=42 in our probe), expecting a
            // `Future<Output = i64>` to `.await`. Silent acceptance
            // is wrong-class — the Future protocol is missing entirely
            // (no executor, no `.await`, no state-machine lowering).
            // Halt cleanly at the decl. Sister to v0.6.53 `unsafe fn`
            // halt (same shape, same dispatch lookahead).
```

### `compiler/s1/parse.nr:4415`

```
            // v0.7.73 (defensive halt — `extern crate <name>;`).
            // Pre-fix this was silently dropped at module-item
            // dispatch — the `extern` ident matched no branch, the
            // dispatcher fell through, and the trailing tokens
            // (`crate`, `<name>`, `;`) were skipped. Adopters
            // translating Rust 2015-style or workspace-style code
            // got NO signal that the dependency wasn't actually
            // pulled in; later `crate_name::path` use sites failed
            // opaquely. Halt cleanly. Sister to v0.7.71 `async fn`
            // and v0.6.53 `unsafe fn` halts (same module-item
            // silent-strip class).
```

### `compiler/s1/parse.nr:4430`

```
            // v0.7.73 (defensive halt — `macro_rules! name { ... }`).
            // corrected token check from 97 (`?`) to 38 (`!`).
            // Pre-v0.8.28 the check used token kind 97 (which is `?`,
            // not `!`), so the halt NEVER fired — the `macro_rules! name
            // { ... }` block was silently swallowed at module scope as
            // before v0.7.73. v0.8.28 fixes the token constant so the
            // halt properly fires on `macro_rules` + `!` (token 38).
```

## `compiler/ts/builtins.nr`

### `compiler/ts/builtins.nr:71`

```
    // v0.4.92 mirror.
```

### `compiler/ts/builtins.nr:376`

```
    // v0.3.236 Phase A — sym-aux side hashmap helpers
```

### `compiler/ts/builtins.nr:381`

```
    // v0.4.10 Phase A — compile-source side table
```

### `compiler/ts/builtins.nr:827`

```
    // v0.3.0 (T3.1): synced from s1.
```

## `compiler/ts/check_taint.nr`

### `compiler/ts/check_taint.nr:1417`

```
    // v0.4.2 RFC-NRT-004 §G (sync from nucleor_s1_compiler.nr:
    // match_bind_payloads_per_idx, lines 10498-10540): per-binding
    // payload-type lookup. Each binding in the pipe-separated list
    // gets its own __type_<name> based on the variant's payload-
    // type table populated by enum_populate_sym. Without this, a
    // struct-typed enum payload binding (Outcome::Err(e) where e:
    // ErrInfo) leaves the binding's type unknown; the subsequent
    // e.message lookup in the lowering returns -1 (the field-not-
    // resolved sentinel) which clang rejects as an undefined SSA
    // register %r.-1.
```

### `compiler/ts/check_taint.nr:1453`

```
                // v0.4.4 SPEC-1.5 wishlist: Option<str> / Result<*, str>
                // hardcoded defaults (sync from s1's match_bind_payloads_per_idx).
```

## `compiler/ts/cli.nr`

### `compiler/ts/cli.nr:1818`

```
    // v0.2.339 (T1.7): switched from `mkdir target 2>NUL` shell-out to
    // the cross-platform fs_create_dir_all builtin so `nuc test` works
    // on Linux + macOS without cmd.exe.
```

### `compiler/ts/cli.nr:2279`

```
    // v0.2.339 (T1.7): replaced `dir /b examples\*.nr` shell-out with
    // fs_list_dir + a .nr extension filter. The (unused-after-this)
    // `tag` parameter is kept for API compatibility; the temp listing
    // file path is no longer needed since we never write to disk.
```

### `compiler/ts/cli.nr:3050`

```
    // v0.2.339 (T1.7): replaced `dir /b /s` shell-out with the
    // platform-portable walk_dir_recursive_native helper. The output
    // ordering matches the prior cmd.exe `/on` (alphabetical), so
    // pre-existing checksums in Nucleor.lock files remain stable.
```

### `compiler/ts/cli.nr:3145`

```
// v0.8.149 RFC-0061 Tier 2 (V1.17b) — render the lock-graph in
// one of four formats for `nuc deps graph`. Reuses the existing
// lock_build_graph_recursive output. Pure additive; doesn't
// touch the lockfile renderer.
```

### `compiler/ts/cli.nr:3424`

```
    // v0.2.339 (T1.7): replaced the prior `dir /b` shell-out with the
    // cross-platform __nucleor_fs_list_dir builtin so this works on
    // both Windows and POSIX without needing cmd.exe. dirs_only
    // post-filters via fs_is_dir on the joined path.
```

### `compiler/ts/cli.nr:3448`

```
    // v0.2.339 (T1.7): cross-platform replacement for `dir /b /s /a-d /on`.
    // Returns an ordered Vec<str> of every regular file's full path under
    // root_dir, walked via fs_list_dir + fs_is_dir. Used by package
    // checksum + publish — both call sites used to shell out to cmd.exe
    // which broke `nuc lock` and `nuc publish` on Linux/macOS.
```

### `compiler/ts/cli.nr:3607`

```
    // v0.2.339 (T1.7): replaced `dir /b /s` walk + `mkdir`/`copy /Y`
    // shell-outs with the cross-platform fs_* runtime builtins.
    // walk_dir_recursive_native + fs_create_dir_all + fs_copy_file work
    // identically on Windows and POSIX.
```

### `compiler/ts/cli.nr:3895`

```
    // v0.8.89 PKG-3 Phase 2 — caret resolution.
    // `^X.Y.Z` matches the highest version in the registry that
    // satisfies `>=X.Y.Z, <next_compatible(X.Y.Z)` per semver.org:
    //   X > 0  : upper exclusive = (X+1).0.0
    //   X == 0, Y > 0 : upper exclusive = 0.(Y+1).0
    //   X == 0, Y == 0 : upper exclusive = 0.0.(Z+1)  (effectively pinned)
```

### `compiler/ts/cli.nr:3929`

```
    // v0.8.90 PKG-3 Phase 2 — tilde resolution.
    // `~X.Y.Z` matches `[X.Y.Z, X.(Y+1).0)` — patch-level changes
    // permitted, minor pinned. Always pins major + minor.
```

### `compiler/ts/cli.nr:3950`

```
    // v0.8.91 PKG-3 Phase 3 — wildcard resolution.
    // `*`        same as `latest`
    // `X.*`      [X.0.0, (X+1).0.0)
    // `X.Y.*`    [X.Y.0, X.(Y+1).0)
```

### `compiler/ts/cli.nr:3998`

```
    // v0.8.93 PKG-3 Phase 4 sister — compound multi-token range.
    //   >=X.Y.Z <=A.B.C    AND of two comparisons
    //   >X.Y.Z <A.B.C      strict variants
    // Splits on whitespace, parses each token as a single comparison,
    // ANDs the bounds, walks versions desc, returns first match.
```

### `compiler/ts/cli.nr:4067`

```
    // v0.8.92 PKG-3 Phase 4 — single-token comparison resolution.
    //   >=X.Y.Z   highest version with score >= base_score
    //   >X.Y.Z    highest version with score > base_score
    //   <=X.Y.Z   highest version with score <= base_score
    //   <X.Y.Z    highest version with score < base_score
```

### `compiler/ts/cli.nr:6918`

```
        // v0.2.339 (T1.7): switched from `mkdir name\src` shell-out
        // (Windows-only path separator) to fs_create_dir_all which
        // accepts forward slashes on every platform.
```

## `compiler/ts/emit.nr`

### `compiler/ts/emit.nr:175`

```
    // v0.4.92 mirror.
```

### `compiler/ts/emit.nr:369`

```
    // v0.3.236 Phase A — sym-aux side hashmap helpers
```

### `compiler/ts/emit.nr:377`

```
    // v0.4.10 Phase A — compile-source side table
```

## `compiler/ts/modules.nr`

### `compiler/ts/modules.nr:1147`

```
    // v0.3.0 (T3.1): #[deadline = N] runtime-check rewrite (synced).
```

