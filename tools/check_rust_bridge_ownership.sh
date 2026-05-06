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
  --fixture PATH           Focused fixture to build (default: tests/features/rust_bridge_string_free_smoke.nr)
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

fail() {
    echo "ERROR rust_bridge ownership: $*" >&2
    exit 1
}

unsupported() {
    echo "UNSUPPORTED rust_bridge ownership: $*" >&2
    exit 96
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
iterations=100
fixture_arg="tests/features/rust_bridge_string_free_smoke.nr"
out_name="_rust_bridge_ownership_check"
build_timeout_sec=180
run_timeout_sec=30
doctor=0

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
            [ "$#" -ge 2 ] || usage_error "--fixture needs a path"
            fixture_arg="$2"
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

bridge_crate="$root/stdlib/rods/rust_bridge"
bridge_cargo="$bridge_crate/Cargo.toml"
bridge_src="$bridge_crate/src/lib.rs"
bridge_artifact="$bridge_crate/target/release/libnucleor_rust_bridge.a"
windows_bridge_artifact="$bridge_crate/target/release/nucleor_rust_bridge.lib"
compiler="$root/bin/nucleor"
windows_compiler="$root/bin/nucleor.exe"
target_dir="$root/target"

case "$fixture_arg" in
    /*) fixture="$fixture_arg" ;;
    *) fixture="$root/$fixture_arg" ;;
esac
fixture_cycles=100
case "$fixture_arg" in
    *rust_bridge_string_free_repeat_smoke.nr) fixture_cycles=700 ;;
esac

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

doctor_failed=0

doctor_ok() {
    echo "doctor $1: OK - $2"
}

doctor_bad() {
    echo "doctor $1: FAIL - $2"
    doctor_failed=1
}

readiness() {
    local cargo
    cargo="$(cargo_path)"

    if [ -n "$cargo" ] && ! is_exe_path "$cargo"; then
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
        doctor_ok "release-artifact" "$bridge_artifact"
    elif [ -n "$cargo" ] && ! is_exe_path "$cargo" && [ -f "$bridge_cargo" ]; then
        doctor_ok "release-artifact" "not present yet; normal run will attempt cargo build --release; expected $bridge_artifact"
    elif [ -f "$windows_bridge_artifact" ]; then
        doctor_bad "release-artifact" "POSIX artifact missing; Windows artifact is not accepted: $windows_bridge_artifact"
    else
        doctor_bad "release-artifact" "missing and cannot be built; expected $bridge_artifact"
    fi

    if [ -x "$compiler" ]; then
        doctor_ok "compiler-binary" "$compiler"
    elif [ -f "$windows_compiler" ]; then
        doctor_bad "compiler-binary" "native POSIX compiler missing; Windows .exe is not accepted: $windows_compiler"
    else
        doctor_bad "compiler-binary" "missing $compiler"
    fi

    if [ -f "$fixture" ]; then
        doctor_ok "focused-fixture" "$fixture"
    else
        doctor_bad "focused-fixture" "missing $fixture"
    fi

    if [ "$doctor_failed" -eq 0 ]; then
        doctor_ok "fixture-buildable" "prerequisites are sufficient to build $fixture_arg"
    else
        doctor_bad "fixture-buildable" "missing native POSIX cargo, compiler, bridge crate/artifact, or fixture"
    fi
}

if [ "$doctor" -eq 1 ]; then
    readiness
    if [ "$doctor_failed" -eq 0 ]; then
        echo "doctor result: ready for POSIX rust_bridge ownership harness"
        exit 0
    fi
    echo "doctor result: not ready for POSIX rust_bridge ownership harness"
    exit 96
fi

cargo="$(cargo_path)"
[ -n "$cargo" ] || unsupported "cargo is missing from PATH"
is_exe_path "$cargo" && unsupported "found Windows cargo, not native POSIX cargo: $cargo"
[ -f "$bridge_cargo" ] && [ -f "$bridge_src" ] || unsupported "rust_bridge crate is missing Cargo.toml or src/lib.rs under $bridge_crate"
[ -f "$fixture" ] || unsupported "focused fixture missing: $fixture"
[ -x "$compiler" ] || unsupported "native POSIX compiler missing: $compiler"

if [ ! -f "$bridge_artifact" ]; then
    echo "rust_bridge POSIX artifact missing; running cargo build --release"
    (
        cd "$bridge_crate" || exit 1
        run_with_timeout "$build_timeout_sec" "$cargo" build --release
    ) || fail "cargo build --release failed"
    [ -f "$bridge_artifact" ] || fail "cargo build --release completed but no POSIX bridge artifact was found: $bridge_artifact"
fi

mkdir -p "$target_dir" || fail "cannot create target directory: $target_dir"
rm -f "$target_dir/$out_name" "$target_dir/$out_name.exe"

echo "building focused fixture: $fixture_arg"
(
    cd "$root" || exit 1
    run_with_timeout "$build_timeout_sec" "$compiler" build "$fixture_arg" -o "$out_name" --no-cache
) || fail "fixture build failed: $fixture_arg"

exe="$(first_output_exe)"
[ -n "$exe" ] || fail "fixture build reported success but executable was not found under target for output $out_name"

i=1
while [ "$i" -le "$iterations" ]; do
    (
        cd "$root" || exit 1
        run_with_timeout "$run_timeout_sec" "$exe"
    ) || fail "ownership fixture iteration $i/$iterations failed"
    i=$((i + 1))
done

echo "OK rust_bridge ownership: iterations=$iterations fixture_alloc_free_cycles=$((iterations * fixture_cycles)) bridge_artifact=$bridge_artifact executable=$exe"
exit 0
