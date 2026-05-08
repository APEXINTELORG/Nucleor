#!/usr/bin/env python3
"""Compare PROBE-2 pipeline 01 (tabular_classification) Nucleor stdout
against reference JSON's predict fields.

Usage: python compare_01.py <nucleor_stdout> <reference_json>
Exit 0 on byte-equal predict; non-zero on mismatch.
"""
import json
import re
import sys


def parse_nucleor(path: str) -> dict:
    """Parse the structured plain-text output of pipeline_01."""
    out = {"y_pred": [], "accuracy_correct": None, "accuracy_total": None}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = [ln.rstrip("\r\n") for ln in f]
    section = None
    for ln in lines:
        s = ln.strip()
        if s == "y_pred:":
            section = "y_pred"
            continue
        if s == "accuracy_correct:":
            section = "accuracy_correct"
            continue
        if s == "accuracy_total:":
            section = "accuracy_total"
            continue
        if not s:
            section = None
            continue
        if section == "y_pred" and re.fullmatch(r"-?\d+", s):
            out["y_pred"].append(int(s))
        elif section == "accuracy_correct" and re.fullmatch(r"-?\d+", s):
            out["accuracy_correct"] = int(s)
            section = None
        elif section == "accuracy_total" and re.fullmatch(r"-?\d+", s):
            out["accuracy_total"] = int(s)
            section = None
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: compare_01.py <nucleor_stdout> <reference_json>", file=sys.stderr)
        return 2

    got = parse_nucleor(sys.argv[1])
    ref = json.load(open(sys.argv[2], "r", encoding="utf-8"))

    if got["y_pred"] != ref["y_pred"]:
        print(f"y_pred mismatch: got={got['y_pred']} expected={ref['y_pred']}", file=sys.stderr)
        return 1

    expected_correct = sum(1 for a, b in zip(ref["y_pred"], ref["y_test"]) if a == b)
    expected_total = len(ref["y_test"])
    if got["accuracy_correct"] != expected_correct:
        print(
            f"accuracy_correct mismatch: got={got['accuracy_correct']} expected={expected_correct}",
            file=sys.stderr,
        )
        return 1
    if got["accuracy_total"] != expected_total:
        print(
            f"accuracy_total mismatch: got={got['accuracy_total']} expected={expected_total}",
            file=sys.stderr,
        )
        return 1

    print(f"PROBE-2 01: y_pred byte-equal, accuracy {got['accuracy_correct']}/{got['accuracy_total']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
