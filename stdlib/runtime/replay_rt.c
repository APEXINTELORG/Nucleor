/* replay_rt.c — RFC-0056 Phase A: process-local replay-event
 * log + handle table. Phase A keeps everything in-memory (the
 * `path` parameter is recorded as the log name but no file IO
 * happens); Phase B adds DSSE-signed file persistence + per-
 * backend deterministic-kernel flags. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_REPLAY_MAX_LOGS 16
#define NUC_REPLAY_MAX_EVENTS 8192

typedef struct {
    long long kind;
    long long a;
    long long b;
} NucReplayEvent;

typedef struct {
    char *path;
    long long mode;
    NucReplayEvent events[NUC_REPLAY_MAX_EVENTS];
    int count;
    int cursor;          /* replay-side consume index */
    int in_use;
} NucReplayLog;

static NucReplayLog _nuc_replay_logs[NUC_REPLAY_MAX_LOGS];
static int _nuc_replay_init = 0;

static void _nuc_replay_init_table(void) {
    if (_nuc_replay_init) return;
    for (int i = 0; i < NUC_REPLAY_MAX_LOGS; i++) {
        _nuc_replay_logs[i].in_use = 0;
        _nuc_replay_logs[i].path = NULL;
    }
    _nuc_replay_init = 1;
}

static char *_nuc_replay_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

long long nuc_replay_open(long long path_p, long long mode_id) {
    _nuc_replay_init_table();
    for (int i = 0; i < NUC_REPLAY_MAX_LOGS; i++) {
        if (!_nuc_replay_logs[i].in_use) {
            NucReplayLog *L = &_nuc_replay_logs[i];
            L->path = _nuc_replay_strdup((const char *)path_p);
            L->mode = mode_id;
            L->count = 0;
            L->cursor = 0;
            L->in_use = 1;
            return (long long)i;
        }
    }
    return -1;
}

long long nuc_replay_close(long long handle) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return -1;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return -1;
    free(L->path);
    L->path = NULL;
    L->in_use = 0;
    L->count = 0;
    L->cursor = 0;
    return 0;
}

long long nuc_replay_event_count(long long handle) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return 0;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return 0;
    return (long long)L->count;
}

long long nuc_replay_append(long long handle, long long kind, long long a, long long b) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return -1;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return -1;
    if (L->count >= NUC_REPLAY_MAX_EVENTS) return -1;
    L->events[L->count].kind = kind;
    L->events[L->count].a = a;
    L->events[L->count].b = b;
    L->count++;
    return (long long)(L->count - 1);
}

long long nuc_replay_event_kind(long long handle, long long idx) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return 0;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return 0;
    if (idx < 0 || idx >= L->count) return 0;
    return L->events[idx].kind;
}

long long nuc_replay_event_a(long long handle, long long idx) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return 0;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return 0;
    if (idx < 0 || idx >= L->count) return 0;
    return L->events[idx].a;
}

long long nuc_replay_event_b(long long handle, long long idx) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return 0;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return 0;
    if (idx < 0 || idx >= L->count) return 0;
    return L->events[idx].b;
}

long long nuc_replay_assert_byte_identical(long long handle, long long want_a, long long want_b) {
    if (handle < 0 || handle >= NUC_REPLAY_MAX_LOGS) return 0;
    NucReplayLog *L = &_nuc_replay_logs[handle];
    if (!L->in_use) return 0;
    if (L->cursor >= L->count) return 0;
    NucReplayEvent *e = &L->events[L->cursor];
    L->cursor++;
    if (e->a == want_a && e->b == want_b) return 1;
    return 0;
}
