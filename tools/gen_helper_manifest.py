#!/usr/bin/env python3
"""
gen_helper_manifest.py — Generate docs/rfcs/helper_manifest.toml from the
canonical compiler ABI tables and runtime C source.

Authoritative sources (read-only):
  compiler/nucleor_s1_compiler.nr   (get_rt_name / is_ptr_ret / is_ptr_arg /
                                     is_void_ret tables + IR `declare` block)
  compiler/nucleor_tools_suite.nr   (mirror — drift gate enforces parity)
  stdlib/runtime/*.c                (__nucleor_* definitions)

Usage: python tools/gen_helper_manifest.py

Output: docs/rfcs/helper_manifest.toml (overwrites)

This script is the executable form of the Helpers.md contract Phase 2:
- Inventories every helper symbol declared by the compiler.
- Classifies by name pattern into the 14 v0.2.39 taxonomy classes.
- Marks unclassified entries as `class = "Unclassified"` and lists
  them under the file's REVIEW REQUIRED block.
- Marks declared-but-undefined entries as `stability = "experimental"`
  with a `notes` flag (latent linker gaps from earlier eras).
- Marks policy-sensitive fields (effects, taint, units,
  proof_obligation) as TODO unless trivially derivable; non-trivial
  rows go under REVIEW REQUIRED.

Re-run this script after adding any new helper. The Helpers.md contract
going-forward constraint requires the manifest to stay in sync.
"""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
S1 = ROOT / "compiler" / "nucleor_s1_compiler.nr"
RT_DIR = ROOT / "stdlib" / "runtime"
OUT = ROOT / "docs" / "rfcs" / "helper_manifest.toml"


# ---------- Pull ABI tables from the s1 compiler source ----------

def parse_get_rt_name(src):
    """Return list of (name, symbol) pairs from the get_rt_name table."""
    out = []
    rx = re.compile(r'if str_eq\(name, "([^"]+)"\) \{ return "([^"]+)";')
    for m in rx.finditer(src):
        name, symbol = m.group(1), m.group(2)
        if symbol.startswith("__nucleor_"):
            out.append((name, symbol))
    return out


def parse_is_void_ret(src):
    """Return set of names declared void-returning."""
    # Match the is_void_ret function body by finding the fn definition
    fn_match = re.search(r'fn is_void_ret\(name: str\)[^{]*\{(.*?)\n\}',
                         src, re.DOTALL)
    if not fn_match:
        return set()
    body = fn_match.group(1)
    return set(re.findall(r'if str_eq\(name, "([^"]+)"\) \{ return 1;', body))


def parse_is_ptr_ret(src):
    """Return set of names declared ptr-returning."""
    fn_match = re.search(r'fn is_ptr_ret\(name: str\)[^{]*\{(.*?)\nfn ',
                         src, re.DOTALL)
    if not fn_match:
        return set()
    body = fn_match.group(1)
    return set(re.findall(r'if str_eq\(name, "([^"]+)"\) \{ return 1;', body))


def parse_ir_declares(src):
    """Return dict symbol -> (ret_type, arg_types) from IR declares."""
    out = {}
    rx = re.compile(
        r'sb_append\(sb, "declare ([a-z0-9]+) @(__nucleor_[a-zA-Z0-9_]+)\(([^)]*)\)\\n"'
    )
    for m in rx.finditer(src):
        ret, sym, args = m.group(1), m.group(2), m.group(3).strip()
        arg_list = [a.strip() for a in args.split(",")] if args else []
        out[sym] = (ret, arg_list)
    return out


def collect_runtime_defs():
    """Set of __nucleor_* symbols defined in stdlib/runtime/*.c."""
    out = set()
    for c in sorted(RT_DIR.glob("*.c")):
        text = c.read_text(errors="replace")
        # Function definitions: signature ending in "name(" at line start-ish
        for m in re.finditer(r'\b(__nucleor_[a-zA-Z0-9_]+)\s*\(',
                             text):
            sym = m.group(1)
            # Filter macro-name fragments (trailing underscore on bare token)
            if sym.endswith("_") and len(sym.rstrip("_")) < len(sym) - 0:
                # Allow trailing underscore if it's part of a real symbol like
                # __nucleor_overflow_flag (already rstripped form)
                pass
            out.add(sym)
    return out


# ---------- Classification ----------

CLASS_RULES = [
    # (class_name, list of regex patterns matched against bare helper name)
    ("VectorOps",       [r"^vec_(?!u8|deque)", r"^vec_u8_", r"^f32x4_", r"^i32x4_",
                         r"^simd_", r"^vector_"]),
    ("Collection",      [r"^hashmap_", r"^hashset_", r"^btreemap_", r"^btreeset_",
                         r"^heapmap_", r"^vecdeque_"]),
    ("StringFormat",    [r"^str_", r"^string_", r"^sb_", r"^format_", r"^format[0-9]",
                         r"^chr$", r"^char_", r"^int_to_(str|hex|bin|oct)$",
                         r"^f64_to_str$", r"^bool_to_str$",
                         r"^str_to_(i64|f64|bool)$", r"^str_to_i64_radix$",
                         r"^parse_(hex|bin)$"]),
    ("IO",              [r"^fs_", r"^path_", r"^file_", r"^env_", r"^getenv$",
                         r"^getcwd$", r"^process_id$", r"^os_", r"^read_(line|int|i64|byte)$",
                         r"^stdin_", r"^stdout_", r"^stderr_", r"^isatty_",
                         r"^print", r"^eprint", r"^pipe_", r"^proc_", r"^system$",
                         r"^socket_", r"^http_", r"^tcp_", r"^udp_", r"^putchar$",
                         r"^args_", r"^init_args$", r"^dbg_"]),
    ("Concurrency",     [r"^mutex_", r"^channel_", r"^chan_", r"^thread_",
                         r"^rwlock_", r"^cancel_token_", r"^once_", r"^atomic_",
                         r"^cas_", r"^par_", r"^scheduler_", r"^ambient_scheduler",
                         r"^cpu_count$"]),
    ("Random",          [r"^rng_", r"^random_", r"^ambient_random$"]),
    ("Time",            [r"^time_", r"^sleep_", r"^now_"]),
    ("PanickingArith",  [r"^checked_", r"^saturating_", r"^wrapping_",
                         r"^overflow", r"^panic", r"^trap_", r"^bounds_check",
                         r"^stack_probe", r"^assert$", r"^sat_i32$", r"^wrap_i32$"]),
    ("PureMath",        [r"^popcount$", r"^leading_zeros$", r"^trailing_zeros$",
                         r"^byte_swap$", r"^rotate_left$", r"^rotate_right$",
                         r"^count_ones$", r"^count_zeros$",
                         r"^i64_", r"^f64_", r"^f32_", r"^i32_", r"^f16_",
                         r"^f8e[45]m[23]_to_f32$",
                         r"^abs$", r"^min$", r"^max$", r"^clamp$", r"^sqrt$",
                         r"^sin$", r"^cos$", r"^tan$", r"^pow$", r"^exp$",
                         r"^log$", r"^floor$", r"^ceil$", r"^round$",
                         r"^fabs$", r"^fmod$", r"^sigmoid$", r"^tanh$",
                         r"^relu$", r"^gelu$",
                         r"^as_(f32|f64|i8|i16|i32|i64|u8|u16|u32|u64)$",
                         r"^buf_(read|write)_u(8|16|32|64)"]),
    ("DataCodec",       [r"^toml_", r"^json_", r"^csv_", r"^ini_", r"^base64_",
                         r"^msgpack_", r"^uuid_", r"^sha256", r"^fnv1a",
                         r"^murmur3", r"^crc32", r"^bit_"]),
    ("Allocation",      [r"^region_", r"^arena_", r"^alloc_", r"^free$",
                         r"^realloc$", r"^drop_", r"^malloc$", r"^memcpy$",
                         r"^calloc$", r"^capture_"]),
    ("TensorOps",       [r"^tensor_", r"^matmul", r"^conv2d", r"^attention",
                         r"^cuda_", r"^gpu_", r"^device_", r"^layout_",
                         r"^dlpack_", r"^kvcache_", r"^kvprefix_"]),
    ("ToolingMeta",     [r"^plot_", r"^profile_", r"^certify_", r"^evidence_",
                         r"^impact_", r"^audit_", r"^policy_", r"^doc_",
                         r"^manifest_", r"^stage_", r"^bench_", r"^cli_",
                         r"^test_", r"^summary_", r"^py_eval$",
                         r"^rods_f64_"]),
]


def classify(name):
    for cls, patterns in CLASS_RULES:
        for p in patterns:
            if re.match(p, name):
                return cls
    return "Unclassified"


def fmt_abi(ir_decl):
    if not ir_decl:
        return "TODO"
    ret, args = ir_decl
    args_str = ", ".join(args) if args else ""
    return f"({args_str}) -> {ret}"


# ---------- Main ----------

def main():
    src = S1.read_text(errors="replace")

    rt_pairs = parse_get_rt_name(src)            # (name, symbol)
    void_set = parse_is_void_ret(src)
    ptr_ret_set = parse_is_ptr_ret(src)
    ir = parse_ir_declares(src)                  # symbol -> (ret, args)
    rt_defs = collect_runtime_defs()

    # Deduplicate by symbol — many short names map to the same symbol
    by_symbol = {}
    for name, symbol in rt_pairs:
        if symbol not in by_symbol:
            by_symbol[symbol] = name
        # else: keep first short name; alternatives are aliases

    # Add IR-only entries (symbols declared but with no get_rt_name mapping
    # — usually generated from macro expansion or referenced internally).
    for sym in sorted(ir.keys()):
        if sym not in by_symbol:
            short = sym[len("__nucleor_"):]
            by_symbol[sym] = short

    # ---- Classify and emit ----
    rows = []
    for sym, name in by_symbol.items():
        cls = classify(name)
        ir_decl = ir.get(sym)
        defined = sym in rt_defs
        stability = "stable" if defined else "experimental"

        notes_bits = []
        if not defined:
            notes_bits.append("declared in IR but no __nucleor_* definition found in stdlib/runtime/*.c (REVIEW REQUIRED)")
        if cls == "Unclassified":
            notes_bits.append("name pattern did not match any class rule (REVIEW REQUIRED)")

        rows.append({
            "name": name,
            "class": cls,
            "symbol": sym,
            "dispatch": "RuntimeCall",
            "abi": fmt_abi(ir_decl),
            "effects": "[]" if cls in ("PureMath",) else "TODO",
            "taint": "passthrough" if cls in ("PureMath", "VectorOps") else "TODO",
            "units": "passthrough",
            "proof_obligation": "none" if cls in ("PureMath",) else "TODO",
            "stability": stability,
            "since": "0.1.0",
            "notes": "; ".join(notes_bits),
        })

    rows.sort(key=lambda r: (r["class"], r["name"]))

    # ---- Build REVIEW REQUIRED list ----
    review = [r for r in rows if "REVIEW REQUIRED" in r["notes"]]

    # ---- Emit ----
    out_lines = []
    out_lines.append("# helper_manifest.toml")
    out_lines.append("#")
    out_lines.append("# Source-of-truth schema map for every helper in the Nucleor_OSS")
    out_lines.append("# project. Generated by tools/gen_helper_manifest.py from the")
    out_lines.append("# canonical compiler ABI tables and runtime C source. Do not edit")
    out_lines.append("# by hand — re-run the generator after adding any helper.")
    out_lines.append("#")
    out_lines.append("# Schema: see docs/rfcs/helper_manifest_schema.md")
    out_lines.append("# Contract: see docs/rfcs/HELPER-CONTRACT.md")
    out_lines.append(f"# Total helpers: {len(rows)}")
    out_lines.append(f"# Of which REVIEW REQUIRED: {len(review)}")
    out_lines.append("")

    # ---- REVIEW REQUIRED block ----
    out_lines.append("# ============================================================")
    out_lines.append("# REVIEW REQUIRED")
    out_lines.append("# ============================================================")
    out_lines.append("# These helpers need a human pass before their rows below can be")
    out_lines.append("# considered authoritative. Two reasons trigger inclusion:")
    out_lines.append("#  1. Declared in IR but no __nucleor_* definition found in the")
    out_lines.append("#     runtime (latent linker gap from earlier eras OR the symbol")
    out_lines.append("#     is generated by a runtime macro the regex didn't match).")
    out_lines.append("#  2. Name pattern didn't match any class rule (Unclassified).")
    out_lines.append("# Each row is still emitted below with `stability = \"experimental\"`")
    out_lines.append("# or `class = \"Unclassified\"` so callers can find them.")
    out_lines.append("#")
    for r in review:
        bits = []
        if r["class"] == "Unclassified":
            bits.append("Unclassified")
        if r["stability"] == "experimental":
            bits.append("undefined")
        flag = ", ".join(bits)
        out_lines.append(f"#   {r['name']:<40s} ({flag})")
    out_lines.append("")

    # ---- Helper rows ----
    last_class = None
    for r in rows:
        if r["class"] != last_class:
            out_lines.append("")
            out_lines.append(f"# ----- class: {r['class']} -----")
            out_lines.append("")
            last_class = r["class"]

        out_lines.append("[[helper]]")
        out_lines.append(f'name             = "{r["name"]}"')
        out_lines.append(f'class            = "{r["class"]}"')
        out_lines.append(f'symbol           = "{r["symbol"]}"')
        out_lines.append(f'dispatch         = "{r["dispatch"]}"')
        out_lines.append(f'abi              = "{r["abi"]}"')
        if r["effects"] == "[]":
            out_lines.append('effects          = []')
        else:
            out_lines.append(f'effects          = "{r["effects"]}"  # TODO')
        if r["taint"] == "TODO":
            out_lines.append(f'taint            = "{r["taint"]}"  # verify before use')
        else:
            out_lines.append(f'taint            = "{r["taint"]}"')
        out_lines.append(f'units            = "{r["units"]}"')
        if r["proof_obligation"] == "TODO":
            out_lines.append(f'proof_obligation = "{r["proof_obligation"]}"  # verify before use')
        else:
            out_lines.append(f'proof_obligation = "{r["proof_obligation"]}"')
        out_lines.append(f'stability        = "{r["stability"]}"')
        out_lines.append(f'since            = "{r["since"]}"')
        if r["notes"]:
            out_lines.append(f'notes            = "{r["notes"]}"')
        else:
            out_lines.append('notes            = ""')
        out_lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out_lines), encoding="utf-8")

    print(f"Wrote {OUT}")
    print(f"Total helpers: {len(rows)}")
    print(f"REVIEW REQUIRED: {len(review)}")
    klass_counts = {}
    for r in rows:
        klass_counts[r["class"]] = klass_counts.get(r["class"], 0) + 1
    for k, v in sorted(klass_counts.items(), key=lambda kv: -kv[1]):
        print(f"  {k:<20s} {v}")


if __name__ == "__main__":
    main()
