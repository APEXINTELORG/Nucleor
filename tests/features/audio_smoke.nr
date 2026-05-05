// v0.8.132 stdlib/rods/audio.nr first test coverage.
//
// audio_new constructor + WAV save/load round-trip.
//
// Pre-v0.8.132: audio rod only had `audio_load(path)` for input.
// No way to synthesize an AudioClip without an existing WAV file
// on disk — blocks every adopter doing ML training input
// synthesis, test-tone generation, procedural audio.
//
// v0.8.132: `audio_new(samples, sample_rate)` constructs an
// AudioClip from a Vec<i64> of f64-bits samples in [-1.0, 1.0].
//
// Locks:
//   1. audio_new produces a valid handle (non-zero).
//   2. sample_rate + n_samples round-trip through accessors.
//   3. WAV save + load round-trip preserves sample_rate + n_samples
//      (16-bit PCM truncation is expected — sample values not
//      asserted byte-exact).
//
// Expected: rc=0.

import "stdlib/rods/audio.nr"
import "stdlib/rods/fs.nr"

fn check_audio_new() -> i64 {
    let mut samples: Vec<i64> = Vec::new();
    samples.push(f64_to_bits(0.0));
    samples.push(f64_to_bits(0.5));
    samples.push(f64_to_bits(0.0 - 0.5));
    samples.push(f64_to_bits(0.25));
    samples.push(f64_to_bits(0.0));
    let clip: i64 = audio_new(samples, 44100);
    if clip == 0 { return 1; };
    if audio_sample_rate(clip) != 44100 { audio_free(clip); return 2; };
    if audio_n_samples(clip) != 5 { audio_free(clip); return 4; };
    audio_free(clip);
    return 0;
}

fn check_wav_round_trip() -> i64 {
    let path: str = "target/_audio_smoke.wav";
    // Synthesize a short tone (8 samples, 8 kHz)
    let mut s: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 8 {
        s.push(f64_to_bits(0.1));
        i = i + 1;
    };
    let clip: i64 = audio_new(s, 8000);
    if clip == 0 { return 8; };
    audio_save(clip, path);
    audio_free(clip);

    if fs_exists(path) != 1 { return 16; };

    let loaded: i64 = audio_load(path);
    if loaded == 0 { fs_remove(path); return 32; };
    let sr: i64 = audio_sample_rate(loaded);
    let n: i64 = audio_n_samples(loaded);
    audio_free(loaded);
    fs_remove(path);
    if sr != 8000 { return 64; };
    if n != 8 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_audio_new();
    fails = fails + check_wav_round_trip();
    return fails;
}
