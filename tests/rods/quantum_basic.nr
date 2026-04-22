// quantum_basic.nr — fundamental quantum gates: H, X, CNOT
import "stdlib/rods/quantum.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    rng_seed(7);

    // X|0> -> |1> deterministically
    let sv1: i64 = qsim_init(1);
    qsim_x(sv1, 0);
    let m1: i64 = qsim_measure(sv1, 0);
    if m1 != 1 { print("FAIL quantum: X gate"); fail = fail + 1; };

    // XX|0> -> |0> deterministically
    let sv2: i64 = qsim_init(1);
    qsim_x(sv2, 0);
    qsim_x(sv2, 0);
    let m2: i64 = qsim_measure(sv2, 0);
    if m2 != 0 { print("FAIL quantum: XX = I"); fail = fail + 1; };

    // Bell state: H + CNOT entangles q0 and q1
    let mut bell_eq: i64 = 0;  // count outcomes where q0 == q1 (always true for Bell)
    let shots: i64 = 200;
    let mut s: i64 = 0;
    while s < shots {
        let sv: i64 = qsim_init(2);
        qsim_h(sv, 0);
        qsim_cnot(sv, 0, 1);
        let q0: i64 = qsim_measure(sv, 0);
        let q1: i64 = qsim_measure(sv, 1);
        if q0 == q1 { bell_eq = bell_eq + 1; };
        s = s + 1;
    };
    if bell_eq != shots { print("FAIL quantum: Bell entanglement broken"); fail = fail + 1; };

    if fail == 0 { print("OK quantum_basic"); return 0; };
    return 1;
}
