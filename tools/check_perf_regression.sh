#!/usr/bin/env bash
set -u

usage() {
    cat <<'EOF'
usage: tools/check_perf_regression.sh [options]

POSIX/Linux cold + hot self-build perf check. Requires a native Linux
bin/nucleor, Linux /proc, and tools/run_capped.sh for process-tree RSS.

Options:
  --baseline PATH       Baseline JSON path (default: tools/perf_baseline.json)
  --bin PATH            Native POSIX compiler binary (default: bin/nucleor)
  --src PATH            Source to self-build (default: compiler/nucleor_s1_compiler.nr)
  --cold-samples N      Cold samples to run (default: 3)
  --hot-samples N       Hot samples to run (default: 3)
  --budget-mb N         RSS e-stop budget passed to run_capped.sh (default: 1000)
  --warning-mb N        RSS warning threshold passed to run_capped.sh (default: 800)
  --timeout-sec N       Per-sample timeout passed to run_capped.sh (default: 180)
  --sample-ms N         RSS sample interval passed to run_capped.sh (default: 100)
  --doctor              Print native POSIX perf readiness checks, then exit
  --quiet               Print only failures and final summary
  --verbose             Print one line per sample plus final summary
  -h, --help            Show this help

Exit codes:
  0   within thresholds
  1   regression or invalid measurement
  2   usage error
  96  unsupported host for POSIX perf evidence
EOF
}

die() {
    echo "ERROR POSIX perf: $*" >&2
    exit 1
}

usage_error() {
    echo "ERROR POSIX perf: $*" >&2
    usage >&2
    exit 2
}

unsupported() {
    echo "UNSUPPORTED POSIX perf: $*" >&2
    exit 96
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"

is_wsl() {
    grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease /proc/version 2>/dev/null
}

# Pick the platform-default baseline when --baseline is not supplied.
# True Linux (non-WSL) prefers tools/perf_baseline_linux.json when present;
# otherwise we fall back to the legacy tools/perf_baseline.json (Windows).
default_baseline_for_host() {
    local uname_s
    uname_s="$(uname -s 2>/dev/null || echo unknown)"
    if [ "$uname_s" = "Linux" ] && ! is_wsl && [ -f "$root/tools/perf_baseline_linux.json" ]; then
        printf '%s\n' "$root/tools/perf_baseline_linux.json"
    else
        printf '%s\n' "$root/tools/perf_baseline.json"
    fi
}

# baseline left empty as a sentinel so platform-aware default selection
# below can distinguish "user did not pass --baseline" from "user picked
# the Windows baseline explicitly". A user-supplied --baseline always wins.
baseline=""
bin="$root/bin/nucleor"
src="$root/compiler/nucleor_s1_compiler.nr"
cold_samples=3
hot_samples=3
budget_mb=1000
warning_mb=800
timeout_sec=180
sample_ms=100
quiet=1
doctor=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --baseline)
            [ "$#" -ge 2 ] || usage_error "--baseline needs a path"
            baseline="$2"
            shift 2
            ;;
        --bin)
            [ "$#" -ge 2 ] || usage_error "--bin needs a path"
            bin="$2"
            shift 2
            ;;
        --src)
            [ "$#" -ge 2 ] || usage_error "--src needs a path"
            src="$2"
            shift 2
            ;;
        --cold-samples)
            [ "$#" -ge 2 ] || usage_error "--cold-samples needs a value"
            cold_samples="$2"
            shift 2
            ;;
        --hot-samples)
            [ "$#" -ge 2 ] || usage_error "--hot-samples needs a value"
            hot_samples="$2"
            shift 2
            ;;
        --budget-mb)
            [ "$#" -ge 2 ] || usage_error "--budget-mb needs a value"
            budget_mb="$2"
            shift 2
            ;;
        --warning-mb)
            [ "$#" -ge 2 ] || usage_error "--warning-mb needs a value"
            warning_mb="$2"
            shift 2
            ;;
        --timeout-sec)
            [ "$#" -ge 2 ] || usage_error "--timeout-sec needs a value"
            timeout_sec="$2"
            shift 2
            ;;
        --sample-ms)
            [ "$#" -ge 2 ] || usage_error "--sample-ms needs a value"
            sample_ms="$2"
            shift 2
            ;;
        --doctor)
            doctor=1
            shift
            ;;
        --quiet)
            quiet=1
            shift
            ;;
        --verbose)
            quiet=0
            shift
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

require_uint() {
    local name="$1"
    local value="$2"
    case "$value" in
        ''|*[!0-9]*) usage_error "$name must be an integer" ;;
    esac
    [ "$value" -gt 0 ] || usage_error "$name must be > 0"
}

require_uint "--cold-samples" "$cold_samples"
require_uint "--hot-samples" "$hot_samples"
require_uint "--budget-mb" "$budget_mb"
require_uint "--warning-mb" "$warning_mb"
require_uint "--timeout-sec" "$timeout_sec"
require_uint "--sample-ms" "$sample_ms"

[ "$warning_mb" -lt "$budget_mb" ] || warning_mb=$((budget_mb - 1))

if [ -z "$baseline" ]; then
    baseline="$(default_baseline_for_host)"
fi

run_capped="$root/tools/run_capped.sh"

doctor_fail=0

doctor_ok() {
    echo "doctor $1: OK - $2"
}

doctor_bad() {
    echo "doctor $1: FAIL - $2"
    doctor_fail=1
}

doctor_skip() {
    echo "doctor $1: SKIP - $2"
}

run_doctor() {
    local uname_s
    local osrelease
    local missing
    local tool
    local baseline_src_missing
    local bin_kind

    uname_s="$(uname -s 2>/dev/null || echo unknown)"
    osrelease="$(cat /proc/sys/kernel/osrelease 2>/dev/null || true)"

    if [ "$uname_s" = "Linux" ] && ! is_wsl; then
        doctor_ok "native-linux" "kernel=$uname_s${osrelease:+ osrelease=$osrelease}"
    elif [ "$uname_s" = "Linux" ] && is_wsl; then
        doctor_bad "native-linux" "WSL kernel is shell-check only for this gate${osrelease:+ osrelease=$osrelease}"
    else
        doctor_bad "native-linux" "requires Linux, saw $uname_s"
    fi

    if [ -d /proc ]; then
        doctor_ok "linux-proc" "/proc is present"
    else
        doctor_bad "linux-proc" "/proc is missing"
    fi

    missing=""
    for tool in awk grep sed sort date mktemp rm tail bash setsid; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing="${missing}${missing:+, }$tool"
        fi
    done
    if [ -z "$missing" ]; then
        doctor_ok "required-shell-tools" "awk grep sed sort date mktemp rm tail bash setsid"
    else
        doctor_bad "required-shell-tools" "missing: $missing"
    fi

    if command -v clang >/dev/null 2>&1; then
        doctor_ok "clang" "$(command -v clang)"
    else
        doctor_bad "clang" "missing from PATH"
    fi

    if [ -f "$run_capped" ]; then
        doctor_ok "run-capped" "$run_capped"
    else
        doctor_bad "run-capped" "missing: $run_capped"
    fi

    baseline_src_missing=""
    [ -f "$baseline" ] || baseline_src_missing="${baseline_src_missing}${baseline_src_missing:+, }baseline missing: $baseline"
    [ -f "$src" ] || baseline_src_missing="${baseline_src_missing}${baseline_src_missing:+, }source missing: $src"
    if [ -z "$baseline_src_missing" ]; then
        case "$baseline" in
            */perf_baseline_linux.json) doctor_ok "baseline-and-source" "baseline=$baseline (linux platform default) source=$src" ;;
            */perf_baseline.json) doctor_ok "baseline-and-source" "baseline=$baseline (windows/legacy default) source=$src" ;;
            *) doctor_ok "baseline-and-source" "baseline=$baseline source=$src" ;;
        esac
    else
        doctor_bad "baseline-and-source" "$baseline_src_missing"
    fi

    case "$bin" in
        *.exe|*.EXE)
            doctor_bad "native-executable" "Windows .exe is not POSIX evidence: $bin"
            ;;
        *)
            if [ -x "$bin" ]; then
                doctor_ok "native-executable" "$bin"
            elif [ -f "$root/bin/nucleor.exe" ]; then
                doctor_bad "native-executable" "native $bin is missing or not executable; bin/nucleor.exe is Windows-only"
            else
                doctor_bad "native-executable" "missing or not executable: $bin"
            fi
            ;;
    esac

    if command -v file >/dev/null 2>&1; then
        if [ -f "$bin" ]; then
            bin_kind="$(file "$bin" 2>/dev/null || true)"
            case "$bin_kind" in
                *ELF*) doctor_ok "elf-proof" "$bin_kind" ;;
                *PE32*|*MS-DOS*) doctor_bad "elf-proof" "not native Linux ELF: $bin_kind" ;;
                *) doctor_bad "elf-proof" "cannot prove native Linux ELF: ${bin_kind:-<no output>}" ;;
            esac
        else
            doctor_bad "elf-proof" "cannot inspect missing binary: $bin"
        fi
    else
        doctor_skip "elf-proof" "file command is unavailable"
    fi

    if [ "$doctor_fail" -eq 0 ]; then
        echo "doctor result: ready for native POSIX perf evidence"
        exit 0
    fi

    echo "doctor result: unsupported for native POSIX perf evidence"
    exit 96
}

if [ "$doctor" -eq 1 ]; then
    run_doctor
fi

[ -f "$baseline" ] || die "baseline missing: $baseline"
[ -f "$src" ] || die "source missing: $src"

[ -d /proc ] || unsupported "Linux /proc is required for valid POSIX RSS evidence"
[ "$(uname -s 2>/dev/null)" = "Linux" ] || unsupported "requires a native Linux host, not $(uname -s 2>/dev/null || echo unknown)"

if is_wsl; then
    unsupported "WSL is shell-check only for this gate; use a native Linux runner for R10-D3 perf/RSS evidence"
fi

for tool in awk grep sed sort date mktemp rm tail bash setsid clang; do
    command -v "$tool" >/dev/null 2>&1 || unsupported "missing required tool: $tool"
done

[ -f "$run_capped" ] || die "missing tools/run_capped.sh"

case "$bin" in
    *.exe|*.EXE)
        unsupported "Windows .exe cannot be used as POSIX RSS evidence; run bash tools/bootstrap_linux.sh to produce native bin/nucleor"
        ;;
esac

if [ ! -x "$bin" ]; then
    if [ -f "$root/bin/nucleor.exe" ]; then
        unsupported "native bin/nucleor is missing; bin/nucleor.exe is Windows-only, so run bash tools/bootstrap_linux.sh on a native Linux runner first"
    fi
    unsupported "native bin/nucleor is missing or not executable; run bash tools/bootstrap_linux.sh first"
fi

if command -v file >/dev/null 2>&1; then
    bin_kind="$(file "$bin" 2>/dev/null || true)"
    case "$bin_kind" in
        *PE32*|*MS-DOS*) unsupported "compiler binary is not native POSIX: $bin_kind" ;;
        *ELF*) ;;
        *) unsupported "cannot prove compiler binary is native Linux ELF: $bin_kind" ;;
    esac
fi

json_number() {
    local key="$1"
    awk -v key="$key" '
        index($0, "\"" key "\"") {
            line = $0
            sub(/^[^:]*:/, "", line)
            gsub(/[", ]/, "", line)
            sub(/,$/, "", line)
            if (line ~ /^[-+]?[0-9]+([.][0-9]+)?$/) {
                print line
                exit
            }
        }
    ' "$baseline"
}

require_json_number() {
    local key="$1"
    local value
    value="$(json_number "$key")"
    [ -n "$value" ] || die "baseline missing numeric field: $key"
    printf '%s\n' "$value"
}

cold_max="$(require_json_number cold_max_allowed_seconds)"
hot_max="$(require_json_number hot_max_allowed_seconds)"
cold_process_tree_max="$(require_json_number cold_max_allowed_memory_mb)"
hot_process_tree_max="$(require_json_number hot_max_allowed_memory_mb)"
cold_baseline="$(json_number cold_self_build_seconds)"
hot_baseline="$(json_number hot_self_build_seconds)"
cold_process_tree_baseline="$(json_number cold_process_tree_peak_memory_mb)"
hot_process_tree_baseline="$(json_number hot_process_tree_peak_memory_mb)"
[ -n "$cold_baseline" ] || cold_baseline="$cold_max"
[ -n "$hot_baseline" ] || hot_baseline="$hot_max"
[ -n "$cold_process_tree_baseline" ] || cold_process_tree_baseline="$cold_process_tree_max"
[ -n "$hot_process_tree_baseline" ] || hot_process_tree_baseline="$hot_process_tree_max"

now_ms() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        echo "${EPOCHREALTIME//./}" | cut -c1-13
    else
        local ms
        ms="$(date +%s%3N 2>/dev/null)"
        case "$ms" in
            *%3N*) echo "$(($(date +%s) * 1000))" ;;
            *) echo "$ms" ;;
        esac
    fi
}

median_file() {
    sort -n "$1" | awk '
        { vals[NR] = $1 }
        END {
            if (NR == 0) {
                print "0.00"
            } else if (NR % 2 == 1) {
                printf "%.2f\n", vals[(NR + 1) / 2]
            } else {
                printf "%.2f\n", (vals[NR / 2] + vals[(NR / 2) + 1]) / 2.0
            }
        }
    '
}

float_le() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit(a <= b ? 0 : 1) }'
}

ratio() {
    awk -v a="$1" -v b="$2" 'BEGIN { if (b == 0) printf "n/a"; else printf "%.1f", a / b }'
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nuc_posix_perf.XXXXXX")" || die "mktemp failed"
trap 'rm -rf "$tmpdir"' EXIT
cold_times="$tmpdir/cold_times.txt"
hot_times="$tmpdir/hot_times.txt"
: > "$cold_times"
: > "$hot_times"
cold_process_tree_mb=0
hot_process_tree_mb=0

run_sample() {
    local phase="$1"
    local sample="$2"
    local expected_cache="$3"
    local out="$tmpdir/${phase}_${sample}.log"
    local start end rc wall cache_line peak

    if [ "$phase" = "cold" ]; then
        rm -rf "$root/.nuc_cache" "$root/target" 2>/dev/null || true
    fi

    start="$(now_ms)"
    (
        cd "$root" || exit 1
        bash "$run_capped" \
            --budget-mb "$budget_mb" \
            --warning-mb "$warning_mb" \
            --sample-ms "$sample_ms" \
            --timeout-sec "$timeout_sec" \
            --label "posix-${phase}-${sample}" \
            -- "$bin" build "$src" -o nuc_perf_check
    ) >"$out" 2>&1
    rc=$?
    end="$(now_ms)"
    wall="$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.3f", (e - s) / 1000.0 }')"

    if [ "$rc" -eq 96 ]; then
        tail -n 20 "$out" >&2
        unsupported "tools/run_capped.sh reported unsupported host while measuring ${phase} sample ${sample}"
    fi
    if [ "$rc" -ne 0 ]; then
        echo "FAIL POSIX perf: ${phase} sample ${sample} exited ${rc}" >&2
        tail -n 30 "$out" >&2
        exit 1
    fi

    cache_line="$(grep '^cache:' "$out" | tail -n 1 || true)"
    case "$cache_line" in
        "cache: ${expected_cache}"*) ;;
        *)
            echo "FAIL POSIX perf: ${phase} sample ${sample} expected cache: ${expected_cache}, saw: ${cache_line:-<none>}" >&2
            tail -n 30 "$out" >&2
            exit 1
            ;;
    esac

    peak="$(sed -n 's/.*RSS-CAP summary: .* peak=\([0-9][0-9]*\) MB.*/\1/p' "$out" | tail -n 1)"
    case "$peak" in
        ''|*[!0-9]*)
            echo "FAIL POSIX perf: ${phase} sample ${sample} did not emit parseable RSS-CAP summary" >&2
            tail -n 30 "$out" >&2
            exit 1
            ;;
    esac

    if [ "$phase" = "cold" ]; then
        printf '%s\n' "$wall" >> "$cold_times"
        [ "$peak" -le "$cold_process_tree_mb" ] || cold_process_tree_mb="$peak"
    else
        printf '%s\n' "$wall" >> "$hot_times"
        [ "$peak" -le "$hot_process_tree_mb" ] || hot_process_tree_mb="$peak"
    fi

    if [ "$quiet" -ne 1 ]; then
        echo "sample ${phase} ${sample}: ${wall}s, process_tree=${peak}MB, ${cache_line}"
    fi
}

sample=1
while [ "$sample" -le "$cold_samples" ]; do
    run_sample cold "$sample" miss
    sample=$((sample + 1))
done

sample=1
while [ "$sample" -le "$hot_samples" ]; do
    run_sample hot "$sample" hit
    sample=$((sample + 1))
done

cold="$(median_file "$cold_times")"
hot="$(median_file "$hot_times")"

cold_ok=1
hot_ok=1
cold_mem_ok=1
hot_mem_ok=1
float_le "$cold" "$cold_max" || cold_ok=0
float_le "$hot" "$hot_max" || hot_ok=0
[ "$cold_process_tree_mb" -le "$cold_process_tree_max" ] || cold_mem_ok=0
[ "$hot_process_tree_mb" -le "$hot_process_tree_max" ] || hot_mem_ok=0

if [ "$cold_ok" -eq 1 ] && [ "$hot_ok" -eq 1 ] && [ "$cold_mem_ok" -eq 1 ] && [ "$hot_mem_ok" -eq 1 ]; then
    echo "OK POSIX perf: cold=${cold}s (max ${cold_max}s) | hot=${hot}s (max ${hot_max}s) | mem cold_tree=${cold_process_tree_mb}/${cold_process_tree_max}MB cold_compiler=n/a hot_tree=${hot_process_tree_mb}/${hot_process_tree_max}MB hot_compiler=n/a"
    echo "  note: POSIX gate enforces Linux process-tree RSS via tools/run_capped.sh; compiler-only RSS split remains Windows-only in this prep branch."
    exit 0
fi

echo ""
echo "POSIX PERF REGRESSION DETECTED"
if [ "$cold_ok" -ne 1 ]; then
    echo "  COLD self-build: ${cold}s vs baseline ${cold_baseline}s ($(ratio "$cold" "$cold_baseline")x, max ${cold_max}s)"
fi
if [ "$hot_ok" -ne 1 ]; then
    echo "  HOT self-build: ${hot}s vs baseline ${hot_baseline}s ($(ratio "$hot" "$hot_baseline")x, max ${hot_max}s)"
fi
if [ "$cold_mem_ok" -ne 1 ]; then
    echo "  COLD PROCESS-TREE MEMORY: ${cold_process_tree_mb}MB vs baseline ${cold_process_tree_baseline}MB ($(ratio "$cold_process_tree_mb" "$cold_process_tree_baseline")x, max ${cold_process_tree_max}MB)"
fi
if [ "$hot_mem_ok" -ne 1 ]; then
    echo "  HOT PROCESS-TREE MEMORY: ${hot_process_tree_mb}MB vs baseline ${hot_process_tree_baseline}MB ($(ratio "$hot_process_tree_mb" "$hot_process_tree_baseline")x, max ${hot_process_tree_max}MB)"
fi
echo "  compiler-only RSS: n/a on POSIX prep gate; process-tree RSS is enforced."
exit 1
