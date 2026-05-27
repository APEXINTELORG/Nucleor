#!/usr/bin/env python3
"""Strip leading-vX.Y.Z multi-line comment blocks from compiler source files.

Each block is recognized as:
  - first line matches r'^(\s*)//\s*v\d+\.\d+(\.\d+)?\b'
  - subsequent lines at the same indentation that start with `//` are also
    part of the block
  - block ends at the first line that is not `//` at that indentation

Removed blocks get archived to docs/internals/history.md under per-file
sections so the original triage notes are not lost.

Run from the repo root:
  python3 tools/strip_version_stamps.py
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HISTORY = ROOT / "docs/internals/history.md"

VERSION_RE = re.compile(r"^(\s*)//\s*v\d+\.\d+(?:\.\d+)?\b")
CONTINUATION_RE = re.compile(r"^\s*//")

TARGETS = sorted(
    [p for p in (ROOT / "compiler/s1").glob("*.nr") if not p.name.endswith(".gen.nr")]
    + [p for p in (ROOT / "compiler/ts").glob("*.nr") if not p.name.endswith(".gen.nr")]
)


def process_file(path: Path):
    lines = path.read_text().splitlines(keepends=False)
    out = []
    archived = []  # (start_line, [block_lines])
    i = 0
    while i < len(lines):
        line = lines[i]
        m = VERSION_RE.match(line)
        if not m:
            out.append(line)
            i += 1
            continue
        indent = m.group(1)
        block_start = i
        block = [line]
        j = i + 1
        while j < len(lines):
            nxt = lines[j]
            if nxt.startswith(indent) and CONTINUATION_RE.match(nxt[len(indent):]):
                block.append(nxt)
                j += 1
            else:
                break
        archived.append((block_start + 1, block))
        i = j
    return out, archived


def main():
    history_chunks = ["# Source-Comment History Archive",
                      "",
                      "Auto-extracted from `compiler/s1/*.nr` and `compiler/ts/*.nr`",
                      "by `tools/strip_version_stamps.py`. The triage / fix notes that",
                      "used to live inline are preserved here so a reader can still",
                      "trace the why of a given defensive halt back to the original",
                      "version pin. The compiler source itself no longer carries the",
                      "per-fix narrative; behavior is documented by the inline",
                      "`print(...)` / `panic(...)` calls and by the surrounding code.",
                      ""]
    total_blocks = 0
    total_lines_removed = 0
    for path in TARGETS:
        out, archived = process_file(path)
        if not archived:
            continue
        path.write_text("\n".join(out) + ("\n" if out and out[-1] != "" else ""))
        rel = path.relative_to(ROOT)
        history_chunks.append(f"## `{rel}`")
        history_chunks.append("")
        for start_line, block in archived:
            total_blocks += 1
            total_lines_removed += len(block)
            history_chunks.append(f"### `{rel}:{start_line}`")
            history_chunks.append("")
            history_chunks.append("```")
            history_chunks.extend(block)
            history_chunks.append("```")
            history_chunks.append("")
    HISTORY.parent.mkdir(parents=True, exist_ok=True)
    HISTORY.write_text("\n".join(history_chunks) + "\n")
    print(f"stripped {total_blocks} comment blocks ({total_lines_removed} lines)")
    print(f"archived to {HISTORY}")


if __name__ == "__main__":
    main()
