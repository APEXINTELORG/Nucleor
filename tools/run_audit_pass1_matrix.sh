#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PS_SCRIPT="$ROOT/tools/run_audit_pass1_matrix.ps1"

ARGS=()
for arg in "$@"; do
    case "$arg" in
        --list-only)
            ARGS+=("-ListOnly")
            ;;
        --closed-only)
            ARGS+=("-ClosedOnly")
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "${ARGS[@]}"
fi

if command -v powershell.exe >/dev/null 2>&1; then
    if command -v wslpath >/dev/null 2>&1; then
        PS_SCRIPT_WIN="$(wslpath -w "$PS_SCRIPT")"
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN" "${ARGS[@]}"
    fi
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "${ARGS[@]}"
fi

echo "run_audit_pass1_matrix: requires pwsh or powershell.exe" >&2
exit 127
