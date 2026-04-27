// t477_provenance_section.nr -- v0.4.5 RFC-NRT-001 regression pin.
// Asserts the binary builds; the verify gate Step then runs
// llvm-readobj to confirm the .nucprov section is present.
fn main() -> i64 {
    println!("provenance section present");
    return 0;
}
