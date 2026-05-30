#!/usr/bin/env bash
set -u

usage() {
    cat <<'EOF'
usage: tools/check_rust_bridge_ownership.sh [options]

Standalone POSIX rust_bridge string ownership harness. This is opt-in tooling;
it is not wired into verify.sh or perf gates.

Options:
  --doctor                 Print readiness checks, then exit
  --self-test              Validate selector, JSON, and fail-closed contracts
  --iterations N           Number of fixture process runs (default: 100)
  --fixture SELECTOR       string-free, hash, all, string-free-repeat, or a fixture path
  --json                   Emit machine-readable JSON instead of text
  --simulate-missing KIND  Test-only override: cargo, compiler, bridge-artifact, or none
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
self_test=0
json=0
completed_executions=0
failure_reason=""
simulate_missing="none"
resolve_error=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --doctor)
            doctor=1
            shift
            ;;
        --self-test)
            self_test=1
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
        --simulate-missing)
            [ "$#" -ge 2 ] || usage_error "--simulate-missing needs a value"
            simulate_missing="$2"
            shift 2
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
case "$simulate_missing" in
    none|cargo|compiler|bridge-artifact) ;;
    *) usage_error "--simulate-missing must be cargo, compiler, bridge-artifact, or none" ;;
esac

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
self_test_checks=()
readiness_failed=0
cargo=""
cargo_native=1
compiler_present=1
bridge_artifact_present=1
bridge_crate_present=1
can_build_artifact=1
can_build_fixture=1

fixture_cycle_count() {
    case "$1" in
        *rust_bridge_string_free_repeat_smoke.nr) printf '700' ;;
        *rust_bridge_hash_determinism_smoke.nr) printf '2' ;;
        *) printf '100' ;;
    esac
}

reset_fixtures() {
    fixture_keys=()
    fixture_args=()
    fixture_paths=()
    fixture_cycles=()
    resolve_error=""
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

is_explicit_fixture_path() {
    case "$1" in
        */*|*\\*|*.nr) return 0 ;;
        *) return 1 ;;
    esac
}

resolve_fixtures() {
    local selector="$1"
    reset_fixtures
    case "$selector" in
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
            if is_explicit_fixture_path "$selector"; then
                add_fixture "custom" "$selector" "$(fixture_cycle_count "$selector")"
            else
                resolve_error="invalid fixture selector '$selector'; expected string-free, hash, all, string-free-repeat, or an explicit .nr fixture path"
                return 2
            fi
            ;;
    esac
    return 0
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
    [ "$simulate_missing" = "cargo" ] && return 0
    if [ "$simulate_missing" != "none" ]; then
        printf '%s\n' "/simulated/native/cargo"
        return 0
    fi
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

    # POSIX-only harness. The rust_bridge ownership fixture links the
    # static POSIX archive (libnucleor_rust_bridge.a); a Windows toolchain
    # produces the MSVC import lib (nucleor_rust_bridge.lib) instead, which
    # this harness deliberately does not accept. On a Windows host, mark
    # readiness as unmet so the caller SKIPs (exit 96) rather than building
    # the .lib and then failing on the absent .a. The simulate-missing
    # test path bypasses this so the self-test still exercises the logic.
    if [ "$simulate_missing" = "none" ]; then
        case "$(uname -s 2>/dev/null || echo unknown)" in
            MINGW*|MSYS*|CYGWIN*|Windows*)
                readiness_failed=1
                failure_reason="POSIX-only harness: Windows host produces the MSVC .lib, not the POSIX .a (run on Linux/macOS or under WSL)"
                doctor_bad "host-family" "$failure_reason"
                return
                ;;
        esac
    fi

    cargo="$(cargo_path)"
    cargo_native=1
    compiler_present=1
    bridge_artifact_present=1
    bridge_crate_present=1
    can_build_artifact=1
    can_build_fixture=1

    if [ -n "$cargo" ] && ! is_exe_path "$cargo"; then
        cargo_native=0
        doctor_ok "cargo" "$cargo"
    elif [ -n "$cargo" ]; then
        doctor_bad "cargo" "found Windows cargo, not native POSIX cargo: $cargo"
    elif [ "$simulate_missing" = "cargo" ]; then
        doctor_bad "cargo" "simulated missing cargo"
    else
        doctor_bad "cargo" "missing from PATH"
    fi

    if [ -f "$bridge_cargo" ] && [ -f "$bridge_src" ]; then
        bridge_crate_present=0
        doctor_ok "bridge-crate" "$bridge_crate"
    else
        doctor_bad "bridge-crate" "missing Cargo.toml or src/lib.rs under $bridge_crate"
    fi

    if [ "$simulate_missing" = "bridge-artifact" ]; then
        doctor_bad "release-artifact" "simulated missing bridge artifact"
    elif [ "$simulate_missing" != "none" ]; then
        bridge_artifact_present=0
        doctor_ok "release-artifact" "simulated present bridge artifact: $bridge_artifact"
    elif [ -f "$bridge_artifact" ]; then
        bridge_artifact_present=0
        doctor_ok "release-artifact" "$bridge_artifact"
    elif [ -n "$cargo" ] && ! is_exe_path "$cargo" && [ -f "$bridge_cargo" ]; then
        can_build_artifact=0
        doctor_ok "release-artifact" "not present yet; normal run will attempt cargo build --release; expected $bridge_artifact"
    elif [ -f "$windows_bridge_artifact" ]; then
        doctor_bad "release-artifact" "POSIX artifact missing; Windows artifact is not accepted: $windows_bridge_artifact"
    else
        doctor_bad "release-artifact" "missing and cannot be built; expected $bridge_artifact"
    fi

    if [ "$simulate_missing" = "compiler" ]; then
        doctor_bad "compiler-binary" "simulated missing compiler"
    elif [ "$simulate_missing" != "none" ]; then
        compiler_present=0
        doctor_ok "compiler-binary" "simulated present compiler: $compiler"
    elif [ -x "$compiler" ]; then
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
        can_build_fixture=0
        doctor_ok "fixture-buildable" "prerequisites are sufficient to build selector $fixture_selector"
    else
        doctor_bad "fixture-buildable" "$(readiness_failure_reason)"
    fi
}

readiness_failure_reason() {
    if [ -n "$failure_reason" ]; then
        printf '%s' "$failure_reason"
    else
        printf 'missing native POSIX cargo, compiler, bridge crate/artifact, or fixture'
    fi
}

preflight_exit_code() {
    if [ "$can_build_fixture" -eq 0 ]; then
        printf '0'
    else
        printf '96'
    fi
}

emit_json() {
    local status="$1"
    local reason="$2"
    local completed="$3"
    local artifact_path="$4"
    local artifact_present=1
    [ -f "$artifact_path" ] && [ "$simulate_missing" != "bridge-artifact" ] && artifact_present=0
    [ "$simulate_missing" != "none" ] && [ "$simulate_missing" != "bridge-artifact" ] && artifact_present=0

    local mode="run"
    [ "$doctor" -eq 1 ] && mode="doctor"
    [ "$self_test" -eq 1 ] && mode="self-test"

    printf '{\n'
    printf '  "schema_version": 1,\n'
    printf '  "host_family": "posix",\n'
    printf '  "mode": "%s",\n' "$mode"
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
    printf '  "simulated_missing": "%s",\n' "$(json_escape "$simulate_missing")"
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
    printf '  ],\n'
    printf '  "self_test_checks": ['
    for i in "${!self_test_checks[@]}"; do
        [ "$i" -gt 0 ] && printf ', '
        printf '"%s"' "$(json_escape "${self_test_checks[$i]}")"
    done
    printf ']\n'
    printf '}\n'
}

json_has_required_keys() {
    local text="$1"
    local key
    for key in schema_version host_family mode fixture_selector iterations_requested fixture_executions_completed cargo bridge_artifact compiler result_status failure_reason fixtures; do
        case "$text" in
            *"\"$key\""*) ;;
            *) return 1 ;;
        esac
    done
    return 0
}

self_check() {
    local name="$1"
    local ok="$2"
    local reason="$3"
    if [ "$ok" -ne 0 ]; then
        failure_reason="self-test $name: $reason"
        return 1
    fi
    self_test_checks+=("$name")
    [ "$json" -eq 1 ] || echo "self-test $name: OK"
    return 0
}

run_self_test() {
    local old_simulate="$simulate_missing"
    local selector json_text preflight reason parsed_ok

    for selector in string-free hash all; do
        if resolve_fixtures "$selector"; then
            [ "${#fixture_keys[@]}" -ge 1 ]
            self_check "selector:$selector" "$?" "selector did not resolve" || return 1
        else
            self_check "selector:$selector" 1 "$resolve_error" || return 1
        fi
    done

    if resolve_fixtures "__invalid_selector__"; then
        self_check "selector:invalid" 1 "invalid selector resolved successfully" || return 1
    else
        case "$resolve_error" in
            invalid\ fixture\ selector*) self_check "selector:invalid" 0 "" || return 1 ;;
            *) self_check "selector:invalid" 1 "$resolve_error" || return 1 ;;
        esac
    fi

    simulate_missing="none"
    resolve_fixtures "all" || return 1
    check_readiness >/dev/null
    json_text="$(emit_json "passed" "" 0 "$bridge_artifact")"
    json_has_required_keys "$json_text"
    self_check "json:required-keys" "$?" "JSON output missing required keys" || return 1

    for selector in cargo compiler bridge-artifact; do
        simulate_missing="$selector"
        resolve_fixtures "string-free" || return 1
        check_readiness >/dev/null
        preflight="$(preflight_exit_code)"
        reason="$(readiness_failure_reason)"
        if [ "$preflight" -ne 0 ] && [ -n "$reason" ]; then parsed_ok=0; else parsed_ok=1; fi
        self_check "fail-closed:$selector" "$parsed_ok" "missing prerequisite did not produce nonzero preflight and reason" || return 1

        json_text="$(emit_json "unsupported" "$reason" 0 "$bridge_artifact")"
        case "$json_text" in
            *'"result_status": "unsupported"'*'"failure_reason": "'*) parsed_ok=0 ;;
            *) parsed_ok=1 ;;
        esac
        json_has_required_keys "$json_text" || parsed_ok=1
        self_check "json:fail-closed:$selector" "$parsed_ok" "fail-closed JSON missing status or reason" || return 1
    done

    simulate_missing="$old_simulate"
    resolve_fixtures "$fixture_selector" || return 1
    check_readiness >/dev/null
    if [ "$json" -eq 1 ]; then
        emit_json "passed" "" 0 "$bridge_artifact"
    else
        echo "self-test result: passed"
    fi
    return 0
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

if [ "$self_test" -eq 1 ]; then
    if run_self_test; then
        exit 0
    fi
    if [ "$json" -eq 1 ]; then
        resolve_fixtures "$fixture_selector" >/dev/null 2>&1 || true
        check_readiness >/dev/null
        emit_json "failed" "$failure_reason" 0 "$bridge_artifact"
    else
        echo "self-test result: FAILED - $failure_reason" >&2
    fi
    exit 1
fi

if ! resolve_fixtures "$fixture_selector"; then
    if [ "$json" -eq 1 ]; then
        check_readiness >/dev/null
        emit_json "failed" "$resolve_error" 0 "$bridge_artifact"
    else
        echo "ERROR rust_bridge ownership: $resolve_error" >&2
    fi
    exit 2
fi

if [ "$doctor" -eq 1 ]; then
    check_readiness
    if [ "$json" -eq 1 ]; then
        if [ "$readiness_failed" -eq 0 ]; then
            emit_json "ready" "" 0 "$bridge_artifact"
            exit 0
        fi
        emit_json "unsupported" "$(readiness_failure_reason)" 0 "$bridge_artifact"
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
[ "$readiness_failed" -eq 0 ] || unsupported "$(readiness_failure_reason)"

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
