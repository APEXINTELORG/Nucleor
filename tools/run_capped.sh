#!/usr/bin/env bash
set -u

usage() {
    cat <<'EOF'
usage: tools/run_capped.sh --budget-mb N [--warning-mb N] [--sample-ms N] [--timeout-sec N] [--label NAME] -- command [args...]

Runs a command under a Linux /proc process-tree RSS e-stop.

Exit codes:
  96  unsupported host or missing containment primitive
  98  timeout, process group killed
  99  RSS e-stop crossed, process group killed
  else command exit code
EOF
}

unsupported() {
    echo "UNSUPPORTED: $*" >&2
    exit 96
}

budget_mb=1024
warning_mb=0
sample_ms=100
timeout_sec=0
label=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --budget-mb)
            [ "$#" -ge 2 ] || { echo "ERROR: --budget-mb needs a value" >&2; exit 2; }
            budget_mb="$2"
            shift 2
            ;;
        --warning-mb)
            [ "$#" -ge 2 ] || { echo "ERROR: --warning-mb needs a value" >&2; exit 2; }
            warning_mb="$2"
            shift 2
            ;;
        --sample-ms)
            [ "$#" -ge 2 ] || { echo "ERROR: --sample-ms needs a value" >&2; exit 2; }
            sample_ms="$2"
            shift 2
            ;;
        --timeout-sec)
            [ "$#" -ge 2 ] || { echo "ERROR: --timeout-sec needs a value" >&2; exit 2; }
            timeout_sec="$2"
            shift 2
            ;;
        --label)
            [ "$#" -ge 2 ] || { echo "ERROR: --label needs a value" >&2; exit 2; }
            label="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ "$#" -gt 0 ] || { echo "ERROR: missing command after --" >&2; usage >&2; exit 2; }
[ -d /proc ] || unsupported "Linux /proc is required for real RSS sampling"
[ "$(uname -s 2>/dev/null)" = "Linux" ] || unsupported "real POSIX RSS e-stop is implemented only for Linux /proc hosts"
command -v setsid >/dev/null 2>&1 || unsupported "setsid is required to contain and kill the process group"

is_wsl() {
    grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease /proc/version 2>/dev/null
}

case "$budget_mb" in *[!0-9]*|"") echo "ERROR: --budget-mb must be an integer MB value" >&2; exit 2 ;; esac
case "$warning_mb" in *[!0-9]*|"") echo "ERROR: --warning-mb must be an integer MB value" >&2; exit 2 ;; esac
case "$sample_ms" in *[!0-9]*|"") echo "ERROR: --sample-ms must be an integer millisecond value" >&2; exit 2 ;; esac
case "$timeout_sec" in *[!0-9]*|"") echo "ERROR: --timeout-sec must be an integer second value" >&2; exit 2 ;; esac
[ "$sample_ms" -gt 0 ] || { echo "ERROR: --sample-ms must be > 0" >&2; exit 2; }

if [ -z "$label" ]; then
    label="$1"
fi

case "$1" in
    *.exe|*.EXE)
        if is_wsl; then
            unsupported "WSL cannot measure Windows .exe RSS through Linux /proc; use the PowerShell sampler or a native Linux compiler binary"
        fi
        ;;
esac

sleep_s="$(awk -v ms="$sample_ms" 'BEGIN { printf "%.3f", ms / 1000.0 }')"
start_s="$(date +%s)"
peak_kb=0
peak_count=0
warned=0
killed=0

proc_state() {
    local pid="$1"
    local stat rest
    stat="$(cat "/proc/$pid/stat" 2>/dev/null)" || return 1
    rest="${stat#*) }"
    set -- $rest
    [ "$#" -ge 1 ] || return 1
    printf '%s\n' "$1"
}

proc_running() {
    local state
    state="$(proc_state "$1")" || return 1
    [ "$state" != "Z" ]
}

collect_tree_childrenfs() {
    local root="$1"
    local pids="$root"
    local queue="$root"
    local parent child children child_file

    while [ -n "$queue" ]; do
        set -- $queue
        parent="$1"
        shift || true
        queue="$*"

        for child_file in /proc/"$parent"/task/*/children; do
            [ -r "$child_file" ] || continue
            children="$(cat "$child_file" 2>/dev/null || true)"
            for child in $children; do
                case " $pids " in
                    *" $child "*) ;;
                    *)
                        pids="$pids $child"
                        queue="${queue:+$queue }$child"
                        ;;
                esac
            done
        done
    done

    printf '%s\n' $pids
}

collect_tree_procscan() {
    local root="$1"
    local pids="$root"
    local changed=1
    local stat_path stat rest pid ppid

    while [ "$changed" -eq 1 ]; do
        changed=0
        for stat_path in /proc/[0-9]*/stat; do
            [ -r "$stat_path" ] || continue
            pid="${stat_path#/proc/}"
            pid="${pid%/stat}"
            case " $pids " in *" $pid "*) continue ;; esac
            stat="$(cat "$stat_path" 2>/dev/null)" || continue
            rest="${stat#*) }"
            set -- $rest
            [ "$#" -ge 2 ] || continue
            ppid="$2"
            case " $pids " in
                *" $ppid "*)
                    pids="$pids $pid"
                    changed=1
                    ;;
            esac
        done
    done

    printf '%s\n' $pids
}

collect_tree() {
    local root="$1"
    local children_file="/proc/$root/task/$root/children"
    if [ -r "$children_file" ]; then
        collect_tree_childrenfs "$root"
    else
        collect_tree_procscan "$root"
    fi
}

rss_kb_for_pid() {
    local pid="$1"
    awk '/^VmRSS:/ { print $2; found=1; exit } END { if (!found) print 0 }' "/proc/$pid/status" 2>/dev/null || echo 0
}

sample_tree() {
    local root="$1"
    local total=0
    local count=0
    local pid rss
    for pid in $(collect_tree "$root"); do
        [ -r "/proc/$pid/status" ] || continue
        rss="$(rss_kb_for_pid "$pid")"
        case "$rss" in *[!0-9]*|"") rss=0 ;; esac
        total=$((total + rss))
        count=$((count + 1))
    done
    printf '%s %s\n' "$total" "$count"
}

kill_group() {
    local pgid="$1"
    kill -TERM "-$pgid" 2>/dev/null || true
    sleep 0.2
    kill -KILL "-$pgid" 2>/dev/null || true
}

setsid "$@" &
child=$!
pgid=$child

echo "RSS-CAP start: ${label}: budget=${budget_mb} MB warning=${warning_mb} MB sample=${sample_ms} ms pid=${child}"

while proc_running "$child"; do
    sample="$(sample_tree "$child")"
    set -- $sample
    cur_kb="$1"
    cur_count="$2"

    if [ "$cur_kb" -gt "$peak_kb" ]; then
        peak_kb="$cur_kb"
        peak_count="$cur_count"
    fi

    cur_mb=$(((cur_kb + 1023) / 1024))
    if [ "$warning_mb" -gt 0 ] && [ "$warned" -eq 0 ] && [ "$cur_mb" -gt "$warning_mb" ]; then
        echo "RSS-CAP warn: ${label}: ${cur_mb} MB crossed warning ${warning_mb} MB"
        warned=1
    fi

    if [ "$cur_mb" -gt "$budget_mb" ]; then
        echo "RSS-CAP e-stop: ${label}: ${cur_mb} MB crossed budget ${budget_mb} MB; killing process group ${pgid}" >&2
        killed=1
        kill_group "$pgid"
        wait "$child" 2>/dev/null || true
        peak_mb=$(((peak_kb + 1023) / 1024))
        echo "RSS-CAP summary: ${label}: KILLED peak=${peak_mb} MB / ${budget_mb} MB pids=${peak_count}"
        exit 99
    fi

    if [ "$timeout_sec" -gt 0 ]; then
        now_s="$(date +%s)"
        if [ $((now_s - start_s)) -gt "$timeout_sec" ]; then
            echo "RSS-CAP timeout: ${label}: exceeded ${timeout_sec}s; killing process group ${pgid}" >&2
            killed=1
            kill_group "$pgid"
            wait "$child" 2>/dev/null || true
            peak_mb=$(((peak_kb + 1023) / 1024))
            echo "RSS-CAP summary: ${label}: TIMEOUT peak=${peak_mb} MB / ${budget_mb} MB pids=${peak_count}"
            exit 98
        fi
    fi

    sleep "$sleep_s"
done

wait "$child"
rc=$?

sample="$(sample_tree "$child" 2>/dev/null || echo "0 0")"
set -- $sample
cur_kb="$1"
cur_count="$2"
if [ "$cur_kb" -gt "$peak_kb" ]; then
    peak_kb="$cur_kb"
    peak_count="$cur_count"
fi

peak_mb=$(((peak_kb + 1023) / 1024))
if [ "$killed" -eq 0 ]; then
    echo "RSS-CAP summary: ${label}: exit=${rc} peak=${peak_mb} MB / ${budget_mb} MB pids=${peak_count}"
fi

exit "$rc"
