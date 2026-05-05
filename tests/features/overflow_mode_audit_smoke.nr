// v0.8.173 RFC-0044 Phase B step-1 — per-BinOp OverflowMode
// audit (V1.13 drift restoration).
//
// Pre-v0.8.173: V2 carried `OverflowMode { Trap | Wrap |
// Saturate }` as a per-`BinOp` IR field; OSS retained only
// (potentially) the block form `wrapping{}` / `saturating{}` /
// `checked{}`. Phase B step-1 surfaces adopter usage of either
// form via build-time audit, matching the v0.8.143 fixed<I,F>
// pattern. Phase B step-2 (real per-BinOp lowering + inline-
// suffix `*#wrap` / `as#sat` lexer extension) is the ~150 LOC
// compiler ship.
//
// Fixture is intentionally non-exercising: it just keeps the
// build path green for the audit pass. Comment text mentioning
// `wrapping {` etc. counts as audit hits via text-scan (same
// known shape as the v0.8.5 @differentiable audit).
//
// Expected: rc=0; audit fires.

fn main() -> i64 {
    // The strings below intentionally appear in the source so
    // the audit pass picks them up. Adopter code that actually
    // uses `wrapping { x * y }` or `as#wrap` would surface the
    // same way.
    let _: str = "wrapping { ... } saturating { ... } checked { ... }";
    return 0;
}
