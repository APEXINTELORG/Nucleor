/* model_provenance_rt.c — RFC-0051 Phase A: process-local
 * registry for foundation-model provenance metadata.
 *
 * Adopters call model_provenance_register() from model-load
 * paths; external tooling (audit scripts, CI gates, `nuc evidence`
 * extensions) reads back the registry to surface provenance for
 * every model loaded in a process.
 *
 * No verification happens here — Phase A is metadata-only per
 * the RFC's V2.6 advisory scope. Phase B parser-level support
 * for string-literal generic params + type-checker enforcement
 * lands separately. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_MODEL_PROV_MAX 256

typedef struct {
    long long arch_id;
    char *weights_hash;
    char *dataset_lineage;
    char *license;
    char *safety_eval;
    long long quant_id;
} NucModelProv;

static NucModelProv _nuc_model_provs[NUC_MODEL_PROV_MAX];
static int _nuc_model_prov_count = 0;

static char *_nuc_mp_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

long long nuc_model_prov_register(long long arch_id, long long weights_hash_p,
                                   long long dataset_p, long long license_p,
                                   long long safety_eval_p, long long quant_id) {
    if (_nuc_model_prov_count >= NUC_MODEL_PROV_MAX) return -1;
    NucModelProv *m = &_nuc_model_provs[_nuc_model_prov_count];
    m->arch_id         = arch_id;
    m->weights_hash    = _nuc_mp_strdup((const char *)weights_hash_p);
    m->dataset_lineage = _nuc_mp_strdup((const char *)dataset_p);
    m->license         = _nuc_mp_strdup((const char *)license_p);
    m->safety_eval     = _nuc_mp_strdup((const char *)safety_eval_p);
    m->quant_id        = quant_id;
    _nuc_model_prov_count++;
    return (long long)(_nuc_model_prov_count - 1);
}

long long nuc_model_prov_count(void) { return (long long)_nuc_model_prov_count; }

long long nuc_model_prov_arch(long long idx) {
    if (idx < 0 || idx >= _nuc_model_prov_count) return 0;
    return _nuc_model_provs[(int)idx].arch_id;
}
long long nuc_model_prov_weights_hash(long long idx) {
    if (idx < 0 || idx >= _nuc_model_prov_count) return (long long)"";
    NucModelProv *m = &_nuc_model_provs[(int)idx];
    return (long long)(m->weights_hash ? m->weights_hash : "");
}
long long nuc_model_prov_dataset(long long idx) {
    if (idx < 0 || idx >= _nuc_model_prov_count) return (long long)"";
    NucModelProv *m = &_nuc_model_provs[(int)idx];
    return (long long)(m->dataset_lineage ? m->dataset_lineage : "");
}
long long nuc_model_prov_license(long long idx) {
    if (idx < 0 || idx >= _nuc_model_prov_count) return (long long)"";
    NucModelProv *m = &_nuc_model_provs[(int)idx];
    return (long long)(m->license ? m->license : "");
}
long long nuc_model_prov_safety_eval(long long idx) {
    if (idx < 0 || idx >= _nuc_model_prov_count) return (long long)"";
    NucModelProv *m = &_nuc_model_provs[(int)idx];
    return (long long)(m->safety_eval ? m->safety_eval : "");
}
long long nuc_model_prov_quant(long long idx) {
    if (idx < 0 || idx >= _nuc_model_prov_count) return 0;
    return _nuc_model_provs[(int)idx].quant_id;
}

long long nuc_model_prov_clear(void) {
    for (int i = 0; i < _nuc_model_prov_count; i++) {
        free(_nuc_model_provs[i].weights_hash);
        free(_nuc_model_provs[i].dataset_lineage);
        free(_nuc_model_provs[i].license);
        free(_nuc_model_provs[i].safety_eval);
        memset(&_nuc_model_provs[i], 0, sizeof(NucModelProv));
    }
    _nuc_model_prov_count = 0;
    return 0;
}
