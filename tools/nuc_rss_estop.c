#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#define _CRT_SECURE_NO_WARNINGS

#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <wchar.h>

#pragma comment(lib, "psapi.lib")

typedef struct {
    DWORD pid;
    DWORD parent;
    WCHAR name[MAX_PATH];
} ProcEntry;

typedef struct {
    DWORD pid;
    WCHAR name[MAX_PATH];
    SIZE_T rss;
} ProcSample;

typedef struct {
    ProcSample *items;
    size_t count;
    size_t cap;
} SampleVec;

typedef struct {
    int exit_code;
    int killed;
    const WCHAR *reason;
    int budget_mb;
    int warning_mb;
    int crossed_warning;
    double warning_at_seconds;
    WCHAR warning_detail[1024];
    double peak_mb;
    WCHAR peak_detail[1024];
    double process_tree_peak_mb;
    WCHAR process_tree_peak_detail[1024];
    double compiler_peak_mb;
    WCHAR compiler_peak_detail[1024];
    double root_peak_mb;
    WCHAR root_peak_detail[1024];
    double wall_seconds;
    int sample_ms;
    const WCHAR *stdout_path;
    const WCHAR *stderr_path;
} Summary;

static ULONGLONG filetime_u64(FILETIME ft) {
    return (((ULONGLONG)ft.dwHighDateTime) << 32) | (ULONGLONG)ft.dwLowDateTime;
}

static double seconds_since(LARGE_INTEGER start, LARGE_INTEGER freq) {
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);
    return (double)(now.QuadPart - start.QuadPart) / (double)freq.QuadPart;
}

static int append_w(WCHAR **buf, size_t *len, size_t *cap, const WCHAR *s) {
    size_t n = wcslen(s);
    if (*len + n + 1 > *cap) {
        size_t next = *cap ? *cap : 256;
        while (*len + n + 1 > next) next *= 2;
        WCHAR *p = (WCHAR *)realloc(*buf, next * sizeof(WCHAR));
        if (!p) return 0;
        *buf = p;
        *cap = next;
    }
    memcpy(*buf + *len, s, n * sizeof(WCHAR));
    *len += n;
    (*buf)[*len] = 0;
    return 1;
}

static int append_quoted_arg(WCHAR **buf, size_t *len, size_t *cap, const WCHAR *arg) {
    if (!append_w(buf, len, cap, L"\"")) return 0;
    size_t slash_count = 0;
    for (const WCHAR *p = arg; *p; p++) {
        if (*p == L'\\') {
            slash_count++;
            continue;
        }
        if (*p == L'"') {
            for (size_t i = 0; i < slash_count * 2 + 1; i++) {
                if (!append_w(buf, len, cap, L"\\")) return 0;
            }
            slash_count = 0;
            if (!append_w(buf, len, cap, L"\"")) return 0;
            continue;
        }
        for (size_t i = 0; i < slash_count; i++) {
            if (!append_w(buf, len, cap, L"\\")) return 0;
        }
        slash_count = 0;
        WCHAR tmp[2] = {*p, 0};
        if (!append_w(buf, len, cap, tmp)) return 0;
    }
    for (size_t i = 0; i < slash_count * 2; i++) {
        if (!append_w(buf, len, cap, L"\\")) return 0;
    }
    return append_w(buf, len, cap, L"\"");
}

static int append_command_arg(WCHAR **buf, size_t *len, size_t *cap, const WCHAR *arg) {
    if (!arg || !arg[0]) return append_quoted_arg(buf, len, cap, L"");
    for (const WCHAR *p = arg; *p; p++) {
        if (*p == L' ' || *p == L'\t' || *p == L'\n' || *p == L'\r' || *p == L'"') {
            return append_quoted_arg(buf, len, cap, arg);
        }
    }
    return append_w(buf, len, cap, arg);
}

static const WCHAR *basename_w(const WCHAR *path) {
    if (!path) return L"";
    const WCHAR *base = path;
    for (const WCHAR *p = path; *p; p++) {
        if (*p == L'\\' || *p == L'/') base = p + 1;
    }
    return base;
}

static WCHAR *build_command_line(const WCHAR *file, int argc, WCHAR **argv, int arg_start, const WCHAR *arg_string) {
    WCHAR *cmd = NULL;
    size_t len = 0, cap = 0;
    if (!append_quoted_arg(&cmd, &len, &cap, file)) return NULL;
    if (arg_string && arg_string[0]) {
        if (!append_w(&cmd, &len, &cap, L" ")) return NULL;
        if (!append_w(&cmd, &len, &cap, arg_string)) return NULL;
    } else {
        for (int i = arg_start; i < argc; i++) {
            if (!append_w(&cmd, &len, &cap, L" ")) return NULL;
            if (!append_command_arg(&cmd, &len, &cap, argv[i])) return NULL;
        }
    }
    return cmd;
}

static int sample_vec_push(SampleVec *vec, ProcSample sample) {
    if (vec->count == vec->cap) {
        size_t next = vec->cap ? vec->cap * 2 : 16;
        ProcSample *p = (ProcSample *)realloc(vec->items, next * sizeof(ProcSample));
        if (!p) return 0;
        vec->items = p;
        vec->cap = next;
    }
    vec->items[vec->count++] = sample;
    return 1;
}

static int pid_seen(DWORD *seen, size_t seen_count, DWORD pid) {
    for (size_t i = 0; i < seen_count; i++) {
        if (seen[i] == pid) return 1;
    }
    return 0;
}

static int find_entry(ProcEntry *entries, size_t count, DWORD pid) {
    for (size_t i = 0; i < count; i++) {
        if (entries[i].pid == pid) return (int)i;
    }
    return -1;
}

static int sample_process(DWORD pid, const WCHAR *name, int is_root, int root_exited,
                          ULONGLONG lower_time, ULONGLONG root_upper_time, ProcSample *out) {
    if (is_root && root_exited) return 0;
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!h) return 0;

    FILETIME created, exited, kernel, user;
    PROCESS_MEMORY_COUNTERS pmc;
    int ok = 0;
    if (GetProcessTimes(h, &created, &exited, &kernel, &user)) {
        ULONGLONG created_u = filetime_u64(created);
        if ((is_root && created_u >= lower_time && created_u <= root_upper_time) ||
            (!is_root && created_u >= lower_time)) {
            ZeroMemory(&pmc, sizeof(pmc));
            pmc.cb = sizeof(pmc);
            if (GetProcessMemoryInfo(h, &pmc, sizeof(pmc))) {
                out->pid = pid;
                wcsncpy(out->name, name ? name : L"", MAX_PATH - 1);
                out->name[MAX_PATH - 1] = 0;
                out->rss = pmc.WorkingSetSize;
                ok = 1;
            }
        }
    }
    CloseHandle(h);
    return ok;
}

static SampleVec sample_tree(DWORD root_pid, int root_exited, ULONGLONG root_created) {
    SampleVec samples = {0};
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return samples;

    ProcEntry *entries = NULL;
    size_t count = 0, cap = 0;
    PROCESSENTRY32W pe;
    ZeroMemory(&pe, sizeof(pe));
    pe.dwSize = sizeof(pe);
    if (Process32FirstW(snap, &pe)) {
        do {
            if (count == cap) {
                size_t next = cap ? cap * 2 : 512;
                ProcEntry *p = (ProcEntry *)realloc(entries, next * sizeof(ProcEntry));
                if (!p) break;
                entries = p;
                cap = next;
            }
            entries[count].pid = pe.th32ProcessID;
            entries[count].parent = pe.th32ParentProcessID;
            wcsncpy(entries[count].name, pe.szExeFile, MAX_PATH - 1);
            entries[count].name[MAX_PATH - 1] = 0;
            count++;
            pe.dwSize = sizeof(pe);
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);

    DWORD *queue = (DWORD *)calloc(count + 1, sizeof(DWORD));
    DWORD *seen = (DWORD *)calloc(count + 1, sizeof(DWORD));
    if (!queue || !seen) {
        free(queue);
        free(seen);
        free(entries);
        return samples;
    }

    ULONGLONG lower_time = root_created > 20000000ULL ? root_created - 20000000ULL : 0ULL;
    ULONGLONG root_upper = root_created + 20000000ULL;
    size_t qh = 0, qt = 0, seen_count = 0;
    queue[qt++] = root_pid;

    while (qh < qt) {
        DWORD pid = queue[qh++];
        if (pid_seen(seen, seen_count, pid)) continue;
        seen[seen_count++] = pid;

        int idx = find_entry(entries, count, pid);
        const WCHAR *name = idx >= 0 ? entries[idx].name : L"";
        ProcSample sample;
        if (sample_process(pid, name, pid == root_pid, root_exited, lower_time, root_upper, &sample)) {
            sample_vec_push(&samples, sample);
        }

        for (size_t i = 0; i < count; i++) {
            if (entries[i].parent == pid && !pid_seen(seen, seen_count, entries[i].pid)) {
                if (qt < count + 1) queue[qt++] = entries[i].pid;
            }
        }
    }

    free(queue);
    free(seen);
    free(entries);
    return samples;
}

static int compare_sample_desc(const void *a, const void *b) {
    const ProcSample *pa = (const ProcSample *)a;
    const ProcSample *pb = (const ProcSample *)b;
    if (pa->rss < pb->rss) return 1;
    if (pa->rss > pb->rss) return -1;
    return 0;
}

static void format_detail(SampleVec *samples, WCHAR *out, size_t out_len) {
    out[0] = 0;
    if (samples->count == 0) return;
    ProcSample *copy = (ProcSample *)malloc(samples->count * sizeof(ProcSample));
    if (!copy) return;
    memcpy(copy, samples->items, samples->count * sizeof(ProcSample));
    qsort(copy, samples->count, sizeof(ProcSample), compare_sample_desc);

    size_t limit = samples->count < 8 ? samples->count : 8;
    for (size_t i = 0; i < limit; i++) {
        WCHAR part[160];
        swprintf(part, 160, L"%ls:%.1fMB", copy[i].name[0] ? copy[i].name : L"process", (double)copy[i].rss / (1024.0 * 1024.0));
        if (i > 0) wcsncat(out, L", ", out_len - wcslen(out) - 1);
        wcsncat(out, part, out_len - wcslen(out) - 1);
    }
    free(copy);
}

static void terminate_samples(SampleVec *samples) {
    for (size_t i = samples->count; i > 0; i--) {
        DWORD pid = samples->items[i - 1].pid;
        HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
        if (h) {
            TerminateProcess(h, 99);
            CloseHandle(h);
        }
    }
}

static uint64_t sum_samples(SampleVec *samples) {
    uint64_t total = 0;
    for (size_t i = 0; i < samples->count; i++) total += (uint64_t)samples->items[i].rss;
    return total;
}

static SampleVec filter_samples_by_name(SampleVec *samples, const WCHAR *name) {
    SampleVec out = {0};
    if (!name || !name[0]) return out;
    for (size_t i = 0; i < samples->count; i++) {
        if (_wcsicmp(samples->items[i].name, name) == 0) {
            sample_vec_push(&out, samples->items[i]);
        }
    }
    return out;
}

static SampleVec filter_samples_by_pid(SampleVec *samples, DWORD pid) {
    SampleVec out = {0};
    for (size_t i = 0; i < samples->count; i++) {
        if (samples->items[i].pid == pid) {
            sample_vec_push(&out, samples->items[i]);
        }
    }
    return out;
}

static void json_wstr(const WCHAR *s) {
    putchar('"');
    if (s) {
        for (const WCHAR *p = s; *p; p++) {
            WCHAR ch = *p;
            if (ch == L'\\' || ch == L'"') {
                putchar('\\');
                putchar((char)ch);
            } else if (ch == L'\n') {
                fputs("\\n", stdout);
            } else if (ch == L'\r') {
                fputs("\\r", stdout);
            } else if (ch == L'\t') {
                fputs("\\t", stdout);
            } else if (ch >= 32 && ch < 127) {
                putchar((char)ch);
            } else {
                char mb[8];
                int n = WideCharToMultiByte(CP_UTF8, 0, p, 1, mb, sizeof(mb), NULL, NULL);
                if (n > 0) fwrite(mb, 1, (size_t)n, stdout);
            }
        }
    }
    putchar('"');
}

static void print_summary_json(const Summary *s) {
    printf("{");
    printf("\"exit_code\":%d,", s->exit_code);
    printf("\"killed\":%s,", s->killed ? "true" : "false");
    printf("\"reason\":"); json_wstr(s->reason ? s->reason : L""); printf(",");
    printf("\"budget_mb\":%d,", s->budget_mb);
    printf("\"warning_mb\":%d,", s->warning_mb);
    printf("\"crossed_warning\":%s,", s->crossed_warning ? "true" : "false");
    if (s->crossed_warning) printf("\"warning_at_seconds\":%.3f,", s->warning_at_seconds);
    else printf("\"warning_at_seconds\":null,");
    printf("\"warning_detail\":"); json_wstr(s->warning_detail); printf(",");
    printf("\"peak_mb\":%.1f,", s->peak_mb);
    printf("\"peak_detail\":"); json_wstr(s->peak_detail); printf(",");
    printf("\"process_tree_peak_mb\":%.1f,", s->process_tree_peak_mb);
    printf("\"process_tree_peak_detail\":"); json_wstr(s->process_tree_peak_detail); printf(",");
    printf("\"compiler_peak_mb\":%.1f,", s->compiler_peak_mb);
    printf("\"compiler_peak_detail\":"); json_wstr(s->compiler_peak_detail); printf(",");
    printf("\"root_peak_mb\":%.1f,", s->root_peak_mb);
    printf("\"root_peak_detail\":"); json_wstr(s->root_peak_detail); printf(",");
    printf("\"wall_seconds\":%.3f,", s->wall_seconds);
    printf("\"sample_ms\":%d,", s->sample_ms);
    printf("\"stdout\":"); json_wstr(s->stdout_path); printf(",");
    printf("\"stderr\":"); json_wstr(s->stderr_path); printf(",");
    printf("\"tmp_dir\":\"\",");
    printf("\"job_assigned\":false,");
    printf("\"native\":true");
    printf("}\n");
}

static int parse_int(const WCHAR *s, int fallback) {
    if (!s || !s[0]) return fallback;
    return _wtoi(s);
}

int wmain(int argc, WCHAR **argv) {
    const WCHAR *file = NULL;
    const WCHAR *cwd = NULL;
    const WCHAR *stdout_path = L"NUL";
    const WCHAR *stderr_path = L"NUL";
    const WCHAR *arg_string = NULL;
    int arg_start = argc;
    int budget_mb = 1000;
    int warning_mb = 800;
    int timeout_sec = 0;
    int sample_ms = 100;

    for (int i = 1; i < argc; i++) {
        if (wcscmp(argv[i], L"--") == 0) {
            arg_start = i + 1;
            break;
        } else if (wcscmp(argv[i], L"--arg-count") == 0 && i + 1 < argc) {
            (void)parse_int(argv[++i], 0);
            arg_start = i + 1;
            break;
        } else if (wcscmp(argv[i], L"--file") == 0 && i + 1 < argc) {
            file = argv[++i];
        } else if (wcscmp(argv[i], L"--cwd") == 0 && i + 1 < argc) {
            cwd = argv[++i];
        } else if (wcscmp(argv[i], L"--stdout") == 0 && i + 1 < argc) {
            stdout_path = argv[++i];
        } else if (wcscmp(argv[i], L"--stderr") == 0 && i + 1 < argc) {
            stderr_path = argv[++i];
        } else if (wcscmp(argv[i], L"--arg-string") == 0 && i + 1 < argc) {
            arg_string = argv[++i];
        } else if (wcscmp(argv[i], L"--budget-mb") == 0 && i + 1 < argc) {
            budget_mb = parse_int(argv[++i], budget_mb);
        } else if (wcscmp(argv[i], L"--warning-mb") == 0 && i + 1 < argc) {
            warning_mb = parse_int(argv[++i], warning_mb);
        } else if (wcscmp(argv[i], L"--timeout-sec") == 0 && i + 1 < argc) {
            timeout_sec = parse_int(argv[++i], timeout_sec);
        } else if (wcscmp(argv[i], L"--sample-ms") == 0 && i + 1 < argc) {
            sample_ms = parse_int(argv[++i], sample_ms);
        }
    }

    Summary summary;
    ZeroMemory(&summary, sizeof(summary));
    summary.exit_code = 1;
    summary.budget_mb = budget_mb;
    summary.warning_mb = warning_mb;
    summary.sample_ms = sample_ms;
    summary.stdout_path = stdout_path;
    summary.stderr_path = stderr_path;

    if (!file || budget_mb < 1 || sample_ms < 25 || warning_mb >= budget_mb) {
        summary.reason = L"invalid nuc_rss_estop arguments";
        print_summary_json(&summary);
        return 1;
    }

    SECURITY_ATTRIBUTES inherit_sa;
    ZeroMemory(&inherit_sa, sizeof(inherit_sa));
    inherit_sa.nLength = sizeof(inherit_sa);
    inherit_sa.bInheritHandle = TRUE;
    HANDLE out_h = CreateFileW(stdout_path, GENERIC_WRITE, FILE_SHARE_READ, &inherit_sa, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    HANDLE err_h = CreateFileW(stderr_path, GENERIC_WRITE, FILE_SHARE_READ, &inherit_sa, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (out_h == INVALID_HANDLE_VALUE || err_h == INVALID_HANDLE_VALUE) {
        summary.reason = L"failed to open child stdout/stderr paths";
        if (out_h != INVALID_HANDLE_VALUE) CloseHandle(out_h);
        if (err_h != INVALID_HANDLE_VALUE) CloseHandle(err_h);
        print_summary_json(&summary);
        return 1;
    }

    WCHAR *cmd = build_command_line(file, argc, argv, arg_start, arg_string);
    if (!cmd) {
        summary.reason = L"failed to allocate command line";
        CloseHandle(out_h);
        CloseHandle(err_h);
        print_summary_json(&summary);
        return 1;
    }

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    ZeroMemory(&pi, sizeof(pi));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = out_h;
    si.hStdError = err_h;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

    BOOL ok = CreateProcessW(file, cmd, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, cwd, &si, &pi);
    free(cmd);
    CloseHandle(out_h);
    CloseHandle(err_h);
    if (!ok) {
        summary.reason = L"CreateProcessW failed";
        print_summary_json(&summary);
        return 1;
    }

    FILETIME created, exited, kernel, user;
    ULONGLONG root_created = 0;
    if (GetProcessTimes(pi.hProcess, &created, &exited, &kernel, &user)) {
        root_created = filetime_u64(created);
    }

    LARGE_INTEGER freq, start;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&start);

    const WCHAR *root_name = basename_w(file);
    SIZE_T process_tree_peak_bytes = 0;
    SIZE_T compiler_peak_bytes = 0;
    SIZE_T root_peak_bytes = 0;
    int killed = 0;
    DWORD exit_code = 0;
    const uint64_t limit_bytes = (uint64_t)budget_mb * 1024ULL * 1024ULL;
    const uint64_t warning_bytes = (uint64_t)warning_mb * 1024ULL * 1024ULL;

    for (;;) {
        DWORD root_status = STILL_ACTIVE;
        GetExitCodeProcess(pi.hProcess, &root_status);
        int root_exited = (root_status != STILL_ACTIVE);

        SampleVec samples = sample_tree(pi.dwProcessId, root_exited, root_created);
        uint64_t rss = sum_samples(&samples);

        if (rss > process_tree_peak_bytes) {
            process_tree_peak_bytes = (SIZE_T)rss;
            format_detail(&samples, summary.process_tree_peak_detail, sizeof(summary.process_tree_peak_detail) / sizeof(summary.process_tree_peak_detail[0]));
            wcsncpy(summary.peak_detail, summary.process_tree_peak_detail, (sizeof(summary.peak_detail) / sizeof(summary.peak_detail[0])) - 1);
            summary.peak_detail[(sizeof(summary.peak_detail) / sizeof(summary.peak_detail[0])) - 1] = 0;
        }

        SampleVec compiler_samples = filter_samples_by_name(&samples, root_name);
        uint64_t compiler_rss = sum_samples(&compiler_samples);
        if (compiler_rss > compiler_peak_bytes) {
            compiler_peak_bytes = (SIZE_T)compiler_rss;
            format_detail(&compiler_samples, summary.compiler_peak_detail, sizeof(summary.compiler_peak_detail) / sizeof(summary.compiler_peak_detail[0]));
        }

        SampleVec root_samples = filter_samples_by_pid(&samples, pi.dwProcessId);
        uint64_t root_rss = sum_samples(&root_samples);
        if (root_rss > root_peak_bytes) {
            root_peak_bytes = (SIZE_T)root_rss;
            format_detail(&root_samples, summary.root_peak_detail, sizeof(summary.root_peak_detail) / sizeof(summary.root_peak_detail[0]));
        }
        free(compiler_samples.items);
        free(root_samples.items);

        if (!summary.crossed_warning && rss > warning_bytes) {
            summary.crossed_warning = 1;
            summary.warning_at_seconds = seconds_since(start, freq);
            format_detail(&samples, summary.warning_detail, sizeof(summary.warning_detail) / sizeof(summary.warning_detail[0]));
        }

        if (rss > limit_bytes) {
            killed = 1;
            summary.reason = L"process-tree RSS exceeded e-stop";
            terminate_samples(&samples);
            free(samples.items);
            Sleep(100);
            SampleVec remaining = sample_tree(pi.dwProcessId, 0, root_created);
            terminate_samples(&remaining);
            free(remaining.items);
            break;
        }

        if (timeout_sec > 0 && seconds_since(start, freq) > (double)timeout_sec) {
            killed = 1;
            summary.reason = L"timeout exceeded";
            terminate_samples(&samples);
            free(samples.items);
            Sleep(100);
            SampleVec remaining = sample_tree(pi.dwProcessId, 0, root_created);
            terminate_samples(&remaining);
            free(remaining.items);
            break;
        }

        if (samples.count == 0 && root_exited) {
            exit_code = root_status;
            free(samples.items);
            break;
        }
        free(samples.items);

        if (!root_exited) {
            WaitForSingleObject(pi.hProcess, (DWORD)sample_ms);
        } else {
            Sleep((DWORD)sample_ms);
        }
    }

    if (!killed) {
        WaitForSingleObject(pi.hProcess, INFINITE);
        GetExitCodeProcess(pi.hProcess, &exit_code);
    } else {
        exit_code = 99;
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    summary.exit_code = (int)exit_code;
    summary.killed = killed;
    summary.peak_mb = (double)process_tree_peak_bytes / (1024.0 * 1024.0);
    summary.process_tree_peak_mb = summary.peak_mb;
    summary.compiler_peak_mb = (double)compiler_peak_bytes / (1024.0 * 1024.0);
    summary.root_peak_mb = (double)root_peak_bytes / (1024.0 * 1024.0);
    summary.wall_seconds = seconds_since(start, freq);
    print_summary_json(&summary);
    return (int)exit_code;
}
