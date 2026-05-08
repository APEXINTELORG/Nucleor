#!/usr/bin/env python3
"""Compare PROBE-2 pipeline 02 (regression) Nucleor stdout against
reference JSON's predict fields. Numeric tolerance 1e-5 (Nucleor prints
f64 to 6 decimals; reference is full-precision)."""
import json
import re
import sys


TOLERANCE = 1e-5


def parse_nucleor(path: str) -> dict:
    out = {"y_pred": [], "close_count_vs_reference": None, "close_count_total": None}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = [ln.rstrip("\r\n") for ln in f]
    section = None
    for ln in lines:
        s = ln.strip()
        if s == "y_pred:":
            section = "y_pred"
            continue
        if s == "close_count_vs_reference:":
            section = "close_count_vs_reference"
            continue
        if s == "close_count_total:":
            section = "close_count_total"
            continue
        if not s:
            section = None
            continue
        if section == "y_pred" and re.fullmatch(r"-?\d+(?:\.\d+)?", s):
            out["y_pred"].append(float(s))
        elif section == "close_count_vs_reference" and re.fullmatch(r"-?\d+", s):
            out["close_count_vs_reference"] = int(s)
            section = None
        elif section == "close_count_total" and re.fullmatch(r"-?\d+", s):
            out["close_count_total"] = int(s)
            section = None
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: compare_02.py <nucleor_stdout> <reference_json>", file=sys.stderr)
        return 2

    got = parse_nucleor(sys.argv[1])
    ref = json.load(open(sys.argv[2], "r", encoding="utf-8"))

    if len(got["y_pred"]) != len(ref["y_pred"]):
        print(
            f"y_pred length mismatch: got={len(got['y_pred'])} expected={len(ref['y_pred'])}",
            file=sys.stderr,
        )
        return 1
    for i, (a, b) in enumerate(zip(got["y_pred"], ref["y_pred"])):
        if abs(a - b) > TOLERANCE:
            print(
                f"y_pred[{i}] mismatch: got={a} expected={b} delta={abs(a - b)}",
                file=sys.stderr,
            )
            return 1

    if got["close_count_vs_reference"] != got["close_count_total"]:
        print(
            f"self-check mismatch: close_count_vs_reference={got['close_count_vs_reference']} "
            f"!= close_count_total={got['close_count_total']}",
            file=sys.stderr,
        )
        return 1

    print(
        f"PROBE-2 02: y_pred {len(got['y_pred'])}/{len(ref['y_pred'])} within {TOLERANCE} abs"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
