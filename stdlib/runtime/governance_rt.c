// governance_rt.c — Process-local governance registry (RFC-0060 Phase 2a).
//
// Stores AuthorRecord entries declared via stdlib/rods/governance.nr.
// Strings are interned via heap-copy so the registry survives caller-side
// buffer churn. All values pass as i64 (the Nucleor ABI).
//
// Compile: clang -c stdlib/runtime/governance_rt.c -o target/governance_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_GOV_MAX_AUTHORS 256

typedef struct {
    char *by;
    char *tool;
    char *date;
    char *commit;
    char *review;
} NucGovAuthor;

static NucGovAuthor _nuc_gov_authors[NUC_GOV_MAX_AUTHORS];
static int _nuc_gov_author_count = 0;

static char *_nuc_gov_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

static const char *_nuc_gov_get_field(long long idx, int field) {
    if (idx < 0 || idx >= _nuc_gov_author_count) return "";
    NucGovAuthor *a = &_nuc_gov_authors[(int)idx];
    switch (field) {
        case 0: return a->by ? a->by : "";
        case 1: return a->tool ? a->tool : "";
        case 2: return a->date ? a->date : "";
        case 3: return a->commit ? a->commit : "";
        case 4: return a->review ? a->review : "";
        default: return "";
    }
}

long long nuc_gov_register_authored(long long by_p, long long tool_p, long long date_p,
                                    long long commit_p, long long review_p) {
    if (_nuc_gov_author_count >= NUC_GOV_MAX_AUTHORS) return -1;
    NucGovAuthor *a = &_nuc_gov_authors[_nuc_gov_author_count];
    a->by     = _nuc_gov_strdup((const char *)by_p);
    a->tool   = _nuc_gov_strdup((const char *)tool_p);
    a->date   = _nuc_gov_strdup((const char *)date_p);
    a->commit = _nuc_gov_strdup((const char *)commit_p);
    a->review = _nuc_gov_strdup((const char *)review_p);
    _nuc_gov_author_count++;
    return (long long)(_nuc_gov_author_count - 1);
}

long long nuc_gov_authored_count(void) { return (long long)_nuc_gov_author_count; }

long long nuc_gov_authored_by(long long idx)     { return (long long)_nuc_gov_get_field(idx, 0); }
long long nuc_gov_authored_tool(long long idx)   { return (long long)_nuc_gov_get_field(idx, 1); }
long long nuc_gov_authored_date(long long idx)   { return (long long)_nuc_gov_get_field(idx, 2); }
long long nuc_gov_authored_commit(long long idx) { return (long long)_nuc_gov_get_field(idx, 3); }
long long nuc_gov_authored_review(long long idx) { return (long long)_nuc_gov_get_field(idx, 4); }

long long nuc_gov_clear(void) {
    for (int i = 0; i < _nuc_gov_author_count; i++) {
        free(_nuc_gov_authors[i].by);
        free(_nuc_gov_authors[i].tool);
        free(_nuc_gov_authors[i].date);
        free(_nuc_gov_authors[i].commit);
        free(_nuc_gov_authors[i].review);
        memset(&_nuc_gov_authors[i], 0, sizeof(NucGovAuthor));
    }
    _nuc_gov_author_count = 0;
    return 0;
}
