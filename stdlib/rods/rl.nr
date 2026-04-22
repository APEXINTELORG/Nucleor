// rods/rl — Reinforcement learning primitives
// Replay buffer, GAE, PPO/DQN losses, epsilon-greedy.
#cfile "../runtime/rl_rt.c"

extern fn nuc_rl_replay_new(capacity: i64, state_dim: i64) -> i64;
extern fn nuc_rl_replay_add(rb: i64, state: i64, action: i64, reward: i64, next_state: i64, done: i64);
extern fn nuc_rl_replay_sample(rb: i64, batch_size: i64) -> i64;
extern fn nuc_rl_replay_size(rb: i64) -> i64;
extern fn nuc_rl_discount_returns(rewards: i64, gamma: i64) -> i64;
extern fn nuc_rl_gae(rewards: i64, values: i64, gamma: i64, lambda: i64) -> i64;
extern fn nuc_rl_ppo_loss(log_old: i64, log_new: i64, advantages: i64, clip: i64) -> i64;
extern fn nuc_rl_dqn_target(q_next: i64, rewards: i64, gamma: i64, done: i64) -> i64;
extern fn nuc_rl_epsilon_greedy(q_values: i64, epsilon: i64) -> i64;
extern fn nuc_rl_replay_free(rb: i64);

fn rl_replay_new(cap: i64, state_dim: i64) -> i64 { return nuc_rl_replay_new(cap, state_dim); }
fn rl_replay_add(rb: i64, s: i64, a: i64, r: i64, ns: i64, d: i64) { nuc_rl_replay_add(rb, s, a, r, ns, d); }
fn rl_replay_sample(rb: i64, batch: i64) -> i64 { return nuc_rl_replay_sample(rb, batch); }
fn rl_replay_size(rb: i64) -> i64 { return nuc_rl_replay_size(rb); }
fn rl_returns(r: i64, gamma: i64) -> i64 { return nuc_rl_discount_returns(r, gamma); }
fn rl_gae(r: i64, v: i64, gamma: i64, lambda: i64) -> i64 { return nuc_rl_gae(r, v, gamma, lambda); }
fn rl_ppo_loss(old_lp: i64, new_lp: i64, adv: i64, clip: i64) -> i64 { return nuc_rl_ppo_loss(old_lp, new_lp, adv, clip); }
fn rl_dqn_target(q: i64, r: i64, gamma: i64, d: i64) -> i64 { return nuc_rl_dqn_target(q, r, gamma, d); }
fn rl_epsilon_greedy(q: i64, eps: i64) -> i64 { return nuc_rl_epsilon_greedy(q, eps); }
fn rl_replay_free(rb: i64) { nuc_rl_replay_free(rb); }
