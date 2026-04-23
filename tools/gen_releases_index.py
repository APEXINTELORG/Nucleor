#!/usr/bin/env python3
"""
gen_releases_index.py — Generate RELEASES.md from CHANGELOG.md.

CHANGELOG.md has 179+ entries through the v0.2.x chain
(v0.1.46 → v0.2.110+ as of this docstring). RELEASES.md is a
navigable tag-only index — one line per release, version + date
+ one-line summary — so readers can scan the chain without paging
through the full CHANGELOG. CHANGELOG↔git-tag parity is
drift-gate-enforced since v0.2.83 (every tag must have a
`## [version]` heading or the verify gate fails).

Usage: python tools/gen_releases_index.py
Output: RELEASES.md (overwrites)

Parsing rules:
  - Each release starts with a line `## [X.Y.Z] — YYYY-MM-DD`
  - The summary is the first **bold** line in the body, OR the first
    non-blank non-bullet line if no bold present.
  - Releases without parseable summaries get `(no summary parsed)` —
    fix the CHANGELOG entry to follow the convention.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
OUT = ROOT / "RELEASES.md"


def parse_changelog():
    text = CHANGELOG.read_text(encoding="utf-8")
    # Each entry begins with a line `## [version] — date` (em-dash or
    # hyphen tolerated). Capture (version, date, body).
    pattern = re.compile(
        r'^## \[([\d.]+)\][^\n]*?(\d{4}-\d{2}-\d{2})\s*\n+(.*?)(?=^## \[|\Z)',
        re.MULTILINE | re.DOTALL,
    )
    rows = []
    for m in pattern.finditer(text):
        version = m.group(1)
        date = m.group(2)
        body = m.group(3)
        # Try to extract the first bold line as the summary.
        bold_match = re.search(r'\*\*([^*]+?)\*\*', body)
        if bold_match:
            summary = bold_match.group(1).strip()
        else:
            # Fallback: first non-blank, non-bullet line.
            for line in body.splitlines():
                s = line.strip()
                if s and not s.startswith(('- ', '* ', '#', '|')):
                    summary = s
                    break
            else:
                summary = "(no summary parsed)"
        # Trim trailing period if present
        summary = summary.rstrip('.')
        rows.append((version, date, summary))
    return rows


def version_key(v):
    """Sort key for X.Y.Z version strings."""
    parts = [int(p) for p in v.split('.')]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def main():
    rows = parse_changelog()
    if not rows:
        print("ERROR: no releases parsed from CHANGELOG.md", file=sys.stderr)
        sys.exit(1)

    # Sort by version descending (newest first, matches CHANGELOG order)
    rows.sort(key=lambda r: version_key(r[0]), reverse=True)

    out_lines = []
    out_lines.append("# Releases")
    out_lines.append("")
    out_lines.append(
        "Tag-only navigable index of every Nucleor release. Generated "
        "by `tools/gen_releases_index.py` from `CHANGELOG.md`."
    )
    out_lines.append("")
    out_lines.append(
        "For full per-release notes (changes, gate status, fixed point), "
        "see [`CHANGELOG.md`](CHANGELOG.md). For RFC-by-RFC status see "
        "[`docs/rfcs/README.md`](docs/rfcs/README.md). For the v0.2 "
        "shipped/deferred rollup see "
        "[`docs/status/v0.2-shipped-and-deferred.md`](docs/status/v0.2-shipped-and-deferred.md)."
    )
    out_lines.append("")
    out_lines.append(f"**Total releases:** {len(rows)}")
    out_lines.append("")
    out_lines.append(
        "GitHub tag URLs follow the pattern "
        "`https://github.com/APEXINTELORG/Nucleor/releases/tag/vX.Y.Z`."
    )
    out_lines.append("")

    # Group by major.minor (e.g. 0.2, 0.1) for visual separation
    groups = {}
    for v, d, s in rows:
        major_minor = ".".join(v.split('.')[:2])
        groups.setdefault(major_minor, []).append((v, d, s))

    for mm in sorted(groups.keys(), key=version_key, reverse=True):
        out_lines.append(f"## v{mm}.x")
        out_lines.append("")
        out_lines.append("| Version | Date | Summary |")
        out_lines.append("|---|---|---|")
        for v, d, s in groups[mm]:
            # Markdown-escape the pipe character in summaries
            s_esc = s.replace('|', '\\|')
            out_lines.append(f"| **v{v}** | {d} | {s_esc} |")
        out_lines.append("")

    OUT.write_text("\n".join(out_lines), encoding="utf-8")

    no_summary = sum(1 for v, d, s in rows if s == "(no summary parsed)")
    print(f"Wrote {OUT}")
    print(f"Total releases: {len(rows)}")
    if no_summary:
        print(f"WARN: {no_summary} entries had no parseable summary "
              f"(fix CHANGELOG.md and re-run)")


if __name__ == "__main__":
    main()
