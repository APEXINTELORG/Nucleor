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

/* ------------------------------------------------------------------
 * v0.7.79 — RFC-0060 Phase 2b: PolicyDecl registry.
 *
 * Stores policy intents declared via governance_declare_policy(name).
 * The actual policy enforcement against source happens in
 * compiler/nucleor_tools_suite.nr's source_rule_check pass
 * (GOV-001 require_authored, GOV-002 no_unsafe). This registry is
 * the metadata surface that `nuc gov policy` and external tooling
 * query to discover declared policy intent.
 * ------------------------------------------------------------------ */

#define NUC_GOV_MAX_POLICIES 64

typedef struct {
    char *name;
    char *severity; /* "warn" | "deny" — defaults "deny" */
} NucGovPolicy;

static NucGovPolicy _nuc_gov_policies[NUC_GOV_MAX_POLICIES];
static int _nuc_gov_policy_count = 0;

long long nuc_gov_register_policy(long long name_p, long long severity_p) {
    if (_nuc_gov_policy_count >= NUC_GOV_MAX_POLICIES) return -1;
    NucGovPolicy *p = &_nuc_gov_policies[_nuc_gov_policy_count];
    p->name     = _nuc_gov_strdup((const char *)name_p);
    p->severity = _nuc_gov_strdup((const char *)severity_p);
    _nuc_gov_policy_count++;
    return (long long)(_nuc_gov_policy_count - 1);
}

long long nuc_gov_policy_count(void) { return (long long)_nuc_gov_policy_count; }

long long nuc_gov_policy_name(long long idx) {
    if (idx < 0 || idx >= _nuc_gov_policy_count) return (long long)"";
    NucGovPolicy *p = &_nuc_gov_policies[(int)idx];
    return (long long)(p->name ? p->name : "");
}

long long nuc_gov_policy_severity(long long idx) {
    if (idx < 0 || idx >= _nuc_gov_policy_count) return (long long)"";
    NucGovPolicy *p = &_nuc_gov_policies[(int)idx];
    return (long long)(p->severity ? p->severity : "");
}

long long nuc_gov_policy_clear(void) {
    for (int i = 0; i < _nuc_gov_policy_count; i++) {
        free(_nuc_gov_policies[i].name);
        free(_nuc_gov_policies[i].severity);
        memset(&_nuc_gov_policies[i], 0, sizeof(NucGovPolicy));
    }
    _nuc_gov_policy_count = 0;
    return 0;
}

/* Lightweight source-substring check that mirrors the compiler-side
 * source_rule_check pass at the rod level. Adopters can call this to
 * pre-flight a source string against their declared policies before
 * shelling out to `nuc build`. Returns the number of violations found. */
long long nuc_gov_check_source(long long source_p) {
    const char *src = (const char *)source_p;
    if (!src) return 0;
    long long violations = 0;
    for (int i = 0; i < _nuc_gov_policy_count; i++) {
        const char *name = _nuc_gov_policies[i].name;
        if (!name) continue;
        if (strcmp(name, "no_unsafe") == 0) {
            if (strstr(src, "unsafe")) violations++;
        } else if (strcmp(name, "require_authored") == 0) {
            /* fn without a preceding @authored line counts as one violation */
            const char *cursor = src;
            while ((cursor = strstr(cursor, "fn ")) != NULL) {
                /* search backwards up to 256 chars for @authored */
                long long back = 0;
                int found = 0;
                while (back < 256 && (cursor - back) > src) {
                    if (strncmp(cursor - back, "@authored", 9) == 0) { found = 1; break; }
                    back++;
                }
                if (!found) violations++;
                cursor += 3;
            }
        } else if (strcmp(name, "no_extern") == 0) {
            if (strstr(src, "extern fn") || strstr(src, "extern \"")) violations++;
        }
    }
    return violations;
}
