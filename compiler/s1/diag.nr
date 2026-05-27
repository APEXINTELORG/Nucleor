// =====================================================
// S12a — STRUCTURED DIAGNOSTIC SURFACE
// =====================================================
#[manual_drop]
fn diag_new() -> Vec<i32> { return Vec::new(); }
#[manual_drop]
fn diag_add(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, fn_name: str, line: i64) -> i64 {
    return diag_add_ex(diags, severity, checker, code, message, fn_name, line, 0, "");
}
#[manual_drop]
fn diag_add_ex(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, fn_name: str, line: i64, col: i64, related_id: str) -> i64 {
    // dedup at the emit site. Some type-check passes run their per-
    // call type-mismatch check more than once (call site visited
    // through multiple paths — postfix, direct-call dispatch, generic-
    // bound resolution). Each visit re-emitted the same diag; adopters
    // saw a triple error wall for one call.
    // Walk existing diags; if a row already has identical (code, message,
    // fn_name, line, col), skip the emit. Severity and checker are
    // included in the comparison via code (codes are unique per checker).
    let dn_v064: i64 = vec_len(diags);
    let mut di_v064: i64 = 0;
    while di_v064 < dn_v064 {
        let prior_d: Vec<i32> = vec_get(diags, di_v064);
        let pcode: str = vec_get(prior_d, 2);
        if str_eq(pcode, code) == 1 {
            let pmsg: str = vec_get(prior_d, 3);
            let pfn: str = vec_get(prior_d, 4);
            let pline: i64 = vec_get(prior_d, 5);
            let pcol: i64 = vec_get(prior_d, 6);
            if pline == line && pcol == col && str_eq(pfn, fn_name) == 1 && str_eq(pmsg, message) == 1 {
                return vec_len(diags);
            };
        };
        di_v064 = di_v064 + 1;
    };
    let mut d: Vec<i32> = Vec::new();
    d.push(severity); d.push(checker); d.push(code); d.push(message); d.push(fn_name); d.push(line);
    d.push(col); d.push(related_id);
    // Auto-generate suggestions based on error code
    let mut sug_msg: str = "";
    let mut sug_app: str = "Unspecified";
    if str_eq(code, "OWN-001") { sug_msg = "Consider cloning the value before passing it, or restructure to avoid the second use"; sug_app = "MaybeIncorrect"; };
    if str_eq(code, "TNT-001") { sug_msg = "Sanitize the tainted data before passing to the sensitive function: sanitize(value)"; sug_app = "HasPlaceholders"; };
    if str_eq(code, "EFF-001") { sug_msg = "Declare the required effect in the caller row, or remove the side-effecting call"; sug_app = "MaybeIncorrect"; };
    d.push(sug_msg); // index 8
    d.push(sug_app); // index 9
    // Child note (for ownership: "moved here")
    d.push(""); // index 10: child_message
    d.push(0);  // index 11: child_line
    diags.push(d);
    return vec_len(diags);
}
#[manual_drop]
fn diag_find_global_linecol(source: str, needle: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let nlen: i64 = str_len(needle);
    if nlen == 0 { out.push(1); out.push(1); return out; };
    let slen: i64 = str_len(source);
    let mut line: i64 = 1;
    let mut col: i64 = 1;
    let mut i: i64 = 0;
    while i + nlen <= slen {
        if str_eq_at_len(source, i, needle, nlen) == 1 {
            out.push(line);
            out.push(col);
            return out;
        };
        if str_char_at(source, i) == 10 { line = line + 1; col = 1; }
        else { col = col + 1; };
        i = i + 1;
    };
    out.push(1);
    out.push(1);
    return out;
}
#[manual_drop]
fn diag_linecol_at_byte(source: str, byte_off: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut limit: i64 = byte_off;
    if limit < 0 { limit = 0; };
    if limit > slen { limit = slen; };
    let mut line: i64 = 1;
    let mut col: i64 = 1;
    let mut i: i64 = 0;
    while i < limit {
        if str_char_at(source, i) == 10 { line = line + 1; col = 1; }
        else { col = col + 1; };
        i = i + 1;
    };
    out.push(line);
    out.push(col);
    return out;
}
#[manual_drop]
fn diag_add_fn_site(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, source: str, fn_name: str) -> i64 {
    let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
    let mut line: i64 = vec_get(lc, 0);
    let mut col: i64 = vec_get(lc, 1);
    if line <= 0 {
        let glc: Vec<i32> = diag_find_global_linecol(source, fn_name);
        line = vec_get(glc, 0);
        col = vec_get(glc, 1);
    };
    return diag_add_ex(diags, severity, checker, code, message, fn_name, line, col, "");
}
#[manual_drop]
fn diag_add_symbol_site(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, source: str, fn_name: str, symbol: str) -> i64 {
    let lc: Vec<i32> = find_linecol_in_source(source, fn_name, symbol);
    let mut line: i64 = vec_get(lc, 0);
    let mut col: i64 = vec_get(lc, 1);
    if line <= 0 {
        let glc: Vec<i32> = diag_find_global_linecol(source, symbol);
        line = vec_get(glc, 0);
        col = vec_get(glc, 1);
    };
    return diag_add_ex(diags, severity, checker, code, message, fn_name, line, col, "");
}
#[manual_drop]
fn diag_count(diags: Vec<i32>) -> i64 { return vec_len(diags); }
#[manual_drop]
fn diag_count_errors(diags: Vec<i32>) -> i64 {
    let n: i64 = vec_len(diags);
    let mut errors: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let d: Vec<i32> = vec_get(diags, i);
        let sev: str = vec_get(d, 0);
        if str_eq(sev, "error") == 1 { errors = errors + 1; };
        i = i + 1;
    };
    return errors;
}
#[manual_drop]
fn diag_get(diags: Vec<i32>, i: i64) -> Vec<i32> { return vec_get(diags, i); }

// RFC-0028 §Suppression — minimal `#[allow(CODE)]` post-filter.
// Scans the source for the literal pattern `#[allow(CODE)]` and
// returns a Vec<str> of the CODEs the user has marked as silenced.
// Whitespace inside the parens is tolerated but the CODE must be a
// bare identifier (e.g. `NUM-003`, `MATCH-001`) — quoted-string
// payloads are not supported in the v0.2 subset.
// `#[allow]` is file-wide for now; per-fn / per-block scoping ships
// with the v0.4 attribute-with-argument parsing pass that powers
// RFC-0004 `#[assume]` and RFC-0014 `#[max_depth]`.
#[manual_drop]
fn collect_allowed_codes(source: str) -> Vec<i32> {
    let mut allowed: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[allow(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            // Skip leading whitespace inside the parens.
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) {
                q = q + 1;
            };
            let start: i64 = q;
            // Read the bare identifier up to ')' or whitespace.
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q > start {
                let code: str = str_substring(source, start, q);
                allowed.push(code);
            };
            p = q + 1;
        } else {
            p = p + 1;
        };
    };
    return allowed;
}

// T3.12: per-fn #[allow_fn(CODE)] attribute. Sibling
// of collect_allowed_codes that ALSO records which fn the
// attribute attaches to. Returns alternating [fn_name, code, ...]
// so the diag filter can suppress only when (diag.fn_name,
// diag.code) matches an entry. Lets users narrow file-wide
// #[allow] noise to a specific fn — handy when one fn has a
// legitimate reason to fire RT-007 but the rest of the file
// shouldn't be silenced too.
#[manual_drop]
fn collect_allow_fn_pairs(source: str) -> Vec<i32> {
    let mut pairs: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[allow_fn(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            let code_start: i64 = q;
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q == code_start { p = p + 1; continue; };
            let code: str = str_substring(source, code_start, q);
            // Skip past `]` to land at the line break / following content.
            while q < slen && str_char_at(source, q) != 93 { q = q + 1; };
            if q < slen { q = q + 1; };
            // Walk past blank/doc/other-attribute lines for the next `fn NAME(`.
            let mut found: i64 = 0;
            while q + 3 <= slen && found == 0 {
                while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
                    q = q + 1;
                };
                if q + 3 > slen { found = 0 - 1; }
                else if str_char_at(source, q) == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 35 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 102 && str_char_at(source, q + 1) == 110 && str_char_at(source, q + 2) == 32 {
                    q = q + 3;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let fname: str = str_substring(source, nm_start, q);
                        pairs.push(fname);
                        pairs.push(code);
                        found = 1;
                    } else {
                        found = 0 - 1;
                    };
                } else if q + 4 <= slen && str_char_at(source, q) == 112 && str_char_at(source, q + 1) == 117 && str_char_at(source, q + 2) == 98 && str_char_at(source, q + 3) == 32 {
                    // pub <space> — could be `pub fn`. Skip past `pub `.
                    q = q + 4;
                } else {
                    found = 0 - 1;
                };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return pairs;
}

// Drop every diagnostic whose code is in `allowed` (file-wide)
// or whose (fn_name, code) is in the per-fn pair list. Errors
// are always preserved — `#[allow]` / `#[allow_fn]` only
// suppress warnings (Rust model). Modifies the input vec by
// rebuilding a filtered copy.
#[manual_drop]
fn filter_allow_suppressed(diags: Vec<i32>, source: str) -> Vec<i32> {
    let allowed: Vec<i32> = collect_allowed_codes(source);
    let allow_fn_pairs: Vec<i32> = collect_allow_fn_pairs(source);
    if vec_len(allowed) == 0 && vec_len(allow_fn_pairs) == 0 { return diags; };
    let mut filtered: Vec<i32> = Vec::new();
    let n: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < n {
        let d: Vec<i32> = vec_get(diags, i);
        let sev: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let fn_name: str = vec_get(d, 4);
        let mut suppressed: i64 = 0;
        if str_eq(sev, "error") == 0 {
            let mut j: i64 = 0;
            let m: i64 = vec_len(allowed);
            while j < m && suppressed == 0 {
                if str_eq(vec_get(allowed, j), code) == 1 { suppressed = 1; };
                j = j + 1;
            };
            if suppressed == 0 {
                let pn: i64 = vec_len(allow_fn_pairs);
                let mut pi: i64 = 0;
                while pi + 1 < pn && suppressed == 0 {
                    if str_eq(vec_get(allow_fn_pairs, pi), fn_name) == 1
                       && str_eq(vec_get(allow_fn_pairs, pi + 1), code) == 1 {
                        suppressed = 1;
                    };
                    pi = pi + 2;
                };
            };
        };
        if suppressed == 0 { filtered.push(d); };
        i = i + 1;
    };
    return filtered;
}

// RFC-0028 §Suppression — sibling of collect_allowed_codes.
// Scans the source for the literal pattern `#[deny(CODE)]`; same
// scope rules (file-wide for v0.2; per-fn deferred to v0.4).
#[manual_drop]
fn collect_denied_codes(source: str) -> Vec<i32> {
    let mut denied: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[deny(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) {
                q = q + 1;
            };
            let start: i64 = q;
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q > start {
                let code: str = str_substring(source, start, q);
                denied.push(code);
            };
            p = q + 1;
        } else {
            p = p + 1;
        };
    };
    return denied;
}

// Promote every warning-severity diagnostic whose code is in
// `denied` to error severity. Errors stay errors; allow-then-deny
// of the same code is order-dependent (allow strips the diag, so
// deny would not see it) — the recommended user pattern is to use
// at most one of `#[allow(CODE)]` or `#[deny(CODE)]` per code per
// file. Mutates each promoted diag's severity slot in place via
// vec_set (the diag inner vec is the actual storage, not a copy).
// T3.13: per-fn #[deny_fn(CODE)] attribute. Sibling
// of #[allow_fn] (v0.3.20) and the file-wide #[deny] (v0.2.152).
// Promotes one warning-tier diagnostic to error for the next fn
// declaration only — useful when a critical fn has stricter
// requirements than the rest of the file. Returns alternating
// [fn_name, code, ...].
#[manual_drop]
fn collect_deny_fn_pairs(source: str) -> Vec<i32> {
    let mut pairs: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[deny_fn(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            let code_start: i64 = q;
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q == code_start { p = p + 1; continue; };
            let code: str = str_substring(source, code_start, q);
            while q < slen && str_char_at(source, q) != 93 { q = q + 1; };
            if q < slen { q = q + 1; };
            let mut found: i64 = 0;
            while q + 3 <= slen && found == 0 {
                while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
                    q = q + 1;
                };
                if q + 3 > slen { found = 0 - 1; }
                else if str_char_at(source, q) == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 35 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 102 && str_char_at(source, q + 1) == 110 && str_char_at(source, q + 2) == 32 {
                    q = q + 3;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let fname: str = str_substring(source, nm_start, q);
                        pairs.push(fname);
                        pairs.push(code);
                        found = 1;
                    } else {
                        found = 0 - 1;
                    };
                } else if q + 4 <= slen && str_char_at(source, q) == 112 && str_char_at(source, q + 1) == 117 && str_char_at(source, q + 2) == 98 && str_char_at(source, q + 3) == 32 {
                    q = q + 4;
                } else {
                    found = 0 - 1;
                };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return pairs;
}

// T3.20: validation pass for #[allow(_fn)] / #[deny(_fn)]
// CODE arguments. The four collectors above accept any well-formed
// substring; a typo like #[allow_fn(RT-099)] would silently absorb
// (the user's intended diagnostic still fires, but the suppression
// they wrote points at nothing).
// T3.22: tightened from prefix-only to enumerated. The
// canonical code set below mirrors cli_explain_full_smoke (verify.sh
// + verify.ps1). When minting a new code, add to BOTH this list and
// the cli_explain_full_smoke `codes` array. A future ship may unify
// via a generated header or a runtime registry exposed through
// `nuc explain`.
#[manual_drop]
fn is_known_diag_code(code: str) -> i64 {
    // NR series — RFC-0020 baseline pipeline diagnostics
    if str_eq(code, "NR001") == 1 { return 1; };
    if str_eq(code, "NR005") == 1 { return 1; };
    if str_eq(code, "NR010") == 1 { return 1; };
    if str_eq(code, "NR020") == 1 { return 1; };
    if str_eq(code, "PARSE-LET-SEMI") == 1 { return 1; };
    if str_eq(code, "NR030") == 1 { return 1; };
    if str_eq(code, "NR031") == 1 { return 1; };
    if str_eq(code, "NR032") == 1 { return 1; };
    if str_eq(code, "NR033") == 1 { return 1; };
    if str_eq(code, "NR034") == 1 { return 1; };
    if str_eq(code, "NR035") == 1 { return 1; };
    if str_eq(code, "NR036") == 1 { return 1; };
    if str_eq(code, "NR040") == 1 { return 1; };
    if str_eq(code, "NR050") == 1 { return 1; };
    if str_eq(code, "NR051") == 1 { return 1; };
    if str_eq(code, "NR070") == 1 { return 1; };
    if str_eq(code, "NR090") == 1 { return 1; };
    // RFC-0001 RT
    if str_eq(code, "RT-001") == 1 { return 1; };
    if str_eq(code, "RT-002") == 1 { return 1; };
    if str_eq(code, "RT-003") == 1 { return 1; };
    if str_eq(code, "RT-004") == 1 { return 1; };
    if str_eq(code, "RT-005") == 1 { return 1; };
    if str_eq(code, "RT-006") == 1 { return 1; };
    if str_eq(code, "ASYNC-001") == 1 { return 1; };
    if str_eq(code, "RT-007") == 1 { return 1; };
    if str_eq(code, "RT-008") == 1 { return 1; };
    if str_eq(code, "RT-009") == 1 { return 1; };
    // RFC-0002 allocators
    if str_eq(code, "ALLOC-001") == 1 { return 1; };
    if str_eq(code, "ALLOC-002") == 1 { return 1; };
    if str_eq(code, "ALLOC-003") == 1 { return 1; };
    // RFC-0003 typed frames
    if str_eq(code, "FRAME-001") == 1 { return 1; };
    if str_eq(code, "FRAME-002") == 1 { return 1; };
    if str_eq(code, "FRAME-003") == 1 { return 1; };
    // OWN — borrow checker
    if str_eq(code, "OWN-001") == 1 { return 1; };
    if str_eq(code, "OWN-002") == 1 { return 1; };
    if str_eq(code, "OWN-003") == 1 { return 1; };
    if str_eq(code, "OWN-004") == 1 { return 1; };
    if str_eq(code, "OWN-005") == 1 { return 1; };
    if str_eq(code, "OWN-006") == 1 { return 1; };
    if str_eq(code, "OWN-007") == 1 { return 1; };
    if str_eq(code, "OWN-008") == 1 { return 1; };
    if str_eq(code, "OWN-009") == 1 { return 1; };
    if str_eq(code, "OWN-010") == 1 { return 1; };
    if str_eq(code, "OWN-011") == 1 { return 1; };
    if str_eq(code, "OWN-012") == 1 { return 1; };
    if str_eq(code, "OWN-013") == 1 { return 1; };
    // RFC-0062 G-4 Phase 2b/3/4 — IR-level use-after-drop. Manual
    // `vec_free` / `hashmap_free` / `str_free` mark the arg's slot
    // freed; subsequent reads in the same CFG path emit this code at
    // error severity (Phase 4 hard-fail). The Phase 2a OWN-012
    // textual count remains as a build-summary line.
    if str_eq(code, "OWN-G4-USE-AFTER-DROP") == 1 { return 1; };
    if str_eq(code, "OWN-G1-RAW-HANDLE-CAST") == 1 { return 1; };
    // RACE — RFC-0035 Sendable + actor isolation
    if str_eq(code, "RACE-001") == 1 { return 1; };
    if str_eq(code, "RACE-002") == 1 { return 1; };
    if str_eq(code, "RACE-003") == 1 { return 1; };
    if str_eq(code, "RACE-004") == 1 { return 1; };
    if str_eq(code, "RACE-005") == 1 { return 1; };
    if str_eq(code, "RACE-006") == 1 { return 1; };
    if str_eq(code, "RACE-007") == 1 { return 1; };
    if str_eq(code, "RACE-008") == 1 { return 1; };
    if str_eq(code, "RACE-009") == 1 { return 1; };
    if str_eq(code, "RACE-010") == 1 { return 1; };
    // GOV — governance
    if str_eq(code, "GOV-001") == 1 { return 1; };
    if str_eq(code, "GOV-002") == 1 { return 1; };
    // TNT — taint
    if str_eq(code, "TNT-001") == 1 { return 1; };
    // TYP — type checker
    if str_eq(code, "TYP-001") == 1 { return 1; };
    if str_eq(code, "TYP-002") == 1 { return 1; };
    if str_eq(code, "TYP-003") == 1 { return 1; };
    if str_eq(code, "TYP-004") == 1 { return 1; };
    if str_eq(code, "TYP-005") == 1 { return 1; };
    if str_eq(code, "TYP-006") == 1 { return 1; };
    if str_eq(code, "TYP-007") == 1 { return 1; };
    if str_eq(code, "TYP-008") == 1 { return 1; };
    if str_eq(code, "TYP-009") == 1 { return 1; };
    if str_eq(code, "TYP-010") == 1 { return 1; };
    if str_eq(code, "TYP-011") == 1 { return 1; };
    if str_eq(code, "TYP-012") == 1 { return 1; };
    if str_eq(code, "TYP-013") == 1 { return 1; };
    if str_eq(code, "TYP-044") == 1 { return 1; };
    if str_eq(code, "TYP-026") == 1 { return 1; };
    if str_eq(code, "TYP-027") == 1 { return 1; };
    // RFC-0062 G-2 Phase 2b/3/4 — single-input lifetime check.
    // Phase 2b adds the IR-level analysis in check_fn; Phase 4 promotes
    // the diagnostic to a hard error. When a fn has exactly one
    // ref-typed parameter and a ref return type, the returned region
    // must equal the input's region.
    if str_eq(code, "BORROW-G2-LIFETIME") == 1 { return 1; };
    // RFC-0062 G-8 Phase 2b/3/4 — conditional-divergence move-state
    // join. When a binding is moved on one arm of an if/else but
    // not the other, the join state is "conditionally moved":
    // subsequent reads emit this code at error severity. Distinct
    // from OWN-001 (which fires when the binding is moved on every
    // incoming path).
    if str_eq(code, "OWN-G8-COND-MOVE") == 1 { return 1; };
    // RFC-0062 G-11 Phase 2b/3/4 — definite-assignment flow
    // analysis. Phase 2b relaxes the unconditional TYP-008 rejection
    // of `let mut x: T;` (no-init mutable bindings), allowing them
    // when DA proves every read is dominated by an assignment.
    // Reads on a path where the binding is not definitely assigned
    // emit this code at error severity. Cooperates with the
    // own_merge_moved lattice to intersect init state at if/else
    // join points.
    if str_eq(code, "INIT-G11-READ-BEFORE-INIT") == 1 { return 1; };
    // RFC-0062 G-3 Phase 3 — heap-aliasing per-fn analysis. Promotes
    // the earlier textual build-summary count to
    // per-call-site error in `check_expr` kind-7. ALIAS-G3-VEC-OF-REFS
    // fires when `vec_push` / `vec_insert` lands on a binding declared
    // as `Vec<&T>` (pushing a borrow into a Vec hides aliasing from
    // the syntactic borrow tracker). ALIAS-G3-HASHMAP-REHASH fires
    // when `hashmap_insert` / `hashmap_remove` / `hashmap_clear` /
    // `hashmap_free` is called while a live shared borrow exists on
    // the same map binding (rehash invalidates held references).
    if str_eq(code, "ALIAS-G3-VEC-OF-REFS") == 1 { return 1; };
    if str_eq(code, "ALIAS-G3-HASHMAP-REHASH") == 1 { return 1; };
    // Unknown effect-name detection.
    // Pre-fix `#[effect(banana)]` silently dropped `banana` —
    // typos like `may_retrun_null` lost the intended constraint.
    if str_eq(code, "EFFECT-G10-UNKNOWN-NAME") == 1 { return 1; };
    // Info-level disclosure of
    // the effect-framework opt-in cliff. Fires when source carries
    // the explicit `#[disclose_effects_status]` outer attribute and
    // has no opt-in `#[effect(...)]` / `#[allow_effect(...)]`
    // attribute anywhere, telling adopters the entire G-5/G-7/G-9/
    // G-10 framework is inactive for this TU.
    if str_eq(code, "EFFECT-G10-OPT-IN-CLIFF") == 1 { return 1; };
    // Opaque concurrency-handle
    // construction guard. Forbids struct-literal construction
    // of AtomicI64 / AtomicU64 / AtomicI32 / AtomicU32 /
    // AtomicBool from outside the rod's constructor fns —
    // adopter code MUST use the public constructor fn. Pre-fix
    // any program could fabricate a fake handle and crash the
    // process via SEGV / UAF when the runtime dereferenced it.
    if str_eq(code, "CONC-G6-OPAQUE-HANDLE") == 1 { return 1; };
    // RFC-0062 G-6 Phase 3 — Sendable per-call-site classification at
    // spawn boundaries (`thread_spawn` / `async_spawn` / `conc_spawn`).
    // Promotes the earlier textual build-summary
    // count) to per-call-site error in `check_expr` kind-7. The
    // existing RACE-001 textual pre-pass continues to fire for plain
    // non-Sendable struct args; the codes below are more specific
    // shape classifications. SEND-G6-HASHMAP fires for HashMap /
    // Cell / RefCell args. SEND-G6-CLOSURE-CAPTURE fires when the
    // arg expression is a closure literal (kind 42). SEND-G6-TUPLE
    // fires when the arg's declared type starts with `(` and any
    // tuple element is non-Sendable. SEND-G6-ENUM fires when the arg's
    // declared type names an enum that has at least one variant
    // payload type containing a non-Sendable shape.
    if str_eq(code, "SEND-G6-HASHMAP") == 1 { return 1; };
    if str_eq(code, "SEND-G6-CLOSURE-CAPTURE") == 1 { return 1; };
    if str_eq(code, "SEND-G6-TUPLE") == 1 { return 1; };
    if str_eq(code, "SEND-G6-ENUM") == 1 { return 1; };
    // RFC-0062 G-10 Phase 2b — effect annotations framework.
    // The `#[effect(E1, E2, ...)]` attribute declares the effects a
    // fn produces; `#[allow_effect(E)]` silences the diagnostic for
    // a single effect on a single fn. Initial vocabulary: `frees`,
    // `borrows_mut`, `may_return_null`, `direct_ffi`. Three codes:
    //   EFFECT-G10-UNDECLARED   — body produces effect E but the fn
    //                              carries no `#[effect(...)]` row at all
    //                              and no `#[allow_effect(E)]` opt-out.
    //   EFFECT-G10-MISSING-ALLOW — fn HAS `#[effect(...)]` but body
    //                              produces an extra effect E that is not
    //                              in the row and not silenced.
    //   EFFECT-G10-WRONG-ROW    — fn declares effect E in `#[effect(...)]`
    //                              but the body produces no operation
    //                              (leaf builtin or call to a declared-
    //                              effect fn) that yields E (over-decl).
    // Leaf inference is conservative: vec_free / hashmap_free / str_free
    // → `frees`. Call-propagation reads other fns' `#[effect(...)]`
    // declarations. R4 (G-5/G-7/G-9) extends leaf inference for
    // `direct_ffi`, `may_return_null`, `borrows_mut`.
    if str_eq(code, "EFFECT-G10-UNDECLARED") == 1 { return 1; };
    if str_eq(code, "EFFECT-G10-MISSING-ALLOW") == 1 { return 1; };
    if str_eq(code, "EFFECT-G10-WRONG-ROW") == 1 { return 1; };
    // RFC-0062 G-5 + G-7 + G-9 Phase 4 — FFI surface specializations
    // over R3's effect framework. These three codes supersede the
    // generic EFFECT-G10-UNDECLARED when the unhandled effect is
    // direct_ffi / may_return_null / unsafe. Specialized = better
    // adopter message (names the extern fn or unsafe block) plus, for
    // G-5, the actual sound deref-after-extern-call dataflow check.
    // R4 also adds the `unsafe` token to the vocabulary in
    // g10_attr_known_effect.
    if str_eq(code, "FFI-G5-NULL-DEREF") == 1 { return 1; };
    if str_eq(code, "FFI-G9-MISSING-ALLOW-DIRECT-FFI") == 1 { return 1; };
    if str_eq(code, "UNSAFE-G7-MISSING-ALLOW") == 1 { return 1; };
    if str_eq(code, "FMT-002") == 1 { return 1; };
    if str_eq(code, "FMT-003") == 1 { return 1; };
    if str_eq(code, "TRAIT-001") == 1 { return 1; };
    // RFC-0004 assume!
    if str_eq(code, "ASSUME-001") == 1 { return 1; };
    if str_eq(code, "ASSUME-002") == 1 { return 1; };
    if str_eq(code, "ASSUME-003") == 1 { return 1; };
    if str_eq(code, "ASSUME-004") == 1 { return 1; };
    if str_eq(code, "ASSUME-005") == 1 { return 1; };
    // RFC-0005 units
    if str_eq(code, "UNIT-001") == 1 { return 1; };
    if str_eq(code, "UNIT-002") == 1 { return 1; };
    if str_eq(code, "UNIT-003") == 1 { return 1; };
    if str_eq(code, "UNIT-004") == 1 { return 1; };
    if str_eq(code, "UNIT-005") == 1 { return 1; };
    // RFC-0006 contracts
    if str_eq(code, "CONTRACT-001") == 1 { return 1; };
    if str_eq(code, "CONTRACT-002") == 1 { return 1; };
    if str_eq(code, "CONTRACT-003") == 1 { return 1; };
    if str_eq(code, "CONTRACT-004") == 1 { return 1; };
    if str_eq(code, "CONTRACT-005") == 1 { return 1; };
    if str_eq(code, "CONTRACT-006") == 1 { return 1; };
    if str_eq(code, "CONTRACT-007") == 1 { return 1; };
    if str_eq(code, "CONTRACT-008") == 1 { return 1; };
    if str_eq(code, "CONTRACT-009") == 1 { return 1; };
    if str_eq(code, "CONTRACT-010") == 1 { return 1; };
    if str_eq(code, "CONTRACT-011") == 1 { return 1; };
    // RFC-0007 atomic
    if str_eq(code, "ATOMIC-001") == 1 { return 1; };
    if str_eq(code, "ATOMIC-002") == 1 { return 1; };
    if str_eq(code, "ATOMIC-003") == 1 { return 1; };
    if str_eq(code, "ATOMIC-004") == 1 { return 1; };
    if str_eq(code, "ATOMIC-005") == 1 { return 1; };
    if str_eq(code, "ATOMIC-006") == 1 { return 1; };
    // RFC-0008 ISR
    if str_eq(code, "ISR-001") == 1 { return 1; };
    if str_eq(code, "ISR-002") == 1 { return 1; };
    if str_eq(code, "ISR-003") == 1 { return 1; };
    if str_eq(code, "ISR-004") == 1 { return 1; };
    if str_eq(code, "ISR-005") == 1 { return 1; };
    if str_eq(code, "ISR-006") == 1 { return 1; };
    if str_eq(code, "ISR-007") == 1 { return 1; };
    if str_eq(code, "ISR-008") == 1 { return 1; };
    // RFC-0009 WCET
    if str_eq(code, "WCET-001") == 1 { return 1; };
    if str_eq(code, "WCET-002") == 1 { return 1; };
    if str_eq(code, "WCET-003") == 1 { return 1; };
    if str_eq(code, "WCET-004") == 1 { return 1; };
    if str_eq(code, "WCET-005") == 1 { return 1; };
    if str_eq(code, "WCET-006") == 1 { return 1; };
    // RFC-0010 DLPack
    if str_eq(code, "DLPACK-001") == 1 { return 1; };
    if str_eq(code, "DLPACK-002") == 1 { return 1; };
    if str_eq(code, "DLPACK-003") == 1 { return 1; };
    if str_eq(code, "DLPACK-004") == 1 { return 1; };
    if str_eq(code, "DLPACK-005") == 1 { return 1; };
    // RFC-0011 nuc-cxx
    if str_eq(code, "CXX-001") == 1 { return 1; };
    if str_eq(code, "CXX-002") == 1 { return 1; };
    if str_eq(code, "CXX-003") == 1 { return 1; };
    if str_eq(code, "CXX-004") == 1 { return 1; };
    if str_eq(code, "CXX-005") == 1 { return 1; };
    // RFC-0012 nuc-bindgen
    if str_eq(code, "BINDGEN-001") == 1 { return 1; };
    if str_eq(code, "BINDGEN-002") == 1 { return 1; };
    if str_eq(code, "BINDGEN-003") == 1 { return 1; };
    if str_eq(code, "BINDGEN-004") == 1 { return 1; };
    if str_eq(code, "BINDGEN-005") == 1 { return 1; };
    // RFC-0013 URDF
    if str_eq(code, "URDF-001") == 1 { return 1; };
    if str_eq(code, "URDF-002") == 1 { return 1; };
    if str_eq(code, "URDF-003") == 1 { return 1; };
    if str_eq(code, "URDF-004") == 1 { return 1; };
    if str_eq(code, "URDF-005") == 1 { return 1; };
    if str_eq(code, "URDF-006") == 1 { return 1; };
    // RFC-0014 max_depth
    if str_eq(code, "DEPTH-001") == 1 { return 1; };
    if str_eq(code, "DEPTH-002") == 1 { return 1; };
    if str_eq(code, "DEPTH-003") == 1 { return 1; };
    if str_eq(code, "DEPTH-004") == 1 { return 1; };
    if str_eq(code, "DEPTH-005") == 1 { return 1; };
    // RFC-0015 numeric types — base set + v0.2.319 expansion (NUM-006..020)
    if str_eq(code, "NUM-001") == 1 { return 1; };
    if str_eq(code, "NUM-002") == 1 { return 1; };
    if str_eq(code, "NUM-003") == 1 { return 1; };
    if str_eq(code, "NUM-004") == 1 { return 1; };
    if str_eq(code, "NUM-005") == 1 { return 1; };
    if str_eq(code, "NUM-006") == 1 { return 1; };
    if str_eq(code, "NUM-007") == 1 { return 1; };
    if str_eq(code, "NUM-008") == 1 { return 1; };
    if str_eq(code, "NUM-009") == 1 { return 1; };
    if str_eq(code, "PERF-1") == 1 { return 1; };
    if str_eq(code, "PERF-2") == 1 { return 1; };
    if str_eq(code, "PERF-3") == 1 { return 1; };
    if str_eq(code, "NUM-010") == 1 { return 1; };
    if str_eq(code, "NUM-011") == 1 { return 1; };
    if str_eq(code, "NUM-012") == 1 { return 1; };
    if str_eq(code, "NUM-013") == 1 { return 1; };
    if str_eq(code, "NUM-014") == 1 { return 1; };
    if str_eq(code, "NUM-015") == 1 { return 1; };
    if str_eq(code, "NUM-016") == 1 { return 1; };
    if str_eq(code, "NUM-017") == 1 { return 1; };
    if str_eq(code, "NUM-018") == 1 { return 1; };
    if str_eq(code, "NUM-019") == 1 { return 1; };
    if str_eq(code, "NUM-020") == 1 { return 1; };
    if str_eq(code, "NUM-021") == 1 { return 1; };
    if str_eq(code, "NUM-022") == 1 { return 1; };
    if str_eq(code, "NUM-023") == 1 { return 1; };
    if str_eq(code, "NUM-024") == 1 { return 1; };
    // RFC-0016 Result/Option/match
    if str_eq(code, "MATCH-001") == 1 { return 1; };
    if str_eq(code, "MATCH-002") == 1 { return 1; };
    if str_eq(code, "MATCH-003") == 1 { return 1; };
    if str_eq(code, "MATCH-004") == 1 { return 1; };
    if str_eq(code, "MATCH-005") == 1 { return 1; };
    if str_eq(code, "MATCH-006") == 1 { return 1; };
    if str_eq(code, "MATCH-007") == 1 { return 1; };
    if str_eq(code, "MATCH-008") == 1 { return 1; };
    if str_eq(code, "MATCH-009") == 1 { return 1; };
    if str_eq(code, "MATCH-010") == 1 { return 1; };
    if str_eq(code, "MATCH-011") == 1 { return 1; };
    if str_eq(code, "MATCH-012") == 1 { return 1; };
    if str_eq(code, "MATCH-013") == 1 { return 1; };
    if str_eq(code, "MATCH-014") == 1 { return 1; };
    // MATCH-015 reserved (parser-side range pattern variant; see ~line 1820).
    if str_eq(code, "MATCH-015") == 1 { return 1; };
    // Lane 1 audit fix (2026-05-08) — close F-002 (cross-enum match
    // silent miscompile). MATCH-016 is the new pattern-vs-scrutinee
    // enum identity check.
    if str_eq(code, "MATCH-016") == 1 { return 1; };
    // RFC-0017 collections
    if str_eq(code, "COLL-001") == 1 { return 1; };
    if str_eq(code, "COLL-002") == 1 { return 1; };
    if str_eq(code, "COLL-003") == 1 { return 1; };
    if str_eq(code, "COLL-004") == 1 { return 1; };
    if str_eq(code, "COLL-005") == 1 { return 1; };
    // RFC-0018 modules
    if str_eq(code, "MOD-001") == 1 { return 1; };
    if str_eq(code, "MOD-002") == 1 { return 1; };
    if str_eq(code, "MOD-003") == 1 { return 1; };
    if str_eq(code, "MOD-004") == 1 { return 1; };
    if str_eq(code, "MOD-005") == 1 { return 1; };
    if str_eq(code, "MOD-006") == 1 { return 1; };
    // RFC-0019 packages
    if str_eq(code, "PKG-001") == 1 { return 1; };
    if str_eq(code, "PKG-002") == 1 { return 1; };
    if str_eq(code, "PKG-003") == 1 { return 1; };
    if str_eq(code, "PKG-004") == 1 { return 1; };
    if str_eq(code, "PKG-005") == 1 { return 1; };
    if str_eq(code, "PKG-006") == 1 { return 1; };
    // RFC-0020 DIAG
    if str_eq(code, "DIAG-001") == 1 { return 1; };
    // RFC-0021 test framework
    if str_eq(code, "TST-001") == 1 { return 1; };
    if str_eq(code, "TST-002") == 1 { return 1; };
    if str_eq(code, "TST-003") == 1 { return 1; };
    // RFC-0022 cross-platform
    if str_eq(code, "TGT-001") == 1 { return 1; };
    if str_eq(code, "TGT-002") == 1 { return 1; };
    if str_eq(code, "TGT-003") == 1 { return 1; };
    if str_eq(code, "TGT-004") == 1 { return 1; };
    // RFC-0031 algebraic laws (R14 reservations through Phase 2)
    if str_eq(code, "LAW-001") == 1 { return 1; };
    if str_eq(code, "LAW-002") == 1 { return 1; };
    if str_eq(code, "LAW-003") == 1 { return 1; };
    if str_eq(code, "LAW-004") == 1 { return 1; };
    if str_eq(code, "LAW-006") == 1 { return 1; };
    if str_eq(code, "LAW-007") == 1 { return 1; };
    if str_eq(code, "LAW-008") == 1 { return 1; };
    // RFC-0032 effects
    if str_eq(code, "EFF-001") == 1 { return 1; };
    if str_eq(code, "EFF-002") == 1 { return 1; };
    if str_eq(code, "EFF-003") == 1 { return 1; };
    if str_eq(code, "EFF-004") == 1 { return 1; };
    if str_eq(code, "EFF-005") == 1 { return 1; };
    return 0;
}

// Walk all four allow/deny collectors; emit warning[DIAG-001] for
// any CODE whose prefix doesn't match the canonical set. Hint
// names docs/spec/Nucleor_Error_Codes.md as the catalog. The
// emitted diags themselves can be suppressed via #[allow(DIAG-001)]
// on a noisy refactor.
#[manual_drop]
fn emit_diag001_unknown_codes(diags: Vec<i32>, source: str) -> Vec<i32> {
    let scan_source: str = source;
    let allowed: Vec<i32> = collect_allowed_codes(scan_source);
    let allow_fn_pairs: Vec<i32> = collect_allow_fn_pairs(scan_source);
    let denied: Vec<i32> = collect_denied_codes(scan_source);
    let deny_fn_pairs: Vec<i32> = collect_deny_fn_pairs(scan_source);
    let mut i: i64 = 0;
    let an: i64 = vec_len(allowed);
    while i < an {
        let code: str = vec_get(allowed, i);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, "' in #[allow(...)] -- not in canonical diagnostic code set; suppression has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"));
            let loc_allow: Vec<i32> = diag_find_global_linecol(scan_source, code);
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, "<file>", vec_get(loc_allow, 0), vec_get(loc_allow, 1), "");
        };
        i = i + 1;
    };
    i = 0;
    let dn: i64 = vec_len(denied);
    while i < dn {
        let code: str = vec_get(denied, i);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, "' in #[deny(...)] -- not in canonical diagnostic code set; promotion has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"));
            let loc_deny: Vec<i32> = diag_find_global_linecol(scan_source, code);
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, "<file>", vec_get(loc_deny, 0), vec_get(loc_deny, 1), "");
        };
        i = i + 1;
    };
    let pn: i64 = vec_len(allow_fn_pairs);
    let mut pi: i64 = 0;
    while pi + 1 < pn {
        let fname: str = vec_get(allow_fn_pairs, pi);
        let code: str = vec_get(allow_fn_pairs, pi + 1);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, str_concat("' in #[allow_fn(...)] on fn '", str_concat(fname, "' -- not in canonical diagnostic code set; suppression has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"))));
            let loc_allow_fn: Vec<i32> = diag_find_global_linecol(scan_source, code);
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, fname, vec_get(loc_allow_fn, 0), vec_get(loc_allow_fn, 1), "");
        };
        pi = pi + 2;
    };
    let qn: i64 = vec_len(deny_fn_pairs);
    let mut qi: i64 = 0;
    while qi + 1 < qn {
        let fname: str = vec_get(deny_fn_pairs, qi);
        let code: str = vec_get(deny_fn_pairs, qi + 1);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, str_concat("' in #[deny_fn(...)] on fn '", str_concat(fname, "' -- not in canonical diagnostic code set; promotion has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"))));
            let loc_deny_fn: Vec<i32> = diag_find_global_linecol(scan_source, code);
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, fname, vec_get(loc_deny_fn, 0), vec_get(loc_deny_fn, 1), "");
        };
        qi = qi + 2;
    };
    return diags;
}

#[manual_drop]
fn promote_denied_to_errors(diags: Vec<i32>, source: str) -> Vec<i32> {
    let denied: Vec<i32> = collect_denied_codes(source);
    let deny_fn_pairs: Vec<i32> = collect_deny_fn_pairs(source);
    if vec_len(denied) == 0 && vec_len(deny_fn_pairs) == 0 { return diags; };
    let n: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < n {
        let d: Vec<i32> = vec_get(diags, i);
        let sev: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let fn_name: str = vec_get(d, 4);
        if str_eq(sev, "warning") == 1 {
            let mut promoted: i64 = 0;
            let mut j: i64 = 0;
            let m: i64 = vec_len(denied);
            while j < m && promoted == 0 {
                if str_eq(vec_get(denied, j), code) == 1 {
                    vec_set(d, 0, "error");
                    promoted = 1;
                };
                j = j + 1;
            };
            if promoted == 0 {
                let pn: i64 = vec_len(deny_fn_pairs);
                let mut pi: i64 = 0;
                while pi + 1 < pn && promoted == 0 {
                    if str_eq(vec_get(deny_fn_pairs, pi), fn_name) == 1
                       && str_eq(vec_get(deny_fn_pairs, pi + 1), code) == 1 {
                        vec_set(d, 0, "error");
                        promoted = 1;
                    };
                    pi = pi + 2;
                };
            };
        };
        i = i + 1;
    };
    return diags;
}

// RFC-0001 phase 1 — `#[no_alloc]` v1 (file-wide source-level
// static check). Scans for `#[no_alloc]` attribute lines and
// associates each with the next `fn NAME(` declaration. For every
// such fn, scans its body text for forbidden allocator-builtin
// call patterns (literal `<name>(` substrings) and fires `RT-001`
// per violation.
// Limitations of the source-level check (acceptable for v1):
//   - False positive if the literal pattern (e.g. `vec_push(`)
//     appears inside a string or comment in the body. Rare in
//     practice; rewrites are easy.
//   - Chases one same-file helper call when the helper body contains
//     a known allocation pattern. Broader transitive, cross-module,
//     and fn-pointer calls remain out of scope for this v1 scan.
//   - Per-file scope only; no module boundary tracking.
// AST-based v2 ships with the rest of RFC-0001 (`#[no_panic]`,
// `#[no_dyn]`, `#[deadline]`).

// T3.7 (v0.3.6): mask string literals + `//` line comments out of a
// fn body before the RT-001/002/003 substring checks scan it. The
// v1 checks were naive str_contains, so a literal `"Vec::new"` in
// a string or `// vec_push(x)` in a comment would false-positive.
// We replace masked ranges with spaces (preserving length so any
// downstream position math stays valid) — `(` characters get
// blanked too, which means the `<name>(` anchor pattern can no
// longer match anywhere inside a quoted/commented region.
#[manual_drop]
fn strip_strings_and_line_comments(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(s, p);
        if c == 47 && p + 1 < slen && str_char_at(s, p + 1) == 47 {
            // Line comment: emit spaces until newline.
            while p < slen && str_char_at(s, p) != 10 {
                sb_append(sb, " ");
                p = p + 1;
            };
            if p < slen { sb_append(sb, "\n"); p = p + 1; };
        } else if c == 34 {
            // Double-quoted string: emit space for the opening quote,
            // then walk past escape sequences until the closing quote.
            sb_append(sb, " ");
            p = p + 1;
            while p < slen && str_char_at(s, p) != 34 {
                if str_char_at(s, p) == 92 && p + 1 < slen {
                    sb_append(sb, "  ");
                    p = p + 2;
                } else {
                    sb_append(sb, " ");
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, " "); p = p + 1; };
        } else if c == 39 {
            // Single-quoted char: same shape as double-quote but with `'`.
            sb_append(sb, " ");
            p = p + 1;
            while p < slen && str_char_at(s, p) != 39 {
                if str_char_at(s, p) == 92 && p + 1 < slen {
                    sb_append(sb, "  ");
                    p = p + 2;
                } else {
                    sb_append(sb, " ");
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, " "); p = p + 1; };
        } else {
            sb_append_char_at(sb, s, p);
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn rt_string_vec_append(v: Vec<i32>, extra: Vec<i32>) -> i64 {
    let n: i64 = vec_len(extra);
    let mut i: i64 = 0;
    while i < n {
        v.push(vec_get(extra, i));
        i = i + 1;
    };
    return vec_len(v);
}

#[manual_drop]
fn rt_string_vec_append_unique(v: Vec<i32>, extra: Vec<i32>) -> i64 {
    let n: i64 = vec_len(extra);
    let mut i: i64 = 0;
    while i < n {
        priv_string_vec_push_unique(v, vec_get(extra, i));
        i = i + 1;
    };
    return vec_len(v);
}

#[manual_drop]
// R05 RFC-0033 row-subtyping bridge.
// this was a whole-header word search that false-positived on any
// occurrence of `effect_name` outside the `with [...]` row — e.g.
// a parameter or type name `Alloc` made the fn look Alloc-effecting
// even when it was declared `with [no_alloc]`. The shared
// row-overlap helper `restricts_row_covers_effect` (used by the
// requires/restricts pre-passes since v0840) now scopes the check
// to the actual with-row contents and applies the symmetric family
// covering rule (token == eff, or eff is sub of token, or token is
// sub of eff). Edge cases preserved: zero `with` keyword in header
// returns 0 immediately; multi-token rows still match per token;
// case-sensitive comparison preserved.
// v0843 R05 consolidation spike: generic row extractor for any
// keyword that introduces a `KEYWORD [ROW]` clause in a fn header.
// Replaces two near-duplicate helpers (effect_row_from_header for
// `requires`, the v0842 extract_with_row for `with`). Word boundary
// is required on the LHS so identifiers like `forwith` or
// `prerequires` don't false-match; optional whitespace is allowed
// between the keyword and `[`.
#[manual_drop]
fn extract_keyword_row(header: str, keyword: str) -> str {
    if str_contains(header, keyword) == 0 { return ""; };
    let hlen: i64 = str_len(header);
    let klen: i64 = str_len(keyword);
    let mut p: i64 = 0;
    while p + klen <= hlen {
        if str_eq_at_len(header, p, keyword, klen) == 1 {
            let before_ok: i64 = if p == 0 { 1 } else {
                let b: i64 = str_char_at(header, p - 1);
                if is_alnum(b) == 0 && b != 95 { 1 } else { 0 }
            };
            let mut q: i64 = p + klen;
            while q < hlen && is_ws(str_char_at(header, q)) == 1 { q = q + 1; };
            if before_ok == 1 && q < hlen && str_char_at(header, q) == 91 {
                let start: i64 = q + 1;
                let mut end: i64 = start;
                while end < hlen && str_char_at(header, end) != 93 { end = end + 1; };
                if end < hlen { return str_substring(header, start, end); };
                return "";
            };
        };
        p = p + 1;
    };
    return "";
}

#[manual_drop]
fn extract_with_row(header: str) -> str {
    return extract_keyword_row(header, "with");
}

#[manual_drop]
fn rt_header_has_effect(header: str, effect_name: str) -> i64 {
    let row: str = extract_with_row(header);
    if str_len(row) == 0 { return 0; };
    return restricts_row_covers_effect(row, effect_name);
}

#[manual_drop]
fn source_has_requires_row_code(source: str) -> i64 {
    let slen: i64 = str_len(source);
    let rkw: str = "requires";
    let rlen: i64 = str_len(rkw);
    let mut p: i64 = 0;
    while p + rlen <= slen {
        let c: i64 = str_char_at(source, p);
        if c == 47 && p + 1 < slen && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if c == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        if c == 39 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 39 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        if str_eq_at_len(source, p, rkw, rlen) == 1 {
            let before_ok: i64 = if p == 0 { 1 } else {
                let b: i64 = str_char_at(source, p - 1);
                if is_alnum(b) == 0 && b != 95 { 1 } else { 0 }
            };
            let mut q: i64 = p + rlen;
            while q < slen && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
            if before_ok == 1 && q < slen && str_char_at(source, q) == 91 { return 1; };
        };
        p = p + 1;
    };
    return 0;
}

#[manual_drop]
fn effect_row_from_header(header: str) -> str {
    return extract_keyword_row(header, "requires");
}

#[manual_drop]
fn effect_row_allows_effect(row: str, eff: str) -> i64 {
    let rlen: i64 = str_len(row);
    let elen: i64 = str_len(eff);
    if elen == 0 { return 1; };
    if rlen == 0 { return 0; };
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    while p <= rlen {
        let at_end: i64 = if p == rlen { 1 } else { 0 };
        let at_comma: i64 = if at_end == 0 && str_char_at(row, p) == 44 { 1 } else { 0 };
        if at_end == 1 || at_comma == 1 {
            let tok: str = str_substring(row, start, p);
            let tlen: i64 = str_len(tok);
            if tlen > 0 {
                if str_eq(tok, eff) == 1 { return 1; };
                if elen > tlen && str_starts_with(eff, str_concat(tok, ".")) == 1 { return 1; };
            };
            start = p + 1;
        };
        p = p + 1;
    };
    return 0;
}

#[manual_drop]
fn effect_row_first_missing(caller_row: str, callee_row: str) -> str {
    let clen: i64 = str_len(callee_row);
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    while p <= clen {
        let at_end: i64 = if p == clen { 1 } else { 0 };
        let at_comma: i64 = if at_end == 0 && str_char_at(callee_row, p) == 44 { 1 } else { 0 };
        if at_end == 1 || at_comma == 1 {
            let eff: str = str_substring(callee_row, start, p);
            if str_len(eff) > 0 && effect_row_allows_effect(caller_row, eff) == 0 { return eff; };
            start = p + 1;
        };
        p = p + 1;
    };
    return "";
}

#[manual_drop]
fn requires_body_direct_missing(row: str, body: str) -> str {
    let calls: Vec<i32> = restricts_extract_call_names(body);
    let cn: i64 = vec_len(calls);
    let mut ci: i64 = 0;
    while ci < cn {
        let callee: str = vec_get(calls, ci);
        let eff: str = restricts_builtin_effect(callee);
        if str_len(eff) > 0 && effect_row_allows_effect(row, eff) == 0 { return eff; };
        ci = ci + 1;
    };
    let stripped: str = strip_strings_and_line_comments(body);
    if effect_row_allows_effect(row, "alloc") == 0 {
        if str_index_of(stripped, "Vec::new") >= 0 { return "alloc"; };
        if str_index_of(stripped, "Box::new") >= 0 { return "alloc"; };
    };
    return "";
}

#[manual_drop]
fn requires_transitive_missing(row: str, body: str, table: Vec<i32>, depth_remaining: i64, visited: Vec<i32>) -> str {
    let direct: str = requires_body_direct_missing(row, body);
    if str_len(direct) > 0 { return direct; };
    let calls: Vec<i32> = restricts_extract_call_names(body);
    let cn: i64 = vec_len(calls);
    let mut ci: i64 = 0;
    while ci < cn {
        let callee: str = vec_get(calls, ci);
        if name_in_vec(visited, callee) == 0 {
            let callee_row: str = lookup_fn_row_in_table(table, callee);
            // Same ambiguity fail-open as in
            // `restricts_transitive_check` and `enforce_requires_direct_calls`.
            // For shared method names with distinct rows, skip the row check
            // and fall through to the body walk (when depth allows).
            let callee_ambig: i64 = name_has_distinct_rows_in_table(table, callee);
            if str_len(callee_row) > 0 && callee_ambig == 0 {
                let missing: str = effect_row_first_missing(row, callee_row);
                if str_len(missing) > 0 { return missing; };
            } else {
                if depth_remaining > 0 {
                    let callee_body: str = lookup_fn_body_in_table(table, callee);
                    if str_len(callee_body) > 0 {
                        visited.push(callee);
                        let nested: str = requires_transitive_missing(row, callee_body, table, depth_remaining - 1, visited);
                        if str_len(nested) > 0 { return nested; };
                    };
                };
            };
        };
        ci = ci + 1;
    };
    return "";
}

#[manual_drop]
fn enforce_requires_direct_calls(diags: Vec<i32>, source: str) -> Vec<i32> {
    if source_has_requires_row_code(source) == 0 { return diags; };
    let table: Vec<i32> = collect_fn_table(source);
    if vec_len(table) == 0 { return diags; };
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            let mut h: i64 = p;
            while h < slen && str_char_at(source, h) != 123 && str_char_at(source, h) != 59 { h = h + 1; };
            let header: str = str_substring(source, p, h);
            let caller_row: str = effect_row_from_header(header);
            if h < slen && str_char_at(source, h) == 123 {
                let body_start: i64 = h + 1;
                let mut q: i64 = h + 1;
                let mut depth: i64 = 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                let mut emitted: i64 = 0;
                if str_len(caller_row) > 0 {
                    let direct_missing: str = requires_body_direct_missing(caller_row, body);
                    if str_len(direct_missing) > 0 {
                        let msg0: str = str_concat("body of `", str_concat(fn_name, str_concat("()` uses effect `", str_concat(direct_missing, "` but its `requires [...]` row does not declare that effect"))));
                        let lc0: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "error", "effect", "EFF-001", msg0, fn_name, vec_get(lc0, 0), vec_get(lc0, 1), "");
                        emitted = 1;
                    };
                };
                let tn: i64 = vec_len(table);
                let mut ti: i64 = 0;
                while ti + 2 < tn && emitted == 0 {
                    let callee: str = vec_get(table, ti);
                    let callee_row: str = vec_get(table, ti + 1);
                    // Skip ambiguous-name callees.
                    // Source-text substring search can't pick which impl a
                    // receiver-typed call resolves to; failing open here
                    // avoids false-positive EFF-001 on the un-rowed impl
                    // when an unrelated rowed impl shares the name. See
                    // `name_has_distinct_rows_in_table` for the rationale.
                    if str_eq(callee, fn_name) == 0 && str_len(callee_row) > 0 && name_has_distinct_rows_in_table(table, callee) == 0 {
                        let pat: str = str_concat(callee, "(");
                        if str_contains(body, pat) == 1 {
                            let missing: str = effect_row_first_missing(caller_row, callee_row);
                            if str_len(missing) > 0 {
                                let msg: str = str_concat("call to `", str_concat(callee, str_concat("()` requires effect `", str_concat(missing, str_concat("` but `", str_concat(fn_name, "` does not declare that effect in `requires [...]`"))))));
                                let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                                diag_add_ex(diags, "error", "effect", "EFF-001", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                                emitted = 1;
                            };
                        };
                    };
                    ti = ti + 3;
                };
                if emitted == 0 && str_len(caller_row) > 0 {
                    let mut visited: Vec<i32> = Vec::new();
                    visited.push(fn_name);
                    // Bump from depth=3 to depth=8 to
                    // match `restricts_transitive_check`'s bound. Visited-set
                    // dedup already gives O(N) termination per chain, so the
                    // wider hop budget closes the silent fall-through where a
                    // 4..=7-hop transitive chain (often produced by helpers
                    // imported via the resolved-source path) reached a rowed
                    // effect without a diagnostic. Probe v0845: 4-deep
                    // cross-module chain caller→hop1→...→hop4→print built
                    // clean at depth=3; rebuilds with EFF-001 at depth=8.
                    let trans_missing: str = requires_transitive_missing(caller_row, body, table, 8, visited);
                    if str_len(trans_missing) > 0 {
                        let msg2: str = str_concat("call chain from `", str_concat(fn_name, str_concat("()` reaches effect `", str_concat(trans_missing, "` but its `requires [...]` row does not declare that effect"))));
                        let lc2: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "error", "effect", "EFF-001", msg2, fn_name, vec_get(lc2, 0), vec_get(lc2, 1), "");
                    };
                };
                p = q;
            } else {
                p = eol + 1;
            };
        } else {
            p = eol + 1;
        };
    };
    return diags;
}

