// rl_rt.c — Reinforcement Learning Infrastructure for Nucleor
// Replay buffer, discount returns, GAE, PPO loss, DQN target, epsilon-greedy.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/rl_rt.c -o target/rl_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _rl_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _rl_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } RLVec;

static RLVec *rlvec_new(int n) {
    RLVec *v = (RLVec *)malloc(sizeof(RLVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Replay Buffer
// ================================================================

typedef struct {
    int capacity;
    int state_dim;
    int pos;
    int size;
    double *states;       // [capacity, state_dim]
    long long *actions;   // [capacity]
    double *rewards;      // [capacity]
    double *next_states;  // [capacity, state_dim]
    int *dones;           // [capacity]
} ReplayBuffer;

long long nuc_rl_replay_new(long long capacity, long long state_dim) {
    int cap = (int)capacity, sd = (int)state_dim;
    ReplayBuffer *rb = (ReplayBuffer *)calloc(1, sizeof(ReplayBuffer));
    rb->capacity = cap;
    rb->state_dim = sd;
    rb->states = (double *)calloc(cap * sd, sizeof(double));
    rb->actions = (long long *)calloc(cap, sizeof(long long));
    rb->rewards = (double *)calloc(cap, sizeof(double));
    rb->next_states = (double *)calloc(cap * sd, sizeof(double));
    rb->dones = (int *)calloc(cap, sizeof(int));
    return (long long)rb;
}

void nuc_rl_replay_add(long long rbh, long long state_h, long long action,
                        long long reward_bits, long long next_state_h, long long done) {
    ReplayBuffer *rb = (ReplayBuffer *)(void *)rbh;
    RLVec *s = (RLVec *)(void *)state_h;
    RLVec *ns = (RLVec *)(void *)next_state_h;
    int idx = rb->pos % rb->capacity;

    for (int i = 0; i < rb->state_dim && i < s->len; i++)
        rb->states[idx * rb->state_dim + i] = _rl_i2f(s->data[i]);
    rb->actions[idx] = action;
    rb->rewards[idx] = _rl_i2f(reward_bits);
    for (int i = 0; i < rb->state_dim && i < ns->len; i++)
        rb->next_states[idx * rb->state_dim + i] = _rl_i2f(ns->data[i]);
    rb->dones[idx] = (int)done;

    rb->pos++;
    if (rb->size < rb->capacity) rb->size++;
}

// Sample batch: returns flat Vec with batch_size entries
// Layout: [states..., actions..., rewards..., next_states..., dones...]
long long nuc_rl_replay_sample(long long rbh, long long batch_size) {
    ReplayBuffer *rb = (ReplayBuffer *)(void *)rbh;
    int bs = (int)batch_size;
    if (bs > rb->size) bs = rb->size;
    int sd = rb->state_dim;

    unsigned int rng = (unsigned int)(rb->pos * 7919 + 42);
    int total = bs * (2 * sd + 3); // states + actions + rewards + next_states + dones
    RLVec *batch = rlvec_new(total);

    for (int b = 0; b < bs; b++) {
        rng = rng * 1103515245 + 12345;
        int idx = (int)(rng % rb->size);

        int off = b;
        for (int i = 0; i < sd; i++)
            batch->data[b * sd + i] = _rl_f2i(rb->states[idx * sd + i]);
        for (int i = 0; i < sd; i++)
            batch->data[bs * sd + b * sd + i] = _rl_f2i(rb->next_states[idx * sd + i]);
        batch->data[bs * sd * 2 + b] = rb->actions[idx];
        batch->data[bs * sd * 2 + bs + b] = _rl_f2i(rb->rewards[idx]);
        batch->data[bs * sd * 2 + bs * 2 + b] = (long long)rb->dones[idx];
    }
    return (long long)batch;
}

long long nuc_rl_replay_size(long long rbh) {
    return (long long)((ReplayBuffer *)(void *)rbh)->size;
}

// ================================================================
//  Discounted Returns
// ================================================================

long long nuc_rl_discount_returns(long long rewards_h, long long gamma_bits) {
    RLVec *rewards = (RLVec *)(void *)rewards_h;
    double gamma = _rl_i2f(gamma_bits);
    int n = rewards->len;

    RLVec *returns = rlvec_new(n);
    double running = 0;
    for (int i = n - 1; i >= 0; i--) {
        running = _rl_i2f(rewards->data[i]) + gamma * running;
        returns->data[i] = _rl_f2i(running);
    }
    return (long long)returns;
}

// ================================================================
//  Generalized Advantage Estimation (GAE)
// ================================================================

long long nuc_rl_gae(long long rewards_h, long long values_h,
                      long long gamma_bits, long long lambda_bits) {
    RLVec *rewards = (RLVec *)(void *)rewards_h;
    RLVec *values = (RLVec *)(void *)values_h;
    double gamma = _rl_i2f(gamma_bits);
    double lam = _rl_i2f(lambda_bits);
    int n = rewards->len;

    RLVec *advantages = rlvec_new(n);
    double gae = 0;
    for (int i = n - 1; i >= 0; i--) {
        double r = _rl_i2f(rewards->data[i]);
        double v = _rl_i2f(values->data[i]);
        double v_next = (i + 1 < n) ? _rl_i2f(values->data[i + 1]) : 0.0;
        double delta = r + gamma * v_next - v;
        gae = delta + gamma * lam * gae;
        advantages->data[i] = _rl_f2i(gae);
    }
    return (long long)advantages;
}

// ================================================================
//  PPO Clipped Loss
// ================================================================

long long nuc_rl_ppo_loss(long long log_probs_old_h, long long log_probs_new_h,
                           long long advantages_h, long long clip_bits) {
    RLVec *lpo = (RLVec *)(void *)log_probs_old_h;
    RLVec *lpn = (RLVec *)(void *)log_probs_new_h;
    RLVec *adv = (RLVec *)(void *)advantages_h;
    double clip = _rl_i2f(clip_bits);
    int n = lpo->len;

    double loss = 0;
    for (int i = 0; i < n; i++) {
        double ratio = exp(_rl_i2f(lpn->data[i]) - _rl_i2f(lpo->data[i]));
        double a = _rl_i2f(adv->data[i]);
        double clipped = ratio;
        if (clipped < 1 - clip) clipped = 1 - clip;
        if (clipped > 1 + clip) clipped = 1 + clip;
        double surr1 = ratio * a;
        double surr2 = clipped * a;
        loss += (surr1 < surr2) ? surr1 : surr2;
    }
    return _rl_f2i(-loss / n); // negative because we minimize
}

// ================================================================
//  DQN Target: r + gamma * max(Q_next) * (1 - done)
// ================================================================

long long nuc_rl_dqn_target(long long q_next_h, long long rewards_h,
                              long long gamma_bits, long long done_h) {
    RLVec *q_next = (RLVec *)(void *)q_next_h;
    RLVec *rewards = (RLVec *)(void *)rewards_h;
    RLVec *dones = (RLVec *)(void *)done_h;
    double gamma = _rl_i2f(gamma_bits);
    int n = rewards->len;

    RLVec *targets = rlvec_new(n);
    for (int i = 0; i < n; i++) {
        double max_q = _rl_i2f(q_next->data[i]); // assume pre-computed max
        double r = _rl_i2f(rewards->data[i]);
        double d = (double)dones->data[i];
        targets->data[i] = _rl_f2i(r + gamma * max_q * (1.0 - d));
    }
    return (long long)targets;
}

// ================================================================
//  Epsilon-Greedy Action Selection
// ================================================================

long long nuc_rl_epsilon_greedy(long long q_values_h, long long epsilon_bits) {
    RLVec *q = (RLVec *)(void *)q_values_h;
    double eps = _rl_i2f(epsilon_bits);
    int n = q->len;

    static unsigned int rl_rng = 77777;
    rl_rng = rl_rng * 1103515245 + 12345;
    double u = ((double)((rl_rng >> 16) & 0x7FFF)) / 32767.0;

    if (u < eps) {
        rl_rng = rl_rng * 1103515245 + 12345;
        return (long long)(rl_rng % n);
    }

    int best = 0;
    double best_q = _rl_i2f(q->data[0]);
    for (int i = 1; i < n; i++) {
        double qi = _rl_i2f(q->data[i]);
        if (qi > best_q) { best_q = qi; best = i; }
    }
    return (long long)best;
}

void nuc_rl_replay_free(long long rbh) {
    ReplayBuffer *rb = (ReplayBuffer *)(void *)rbh;
    if (!rb) return;
    free(rb->states); free(rb->actions); free(rb->rewards);
    free(rb->next_states); free(rb->dones); free(rb);
}
