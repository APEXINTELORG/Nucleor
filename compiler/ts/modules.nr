// =====================================================
// MODULE SYSTEM (imports)
// =====================================================
fn resolve_import_path(base_dir: str, raw_path: str) -> str {
    if path_is_absolute(raw_path) == 1 { return sanitize(raw_path); };
    let mut search_dir: str = base_dir;
    while 1 == 1 {
        let candidate: str = sanitize(str_concat(search_dir, raw_path));
        if path_exists(candidate) == 1 { return candidate; };
        if str_len(search_dir) == 0 { break; };
        search_dir = parent_dir(search_dir);
    };
    let from_cwd: str = sanitize(raw_path);
    if path_exists(from_cwd) == 1 { return from_cwd; };
    return sanitize(str_concat(base_dir, raw_path));
}

// V2: Parallel import resolution — collect all imports first, then resolve
// independent ones in parallel via threading. Falls back to sequential if
// only one import or threading unavailable.
fn collect_import_paths(src: str, base_dir: str) -> Vec<i32> {
    let mut paths: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        let mut prefix_len: i64 = 0;
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") { prefix_len = 4; };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            if qp < eol && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < eol && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let imp_path: str = resolve_import_path(base_dir, str_substring(src, ps, pe));
                paths.push(imp_path);
            };
        };
        p = eol + 1;
    };
    return paths;
}

fn resolve_source_with_records(src: str, base_dir: str, imported: Vec<i32>, module_records: Vec<i32>) -> str {
    // T1.5a (v0.2.340): tools-suite resolver brought to parity with the
    // s1 compiler resolver. Previously this only handled
    // `import "path"` literals; now it also handles
    // `mod foo;` (file-rooted desugaring) and
    // `mod foo { ... }` (inline block-form, brace-balanced with
    // string and line-comment awareness). This closes the divergence
    // gap that broke `nuc test` whenever a test fixture used
    // mod-keyword imports.
    let mut result: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        let mut prefix_len: i64 = 0;
        let mut is_mod_decl: i64 = 0;
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") { prefix_len = 4; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "mod ") == 1 {
            let mut sp: i64 = lp + 4;
            while sp < eol && str_char_at(src, sp) == 32 { sp = sp + 1; };
            let mut np: i64 = sp;
            while np < eol && (is_alnum(str_char_at(src, np)) == 1) { np = np + 1; };
            let mut tp: i64 = np;
            while tp < eol && str_char_at(src, tp) == 32 { tp = tp + 1; };
            if np > sp && tp < eol && str_char_at(src, tp) == 59 {
                is_mod_decl = 1;
                prefix_len = 4;
            };
            if np > sp && tp < eol && str_char_at(src, tp) == 123 {
                // Block-form `mod foo { ... }` — brace-balanced inline.
                let body_start: i64 = tp + 1;
                let mut depth: i64 = 1;
                let mut q: i64 = body_start;
                let mut in_dquote: i64 = 0;
                let mut in_squote: i64 = 0;
                let mut in_line_comment: i64 = 0;
                while q < slen && depth > 0 {
                    let ch: i64 = str_char_at(src, q);
                    if in_line_comment == 1 {
                        if ch == 10 { in_line_comment = 0; };
                    } else if in_dquote == 1 {
                        if ch == 92 && q + 1 < slen { q = q + 1; }
                        else if ch == 34 { in_dquote = 0; };
                    } else if in_squote == 1 {
                        if ch == 92 && q + 1 < slen { q = q + 1; }
                        else if ch == 39 { in_squote = 0; };
                    } else if ch == 47 && q + 1 < slen && str_char_at(src, q + 1) == 47 {
                        in_line_comment = 1;
                        q = q + 1;
                    } else if ch == 34 {
                        in_dquote = 1;
                    } else if ch == 39 {
                        in_squote = 1;
                    } else if ch == 123 {
                        depth = depth + 1;
                    } else if ch == 125 {
                        depth = depth - 1;
                    };
                    q = q + 1;
                };
                if depth == 0 {
                    let body: str = str_substring(src, body_start, q - 1);
                    sb_append(result, "// mod ");
                    sb_append(result, str_substring(src, sp, np));
                    sb_append(result, " { ... } (inlined block-form)\n");
                    sb_append(result, resolve_source_with_records(body, base_dir, imported, module_records));
                    sb_append(result, "\n");
                    p = q;
                    continue;
                };
            };
        };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            let mut rust_path: str = "";
            if is_mod_decl == 1 {
                let mut np: i64 = qp;
                while np < eol && is_alnum(str_char_at(src, np)) == 1 { np = np + 1; };
                if np > qp {
                    rust_path = str_concat(str_substring(src, qp, np), ".nr");
                };
            };
            if str_len(rust_path) > 0 {
                let path: str = resolve_import_path(base_dir, rust_path);
                let mut already: i64 = 0;
                let mut ii: i64 = 0;
                while ii < vec_len(imported) {
                    if str_eq(vec_get(imported, ii), path) { already = 1; };
                    ii = ii + 1;
                };
                if already == 0 {
                    imported.push(path);
                    let isrc: str = file_read_string(path);
                    if str_len(isrc) > 0 {
                        let isrc_used: str = priv_apply_if_opted_in(isrc, path);
                        module_record_add(module_records, path, isrc_used);
                        let idir: str = extract_dir(path);
                        // Mirror of s1/modules.nr: free the recursive call's
                        // returned string after append to avoid the per-
                        // iteration leak that bloats cold compile memory
                        // when many sibling imports are present.
                        let resolved_imp: str = resolve_source_with_records(isrc_used, idir, imported, module_records);
                        sb_append(result, resolved_imp);
                        str_free(resolved_imp);
                        sb_append(result, "\n");
                    } else {
                        sb_append(result, str_concat("// ERROR: cannot read mod path ", path));
                        sb_append(result, "\n");
                    };
                };
            } else if qp < eol && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < eol && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let path: str = resolve_import_path(base_dir, str_substring(src, ps, pe));
                let mut already: i64 = 0;
                let mut ii: i64 = 0;
                while ii < vec_len(imported) {
                    if str_eq(vec_get(imported, ii), path) { already = 1; };
                    ii = ii + 1;
                };
                if already == 0 {
                    imported.push(path);
                    let isrc: str = file_read_string(path);
                    if str_len(isrc) > 0 {
                        let isrc_used: str = priv_apply_if_opted_in(isrc, path);
                        module_record_add(module_records, path, isrc_used);
                        let idir: str = extract_dir(path);
                        // Mirror of the mod-arm above — free recursive return.
                        let resolved_imp: str = resolve_source_with_records(isrc_used, idir, imported, module_records);
                        sb_append(result, resolved_imp);
                        str_free(resolved_imp);
                        sb_append(result, "\n");
                    } else {
                        sb_append(result, str_concat("// ERROR: cannot read import ", path));
                        sb_append(result, "\n");
                    };
                };
            } else {
                sb_append(result, str_substring(src, p, eol));
                sb_append(result, "\n");
            };
        } else if line_len >= 2 && str_char_at(src, lp) == 35 && str_char_at(src, lp + 1) != 91 {
            // Skip # directives (#link, #cfile). Preserve `#[...]` outer
            // attributes so the diag-filter sees them.
            sb_append(result, "\n");
        } else {
            sb_append(result, str_substring(src, p, eol));
            sb_append(result, "\n");
        };
        p = eol + 1;
    };
    return sb_to_str(result);
}

fn ascii_upper(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c >= 97 && c <= 122 {
            sb_append(sb, str_substring("ABCDEFGHIJKLMNOPQRSTUVWXYZ", c - 97, c - 96));
        } else {
            sb_append(sb, str_substring(s, i, i + 1));
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn explain_error_title(code: str) -> str {
    if str_eq(code, "NR001") { return "Source Input Failure"; };
    if str_eq(code, "NR005") { return "Module Resolution Failure"; };
    if str_eq(code, "NR010") { return "Lexical Syntax Failure"; };
    if str_eq(code, "NR020") { return "Parser Failure"; };
    if str_eq(code, "PARSE-LET-SEMI") { return "Missing semicolon after let statement"; };
    if str_eq(code, "NR030") { return "Semantic Type Failure"; };
    if str_eq(code, "NR031") { return "Borrow Safety Failure (legacy — superseded by RFC-0062 G-series at v1.0)"; };
    if str_eq(code, "NR032") { return "Effect or Policy Failure"; };
    if str_eq(code, "NR033") { return "Taint Safety Failure"; };
    if str_eq(code, "NR034") { return "Send/Sync Safety Failure"; };
    if str_eq(code, "NR035") { return "Explicit enum discriminants not yet supported"; };
    if str_eq(code, "NR036") { return "Self-recursive struct without Box / & indirection (Rust E0072)"; };
    if str_eq(code, "NR040") { return "IR Lowering Failure"; };
    if str_eq(code, "NR050") { return "Backend Code Generation Failure"; };
    if str_eq(code, "NR051") { return "WASM Backend Unavailable"; };
    if str_eq(code, "NR070") { return "Manifest or Lockfile Failure"; };
    if str_eq(code, "NR090") { return "Compiler Pipeline Invariant Failure"; };
    // RFC-0001 RT attributes
    if str_eq(code, "RT-001") { return "Allocation in #[no_alloc] function"; };
    if str_eq(code, "RT-002") { return "Possibly-panicking expression in #[no_panic] function"; };
    if str_eq(code, "RT-003") { return "Dynamic dispatch in #[no_dyn] function"; };
    if str_eq(code, "RT-004") { return "Heuristic deadline estimate exceeds declared #[deadline] (NOT certified WCET)"; };
    if str_eq(code, "RT-005") { return "FFI call in RT function without #[ffi_no_*] annotation"; };
    if str_eq(code, "RT-006") { return "RT attribute on async fn"; };
    if str_eq(code, "ASYNC-001") { return "`async` keyword on fn is silently stripped (v0.5 has no Future/.await; use async_spawn + async_await for threading)"; };
    if str_eq(code, "RT-007") { return "Deadline annotation without no_alloc or no_panic"; };
    if str_eq(code, "RT-008") { return "Recursive call in #[deadline] function without #[max_depth]"; };
    if str_eq(code, "RT-009") { return "Implicit panic-capable expression in #[no_panic] function"; };
    // RFC-0020 DIAG series — minted v0.3.36 (DIAG-001 only).
    if str_eq(code, "DIAG-001") { return "Unknown diagnostic code in #[allow]/#[deny] attribute"; };
    // RFC-0002 allocator types
    if str_eq(code, "ALLOC-001") { return "Allocated value escapes its allocator"; };
    if str_eq(code, "ALLOC-002") { return "Allocator type mismatch"; };
    if str_eq(code, "ALLOC-003") { return "Allocation forbidden by #[no_alloc]"; };
    // RFC-0003 typed frames
    if str_eq(code, "FRAME-001") { return "Cannot add values in different coordinate frames"; };
    if str_eq(code, "FRAME-002") { return "Transform composition mismatch"; };
    if str_eq(code, "FRAME-003") { return "Cannot apply transform to value in incompatible frame"; };
    // OWN series — borrow-checker (expansion of NR031)
    if str_eq(code, "OWN-001") { return "Use of moved variable"; };
    if str_eq(code, "OWN-002") { return "Cannot borrow moved value"; };
    if str_eq(code, "OWN-003") { return "Cannot move value that is borrowed"; };
    if str_eq(code, "OWN-004") { return "Cannot mutably borrow value already borrowed"; };
    if str_eq(code, "OWN-005") { return "Cannot shared-borrow mutably-borrowed value"; };
    if str_eq(code, "OWN-006") { return "Cannot assign through shared reference"; };
    if str_eq(code, "OWN-007") { return "Cannot assign to borrowed location"; };
    if str_eq(code, "OWN-008") { return "Cannot assign to immutable binding"; };
    if str_eq(code, "OWN-009") { return "Cannot return reference to local value"; };
    if str_eq(code, "OWN-010") { return "Cannot bind a reference that escapes an inner block"; };
    if str_eq(code, "OWN-011") { return "Cannot mutably borrow immutable value"; };
    if str_eq(code, "OWN-012") { return "Cannot destroy arena with live references"; };
    if str_eq(code, "OWN-013") { return "Spawn block captures non-Send DeviceBuffer value"; };
    if str_eq(code, "RACE-001") { return "Non-Sendable value crosses a spawned boundary"; };
    if str_eq(code, "RACE-002") { return "Actor method called without await"; };
    if str_eq(code, "RACE-003") { return "Actor internal state escapes isolation"; };
    if str_eq(code, "RACE-004") { return "Shared mutable state without Mutex or actor"; };
    if str_eq(code, "RACE-005") { return "&mut value crosses a thread boundary"; };
    if str_eq(code, "RACE-006") { return "Reentrant actor lock violation"; };
    if str_eq(code, "RACE-007") { return "Deadline composition under actor await is invalid"; };
    if str_eq(code, "RACE-008") { return "#[not_sendable] type used where Sendable is required"; };
    if str_eq(code, "RACE-009") { return "Reserved Sendable/actor diagnostic"; };
    if str_eq(code, "RACE-010") { return "Reserved Sendable/actor diagnostic"; };
    // GOV series — governance policies
    if str_eq(code, "GOV-001") { return "policy(require_authored) requires authored annotations"; };
    if str_eq(code, "GOV-002") { return "policy(no_unsafe) forbids unsafe blocks"; };
    // TNT series — taint analysis (expansion of NR033)
    if str_eq(code, "TNT-001") { return "Tainted data passed to sensitive sink"; };
    // TYP series — type checker (expansion of NR030)
    if str_eq(code, "TYP-001") { return "Non-exhaustive match (LEGACY — unified under MATCH-001 in v0.5.18; no longer emitted)"; };
    if str_eq(code, "TYP-002") { return "Boolean values cannot be used in arithmetic"; };
    if str_eq(code, "TYP-003") { return "Unit operands for addition/subtraction must match"; };
    if str_eq(code, "TYP-004") { return "Cannot dereference a non-reference value"; };
    if str_eq(code, "TYP-005") { return "Wrong number of arguments"; };
    if str_eq(code, "TYP-006") { return "Argument type mismatch in call"; };
    if str_eq(code, "TYP-007") { return "Bare numeric literal cannot initialize a unit value"; };
    if str_eq(code, "TYP-008") { return "Type mismatch for binding"; };
    if str_eq(code, "TYP-009") { return "Assignment type mismatch"; };
    if str_eq(code, "TYP-010") { return "Return type mismatch"; };
    if str_eq(code, "TYP-011") { return "`str + str` not supported (would silently segfault)"; };
    if str_eq(code, "TYP-012") { return "Missing field(s) in struct initialization (would silently default to 0/empty)"; };
    if str_eq(code, "TYP-013") { return "Unknown field in struct initialization (would silently drop the extra field)"; };
    if str_eq(code, "TYP-026") { return "Invalid or unproven `as char`, or non-void function reaches the end without returning a value"; };
    if str_eq(code, "TYP-027") { return "Type inference failed"; };
    if str_eq(code, "TYP-044") { return "Implicit integer width conversion in binding"; };
    if str_eq(code, "FMT-002") { return "Type does not implement Display for bare `{}` formatting"; };
    if str_eq(code, "FMT-003") { return "Format string has more arguments than `{}` placeholders (extras would be silently dropped)"; };
    if str_eq(code, "TRAIT-001") { return "Missing From conversion for `?` error propagation"; };
    // RFC-0015 numeric types
    if str_eq(code, "NUM-001") { return "Mixed-width arithmetic without cast"; };
    if str_eq(code, "NUM-002") { return "Numeric literal out of range for declared type"; };
    if str_eq(code, "NUM-003") { return "Cast loses precision (warning)"; };
    if str_eq(code, "NUM-004") { return "f8/f16/bf16 op without hardware support"; };
    if str_eq(code, "NUM-005") { return "usize/isize mixed with explicit-width type"; };
    // T1.1 Phase 10 (v0.2.319): expanded NUM namespace for the maximalist
    // numerics refactor. Each entry has a matching explanation + reasoning
    // body in the longer-form sections below.
    if str_eq(code, "NUM-006") { return "Signed/unsigned arithmetic without explicit cast"; };
    if str_eq(code, "NUM-007") { return "Float→int cast saturates to type bounds"; };
    if str_eq(code, "NUM-008") { return "Shift amount equals or exceeds operand width (UB-prone)"; };
    if str_eq(code, "NUM-009") { return "@const_fn body contains an effectful operation"; };
    if str_eq(code, "PERF-1") { return "Invalid --tier value (router-level)"; };
    if str_eq(code, "PERF-2") { return "@hot function contains a perf-violation (alloc / I/O)"; };
    if str_eq(code, "PERF-3") { return "Heap allocation inside a while/loop block (HeapInLoop)"; };
    if str_eq(code, "NUM-009") { return "Division or remainder by literal zero"; };
    if str_eq(code, "NUM-010") { return "Implicit narrowing of f64 literal to f32 may lose precision"; };
    if str_eq(code, "NUM-011") { return "Overflow attribute conflicts with operation kind"; };
    if str_eq(code, "NUM-012") { return "Cast from pointer to non-pointer-width integer"; };
    if str_eq(code, "NUM-013") { return "Vec<T> requires sized element type"; };
    if str_eq(code, "NUM-014") { return "sizeof_struct on unknown / generic struct"; };
    if str_eq(code, "NUM-015") { return "extern fn signature uses non-ABI-stable type"; };
    if str_eq(code, "NUM-016") { return "Comparison between signed and unsigned of equal width"; };
    if str_eq(code, "NUM-017") { return "Bitwise op on signed type may have surprising sign-extension"; };
    if str_eq(code, "NUM-018") { return "Float literal in integer context"; };
    if str_eq(code, "NUM-019") { return "Negative literal assigned to unsigned type"; };
    if str_eq(code, "NUM-020") { return "Mixed-width comparison without explicit cast"; };
    if str_eq(code, "NUM-021") { return "Integer literal or constant expression overflows at compile time"; };
    if str_eq(code, "NUM-022") { return "Integer vs float in arithmetic/comparison binop"; };
    if str_eq(code, "NUM-023") { return "Float / bool `as`-cast to `str` rejected"; };
    if str_eq(code, "NUM-024") { return "Cross-width call-site narrowing audit (opt-in via NUCLEOR_AUDIT_NUM024=1)"; };
    // RFC-0016 match
    if str_eq(code, "MATCH-001") { return "Non-exhaustive match"; };
    if str_eq(code, "MATCH-002") { return "Unreachable match arm"; };
    if str_eq(code, "MATCH-003") { return "Type mismatch between match arms"; };
    if str_eq(code, "MATCH-004") { return "? in a function not returning Result/Option"; };
    if str_eq(code, "MATCH-005") { return "? error type doesn't Into the function's error type"; };
    if str_eq(code, "MATCH-006") { return "unwrap() in #[no_panic] function"; };
    if str_eq(code, "MATCH-007") { return "Range pattern bounds in wrong order"; };
    if str_eq(code, "MATCH-008") { return "Or-pattern arms have different bindings"; };
    if str_eq(code, "MATCH-009") { return "Slice pattern overlaps"; };
    if str_eq(code, "MATCH-010") { return "@-binding name collides with outer scope"; };
    if str_eq(code, "MATCH-011") { return "Match arms produce values of incompatible types"; };
    if str_eq(code, "MATCH-012") { return "Struct pattern field after `:` must be an identifier (literal field-equality patterns deferred)"; };
    if str_eq(code, "MATCH-013") { return "Float scrutinee or float-literal pattern in `match` is not supported"; };
    if str_eq(code, "MATCH-014") { return "Negative literal bounds in range patterns are not yet supported"; };
    if str_eq(code, "MATCH-015") { return "Negative literal pattern in match arm not yet supported"; };
    if str_eq(code, "MATCH-016") { return "Cross-enum pattern: scrutinee enum type does not match constructor's enum type"; };
    // RFC-0004 assume!
    if str_eq(code, "ASSUME-001") { return "predicate not in analyzer's vocabulary"; };
    if str_eq(code, "ASSUME-002") { return "assume_unchecked! used without justification"; };
    if str_eq(code, "ASSUME-003") { return "assume! predicate is a tautology"; };
    if str_eq(code, "ASSUME-004") { return "assume! contradicts type-system fact"; };
    if str_eq(code, "ASSUME-005") { return "cert-profile: assume! not proven"; };
    // RFC-0005 units
    if str_eq(code, "UNIT-001") { return "Add/sub mismatched dimensions"; };
    if str_eq(code, "UNIT-002") { return "Implicit unit conversion attempted"; };
    if str_eq(code, "UNIT-003") { return "Power expression is non-integer at compile time"; };
    if str_eq(code, "UNIT-004") { return "Unknown unit alias"; };
    if str_eq(code, "UNIT-005") { return "Dimensional inconsistency in @law annotation"; };
    // RFC-0006 contracts
    if str_eq(code, "CONTRACT-001") { return "Require violation"; };
    if str_eq(code, "CONTRACT-002") { return "Ensure violation"; };
    if str_eq(code, "CONTRACT-003") { return "Invariant violation"; };
    if str_eq(code, "CONTRACT-004") { return "Trait impl weakens precondition (Liskov)"; };
    if str_eq(code, "CONTRACT-005") { return "Trait impl strengthens postcondition (Liskov)"; };
    if str_eq(code, "CONTRACT-006") { return "old(expr) references mutable state without snapshot"; };
    if str_eq(code, "CONTRACT-007") { return "In cert profile, contract not statically provable"; };
    if str_eq(code, "CONTRACT-008") { return "result referenced in void-fn ensure"; };
    if str_eq(code, "CONTRACT-009") { return "Invalid NUCLEOR_DBC_MODE value"; };
    if str_eq(code, "CONTRACT-010") { return "old(expr) used in require precondition"; };
    if str_eq(code, "CONTRACT-011") { return "Undefined identifier in contract predicate"; };
    // RFC-0007 atomic
    if str_eq(code, "ATOMIC-001") { return "Blocking call inside #[atomic] function"; };
    if str_eq(code, "ATOMIC-002") { return "Allocating call inside #[atomic] function"; };
    if str_eq(code, "ATOMIC-003") { return "Use of Cell/RefCell in #[atomic]"; };
    if str_eq(code, "ATOMIC-004") { return "Mismatched orderings in compare_exchange"; };
    if str_eq(code, "ATOMIC-005") { return "Invalid memory ordering for atomic load/store"; };
    if str_eq(code, "ATOMIC-006") { return "Atomic helper inside closure is temporarily unsupported"; };
    // RFC-0008 ISR
    if str_eq(code, "ISR-001") { return "#[isr] function must be fn() -> void"; };
    if str_eq(code, "ISR-002") { return "#[isr] cannot be combined with #[deadline]"; };
    if str_eq(code, "ISR-003") { return "Target does not support #[isr] yet"; };
    if str_eq(code, "ISR-004") { return "Vector name not recognized for target"; };
    if str_eq(code, "ISR-005") { return "Two ISRs assigned to the same vector"; };
    if str_eq(code, "ISR-006") { return "Priority out of range for target NVIC"; };
    if str_eq(code, "ISR-007") { return "Malformed prio attribute (negative / string / missing value)"; };
    if str_eq(code, "ISR-008") { return "#[isr] applied to a non-fn item"; };
    // RFC-0009 WCET
    if str_eq(code, "WCET-001") { return "#[deadline] function uses dynamic dispatch"; };
    if str_eq(code, "WCET-002") { return "Loop bound unknown"; };
    if str_eq(code, "WCET-003") { return "WCET exceeds declared deadline"; };
    if str_eq(code, "WCET-004") { return "Indirect-call bound unknown"; };
    if str_eq(code, "WCET-005") { return "Recursive call exceeds #[max_depth]"; };
    if str_eq(code, "WCET-006") { return "Heptane analysis failed (internal tool error)"; };
    // RFC-0010 DLPack
    if str_eq(code, "DLPACK-001") { return "Unsupported device"; };
    if str_eq(code, "DLPACK-002") { return "Unsupported dtype"; };
    if str_eq(code, "DLPACK-003") { return "Shape mismatch"; };
    if str_eq(code, "DLPACK-004") { return "Non-contiguous tensor and no copy requested"; };
    if str_eq(code, "DLPACK-005") { return "DLPack version too old"; };
    // RFC-0011 nuc-cxx
    if str_eq(code, "CXX-001") { return "C++ header not found"; };
    if str_eq(code, "CXX-002") { return "Type mismatch between Nucleor decl and C++ source"; };
    if str_eq(code, "CXX-003") { return "Use of std::function without #[no_dyn] opt-out"; };
    if str_eq(code, "CXX-004") { return "extern \"Nucleor\" type with non-#[repr(C)] layout"; };
    if str_eq(code, "CXX-005") { return "C++ exception escapes through bridge"; };
    // RFC-0012 nuc-bindgen
    if str_eq(code, "BINDGEN-001") { return "Header file not found"; };
    if str_eq(code, "BINDGEN-002") { return "libclang parse error"; };
    if str_eq(code, "BINDGEN-003") { return "Type conversion not supported"; };
    if str_eq(code, "BINDGEN-004") { return "Forward-declared type with no definition"; };
    if str_eq(code, "BINDGEN-005") { return "Duplicate symbol"; };
    // RFC-0013 URDF
    if str_eq(code, "URDF-001") { return "No path from A to B in any imported URDF"; };
    if str_eq(code, "URDF-002") { return "A and B in different URDFs without #[urdf_attach]"; };
    if str_eq(code, "URDF-003") { return "Cycle in URDF tree"; };
    if str_eq(code, "URDF-004") { return "URDF file not found"; };
    if str_eq(code, "URDF-005") { return "URDF parse error"; };
    if str_eq(code, "URDF-006") { return "Joint limit violated"; };
    // RFC-0014 max_depth
    if str_eq(code, "DEPTH-001") { return "Max-depth analysis cannot bound recursive path"; };
    if str_eq(code, "DEPTH-002") { return "Bounded recursion exceeds #[max_depth = N]"; };
    if str_eq(code, "DEPTH-003") { return "Mutually-recursive max_depth cycle violates bounds"; };
    if str_eq(code, "DEPTH-004") { return "Invalid #[max_depth] attribute placement or value"; };
    if str_eq(code, "DEPTH-005") { return "Total stack budget exceeded"; };
    // RFC-0031 laws (R14 audit reservations)
    if str_eq(code, "LAW-001") { return "Generated law check failed, declared law has unsupported arity, or canonical form lacks a shipped bounded checker"; };
    if str_eq(code, "LAW-002") { return "SMT disproves law (RESERVED — Phase 3 not shipped)"; };
    if str_eq(code, "LAW-003") { return "Law cited but optimizer cannot use it (RESERVED — Phase 2 not shipped)"; };
    if str_eq(code, "LAW-004") { return "Float or approximate law form lacks shipped tolerance semantics"; };
    if str_eq(code, "LAW-006") { return "Deprecated alias `zero = Z`; use `absorbing = Z`"; };
    if str_eq(code, "LAW-007") { return "Deprecated alias bare `distributive`; use `distributive_over = g`"; };
    if str_eq(code, "LAW-008") { return "Unrecognized law name"; };
    // RFC-0032 effects
    if str_eq(code, "EFF-001") { return "Function uses effect not in declared row"; };
    if str_eq(code, "EFF-002") { return "pure fn calls effectful fn"; };
    if str_eq(code, "EFF-003") { return "restricts [...] violated"; };
    if str_eq(code, "EFF-004") { return "Effect declared but not used (warning)"; };
    if str_eq(code, "EFF-005") { return "Custom effect handler missing"; };
    // RFC-0017 collections
    if str_eq(code, "COLL-001") { return "K: Hash + Eq requirement violated"; };
    if str_eq(code, "COLL-002") { return "K: Ord requirement violated for BTree"; };
    if str_eq(code, "COLL-003") { return "Collection method that may grow used in #[no_alloc]"; };
    if str_eq(code, "COLL-004") { return "Iterator invalidated by mutation during walk"; };
    if str_eq(code, "COLL-005") { return "Index out of bounds on fixed-length collection"; };
    // RFC-0018 modules
    if str_eq(code, "MOD-001") { return "Module file not found at expected path"; };
    if str_eq(code, "MOD-002") { return "Path references non-existent module/item"; };
    if str_eq(code, "MOD-003") { return "Visibility violation"; };
    if str_eq(code, "MOD-004") { return "Glob `use *` from a module without an explicit prelude (warning)"; };
    if str_eq(code, "MOD-005") { return "Circular module dependency"; };
    if str_eq(code, "MOD-006") { return "Two `use` declarations bind the same name"; };
    // RFC-0019 packages
    if str_eq(code, "PKG-001") { return "Manifest schema error"; };
    if str_eq(code, "PKG-002") { return "Version conflict — no resolution found"; };
    if str_eq(code, "PKG-003") { return "Checksum mismatch"; };
    if str_eq(code, "PKG-004") { return "Network error fetching package"; };
    if str_eq(code, "PKG-005") { return "Unknown package / version"; };
    if str_eq(code, "PKG-006") { return "Yanked version explicitly required"; };
    // RFC-0022 cross-platform
    if str_eq(code, "TGT-001") { return "Unknown target triple"; };
    if str_eq(code, "TGT-002") { return "Sysroot not installed for target"; };
    if str_eq(code, "TGT-003") { return "Feature unsupported on target"; };
    if str_eq(code, "TGT-004") { return "Cross-link error"; };
    // RFC-0021 test framework
    if str_eq(code, "TST-001") { return "Test discovery: no #[test] functions found"; };
    if str_eq(code, "TST-002") { return "Test isolation: process child crashed before reporting"; };
    if str_eq(code, "TST-003") { return "Test fixture: setup fn returned non-zero"; };
    // RFC-0062 G-series memory-safety gates (v1.0)
    if str_eq(code, "OWN-G4-USE-AFTER-DROP") { return "Use of value after manual free (use-after-drop)"; };
    if str_eq(code, "OWN-G8-COND-MOVE") { return "Use of value moved on one branch but not the other"; };
    if str_eq(code, "INIT-G11-READ-BEFORE-INIT") { return "Read of binding before definite assignment"; };
    if str_eq(code, "BORROW-G2-LIFETIME") { return "Returned reference does not trace back to a reference input"; };
    if str_eq(code, "ALIAS-G3-VEC-OF-REFS") { return "Heap aliasing: vec_push of borrow into Vec<&T>"; };
    if str_eq(code, "ALIAS-G3-HASHMAP-REHASH") { return "Heap aliasing: mutating hashmap call invalidates outstanding borrow"; };
    if str_eq(code, "SEND-G6-HASHMAP") { return "Spawn-call argument carries a non-Sendable HashMap"; };
    if str_eq(code, "SEND-G6-CLOSURE-CAPTURE") { return "Spawn-call closure captures a non-Sendable value"; };
    if str_eq(code, "SEND-G6-TUPLE") { return "Spawn-call argument is a tuple containing a non-Sendable element"; };
    if str_eq(code, "SEND-G6-ENUM") { return "Spawn-call argument is an enum variant carrying a non-Sendable payload"; };
    if str_eq(code, "FFI-G5-NULL-DEREF") { return "Use of may_return_null FFI pointer without a dominating null guard"; };
    if str_eq(code, "FFI-G9-MISSING-ALLOW-DIRECT-FFI") { return "Call to extern fn without #[effect(direct_ffi)] / #[allow_effect(direct_ffi)] on the caller"; };
    if str_eq(code, "UNSAFE-G7-MISSING-ALLOW") { return "unsafe { } block without #[effect(unsafe)] / #[allow_effect(unsafe)] on the caller"; };
    if str_eq(code, "EFFECT-G10-UNDECLARED") { return "Function produces an effect that is not in its declared #[effect(...)] row"; };
    if str_eq(code, "EFFECT-G10-MISSING-ALLOW") { return "Caller invokes effectful fn without an #[allow_effect(...)] entry for the produced effect"; };
    if str_eq(code, "EFFECT-G10-WRONG-ROW") { return "Declared #[effect(...)] row does not match the effects the function actually produces"; };
    return "";
}

fn explain_error_summary(code: str) -> str {
    if str_eq(code, "NR001") { return "Nucleor could not read the requested source file."; };
    if str_eq(code, "NR005") { return "A use target or package import could not be resolved safely."; };
    if str_eq(code, "NR010") { return "The lexer found an invalid character or token shape."; };
    if str_eq(code, "NR020") { return "The token stream does not form valid Nucleor syntax."; };
    if str_eq(code, "PARSE-LET-SEMI") { return "A `let` statement initializer was not terminated by `;`, so the next token would otherwise be parsed as a separate expression statement."; };
    if str_eq(code, "NR030") { return "The program parsed, but semantic typing rules were violated."; };
    if str_eq(code, "NR031") { return "Ownership or borrowing rules were violated. (Legacy code — at v1.0 the modern compiler emits the specific RFC-0062 G-series codes instead: OWN-G4-USE-AFTER-DROP, OWN-G8-COND-MOVE, BORROW-G2-LIFETIME, ALIAS-G3-VEC-OF-REFS, ALIAS-G3-HASHMAP-REHASH, INIT-G11-READ-BEFORE-INIT, SEND-G6-* — see `nuc explain <CODE>` for any of those.)"; };
    if str_eq(code, "NR032") { return "A denied effect, purity rule, or policy restriction was violated."; };
    if str_eq(code, "NR033") { return "Tainted data reached a location that requires trusted input."; };
    if str_eq(code, "NR034") { return "A spawned or shared context captured a type that is not safe to transfer or share."; };
    if str_eq(code, "NR035") { return "Explicit enum discriminants `enum X { A = N }` are not yet supported in v0.6 — the parser halts at the `=` token."; };
    if str_eq(code, "NR036") { return "A struct that contains itself directly (`struct Node { next: Node }`) has infinite size — Rust E0072. Wrap the recursive field in `Box<Node>` (heap indirection), `Option<Box<Node>>` (linked-list / tree shape with terminator), or `&Node` (reference) so the field is a fixed size."; };
    if str_eq(code, "NR040") { return "The typed AST could not be lowered into compiler IR."; };
    if str_eq(code, "NR050") { return "IR generation succeeded, but a backend could not emit valid target code."; };
    if str_eq(code, "NR051") { return "WASM output was requested without the required backend support."; };
    if str_eq(code, "NR070") { return "Project metadata, dependency graph, or lockfile state is invalid."; };
    if str_eq(code, "NR090") { return "An internal compiler stage received invalid state from a previous pass."; };
    if str_eq(code, "RT-001") { return "A #[no_alloc] function called something that allocates from the global heap."; };
    if str_eq(code, "RT-002") { return "A #[no_panic] function contains an expression the compiler cannot prove is panic-free."; };
    if str_eq(code, "RT-003") { return "A #[no_dyn] function uses dynamic (vtable) dispatch via dyn Trait."; };
    if str_eq(code, "RT-004") { return "A HEURISTIC compile-time estimator (statement-counter + coarse loop multiplier) flags this function as likely to exceed its declared #[deadline]. RT-004 is NOT certified WCET — it does not model callee cost, ISA, cache, or branch prediction. Use #[allow(RT-004)] / #[allow_fn(RT-004)] when the estimate is wrong; treat the runtime deadline check as the actual contract. Certified WCET is future work (RFC-0001 §Heuristic vs certified WCET)."; };
    if str_eq(code, "RT-005") { return "An RT-tagged function called an extern fn lacking #[ffi_no_alloc] or #[ffi_no_panic]."; };
    if str_eq(code, "RT-006") { return "RT attributes (#[no_alloc], #[deadline] etc.) cannot be applied to async fn — async semantics break the deadline guarantee."; };
    if str_eq(code, "ASYNC-001") { return "Pre-v0.5.19 `async fn foo() { ... }` was silently stripped to `fn foo()` and ran sync immediately. Adopters writing the canonical Rust async pattern got immediate execution with no signal. Nucleor v0.5 has no Future / .await polling; threading is via `async_spawn(fn_ptr, arg)` + `async_await(handle)` (RFC-0027 phase 1). Either drop the `async` keyword for sync fns, or call `async_spawn` to actually thread."; };
    if str_eq(code, "RT-007") { return "A #[deadline] annotation alone is incomplete — it is hard to reason about deadline without #[no_alloc] or #[no_panic]."; };
    if str_eq(code, "RT-008") { return "A #[deadline] function uses recursion. Bound it with #[max_depth = N] (RFC-0014)."; };
    if str_eq(code, "RT-009") { return "A #[no_panic] function contains an integer `/` or `%` operator. Integer divide/modulo panic when the divisor is zero. Phase 1 (v0.8.295) flags this as a warning because the estimator does not yet prove non-zero divisors at the IR level. Suppress with `#[allow_fn(RT-009)]` when the divisor is provably non-zero, or replace with `checked_div` / `checked_rem` for explicit Result-typed handling. Phase 2 (R03-D2) adds IR-level non-zero proof."; };
    if str_eq(code, "DIAG-001") { return "An #[allow(_fn)(CODE)] or #[deny(_fn)(CODE)] attribute references a CODE that is not in the canonical enumerated diagnostic code set. The suppression or promotion has no effect at compile time -- the diagnostic the author meant to control still fires unsuppressed. Catches both unknown-prefix codes (e.g. WAT-001) and within-series typos (e.g. RT-099 vs RT-009)."; };
    if str_eq(code, "ALLOC-001") { return "A value allocated in an arena/pool/tlsf cannot outlive its allocator. The borrow checker rejects returning the value when the allocator goes out of scope."; };
    if str_eq(code, "ALLOC-002") { return "Two values from different allocator types cannot be combined where one is required."; };
    if str_eq(code, "ALLOC-003") { return "An allocation site reaches a #[no_alloc(...)] context that forbids that allocator."; };
    if str_eq(code, "FRAME-001") { return "Spatial values in different coordinate frames cannot be combined directly. Transform via tf.lookup or apply an explicit Transform."; };
    if str_eq(code, "FRAME-002") { return "Transform<A, B> * Transform<C, D> requires B == C. The compiler rejected the composition."; };
    if str_eq(code, "FRAME-003") { return "Transform<A, B>.apply(Pose<C>) requires C == A. The compiler rejected the application."; };
    if str_eq(code, "OWN-001") { return "A value was moved into another binding or call; using the original now would alias freed/owned memory. Clone before the move, or restructure to avoid the second use."; };
    if str_eq(code, "OWN-002") { return "Cannot create a new borrow of a value that has been moved. The borrow target no longer exists at the source's binding."; };
    if str_eq(code, "OWN-003") { return "A move would invalidate an outstanding borrow. Wait for the borrow to end (typically by ending the borrowed-reference's scope) before moving."; };
    if str_eq(code, "OWN-004") { return "Two simultaneous mutable borrows would alias. Sequence the borrows or use interior mutability via Atomic<T> for cross-thread sharing."; };
    if str_eq(code, "OWN-005") { return "A shared (immutable) borrow cannot coexist with a live mutable borrow — would risk reading partially-mutated state. End the mutable borrow first."; };
    if str_eq(code, "OWN-006") { return "Shared references (`&T`) are read-only by construction. Use `&mut T` if you need to assign through the reference."; };
    if str_eq(code, "OWN-007") { return "Mutating a location that is currently borrowed (directly or via a struct-field reachable through the borrow) would invalidate the borrow. End the borrow first."; };
    if str_eq(code, "OWN-008") { return "The binding was declared `let x` (immutable). Use `let mut x` to allow assignment after the initial bind."; };
    if str_eq(code, "OWN-009") { return "The function would return a reference to a stack-local value; the value's storage is freed at function exit so the reference would dangle. Return by value or take/return a reference with a longer-lived source."; };
    if str_eq(code, "OWN-010") { return "A reference's source value lives in a nested scope that ends before the binding's scope; the reference would dangle. Move the source out to the enclosing scope, or hold the source by value at the outer scope."; };
    if str_eq(code, "OWN-011") { return "`&mut T` requires the source to be declared `let mut x`. Make the binding mutable, or restructure to take a shared `&T` instead."; };
    if str_eq(code, "OWN-012") { return "An arena cannot be destroyed while references into it are still live — would dangle every outstanding pointer. End all borrows from the arena before destroy."; };
    if str_eq(code, "OWN-013") { return "GPU `DeviceBuffer` handles are pinned to the thread that allocated them, so they are not `Send`. A `spawn { ... }` block runs on a fresh thread and cannot capture them. Move the launch into the owning thread, or pass a host-side handle that the worker can re-acquire its own DeviceBuffer from."; };
    if str_eq(code, "RACE-001") { return "RFC-0035 requires values moved into spawned work to be Sendable. Primitive values, Sendable containers, and types with an explicit `impl Sendable for T` pass this first check."; };
    if str_eq(code, "RACE-002") { return "Actor calls can suspend on the actor executor. Calling them without await would bypass the serialization contract."; };
    if str_eq(code, "RACE-003") { return "Actor fields are isolated mutable state. Direct field access from outside the actor bypasses the actor executor and is rejected."; };
    if str_eq(code, "RACE-004") { return "Shared mutable state needs an actor or synchronization primitive so two tasks cannot mutate it concurrently."; };
    if str_eq(code, "RACE-005") { return "A mutable reference crossing a thread boundary can outlive the source stack frame or race the original owner. Move owned data or use synchronization."; };
    if str_eq(code, "RACE-006") { return "The same actor lock cannot be re-entered while already held; doing so can deadlock or violate serialized state access."; };
    if str_eq(code, "RACE-007") { return "Deadline checking and actor await composition require a scheduler-aware bound. The first pass rejects the combination."; };
    if str_eq(code, "RACE-008") { return "`#[not_sendable]` is an explicit opt-out from structural Sendable inference. The compiler honors it even when fields look safe."; };
    if str_eq(code, "RACE-009") { return "Reserved for a future RFC-0035 Sendable/actor diagnostic."; };
    if str_eq(code, "RACE-010") { return "Reserved for a future RFC-0035 Sendable/actor diagnostic."; };
    if str_eq(code, "GOV-001") { return "The source declares `@policy(require_authored)` at the module level but at least one function lacks an `@authored(\"name\")` annotation. Add `@authored(\"...\")` to every fn, or remove the policy."; };
    if str_eq(code, "GOV-002") { return "The source declares `@policy(no_unsafe)` at the module level but contains an `unsafe { ... }` block. Either remove the unsafe block (preferred) or remove the no_unsafe policy."; };
    if str_eq(code, "TNT-001") { return "Tainted data flowing into a function annotated as a sensitive sink. Wrap the value in `sanitize(value)` to strip the taint marker before the call."; };
    if str_eq(code, "TYP-001") { return "Legacy non-exhaustive-match warning. Unified under the canonical MATCH-001 (RFC-0016) in v0.5.18 — TYP-001 is no longer emitted by the main compiler (was always paired with MATCH-001 with identical text; the dual-emit was a noisy adopter UX hazard). The explain entry stays so existing adopter docs / scripts that reference TYP-001 still resolve."; };
    if str_eq(code, "TYP-002") { return "Booleans are not numeric in Nucleor; `true + false` etc. are rejected. Use `if cond { 1 } else { 0 }` if you need to convert."; };
    if str_eq(code, "TYP-003") { return "RFC-0005 — adding two unit values requires identical dimensions (both must be `unit<T,m>` or both `unit<T,s>`, etc.). Convert one to the other or use multiplication."; };
    if str_eq(code, "TYP-004") { return "The `*` (deref) operator only applies to `&T` / `&mut T` / `Box<T>`. Applying it to a value type (`i64`, struct field by value, etc.) is rejected."; };
    if str_eq(code, "TYP-005") { return "The call site supplies a different number of arguments than the function declared. Check the function signature."; };
    if str_eq(code, "TYP-006") { return "Argument N has a type incompatible with parameter N's declared type. Includes taint-marker type mismatches (passing tainted T to a clean T parameter)."; };
    if str_eq(code, "TYP-007") { return "RFC-0005 unit values must be initialized via the unit constructor (e.g. `meters(5.0)`) — a bare `5.0` doesn't carry the dimension tag and would silently mix units."; };
    if str_eq(code, "TYP-008") { return "`let x: T = expr` requires `expr` to type-check as `T`. Mismatched types produce TYP-008 with the expected and actual types."; };
    if str_eq(code, "TYP-009") { return "`x = expr` requires `expr` to match `x`'s declared type after the initial bind. Re-binding to a different type isn't allowed without a fresh `let` shadowing."; };
    if str_eq(code, "TYP-010") { return "`return expr` requires `expr` to type-check as the function's declared return type. The body type and the signature type must agree."; };
    if str_eq(code, "TYP-011") { return "`str + str` (and longer chains like `\"a\" + \"b\" + \"c\"`) silently SIGSEGVed pre-v0.4.51 because the binop lowered to i64_add on the string pointers, producing a garbage pointer that crashed in print_str. Use `str_concat(a, b)` to concatenate strings."; };
    if str_eq(code, "TYP-012") { return "Pre-v0.4.62 `Point { x: 1, y: 2 }` for a struct with 3 fields silently defaulted the missing field to 0 / empty. Adopters writing the canonical Rust idiom (which errors with E0063) got a quiet wrong value. Either list every field explicitly or define a `Point::new(x, y)` constructor fn that supplies the rest."; };
    if str_eq(code, "TYP-013") { return "Pre-v0.4.63 `Point { x: 1, y: 2, z: 3 }` for a 2-field Point silently dropped the extra `z` field (Rust E0560 errors). Check the struct definition and remove the unknown field, or add it to the struct decl."; };
    if str_eq(code, "TYP-026") { return "`as char` requires a valid Unicode scalar value. Constant casts must be within 0..0x10FFFF and outside 0xD800..0xDFFF; non-constant casts must be guarded by a recognized scalar-range proof such as `v >= 0 && v < 0xD800`. This code also covers non-void functions that can fall through without an explicit return or tail expression."; };
    if str_eq(code, "TYP-027") { return "Strict inference mode found an expression whose type checker returned the empty-type sentinel. The compiler rejects it instead of treating the unknown type as compatible with every annotated type."; };
    if str_eq(code, "TYP-044") { return "A binding annotated with one integer width was initialized by another integer width. Silent widening or narrowing is rejected so portability and truncation are explicit."; };
    if str_eq(code, "FMT-002") { return "Bare `{}` formatting for a user struct requires an `impl Display for Type` with `fn fmt(self) -> str`; use `{:?}` for derived structural debug output."; };
    if str_eq(code, "FMT-003") { return "`format!(\"{}\", 1, 2, 3)` (more args than placeholders) silently dropped the extras pre-v0.5.11 — including any side effects in the dropped argument expressions. Either add `{}` placeholders for each extra arg or remove the unused args from the call. Mirrors the v0.4.70 placeholder>args check (the loud-direction asymmetry that left this case silent)."; };
    if str_eq(code, "TRAIT-001") { return "`?` on `Result<T, SrcErr>` inside a function returning `Result<U, DstErr>` requires `impl From<SrcErr> for DstErr` when the error payload types differ."; };
    if str_eq(code, "NUM-001") { return "Nucleor follows Rust's no-implicit-conversion rule. Cast explicitly with `as`: `(u8_val as i32) + i32_val`."; };
    if str_eq(code, "NUM-002") { return "The literal does not fit in the declared type — e.g. 256u8 overflows u8."; };
    if str_eq(code, "NUM-003") { return "An `as` cast may truncate or round. The warning is informational; promote to error with #![deny(precision_loss)]."; };
    if str_eq(code, "NUM-004") { return "The current target lacks hardware support for the requested low-precision float (f8e4m3 / f8e5m2 / f16 / bf16); the operation is emulated in software and may be slow."; };
    if str_eq(code, "NUM-005") { return "usize and isize are platform-pointer-width and incompatible with explicit i64 / u64 etc. without cast."; };
    if str_eq(code, "NUM-006") { return "Signed and unsigned of the same width are distinct types. Cast one explicitly: `(u32_val as i32) + i32_val`. Reason: silent sign-coercion is a recurring bug source in C/C++."; };
    if str_eq(code, "NUM-007") { return "Float→int cast saturates to the target's max/min when the value is out of range (matches Rust). Use `.try_as_i32()` if you want a Result-typed conversion that surfaces overflow."; };
    if str_eq(code, "NUM-008") { return "Shift amount must be < operand width. `let x: u8 = 1; let y = x << 8;` is UB in C, returns 0 in some Rust modes, traps in others. Nucleor matches Rust 'wrapping shift' semantics in release; debug builds trap."; };
    if str_eq(code, "NUM-009") { return "A function annotated `@const_fn` contains an effectful operation (I/O, allocation, panic-capable expression, or ambient capability). const-fns must be pure so they can be evaluated at compile time. Either remove the @const_fn annotation, or move the effectful work to a separate normal fn. Audit R09-D4 (NUM-G9) v0.8.293 — pre-v0.8.293 @const_fn was silently ignored; post-v0.8.293 it's enforced fail-closed."; };
    if str_eq(code, "PERF-1") { return "Router-level: --tier <X> got a value other than 0/1/2. Phase 2 wires --tier through to clang -O level + cache key + artifact metadata."; };
    if str_eq(code, "PERF-2") { return "A function annotated `@hot` contains a perf-violation: heap allocation (Vec::new / Box::new) or I/O (print / println / panic). Hot paths should be alloc-free and I/O-free; either suppress with #[allow_fn(PERF-2)] when intentional, or move the work out of the @hot body. Audit R10-D2 v0.8.297 — pre-v0.8.297 @hot was discovery-only; post-v0.8.297 violations emit a warning."; };
    if str_eq(code, "PERF-3") { return "A function body contains a Vec::new() or Box::new() call inside a `while` or `loop {}` block. Per-iteration heap allocation is the dominant perf bug class for adopters who compose with std collections. Move the alloc outside the loop (`let mut v = Vec::with_capacity(n);` then push inside), or use a stack buffer, or `#[allow_fn(PERF-3)]` when intentional. Audit R10-D2 v0.8.298."; };
    if str_eq(code, "NUM-009") { return "Constant-folded division by zero. Either change the divisor or guard the call site with `if divisor != 0 { ... }`."; };
    if str_eq(code, "NUM-010") { return "An f64 literal assigned to an f32 binding is narrowed via `__nucleor_as_f32` at the bind site (Phase 5). For most literals this is exact; for values requiring more than 24 bits of mantissa precision (e.g. 0.1), the rounded f32 differs from the f64."; };
    if str_eq(code, "NUM-011") { return "`#[overflow(trap)]` on a function whose body uses `wrapping_add` is contradictory — wrapping_add is opt-in and won't trap regardless of the attribute. Pick one mode."; };
    if str_eq(code, "NUM-012") { return "Casting `*const T` or `*mut T` to a non-pointer-width int (i8/i16/i32) loses bits on 64-bit targets. Use `usize`/`isize` for round-trip-safe pointer-int conversions."; };
    if str_eq(code, "NUM-013") { return "`Vec<T>` requires T to be a primitive or sized struct. Generic / trait-object element types are not yet supported (lands with the Vec<T> monomorphization phase)."; };
    if str_eq(code, "NUM-014") { return "`sizeof_struct(Foo)` requires Foo to be a defined struct with non-generic field types. Phase 3b ships byte sizes for primitives + simple structs; nested generic structs land in 3b.2."; };
    if str_eq(code, "NUM-015") { return "`extern fn` signatures should use ABI-stable C types: i8..i64 / u8..u64 / f32 / f64 / ptr / str. Nucleor-only types (Vec<T>, str, generics) are forwarded as i64 handles via FFI but won't link to native C."; };
    if str_eq(code, "NUM-016") { return "Comparing i32 < u32 risks sign mismatch — the negative i32 is interpreted as a giant u32. Cast one operand explicitly to make the intent visible."; };
    if str_eq(code, "NUM-017") { return "Bitwise ops on signed types preserve the sign bit on right shift (arithmetic shift). For unsigned semantics use `bit_shift_right` (logical); for sign-preserving use `bit_shift_right_signed`."; };
    if str_eq(code, "NUM-018") { return "A float literal (`3.14`) was used where an integer is expected. Either cast (`3.14 as i32`) or change the binding type to f32/f64."; };
    if str_eq(code, "NUM-019") { return "`let x: u8 = -1` doesn't fit in u8 (range 0..255). Use `255u8` (the wrap result) or change the type to i8 / i16."; };
    if str_eq(code, "NUM-020") { return "`let a: i32 = 5; let b: i64 = 6; if a < b { ... }` mixes widths. Cast one operand: `if (a as i64) < b { ... }`."; };
    if str_eq(code, "NUM-021") { return "A decimal integer literal exceeds u64::MAX, or a module-level const integer expression overflows i64 during compile-time evaluation. Pre-fix these paths wrapped through compiler internals and either produced meaningless bits, runtime-startup panics, or confusing generated-IR failures."; };
    if str_eq(code, "NUM-022") { return "`5 < 5.0` mixes integer and float operands; pre-v0.4.137 this silently coerced and the comparison produced unexpected results. Cast one operand: `5.0 < 5.0` or `5 < (5.0 as i64)`."; };
    if str_eq(code, "NUM-023") { return "`(3.14 as str)` and `(true as str)` are not defined as numeric `as`-casts. Use `str_from_float` / `str_from_bool` (or format) instead."; };
    if str_eq(code, "NUM-024") { return "Opt-in audit warning. With `NUCLEOR_AUDIT_NUM024=1` set, the compiler reports every call site where a wider-typed argument flows into a narrower-typed param via Nucleor's i64-everywhere ABI. v0.4.230 closed the audit surface to 0/0 across self-build by widening str_from_int's signature; the audit remains as a regression gate."; };
    if str_eq(code, "MATCH-001") { return "The match does not cover all variants of the matched type. The compiler shows a witness uncovered value."; };
    if str_eq(code, "MATCH-002") { return "An arm is preceded by patterns that already match every case it would handle."; };
    if str_eq(code, "MATCH-003") { return "Match arm bodies must produce the same type (or () in statement context)."; };
    if str_eq(code, "MATCH-004") { return "The ? operator desugars to a function-level early return; the function must return Result/Option for ? to type-check."; };
    if str_eq(code, "MATCH-005") { return "? converts the inner error via `From::from`. The compiler cannot find an impl mapping the source error type to the function's declared error type."; };
    if str_eq(code, "MATCH-006") { return "unwrap() panics on Err/None. Use unwrap_or, ?, or match in #[no_panic] code."; };
    if str_eq(code, "MATCH-007") { return "Range patterns like `1..=5` require `low <= high`. The compiler refuses inverted bounds since they would never match."; };
    if str_eq(code, "MATCH-008") { return "Or-patterns like `Some(x) | Other(x)` must bind the same set of names with the same types in every arm so the body type-checks identically."; };
    if str_eq(code, "MATCH-009") { return "Slice patterns split a slice into prefix/middle/suffix. Two patterns claiming the same element are ambiguous and rejected."; };
    if str_eq(code, "MATCH-010") { return "An @-binding (e.g. `n @ 1..=5`) introduces a fresh name; using a name already in scope is rejected to prevent silent shadowing."; };
    if str_eq(code, "MATCH-011") { return "Every arm of a match expression must yield the same concrete type (or unit `()` in statement context). Pre-v0.4.140 heterogeneous arms silently produced whichever value the runtime hit first, with the wrong type stored in the result slot — a runtime SIGSEGV class."; };
    if str_eq(code, "MATCH-012") { return "Struct patterns currently support only the binding form `Point { x, y }` and the rename form `Point { x: rename, y: rename }`. Field-equality literal patterns like `Point { x: 0, y: 0 }` are deferred to v0.5+. Express the same intent today with a guard: `Point { x, y } if x == 0 && y == 0 => ...`. Pre-v0.4.163 the parser fed the literal's raw value as a string-id binding, producing garbage that crashed codegen with an ACCESS VIOLATION."; };
    if str_eq(code, "MATCH-013") { return "Float scrutinees (`match x { ... }` for x: f32/f64) and float-literal patterns (`1.5 => ...`) are not supported. Float equality is fragile: NaN ≠ NaN, and arithmetic round-off makes literal-equality unreliable. Pre-v0.4.206 the compiler crashed with ACCESS_VIOLATION (no diagnostic) on float-lit patterns or float-typed scrutinees. Use an `if`-chain with tolerance (`if (x - 1.5).abs() < 0.001 { ... }`) or convert via `(x * 100.0) as i32` to match on integer scaled values."; };
    if str_eq(code, "MATCH-014") { return "Range patterns currently parse only non-negative integer literal bounds. A pattern such as `-10..=-1` tokenizes as unary minus plus integer literal at each bound, and that unary form is not part of the range-pattern grammar yet. The compiler now halts with MATCH-014 instead of falling through to the generic NR020 expected-token error."; };
    if str_eq(code, "MATCH-015") { return "Negative literal patterns (`-5 => ...`) are not yet parsed; the unary minus is read as an operator, not part of the literal pattern. Sister to MATCH-014's range-bound limitation. Use a guard for now: `_ if x == -5 => ...`."; };
    if str_eq(code, "MATCH-016") { return "A pattern's enum constructor (e.g. `Color::Red`) names a different enum type than the scrutinee. Pre-v1.0.1 (Lane 1 audit fix F-002) this miscompiled silently — `match a { B::On => ... }` for `a: A` would lower the B variant tag against A's vtable, returning whichever A variant happened to share the tag value. The check now fires when the scrutinee's enum type can be inferred."; };
    if str_eq(code, "ASSUME-001") { return "The assume! predicate uses an expression form the analyzer doesn't track for static reasoning. Runtime check still happens; static benefit is none."; };
    if str_eq(code, "ASSUME-002") { return "assume_unchecked! disables even the debug-mode runtime check. The warning surfaces a missing comment justifying the unsafety."; };
    if str_eq(code, "ASSUME-003") { return "The assume! predicate is true for all inputs (e.g., assume!(x == x) or assume!(true)). The runtime check is dead code; remove the assertion."; };
    if str_eq(code, "ASSUME-004") { return "The assume! predicate is provably false from the type system (e.g., assume!(x < 0) for x: u32)."; };
    if str_eq(code, "ASSUME-005") { return "In --profile=cert, every assume! must be discharged via SMT proof or explicit chain-of-trust. The verifier could neither prove nor refute this one."; };
    if str_eq(code, "UNIT-001") { return "Adding/subtracting unit<T,m> and unit<T,s> is dimensionally invalid. Convert one to the other or use multiplication."; };
    if str_eq(code, "UNIT-002") { return "Implicit unit conversion is forbidden by RFC-0005. Use explicit .into() or From::from to cross unit systems."; };
    if str_eq(code, "UNIT-003") { return "Unit exponents must resolve to integers at compile time. e.g. m^2 is fine but m^x where x is runtime is not."; };
    if str_eq(code, "UNIT-004") { return "Unknown unit alias. Check stdlib/rods/units_si.nr or units_imperial.nr."; };
    if str_eq(code, "UNIT-005") { return "An @law annotation references quantities whose unit dimensions don't reduce — e.g. claiming a force-times-time equals a length."; };
    if str_eq(code, "CONTRACT-001") { return "A #[require(...)] precondition was violated by the caller. Caller must satisfy the predicate before the call."; };
    if str_eq(code, "CONTRACT-002") { return "A #[ensure(...)] postcondition was violated by the function body. Body must produce a result matching the predicate."; };
    if str_eq(code, "CONTRACT-003") { return "A #[invariant(...)] struct invariant was violated on method entry or exit."; };
    if str_eq(code, "CONTRACT-004") { return "Liskov substitution: a trait impl cannot weaken the trait's preconditions. Add the missing #[require] to the impl."; };
    if str_eq(code, "CONTRACT-005") { return "Liskov substitution: a trait impl cannot strengthen the trait's postconditions either. The impl must guarantee at least what the trait promised."; };
    if str_eq(code, "CONTRACT-006") { return "old(expr) reads the value at function entry; if expr was mutated by the body, take an explicit snapshot at entry first."; };
    if str_eq(code, "CONTRACT-007") { return "In --profile=cert, every contract must be statically discharged. The SMT backend could not prove the predicate; tighten or annotate."; };
    if str_eq(code, "CONTRACT-008") { return "A #[ensure(...)] predicate references result, but the annotated function returns no value."; };
    if str_eq(code, "CONTRACT-009") { return "NUCLEOR_DBC_MODE must be one of debug, safe-release, release, or cert."; };
    if str_eq(code, "CONTRACT-010") { return "old(...) snapshots function-entry state and is only meaningful in postconditions, not preconditions."; };
    if str_eq(code, "CONTRACT-011") { return "A contract predicate references an identifier that is not a fn parameter, DbC keyword (true/false/null/Some/None/Ok/Err/result/old/self), CamelCase type or variant name, or fn call site."; };
    if str_eq(code, "ATOMIC-001") { return "#[atomic] functions cannot block. Mutex::lock, Channel::recv, sleep, or syscalls are forbidden. Use lock-free structures (SpscQueue, MpmcQueue) or Atomic<T>."; };
    if str_eq(code, "ATOMIC-002") { return "#[atomic] implies #[no_alloc]. See RT-001 explanation."; };
    if str_eq(code, "ATOMIC-003") { return "Cell/RefCell carry runtime borrow checks that can panic; #[atomic] forbids panicking control flow. Use Atomic<T> primitives instead."; };
    if str_eq(code, "ATOMIC-004") { return "compare_exchange takes (success, failure) orderings; failure must not be stronger than success and not Release/AcqRel. The compiler enforces the ordering lattice."; };
    if str_eq(code, "ATOMIC-005") { return "atomic_load accepts Relaxed, Acquire, or SeqCst. atomic_store accepts Relaxed, Release, or SeqCst. Acquire stores and Release loads are invalid memory-model combinations."; };
    if str_eq(code, "ATOMIC-006") { return "Closure lowering does not yet inherit the parent function's enum-variant scope for atomic memory-order constants."; };
    if str_eq(code, "ISR-001") { return "An ISR is entered by hardware, so the first pass accepts only a zero-argument void function. Move data exchange through atomics or static state."; };
    if str_eq(code, "ISR-002") { return "Deadline wrappers measure wall-time function calls. ISR latency is target interrupt timing, so #[deadline] composition is rejected."; };
    if str_eq(code, "ISR-003") { return "The current ISR lowering substrate recognizes cortex-m4f and rv32imac. Other targets must wait for a target-specific interrupt ABI ship."; };
    if str_eq(code, "ISR-004") { return "The vector name in #[isr(vector = ...)] does not match this target's PAC. Check stdlib/embedded/<target>/vectors.nr for the valid set."; };
    if str_eq(code, "ISR-005") { return "Two #[isr] functions claim the same vector. The vector table can only bind one — combine them or distinguish the priorities."; };
    if str_eq(code, "ISR-006") { return "Cortex-M NVIC priorities range 0..2^N where N depends on the chip (typically 3–4). The supplied priority is out of range."; };
    if str_eq(code, "ISR-007") { return "The `prio` named attribute inside #[isr(prio = N)] requires a non-negative integer literal. Pre-v0.6.32 negative-int / string-literal / bare-ident were silently accepted with undefined effect on the target controller."; };
    if str_eq(code, "ISR-008") { return "#[isr] is meaningful only on fn items. Pre-v0.6.31 it was silently dropped on non-fn items (struct/enum/impl/trait/mod/use/const/static/type) AND leaked to the next fn, surfacing as a misleading ISR-001 diag pointing at the wrong fn."; };
    if str_eq(code, "WCET-001") { return "Heptane needs a static call graph; dyn Trait or fn-pointers without #[wcet_dispatch_table] make targets unknown. Make the dispatch concrete or annotate the table."; };
    if str_eq(code, "WCET-002") { return "Add #[loop_bound(N)] or assume!(arr.len() == N) so Heptane can bound the loop."; };
    if str_eq(code, "WCET-003") { return "Static WCET upper bound exceeds the declared deadline. See the WCET report for the dominant cost path."; };
    if str_eq(code, "WCET-004") { return "Indirect call (function pointer / closure) without a declared dispatch table — Heptane cannot bound the callee. Annotate or rewrite as static dispatch."; };
    if str_eq(code, "WCET-005") { return "Recursion in the WCET graph exceeds the #[max_depth] bound. Either raise the bound or refactor to iteration."; };
    if str_eq(code, "WCET-006") { return "Heptane crashed or returned an internal error. File a bug with the IL dump from `nuc dump --wcet-il`."; };
    if str_eq(code, "DLPACK-001") { return "DLPack tensor's device kind doesn't map to any device this Nucleor build supports. Check the supported set with `nuc target list`."; };
    if str_eq(code, "DLPACK-002") { return "DLPack dtype field doesn't match a Nucleor numeric type. Check RFC-0010 §3.4 for the supported codes."; };
    if str_eq(code, "DLPACK-003") { return "Tensor's runtime shape doesn't match the static shape declared on the import side. Reshape upstream or relax the static shape."; };
    if str_eq(code, "DLPACK-004") { return "DLPack tensor's strides don't match a contiguous layout. Pass copy_on_import=true or contiguify upstream."; };
    if str_eq(code, "DLPACK-005") { return "DLPack ABI version on the wire is older than this build supports. Upgrade the producer."; };
    if str_eq(code, "CXX-001") { return "#[cxx_include] points at a header that doesn't resolve under any --include-path. Add the path or relocate the header."; };
    if str_eq(code, "CXX-002") { return "The Nucleor extern \"C++\" decl's signature doesn't match the libclang-extracted signature from the header. Update one to match the other."; };
    if str_eq(code, "CXX-003") { return "std::function is type-erased dispatch; #[no_dyn] forbids it. Refactor to a concrete callable type or opt out with #[allow(no_dyn)]."; };
    if str_eq(code, "CXX-004") { return "Types crossing the C++ bridge must have stable layouts. Add #[repr(C)] to the struct or wrap it."; };
    if str_eq(code, "CXX-005") { return "C++ exceptions cannot unwind through a Nucleor frame. Wrap the C++ call site with try/catch and convert to Result<T, CxxError>."; };
    if str_eq(code, "BINDGEN-001") { return "nuc-bindgen could not locate the C header. Add --include-path or fix the spelling in the bindgen.toml."; };
    if str_eq(code, "BINDGEN-002") { return "libclang failed to parse the header. Common causes: missing -D defines, missing system headers, or C++ syntax in a .h file. Pass --extra-clang-arg to bindgen."; };
    if str_eq(code, "BINDGEN-003") { return "C type has no Nucleor analog (e.g., GCC vector extensions, _Complex). Add a manual binding or skip with bindgen.toml's [skip] section."; };
    if str_eq(code, "BINDGEN-004") { return "Header declares `struct foo;` but never defines it. Either #include the definition or mark the type opaque in bindgen.toml."; };
    if str_eq(code, "BINDGEN-005") { return "Two #include paths produced different definitions of the same symbol. Resolve by --keep-only or by reorganizing the include order."; };
    if str_eq(code, "URDF-001") { return "RFC-0013 verifies frame chains at compile time. The compiler couldn't find a transform path between the two named frames in any URDF on the import path."; };
    if str_eq(code, "URDF-002") { return "Two frames belong to separate URDF trees. Bridge them with #[urdf_attach(parent, child)] to declare the joint, or import a unified URDF."; };
    if str_eq(code, "URDF-003") { return "URDF parser detected a cycle (e.g. base_link → arm_link → base_link). The kinematic graph must be a tree."; };
    if str_eq(code, "URDF-004") { return "#[urdf_load(\"...\")] points to a missing file. Check working directory and import paths."; };
    if str_eq(code, "URDF-005") { return "URDF XML failed to parse. Common issues: missing <robot> root, malformed <joint> attributes, mismatched origin tags."; };
    if str_eq(code, "URDF-006") { return "Joint angle/displacement passed to lookup() exceeds the URDF-declared joint limit. Clamp upstream or relax the limit in the URDF."; };
    if str_eq(code, "DEPTH-001") { return "The RFC-0014 analyzer found recursion but could not prove a finite bound. Use a visible counter parameter, entry guard, and a positive counter increment; mark callback parameters #[no_recurse] only when they cannot recurse into the max_depth region."; };
    if str_eq(code, "DEPTH-002") { return "The analyzer proved a finite recursion depth, but that depth is larger than the declared #[max_depth = N]."; };
    if str_eq(code, "DEPTH-003") { return "A mutually-recursive cycle has incompatible or unproven #[max_depth] bounds. Runtime overrun checks also report this code when a counter exceeds N."; };
    if str_eq(code, "DEPTH-004") { return "`#[max_depth]` must use a positive integer literal and apply directly to a fn declaration."; };
    if str_eq(code, "DEPTH-005") { return "Sum of (max_depth_i * estimated_frame_size_i) along a recursion chain exceeds the project's stack budget."; };
    if str_eq(code, "LAW-001") { return "`nuc test --check-laws` generated a bounded integer check for a low-risk @law annotation and the check failed, or the declared law has unsupported arity for the annotated function. The shipped checker covers commutative, associative, identity, absorbing, idempotent, involution, distributive_over, and unary inverse forms (inverse round-trips `f(g(a)) == a` and `g(f(a)) == a` at four bounded sample integers). Fusion generation, Arbitrary-driven broad property tests, float tolerance handling, and SMT proof obligations remain future RFC-0031 phases and fail closed instead of being silently accepted."; };
    if str_eq(code, "LAW-002") { return "RESERVED diagnostic. Phase 3 of RFC-0031 will route @law through Z3/CVC5 SMT proof under --profile=cert. Phase 1 (v0.8.265) does not run any solver; LAW-002 is reserved for future emission."; };
    if str_eq(code, "LAW-003") { return "RESERVED diagnostic. Phase 2 of RFC-0031 will pattern-match @law citations during optimizer pass; today the law-rewrite pass is a metadata-only no-op (v0.8.265). LAW-003 is reserved for the rewrite pass once it has real semantics."; };
    if str_eq(code, "LAW-004") { return "`nuc test --check-laws` rejects float/approximate law modifiers until the language has explicit tolerance semantics. The canonical schema (docs/spec/Nucleor_Algebraic_Laws_Schema.md) lists eps as a future modifier for floats; this bounded integer checker fails closed."; };
    if str_eq(code, "LAW-006") { return "`nuc test --check-laws` rejects the deprecated alias `zero = Z`; use the canonical `absorbing = Z`. The schema migration table is at docs/spec/Nucleor_Algebraic_Laws_Schema.md section 3."; };
    if str_eq(code, "LAW-007") { return "`nuc test --check-laws` rejects the deprecated bare `distributive`; use the canonical `distributive_over = g` because the partner operator is required. See docs/spec/Nucleor_Algebraic_Laws_Schema.md section 3."; };
    if str_eq(code, "LAW-008") { return "`nuc test --check-laws` rejects any law name not in the canonical set (commutative, associative, identity, idempotent, involution, absorbing, distributive_over, inverse, fusion). Suggest a canonical spelling. See docs/spec/Nucleor_Algebraic_Laws_Schema.md section 1."; };
    if str_eq(code, "EFF-001") { return "RFC-0032 effect rows are checked at type-check. The function body uses an effect (io.read, alloc, etc.) not declared in its signature's `+ effect_row`."; };
    if str_eq(code, "EFF-002") { return "pure fn cannot perform side effects. Either remove the call, mark the callee pure, or remove the pure annotation from the caller."; };
    if str_eq(code, "EFF-003") { return "restricts [...] forbids the listed effects in the callee. The callee uses an effect on the restrict list."; };
    if str_eq(code, "EFF-004") { return "An effect is in the function's `requires [...]` row but no call inside the body actually uses it. Remove the effect from the row to keep the type tight."; };
    if str_eq(code, "EFF-005") { return "An effectful call requires a handler in scope (RFC-0032 §3.1) but none was found. Wrap the call site in a `with handler { ... }` block."; };
    if str_eq(code, "COLL-001") { return "Hash-backed collections require K to implement both Hash + Eq."; };
    if str_eq(code, "COLL-002") { return "BTree-backed collections require K to implement Ord."; };
    if str_eq(code, "COLL-003") { return "push/insert/etc. may allocate to grow. In #[no_alloc] context use try_*-suffixed variants or pre-size with with_capacity."; };
    if str_eq(code, "COLL-004") { return "Mutating a collection (push/remove/clear) while iterating it leaves the iterator pointing at stale or freed memory."; };
    if str_eq(code, "COLL-005") { return "An index expression resolved to a value outside the collection's [0, len) bounds at compile time."; };
    if str_eq(code, "MOD-001") { return "`mod foo;` resolved to a path that does not exist on disk."; };
    if str_eq(code, "MOD-002") { return "A use path or full-path reference resolves to a module/item that doesn't exist."; };
    if str_eq(code, "MOD-003") { return "Item not pub for the access level used (pub, pub(crate), pub(super), or unrestricted)."; };
    if str_eq(code, "MOD-004") { return "use foo::* without an explicit prelude pulls in everything; can shadow names unexpectedly."; };
    if str_eq(code, "MOD-005") { return "Module dependency graph has a cycle (mod a uses b which uses a)."; };
    if str_eq(code, "MOD-006") { return "Two use declarations binding the same identifier shadow each other; rename via `use foo::Bar as FBar`."; };
    if str_eq(code, "PKG-001") { return "Nucleor.toml manifest fails schema validation."; };
    if str_eq(code, "PKG-002") { return "PubGrub resolver could not find a set of versions satisfying all constraints."; };
    if str_eq(code, "PKG-003") { return "Downloaded package hash does not match the lockfile entry. Possible network corruption or registry compromise."; };
    if str_eq(code, "PKG-004") { return "HTTP/git fetch failed. Check connectivity, registry URL, and auth tokens."; };
    if str_eq(code, "PKG-005") { return "Package or version not in registry. Check spelling; the version may be yanked."; };
    if str_eq(code, "PKG-006") { return "The lockfile pins a version that the registry has yanked. Re-run nuc update to pick a non-yanked version."; };
    if str_eq(code, "TGT-001") { return "Target triple does not match Tier-1 (windows-msvc, linux-gnu, apple-darwin) or any installed Tier-2/3 target."; };
    if str_eq(code, "TGT-002") { return "Run nuc install sysroot --target=<triple> to install the cross-compilation sysroot."; };
    if str_eq(code, "TGT-003") { return "Feature requires capability missing on this target (e.g. mmap on bare metal). Use --target check to see the missing capability list."; };
    if str_eq(code, "TGT-004") { return "Cross-linker rejected the binary. Likely missing C library; consult the linker error output for the specific symbol."; };
    if str_eq(code, "TST-001") { return "`nuc test` scanned the source but found no functions annotated `#[test]`. Either add tests or invoke `nuc build`/`nuc check` directly."; };
    if str_eq(code, "TST-002") { return "Under `--isolation=process`, the spawned child for a test exited with an unexpected signal (segv / abort / oom) before the harness could record PASS or FAIL."; };
    if str_eq(code, "TST-003") { return "A `#[test]` declared `setup` or `teardown` returned non-zero. The test body did not run."; };
    // RFC-0062 G-series memory-safety gates (v1.0)
    if str_eq(code, "OWN-G4-USE-AFTER-DROP") { return "A heap-backed binding (Vec/HashMap/Box/String/VecDeque) was freed by an explicit `vec_free` / `hashmap_free` / etc., and a subsequent read of the same binding would alias freed memory. Either move the read above the free, drop the binding before the free site, or remove the explicit free and let auto-drop handle the lifetime."; };
    if str_eq(code, "OWN-G8-COND-MOVE") { return "Inside an if/else (or other branching control flow), the binding was moved on one arm but not the other. After the join point, a read of the binding cannot be proven safe because some CFG paths leave it valid and others leave it moved. Either move on every path, on no path, or restructure to avoid the post-join read."; };
    if str_eq(code, "INIT-G11-READ-BEFORE-INIT") { return "A `let mut x: T;` declaration without an initializer was followed by a read where the definite-assignment flow analysis cannot prove every CFG path assigns `x` first. Initialize at the declaration site, assign on every path before the read, or move the read inside a branch that assigns."; };
    if str_eq(code, "BORROW-G2-LIFETIME") { return "A function with one reference input and a reference return type returns a borrow that does not trace back to the input — typically a borrow of a stack-local value, a synthesized temporary, or a reference threaded through a non-input path. Return by value, take/return ownership, or restructure so the returned reference is rooted at the input parameter."; };
    if str_eq(code, "ALIAS-G3-VEC-OF-REFS") { return "A `vec_push` / `vec_insert` lands a borrow into a `Vec<&T>`. The syntactic borrow tracker does not follow elements through `Vec<&T>`, so the alias relationship between the pushed reference and any later borrow of the same backing storage is invisible to the checker. Use a `Vec<T>` (owned) or restructure to thread the lifetime through the function signature."; };
    if str_eq(code, "ALIAS-G3-HASHMAP-REHASH") { return "A mutating `hashmap_insert` / `hashmap_remove` / `hashmap_clear` runs while an outstanding borrow into the hashmap is live. The rehash can move backing storage and invalidate the borrow. End the borrow first, copy out the value, or move the mutating call before the borrow."; };
    if str_eq(code, "SEND-G6-HASHMAP") { return "A spawn-call argument carries a `HashMap` (or a struct/tuple/enum containing one). HashMap is non-Sendable in v1.0 — the rehash + iterator state are not safe to move across thread boundaries. Convert to a `Vec<(K, V)>` snapshot, wrap in a Sendable handle, or pass only Sendable values into the spawn."; };
    if str_eq(code, "SEND-G6-CLOSURE-CAPTURE") { return "A closure passed to `spawn` (or another spawn-class call) captures a non-Sendable value through its environment. The recursive capture-set walker traces every binding the closure body reads. Either remove the offending capture, convert it to a Sendable form before the spawn, or use a bare-parameter closure that takes the value as an argument."; };
    if str_eq(code, "SEND-G6-TUPLE") { return "A spawn-call tuple argument contains a non-Sendable element. Send-checking is structural — the tuple is non-Sendable if any field is. Project out the Sendable members and move them individually, or convert the offending field before the spawn."; };
    if str_eq(code, "SEND-G6-ENUM") { return "A spawn-call enum-variant argument carries a non-Sendable payload (typically a HashMap inside one of the variants). The Send analysis is structural across all variants. Either remove the non-Sendable payload from the enum or pre-extract a Sendable view before the spawn."; };
    if str_eq(code, "FFI-G5-NULL-DEREF") { return "An `extern fn` declared `#[effect(may_return_null)]` returned a raw pointer that was dereferenced (or passed to a non-null sink) without a dominating `ptr_is_null(<binding>)` guard. Add an explicit `if ptr_is_null(p) { return ...; }` before the use, or use a Result/Option-typed wrapper. The guard-state lattice is intersected at if/else joins so a guard on every path counts."; };
    if str_eq(code, "FFI-G9-MISSING-ALLOW-DIRECT-FFI") { return "The calling function invokes an `extern fn` without declaring `#[effect(direct_ffi)]` or `#[allow_effect(direct_ffi)]`. Direct FFI is a tracked effect — the annotation makes the audit explicit. Add the attribute on the calling fn (or on a containing fn that intentionally exposes the effect)."; };
    if str_eq(code, "UNSAFE-G7-MISSING-ALLOW") { return "An `unsafe { ... }` block was written in a function that does not declare `#[effect(unsafe)]` or `#[allow_effect(unsafe)]`. Audited unsafe is a tracked effect. The OSS compiler self-host source contains zero unsafe blocks; if a user-code path needs one, the annotation makes the deviation explicit."; };
    if str_eq(code, "EFFECT-G10-UNDECLARED") { return "The function body produces an effect (frees, borrows_mut, may_return_null, direct_ffi, unsafe) that is not declared in the function's `#[effect(...)]` row. Either add the effect to the row, or refactor to remove the effect-producing call from the function body."; };
    if str_eq(code, "EFFECT-G10-MISSING-ALLOW") { return "The caller invoked an effectful function without an `#[allow_effect(...)]` entry for the produced effect. Either add the matching `#[allow_effect(...)]` on the caller or declare the effect on the caller's `#[effect(...)]` row to propagate it."; };
    if str_eq(code, "EFFECT-G10-WRONG-ROW") { return "The declared `#[effect(...)]` row does not match the effects the function actually produces — typically a row claims an effect the body never emits, or omits one that the body does emit. Reconcile the row with the body."; };
    return "";
}

fn explain_error_explanation(code: str) -> str {
    if str_eq(code, "NR001") { return "The compiler could not open or read the input file. This is usually a path, permission, or working-directory problem rather than a language error."; };
    if str_eq(code, "NR005") { return "The import graph could not be resolved because a target was missing, escaped its package boundary, created a cycle, or conflicted with another exported symbol."; };
    if str_eq(code, "NR010") { return "The source text cannot be tokenized into valid Nucleor tokens. This usually means a malformed literal, a non-ASCII identifier, or an unexpected character."; };
    if str_eq(code, "NR020") { return "The parser reached a token sequence that does not match the grammar. This is usually a missing delimiter, malformed declaration, or invalid expression shape."; };
    if str_eq(code, "PARSE-LET-SEMI") { return "Nucleor requires `let name: Type = expr;` or `let name = expr;`. Pre-v1.1 builds could accept input such as `let x: i64 = 1 2 3;` and silently drop the trailing tokens as no-op expression statements. The parser now rejects the statement before lowering or codegen."; };
    if str_eq(code, "NR030") { return "The checker rejected the program because types, names, effects, or ownership rules did not line up. More specific semantic failures use narrower codes when possible."; };
    if str_eq(code, "NR031") { return "The checker found an illegal aliasing, move, or borrow pattern. Typical causes are moving a borrowed value, mixing shared and mutable borrows, or using a value after move."; };
    if str_eq(code, "NR032") { return "The program attempted an operation that the current effect context, purity contract, or active policy block does not allow."; };
    if str_eq(code, "NR033") { return "The taint system prevented untrusted data from flowing into a sink that expects sanitized or trusted values."; };
    if str_eq(code, "NR034") { return "The checker found a cross-thread or cross-scope capture that violates Nucleor's Send/Share rules. This usually means a resource, mutable reference, or other non-Send value crossed a spawn boundary."; };
    if str_eq(code, "NR035") { return "v0.6.35 — closes probe finding 2026-05-01-enum-discriminant-segfaults-compiler. Workaround: drop the `= N` and rely on order-based discriminants (`enum Code { OK, WARN, ERR }` lowers to 0, 1, 2). For FFI / wire-protocol values needing specific numbers, build a separate `const` table. Real explicit-discriminant lowering is forward-roadmap (needs the enum AST to carry per-variant i64 values + IR-emit propagation to match-arm dispatch)."; };
    if str_eq(code, "NR036") { return "v0.6.36 — closes probe finding 2026-05-01-self-recursive-struct-infinite-size-accepted. Pre-fix `struct Node { val: i64, next: Node }` was accepted at parse + type-check and crashed at instantiation with STATUS_STACK_OVERFLOW (Windows exception 0xC00000FD) — the struct contains itself directly so the size is infinite. v0.6.36 catches it at parse-time. Wrap the recursive field in `Box<Node>` / `Option<Box<Node>>` / `&Node` so the field is a fixed size. Real recursive-struct lowering through Box is already supported; only the bare-recursion case needs the halt."; };
    if str_eq(code, "NR040") { return "Lowering hit an internal semantic boundary the IR pipeline could not represent. This is usually a compiler implementation gap rather than a front-end syntax issue."; };
    if str_eq(code, "NR050") { return "LLVM rejected the IR, hit an unsupported ABI path, or failed during object emission or linking preparation. (R10-D6 v0.8.278: removed 'Cranelift or' — Nucleor ships only the LLVM backend; no Cranelift backend exists. Phase 2 may add Cranelift as a tier-0 fast-path; until then docs and diagnostics must not imply a backend that's not there.)"; };
    if str_eq(code, "NR051") { return "The current CLI build does not include the backend support required for wasm code generation, or the wasm linker/toolchain is unavailable."; };
    if str_eq(code, "NR070") { return "Nucleor could not resolve the project package graph because the manifest was malformed, a dependency could not be found, or the lockfile was missing or stale."; };
    if str_eq(code, "NR090") { return "A compiler pipeline stage ran out of order or consumed data that was not produced by the earlier stage it depends on. This is an internal compiler bug, not a user program error."; };
    if str_eq(code, "RT-001") { return "RFC-0001 #[no_alloc] forbids any expression whose effect set includes alloc. Common offenders: Box::new, Vec::push past capacity, String operations, HashMap::insert. Use a pre-sized container, an arena/pool/tlsf allocator (RFC-0002), or refactor the allocation outside the RT path."; };
    if str_eq(code, "RT-002") { return "RFC-0001 #[no_panic] uses a conservative dataflow analysis. Sources of panic include integer overflow on +/-/*, division by zero, out-of-bounds indexing, unwrap() on Option/Result, and explicit panic!(). Use checked_*/wrapping_*/saturating_* arithmetic, guard divisions, use get() instead of [], and prove safety with assume! (RFC-0004)."; };
    if str_eq(code, "RT-003") { return "RFC-0001 #[no_dyn] forbids dynamic dispatch via Box<dyn Trait> or &dyn Trait. Replace with generics (fn f<T: Trait>(x: T)) for static dispatch, or with an enum-based polymorphism pattern."; };
    if str_eq(code, "RT-004") { return "RFC-0009 static WCET analysis estimates the function's worst-case time exceeds the deadline. Inspect the dominant cost in the report; reduce loop bounds, simplify hot paths, or relax the deadline if appropriate."; };
    if str_eq(code, "RT-005") { return "Calls into C/C++ via extern fn are opaque to the analysis. Mark trusted extern declarations with #[ffi_no_alloc] and/or #[ffi_no_panic] (v0.3.24, RFC-0001 §3.5) -- two separate attributes, not one comma-list. #[deadline] callers need BOTH markers (intersection rule). To skip per-symbol annotation: #[allow(RT-005)] (file-wide)."; };
    if str_eq(code, "RT-006") { return "async fn introduces poll-based scheduling and arbitrary suspend points. RT attributes promise bounded time and no allocation; the two are fundamentally incompatible. Refactor the function as sync, or use rod/tokio (RFC-0030) outside the RT path."; };
    if str_eq(code, "ASYNC-001") { return "Workaround: drop the `async` keyword if you want sync execution (the keyword was a no-op pre-v0.5.19, now triggers this warning). For real threading, use `async_spawn(fn_ptr, arg)` to spawn the fn on an OS thread → returns an opaque task handle. Then `async_await(handle)` joins the thread and returns the captured i64 result. See stdlib/rods/async.nr and the RFC-0027 phase 1 commitment to threads-only (no green-thread scheduler, no future polling)."; };
    if str_eq(code, "RT-007") { return "Add #[no_alloc] or #[no_panic] (or both) to the fn -- that makes the deadline reasoning sound. To intentionally suppress: #[allow(RT-007)] (file-wide) or #[allow_fn(RT-007)] (per-fn, v0.3.20). The warning surfaces a likely-incomplete annotation."; };
    if str_eq(code, "RT-008") { return "Deadline analysis cannot bound an unbounded recursion. Annotate the function with #[max_depth = N] per RFC-0014 to give the analyzer a depth bound."; };
    if str_eq(code, "RT-009") { return "Rust's `#[no_panic]` (via the `no_panic` crate) checks at link time. Nucleor checks at build time. The integer-divide-by-zero case is a known gap in Rust's checker too — RT-009 surfaces it explicitly so adopters can decide."; };
    if str_eq(code, "DIAG-001") { return "v0.3.38 enumerated check: the s1 compiler validates the full CODE substring against the canonical diagnostic code set (mirrored in cli_explain_full_smoke). When minting a new code, add to BOTH the s1 compiler's is_known_diag_code fn AND the cli_explain_full_smoke codes array. To suppress DIAG-001 itself during a noisy refactor: #[allow(DIAG-001)]."; };
    if str_eq(code, "ALLOC-001") { return "Per RFC-0002, Box<T, A: Allocator> is bound by the lifetime of A. Returning a Box<T, Arena> from a fn whose Arena is local is rejected. Either pass &Arena into the fn (caller owns the arena), or copy the value into a Box<T, Global> before returning."; };
    if str_eq(code, "ALLOC-002") { return "Allocator type is part of the value type. fn f(x: Box<T, Arena>) cannot accept a Box<T, Pool>. Use generics (fn f<A: Allocator>(x: Box<T, A>)) for allocator-agnostic APIs."; };
    if str_eq(code, "ALLOC-003") { return "RFC-0001 #[no_alloc(...)] accepts an explicit allow-list of allowed allocators. The default #[no_alloc] forbids all four (global/arena/pool/tlsf); narrow with #[no_alloc(global)] etc."; };
    if str_eq(code, "FRAME-001") { return "RFC-0003 typed frames make Pose<World> != Pose<BaseLink> at the type level. To combine, look up the transform: tf.lookup::<World, BaseLink>(time).apply(pose_world)."; };
    if str_eq(code, "FRAME-002") { return "Transform composition Transform<A,B> * Transform<C,D> requires B == C. The compiler enforces the chain at compile time. Reorder, invert one transform, or look up an intermediate."; };
    if str_eq(code, "FRAME-003") { return "Applying a Transform<From, To> requires the target value to be in the From frame. Convert via lookup of the appropriate transform."; };
    if str_eq(code, "OWN-001") { return "Borrow-checker classic: a value was moved (consumed) into a struct, fn argument, or another binding. Subsequent reads of the original would alias freed memory. Fix: clone the value before the move (if `T: Clone` is satisfied), restructure to take a reference, or sequence the code so the original isn't read after the move. The compiler shows the move site and the use site."; };
    if str_eq(code, "OWN-002") { return "OWN-002 fires when you try to *borrow* a value that was previously moved. The borrow target no longer exists at the source binding (the value has moved elsewhere). Same fix as OWN-001 — clone or restructure."; };
    if str_eq(code, "OWN-003") { return "Move-while-borrowed: an outstanding `&T` or `&mut T` would dangle if the source moves. The compiler tracks active borrows and rejects moves that would invalidate them. Sequence so the borrow ends before the move (typically by ending the borrow's lexical scope)."; };
    if str_eq(code, "OWN-004") { return "Two simultaneous `&mut T` of the same value would alias mutable memory — Nucleor (like Rust) forbids this at compile time. Sequence the borrows so they don't overlap, or use Atomic<T> / per-thread split for genuine cross-thread sharing."; };
    if str_eq(code, "OWN-005") { return "Cannot create `&T` while `&mut T` of the same value is live — the shared reader could observe the mutator mid-update. Drop the mutable borrow first, then take the shared one."; };
    if str_eq(code, "OWN-006") { return "`&T` is read-only by definition. Trying to assign through it is a category error. Either change the binding to `&mut T` (which requires the source to be `let mut`), or use Cell/RefCell for interior mutability (with the runtime borrow-tracking cost)."; };
    if str_eq(code, "OWN-007") { return "Assigning to a location that is currently borrowed (or whose enclosing struct is borrowed) would invalidate the borrow — the borrowed value would disappear or change underneath the borrow holder. Drop the borrow first."; };
    if str_eq(code, "OWN-008") { return "`let x` declares an immutable binding; subsequent `x = ...` is rejected. Use `let mut x` to make the binding mutable. (Note: `let mut x = 5; let x = x + 1;` is also valid — the second `let` shadows the first as a new binding.)"; };
    if str_eq(code, "OWN-009") { return "Returning `&local` from a function returns a reference to stack memory that's freed at function exit. Either return the value by-move (which transfers ownership), allocate on the heap and return Box<T>, or take a `&mut Out` parameter and write into it."; };
    if str_eq(code, "OWN-010") { return "Inner-block lifetime escape: `let r = { let x = 5; &x };` would leave `r` pointing at freed `x`. The compiler tracks scope-exit destruction and rejects bindings that would outlive their referent. Move the source value out to the outer scope, or hold by value rather than reference."; };
    if str_eq(code, "OWN-011") { return "`&mut T` requires the source to be declared `let mut`. Add `mut` to the binding, or use `&T` if you don't actually need to write through the reference."; };
    if str_eq(code, "OWN-012") { return "Arenas free all their backing storage on destroy. If any reference into the arena is still live, the destroy would dangle every outstanding pointer. End all borrows from the arena (typically by exiting the scope where they live) before destroy."; };
    if str_eq(code, "OWN-013") { return "Spawn-capture pass detected a `spawn { ... }` block capturing a `DeviceBuffer` value. GPU memory handles are pinned to the thread that allocated them via the CUDA / Vulkan context binding — the worker thread that spawn dispatches to has no context attached, so the capture would be undefined behavior at runtime. Either keep the launch on the owning thread (process the buffer there before spawning the consumer), or pass a host-side handle (CPU-side index / descriptor) that the worker re-acquires its own DeviceBuffer from with its own context."; };
    if str_eq(code, "RACE-001") { return "Add an explicit `impl Sendable for T {}` when the type is safe to move across tasks, or keep the value on the originating thread."; };
    if str_eq(code, "RACE-002") { return "Await actor method calls so the actor executor serializes access."; };
    if str_eq(code, "RACE-003") { return "Expose actor state through an actor method instead of reading or assigning fields directly."; };
    if str_eq(code, "RACE-004") { return "Wrap shared mutable payloads in an actor or an audited synchronization primitive."; };
    if str_eq(code, "RACE-005") { return "Do not pass `&mut T` to spawn/thread APIs; move an owned Sendable value or pass a synchronized handle."; };
    if str_eq(code, "RACE-006") { return "Refactor the actor method to avoid re-entering the same actor while its lock is held."; };
    if str_eq(code, "RACE-007") { return "Move the actor await out of the deadline region or use scheduler-aware actor latency tooling when it lands."; };
    if str_eq(code, "RACE-008") { return "Remove `#[not_sendable]` only if the type is genuinely thread-safe; otherwise keep it out of spawned work."; };
    if str_eq(code, "RACE-009") { return "Reserved diagnostic; no user action."; };
    if str_eq(code, "RACE-010") { return "Reserved diagnostic; no user action."; };
    if str_eq(code, "GOV-001") { return "The `@policy(require_authored)` module-level attribute requires every fn in the source to carry an `@authored(\"name\")` annotation (the governance audit trail). The audit pass found at least one un-annotated fn. Add `@authored(\"...\")` above each fn, or remove the policy if it doesn't apply to this module."; };
    if str_eq(code, "GOV-002") { return "The `@policy(no_unsafe)` module-level attribute forbids `unsafe { ... }` blocks anywhere in the source. The audit pass found at least one. Either remove the unsafe block (preferred — usually means switching to a safe API) or remove the no_unsafe policy if the module legitimately needs unsafe operations."; };
    if str_eq(code, "TNT-001") { return "Strict-mode taint pass detected tainted data flowing into a function annotated as a sensitive sink. The suggestion is to wrap the value in `sanitize(value)` (which strips the taint marker) before the call. Fires from the tools-suite strict checker, not the s1 main type-check pass."; };
    if str_eq(code, "TYP-001") { return "**Legacy** non-exhaustive-match warning. Unified under the canonical MATCH-001 (RFC-0016) in v0.5.18. The main compiler no longer emits TYP-001; only MATCH-001 fires (with identical text). The explain entry stays so existing docs that reference TYP-001 still resolve to a meaningful description."; };
    if str_eq(code, "TYP-002") { return "Booleans aren't numeric — `true + false`, `bool * bool`, etc. are rejected. The arithmetic operator type-check (in check_expr's binop branch) fires TYP-002 when either operand resolves to bool."; };
    if str_eq(code, "TYP-003") { return "RFC-0005 — adding `unit<T,m>` and `unit<T,s>` is dimensionally invalid (length-plus-time has no physical meaning). Convert one to the other via the appropriate physical relationship, or use multiplication (`unit<T,m> * unit<T,1/s>` produces `unit<T,m/s>`)."; };
    if str_eq(code, "TYP-004") { return "The `*` (deref) operator is defined only on `&T`, `&mut T`, and `Box<T>`. Applying it to a value type, struct field by value, or i64/f64 is a category error — those are already values, not references to values."; };
    if str_eq(code, "TYP-005") { return "Argument arity mismatch. The function declares N parameters; the call site passed M ≠ N. Check the function signature and the call site. Variadic dispatch isn't supported in v0.2."; };
    if str_eq(code, "TYP-006") { return "Argument N has type incompatible with parameter N's declared type. Includes the taint-marker case: passing `T tainted` to a parameter declared as plain `T` (or vice-versa) fires TYP-006 rather than a separate TAINT-* code."; };
    if str_eq(code, "TYP-007") { return "RFC-0005 unit values must be initialized via the unit constructor (e.g. `meters(5.0)`, not `5.0` alone). A bare numeric literal doesn't carry the dimension tag and would silently mix units when assigned to a `unit<...>` binding."; };
    if str_eq(code, "TYP-008") { return "`let x: T = expr` requires `expr` to type-check as `T` (or coerce per the type lattice in RFC-0015 §3). Includes taint-marker mismatches between the declared type and the expression's type."; };
    if str_eq(code, "TYP-009") { return "After the initial bind, `x = expr` requires `expr` to match `x`'s declared type. Re-binding to a different type isn't allowed without a fresh `let` shadowing (which creates a new binding rather than re-typing the existing one)."; };
    if str_eq(code, "TYP-010") { return "`return expr` (or implicit tail-expression return) requires `expr` to type-check as the function's declared `-> T`. Body type and signature type must agree."; };
    if str_eq(code, "TYP-011") { return "Nucleor's i64-everywhere ABI lowers `+` to integer addition. For `str + str` that meant adding two string pointers as i64, producing a garbage pointer that SIGSEGVed when later passed to a string helper (e.g. `print_str`). Pre-v0.4.51 this was silent at compile time. v0.4.51 promotes the pattern to a hard error pointing at `str_concat(a, b)`. Reasoning: the canonical Rust idiom `&str + &str` doesn't compile in Rust either, so adopters expected a compile error and got runtime garbage instead."; };
    if str_eq(code, "TYP-012") { return "Struct constructor expressions like `Point { x: 1, y: 2 }` must list ALL declared fields. Pre-v0.4.62 the lower silently zero-initialized any missing field — equivalent to a quiet `field: 0` (or `field: \"\"` for str). Rust errors here with E0063, so adopters writing the canonical idiom got a wrong value with no compile-time signal. Workaround: list every field explicitly, OR write a `Point::new(x, y)` constructor fn that supplies the rest."; };
    if str_eq(code, "TYP-013") { return "Pre-v0.4.63 `Point { x: 1, y: 2, z: 3 }` for a 2-field Point silently dropped the extra field — the lower walked the init list in declared order, so any extra entries past the declared count were ignored. Rust errors here with E0560 — adopters writing canonical struct literals got a quiet wrong shape. Either remove the unknown field from the literal, or add it to the struct definition."; };
    if str_eq(code, "TYP-026") { return "For `as char`, keep invalid constants out of the cast and guard dynamic codepoints before casting. For missing returns, audit every control-flow path and make the returned value explicit; side-effect-only functions should return void."; };
    if str_eq(code, "TYP-027") { return "Add a concrete type annotation or route the expression through a helper whose return type is known to the type checker. For collection helpers, prefer typed methods or explicit wrappers until strict inference becomes the default."; };
    if str_eq(code, "TYP-044") { return "Cast explicitly with `as` at the binding site, or change the annotation to the expression's real integer width."; };
    if str_eq(code, "FMT-002") { return "`println!(\"{}\", value)` previously fell through to `int_to_str(value)` for struct values, printing an ABI handle instead of user-facing text. The format expander now hard-errors unless the struct has a Display impl; `println!(\"{:?}\", value)` remains the structural debug path."; };
    if str_eq(code, "FMT-003") { return "Pre-v0.5.11 `format!(\"just {}\", 1, 2, 3)` silently dropped args 2 and 3 — the format expander walked the placeholders and stopped at the first arg, leaving the rest unevaluated/unreferenced. Adopter typos (left an arg after removing a placeholder) and refactor mistakes (renamed a placeholder, kept the arg) hit silently. v0.5.11 mirrors the v0.4.70 placeholder>args check direction so both asymmetries halt cleanly. Side-effecting expressions in dropped args (e.g. `format!(\"{}\", 1, expensive_call())`) no longer evaluate-then-discard."; };
    if str_eq(code, "TRAIT-001") { return "The `?` operator propagates the Err payload early. When the callee error type and enclosing function error type differ, Nucleor now performs the Rust-style `From<SrcErr> for DstErr` conversion. If that impl is absent, continuing would either return the wrong payload layout or silently expose the source error type through the destination API, so the compiler stops with TRAIT-001."; };
    if str_eq(code, "NUM-001") { return "Nucleor models on Rust: numeric types are distinct, no implicit conversion. Cast explicitly with `as`. Reasoning: silent conversions are a recurring bug source (truncation, sign extension)."; };
    if str_eq(code, "NUM-002") { return "Numeric literal exceeds the declared type's range — e.g. 256u8, -1u32, 4_000_000_000i32. Use a wider type or change the literal."; };
    if str_eq(code, "NUM-003") { return "Casting f64 to i32, i64 to i8 etc. may lose precision or wrap. The warning surfaces the risk; if intentional, suppress with #[allow(precision_loss)] on the call site."; };
    if str_eq(code, "NUM-004") { return "RFC-0015 §3.4 — f8e4m3 / f8e5m2 (NVIDIA Hopper formats), f16 (IEEE half), and bf16 (Brain float) need hardware support to be fast. Without it the operation is emulated via f32 conversion in the runtime. The warning is informational; suppress with #[allow(no_hw_lp_float)] or move the kernel to a target that has the instruction set."; };
    if str_eq(code, "NUM-005") { return "usize/isize represent platform-pointer-width values used for indices and pointer arithmetic. Mixing with explicit i64/u64 risks portability bugs across 32-/64-bit targets."; };
    if str_eq(code, "NUM-006") { return "Signed and unsigned types of the same width are distinct. Cast explicitly to make the conversion intent visible at the call site. Storage is i64-uniform under the hood, but the type system enforces sign-discipline."; };
    if str_eq(code, "NUM-007") { return "Float→int cast in Rust semantics saturates (3e9 as i32 = i32::MAX, NaN as i32 = 0). Catches the silent-truncation bug class C inherits from its float→int rules."; };
    if str_eq(code, "NUM-008") { return "Shifting by >= the operand width is UB in C and panics in Rust debug mode. Nucleor matches Rust's release-mode wrapping shift; debug-mode trap will land with #[overflow(trap)] phase 7.2."; };
    if str_eq(code, "NUM-009") { return "C/C++ has no compile-time-evaluation contract; Rust's `const fn` enforces purity at the type-checker level. Nucleor's @const_fn now matches Rust: if the body could run effects at runtime, it can't be evaluated at compile time, so it's rejected. Phase 2 will actually evaluate and fold pure const_fn bodies."; };
    if str_eq(code, "PERF-1") { return "Tier validation lives at the router (powershell wrapper) so the compiler is never invoked with a malformed --tier; Phase 2 wires the value through. This matches Rust's split between `cargo` and `rustc` flag validation."; };
    if str_eq(code, "PERF-2") { return "C++ has no `@hot` annotation; profile-guided optimization is the closest analogue. Rust's `#[inline(always)]` is a hint, not a contract. Nucleor's @hot is checker-enforced (Phase 1 warning, Phase 2 will promote some violations to error)."; };
    if str_eq(code, "PERF-3") { return "Rust's clippy has the `needless_collect` lint and similar; this PERF-3 is the simpler ancestor — just don't allocate per iteration. C++ relies on profilers to catch this; Nucleor surfaces it at compile time."; };
    if str_eq(code, "NUM-009") { return "Constant-folded division by zero is detectable at compile time and almost always a bug. The runtime trap costs cycles in hot loops; surface it earlier."; };
    if str_eq(code, "NUM-010") { return "f64 → f32 narrowing rounds to nearest representable f32, which is exact for many literals (1.0, 0.5, 2.5) but loses precision on others (0.1, 1/3). The warning is informational."; };
    if str_eq(code, "NUM-011") { return "#[overflow(trap)] + wrapping_add inside the same fn produces inconsistent semantics — wrapping always wraps regardless of attribute. Refactor to use the matching primitive."; };
    if str_eq(code, "NUM-012") { return "Pointer-int cast portability: 32-bit targets have 32-bit pointers; 64-bit targets have 64-bit pointers. Use usize/isize for round-trip safety; explicit i32/i64 risks losing bits on the wrong target."; };
    if str_eq(code, "NUM-013") { return "Vec<T> monomorphization (Phase 8) currently supports primitives + flat structs. Generic / trait-object element types need a vtable layer that lands later."; };
    if str_eq(code, "NUM-014") { return "sizeof_struct is compile-time-constant; the struct must be statically known. Generic struct parameters (Vec<T> field of an outer struct) defer to runtime via a separate sizeof query."; };
    if str_eq(code, "NUM-015") { return "ABI stability matters when other languages call into Nucleor-compiled libraries. Stick to the C-stable types; Vec / str / generics need a manual marshalling layer."; };
    if str_eq(code, "NUM-016") { return "Equal-width sign mismatch is the C 'comparing -1 to 0xFFFFFFFF' bug — the comparison silently sign-extends and yields wrong answers. Always cast first."; };
    if str_eq(code, "NUM-017") { return "Right-shift on a signed integer preserves the sign bit (arithmetic shift). For -8 >> 1, you get -4 (arithmetic) or 0x7FFF...FC (logical). Pick the helper matching your intent."; };
    if str_eq(code, "NUM-018") { return "Integer context expects an integer; a float literal there is almost always a typo. If you intended a truncating conversion, write it explicitly with `as`."; };
    if str_eq(code, "NUM-019") { return "Unsigned types can't represent negative values. -1u32 as a literal is rejected; (-1 as u32) compiles and gives u32::MAX (the wrap result)."; };
    if str_eq(code, "NUM-020") { return "Mixed-width comparison forces a widening conversion. Make it explicit so the reader sees which operand is being widened and why."; };
    if str_eq(code, "NUM-021") { return "For oversized literals, reduce the literal or use a wide-int library. For const expressions, use an explicit wrapping_* / saturating_* helper, reduce the value, or move the calculation to runtime if wrapping is intentional."; };
    if str_eq(code, "NUM-022") { return "Pre-v0.4.137 the compiler silently coerced int↔float at binop sites; user programs got wrong results because LLVM's fcmp on bit-cast operands compares bit patterns, not values. NUM-022 turns the silent miscompute into a compile-time error so the cast intent is explicit."; };
    if str_eq(code, "NUM-023") { return "`as` is for numeric truncation/extension. `f64 as str` and `bool as str` were silent no-ops that returned an undefined pointer (URGENT — could SIGSEGV). NUM-023 rejects the cast and points at `str_from_float` / `str_from_bool`."; };
    if str_eq(code, "NUM-024") { return "Audit-only. Nucleor's call ABI forwards every value as i64 regardless of the param's declared type. v0.4.221's attempt to trunc-on-entry broke the compiler's self-build because `str_from_int(n: i32)` was called with i64 magnitudes; v0.4.230 widened that signature and the audit surface dropped to 0/0. NUM-024 is now a permanent regression gate — any new declared-iN param called with a wider source-level type fires the warning."; };
    if str_eq(code, "MATCH-001") { return "The match must cover every variant of the discriminant type, or use a wildcard (_) arm. Compiler shows the missing case."; };
    if str_eq(code, "MATCH-002") { return "Patterns are tested in order. A later arm cannot match if an earlier arm covers all values it would handle."; };
    if str_eq(code, "MATCH-003") { return "All arms in a match expression must yield the same type. Cast or restructure to align."; };
    if str_eq(code, "MATCH-004") { return "The ? operator desugars to `match e { Ok(v) => v, Err(e) => return Err(e) }`. The function must return Result (or Option for option-?) for the desugar to type-check."; };
    if str_eq(code, "MATCH-005") { return "RFC-0016 §3.7 — implement `From<SourceError> for TargetError` (or use a single boxed error type). The ? desugar inserts the conversion automatically."; };
    if str_eq(code, "MATCH-006") { return "Use unwrap_or, unwrap_or_else, ?, or match in #[no_panic] context. The compiler treats unwrap as may_panic."; };
    if str_eq(code, "MATCH-007") { return "RFC-0023 §3.1 — swap the bounds. Half-open ranges `1..5` exclude the upper bound and have the same restriction."; };
    if str_eq(code, "MATCH-008") { return "RFC-0023 §3.2 — every alternative must bind the same names with compatible types. Restructure the patterns so each path produces an identical binding set."; };
    if str_eq(code, "MATCH-009") { return "RFC-0023 §3.4 — at most one wildcard prefix/middle/suffix per slice pattern. Restructure to a non-overlapping decomposition."; };
    if str_eq(code, "MATCH-010") { return "RFC-0023 §3.3 — pick a fresh identifier for the binding, or `let outer = outer;` to make shadowing explicit before the match."; };
    if str_eq(code, "MATCH-011") { return "RFC-0023 §3.5 — restructure each arm to yield the same type. Use a common ancestor (often `i64`) or split the match into kind-specific branches that don't merge."; };
    if str_eq(code, "MATCH-012") { return "RFC-0023 §3.6 — replace `Point { x: 0, y: 0 }` with `Point { x, y } if x == 0 && y == 0 => ...`. Field-equality literal patterns ship in v0.5+ once nested-pattern lowering is wired."; };
    if str_eq(code, "MATCH-013") { return "Float pattern matching is intentionally unsupported (NaN ≠ NaN; round-off drift). Use an `if`-chain with tolerance, OR convert the float to a scaled integer (`(x * 100.0) as i32`) and match on the integer. Pre-v0.4.206 the compiler crashed with ACCESS_VIOLATION on this construct; now halts with a clear MATCH-013."; };
    if str_eq(code, "MATCH-014") { return "Use a guard today: `_ if value >= -10 && value <= -1 => ...`, or shift the matched domain before matching so the range bounds are non-negative literals. Full negative-bound range parsing needs unary-minus support in pattern grammar."; };
    if str_eq(code, "MATCH-015") { return "Use a guard today: `_ if x == -5 => ...`. Full negative literal pattern parsing ships alongside MATCH-014's range-bound fix."; };
    if str_eq(code, "MATCH-016") { return "Either name the matching enum constructor (e.g. `A::Red` for a scrutinee of type `A`) or restructure to dispatch over the actual scrutinee enum. Lane 1 audit close (F-002) wires the structural check; the diagnostic is gated on the type-checker having scrut_t populated for the match site."; };
    if str_eq(code, "ASSUME-001") { return "RFC-0004 §3.2 lists the predicate vocabulary the analyzer understands: x < N, x != 0, arr.len() == N, opt.is_some(), result.is_ok(), equality substitution. Other predicates are accepted as runtime checks but contribute nothing to static analysis."; };
    if str_eq(code, "ASSUME-002") { return "RFC-0004 §3.6 — assume_unchecked! is a footgun for extreme RT loops. Document why the runtime check is too costly to justify."; };
    if str_eq(code, "ASSUME-003") { return "RFC-0004 §3.9 — the compiler simplified the predicate to TRUE; the assume! adds no information for the analyzer and the runtime check is dead code. Delete the assume!."; };
    if str_eq(code, "ASSUME-004") { return "The compiler proved the predicate is unsatisfiable at this program point. The assume! is wrong."; };
    if str_eq(code, "ASSUME-005") { return "RFC-0004 §3.1 — in --profile=cert every assume! must be discharged. The proof obligation goes to the SMT pipeline; if neither prove nor refute is reached the cert build fails. Add a justification comment, derive the predicate from a stronger fact in scope, or weaken the assume."; };
    if str_eq(code, "UNIT-001") { return "RFC-0005 §3.1 — units form a 7-dimensional polynomial. Add/sub require equal dimensions; mul/div produce sums/differences of dimension exponents."; };
    if str_eq(code, "UNIT-002") { return "RFC-0005 §3.4 — silent unit conversions are exactly the bug class typed units exist to prevent."; };
    if str_eq(code, "UNIT-003") { return "RFC-0005 §3.1 — unit exponents must be compile-time integer constants (positive or negative). Runtime-computed powers don't form a valid unit type. Refactor to use a fixed exponent or wrap in a dimensionless helper."; };
    if str_eq(code, "UNIT-004") { return "RFC-0005 §3.3 — alias library lives in stdlib/rods/units_si.nr (SI), units_imperial.nr, units_robotics.nr."; };
    if str_eq(code, "UNIT-005") { return "RFC-0005 — @law annotations carry through unit checking. If the LHS and RHS of the law reduce to different unit dimensions the law is dimensionally wrong; review the law's algebra."; };
    if str_eq(code, "CONTRACT-001") { return "RFC-0006 §3.2 — #[require] is checked at the call site (debug profile) or assumed (release). Either fix the call or relax the require."; };
    if str_eq(code, "CONTRACT-002") { return "RFC-0006 §3.3 — #[ensure] is checked at function exit. The function returned a value or modified state in a way that violated the contract."; };
    if str_eq(code, "CONTRACT-003") { return "RFC-0006 §3.4 — invariants checked on entry to + exit from every public method. Either restore the invariant before the method ends or weaken the invariant."; };
    if str_eq(code, "CONTRACT-004") { return "RFC-0006 §3.5 — Liskov substitution principle. Trait impls cannot weaken preconditions; the impl must satisfy at least the trait's #[require]."; };
    if str_eq(code, "CONTRACT-005") { return "RFC-0006 §3.5 — the dual of CONTRACT-004. An impl that promises strictly more than the trait breaks substitutability when callers swap the impl through a trait object. Match the trait's #[ensure] verbatim or weaken."; };
    if str_eq(code, "CONTRACT-006") { return "RFC-0006 §3.3 — old(expr) snapshots the value at function entry. If expr was mutated by the body, old(...) sees the post-mutation value because no entry snapshot was taken. Capture explicitly: `let _entry_x = x; ... old(x) = _entry_x;`."; };
    if str_eq(code, "CONTRACT-007") { return "RFC-0006 — in --profile=cert, every contract is SMT-discharged. The solver could not prove the predicate. Strengthen the require/ensure with an additional clause that closes the gap, or annotate `#[contract(approximate)]` to fall back to runtime check."; };
    if str_eq(code, "CONTRACT-008") { return "Remove `result` from the ensure predicate, or give the function a concrete return type if the contract is meant to constrain the returned value."; };
    if str_eq(code, "CONTRACT-009") { return "Unset NUCLEOR_DBC_MODE for debug behavior, or set it explicitly to debug, safe-release, release, or cert."; };
    if str_eq(code, "CONTRACT-010") { return "Move the old(...) check into #[ensure(...)] or compare directly against the incoming parameter in #[require(...)]."; };
    if str_eq(code, "CONTRACT-011") { return "Check spelling of the identifier; rewrite the predicate to compare against a fn parameter; or qualify with a path / fn-call / field-access if it's actually a module-level reference."; };
    if str_eq(code, "ATOMIC-001") { return "RFC-0007 §3.3 — #[atomic] is the inter-thread RT contract. Use Atomic<T> ops, SpscQueue/MpmcQueue.try_push/try_pop, and avoid all blocking primitives."; };
    if str_eq(code, "ATOMIC-002") { return "RFC-0007 §3.3 — see RT-001."; };
    if str_eq(code, "ATOMIC-003") { return "RFC-0007 — Cell/RefCell rely on runtime borrow tracking that may panic; #[atomic] forbids panicking flow because it would break atomicity guarantees. Replace with Atomic<T> or AtomicCell<T>."; };
    if str_eq(code, "ATOMIC-004") { return "RFC-0007 §3.2 — compare_exchange takes (success_ordering, failure_ordering); failure cannot be stronger than success and cannot be Release/AcqRel (since failure does not perform a write). Compiler enforces the ordering lattice as defined by the C++/Rust memory model."; };
    if str_eq(code, "ATOMIC-005") { return "RFC-0007 §3.2 maps MemOrder to LLVM atomic ordering keywords. LLVM rejects release/acq_rel loads and acquire/acq_rel stores; use Acquire/SeqCst for loads and Release/SeqCst for stores."; };
    if str_eq(code, "ATOMIC-006") { return "Call the atomic helper directly from a regular function body instead of wrapping it in a closure until closure scope inheritance lands."; };
    if str_eq(code, "ISR-001") { return "RFC-0008 first pass — hardware-entered handlers must be `fn() -> void` with no params and no return value."; };
    if str_eq(code, "ISR-002") { return "RFC-0008 first pass — `#[isr]` rejects `#[deadline]`; use ISR-specific latency/vector tooling instead of deadline wrappers."; };
    if str_eq(code, "ISR-003") { return "RFC-0008 first pass — target-specific interrupt calling conventions are enabled only for cortex-m4f and rv32imac; other targets fail closed."; };
    if str_eq(code, "ISR-004") { return "RFC-0008 §3.1 — vector names are target-specific. The PAC for your MCU is in stdlib/embedded/<target>/vectors.nr."; };
    if str_eq(code, "ISR-005") { return "RFC-0008 §3.3 — the vector table maps each interrupt source to exactly one handler. Two #[isr]'s claiming the same vector is ambiguous; either combine them, or use a software dispatch shim."; };
    if str_eq(code, "ISR-006") { return "RFC-0008 §3.1 — Cortex-M NVIC priority bit-width varies (typically 3 or 4 bits = 8 or 16 priority levels). Check stdlib/embedded/<target>/nvic.nr for your chip's priority range."; };
    if str_eq(code, "ISR-007") { return "v0.6.32 — `#[isr(prio = N)]` requires N to be a non-negative integer literal. Pre-fix the prio attribute parser silently accepted negative-int (`-1`), string-literal (`\"high\"`), and missing-value (bare `prio`) shapes; v0.6.32 catches them at the attribute site."; };
    if str_eq(code, "ISR-008") { return "v0.6.31 — `#[isr]` may only be applied to fn items. Pre-fix the attribute was silently dropped on non-fn items AND leaked to the next fn in the file, producing a misleading ISR-001 diag pointing at the wrong fn (typically `main`). Originally shipped under ISR-004; renamed to ISR-008 in v0.6.32 because ISR-004 is reserved for the planned 'vector name not recognized' diag (RFC-0008 §3.1)."; };
    if str_eq(code, "WCET-001") { return "RFC-0009 §3.5 — Heptane needs a static call graph. dyn Trait or fn-pointer dispatch makes the callee unknown. Either rewrite as monomorphized static dispatch or annotate with #[wcet_dispatch_table(...)] listing the candidate targets."; };
    if str_eq(code, "WCET-002") { return "RFC-0009 §3.2 — Heptane needs trip counts to bound loops. Annotate the loop with #[loop_bound(N)] or assert the array length with assume!(arr.len() == N) before entering."; };
    if str_eq(code, "WCET-003") { return "RFC-0009 §3.3 — static WCET upper bound exceeds the declared deadline. The diagnostic shows the dominant cost path. Reduce loop bounds, simplify hot expressions, or relax the deadline."; };
    if str_eq(code, "WCET-004") { return "RFC-0009 §3.5 — same root cause as WCET-001 but specifically for fn pointers stored in a struct field or passed as an argument. Provide a #[wcet_dispatch_table] for the fn-pointer site."; };
    if str_eq(code, "WCET-005") { return "RFC-0009 + RFC-0014 — Heptane unrolls recursive calls up to #[max_depth]; if the analysis exceeds the bound, raise it (paying for the WCET cost) or eliminate the recursion."; };
    if str_eq(code, "WCET-006") { return "RFC-0009 — internal Heptane error. Re-run with `nuc dump --wcet-il -o /tmp/wcet.il` and file a bug attaching the IL dump."; };
    if str_eq(code, "DLPACK-001") { return "RFC-0010 §3.3 — DLPack defines device kinds (1=CPU, 2=CUDA, 3=CPUPinned, 4=OpenCL, ...). Nucleor binds the subset its target supports. Re-export with kind=1 (CPU) or recompile against a target that includes the device."; };
    if str_eq(code, "DLPACK-002") { return "RFC-0010 §3.4 — DLPack dtype is a (code, bits, lanes) triple. Code 0=Int, 1=UInt, 2=Float, 3=BFloat, 4=Complex, 5=Bool. The supplied combination doesn't map to a Nucleor numeric type."; };
    if str_eq(code, "DLPACK-003") { return "RFC-0010 §3.2 — bind sites can carry static shapes via Tensor<Shape>. The runtime-discovered shape must agree, or upstream must reshape."; };
    if str_eq(code, "DLPACK-004") { return "RFC-0010 §3.5 — DLPack tensors expose strides; if not contiguous and copy_on_import is false, Nucleor refuses (a copy would be unexpected). Either pass copy_on_import=true or contiguify upstream (np.ascontiguousarray, .contiguous(), etc.)."; };
    if str_eq(code, "DLPACK-005") { return "RFC-0010 §3.1 — DLPack's struct layout has versioned. The producer is on an older ABI than this Nucleor build. Upgrade the producer."; };
    if str_eq(code, "CXX-001") { return "RFC-0011 §3.1 — #[cxx_include(\"...\")] resolves under --include-path / NUCLEOR_CXX_INCLUDE_PATH. Add the path or move the header."; };
    if str_eq(code, "CXX-002") { return "RFC-0011 §3.3 — nuc-cxx parses the C++ header with libclang and compares the extracted signature with the Nucleor extern \"C++\" declaration. Mismatches must be reconciled in one direction."; };
    if str_eq(code, "CXX-003") { return "RFC-0011 §3.2 — std::function is type-erased and uses dynamic dispatch (typically allocating a heap functor). #[no_dyn] forbids both. Replace with a concrete callable or opt out at the call site."; };
    if str_eq(code, "CXX-004") { return "RFC-0011 §3.1 — types crossing the bridge must have layout the C++ side can rely on. Add #[repr(C)] to make the layout C-stable."; };
    if str_eq(code, "CXX-005") { return "RFC-0011 §5 — Nucleor frames don't unwind through C++ exceptions; the runtime intentionally aborts on uncaught C++ exceptions to preserve safety. Wrap the C++ call site in a try/catch that converts to Result<T, CxxError>."; };
    if str_eq(code, "BINDGEN-001") { return "RFC-0012 §3.1 — bindgen.toml's [headers] section lists C headers; each must resolve under --include-path. Either add the path or fix the spelling."; };
    if str_eq(code, "BINDGEN-002") { return "RFC-0012 §4 — libclang emitted parse errors. Common causes: missing #defines, missing system headers (add a sysroot), or C++ syntax in a .h file. Pass --extra-clang-arg='-D...' or '-isystem...'."; };
    if str_eq(code, "BINDGEN-003") { return "RFC-0012 §3.2 — some C types have no Nucleor analog (GCC vector extensions, _Complex, __int128 on 32-bit targets). Either add a manual wrapper or skip the symbol with bindgen.toml [skip]."; };
    if str_eq(code, "BINDGEN-004") { return "RFC-0012 §3.2 — `struct foo;` with no struct definition leaves the type opaque. Either #include the file that defines it (so libclang can extract the layout) or mark it opaque in bindgen.toml [opaque] (compiler will treat it as a void* handle)."; };
    if str_eq(code, "BINDGEN-005") { return "RFC-0012 — duplicate symbol from two #include paths. Resolve via [keep_only] in bindgen.toml or by reordering includes so the canonical definition wins."; };
    if str_eq(code, "URDF-001") { return "RFC-0013 §3.2 — frame chain compile-time check. The compiler walks every imported URDF and could not find a transform path between the two named frames. Either import a URDF that connects them or add a #[urdf_attach] joint."; };
    if str_eq(code, "URDF-002") { return "RFC-0013 §3.3 — multiple URDF imports produce disjoint trees. #[urdf_attach(parent_frame, child_frame)] declares the joint that bridges them; without it the compiler refuses cross-tree transforms."; };
    if str_eq(code, "URDF-003") { return "RFC-0013 — the kinematic graph must be a DAG (rooted at base_link). A cycle suggests either a malformed URDF or two #[urdf_attach] joints that close a loop. Remove one of the bridging joints."; };
    if str_eq(code, "URDF-004") { return "RFC-0013 §3.1 — #[urdf_load(\"path/to/robot.urdf\")] resolves relative to the source file's directory. Check the path and ensure the URDF is in source control or a known asset dir."; };
    if str_eq(code, "URDF-005") { return "RFC-0013 §3.1 — URDF parser uses minixml; common parse errors include missing <robot> root, malformed <joint type=\"...\"> attributes, mismatched origin tags, and unsupported plugin tags. Validate the URDF with `urdf-validator` first."; };
    if str_eq(code, "URDF-006") { return "RFC-0013 §3.4 — joint limits are declared in the URDF as <limit lower upper effort velocity/>. lookup() with an out-of-range angle/displacement is rejected. Clamp upstream or relax the URDF limit if mechanically valid."; };
    if str_eq(code, "DEPTH-001") { return "RFC-0014 structural proof requires a visible counter and a guard. Unmarked callback paths, missing guards, or non-positive/non-literal recursive updates are rejected conservatively."; };
    if str_eq(code, "DEPTH-002") { return "RFC-0014 compared the proven guard depth with the declared N and found the code needs more stack frames than the annotation allows. Raise N or reduce the recursion depth."; };
    if str_eq(code, "DEPTH-003") { return "RFC-0014 SCC analysis found a cycle whose member bounds do not compose. Give every function in the cycle compatible guards/bounds or refactor through a single trampoline."; };
    if str_eq(code, "DEPTH-004") { return "RFC-0014 only accepts fn-level #[max_depth = N] / #[max_depth(N)] with a positive integer literal. Other placements and symbolic values are rejected."; };
    if str_eq(code, "DEPTH-005") { return "RFC-0014 stack-budget check multiplies declared depth by estimated frame size. Reduce locals/frame size, reduce N, or convert recursion to iteration."; };
    if str_eq(code, "LAW-001") { return "`nuc test --check-laws` generated a bounded integer check for a low-risk @law annotation and found a counterexample, or the declaration is arity-incompatible with the annotated function (or, for `inverse = g`, the partner name is missing). The checker currently covers commutative, associative, identity, absorbing, idempotent, involution, distributive_over, and unary inverse forms; broader random Arbitrary generation, fusion generation, float tolerance handling, and cert-profile SMT proofs remain queued."; };
    if str_eq(code, "LAW-002") { return "RESERVED. Phase 3 of RFC-0031 will route @law through Z3/CVC5 SMT proof under --profile=cert. As of v0.8.265 (Phase 1) no solver runs; LAW-002 is reserved for future emission."; };
    if str_eq(code, "LAW-003") { return "RESERVED. Phase 2 of RFC-0031 will pattern-match @law citations during the optimizer's law-rewrite pass. As of v0.8.265 the law-rewrite pass (`opt_law_rewrite_block`) is a metadata-only no-op; LAW-003 is reserved for emission once the rewrite path has real semantics."; };
    if str_eq(code, "LAW-004") { return "`nuc test --check-laws` now emits this when a law uses `eps` or `approximate` before the float tolerance contract ships. Add an integer-only bounded law, or wait for the RFC-0031 float tolerance phase."; };
    if str_eq(code, "LAW-006") { return "`nuc test --check-laws` rejects the deprecated alias `zero = Z`; rename to `absorbing = Z` per the canonical schema (docs/spec/Nucleor_Algebraic_Laws_Schema.md section 3)."; };
    if str_eq(code, "LAW-007") { return "`nuc test --check-laws` rejects bare `distributive` because the partner operator is required; rename to `distributive_over = g` per the canonical schema."; };
    if str_eq(code, "LAW-008") { return "`nuc test --check-laws` rejects any law name not in the canonical set (commutative, associative, identity, idempotent, involution, absorbing, distributive_over, inverse, fusion). The canonical set is locked at docs/spec/Nucleor_Algebraic_Laws_Schema.md section 1."; };
    if str_eq(code, "EFF-001") { return "RFC-0032 §3.1 — every function carries an effect row. Use a function with effects requires the caller to permit those effects. Either declare the effects in the caller's row or remove the call."; };
    if str_eq(code, "EFF-002") { return "RFC-0032 §3.2 — pure fn means no side effects (io, alloc, random, time, panic). The compiler can prove the call violates this."; };
    if str_eq(code, "EFF-003") { return "RFC-0032 §3.4 — restricts [...] is a contract on callbacks. Pass a different callback or remove the restrict."; };
    if str_eq(code, "EFF-004") { return "RFC-0032 — effect rows are typed contracts; an over-claimed row is a maintenance hazard (callers think the function reads io but it doesn't). Trim the row to match what's actually used."; };
    if str_eq(code, "EFF-005") { return "RFC-0032 §3.1 — a custom effect (e.g. `effect Telemetry`) needs a handler in scope to be discharged. Wrap the call site with `with telemetry_handler { ... }` or hoist the effect into the surrounding fn's row."; };
    if str_eq(code, "COLL-001") { return "RFC-0017 §3.2 — derive Hash + Eq for K, or use BTreeMap which only requires Ord, or change to a key type that already implements both."; };
    if str_eq(code, "COLL-002") { return "RFC-0017 §3.3 — BTreeMap/BTreeSet rely on key ordering for sorted iteration and binary search. Derive Ord or implement it."; };
    if str_eq(code, "COLL-003") { return "RFC-0017 §3.7 — pre-size with with_capacity_in for the worst case, then use try_push / push_within_capacity which never reallocate."; };
    if str_eq(code, "COLL-004") { return "RFC-0017 §3.4 — collect indices to mutate during the iteration into a Vec, then apply mutations after the iter completes. The borrow checker tracks shared/mut conflicts on the underlying buffer."; };
    if str_eq(code, "COLL-005") { return "RFC-0017 §3.1 — fixed-length collections (arr[N], const-sized inline_vec) reject out-of-bounds accesses at compile time. Use a runtime-bounds-checked Vec, or guard with a length check."; };
    if str_eq(code, "MOD-001") { return "RFC-0018 §3.1 — `mod foo;` resolves to ./foo.nr or ./foo/mod.nr relative to the current file. Check the path or create the file."; };
    if str_eq(code, "MOD-002") { return "RFC-0018 §3.3 — verify the path. crate::x means project root; super::x means parent module; std::x means stdlib; <pkg>::x means registry dep."; };
    if str_eq(code, "MOD-003") { return "RFC-0018 §3.2 — add `pub` (or pub(crate)/pub(super)) to the item, or move the use site closer to where the item is visible."; };
    if str_eq(code, "MOD-004") { return "RFC-0018 — globs are noisy and shadow-prone. Prefer explicit `use foo::{a, b, c}` lists, or define a prelude module that's intentional about exports."; };
    if str_eq(code, "MOD-005") { return "RFC-0018 — break the cycle by extracting shared definitions to a third module both depend on."; };
    if str_eq(code, "MOD-006") { return "RFC-0018 §3.4 — rename one with `as`: `use foo::Bar as FBar`. The compiler does not silently shadow."; };
    if str_eq(code, "PKG-001") { return "RFC-0019 §3.1 — see the canonical schema in docs/nuc-toml-spec.md (forthcoming). Common errors: missing [package] table, missing name/version, malformed [dependencies] entries."; };
    if str_eq(code, "PKG-002") { return "RFC-0019 §3.3 — PubGrub returns a structured conflict report. Common causes: two transitive deps require incompatible major versions of a shared dep. Loosen one constraint or pick a newer version of the conflicting transitive."; };
    if str_eq(code, "PKG-003") { return "RFC-0019 §3.4 — re-run `nuc update` to refresh the lockfile if intentional, or escalate (registry compromise) if unexpected."; };
    if str_eq(code, "PKG-004") { return "RFC-0019 §3.5 — verify network connectivity. For git deps, check the URL; for registry, check NUCLEOR_REGISTRY env or fall back to https://nucleor.dev/registry/ default."; };
    if str_eq(code, "PKG-005") { return "RFC-0019 §3.5 — `nuc search <name>` to discover the package; check spelling and case (registry is case-sensitive)."; };
    if str_eq(code, "PKG-006") { return "RFC-0019 §3.5 — yanked versions are kept downloadable for users with existing lockfiles but not chosen by `nuc add`. Either pin the yanked version explicitly with `=X.Y.Z`, or update."; };
    if str_eq(code, "TGT-001") { return "RFC-0022 §3.1 — see the Tier-1 list in the RFC. Tier-2/3 targets need explicit installation."; };
    if str_eq(code, "TGT-002") { return "RFC-0022 §3.7 — sysroots ship from nucleor.dev/sysroots/. The download is signed; install with `nuc install sysroot --target=<triple>`."; };
    if str_eq(code, "TGT-003") { return "RFC-0022 §3.6 — runtime feature audit. Some `_rt.c` modules guard with `_WIN32` / `__linux__` / etc.; bare-metal targets exclude entire categories."; };
    if str_eq(code, "TGT-004") { return "RFC-0022 §3.7 — likely missing libc on the target. For Linux→Windows or macOS→Linux cross, consult `clang --target=<triple> --print-search-dirs`."; };
    if str_eq(code, "TST-001") { return "RFC-0021 §3.1 — the discovery pass walks every fn declared in the source and looks for the `#[test]` attribute. None found means either the file has no tests yet or all candidates are gated behind `#[cfg(test)]` that isn't active. To run a single test from a non-test source, mark it `#[test]` explicitly."; };
    if str_eq(code, "TST-002") { return "RFC-0021 §3.4 — `--isolation=process` runs each test in a fresh child via env-var dispatch (`NUCLEOR_TEST_ONLY=<name>`). If the child segfaults, aborts, or is OOM-killed before `print('PASS …')` or `print('FAIL …')`, the harness reports TST-002 with the child's exit code. Re-run under a debugger or drop `--isolation=process` to see the panic in the parent."; };
    if str_eq(code, "TST-003") { return "RFC-0021 (deferred) — the v0.4 fixture work adds `#[before]` / `#[after]` hooks that gate the test body. A non-zero return from the setup hook reports TST-003 and skips the body. Until v0.4 lands, manage setup imperatively at the top of each `#[test]` fn."; };
    // RFC-0062 G-series memory-safety gates (v1.0). Each entry below mirrors the inline build-time message; the explain database is a stable home for the prose so adopters can recall it without re-running the build.
    if str_eq(code, "OWN-G4-USE-AFTER-DROP") { return "RFC-0062 G-4 (v1.0) — IR-level use-after-drop gate. The compiler tracks heap-backed bindings (Vec / HashMap / Box / String / VecDeque) and marks them dead after an explicit free. Reading a dead binding aliases freed memory and is rejected at error severity. Auto-drop is on by default at v1.0; explicit `vec_free` / `hashmap_free` is only required for `#[manual_drop]` paths."; };
    if str_eq(code, "OWN-G8-COND-MOVE") { return "RFC-0062 G-8 (v1.0) — conditional-move tracking. The move-state lattice intersects the `if` and `else` arms at the join point. If the binding is moved on one side and intact on the other, the post-join read is rejected. The fix is symmetry: move on every path, on no path, or restructure so the read is dominated by an arm where the binding is still valid."; };
    if str_eq(code, "INIT-G11-READ-BEFORE-INIT") { return "RFC-0062 G-11 (v1.0) — definite-assignment flow analysis. A `let mut x: T;` declaration without an initializer creates a binding the analysis tracks as 'definitely uninitialized'. A read is allowed only if every CFG path from the declaration to the read site assigns to `x`. The lattice meet at join points is intersection, so a single un-assigning path forces the diagnostic."; };
    if str_eq(code, "BORROW-G2-LIFETIME") { return "RFC-0062 G-2 (v1.0) — single-input lifetime enforcement. For functions with one reference-typed input and a reference-typed return, the v1.0 gate requires the returned reference to be derived from the input. Returning a borrow of a stack-local, a synthesized temporary, or a value reached only through a non-input traversal is rejected."; };
    if str_eq(code, "ALIAS-G3-VEC-OF-REFS") { return "RFC-0062 G-3 Phase 3 (v1.0) — heap-aliasing detection. The syntactic borrow tracker does not follow elements through `Vec<&T>`. Pushing a borrow into the Vec creates an alias the checker cannot see, so a subsequent mutation of either side could silently invalidate the other. The v1.0 fix is to reject `vec_push` / `vec_insert` on `Vec<&T>` at error severity."; };
    if str_eq(code, "ALIAS-G3-HASHMAP-REHASH") { return "RFC-0062 G-3 (v1.0) — HashMap rehash invalidation. Mutating `hashmap_insert` / `hashmap_remove` / `hashmap_clear` calls can move backing storage. Any borrow that points into the map's interior is invalidated by the rehash. The v1.0 gate detects an outstanding borrow at the call site and rejects it."; };
    if str_eq(code, "SEND-G6-HASHMAP") { return "RFC-0062 G-6 (v1.0) — Sendable closure propagation. Spawn-class calls require their argument graph to be Sendable. HashMap is non-Sendable in v1.0 because the rehash + iterator state are not safe to move across thread boundaries. The structural send-checker walks the argument graph; this code fires when a HashMap (or a struct/tuple/enum carrying one) is reached."; };
    if str_eq(code, "SEND-G6-CLOSURE-CAPTURE") { return "RFC-0062 G-6 (v1.0) — Sendable closure propagation. The recursive capture-set walker traces every binding the closure body reads. A closure that captures a non-Sendable value through its environment is itself non-Sendable. Bare-parameter closures (no captures) are clean."; };
    if str_eq(code, "SEND-G6-TUPLE") { return "RFC-0062 G-6 (v1.0) — Sendable structural propagation. Tuples are Sendable iff every field is Sendable. A spawn-call tuple argument with a non-Sendable element fails the gate at the offending field's path through the tuple."; };
    if str_eq(code, "SEND-G6-ENUM") { return "RFC-0062 G-6 (v1.0) — Sendable structural propagation across enum variants. The Send analysis is structural across all variants of the enum: if any variant carries a non-Sendable payload, the enum itself is non-Sendable for the purposes of the spawn-boundary gate."; };
    if str_eq(code, "FFI-G5-NULL-DEREF") { return "RFC-0062 G-5 (v1.0) — FFI null-contract enforcement with deref dataflow. An `extern fn` declared `#[effect(may_return_null)]` returns a pointer that may be null; reading or passing it to a non-null sink without a dominating `ptr_is_null(<binding>)` guard is rejected. The guard-state lattice intersects at if/else joins, so guarding on every CFG path from the FFI return to the use site satisfies the gate."; };
    if str_eq(code, "FFI-G9-MISSING-ALLOW-DIRECT-FFI") { return "RFC-0062 G-9 (v1.0) — FFI direct-call discipline. Direct FFI is a tracked effect. Every call to an `extern fn` from Nucleor source must be reachable from a function that declares `#[effect(direct_ffi)]` or `#[allow_effect(direct_ffi)]`. The annotation makes the audit explicit at function boundaries."; };
    if str_eq(code, "UNSAFE-G7-MISSING-ALLOW") { return "RFC-0062 G-7 (v1.0) — audited unsafe. `unsafe { ... }` blocks are a tracked effect and require the enclosing function to declare `#[effect(unsafe)]` or `#[allow_effect(unsafe)]`. The OSS compiler self-host source contains zero unsafe blocks; if a user-code path needs one, the annotation makes the deviation explicit at function-boundary granularity."; };
    if str_eq(code, "EFFECT-G10-UNDECLARED") { return "RFC-0062 G-10 (v1.0) — effect-annotations framework. The function body produces an effect (frees, borrows_mut, may_return_null, direct_ffi, unsafe) that is not in its declared `#[effect(...)]` row. The fix is either to add the effect to the row or to refactor the body so the effect is no longer produced."; };
    if str_eq(code, "EFFECT-G10-MISSING-ALLOW") { return "RFC-0062 G-10 (v1.0) — effect-annotations framework. The caller invoked an effectful function but did not declare an `#[allow_effect(...)]` for the produced effect. The annotation is per-effect, so each effect the caller intentionally tolerates from callees needs its own entry. Alternatively, declare the effect on the caller's `#[effect(...)]` row to propagate it to the caller's caller."; };
    if str_eq(code, "EFFECT-G10-WRONG-ROW") { return "RFC-0062 G-10 (v1.0) — effect-annotations framework. The declared `#[effect(...)]` row does not match the function's body — typically claiming an effect the body never produces, or omitting one the body does produce. The gate enforces tight rows: declared = produced, no surplus and no shortfall."; };
    return "";
}

fn explain_error_reference(code: str) -> str {
    return str_concat("docs/spec/Nucleor_Error_Codes.md#", ascii_upper(code));
}

fn explain_error_known(code: str) -> i64 {
    if str_len(explain_error_title(code)) == 0 { return 0; };
    return 1;
}

fn explain_error_next_steps(code: str) -> Vec<i32> {
    let mut steps: Vec<i32> = Vec::new();
    if str_eq(code, "NR001") {
        steps.push("Verify the file path passed to the command.");
        steps.push("Check file permissions and current working directory.");
        steps.push("If using a package, confirm [build].entry points to an existing file.");
    } else if str_eq(code, "NR005") {
        steps.push("Check the imported path or package alias.");
        steps.push("Ensure the import stays inside the package root.");
        steps.push("Look for duplicate exported names or cyclic imports.");
    } else if str_eq(code, "NR010") {
        steps.push("Check the reported source offset for the invalid character.");
        steps.push("Verify string and numeric literal syntax.");
        steps.push("Keep identifiers ASCII-only.");
    } else if str_eq(code, "NR020") {
        steps.push("Check the line and column around the reported span.");
        steps.push("Look for missing braces, commas, semicolons, or parentheses.");
        steps.push("Verify declaration headers and function signatures.");
    } else if str_eq(code, "PARSE-LET-SEMI") {
        steps.push("Add `;` immediately after the let initializer.");
        steps.push("If another value follows the initializer, connect it with an explicit operator or split it into a separate statement.");
        steps.push("Re-run the build and check the first token named after the reported byte offset.");
    } else if str_eq(code, "NR030") {
        steps.push("Read the concrete message for the exact mismatch.");
        steps.push("Check variable names, function signatures, and return types.");
        steps.push("Use nuc explain on any more specific code shown with the diagnostic.");
    } else if str_eq(code, "NR031") {
        steps.push("Check whether the value was moved earlier in the scope.");
        steps.push("Avoid overlapping shared and mutable borrows.");
        steps.push("Introduce a narrower scope so the borrow ends before the next use.");
    } else if str_eq(code, "NR032") {
        steps.push("Check the function effect list and current restricts or policy context.");
        steps.push("Add the required effect only if the operation is intentionally impure.");
        steps.push("If the operation must stay pure, refactor the side effect out of the function.");
    } else if str_eq(code, "NR033") {
        steps.push("Identify the tainted source in the data flow.");
        steps.push("Sanitize or validate the value before the sink.");
        steps.push("Keep tainted and trusted values separated until validation is complete.");
    } else if str_eq(code, "NR034") {
        steps.push("Move only owned Send values into spawn blocks.");
        steps.push("Avoid capturing mutable references across thread boundaries.");
        steps.push("Wrap shared state in a synchronization primitive only when the underlying payload is allowed.");
    } else if str_eq(code, "NR040") {
        steps.push("Look at the full message for the unsupported construct.");
        steps.push("Reduce the program to the smallest failing example.");
        steps.push("Treat repeated NR040 failures as compiler bugs to fix in lowering.");
    } else if str_eq(code, "NR050") {
        steps.push("Re-run with the other backend to isolate whether the failure is backend-specific.");
        steps.push("Check the reported symbol or ABI path in the message.");
        steps.push("Treat verifier or emission failures as backend correctness bugs.");
    } else if str_eq(code, "NR051") {
        steps.push("Rebuild the CLI with backend support required for wasm enabled.");
        steps.push("Install or point NUCLEOR_WASM_LD at a working wasm-ld.");
        steps.push("Confirm the LLVM toolchain is visible in PATH.");
    } else if str_eq(code, "NR070") {
        steps.push("Validate Nucleor.toml syntax and dependency paths.");
        steps.push("Run nuc lock after manifest changes.");
        steps.push("Check workspace member and dependency graph cycles.");
    } else if str_eq(code, "NR090") {
        steps.push("Reduce the failing program to a small reproducer.");
        steps.push("Treat repeated NR090 failures as compiler bugs.");
        steps.push("Inspect the named pipeline stage and previous stage outputs.");
    };
    return steps;
}

fn explain_error_render(code: str, json_mode: i64) -> str {
    let title: str = explain_error_title(code);
    let summary: str = explain_error_summary(code);
    let explanation: str = explain_error_explanation(code);
    let reference: str = explain_error_reference(code);
    let steps: Vec<i32> = explain_error_next_steps(code);
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"code\":\""); sb_append(sb, json_escape(code));
        sb_append(sb, "\",\"title\":\""); sb_append(sb, json_escape(title));
        sb_append(sb, "\",\"summary\":\""); sb_append(sb, json_escape(summary));
        sb_append(sb, "\",\"explanation\":\""); sb_append(sb, json_escape(explanation));
        sb_append(sb, "\",\"reference\":\""); sb_append(sb, json_escape(reference));
        sb_append(sb, "\",\"next_steps\":[");
        let mut i: i64 = 0;
        while i < vec_len(steps) {
            if i > 0 { sb_append(sb, ","); };
            sb_append(sb, "\""); sb_append(sb, json_escape(vec_get(steps, i))); sb_append(sb, "\"");
            i = i + 1;
        };
        sb_append(sb, "]}");
        return sb_to_str(sb);
    };
    let mut sb2: i64 = sb_new();
    sb_append(sb2, code); sb_append(sb2, ": "); sb_append(sb2, title); sb_append(sb2, "\n");
    sb_append(sb2, summary); sb_append(sb2, "\n");
    sb_append(sb2, explanation); sb_append(sb2, "\n");
    sb_append(sb2, "reference: "); sb_append(sb2, reference); sb_append(sb2, "\n");
    if vec_len(steps) > 0 {
        sb_append(sb2, "next steps:\n");
        let mut j: i64 = 0;
        while j < vec_len(steps) {
            sb_append(sb2, "- "); sb_append(sb2, vec_get(steps, j)); sb_append(sb2, "\n");
            j = j + 1;
        };
    };
    return sb_to_str(sb2);
}
fn load_resolved_source_bundle(src_path: str, use_cache: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let manifest_path: str = module_graph_manifest_path(src_path);
    let source_path: str = module_graph_source_path(src_path);
    if use_cache == 1 {
        let manifest: str = file_read_string(manifest_path);
        let cached_source: str = file_read_string(source_path);
        if str_len(manifest) > 0 && str_len(cached_source) > 0 {
            let valid: Vec<i32> = module_records_validate(manifest);
            if vec_get(valid, 0) == 1 {
                out.push(expand_actor_decl_keyword(cached_source));
                out.push(vec_get(valid, 1));
                out.push(1);
                return out;
            };
        };
    };
    let raw_source: str = file_read_string(src_path);
    let mut imported: Vec<i32> = Vec::new();
    if str_len(raw_source) == 0 {
        out.push("");
        out.push(imported);
        out.push(0);
        return out;
    };
    let mut module_records: Vec<i32> = Vec::new();
    imported.push(src_path);
    module_record_add(module_records, src_path, raw_source);
    let resolved: str = resolve_source_with_records(raw_source, extract_dir(src_path), imported, module_records);
    // T2.6 (v0.2.346): expand println!/print!/format! macros AFTER all
    // imports inline and BEFORE caching, identical to s1 path.
    let after_format: str = expand_format_macros(resolved);
    // T2.8 (v0.2.353): async syntax — strip `async` keyword + rewrite
    // `<ident>.await`. Synced from s1.
    let after_async: str = expand_async_syntax(after_format);
    // v0.3.0 (T3.1): #[deadline = N] runtime-check rewrite (synced).
    let after_deadline: str = expand_deadline(after_async);
    // T2.3 (v0.2.349): expand closure literals (synced from s1).
    let source: str = expand_actor_decl_keyword(expand_closures(after_deadline));
    if use_cache == 1 {
        fs_create_dir_all(".nuc_cache");
        file_write_string(manifest_path, module_records_serialize(module_records));
        file_write_string(source_path, source);
    };
    out.push(source);
    out.push(imported);
    out.push(0);
    return out;
}


