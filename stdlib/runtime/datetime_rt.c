// datetime_rt.c — Date/Time Operations for Nucleor
// Timestamps, calendar math, formatting, parsing.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/datetime_rt.c -o target/datetime_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
#endif

typedef struct { long long *data; int len; int cap; } DTVec;

// ================================================================
//  Current time (milliseconds since epoch)
// ================================================================

long long nuc_dt_now(void) {
#ifdef _WIN32
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    unsigned long long t = ((unsigned long long)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    t -= 116444736000000000ULL; // Windows epoch → Unix epoch
    return (long long)(t / 10000); // 100ns → ms
#else
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (long long)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
#endif
}

// ================================================================
//  From components → timestamp (ms since epoch)
// ================================================================

long long nuc_dt_from_ymd(long long y, long long m, long long d,
                           long long h, long long min, long long s) {
    struct tm t = {0};
    t.tm_year = (int)y - 1900;
    t.tm_mon = (int)m - 1;
    t.tm_mday = (int)d;
    t.tm_hour = (int)h;
    t.tm_min = (int)min;
    t.tm_sec = (int)s;
    t.tm_isdst = -1;
    time_t epoch = mktime(&t);
    return (long long)epoch * 1000;
}

// v0.8.106: companion using _mkgmtime / timegm — interprets
// the argument components as UTC. Round-trips correctly with
// nuc_dt_to_ymd (which uses gmtime). Fixes the mktime/gmtime
// asymmetry surfaced by the v0.8.96 datetime fixture.
//
// Adopters wanting UTC-anchored timestamps (servers, log lines,
// machine-to-machine) should call this. Adopters wanting local-
// time interpretation (human-facing UIs) keep using
// nuc_dt_from_ymd. The two coexist; nuc_dt_from_ymd's behavior
// is preserved for backwards compatibility.
long long nuc_dt_from_ymd_utc(long long y, long long m, long long d,
                               long long h, long long min, long long s) {
    struct tm t = {0};
    t.tm_year = (int)y - 1900;
    t.tm_mon = (int)m - 1;
    t.tm_mday = (int)d;
    t.tm_hour = (int)h;
    t.tm_min = (int)min;
    t.tm_sec = (int)s;
    t.tm_isdst = 0;
#ifdef _WIN32
    time_t epoch = _mkgmtime(&t);
#else
    time_t epoch = timegm(&t);
#endif
    return (long long)epoch * 1000;
}

// ================================================================
//  Timestamp → components [y, m, d, h, min, s]
// ================================================================

long long nuc_dt_to_ymd(long long ts_ms) {
    time_t epoch = (time_t)(ts_ms / 1000);
    struct tm *t = gmtime(&epoch);
    if (!t) return 0;

    DTVec *v = (DTVec *)malloc(sizeof(DTVec));
    v->len = 6; v->cap = 6;
    v->data = (long long *)malloc(6 * sizeof(long long));
    v->data[0] = t->tm_year + 1900;
    v->data[1] = t->tm_mon + 1;
    v->data[2] = t->tm_mday;
    v->data[3] = t->tm_hour;
    v->data[4] = t->tm_min;
    v->data[5] = t->tm_sec;
    return (long long)v;
}

// ================================================================
//  Arithmetic
// ================================================================

long long nuc_dt_diff_days(long long ts1_ms, long long ts2_ms) {
    long long diff = ts2_ms - ts1_ms;
    return diff / (1000LL * 60 * 60 * 24);
}

long long nuc_dt_diff_seconds(long long ts1_ms, long long ts2_ms) {
    return (ts2_ms - ts1_ms) / 1000;
}

long long nuc_dt_add_days(long long ts_ms, long long n) {
    return ts_ms + n * 1000LL * 60 * 60 * 24;
}

long long nuc_dt_add_hours(long long ts_ms, long long n) {
    return ts_ms + n * 1000LL * 60 * 60;
}

// ================================================================
//  Day of week (0=Sunday, 6=Saturday)
// ================================================================

long long nuc_dt_day_of_week(long long ts_ms) {
    time_t epoch = (time_t)(ts_ms / 1000);
    struct tm *t = gmtime(&epoch);
    return t ? (long long)t->tm_wday : 0;
}

// ================================================================
//  Format: ISO 8601
// ================================================================

const char *nuc_dt_format_iso(long long ts_ms) {
    time_t epoch = (time_t)(ts_ms / 1000);
    struct tm *t = gmtime(&epoch);
    if (!t) return "1970-01-01T00:00:00Z";
    char *buf = (char *)malloc(32);
    snprintf(buf, 32, "%04d-%02d-%02dT%02d:%02d:%02dZ",
             t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
             t->tm_hour, t->tm_min, t->tm_sec);
    return buf;
}

// ================================================================
//  Parse ISO 8601 → timestamp
// ================================================================

long long nuc_dt_parse_iso(const char *str) {
    if (!str) return 0;
    int y, m, d, h = 0, min = 0, s = 0;
    sscanf(str, "%d-%d-%dT%d:%d:%d", &y, &m, &d, &h, &min, &s);
    return nuc_dt_from_ymd(y, m, d, h, min, s);
}

// ================================================================
//  Elapsed timer (high-resolution, returns microseconds)
// ================================================================

long long nuc_dt_elapsed_us(long long start_ms) {
    long long now = nuc_dt_now();
    return (now - start_ms) * 1000; // ms → us
}

// ================================================================
//  Is leap year
// ================================================================

long long nuc_dt_is_leap(long long year) {
    int y = (int)year;
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 1 : 0;
}

// ================================================================
//  Days in month
// ================================================================

long long nuc_dt_days_in_month(long long year, long long month) {
    int m = (int)month;
    static const int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if (m < 1 || m > 12) return 0;
    if (m == 2 && nuc_dt_is_leap(year)) return 29;
    return days[m - 1];
}
