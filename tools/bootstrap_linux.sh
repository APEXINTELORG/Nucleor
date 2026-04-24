#!/usr/bin/env bash
# bootstrap_linux.sh — produce bin/nucleor on Linux/macOS from the
# checked-in IR seed at bootstrap/nucleor_s1_seed.ll.
#
# This is the chicken-and-egg solver: the self-hosted compiler needs
# `bin/nucleor` to compile itself, but a fresh Linux box doesn't have
# one. The seed `.ll` (emitted by the Windows build, target-agnostic
# IR) plus the platform-portable C runtime is enough for clang to
# produce a working stage-1 binary that can then bootstrap itself.
#
# Pipeline:
#   1. Resolve clang on PATH (mirrors the nuc launcher resolution).
#   2. Stage-1 link: clang seed + runtime → bin/nucleor.
#   3. Stage-1 sanity: bin/nucleor --version reports a compiler version.
#   4. Stage-2 self-rebuild: bin/nucleor build compiler/nucleor_s1_compiler.nr
#      → target/nucleor_s2.ll.
#   5. Fixed-point check: stage-2 IR matches the seed byte-for-byte.
#   6. Promote stage-2: clang stage-2 IR + runtime → bin/nucleor.
#
# Steps 4–6 are skipped if --seed-only is passed (CI wants the
# stage-1 binary fast; verify.sh exercises the self-rebuild
# separately).
#
# Usage: ./tools/bootstrap_linux.sh [--seed-only]
# Exit:  0 = bin/nucleor in place; non-zero = bootstrap failed.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED="$ROOT/bootstrap/nucleor_s1_seed.ll"
RUNTIME="$ROOT/stdlib/runtime/nucleor_llvm_rt.c"
OUT="$ROOT/bin/nucleor"
SEED_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --seed-only) SEED_ONLY=1 ;;
        -h|--help)
            sed -n '2,28p' "$0"
            exit 0
            ;;
        *)
            echo "bootstrap_linux: unknown arg '$arg'" >&2
            exit 2
            ;;
    esac
done

# --- Preflight ---------------------------------------------------------
if [ ! -f "$SEED" ]; then
    echo "bootstrap_linux: missing IR seed at $SEED" >&2
    echo "                 see bootstrap/README.md for how to refresh it" >&2
    exit 1
fi
if [ ! -f "$RUNTIME" ]; then
    echo "bootstrap_linux: missing runtime at $RUNTIME" >&2
    exit 1
fi

# Resolve clang (mirrors ./nuc resolution).
if ! command -v clang >/dev/null 2>&1; then
    if [ -n "${NUCLEOR_CLANG_PATH:-}" ] && [ -x "$NUCLEOR_CLANG_PATH" ]; then
        export PATH="$(dirname "$NUCLEOR_CLANG_PATH"):$PATH"
    elif [ -n "${LLVM_SYS_180_PREFIX:-}" ] && [ -x "$LLVM_SYS_180_PREFIX/bin/clang" ]; then
        export PATH="$LLVM_SYS_180_PREFIX/bin:$PATH"
    elif [ -x "/usr/lib/llvm-18/bin/clang" ]; then
        export PATH="/usr/lib/llvm-18/bin:$PATH"
    elif [ -x "/usr/bin/clang-18" ]; then
        export PATH="/usr/bin:$PATH"
    elif [ -x "/usr/bin/clang" ]; then
        export PATH="/usr/bin:$PATH"
    elif [ -x "/opt/homebrew/opt/llvm@18/bin/clang" ]; then
        export PATH="/opt/homebrew/opt/llvm@18/bin:$PATH"
    elif [ -x "/usr/local/opt/llvm@18/bin/clang" ]; then
        export PATH="/usr/local/opt/llvm@18/bin:$PATH"
    fi
fi
if ! command -v clang >/dev/null 2>&1; then
    echo "bootstrap_linux: clang not found on PATH" >&2
    echo "                 install LLVM 18 (sudo apt install clang-18 / brew install llvm@18)" >&2
    exit 1
fi

cd "$ROOT"
mkdir -p bin target

# --- Stage 1: link the seed ------------------------------------------
echo "==> stage-1 link: clang $(realpath --relative-to=. "$SEED") + runtime → bin/nucleor"
clang "$SEED" "$RUNTIME" \
    -o "$OUT" \
    -Wno-override-module \
    -Wl,-z,stacksize=16777216 \
    -lm -lpthread \
    2>&1 | sed 's/^/    /'
if [ ! -x "$OUT" ]; then
    echo "bootstrap_linux: stage-1 link failed (no $OUT produced)" >&2
    exit 1
fi
echo "    stage-1 binary: $(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT") bytes"

# --- Stage 1 sanity check --------------------------------------------
ver_out="$("$OUT" --version 2>&1)"
ver_rc=$?
if [ "$ver_rc" -ne 0 ]; then
    echo "bootstrap_linux: stage-1 binary failed --version (rc=$ver_rc)" >&2
    echo "$ver_out" | sed 's/^/    /' >&2
    exit 1
fi
echo "    stage-1 --version: $(echo "$ver_out" | head -1)"

if [ "$SEED_ONLY" = "1" ]; then
    echo "==> --seed-only: stopping after stage-1 (verify.sh handles self-rebuild)"
    exit 0
fi

# --- Stage 2: self-rebuild --------------------------------------------
echo "==> stage-2 self-rebuild: bin/nucleor build compiler/nucleor_s1_compiler.nr"
"$OUT" build compiler/nucleor_s1_compiler.nr -o nucleor_s2 >/tmp/_nuc_bootstrap.log 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "bootstrap_linux: stage-2 self-rebuild failed (rc=$rc)" >&2
    sed 's/^/    /' /tmp/_nuc_bootstrap.log >&2
    exit 1
fi
if [ ! -f "target/nucleor_s2.ll" ]; then
    echo "bootstrap_linux: stage-2 IR not emitted (target/nucleor_s2.ll missing)" >&2
    exit 1
fi

# --- Fixed-point check ------------------------------------------------
echo "==> fixed-point check: target/nucleor_s2.ll vs bootstrap/nucleor_s1_seed.ll"
seed_sha="$(sha256sum "$SEED" | awk '{print $1}')"
s2_sha="$(sha256sum target/nucleor_s2.ll | awk '{print $1}')"
if [ "$seed_sha" != "$s2_sha" ]; then
    echo "bootstrap_linux: fixed-point check FAILED" >&2
    echo "    seed sha256:    $seed_sha" >&2
    echo "    stage-2 sha256: $s2_sha" >&2
    echo "    refresh the seed (bootstrap/README.md) and retry" >&2
    exit 1
fi
echo "    fixed point: sha256=$s2_sha"

# --- Promote stage-2 binary -------------------------------------------
# Stage-1 binary is already at $OUT (linked from the seed). Stage-2 IR
# matches the seed byte-for-byte, so re-linking is redundant — but we
# do it anyway as a safety check that the linker pipeline is still
# producing a valid binary (catches a corrupt clang install).
echo "==> stage-2 link (sanity): clang target/nucleor_s2.ll + runtime → bin/nucleor"
clang target/nucleor_s2.ll "$RUNTIME" \
    -o "$OUT" \
    -Wno-override-module \
    -Wl,-z,stacksize=16777216 \
    -lm -lpthread \
    2>&1 | sed 's/^/    /'
if [ ! -x "$OUT" ]; then
    echo "bootstrap_linux: stage-2 link failed" >&2
    exit 1
fi
echo "    stage-2 binary: $(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT") bytes"

echo "==> bootstrap complete: bin/nucleor ready"
echo "    next: ./tools/verify.sh"
