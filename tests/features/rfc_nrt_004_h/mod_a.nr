// nucleor:module-namespace mod_a
// §H spike module A. The marker on line 1 opts this file into module
// namespacing with prefix `mod_a`. The §H resolver pass rewrites every
// top-level fn def and intra-file call site (except `main`) to
// mod_a_<name>. Importers reference fns by their prefixed name.

pub fn kind_to_str(k: i64) -> str {
    if k == 0 { return "a_zero"; };
    if k == 1 { return "a_one"; };
    return "a_other";
}

pub fn run(k: i64) -> str {
    // Intra-module call to kind_to_str. §H rewrites this to mod_a_kind_to_str.
    return kind_to_str(k);
}
