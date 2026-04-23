// rods/transformer — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/transformer.nr"

fn main() -> i64 {
    let pe: i64 = tf_positional_encoding(8, 16);
    if pe == 0 { print("FAIL tf_positional_encoding"); return 1; };
    print("OK transformer_smoke");
    return 0;
}
