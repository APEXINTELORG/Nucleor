// =====================================================
// rods/cli — Command-line argument parsing
// =====================================================
// Import: import "stdlib/rods/cli.nr"
// Depends: import "stdlib/rods/strings.nr" (for strings_starts_with, strings_char_to_str)
// Provides: cli_new, cli_flag, cli_option, cli_positional, cli_parse,
//   cli_get, cli_get_int, cli_has, cli_positionals, cli_help
// =====================================================

import "stdlib/rods/strings.nr"
import "stdlib/rods/fmt.nr"

// CLI layout (Vec):
//   [0] = program name (str)
//   [1] = description (str)
//   [2] = flags Vec — each entry is [name, short, desc, type, default]
//   [3] = parsed values (map-like: parallel vecs of name → value)
//   [4] = positional args Vec<str>

fn cli_new(name: str, desc: str) -> Vec<i32> {
    let mut c: Vec<i32> = Vec::new();
    c.push(name);
    c.push(desc);
    let mut flags: Vec<i32> = Vec::new();
    c.push(flags);
    let mut parsed_names: Vec<i32> = Vec::new();
    let mut parsed_vals: Vec<i32> = Vec::new();
    c.push(parsed_names);
    c.push(parsed_vals);
    let mut positionals: Vec<i32> = Vec::new();
    c.push(positionals);
    return c;
}

// type: 0 = bool flag, 1 = string option
//
// v0.8.41 RFC-0062 G-1: `f` is a HANDOFF local — the Vec is
// pushed INTO `flags` (a registry-like field of `c`) where its
// pointer outlives this fn. Under the Phase 2b-3 default-flip,
// auto-drop on `f` would dangle the registry entry. The
// `#[manual_drop]` attribute opts this fn out of default-flip
// auto-drop semantics, preserving the v0.x handoff behavior.
#[manual_drop]
fn cli_add_flag(c: Vec<i32>, name: str, short_name: str, desc: str) {
    let flags: i64 = c.get(2);
    let mut f: Vec<i32> = Vec::new();
    f.push(name);
    f.push(short_name);
    f.push(desc);
    f.push(0);
    f.push("");
    vec_push(flags, f);
}

// v0.8.41 RFC-0062 G-1: same handoff pattern as cli_add_flag.
#[manual_drop]
fn cli_add_option(c: Vec<i32>, name: str, short_name: str, desc: str, default_val: str) {
    let flags: i64 = c.get(2);
    let mut f: Vec<i32> = Vec::new();
    f.push(name);
    f.push(short_name);
    f.push(desc);
    f.push(1);
    f.push(default_val);
    vec_push(flags, f);
}

fn cli_find_flag(c: Vec<i32>, arg: str) -> i64 {
    let flags: i64 = c.get(2);
    let flen: i64 = vec_len(flags);
    let mut i: i64 = 0;
    while i < flen {
        let f: i64 = vec_get(flags, i);
        let name: str = vec_get(f, 0);
        let short_n: str = vec_get(f, 1);
        if str_eq(arg, str_concat("--", name)) { return i; };
        if str_len(short_n) > 0 && str_eq(arg, str_concat("-", short_n)) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn cli_set_parsed(c: Vec<i32>, name: str, value: str) {
    let pnames: i64 = c.get(3);
    let pvals: i64 = c.get(4);
    let plen: i64 = vec_len(pnames);
    let mut i: i64 = 0;
    while i < plen {
        if str_eq(vec_get(pnames, i), name) {
            vec_set(pvals, i, value);
            return;
        };
        i = i + 1;
    };
    vec_push(pnames, name);
    vec_push(pvals, value);
}

fn cli_parse(c: Vec<i32>) -> i64 {
    // Set defaults
    let flags: i64 = c.get(2);
    let flen: i64 = vec_len(flags);
    let mut fi: i64 = 0;
    while fi < flen {
        let f: i64 = vec_get(flags, fi);
        let ftype: i64 = vec_get(f, 3);
        if ftype == 0 {
            cli_set_parsed(c, vec_get(f, 0), "false");
        } else {
            cli_set_parsed(c, vec_get(f, 0), vec_get(f, 4));
        };
        fi = fi + 1;
    };

    let argc: i64 = args_count();
    let mut i: i64 = 1;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--help") || str_eq(arg, "-h") {
            cli_help(c);
            return 0 - 1;
        };
        let fidx: i64 = cli_find_flag(c, arg);
        if fidx >= 0 {
            let f: i64 = vec_get(flags, fidx);
            let ftype: i64 = vec_get(f, 3);
            let fname: str = vec_get(f, 0);
            if ftype == 0 {
                cli_set_parsed(c, fname, "true");
            } else {
                i = i + 1;
                if i < argc {
                    cli_set_parsed(c, fname, args_get(i));
                };
            };
        } else {
            let positionals: i64 = c.get(5);
            vec_push(positionals, arg);
        };
        i = i + 1;
    };
    return 0;
}

fn cli_get(c: Vec<i32>, name: str) -> str {
    let pnames: i64 = c.get(3);
    let pvals: i64 = c.get(4);
    let plen: i64 = vec_len(pnames);
    let mut i: i64 = 0;
    while i < plen {
        if str_eq(vec_get(pnames, i), name) { return vec_get(pvals, i); };
        i = i + 1;
    };
    return "";
}

fn cli_has(c: Vec<i32>, name: str) -> i64 {
    return str_eq(cli_get(c, name), "true");
}

fn cli_get_int(c: Vec<i32>, name: str) -> i64 {
    let val: str = cli_get(c, name);
    if str_len(val) == 0 { return 0; };
    return fmt_to_int(val);
}

fn cli_positionals(c: Vec<i32>) -> Vec<i32> {
    return c.get(5);
}

fn cli_help(c: Vec<i32>) {
    print(str_concat(c.get(0), str_concat(" - ", c.get(1))));
    print("");
    print("Usage:");
    let flags: i64 = c.get(2);
    let flen: i64 = vec_len(flags);
    let mut i: i64 = 0;
    while i < flen {
        let f: i64 = vec_get(flags, i);
        let name: str = vec_get(f, 0);
        let short_n: str = vec_get(f, 1);
        let desc: str = vec_get(f, 2);
        let ftype: i64 = vec_get(f, 3);
        let mut sb: i64 = sb_new();
        sb_append(sb, "  --");
        sb_append(sb, name);
        if str_len(short_n) > 0 {
            sb_append(sb, ", -");
            sb_append(sb, short_n);
        };
        if ftype == 1 { sb_append(sb, " <value>"); };
        sb_append(sb, "  ");
        sb_append(sb, desc);
        if ftype == 1 && str_len(vec_get(f, 4)) > 0 {
            sb_append(sb, " (default: ");
            sb_append(sb, vec_get(f, 4));
            sb_append(sb, ")");
        };
        print(sb_to_str(sb));
        i = i + 1;
    };
}
