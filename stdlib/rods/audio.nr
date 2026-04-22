// rods/audio — WAV I/O + STFT + MFCC
#cfile "../runtime/audio_rt.c"

extern fn nuc_audio_load_wav(path: str) -> i64;
extern fn nuc_audio_save_wav(h: i64, path: str);
extern fn nuc_audio_sample_rate(h: i64) -> i64;
extern fn nuc_audio_n_samples(h: i64) -> i64;
extern fn nuc_audio_samples(h: i64) -> i64;
extern fn nuc_audio_stft(samples: i64, window: i64, hop: i64) -> i64;
extern fn nuc_audio_mfcc(samples: i64, sr: i64, n_mfcc: i64) -> i64;
extern fn nuc_audio_free(h: i64);

fn audio_load(path: str) -> i64 { return nuc_audio_load_wav(path); }
fn audio_save(h: i64, path: str) { nuc_audio_save_wav(h, path); }
fn audio_sample_rate(h: i64) -> i64 { return nuc_audio_sample_rate(h); }
fn audio_n_samples(h: i64) -> i64 { return nuc_audio_n_samples(h); }
fn audio_samples(h: i64) -> i64 { return nuc_audio_samples(h); }
fn audio_stft(s: i64, win: i64, hop: i64) -> i64 { return nuc_audio_stft(s, win, hop); }
fn audio_mfcc(s: i64, sr: i64, n: i64) -> i64 { return nuc_audio_mfcc(s, sr, n); }
fn audio_free(h: i64) { nuc_audio_free(h); }
