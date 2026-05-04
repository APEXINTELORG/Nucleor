// v0.7.89 RFC-0050 Phase A smoke fixture — per-fn energy +
// thermal budget metadata registry.
//   - Declare 3 energy budgets (mJ / J / pJ scales)
//   - Declare 2 thermal budgets (one max-only, one range)
//   - Read back via the count + getter surface
//   - Validate unit names match
//   - Clear and confirm count drops to 0
import "stdlib/rods/energy_budget.nr"

fn main() -> i64 {
    energy_budget_clear();
    thermal_budget_clear();

    energy_budget_declare("pid_step", energy_unit_mJ(), 2);
    energy_budget_declare("filter_apply", energy_unit_J(), 1);
    energy_budget_declare("hot_inner", energy_unit_pJ(), 500);

    if energy_budget_count() != 3 { return 1; };

    let n0: str = energy_budget_get_name(0);
    if str_eq(n0, "pid_step") == 0 { return 2; };
    if energy_budget_get_unit(0) != energy_unit_mJ() { return 3; };
    if energy_budget_get_value(0) != 2 { return 4; };

    let u: i64 = energy_budget_get_unit(2);
    let un: str = energy_unit_name(u);
    if str_eq(un, "pJ") == 0 { return 5; };

    thermal_budget_declare("pid_step", thermal_unit_C(), 70);
    thermal_budget_declare_range("automotive", thermal_unit_C(), 85, 0 - 40);

    if thermal_budget_count() != 2 { return 6; };

    let tn0: str = thermal_budget_get_name(0);
    if str_eq(tn0, "pid_step") == 0 { return 7; };
    if thermal_budget_get_max(0) != 70 { return 8; };

    if thermal_budget_get_max(1) != 85 { return 9; };
    if thermal_budget_get_min(1) != 0 - 40 { return 10; };

    let tu: i64 = thermal_budget_get_unit(0);
    if str_eq(thermal_unit_name(tu), "C") == 0 { return 11; };

    energy_budget_clear();
    thermal_budget_clear();
    if energy_budget_count() != 0 { return 12; };
    if thermal_budget_count() != 0 { return 13; };

    return 0;
}
