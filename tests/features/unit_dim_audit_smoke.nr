// v0.8.146 RFC-0047 Phase B step-1 — typed-dim unit<T,[...]>
// audit (V2.2 frontier easy-win).
//
// Sister to RFC-0046 Pose<F> phantom-frame audit. Surfaces
// adopter usage of `unit<T, [a,b,c,d,e,f,g]>` and the SI
// dimension-alias shapes (`Mass<T>`, `Length<T>`, `Force<T>`,
// `Acceleration<T>`).
//
// Phase B step-2 (real dim-vector arithmetic in type-check —
// `m * g` adds dim vectors element-wise) is the ~400 LOC
// compiler ship.
//
// This fixture exercises Mass / Length / Acceleration / Force
// in let-position and verifies the audit pass counts them.
// Type-position only — no dim-arithmetic enforcement yet, so
// we just lock that the parse + audit + run cycle works.
//
// Expected: rc=0; audit fires with type-position count.

// Dimension aliases — would normally come from a stdlib units
// rod, but we declare them inline here so the fixture is
// self-contained and does not depend on a stdlib type-alias
// surface that may not yet ship.
struct Mass<T>         { value: T }
struct Length<T>       { value: T }
struct Acceleration<T> { value: T }
struct Force<T>        { value: T }

fn main() -> i64 {
    let m: Mass<f64>         = Mass<f64> { value: 5.0 };
    let g: Acceleration<f64> = Acceleration<f64> { value: 9.81 };
    let h: Length<f64>       = Length<f64> { value: 100.0 };
    let f: Force<f64>        = Force<f64> { value: 49.05 };
    let _ = m;
    let _ = g;
    let _ = h;
    let _ = f;
    return 0;
}
