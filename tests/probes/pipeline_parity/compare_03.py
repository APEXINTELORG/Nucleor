#!/usr/bin/env python3
"""Compare PROBE-2 pipeline 03 (KMeans) Nucleor stdout against reference
JSON. KMeans cluster IDs are PERMUTATION-INVARIANT — the comparison
checks (a) cluster-size signature (sorted partition sizes) matches the
reference, (b) the cluster-membership equivalence partition is the same
(any permutation of cluster IDs that yields the same row-equivalence
classes passes)."""
import json
import re
import sys
from collections import Counter


def parse_nucleor(path: str) -> dict:
    out = {"labels": [], "cluster_size_signature_sorted": []}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = [ln.rstrip("\r\n") for ln in f]
    section = None
    for ln in lines:
        s = ln.strip()
        if s == "labels:":
            section = "labels"
            continue
        if s == "cluster_size_signature_sorted:":
            section = "signature"
            continue
        if not s:
            section = None
            continue
        if section == "labels" and re.fullmatch(r"-?\d+", s):
            out["labels"].append(int(s))
        elif section == "signature" and re.fullmatch(r"-?\d+", s):
            out["cluster_size_signature_sorted"].append(int(s))
    return out


def partition_signature(labels):
    """Group row indices by cluster ID, then sort each group + sort the
    list of groups. Identical for any cluster-ID permutation."""
    by_label = {}
    for i, lab in enumerate(labels):
        by_label.setdefault(lab, []).append(i)
    return sorted(tuple(g) for g in by_label.values())


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: compare_03.py <nucleor_stdout> <reference_json>", file=sys.stderr)
        return 2

    got = parse_nucleor(sys.argv[1])
    ref = json.load(open(sys.argv[2], "r", encoding="utf-8"))

    # 1. Cluster size signature: sorted partition sizes.
    expected_sig = sorted(Counter(ref["labels"]).values())
    if got["cluster_size_signature_sorted"] != expected_sig:
        print(
            f"cluster_size_signature mismatch: got={got['cluster_size_signature_sorted']} "
            f"expected={expected_sig}",
            file=sys.stderr,
        )
        return 1

    # 2. Partition equivalence: same row-equivalence classes regardless of
    # cluster-ID permutation.
    if partition_signature(got["labels"]) != partition_signature(ref["labels"]):
        print(
            f"partition mismatch: got={partition_signature(got['labels'])} "
            f"expected={partition_signature(ref['labels'])}",
            file=sys.stderr,
        )
        return 1

    print(
        f"PROBE-2 03: partition byte-equal under cluster-ID permutation, "
        f"sizes={got['cluster_size_signature_sorted']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
