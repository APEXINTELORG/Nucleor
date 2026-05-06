#!/usr/bin/env bash
set -u

usage() {
    cat <<'EOF'
usage: tools/check_rust_bridge_ownership.sh [options]

Standalone POSIX rust_bridge string ownership harness. This is opt-in tooling;
it is not wired into verify.sh or perf gates.

Options:
  --doctor                 Print readiness checks, then exit
  --iterations N           Number of fixture process runs (default: 100)
  --fixture SELECTOR       string-free, hash, all, string-free-repeat, or a fixture path
  --json                   Emit machine-readable JSON instead of text
  --out-name NAME          Output basename under target/ (default: _rust_bridge_ownership_check)
  --build-timeout-sec N    Build timeout when timeout(1) is available (default: 180)
  --run-timeout-sec N      Per-run timeout when timeout(1) is available (default: 30)
  -h, --help               Show this help

Exit codes:
  0   ownership fixture completed
  1   build or fixture run failed
  2   usage error
  96  missing POSIX prerequisites
EOF
}

usage_error() {
    echo "ERROR rust_bridge ownership: $*" >&2
    usage >&2
    exit 2
}

json_escape() {
    local s="${1-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

json_bool() {
    if [ "$1" -eq 0 ]; then
        printf 'true'
    else
        printf 'false'
    fi
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
iterations=100
fixture_selector="string-free"
out_name="_rust_bridge_ownership_check"
build_timeout_sec=180
run_timeout_sec=30
doctor=0
json=0
completed_executions=0
failure_reason=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --doctor)
            doctor=1
            shift
            ;;
        --iterations)
            [ "$#" -ge 2 ] || usage_error "--iterations needs a value"
            iterations="$2"
            shift 2
            ;;
        --fixture)
            [ "$#" -ge 2 ] || usage_error "--fixture needs a value"
            fixture_selector="$2"
            shift 2
            ;;
        --json)
            json=1
            shift
            ;;
        --out-name)
            [ "$#" -ge 2 ] || usage_error "--out-name needs a value"
            out_name="$2"
            shift 2
            ;;
        --build-timeout-sec)
            [ "$#" -ge 2 ] || usage_error "--build-timeout-sec needs a value"
            build_timeout_sec="$2"
            shift 2
            ;;
        --run-timeout-sec)
            [ "$#" -ge 2 ] || usage_error "--run-timeout-sec needs a value"
            run_timeout_sec="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage_error "unknown option: $1"
            ;;
    esac
done

case "$iterations" in ''|*[!0-9]*) usage_error "--iterations must be a positive integer" ;; esac
[ "$iterations" -gt 0 ] || usage_error "--iterations must be > 0"
case "$build_timeout_sec" in ''|*[!0-9]*) usage_error "--build-timeout-sec must be a positive integer" ;; esac
[ "$build_timeout_sec" -gt 0 ] || usage_error "--build-timeout-sec must be > 0"
case "$run_timeout_sec" in ''|*[!0-9]*) usage_error "--run-timeout-sec must be a positive integer" ;; esac
[ "$run_timeout_sec" -gt 0 ] || usage_error "--run-timeout-sec must be > 0"

bridge_crate="$root/stdlib/rods/rust_bridge"
bridge_cargo="$bridge_crate/Cargo.toml"
bridge_src="$bridge_crate/src/lib.rs"
bridge_artifact="$bridge_crate/target/release/libnucleor_rust_bridge.a"
windows_bridge_artifact="$bridge_crate/target/release/nucleor_rust_bridge.lib"
compiler="$root/bin/nucleor"
windows_compiler="$root/bin/nucleor.exe"
target_dir="$root/target"

fixture_keys=()
fixture_args=()
fixture_paths=()
fixture_cycles=()
readiness_failed=0
cargo=""
cargo_native=1
compiler_present=1
bridge_artifact_present=1

fixture_cycle_count() {
    case "$1" in
        *rust_bridge_string_free_repeat_smoke.nr) printf '700' ;;
        *rust_bridge_hash_determinism_smoke.nr) printf '2' ;;
        *) printf '100' ;;
    esac
}

add_fixture() {
    local key="$1"
    local arg="$2"
    local cycles="$3"
    local path
    case "$arg" in
        /*) path="$arg" ;;
        *) path="$root/$arg" ;;
    esac
    fixture_keys+=("$key")
    fixture_args+=("$arg")
    fixture_paths+=("$path")
    fixture_cycles+=("$cycles")
}

resolve_fixtures() {
    case "$fixture_selector" in
        string-free)
            add_fixture "string-free" "tests/features/rust_bridge_string_free_smoke.nr" 100
            ;;
        string-free-repeat|repeat)
            add_fixture "string-free-repeat" "tests/features/rust_bridge_string_free_repeat_smoke.nr" 700
            ;;
        hash)
            add_fixture "hash" "tests/features/rust_bridge_hash_determinism_smoke.nr" 2
            ;;
        all)
            add_fixture "string-free" "tests/features/rust_bridge_string_free_smoke.nr" 100
            add_fixture "hash" "tests/features/rust_bridge_hash_determinism_smoke.nr" 2
            ;;
        *)
            add_fixture "custom" "$fixture_selector" "$(fixture_cycle_count "$fixture_selector")"
            ;;
    esac
}

command_path() {
    command -v "$1" 2>/dev/null || true
}

is_exe_path() {
    case "$1" in
        *.exe|*.EXE) return 0 ;;
        *) return 1 ;;
    esac
}

cargo_path() {
    local c
    c="$(command_path cargo)"
    if [ -n "$c" ]; then
        printf '%s\n' "$c"
        return 0
    fi
    command_path cargo.exe
}

run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
    else
        "$@"
    fi
}

first_output_exe() {
    if [ -x "$target_dir/${out_name}" ]; then
        printf '%s\n' "$target_dir/${out_name}"
    elif [ -x "$target_dir/${out_name}.exe" ]; then
        printf '%s\n' "$target_dir/${out_name}.exe"
    else
        printf '\n'
    fi
}

set_failure_reason() {
    if [ -z "$failure_reason" ]; then
        failure_reason="$1"
    fi
}

doctor_ok() {
    if [ "$json" -eq 0 ]; then
        echo "doctor $1: OK - $2"
    fi
}

doctor_bad() {
    if [ "$json" -eq 0 ]; then
        echo "doctor $1: FAIL - $2"
    fi
    readiness_failed=1
    set_failure_reason "$2"
}

check_readiness() {
    readiness_failed=0
    failure_reason=""
    cargo="$(cargo_path)"
    cargo_native=1
    compiler_present=1
    bridge_artifact_present=1

    if [ -n "$cargo" ] && ! is_exe_path "$cargo"; then
        cargo_native=0
        doctor_ok "cargo" "$cargo"
    elif [ -n "$cargo" ]; then
        doctor_bad "cargo" "found Windows cargo, not native POSIX cargo: $cargo"
    else
        doctor_bad "cargo" "missing from PATH"
    fi

    if [ -f "$bridge_cargo" ] && [ -f "$bridge_src" ]; then
        doctor_ok "bridge-crate" "$bridge_crate"
    else
        doctor_bad "bridge-crate" "missing Cargo.toml or src/lib.rs under $bridge_crate"
    fi

    if [ -f "$bridge_artifact" ]; then
        bridge_artifact_present=0
        doctor_ok "release-artifact" "$bridge_artifact"
    elif [ -n "$cargo" ] && ! is_exe_path "$cargo" && [ -f "$bridge_cargo" ]; then
        doctor_ok "release-artifact" "not present yet; normal run will attempt cargo build --release; expected $bridge_artifact"
    elif [ -f "$windows_bridge_artifact" ]; then
        doctor_bad "release-artifact" "POSIX artifact missing; Windows artifact is not accepted: $windows_bridge_artifact"
    else
        doctor_bad "release-artifact" "missing and cannot be built; expected $bridge_artifact"
    fi

    if [ -x "$compiler" ]; then
        compiler_present=0
        doctor_ok "compiler-binary" "$compiler"
    elif [ -f "$windows_compiler" ]; then
        doctor_bad "compiler-binary" "native POSIX compiler missing; Windows .exe is not accepted: $windows_compiler"
    else
        doctor_bad "compiler-binary" "missing $compiler"
    fi

    local i key path
    for i in "${!fixture_keys[@]}"; do
        key="${fixture_keys[$i]}"
        path="${fixture_paths[$i]}"
        if [ -f "$path" ]; then
            doctor_ok "focused-fixture:$key" "$path"
        else
            doctor_bad "focused-fixture:$key" "missing $path"
        fi
    done

    if [ "$readiness_failed" -eq 0 ]; then
        doctor_ok "fixture-buildable" "prerequisites are sufficient to build selector $fixture_selector"
    else
        doctor_bad "fixture-buildable" "missing native POSIX cargo, compiler, bridge crate/artifact, or fixture"
    fi
}

emit_json() {
    local status="$1"
    local reason="$2"
    local completed="$3"
    local artifact_path="$4"
    local artifact_present=1
    [ -f "$artifact_path" ] && artifact_present=0

    printf '{\n'
    printf '  "schema_version": 1,\n'
    printf '  "host_family": "posix",\n'
    if [ "$doctor" -eq 1 ]; then
        printf '  "mode": "doctor",\n'
    else
        printf '  "mode": "run",\n'
    fi
    printf '  "fixture_selector": "%s",\n' "$(json_escape "$fixture_selector")"
    printf '  "iterations_requested": %s,\n' "$iterations"
    printf '  "fixture_executions_completed": %s,\n' "$completed"
    printf '  "cargo": {"present": '
    if [ -n "$cargo" ]; then printf 'true'; else printf 'false'; fi
    printf ', "native": '
    json_bool "$cargo_native"
    printf ', "path": "%s"},\n' "$(json_escape "$cargo")"
    printf '  "bridge_artifact": {"present": '
    json_bool "$artifact_present"
    printf ', "path": "%s"},\n' "$(json_escape "$bridge_artifact")"
    printf '  "compiler": {"present": '
    json_bool "$compiler_present"
    printf ', "path": "%s"},\n' "$(json_escape "$compiler")"
    printf '  "result_status": "%s",\n' "$(json_escape "$status")"
    printf '  "failure_reason": "%s",\n' "$(json_escape "$reason")"
    printf '  "fixtures": [\n'
    local i comma present
    for i in "${!fixture_keys[@]}"; do
        comma=","
        [ "$i" -eq "$((${#fixture_keys[@]} - 1))" ] && comma=""
        present=1
        [ -f "${fixture_paths[$i]}" ] && present=0
        printf '    {"key": "%s", "path": "%s", "present": ' "$(json_escape "${fixture_keys[$i]}")" "$(json_escape "${fixture_paths[$i]}")"
        json_bool "$present"
        printf ', "rust_owned_free_cycles_per_execution": %s}%s\n' "${fixture_cycles[$i]}" "$comma"
    done
    printf '  ]\n'
    printf '}\n'
}

fail() {
    if [ "$json" -eq 1 ]; then
        emit_json "failed" "$*" "$completed_executions" "$bridge_artifact"
    else
        echo "ERROR rust_bridge ownership: $*" >&2
    fi
    exit 1
}

unsupported() {
    if [ "$json" -eq 1 ]; then
        emit_json "unsupported" "$*" "$completed_executions" "$bridge_artifact"
    else
        echo "UNSUPPORTED rust_bridge ownership: $*" >&2
    fi
    exit 96
}

resolve_fixtures

if [ "$doctor" -eq 1 ]; then
    check_readiness
    if [ "$json" -eq 1 ]; then
        if [ "$readiness_failed" -eq 0 ]; then
            emit_json "ready" "" 0 "$bridge_artifact"
            exit 0
        fi
        emit_json "unsupported" "$failure_reason" 0 "$bridge_artifact"
        exit 96
    fi
    if [ "$readiness_failed" -eq 0 ]; then
        echo "doctor result: ready for POSIX rust_bridge ownership harness"
        exit 0
    fi
    echo "doctor result: not ready for POSIX rust_bridge ownership harness"
    exit 96
fi

check_readiness >/dev/null
[ "$readiness_failed" -eq 0 ] || unsupported "$failure_reason"

if [ ! -f "$bridge_artifact" ]; then
    [ "$json" -eq 1 ] || echo "rust_bridge POSIX artifact missing; running cargo build --release"
    (
        cd "$bridge_crate" || exit 1
        run_with_timeout "$build_timeout_sec" "$cargo" build --release
    ) || fail "cargo build --release failed"
    [ -f "$bridge_artifact" ] || fail "cargo build --release completed but no POSIX bridge artifact was found: $bridge_artifact"
fi

mkdir -p "$target_dir" || fail "cannot create target directory: $target_dir"
total_cycles=0
last_exe=""

for idx in "${!fixture_keys[@]}"; do
    fixture_arg="${fixture_args[$idx]}"
    cycles="${fixture_cycles[$idx]}"
    rm -f "$target_dir/$out_name" "$target_dir/$out_name.exe"

    [ "$json" -eq 1 ] || echo "building focused fixture: $fixture_arg"
    (
        cd "$root" || exit 1
        run_with_timeout "$build_timeout_sec" "$compiler" build "$fixture_arg" -o "$out_name" --no-cache
    ) || fail "fixture build failed: $fixture_arg"

    exe="$(first_output_exe)"
    [ -n "$exe" ] || fail "fixture build reported success but executable was not found under target for output $out_name"
    last_exe="$exe"

    i=1
    while [ "$i" -le "$iterations" ]; do
        (
            cd "$root" || exit 1
            run_with_timeout "$run_timeout_sec" "$exe"
        ) || fail "ownership fixture ${fixture_keys[$idx]} iteration $i/$iterations failed"
        completed_executions=$((completed_executions + 1))
        i=$((i + 1))
    done
    total_cycles=$((total_cycles + iterations * cycles))
done

if [ "$json" -eq 1 ]; then
    emit_json "passed" "" "$completed_executions" "$bridge_artifact"
    exit 0
fi

echo "OK rust_bridge ownership: fixture_selector=$fixture_selector iterations=$iterations fixture_executions=$completed_executions fixture_alloc_free_cycles=$total_cycles bridge_artifact=$bridge_artifact executable=$last_exe"
exit 0
