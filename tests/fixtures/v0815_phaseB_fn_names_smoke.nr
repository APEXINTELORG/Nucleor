// v0.8.15 Phase B step-3 smoke fixture — fn-name extraction
// for the remaining 6 attribute families. Build emits 6 audit
// pairs (count + fn names):
//   audit: @differentiable fns in build: 1
//   audit:   differentiable fns: loss
//   audit: @attested fns in build: 1
//   audit:   attested fns: handshake
//   audit: @hot fns in build: 1
//   audit:   hot fns: hot_path
//   audit: @const_fn fns in build: 1
//   audit:   const_fn fns: ct_eval
//   audit: #[max_depth] fns in build: 1
//   audit:   max_depth fns: bounded
//   audit: #[deadline] fns in build: 1
//   audit:   deadline fns: timed
// rc = 6.

@differentiable
fn loss() -> i64 { return 1; }

@attested(quote_required=true)
fn handshake() -> i64 { return 1; }

@hot
fn hot_path() -> i64 { return 1; }

@const_fn
fn ct_eval() -> i64 { return 1; }

#[max_depth = 8]
fn bounded() -> i64 { return 1; }

#[deadline = 1000]
fn timed() -> i64 { return 1; }

fn main() -> i64 {
    return loss() + handshake() + hot_path() + ct_eval() + bounded() + timed();
}
