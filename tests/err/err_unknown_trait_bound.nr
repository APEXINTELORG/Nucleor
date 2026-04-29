// EXPECT: error[TYP-019] references unknown trait
// v0.4.130: trait-bound clauses now capture the bound trait name
// (parse_generic_params pushes `?<trait>` markers alongside the
// param name) and a verification pass walks every fn (kind 30) +
// looks up each `?<trait>` against the prog's trait declarations
// (kind 43). Pre-fix the bound was parse-skipped (v0.4.103) — a
// typo'd or forgotten-import trait name compiled clean and the
// codegen ignored bounds entirely. Closes audit doc-#1 §8 NAME
// verification (per-call-site impl-existence check is its own
// follow-on ship — needs sig storage to retain bounds + concrete
// T resolution from arg types).

fn add_values<T: NoSuchTrait>(a: T, b: T) -> T {
    a + b
}

fn main() -> i32 {
    print_int(add_values(10, 20));
    0
}
