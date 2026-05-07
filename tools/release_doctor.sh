#!/usr/bin/env bash
# release_doctor.sh — probe Linux/POSIX prerequisites for the Nucleor
# release/publish flow before kicking off a real run.
#
# Pure shell; no Python helpers. Mirrors the doctor-line convention used
# by tools/check_perf_regression.sh --doctor so output is greppable.
#
# Probes:
#   - native Linux host (uname -s = Linux, not WSL)
#   - clang        — needed by tools/bootstrap_linux.sh and the native
#                    code emitter
#   - cargo / rustc — needed by the Rust bridge crates and the
#                    rustc-bridge ownership checker
#   - pwsh         — required by tools/native_release.ps1 (release
#                    keygen / sign / verify pipeline; PowerShell-hosted)
#   - ssh-keygen   — required for `ssh-keygen -Y sign / verify` Ed25519
#                    release-signing operations
#   - bin/nucleor  — must exist as a native Linux ELF binary
#   - bin/nucleor_tools — must exist as a native Linux ELF binary
#                        (built from compiler/nucleor_tools_suite.nr)
#
# Exit codes (matching tools/check_perf_regression.sh):
#   0   all required probes pass
#   2   usage error
#   96  one or more required probes failed (host unsupported)

set -uo pipefail

usage() {
    cat <<'EOF'
usage: tools/release_doctor.sh [options]

Linux release-prerequisite doctor for Nucleor. Reports presence and
version of pwsh, ssh-keygen, clang, cargo, bin/nucleor, and
bin/nucleor_tools so a fresh runner can see what is missing before
attempting a full release / publish flow.

Options:
  --json        Emit machine-readable JSON instead of human lines.
  --quiet       Print only the final summary line.
  -h, --help    Show this help and exit.

Exit codes:
  0   all required probes passed
  2   usage error
  96  one or more required probes failed; not ready for release
EOF
}

usage_error() {
    echo "ERROR release-doctor: $*" >&2
    usage >&2
    exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"

emit_json=0
quiet=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) emit_json=1; shift ;;
        --quiet) quiet=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage_error "unknown option: $1" ;;
    esac
done

is_wsl() {
    grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease /proc/version 2>/dev/null
}

# --- Reporting helpers ---------------------------------------------------

# Probe records: we accumulate name|status|detail rows and emit them at
# the end. Status is one of OK / FAIL / SKIP. Required probes whose
# status != OK flip the overall doctor result to unsupported (exit 96).

records=""

# Required probes: missing => exit 96. Optional probes: missing only logs
# a SKIP / FAIL but does not fail the overall doctor (none right now;
# everything in scope for 8B is required for the release flow).
required="native-linux clang cargo pwsh ssh-keygen bin-nucleor bin-nucleor-tools"

record() {
    # name|status|detail — pipe is the field separator.
    records="${records}${records:+$'\n'}$1|$2|$3"
}

is_required() {
    case " $required " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

human_line() {
    # Format: doctor <name>: <status> - <detail>
    local name="$1" status="$2" detail="$3"
    printf 'doctor %s: %s - %s\n' "$name" "$status" "$detail"
}

json_escape() {
    # Minimal JSON escaper for the fields we emit.
    printf '%s' "$1" | awk '
        BEGIN { ORS="" }
        {
            s = $0
            gsub(/\\/, "\\\\", s)
            gsub(/"/, "\\\"", s)
            gsub(/\t/, "\\t", s)
            gsub(/\r/, "\\r", s)
            print s
            if (NR != 0) print "\\n"
        }
    ' | sed 's/\\n$//'
}

# --- Probes --------------------------------------------------------------

probe_native_linux() {
    local uname_s osrelease detail
    uname_s="$(uname -s 2>/dev/null || echo unknown)"
    osrelease="$(cat /proc/sys/kernel/osrelease 2>/dev/null || true)"
    detail="kernel=$uname_s${osrelease:+ osrelease=$osrelease}"
    if [ "$uname_s" = "Linux" ] && ! is_wsl; then
        record "native-linux" "OK" "$detail"
    elif [ "$uname_s" = "Linux" ] && is_wsl; then
        record "native-linux" "FAIL" "WSL is not native Linux for release evidence ($detail)"
    else
        record "native-linux" "FAIL" "requires Linux, saw $uname_s"
    fi
}

probe_command_with_version() {
    # $1 = probe name, $2 = command, $3 = version invocation suffix
    local name="$1" cmd="$2" version_args="$3" path ver
    path="$(command -v "$cmd" 2>/dev/null || true)"
    if [ -z "$path" ]; then
        record "$name" "FAIL" "missing from PATH; install $cmd"
        return
    fi
    ver=""
    if [ -n "$version_args" ]; then
        # shellcheck disable=SC2086
        ver="$("$cmd" $version_args 2>&1 | head -n 1 | tr -d '\r' || true)"
    fi
    record "$name" "OK" "$path${ver:+ — $ver}"
}

probe_clang() {
    probe_command_with_version "clang" "clang" "--version"
}

probe_cargo() {
    probe_command_with_version "cargo" "cargo" "--version"
}

probe_pwsh() {
    # pwsh is the PowerShell 7 launcher. Windows PowerShell (powershell.exe)
    # is irrelevant on a native Linux runner — release pipeline expects pwsh.
    probe_command_with_version "pwsh" "pwsh" "--version"
}

probe_ssh_keygen() {
    # ssh-keygen prints its banner on stderr, not stdout.
    local path ver
    path="$(command -v ssh-keygen 2>/dev/null || true)"
    if [ -z "$path" ]; then
        record "ssh-keygen" "FAIL" "missing from PATH; install openssh-client (ed25519 release signing relies on ssh-keygen -Y sign/verify)"
        return
    fi
    ver="$(ssh-keygen -V 2>&1 | head -n 1 | tr -d '\r' || true)"
    if [ -z "$ver" ]; then
        ver="$(ssh-keygen -h 2>&1 | head -n 1 | tr -d '\r' || true)"
    fi
    record "ssh-keygen" "OK" "$path${ver:+ — $ver}"
}

probe_native_binary() {
    local name="$1" relpath="$2" hint="$3" path bin_kind
    path="$root/$relpath"
    case "$relpath" in
        *.exe|*.EXE)
            record "$name" "FAIL" "Windows .exe is not POSIX evidence: $relpath"
            return
            ;;
    esac
    if [ ! -e "$path" ]; then
        record "$name" "FAIL" "missing: $relpath ($hint)"
        return
    fi
    if [ ! -x "$path" ]; then
        record "$name" "FAIL" "not executable: $relpath"
        return
    fi
    if command -v file >/dev/null 2>&1; then
        bin_kind="$(file "$path" 2>/dev/null || true)"
        case "$bin_kind" in
            *ELF*) record "$name" "OK" "$relpath ($bin_kind)" ;;
            *PE32*|*MS-DOS*) record "$name" "FAIL" "not native Linux ELF: $bin_kind" ;;
            *) record "$name" "FAIL" "cannot prove native Linux ELF: ${bin_kind:-<no output>}" ;;
        esac
    else
        record "$name" "OK" "$relpath (file(1) unavailable; ELF check skipped)"
    fi
}

probe_bin_nucleor() {
    probe_native_binary "bin-nucleor" "bin/nucleor" "run bash tools/bootstrap_linux.sh first"
}

probe_bin_nucleor_tools() {
    probe_native_binary "bin-nucleor-tools" "bin/nucleor_tools" "build via ./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools and copy target/nucleor_tools to bin/"
}

# Run probes in declared order.
probe_native_linux
probe_clang
probe_cargo
probe_pwsh
probe_ssh_keygen
probe_bin_nucleor
probe_bin_nucleor_tools

# --- Aggregate + emit ----------------------------------------------------

required_fail=0
total_fail=0

# Iterate records to emit human lines and tally failures.
while IFS= read -r row; do
    [ -n "$row" ] || continue
    name="${row%%|*}"
    rest="${row#*|}"
    status="${rest%%|*}"
    detail="${rest#*|}"
    if [ "$emit_json" -ne 1 ] && [ "$quiet" -ne 1 ]; then
        human_line "$name" "$status" "$detail"
    fi
    if [ "$status" != "OK" ]; then
        total_fail=$((total_fail + 1))
        if is_required "$name"; then
            required_fail=$((required_fail + 1))
        fi
    fi
done <<EOF
$records
EOF

if [ "$emit_json" -eq 1 ]; then
    printf '{"probes":['
    first=1
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        name="${row%%|*}"
        rest="${row#*|}"
        status="${rest%%|*}"
        detail="${rest#*|}"
        if [ "$first" -eq 1 ]; then
            first=0
        else
            printf ','
        fi
        is_required "$name" && req=true || req=false
        printf '{"name":"%s","status":"%s","required":%s,"detail":"%s"}' \
            "$(json_escape "$name")" \
            "$(json_escape "$status")" \
            "$req" \
            "$(json_escape "$detail")"
    done <<EOF
$records
EOF
    if [ "$required_fail" -eq 0 ]; then
        printf '],"result":"ready","required_failures":0}\n'
    else
        printf '],"result":"unsupported","required_failures":%d}\n' "$required_fail"
    fi
fi

if [ "$required_fail" -eq 0 ]; then
    if [ "$emit_json" -ne 1 ]; then
        echo "doctor result: ready for native Linux release / publish flow"
    fi
    exit 0
fi

if [ "$emit_json" -ne 1 ]; then
    echo "doctor result: unsupported for native Linux release / publish flow ($required_fail required probe(s) failed)"
fi
exit 96
