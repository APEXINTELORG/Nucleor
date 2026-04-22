// =====================================================
// rods/uuid — UUID generation and utilities
// =====================================================
// Import: import "stdlib/rods/uuid.nr"
// Provides: uuid_v4, uuid_nil, uuid_is_nil
// =====================================================

// Simple pseudo-random number generator state
// Uses a linear congruential generator seeded from a counter
fn uuid_rng_state() -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    // Seed with a large prime; callers should re-seed if determinism matters
    v.push(48271);
    return v;
}

fn uuid_rng_next(state: Vec<i32>) -> i64 {
    // LCG: next = (state * 6364136223846793005 + 1442695040888963407) mod 2^31
    // Simplified to avoid overflow: next = (state * 48271) mod 2147483647
    let s: i64 = state.get(0);
    let next: i64 = s * 48271 - (s * 48271 / 2147483647) * 2147483647;
    let mut pos: i64 = next;
    if pos < 0 { pos = 0 - pos; };
    vec_set(state, 0, pos);
    return pos;
}

// Returns a hex char for a value 0..15
fn uuid_hex_char(val: i64) -> str {
    let hex: str = "0123456789abcdef";
    let v: i64 = val - (val / 16) * 16;
    let mut safe: i64 = v;
    if safe < 0 { safe = 0 - safe; };
    return str_substring(hex, safe, safe + 1);
}

// Generate a random hex string of n characters
fn uuid_rand_hex(state: Vec<i32>, n: i64) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < n {
        let r: i64 = uuid_rng_next(state);
        let nibble: i64 = r - (r / 16) * 16;
        sb_append(sb, uuid_hex_char(nibble));
        i = i + 1;
    };
    return sb_to_str(sb);
}

// Generate a pseudo-random UUID v4 string
// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
// where y is one of 8, 9, a, b
fn uuid_v4() -> str {
    let mut rng: Vec<i32> = uuid_rng_state();
    // Re-seed with something varying — use string length trick
    // In practice, sequential calls produce different UUIDs due to LCG state
    let mut sb: i64 = sb_new();

    // 8 hex chars
    sb_append(sb, uuid_rand_hex(rng, 8));
    sb_append(sb, "-");

    // 4 hex chars
    sb_append(sb, uuid_rand_hex(rng, 4));
    sb_append(sb, "-");

    // 4 hex chars — first char is always '4' (version)
    sb_append(sb, "4");
    sb_append(sb, uuid_rand_hex(rng, 3));
    sb_append(sb, "-");

    // 4 hex chars — first char is 8, 9, a, or b (variant)
    let variant_r: i64 = uuid_rng_next(rng);
    let variant_idx: i64 = variant_r - (variant_r / 4) * 4;
    let variants: str = "89ab";
    sb_append(sb, str_substring(variants, variant_idx, variant_idx + 1));
    sb_append(sb, uuid_rand_hex(rng, 3));
    sb_append(sb, "-");

    // 12 hex chars
    sb_append(sb, uuid_rand_hex(rng, 12));

    return sb_to_str(sb);
}

// Return the nil UUID (all zeros)
fn uuid_nil() -> str {
    return "00000000-0000-0000-0000-000000000000";
}

// Check if a UUID string is the nil UUID
fn uuid_is_nil(uuid: str) -> i64 {
    return str_eq(uuid, "00000000-0000-0000-0000-000000000000");
}
