// rods/time runtime — Time primitives for Nucleor
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
long long rods_time_now_ms(void) {
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    long long t = ((long long)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    // Convert from 100-ns intervals since 1601 to ms since Unix epoch
    t = t / 10000 - 11644473600000LL;
    return t;
}
void rods_time_sleep_ms(long long ms) {
    Sleep((DWORD)ms);
}
#else
#include <time.h>
#include <unistd.h>
long long rods_time_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (long long)ts.tv_sec * 1000 + (long long)ts.tv_nsec / 1000000;
}
void rods_time_sleep_ms(long long ms) {
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000;
    nanosleep(&ts, NULL);
}
#endif

// Format milliseconds since epoch as "YYYY-MM-DD HH:MM:SS"
const char *rods_time_format_ms(long long ms) {
    static char buf[64];
    time_t secs = (time_t)(ms / 1000);
    struct tm *t;
#ifdef _WIN32
    struct tm tbuf;
    localtime_s(&tbuf, &secs);
    t = &tbuf;
#else
    t = localtime(&secs);
#endif
    if (!t) { return "1970-01-01 00:00:00"; }
    snprintf(buf, sizeof(buf), "%04d-%02d-%02d %02d:%02d:%02d",
        t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
        t->tm_hour, t->tm_min, t->tm_sec);
    return buf;
}
