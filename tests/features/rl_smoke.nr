// v0.8.201 stdlib/rods/rl.nr first test coverage.
//
// Reinforcement learning primitives — replay buffer, GAE,
// PPO/DQN losses, epsilon-greedy. Pre-v0.8.201: zero coverage.
//
// Locks four lifecycle invariants on the replay-buffer surface
// and discounted-returns scalar math:
//
//   1. Replay-buffer empty: `rl_replay_size(rb) == 0` after
//      construction.
//   2. Replay-buffer add tracks size: 5 adds → size == 5.
//   3. Discount returns last == last reward: with rewards
//      [r0, r1, r2] and any γ, the LAST return is just r_T (no
//      future rewards to discount).
//   4. Discount returns of all-zeros == all-zeros.
//
// PPO/DQN/GAE need actual policy/value tensors which are
// out-of-scope for a smoke; tested in dedicated RL ships.
//
// Expected: rc=0.

import "stdlib/rods/rl.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_empty_replay() -> i64 {
    let rb: i64 = rl_replay_new(1000, 4);
    if rl_replay_size(rb) != 0 { rl_replay_free(rb); return 1; };
    rl_replay_free(rb);
    return 0;
}

fn check_replay_add_tracks_size() -> i64 {
    let rb: i64 = rl_replay_new(1000, 1);
    let mut state: Vec<i64> = Vec::new();
    state.push(f64_to_bits(0.5));
    let mut next: Vec<i64> = Vec::new();
    next.push(f64_to_bits(0.6));
    let mut i: i64 = 0;
    while i < 5 {
        rl_replay_add(rb, state, 0, f64_to_bits(1.0), next, 0);
        i = i + 1;
    };
    if rl_replay_size(rb) != 5 { rl_replay_free(rb); return 2; };
    rl_replay_free(rb);
    return 0;
}

fn check_discount_returns_last_eq_last_reward() -> i64 {
    let mut r: Vec<i64> = Vec::new();
    r.push(f64_to_bits(0.5));
    r.push(f64_to_bits(0.0 - 0.3));
    r.push(f64_to_bits(0.7));
    let g: i64 = rl_returns(r, f64_to_bits(0.99));
    let last: i64 = vec_get(g, 2);
    if close(last, f64_to_bits(0.7), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_discount_returns_all_zeros() -> i64 {
    let mut r: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 5 {
        r.push(f64_to_bits(0.0));
        i = i + 1;
    };
    let g: i64 = rl_returns(r, f64_to_bits(0.99));
    let mut j: i64 = 0;
    while j < 5 {
        if close(vec_get(g, j), f64_to_bits(0.0), 1e-9) != 1 { return 8; };
        j = j + 1;
    };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_replay();
    fails = fails + check_replay_add_tracks_size();
    fails = fails + check_discount_returns_last_eq_last_reward();
    fails = fails + check_discount_returns_all_zeros();
    return fails;
}
