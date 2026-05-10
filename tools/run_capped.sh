#!/usr/bin/env bash
set -u

usage() {
    cat <<'EOF'
usage: tools/run_capped.sh --budget-mb N [--warning-mb N] [--sample-ms N] [--timeout-sec N] [--label NAME] -- command [args...]

Runs a command under a Linux /proc process-tree RSS e-stop.

Sampler emits three peaks on the RSS-CAP summary line:
  peak=N MB       process-tree (the e-stop / safety view)
  compiler=N MB   sum across descendants whose /proc/<pid>/comm matches
                  the launched root pid's comm (compiler-only view)
  root=N MB       VmRSS of the launched root pid alone

This mirrors the schema produced by tools/rss_estop_lib.ps1 on Windows
(process_tree_peak_mb / compiler_peak_mb / root_peak_mb) so the perf gate
applies the same accounting on both hosts.

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

# Read /proc/<pid>/comm without forking cat. Mirrors the Windows
# rss_estop_lib.ps1 use of Process.ProcessName to identify "compiler-only"
# descendants among the launched process tree. /proc/<pid>/comm is the
# kernel-tracked task name (basename of argv[0] up to 15 chars) and
# survives exec(); it is the right Linux equivalent of ProcessName.
proc_comm() {
    local pid="$1"
    local comm=""
    if [ -r "/proc/$pid/comm" ]; then
        IFS= read -r comm < "/proc/$pid/comm" 2>/dev/null || comm=""
    fi
    printf '%s' "$comm"
}

# Derive the "compiler" comm name used to filter descendant RSS.
#
# Prefer the basename of the launched executable ($1) truncated to 15 chars,
# because the kernel sets /proc/<pid>/comm = basename(argv[0])[0:15] at exec()
# time. /proc/<pid>/comm read immediately after `setsid X &` would still
# report "setsid" until setsid has finished its exec, so polling the live PID
# would race against the spawn. Using the known argv[0] basename is
# deterministic and mirrors the Windows path (Process.ProcessName resolved
# from FileName before the child has any chance to spawn).
#
# /proc fallback is used only if the basename derivation yields an empty
# string (e.g. command supplied via $0 of a sourced script).
derive_compiler_comm() {
    local pid="$1"
    local cmd="$2"
    local comm
    comm="${cmd##*/}"
    # Strip a trailing .exe / .EXE so callers that invoke a Windows-named
    # binary on a Linux host (rare, but reachable through WSL until the
    # WSL-refusal gate fires) still get a stable comm match.
    case "$comm" in
        *.exe|*.EXE) comm="${comm%.*}" ;;
    esac
    # kernel truncates comm to TASK_COMM_LEN-1 = 15 chars
    comm="${comm:0:15}"
    if [ -n "$comm" ]; then
        printf '%s' "$comm"
        return 0
    fi
    printf '%s' "$(proc_comm "$pid")"
}

# Sample the launched process tree and return four numbers:
#   tree_total_kb   sum of VmRSS across every pid descended from $root (the
#                   safety / e-stop view; matches the prior process-tree-only
#                   contract this script shipped with)
#   compiler_kb     sum of VmRSS across only those pids whose /proc/<pid>/comm
#                   matches $compiler_comm (i.e. Nucleor compiler processes,
#                   excluding clang/lld/ld/Defender children)
#   root_kb         VmRSS of the launched root pid alone
#   count           number of pids observed in the tree
#
# Mirrors the schema produced by tools/rss_estop_lib.ps1
# (process_tree_peak_mb / compiler_peak_mb / root_peak_mb) so the cross-host
# perf gate can apply identical accounting on Linux and Windows.
sample_tree() {
    local root="$1"
    local compiler_comm="$2"
    local total=0
    local compiler=0
    local rootkb=0
    local count=0
    local pid rss comm
    for pid in $(collect_tree "$root"); do
        [ -r "/proc/$pid/status" ] || continue
        rss="$(rss_kb_for_pid "$pid")"
        case "$rss" in *[!0-9]*|"") rss=0 ;; esac
        total=$((total + rss))
        count=$((count + 1))
        if [ "$pid" = "$root" ]; then
            rootkb="$rss"
        fi
        if [ -n "$compiler_comm" ]; then
            comm="$(proc_comm "$pid")"
            if [ "$comm" = "$compiler_comm" ]; then
                compiler=$((compiler + rss))
            fi
        fi
    done
    printf '%s %s %s %s\n' "$total" "$compiler" "$rootkb" "$count"
}

kill_group() {
    local pgid="$1"
    kill -TERM "-$pgid" 2>/dev/null || true
    sleep 0.2
    kill -KILL "-$pgid" 2>/dev/null || true
}

peak_compiler_kb=0
peak_root_kb=0

setsid "$@" &
child=$!
pgid=$child

# Resolve the comm of the launched root process so sample_tree can sum
# RSS across "compiler-only" descendants (matching root comm) in
# parallel with the process-tree total. Done once at start; if /proc
# is racing the spawn we fall back to the truncated basename of argv[0].
compiler_comm="$(derive_compiler_comm "$child" "$1")"

echo "RSS-CAP start: ${label}: budget=${budget_mb} MB warning=${warning_mb} MB sample=${sample_ms} ms pid=${child} compiler_comm=${compiler_comm:-<unknown>}"

while proc_running "$child"; do
    sample="$(sample_tree "$child" "$compiler_comm")"
    set -- $sample
    cur_kb="$1"
    cur_compiler_kb="$2"
    cur_root_kb="$3"
    cur_count="$4"

    if [ "$cur_kb" -gt "$peak_kb" ]; then
        peak_kb="$cur_kb"
        peak_count="$cur_count"
    fi
    if [ "$cur_compiler_kb" -gt "$peak_compiler_kb" ]; then
        peak_compiler_kb="$cur_compiler_kb"
    fi
    if [ "$cur_root_kb" -gt "$peak_root_kb" ]; then
        peak_root_kb="$cur_root_kb"
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
        peak_compiler_mb=$(((peak_compiler_kb + 1023) / 1024))
        peak_root_mb=$(((peak_root_kb + 1023) / 1024))
        echo "RSS-CAP summary: ${label}: KILLED peak=${peak_mb} MB compiler=${peak_compiler_mb} MB root=${peak_root_mb} MB / ${budget_mb} MB pids=${peak_count}"
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
            peak_compiler_mb=$(((peak_compiler_kb + 1023) / 1024))
            peak_root_mb=$(((peak_root_kb + 1023) / 1024))
            echo "RSS-CAP summary: ${label}: TIMEOUT peak=${peak_mb} MB compiler=${peak_compiler_mb} MB root=${peak_root_mb} MB / ${budget_mb} MB pids=${peak_count}"
            exit 98
        fi
    fi

    sleep "$sleep_s"
done

wait "$child"
rc=$?

sample="$(sample_tree "$child" "$compiler_comm" 2>/dev/null || echo "0 0 0 0")"
set -- $sample
cur_kb="$1"
cur_compiler_kb="$2"
cur_root_kb="$3"
cur_count="$4"
if [ "$cur_kb" -gt "$peak_kb" ]; then
    peak_kb="$cur_kb"
    peak_count="$cur_count"
fi
if [ "$cur_compiler_kb" -gt "$peak_compiler_kb" ]; then
    peak_compiler_kb="$cur_compiler_kb"
fi
if [ "$cur_root_kb" -gt "$peak_root_kb" ]; then
    peak_root_kb="$cur_root_kb"
fi

# Floor: compiler-only and root-only are subsets of the process tree, so they
# can never legitimately exceed it. If the kernel raced us on a fast-exiting
# helper we report the tree peak as the conservative compiler-peak.
if [ "$peak_compiler_kb" -gt "$peak_kb" ]; then peak_compiler_kb="$peak_kb"; fi
if [ "$peak_root_kb" -gt "$peak_kb" ]; then peak_root_kb="$peak_kb"; fi

peak_mb=$(((peak_kb + 1023) / 1024))
peak_compiler_mb=$(((peak_compiler_kb + 1023) / 1024))
peak_root_mb=$(((peak_root_kb + 1023) / 1024))
if [ "$killed" -eq 0 ]; then
    echo "RSS-CAP summary: ${label}: exit=${rc} peak=${peak_mb} MB compiler=${peak_compiler_mb} MB root=${peak_root_mb} MB / ${budget_mb} MB pids=${peak_count}"
fi

exit "$rc"
