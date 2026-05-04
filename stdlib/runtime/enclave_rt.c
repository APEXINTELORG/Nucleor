/* enclave_rt.c — RFC-0057 Phase A: process-local enclave-handle
 * registry + secret-wrap value table + declassify audit log.
 * Phase A is software-only; Phase B routes to per-vendor
 * attestation services (TDX / SEV-SNP / SecureEnclave / H100). */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_ENCLAVE_MAX 64
#define NUC_SECRET_MAX 1024
#define NUC_DECLASSIFY_LOG_MAX 256

typedef struct {
    long long engine_id;
    long long quote_id;
    int in_use;
} NucEnclave;

typedef struct {
    long long value;
    long long label;
    int in_use;
} NucSecret;

static NucEnclave _nuc_enclaves[NUC_ENCLAVE_MAX];
static int _nuc_enclave_count = 0;
static NucSecret _nuc_secrets[NUC_SECRET_MAX];
static int _nuc_secret_count = 0;
static char *_nuc_declassify_log[NUC_DECLASSIFY_LOG_MAX];
static int _nuc_declassify_log_count = 0;
static long long _nuc_quote_counter = 1;

static char *_nuc_enc_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

long long nuc_enclave_create(long long engine_id) {
    if (_nuc_enclave_count >= NUC_ENCLAVE_MAX) return -1;
    NucEnclave *e = &_nuc_enclaves[_nuc_enclave_count];
    e->engine_id = engine_id;
    e->quote_id = 0;
    e->in_use = 1;
    _nuc_enclave_count++;
    return (long long)(_nuc_enclave_count - 1);
}

long long nuc_enclave_close(long long handle) {
    if (handle < 0 || handle >= _nuc_enclave_count) return -1;
    _nuc_enclaves[handle].in_use = 0;
    return 0;
}

long long nuc_enclave_count(void) { return (long long)_nuc_enclave_count; }

long long nuc_enclave_engine(long long handle) {
    if (handle < 0 || handle >= _nuc_enclave_count) return 0;
    return _nuc_enclaves[handle].engine_id;
}

long long nuc_enclave_attest(long long handle) {
    if (handle < 0 || handle >= _nuc_enclave_count) return 0;
    if (!_nuc_enclaves[handle].in_use) return 0;
    long long q = _nuc_quote_counter++;
    _nuc_enclaves[handle].quote_id = q;
    return q;
}

long long nuc_enclave_verify_quote(long long quote_id, long long want_measurement) {
    /* Phase A: any non-zero quote ID verifies; Phase B routes
     * to per-vendor attestation parsers. The want_measurement
     * field is recorded but not actually checked yet. */
    (void)want_measurement;
    if (quote_id <= 0) return 0;
    return 1;
}

long long nuc_secret_wrap(long long value, long long label) {
    if (_nuc_secret_count >= NUC_SECRET_MAX) return -1;
    NucSecret *s = &_nuc_secrets[_nuc_secret_count];
    s->value = value;
    s->label = label;
    s->in_use = 1;
    _nuc_secret_count++;
    return (long long)(_nuc_secret_count - 1);
}

long long nuc_secret_label(long long handle) {
    if (handle < 0 || handle >= _nuc_secret_count) return 0;
    return _nuc_secrets[handle].label;
}

long long nuc_secret_unwrap_in_enclave(long long secret_h, long long enclave_h) {
    if (secret_h < 0 || secret_h >= _nuc_secret_count) return 0;
    if (enclave_h < 0 || enclave_h >= _nuc_enclave_count) return 0;
    if (!_nuc_secrets[secret_h].in_use) return 0;
    if (!_nuc_enclaves[enclave_h].in_use) return 0;
    return _nuc_secrets[secret_h].value;
}

long long nuc_secret_declassify(long long secret_h, long long justification_p) {
    if (secret_h < 0 || secret_h >= _nuc_secret_count) return 0;
    if (!_nuc_secrets[secret_h].in_use) return 0;
    /* Append-only audit log. */
    if (_nuc_declassify_log_count < NUC_DECLASSIFY_LOG_MAX) {
        _nuc_declassify_log[_nuc_declassify_log_count++] =
            _nuc_enc_strdup((const char *)justification_p);
    }
    return _nuc_secrets[secret_h].value;
}

long long nuc_secret_declassify_log_count(void) {
    return (long long)_nuc_declassify_log_count;
}

long long nuc_secret_declassify_log_get(long long idx) {
    if (idx < 0 || idx >= _nuc_declassify_log_count) return (long long)"";
    char *s = _nuc_declassify_log[(int)idx];
    return (long long)(s ? s : "");
}

long long nuc_secret_clear(void) {
    for (int i = 0; i < _nuc_secret_count; i++) {
        memset(&_nuc_secrets[i], 0, sizeof(NucSecret));
    }
    _nuc_secret_count = 0;
    for (int i = 0; i < _nuc_declassify_log_count; i++) {
        free(_nuc_declassify_log[i]);
        _nuc_declassify_log[i] = NULL;
    }
    _nuc_declassify_log_count = 0;
    return 0;
}
