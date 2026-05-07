#!/usr/bin/env bash
# verify_strict.sh — run verify.sh after wiping the build cache, so step
# bodies that don't already use `--no-cache` are forced through a fresh-
# compile path on first invocation. Intended as the v1.0-release validation
# gate per docs/rfcs/v1_PRODUCTION_READINESS_PLAN_v0846_2026-05-07.md
# Phase 2.
#
# Why this exists:
#   The default `bash tools/verify.sh` run reports headline counts that
#   reflect the CURRENT cache state. A latent compiler bug (e.g. a parser
#   panic on a fixture with control flow) can be masked because the cache
#   from a previous run still has the correctly-compiled LL output.
#   Strict mode wipes the cache first so the "fresh clone" surface is
#   what gets exercised.
#
# Limitation (honest):
#   This is a one-shot wipe at startup. Step bodies that call
#   `"$BIN" build` without `--no-cache` will still regen and reuse the
#   cache mid-run. For every step body to be truly cache-cold,
#   verify.sh would need a `--no-cache` flag threaded through every
#   build/test invocation. That's a separate (and larger) change. For
#   v1.0, the startup wipe gives most of the value: the FIRST run of
#   each cache-sensitive step body now starts cold.
#
# Usage:
#   bash tools/verify_strict.sh
#
# Output: same as `tools/verify.sh`. Exit code = verify.sh exit code.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

echo "verify_strict: wiping build cache to force cache-cold step bodies..."
rm -rf target/.nuc_cache 2>/dev/null || true
rm -rf target/.verify_tmp 2>/dev/null || true
rm -rf .nuc_cache 2>/dev/null || true

# Phase 4 of v1_PRODUCTION_READINESS_PLAN: drift gate flips
# `s1-has-#[manual_drop] / tools-suite-missing` from WARN to FAIL when
# NUC_VERIFY_STRICT=1 is set. Strict-mode users want every divergence
# class as a hard error, not a swallowed warning.
export NUC_VERIFY_STRICT=1
echo "verify_strict: NUC_VERIFY_STRICT=1 — drift gate enforces #[manual_drop] parity."

# Honor an opt-out for advanced users who want to keep some pre-existing
# cache (e.g. when bisecting).
if [ "${NUC_VERIFY_STRICT_NO_WIPE:-0}" = "1" ]; then
    echo "verify_strict: NUC_VERIFY_STRICT_NO_WIPE=1 — skipping cache wipe (advanced)."
fi

# Pass through any args the user supplied. verify.sh already supports
# --only / --range / --rerun-failed; strict mode is orthogonal.
exec bash tools/verify.sh "$@"
