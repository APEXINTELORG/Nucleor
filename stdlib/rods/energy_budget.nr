// rods/energy_budget — RFC-0050 Phase A: per-fn energy +
// thermal budget metadata registry.
//
// The RFC-0050 thesis: edge / embedded / battery-constrained
// programs need to declare per-fn energy + thermal budgets at
// compile time, both for documentation and for future static
// analysis (`nuc perf` flagging fns that can't meet the budget).
//
// The full RFC-0050 ship parses `@energy(max=2mJ)` and
// `@thermal(max_temp=70C)` attributes at lex time, stores them
// as fn metadata, and emits `__nucleor_meta_energy_<fn>` /
// `__nucleor_meta_thermal_<fn>` symbols (~150 LOC parser-side).
// Phase A (this rod) provides a runtime registry surface
// adopters can call from their fn bodies to declare budgets
// programmatically, ahead of the lex-time attribute syntax.
//
// Sister to RFC-0046 / RFC-0047 / RFC-0048 / RFC-0049 Phase A
// landings — same "stdlib first, compiler enforcement later"
// pattern.
//
// Workflow today:
//
//   import "stdlib/rods/energy_budget.nr"
//
//   fn pid_step(s: i64, m: i64) -> i64 {
//       energy_budget_declare("pid_step", energy_unit_mJ(), 2);
//       thermal_budget_declare("pid_step", thermal_unit_C(), 70);
//       // ... real fn body ...
//       return 0;
//   }
//
//   // External tooling (`nuc perf`, custom audit scripts) reads
//   // back the registered budgets:
//   let n: i64 = energy_budget_count();
//   let i: i64 = 0;
//   while i < n { print(energy_budget_get_name(i)); i = i + 1; };

#cfile "../runtime/energy_budget_rt.c"

extern fn nuc_energy_budget_register(name: str, unit_id: i64, value: i64) -> i64;
extern fn nuc_energy_budget_count() -> i64;
extern fn nuc_energy_budget_name(idx: i64) -> str;
extern fn nuc_energy_budget_unit(idx: i64) -> i64;
extern fn nuc_energy_budget_value(idx: i64) -> i64;
extern fn nuc_energy_budget_clear() -> i64;

extern fn nuc_thermal_budget_register(name: str, unit_id: i64, max_value: i64, min_value: i64) -> i64;
extern fn nuc_thermal_budget_count() -> i64;
extern fn nuc_thermal_budget_name(idx: i64) -> str;
extern fn nuc_thermal_budget_unit(idx: i64) -> i64;
extern fn nuc_thermal_budget_max(idx: i64) -> i64;
extern fn nuc_thermal_budget_min(idx: i64) -> i64;
extern fn nuc_thermal_budget_clear() -> i64;

// =====================================================
// Energy unit IDs (stable across rod versions).
// =====================================================
fn energy_unit_pJ() -> i64 { return 1; }   // picojoule (10^-12)
fn energy_unit_nJ() -> i64 { return 2; }   // nanojoule (10^-9)
fn energy_unit_uJ() -> i64 { return 3; }   // microjoule (10^-6)
fn energy_unit_mJ() -> i64 { return 4; }   // millijoule (10^-3)
fn energy_unit_J()  -> i64 { return 5; }   // joule (base)
fn energy_unit_kJ() -> i64 { return 6; }   // kilojoule (10^3)

fn energy_unit_name(id: i64) -> str {
    if id == 1 { return "pJ"; };
    if id == 2 { return "nJ"; };
    if id == 3 { return "uJ"; };
    if id == 4 { return "mJ"; };
    if id == 5 { return "J"; };
    if id == 6 { return "kJ"; };
    return "?J";
}

// =====================================================
// Thermal unit IDs.
// =====================================================
fn thermal_unit_K() -> i64 { return 10; }  // Kelvin (base)
fn thermal_unit_C() -> i64 { return 11; }  // Celsius
fn thermal_unit_F() -> i64 { return 12; }  // Fahrenheit

fn thermal_unit_name(id: i64) -> str {
    if id == 10 { return "K"; };
    if id == 11 { return "C"; };
    if id == 12 { return "F"; };
    return "?T";
}

// =====================================================
// Energy budget surface.
// =====================================================
fn energy_budget_declare(fn_name: str, unit_id: i64, value: i64) -> i64 {
    return nuc_energy_budget_register(fn_name, unit_id, value);
}
fn energy_budget_count() -> i64 { return nuc_energy_budget_count(); }
fn energy_budget_get_name(idx: i64) -> str { return nuc_energy_budget_name(idx); }
fn energy_budget_get_unit(idx: i64) -> i64 { return nuc_energy_budget_unit(idx); }
fn energy_budget_get_value(idx: i64) -> i64 { return nuc_energy_budget_value(idx); }
fn energy_budget_clear() -> i64 { return nuc_energy_budget_clear(); }

// =====================================================
// Thermal budget surface.
// =====================================================
fn thermal_budget_declare(fn_name: str, unit_id: i64, max_value: i64) -> i64 {
    return nuc_thermal_budget_register(fn_name, unit_id, max_value, 0 - 32768);
}
fn thermal_budget_declare_range(fn_name: str, unit_id: i64, max_value: i64, min_value: i64) -> i64 {
    return nuc_thermal_budget_register(fn_name, unit_id, max_value, min_value);
}
fn thermal_budget_count() -> i64 { return nuc_thermal_budget_count(); }
fn thermal_budget_get_name(idx: i64) -> str { return nuc_thermal_budget_name(idx); }
fn thermal_budget_get_unit(idx: i64) -> i64 { return nuc_thermal_budget_unit(idx); }
fn thermal_budget_get_max(idx: i64) -> i64 { return nuc_thermal_budget_max(idx); }
fn thermal_budget_get_min(idx: i64) -> i64 { return nuc_thermal_budget_min(idx); }
fn thermal_budget_clear() -> i64 { return nuc_thermal_budget_clear(); }
