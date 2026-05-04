/* differentiable_rt.c — RFC-0045 Phase A: process-local registry
 * for fn-level differentiability metadata.
 *
 * Adopters call differentiable_register("name") from fn bodies;
 * external tooling + the autodiff rod read back the registry to
 * discover which fns are safe to differentiate. Phase A is
 * metadata-only per the RFC's V1.14 advisory scope; Phase B
 * parser-level @differentiable attribute support + symbol alias
 * emission lands separately. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_DIFF_MAX_FNS 256

typedef struct {
    char *fn_name;
    long long mode_id;
} NucDiff;

static NucDiff _nuc_diffs[NUC_DIFF_MAX_FNS];
static int _nuc_diff_count = 0;

static char *_nuc_diff_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

long long nuc_diff_register(long long name_p, long long mode_id) {
    /* Idempotent: re-registering the same name updates the mode
     * but does not duplicate the entry. */
    const char *name = (const char *)name_p;
    if (name == NULL) name = "";
    for (int i = 0; i < _nuc_diff_count; i++) {
        if (_nuc_diffs[i].fn_name && strcmp(_nuc_diffs[i].fn_name, name) == 0) {
            _nuc_diffs[i].mode_id = mode_id;
            return (long long)i;
        }
    }
    if (_nuc_diff_count >= NUC_DIFF_MAX_FNS) return -1;
    NucDiff *d = &_nuc_diffs[_nuc_diff_count];
    d->fn_name = _nuc_diff_strdup(name);
    d->mode_id = mode_id;
    _nuc_diff_count++;
    return (long long)(_nuc_diff_count - 1);
}

long long nuc_diff_count(void) { return (long long)_nuc_diff_count; }

long long nuc_diff_name(long long idx) {
    if (idx < 0 || idx >= _nuc_diff_count) return (long long)"";
    NucDiff *d = &_nuc_diffs[(int)idx];
    return (long long)(d->fn_name ? d->fn_name : "");
}

long long nuc_diff_mode(long long idx) {
    if (idx < 0 || idx >= _nuc_diff_count) return 0;
    return _nuc_diffs[(int)idx].mode_id;
}

long long nuc_diff_lookup(long long name_p) {
    const char *name = (const char *)name_p;
    if (name == NULL) return -1;
    for (int i = 0; i < _nuc_diff_count; i++) {
        if (_nuc_diffs[i].fn_name && strcmp(_nuc_diffs[i].fn_name, name) == 0) {
            return (long long)i;
        }
    }
    return -1;
}

long long nuc_diff_clear(void) {
    for (int i = 0; i < _nuc_diff_count; i++) {
        free(_nuc_diffs[i].fn_name);
        memset(&_nuc_diffs[i], 0, sizeof(NucDiff));
    }
    _nuc_diff_count = 0;
    return 0;
}
