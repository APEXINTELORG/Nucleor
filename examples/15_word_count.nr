// 15_word_count.nr - Word-frequency counter.
//
// Reads text from $NUC_TEXT_PATH if set, otherwise a bundled passage. Counts
// word frequencies in a HashMap, then prints the top entries sorted by count
// (using vec_sort_i64 over packed (count<<32 | hash) keys for a stable order).
//
// Demonstrates env vars, text tokenization, maps, sorting, and formatting.
//
// Build: nuc build examples/15_word_count.nr -o word_count
// Run:   ./word_count.exe
//        NUC_TEXT_PATH=README.md ./word_count.exe

fn read_text_source() -> str {
    if env_has("NUC_TEXT_PATH") == 1 {
        let path: str = env_get("NUC_TEXT_PATH");
        if str_len(path) > 0 {
            return file_read_string(path);
        };
    };
    // Bundled passage: deliberately repeats words to make the histogram
    // visible. ~50 tokens, ~25 unique.
    return "the quick brown fox jumps over the lazy dog\nthe dog barks at the fox\nthe fox runs from the dog\nthe quick fox is quicker than the dog\nNucleor compiles to LLVM and runs on Windows\nthe Nucleor compiler is fast and the runtime is small\n";
}

// Returns 1 if `c` is a word character (ASCII letter or digit).
fn is_word_char(c: i64) -> i64 {
    if c >= 97 && c <= 122 { return 1; };  // a-z
    if c >= 65 && c <= 90  { return 1; };  // A-Z
    if c >= 48 && c <= 57  { return 1; };  // 0-9
    return 0;
}

// Tokenize on any non-word-char (whitespace, punctuation, newlines).
// Returns a Vec<str> of lowercased words.
fn tokenize(text: str) -> Vec<str> {
    let out: Vec<str> = vec_new();
    let n: i64 = str_len(text);
    let mut i: i64 = 0;
    let mut start: i64 = -1;
    while i < n {
        let c: i64 = str_char_at(text, i);
        if is_word_char(c) == 1 {
            if start == -1 { start = i; };
        } else {
            if start != -1 {
                let word: str = str_to_lower(str_substring(text, start, i));
                vec_push(out, word);
                start = -1;
            };
        };
        i = i + 1;
    };
    if start != -1 {
        let word: str = str_to_lower(str_substring(text, start, n));
        vec_push(out, word);
    };
    return out;
}

fn main() -> i64 {
    print("=== Nucleor word-count demo ===");

    let raw: str = read_text_source();
    if str_len(raw) == 0 {
        print("ERROR: empty input");
        return 1;
    };

    let words: Vec<str> = tokenize(raw);
    let total_words: i64 = vec_len(words);

    // Count via hashmap_get_or to bump existing entries cleanly.
    let counts: i64 = hashmap_new();
    let mut i: i64 = 0;
    while i < total_words {
        let w: str = vec_get(words, i);
        let prev: i64 = hashmap_get_or(counts, w, 0);
        hashmap_insert(counts, w, prev + 1);
        i = i + 1;
    };

    let unique: i64 = hashmap_len(counts);
    print("");
    print(str_concat(str_concat("Total words:  ", int_to_str(total_words)), ""));
    print(str_concat(str_concat("Unique words: ", int_to_str(unique)), ""));
    print("");

    // Sort keys by (count, original_index) using a packed pair. The
    // original index is unique per key, so (count * N) + (N - 1 - i) gives
    // a unique sort key with the desired tiebreak (insertion order asc
    // when packed asc → desc-walk yields insertion order on ties).
    let keys: Vec<str> = hashmap_keys(counts);
    let n_keys: i64 = vec_len(keys);
    let packed: Vec<i64> = vec_new();
    let mut j: i64 = 0;
    while j < n_keys {
        let key: str = vec_get(keys, j);
        let count: i64 = hashmap_get(counts, key);
        let pack: i64 = (count * n_keys) + (n_keys - 1 - j);
        vec_push(packed, pack);
        j = j + 1;
    };
    vec_sort_i64(packed);

    print("Top words by frequency:");
    let pad: i64 = 18;
    print(str_concat(str_pad_right("word", pad, 32), str_pad_left("count", 10, 32)));
    print("----------------------------");
    let limit: i64 = 10;
    let mut shown: i64 = 0;
    let mut idx: i64 = vec_len(packed) - 1;
    while idx >= 0 && shown < limit {
        let pack: i64 = vec_get(packed, idx);
        let count: i64 = pack / n_keys;
        let key_idx: i64 = n_keys - 1 - (pack - (count * n_keys));
        let word: str = vec_get(keys, key_idx);
        print(str_concat(str_pad_right(word, pad, 32), str_pad_left(int_to_str(count), 10, 32)));
        shown = shown + 1;
        idx = idx - 1;
    };
    return 0;
}
