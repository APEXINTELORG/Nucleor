#!/usr/bin/env python3
# G-1 default-flip safety audit (RFC-0062 IMPLEMENTATION-PLAN §3 G-1).
#
# Surveys every fn in the compiler + stdlib rod tree. For each fn:
#   - detects "heap-backed-locals" — Vec::new(), HashMap::new(),
#     String::new(), Box::new(), VecDeque::new()
#   - detects "explicit-free" — vec_free(, hashmap_free(,
#     string_free(, box_free(, vecdeque_free(
#   - detects "auto_drop" — #[auto_drop] attribute on the fn
#   - detects "manual_drop" — #[manual_drop] attribute on the fn
#   - detects "returns owned" — return type is Vec<...> / HashMap<...> /
#     String / Box<...> (owned heap return; bare-name return path
#     skips drop per RFC-0042)
#
# Reports fns that HAVE heap-backed locals AND NO explicit free AND
# NO existing auto_drop AND NO manual_drop AND don't return owned —
# these are the candidates whose behavior would change at the
# default-flip ship.
#
# Output: stdout summary + tools/g1_safety_audit_report.txt detail.

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMPILER_FILES = [
    "compiler/nucleor_s1_compiler.nr",
    "compiler/nucleor_tools_suite.nr",
]
STDLIB_RODS_DIR = "stdlib/rods"

HEAP_PATTERNS = [
    r"Vec::new\(\)",
    r"Vec<\w+>::with_capacity",
    r"HashMap::new\(\)",
    r"String::new\(\)",
    r"Box::new\(",
    r"VecDeque::new\(\)",
]
HEAP_RE = re.compile("|".join(HEAP_PATTERNS))

FREE_RE = re.compile(r"\b(vec_free|hashmap_free|string_free|box_free|vecdeque_free)\s*\(")
AUTO_DROP_RE = re.compile(r"#\[auto_drop\]")
MANUAL_DROP_RE = re.compile(r"#\[manual_drop\]")

# Match `fn NAME(` capturing NAME and start byte position.
FN_DECL_RE = re.compile(r"\bfn\s+(\w+)\s*[<(]")

# Match return types that imply owned-heap-return (bare-name return
# pattern skips drop per RFC-0042).
RETURN_OWNED_RE = re.compile(
    r"->\s*(Vec<|HashMap<|String\b|Box<|VecDeque<)"
)


def split_into_fns(source: str):
    """Yield (fn_name, body_text, decl_line, attribute_block) for each fn.

    Naive brace-balancer. Skips comments and strings. Returns the source
    spanning from the fn declaration to the matching closing brace.
    """
    n = len(source)
    i = 0
    while i < n:
        # Skip line comments
        if i + 1 < n and source[i] == "/" and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                i += 1
            continue
        # Skip strings (very rough)
        if source[i] == '"':
            i += 1
            while i < n and source[i] != '"':
                if source[i] == "\\" and i + 1 < n:
                    i += 2
                else:
                    i += 1
            i += 1
            continue
        m = FN_DECL_RE.match(source, i)
        if not m:
            i += 1
            continue
        fn_name = m.group(1)
        # Find the body opening brace
        j = m.end()
        while j < n and source[j] != "{":
            j += 1
        if j >= n:
            i = m.end()
            continue
        # Look back to find any preceding attribute block (#[...]
        # lines) on the lines immediately before the fn keyword.
        attr_start = m.start()
        k = attr_start - 1
        # Scan back to find the start of the line containing the fn decl
        while k >= 0 and source[k] != "\n":
            k -= 1
        # k is now at the newline before the fn decl line
        # Walk back through #[...] lines
        attr_block_start = k + 1
        cursor = k
        while cursor > 0:
            line_end = cursor
            line_start = cursor - 1
            while line_start > 0 and source[line_start] != "\n":
                line_start -= 1
            line_text = source[line_start + 1: line_end].strip()
            if line_text.startswith("#["):
                attr_block_start = line_start + 1
                cursor = line_start
            else:
                break
        attribute_block = source[attr_block_start: m.start()]
        # Brace balance from j
        depth = 0
        end = j
        while end < n:
            c = source[end]
            if c == "/" and end + 1 < n and source[end + 1] == "/":
                while end < n and source[end] != "\n":
                    end += 1
                continue
            if c == '"':
                end += 1
                while end < n and source[end] != '"':
                    if source[end] == "\\" and end + 1 < n:
                        end += 2
                    else:
                        end += 1
                end += 1
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    end += 1
                    break
            end += 1
        body = source[j: end]
        # Decl line for return-type detection
        decl_line = source[m.start(): j]
        yield fn_name, body, decl_line, attribute_block
        i = end


def audit_file(path: str, source: str):
    candidates = []
    summary = {
        "total_fns": 0,
        "with_heap": 0,
        "with_heap_no_free": 0,
        "with_heap_already_auto": 0,
        "with_heap_already_manual": 0,
        "with_heap_returns_owned": 0,
        "with_heap_has_free": 0,
        "candidates": 0,
    }
    for fn_name, body, decl, attrs in split_into_fns(source):
        summary["total_fns"] += 1
        has_heap = bool(HEAP_RE.search(body))
        if not has_heap:
            continue
        summary["with_heap"] += 1
        has_free = bool(FREE_RE.search(body))
        has_auto = bool(AUTO_DROP_RE.search(attrs))
        has_manual = bool(MANUAL_DROP_RE.search(attrs))
        returns_owned = bool(RETURN_OWNED_RE.search(decl))
        if has_auto:
            summary["with_heap_already_auto"] += 1
            continue
        if has_manual:
            summary["with_heap_already_manual"] += 1
            continue
        if has_free:
            summary["with_heap_has_free"] += 1
            continue
        if returns_owned:
            summary["with_heap_returns_owned"] += 1
            continue
        # Candidate: heap-backed locals, no free, no existing
        # auto/manual attribute, doesn't return owned. Behavior
        # would change at default-flip.
        summary["with_heap_no_free"] += 1
        summary["candidates"] += 1
        candidates.append((fn_name,))
    return summary, candidates


def main():
    files = []
    for f in COMPILER_FILES:
        full = os.path.join(ROOT, f)
        if os.path.exists(full):
            files.append((f, full))
    rod_dir = os.path.join(ROOT, STDLIB_RODS_DIR)
    if os.path.isdir(rod_dir):
        for fn in sorted(os.listdir(rod_dir)):
            if fn.endswith(".nr"):
                files.append((os.path.join(STDLIB_RODS_DIR, fn), os.path.join(rod_dir, fn)))

    grand_total = {
        "files": len(files),
        "total_fns": 0,
        "with_heap": 0,
        "candidates": 0,
        "already_auto": 0,
        "already_manual": 0,
        "has_free": 0,
        "returns_owned": 0,
    }
    report_lines = []
    report_lines.append("# G-1 Default-Flip Safety Audit Report")
    report_lines.append("")
    report_lines.append("Per RFC-0062 IMPLEMENTATION-PLAN §3 G-1.")
    report_lines.append("")
    report_lines.append("Each row: fn_name in file. These fns have heap-backed")
    report_lines.append("locals (Vec/HashMap/String/Box/VecDeque) but NO explicit")
    report_lines.append("free, NO #[auto_drop], NO #[manual_drop], and don't return")
    report_lines.append("owned. Behavior CHANGES at the Phase 2b-3 default-flip ship.")
    report_lines.append("")
    report_lines.append("Action required per fn:")
    report_lines.append("  a) ADD `vec_free(v)` (or appropriate free) before return")
    report_lines.append("     if the leak is a bug.")
    report_lines.append("  b) ADD `#[manual_drop]` to acknowledge the intentional")
    report_lines.append("     handoff (e.g., to long-lived registry).")
    report_lines.append("  c) Refactor to return the owned value (bare-name return")
    report_lines.append("     skips drop per RFC-0042).")
    report_lines.append("")
    for relpath, full in files:
        with open(full, "rb") as fh:
            src = fh.read().decode("utf-8", errors="replace")
        summary, candidates = audit_file(relpath, src)
        grand_total["total_fns"] += summary["total_fns"]
        grand_total["with_heap"] += summary["with_heap"]
        grand_total["candidates"] += summary["candidates"]
        grand_total["already_auto"] += summary["with_heap_already_auto"]
        grand_total["already_manual"] += summary["with_heap_already_manual"]
        grand_total["has_free"] += summary["with_heap_has_free"]
        grand_total["returns_owned"] += summary["with_heap_returns_owned"]
        if candidates:
            report_lines.append(f"## {relpath}")
            report_lines.append(f"({len(candidates)} candidate fns)")
            report_lines.append("")
            for (name,) in candidates:
                report_lines.append(f"- {name}")
            report_lines.append("")
    summary_block = [
        "",
        "# Summary",
        f"  Files audited:               {grand_total['files']}",
        f"  Total fns:                   {grand_total['total_fns']}",
        f"  Fns with heap-backed locals: {grand_total['with_heap']}",
        f"    of which:",
        f"      already #[auto_drop]:    {grand_total['already_auto']}",
        f"      already #[manual_drop]:  {grand_total['already_manual']}",
        f"      has explicit free:       {grand_total['has_free']}",
        f"      returns owned heap:      {grand_total['returns_owned']}",
        f"      DEFAULT-FLIP CANDIDATES: {grand_total['candidates']}",
        "",
    ]
    out_path = os.path.join(ROOT, "tools", "g1_safety_audit_report.txt")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(summary_block + report_lines))
    print("\n".join(summary_block))
    print(f"Detail report: {out_path}")


if __name__ == "__main__":
    main()
