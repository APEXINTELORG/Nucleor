// rods/tokenizer — verify rod wrapper compiles + links (v0.2.150 wrap)
// Note: `tok_char_level` returns a TKVec of token IDs (not a
// BPETokenizer), so we don't `tok_free` it — that helper is for
// BPE handles only.
import "stdlib/rods/tokenizer.nr"

fn main() -> i64 {
    let ids: i64 = tok_char_level("hello");
    if ids == 0 { print("FAIL tok_char_level"); return 1; };
    print("OK tokenizer_smoke");
    return 0;
}
