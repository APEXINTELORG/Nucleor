// t440_tok_helper_int_literal_diag.nr -- v0.3.173 regression
// fixture (positive: build succeeds with WARNING).
//
// Pre-v0.3.173, tok_encode(42, "hello") (and similar mistakes
// for other tok_* / nuc_tok_* helpers) compiled cleanly and
// SIGSEGV'd at runtime when the helper dereferenced 42 as a
// tokenizer handle.
//
// Same hazard class as v0.3.170 (vec_*) and v0.3.171
// (hashmap/hashset/btreemap/btreeset/vecdeque). ML adopters
// use these heavily (per ML suite feedback).
//
// Fix (v0.3.173): explicit literal-only WARNING for the
// tokenizer helper family at the type-check site. Variables
// (which legitimately hold tokenizer handles via the
// i64-everywhere ABI) are NOT flagged.

fn main() -> i64 {
    return 42;
}
