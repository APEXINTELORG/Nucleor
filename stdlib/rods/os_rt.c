// rods/os runtime — OS primitives for Nucleor
#define _CRT_SECURE_NO_WARNINGS
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <direct.h>
#define nr_getcwd _getcwd
#else
#include <unistd.h>
#define nr_getcwd getcwd
#endif

const char *rods_os_getenv(const char *name) {
    if (!name) return "";
    const char *val = getenv(name);
    if (!val) return "";
    return val;
}

void rods_os_exit(long long code) {
    exit((int)code);
}

const char *rods_os_getcwd(void) {
    static char buf[4096];
    if (nr_getcwd(buf, sizeof(buf))) return buf;
    return "";
}

long long rods_os_getpid(void) {
#ifdef _WIN32
    extern unsigned long GetCurrentProcessId(void);
    return (long long)GetCurrentProcessId();
#else
    extern int getpid(void);
    return (long long)getpid();
#endif
}
