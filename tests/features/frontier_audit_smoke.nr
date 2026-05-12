// v0.8.147-149 RFC-0048/49/51 Phase B step-1 — combined frontier
// easy-win audit fixture (V2.3 / V2.4 / V2.6).
//
// Three batched regression gate additions in a single ship cycle:
//
//   - V2.3 (RFC-0048): target.has()/target.os() compile-time
//     hardware capability queries.
//   - V2.4 (RFC-0049): MemSpace_* memory-pool type tags on
//     Tensor<T, Space>.
//   - V2.6 (RFC-0051): Model<Arch,...> foundation-model
//     provenance wrappers.
//
// All three are Phase B step-1 audit-only — Phase B step-2 (real
// compile-time DCE for target.has, real types_compatible for
// MemSpace + Model<...>) is the larger ship per each RFC.
//
// This fixture is a parse-only locking surface: declares marker
// structs + fields that exercise the audit needles. Every audit
// surface counts the occurrences and emits a one-line build
// summary.
//
// Expected: rc=0; build emits three audit lines.

struct MemSpace_HBM;
struct MemSpace_DDR;
struct MemSpace_CXL;

struct VLA;
struct LLM;

fn main() -> i64 {
    let h: MemSpace_HBM = MemSpace_HBM {};
    let d: MemSpace_DDR = MemSpace_DDR {};
    let c: MemSpace_CXL = MemSpace_CXL {};
    let _ = h;
    let _ = d;
    let _ = c;
    return 0;
}
