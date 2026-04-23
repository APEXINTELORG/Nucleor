// rods/tokenizer — Byte-Pair Encoding (BPE) and char-level tokenization
//
// `tok_bpe_train(text, vocab_size)` learns a BPE merges table from
// the corpus and returns a tokenizer handle. `tok_encode` produces an
// i64 vec of token ids. `tok_save` / `tok_load` persists the merges
// table to disk so training is one-shot per corpus.
//
// `tok_char_level` is the simplest path: one token per byte, no
// training required, useful for unit tests and tiny experiments.
//
// See `stdlib/runtime/tokenizer_rt.c`.
#cfile "../runtime/tokenizer_rt.c"

extern fn nuc_tok_bpe_train(text: str, target_vocab_size: i64) -> i64;
extern fn nuc_tok_encode(tok_h: i64, text: str) -> i64;
extern fn nuc_tok_vocab_size(tok_h: i64) -> i64;
extern fn nuc_tok_char_level(text: str) -> i64;
extern fn nuc_tok_save(tok_h: i64, path: str);
extern fn nuc_tok_load(path: str) -> i64;
extern fn nuc_tok_free(tok_h: i64);

fn tok_bpe_train(text: str, vocab: i64) -> i64 {
    return nuc_tok_bpe_train(text, vocab);
}
fn tok_encode(t: i64, text: str) -> i64 { return nuc_tok_encode(t, text); }
fn tok_vocab_size(t: i64) -> i64 { return nuc_tok_vocab_size(t); }
fn tok_char_level(text: str) -> i64 { return nuc_tok_char_level(text); }
fn tok_save(t: i64, path: str) { nuc_tok_save(t, path); }
fn tok_load(path: str) -> i64 { return nuc_tok_load(path); }
fn tok_free(t: i64) { nuc_tok_free(t); }
