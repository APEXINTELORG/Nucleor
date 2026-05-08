// process_rt.c — Cross-platform child-process primitives for Nucleor.
//
// Two complementary surfaces:
//   * proc_run(cmdline) -> exit_code               (no output captured)
//   * proc_capture_stdout(cmdline) -> str          (stdout body, no exit)
//   * proc_capture_status(cmdline) -> i64          (last exit code from
//                                                   the most recent capture)
//   * proc_capture_with_status(cmdline) -> str     (writes a leading
//                                                   "<exit>\n" line then
//                                                   the captured stdout)
//
// All variants run the supplied command line through the platform shell
// (cmd.exe on Windows, /bin/sh -c on POSIX) so quoting + globbing match
// what the user already expects from `nuc test`'s @system invocations.
//
// Designed for `nuc test --isolation=process` (RFC-0021 phase 2): a parent
// driver invokes `nuc test --runner-shim <name>` per test, captures the
// "<exit>\n<stdout>" body, and reports pass/fail without any test process
// being able to corrupt the parent's heap, file handles, or globals.
//
// Compile: clang -c stdlib/runtime/process_rt.c -o target/process_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#define POPEN  _popen
#define PCLOSE _pclose
#else
#include <unistd.h>
#include <sys/wait.h>
#define POPEN  popen
#define PCLOSE pclose
#endif

// Platform-portable exit status normalization. _pclose on Windows returns the
// child's raw exit code; pclose on POSIX returns wait()-style status (use
// WEXITSTATUS to extract the exit code, or the negative of the signal if the
// child died from a signal — we surface that as 128+signo, matching shell).
static int normalize_status(int raw) {
#ifdef _WIN32
    return raw;
#else
    if (WIFEXITED(raw))   return WEXITSTATUS(raw);
    if (WIFSIGNALED(raw)) return 128 + WTERMSIG(raw);
    return raw;
#endif
}

long long __nucleor_proc_run(const char *cmdline) {
    if (!cmdline || !*cmdline) return -1;
    int raw = system(cmdline);
    if (raw == -1) return -1;
    return (long long)normalize_status(raw);
}

// Last exit status from the most recent capture call.
//
// Lane 6 / S2 (audit 2026-05-08): pre-fix this slot was a process-global
// `static long long`. Two threads calling `proc_capture_stdout` raced on
// the slot — the first thread's status was overwritten by the second
// thread's open before the first thread read it. Now `_Thread_local`
// (C11) / `__declspec(thread)` (MSVC); each thread sees its own slot.
// Adopters needing the cross-thread shape should still prefer
// `proc_capture_with_status` which embeds the status in the returned
// string body.
#if defined(_MSC_VER)
static __declspec(thread) long long g_last_capture_status = 0;
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
static _Thread_local long long g_last_capture_status = 0;
#elif defined(__GNUC__) || defined(__clang__)
static __thread long long g_last_capture_status = 0;
#else
/* Fallback: process-global. Documented behavior on toolchains that
 * lack TLS support. */
static long long g_last_capture_status = 0;
#endif

// Lane 6 / S1 (audit 2026-05-08): every error path now returns a
// malloc'd empty string so callers can `__nucleor_str_free` the
// result unconditionally. Pre-fix the error returns were the
// string literal `""`, mixing literal and heap pointers in the
// same return type.
static const char *s1_empty_owned(void) {
    char *r = (char *)malloc(1);
    if (!r) return "";
    r[0] = 0;
    return r;
}

const char *__nucleor_proc_capture_stdout(const char *cmdline) {
    g_last_capture_status = -1;
    if (!cmdline || !*cmdline) return s1_empty_owned();
    FILE *fp = POPEN(cmdline, "r");
    if (!fp) return s1_empty_owned();

    size_t cap = 4096;
    size_t len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { PCLOSE(fp); return s1_empty_owned(); }

    char chunk[1024];
    size_t n;
    while ((n = fread(chunk, 1, sizeof(chunk), fp)) > 0) {
        if (len + n + 1 > cap) {
            while (len + n + 1 > cap) cap *= 2;
            char *grown = (char *)realloc(buf, cap);
            if (!grown) { free(buf); PCLOSE(fp); return s1_empty_owned(); }
            buf = grown;
        }
        memcpy(buf + len, chunk, n);
        len += n;
    }
    buf[len] = 0;

    int raw = PCLOSE(fp);
    g_last_capture_status = (raw == -1) ? -1 : (long long)normalize_status(raw);
    return buf;
}

long long __nucleor_proc_capture_status(void) {
    return g_last_capture_status;
}

// Capture variant that prepends "<exit>\n" so a single str return carries
// both fields atomically — useful when the caller cannot rely on a separate
// status read (e.g. result aggregated across concurrent test runners).
const char *__nucleor_proc_capture_with_status(const char *cmdline) {
    const char *body = __nucleor_proc_capture_stdout(cmdline);
    long long status = g_last_capture_status;

    size_t body_len = strlen(body);
    /* Lane 6 / S4 (audit 2026-05-08): widen header buffer to fit
     * `LLONG_MIN\n\0` (21 chars + sign + nul) with margin. The 32-byte
     * fixed prefix had zero margin and no static assertion. */
    enum { HEADER_BUF = 64 };
    char *combined = (char *)malloc(body_len + HEADER_BUF);
    if (!combined) return body;
    int header_len = snprintf(combined, HEADER_BUF, "%lld\n", status);
    if (header_len < 0 || header_len >= HEADER_BUF) {
        free(combined);
        return body;
    }
    memcpy(combined + header_len, body, body_len);
    combined[header_len + body_len] = 0;
    /* Body is now always heap-owned (s1_empty_owned() above). Free it. */
    free((void *)body);
    return combined;
}

// Lane 6 / S3 (audit 2026-05-08): shell-injection hardening.
// Pre-fix `proc_run1("git", "x\" ; rm -rf /")` produced
//   "git" "x" ; rm -rf /"
// — the embedded `"` closed the double-quoted argv form and the
// rest was interpreted as new shell tokens. Both Windows and POSIX
// quoting are now applied per platform. Inputs containing the
// platform-specific control characters that cannot be quoted
// safely are rejected with a diagnostic instead of being silently
// passed through.
//
// Documented contract:
//   * `cmd` must not contain `"` (Windows) or `'` (POSIX) — these
//     cannot be quoted by this helper without invoking the shell.
//     Adopters needing argv-shaped invocation should use the
//     forthcoming `proc_run_argv` (RFC-0021 follow-on, Lane 6
//     defers full argv-mode shipping).
//   * `arg` is treated as opaque user data and quoted; embedded
//     quotes are escaped per platform.
//
// `proc_run` itself still goes through `system(3)`. Callers that
// need to reach binaries with arbitrary names / shell-meta in the
// path should pre-quote the path themselves and use `proc_run`
// directly with full shell semantics.

static int s3_shell_unquotable(const char *s) {
    if (!s) return 0;
    while (*s) {
#ifdef _WIN32
        if (*s == '"') return 1;
#else
        if (*s == '\'') return 1;
#endif
        s++;
    }
    return 0;
}

/* Worst-case bytes needed to escape `s` into a quoted shell argv. */
static size_t s3_quoted_len(const char *s) {
    if (!s) return 2; /* `""` or `''` */
    size_t L = 0;
    while (*s) {
#ifdef _WIN32
        /* Inside `"..."` cmd.exe treats `\"` as a literal quote;
         * caret-escape covers the rest. We already reject `"` above
         * so each char maps to itself. */
        L += 1;
#else
        if (*s == '\'') L += 4; /* close-quote + escaped-quote + reopen */
        else L += 1;
#endif
        s++;
    }
    return L + 2;
}

static char *s3_quote(const char *s, char *out) {
    if (!s) {
#ifdef _WIN32
        *out++ = '"'; *out++ = '"';
#else
        *out++ = '\''; *out++ = '\'';
#endif
        return out;
    }
#ifdef _WIN32
    *out++ = '"';
    while (*s) { *out++ = *s++; }
    *out++ = '"';
#else
    *out++ = '\'';
    while (*s) {
        if (*s == '\'') {
            *out++ = '\''; *out++ = '\\'; *out++ = '\''; *out++ = '\'';
        } else {
            *out++ = *s;
        }
        s++;
    }
    *out++ = '\'';
#endif
    return out;
}

long long __nucleor_proc_run1(const char *cmd, const char *arg) {
    if (!cmd) return -1;
    if (s3_shell_unquotable(cmd) || s3_shell_unquotable(arg)) {
        fprintf(stderr,
            "PANIC: PROC-QUOTE-001: proc_run1 argument contains a shell-quote character that cannot be safely escaped (use proc_run_argv when shipped, or pre-quote the cmdline and call proc_run directly)\n");
        fflush(stderr);
        return -1;
    }
    size_t need = s3_quoted_len(cmd) + 1 + s3_quoted_len(arg) + 1;
    char *line = (char *)malloc(need);
    if (!line) return -1;
    char *out = s3_quote(cmd, line);
    if (arg && *arg) {
        *out++ = ' ';
        out = s3_quote(arg, out);
    }
    *out = 0;
    long long status = __nucleor_proc_run(line);
    free(line);
    return status;
}
