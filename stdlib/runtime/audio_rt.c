// audio_rt.c — Audio Processing for Nucleor
// WAV read/write, STFT, ISTFT, mel filterbank, MFCC, resampling.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/audio_rt.c -o target/audio_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _au_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _au_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } AUVec;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  WAV File Format
// ================================================================

typedef struct {
    float *samples;
    int n_samples;
    int sample_rate;
    int channels;
} AudioClip;

long long nuc_audio_load_wav(const char *path) {
    if (!path) return 0;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;

    // Read WAV header
    char riff[4]; fread(riff, 1, 4, f);
    if (memcmp(riff, "RIFF", 4) != 0) { fclose(f); return 0; }

    unsigned int file_size; fread(&file_size, 4, 1, f);
    char wave[4]; fread(wave, 1, 4, f);
    if (memcmp(wave, "WAVE", 4) != 0) { fclose(f); return 0; }

    // Find fmt chunk
    short audio_fmt = 1, channels = 1, bits_per_sample = 16;
    int sample_rate = 44100;
    while (!feof(f)) {
        char chunk_id[4]; int chunk_size;
        if (fread(chunk_id, 1, 4, f) != 4) break;
        fread(&chunk_size, 4, 1, f);
        if (memcmp(chunk_id, "fmt ", 4) == 0) {
            fread(&audio_fmt, 2, 1, f);
            fread(&channels, 2, 1, f);
            fread(&sample_rate, 4, 1, f);
            fseek(f, chunk_size - 10, SEEK_CUR);
            // Read remaining fmt fields
            continue; // simplified
        }
        if (memcmp(chunk_id, "data", 4) == 0) {
            int n_samples = chunk_size / (channels * (bits_per_sample / 8));
            AudioClip *clip = (AudioClip *)malloc(sizeof(AudioClip));
            clip->n_samples = n_samples;
            clip->sample_rate = sample_rate;
            clip->channels = channels;
            clip->samples = (float *)malloc(n_samples * sizeof(float));

            for (int i = 0; i < n_samples; i++) {
                short sample = 0;
                fread(&sample, 2, 1, f);
                clip->samples[i] = sample / 32768.0f;
                if (channels > 1) fseek(f, (channels - 1) * 2, SEEK_CUR);
            }
            fclose(f);
            return (long long)clip;
        }
        fseek(f, chunk_size, SEEK_CUR);
    }
    fclose(f);
    return 0;
}

void nuc_audio_save_wav(long long h, const char *path) {
    AudioClip *clip = (AudioClip *)(void *)h;
    if (!clip || !path) return;
    FILE *f = fopen(path, "wb");
    if (!f) return;

    int data_size = clip->n_samples * 2;
    int file_size = 36 + data_size;
    fwrite("RIFF", 1, 4, f); fwrite(&file_size, 4, 1, f);
    fwrite("WAVE", 1, 4, f);
    fwrite("fmt ", 1, 4, f);
    int fmt_size = 16; fwrite(&fmt_size, 4, 1, f);
    short fmt = 1; fwrite(&fmt, 2, 1, f);
    short ch = 1; fwrite(&ch, 2, 1, f);
    fwrite(&clip->sample_rate, 4, 1, f);
    int byte_rate = clip->sample_rate * 2; fwrite(&byte_rate, 4, 1, f);
    short block_align = 2; fwrite(&block_align, 2, 1, f);
    short bps = 16; fwrite(&bps, 2, 1, f);
    fwrite("data", 1, 4, f); fwrite(&data_size, 4, 1, f);

    for (int i = 0; i < clip->n_samples; i++) {
        float s = clip->samples[i];
        if (s > 1.0f) s = 1.0f; if (s < -1.0f) s = -1.0f;
        short sample = (short)(s * 32767);
        fwrite(&sample, 2, 1, f);
    }
    fclose(f);
}

long long nuc_audio_sample_rate(long long h) { return ((AudioClip *)(void *)h)->sample_rate; }
long long nuc_audio_n_samples(long long h) { return ((AudioClip *)(void *)h)->n_samples; }

// Get samples as Vec<f64>
long long nuc_audio_samples(long long h) {
    AudioClip *clip = (AudioClip *)(void *)h;
    AUVec *v = (AUVec *)malloc(sizeof(AUVec));
    v->len = clip->n_samples; v->cap = clip->n_samples;
    v->data = (long long *)malloc(clip->n_samples * sizeof(long long));
    for (int i = 0; i < clip->n_samples; i++)
        v->data[i] = _au_f2i((double)clip->samples[i]);
    return (long long)v;
}

// ================================================================
//  STFT (Short-Time Fourier Transform)
//  Returns flat Vec<f64> [n_frames, window_size] of magnitudes
// ================================================================

long long nuc_audio_stft(long long samples_h, long long window_size, long long hop) {
    AUVec *samp = (AUVec *)(void *)samples_h;
    int ws = (int)window_size, hp = (int)hop;
    int n = samp->len;
    int n_frames = (n - ws) / hp + 1;
    int half = ws / 2 + 1;

    AUVec *result = (AUVec *)malloc(sizeof(AUVec));
    result->len = n_frames * half; result->cap = result->len;
    result->data = (long long *)malloc(result->len * sizeof(long long));

    double *window = (double *)malloc(ws * sizeof(double));
    for (int i = 0; i < ws; i++) window[i] = 0.5 * (1 - cos(2 * M_PI * i / (ws - 1))); // Hann

    double *re = (double *)malloc(ws * sizeof(double));
    double *im = (double *)malloc(ws * sizeof(double));

    for (int f = 0; f < n_frames; f++) {
        int offset = f * hp;
        // Apply window
        for (int i = 0; i < ws; i++) {
            re[i] = _au_i2f(samp->data[offset + i]) * window[i];
            im[i] = 0;
        }
        // DFT (for small windows; FFT would be better for large)
        for (int k = 0; k < half; k++) {
            double sumr = 0, sumi = 0;
            for (int j = 0; j < ws; j++) {
                double angle = -2 * M_PI * k * j / ws;
                sumr += re[j] * cos(angle);
                sumi += re[j] * sin(angle);
            }
            double mag = sqrt(sumr * sumr + sumi * sumi);
            result->data[f * half + k] = _au_f2i(mag);
        }
    }
    free(window); free(re); free(im);
    return (long long)result;
}

// ================================================================
//  MFCC (Mel-Frequency Cepstral Coefficients)
// ================================================================

static double hz_to_mel(double hz) { return 2595 * log10(1 + hz / 700); }
static double mel_to_hz(double mel) { return 700 * (pow(10, mel / 2595) - 1); }

long long nuc_audio_mfcc(long long samples_h, long long sr, long long n_mfcc) {
    AUVec *samp = (AUVec *)(void *)samples_h;
    int sample_rate = (int)sr, nm = (int)n_mfcc;
    int ws = 512, hop = 256;
    int n = samp->len;
    int n_frames = (n - ws) / hop + 1;
    if (n_frames < 1) return 0;
    int half = ws / 2 + 1;
    int n_mels = 26;

    // Compute STFT
    long long stft = nuc_audio_stft(samples_h, ws, hop);
    AUVec *spec = (AUVec *)(void *)stft;

    // Mel filterbank
    double mel_lo = hz_to_mel(0), mel_hi = hz_to_mel(sample_rate / 2.0);
    double *mel_pts = (double *)malloc((n_mels + 2) * sizeof(double));
    for (int i = 0; i < n_mels + 2; i++)
        mel_pts[i] = mel_to_hz(mel_lo + i * (mel_hi - mel_lo) / (n_mels + 1));

    // Apply mel filterbank + log + DCT
    AUVec *mfcc = (AUVec *)malloc(sizeof(AUVec));
    mfcc->len = n_frames * nm; mfcc->cap = mfcc->len;
    mfcc->data = (long long *)malloc(mfcc->len * sizeof(long long));

    for (int f = 0; f < n_frames; f++) {
        // Mel energies
        double *mel_e = (double *)calloc(n_mels, sizeof(double));
        for (int m = 0; m < n_mels; m++) {
            for (int k = 0; k < half; k++) {
                double freq = (double)k * sample_rate / ws;
                double lo = mel_pts[m], mid = mel_pts[m + 1], hi = mel_pts[m + 2];
                double w = 0;
                if (freq >= lo && freq <= mid) w = (freq - lo) / (mid - lo);
                else if (freq > mid && freq <= hi) w = (hi - freq) / (hi - mid);
                mel_e[m] += w * _au_i2f(spec->data[f * half + k]);
            }
            mel_e[m] = log(mel_e[m] + 1e-10);
        }

        // DCT-II for MFCC
        for (int c = 0; c < nm; c++) {
            double sum = 0;
            for (int m = 0; m < n_mels; m++)
                sum += mel_e[m] * cos(M_PI * c * (m + 0.5) / n_mels);
            mfcc->data[f * nm + c] = _au_f2i(sum);
        }
        free(mel_e);
    }
    free(mel_pts);
    return (long long)mfcc;
}

void nuc_audio_free(long long h) {
    AudioClip *clip = (AudioClip *)(void *)h;
    if (clip) { free(clip->samples); free(clip); }
}
