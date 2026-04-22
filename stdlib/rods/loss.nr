// rods/loss — Neural network loss functions
// Cross-entropy (+grad), label-smoothed CE, KL divergence, MSE, Huber,
// focal loss, InfoNCE, cosine similarity matrix.
#cfile "../runtime/loss_rt.c"

extern fn nuc_loss_cross_entropy(logits: i64, target: i64) -> i64;
extern fn nuc_loss_cross_entropy_grad(logits: i64, target: i64) -> i64;
extern fn nuc_loss_label_smooth_ce(logits: i64, target: i64, epsilon: i64) -> i64;
extern fn nuc_loss_kl_divergence(p: i64, q: i64) -> i64;
extern fn nuc_loss_mse(pred: i64, target: i64) -> i64;
extern fn nuc_loss_huber(pred: i64, target: i64, delta: i64) -> i64;
extern fn nuc_loss_focal(logits: i64, target: i64, alpha: i64, gamma: i64) -> i64;
extern fn nuc_loss_infonce(sim_matrix: i64, batch_size: i64, temperature: i64) -> i64;
extern fn nuc_loss_cosine_sim_matrix(a: i64, b: i64, n: i64, dim: i64) -> i64;

fn loss_ce(logits: i64, target: i64) -> i64 { return nuc_loss_cross_entropy(logits, target); }
fn loss_ce_grad(logits: i64, target: i64) -> i64 { return nuc_loss_cross_entropy_grad(logits, target); }
fn loss_smooth_ce(logits: i64, target: i64, eps: i64) -> i64 { return nuc_loss_label_smooth_ce(logits, target, eps); }
fn loss_kl(p: i64, q: i64) -> i64 { return nuc_loss_kl_divergence(p, q); }
fn loss_mse(pred: i64, target: i64) -> i64 { return nuc_loss_mse(pred, target); }
fn loss_huber(pred: i64, target: i64, delta: i64) -> i64 { return nuc_loss_huber(pred, target, delta); }
fn loss_focal(logits: i64, target: i64, alpha: i64, gamma: i64) -> i64 { return nuc_loss_focal(logits, target, alpha, gamma); }
fn loss_infonce(sim: i64, batch: i64, temp: i64) -> i64 { return nuc_loss_infonce(sim, batch, temp); }
fn loss_cosine_matrix(a: i64, b: i64, n: i64, dim: i64) -> i64 { return nuc_loss_cosine_sim_matrix(a, b, n, dim); }
