/* energy_budget_rt.c — RFC-0050 Phase A: process-local registry
 * for per-fn energy + thermal budget metadata.
 *
 * Adopters call energy_budget_declare()/thermal_budget_declare()
 * from fn bodies; external tooling (`nuc perf`, custom audit
 * scripts) reads back the registry to surface budget intent.
 *
 * No analysis happens here — Phase A is metadata-only per the
 * RFC's V2.5 advisory scope. Phase B parser-level attribute
 * support + call-graph energy estimator land separately. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_ENERGY_MAX_BUDGETS 256

typedef struct {
    char *fn_name;
    long long unit_id;
    long long value;
} NucEnergyBudget;

typedef struct {
    char *fn_name;
    long long unit_id;
    long long max_value;
    long long min_value;
} NucThermalBudget;

static NucEnergyBudget _nuc_energy_budgets[NUC_ENERGY_MAX_BUDGETS];
static int _nuc_energy_budget_count = 0;
static NucThermalBudget _nuc_thermal_budgets[NUC_ENERGY_MAX_BUDGETS];
static int _nuc_thermal_budget_count = 0;

static char *_nuc_energy_strdup(const char *s) {
    if (s == NULL) s = "";
    size_t n = strlen(s);
    char *p = (char *)malloc(n + 1);
    if (p == NULL) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

long long nuc_energy_budget_register(long long name_p, long long unit_id, long long value) {
    if (_nuc_energy_budget_count >= NUC_ENERGY_MAX_BUDGETS) return -1;
    NucEnergyBudget *b = &_nuc_energy_budgets[_nuc_energy_budget_count];
    b->fn_name = _nuc_energy_strdup((const char *)name_p);
    b->unit_id = unit_id;
    b->value   = value;
    _nuc_energy_budget_count++;
    return (long long)(_nuc_energy_budget_count - 1);
}

long long nuc_energy_budget_count(void) { return (long long)_nuc_energy_budget_count; }

long long nuc_energy_budget_name(long long idx) {
    if (idx < 0 || idx >= _nuc_energy_budget_count) return (long long)"";
    NucEnergyBudget *b = &_nuc_energy_budgets[(int)idx];
    return (long long)(b->fn_name ? b->fn_name : "");
}
long long nuc_energy_budget_unit(long long idx) {
    if (idx < 0 || idx >= _nuc_energy_budget_count) return 0;
    return _nuc_energy_budgets[(int)idx].unit_id;
}
long long nuc_energy_budget_value(long long idx) {
    if (idx < 0 || idx >= _nuc_energy_budget_count) return 0;
    return _nuc_energy_budgets[(int)idx].value;
}

long long nuc_energy_budget_clear(void) {
    for (int i = 0; i < _nuc_energy_budget_count; i++) {
        free(_nuc_energy_budgets[i].fn_name);
        memset(&_nuc_energy_budgets[i], 0, sizeof(NucEnergyBudget));
    }
    _nuc_energy_budget_count = 0;
    return 0;
}

long long nuc_thermal_budget_register(long long name_p, long long unit_id, long long max_value, long long min_value) {
    if (_nuc_thermal_budget_count >= NUC_ENERGY_MAX_BUDGETS) return -1;
    NucThermalBudget *b = &_nuc_thermal_budgets[_nuc_thermal_budget_count];
    b->fn_name   = _nuc_energy_strdup((const char *)name_p);
    b->unit_id   = unit_id;
    b->max_value = max_value;
    b->min_value = min_value;
    _nuc_thermal_budget_count++;
    return (long long)(_nuc_thermal_budget_count - 1);
}

long long nuc_thermal_budget_count(void) { return (long long)_nuc_thermal_budget_count; }

long long nuc_thermal_budget_name(long long idx) {
    if (idx < 0 || idx >= _nuc_thermal_budget_count) return (long long)"";
    NucThermalBudget *b = &_nuc_thermal_budgets[(int)idx];
    return (long long)(b->fn_name ? b->fn_name : "");
}
long long nuc_thermal_budget_unit(long long idx) {
    if (idx < 0 || idx >= _nuc_thermal_budget_count) return 0;
    return _nuc_thermal_budgets[(int)idx].unit_id;
}
long long nuc_thermal_budget_max(long long idx) {
    if (idx < 0 || idx >= _nuc_thermal_budget_count) return 0;
    return _nuc_thermal_budgets[(int)idx].max_value;
}
long long nuc_thermal_budget_min(long long idx) {
    if (idx < 0 || idx >= _nuc_thermal_budget_count) return 0;
    return _nuc_thermal_budgets[(int)idx].min_value;
}

long long nuc_thermal_budget_clear(void) {
    for (int i = 0; i < _nuc_thermal_budget_count; i++) {
        free(_nuc_thermal_budgets[i].fn_name);
        memset(&_nuc_thermal_budgets[i], 0, sizeof(NucThermalBudget));
    }
    _nuc_thermal_budget_count = 0;
    return 0;
}
