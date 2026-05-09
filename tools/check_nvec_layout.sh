#!/usr/bin/env bash
# check_nvec_layout.sh — Lane 2 audit fix A1 verifier (2026-05-08).
#
# Asserts that the NVec struct layout is single-sourced. Reviews
# every `_rt.c` / `_rt.cu` file under `stdlib/runtime/` and FAILS
# (non-zero exit) when:
#   1. A sister TU redeclares `typedef struct { long long *data;
#      int len; int cap; } NVec;` (the truncated 24-byte shape that
#      caused latent UB pre-fix).
#   2. The canonical `stdlib/runtime/nvec.h` is missing or its
#      payload is not the expected 32-byte layout.
#
# Per the audit, the canonical NVec layout is:
#     typedef struct {
#         long long *data;
#         int len;
#         int cap;
#         long long inline_data[2];
#     } NVec;
# 32 bytes, 16-byte aligned. Sister files MUST NOT redeclare this
# locally; they receive the type via the `-include nuc_alloc.h`
# clang flag (which itself includes nvec.h).
#
# Usage: bash tools/check_nvec_layout.sh
# Exit:  0 = PASS (no drift)
#        1 = FAIL (drift detected; details on stderr)
#
# Wired into tools/verify.sh post-promotion.

set -uo pipefail

REPO_ROOT="${1:-$(pwd)}"
RT_DIR="${REPO_ROOT}/stdlib/runtime"
HEADER="${RT_DIR}/nvec.h"

fail=0

# 1. Canonical header present and contains expected layout.
if [ ! -f "${HEADER}" ]; then
    echo "FAIL: canonical NVec header not found at ${HEADER}" 1>&2
    fail=1
fi

if [ -f "${HEADER}" ]; then
    # Required tokens (each is required to appear in the header).
    for token in "long long \*data;" "int len;" "int cap;" "long long inline_data\[2\];"; do
        if ! grep -q "${token}" "${HEADER}" 2>/dev/null; then
            echo "FAIL: nvec.h missing required token: ${token}" 1>&2
            fail=1
        fi
    done
fi

# 2. No sister file redeclares the truncated 24-byte NVec shape.
#    Pattern matches both function-local typedefs and file-scope ones.
SHADOW=$(grep -rn 'typedef struct { long long \*data; int len; int cap; } NVec;' "${RT_DIR}" 2>/dev/null | grep -v "/nvec\.h:" | grep -v "/nucleor_llvm_rt\.c:.*\* typedef" || true)
if [ -n "${SHADOW}" ]; then
    echo "FAIL: sister _rt.c file(s) redeclare the truncated 24-byte NVec layout:" 1>&2
    echo "${SHADOW}" 1>&2
    echo "" 1>&2
    echo "These local typedefs MUST be removed. The canonical 32-byte NVec is" 1>&2
    echo "force-included via stdlib/runtime/nvec.h (through nuc_alloc.h)." 1>&2
    fail=1
fi

# 3. Canonical TU has the static_assert sentinel.
CANONICAL_TU="${RT_DIR}/nucleor_llvm_rt.c"
if [ -f "${CANONICAL_TU}" ]; then
    if ! grep -q "_Static_assert(sizeof(NVec) == 32" "${CANONICAL_TU}" 2>/dev/null; then
        echo "FAIL: canonical TU ${CANONICAL_TU} missing _Static_assert(sizeof(NVec) == 32, ...)" 1>&2
        fail=1
    fi
fi

if [ "${fail}" -eq 0 ]; then
    echo "PASS: NVec layout single-sourced; no drift in stdlib/runtime/"
fi

exit "${fail}"
