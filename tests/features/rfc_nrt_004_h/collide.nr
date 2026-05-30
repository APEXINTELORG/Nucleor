// §H spike harness. Imports two modules with identical fn names; both
// opt into module namespacing with distinct prefixes. main() calls each
// by its prefixed name. Expected output:
//   a_zero
//   b_zero
//   a_one
//   b_one
import "./mod_a.nr";
import "./mod_b.nr";

fn main() {
    print(mod_a_run(0));
    print(mod_b_run(0));
    print(mod_a_kind_to_str(1));
    print(mod_b_kind_to_str(1));
}
