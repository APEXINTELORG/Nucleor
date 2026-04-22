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

// Last exit status from the most recent capture call.  This is a simple
// thread-local-or-process-global slot — concurrent captures from multiple
// threads should rely on the *_with_status variant which embeds exit on the
// returned string. Single-threaded gate code reads this freely.
static long long g_last_capture_status = 0;

const char *__nucleor_proc_capture_stdout(const char *cmdline) {
    g_last_capture_status = -1;
    if (!cmdline || !*cmdline) return "";
    FILE *fp = POPEN(cmdline, "r");
    if (!fp) return "";

    size_t cap = 4096;
    size_t len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { PCLOSE(fp); return ""; }

    char chunk[1024];
    size_t n;
    while ((n = fread(chunk, 1, sizeof(chunk), fp)) > 0) {
        if (len + n + 1 > cap) {
            while (len + n + 1 > cap) cap *= 2;
            char *grown = (char *)realloc(buf, cap);
            if (!grown) { free(buf); PCLOSE(fp); return ""; }
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
    char *combined = (char *)malloc(body_len + 32);
    if (!combined) return body;
    int header_len = snprintf(combined, 32, "%lld\n", status);
    if (header_len < 0) { free(combined); return body; }
    memcpy(combined + header_len, body, body_len);
    combined[header_len + body_len] = 0;
    if (body && *body) free((void *)body);
    return combined;
}

// Convenience: explicitly-quoted command + single argument. Builds
// `"<cmd>" "<arg>"` and runs it. Avoids users having to do shell escaping
// for the common one-arg case (which is what `nuc test --runner-shim NAME`
// looks like).
long long __nucleor_proc_run1(const char *cmd, const char *arg) {
    if (!cmd) return -1;
    size_t need = strlen(cmd) + 8;
    if (arg) need += strlen(arg);
    char *line = (char *)malloc(need);
    if (!line) return -1;
    if (arg && *arg) {
        snprintf(line, need, "\"%s\" \"%s\"", cmd, arg);
    } else {
        snprintf(line, need, "\"%s\"", cmd);
    }
    long long status = __nucleor_proc_run(line);
    free(line);
    return status;
}
