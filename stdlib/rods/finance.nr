// =====================================================
// rods/finance — Financial Mathematics
// =====================================================
// Import: import "stdlib/rods/finance.nr"
// Provides: Black-Scholes option pricing, full Greeks (Δ Γ Θ ν ρ),
//   implied volatility, NPV, IRR, value-at-risk, mean-variance
//   portfolio optimization.
//
// `type` argument: 0 = call, 1 = put.
// =====================================================

#cfile "../runtime/finance_rt.c"

extern fn nuc_fin_black_scholes(S: i64, K: i64, T: i64, r: i64, sigma: i64, kind: i64) -> i64;
extern fn nuc_fin_greeks(S: i64, K: i64, T: i64, r: i64, sigma: i64) -> i64;
extern fn nuc_fin_greeks_delta(h: i64) -> i64;
extern fn nuc_fin_greeks_gamma(h: i64) -> i64;
extern fn nuc_fin_greeks_theta(h: i64) -> i64;
extern fn nuc_fin_greeks_vega(h: i64) -> i64;
extern fn nuc_fin_greeks_rho(h: i64) -> i64;
extern fn nuc_fin_implied_vol(price: i64, S: i64, K: i64, T: i64, r: i64, kind: i64) -> i64;
extern fn nuc_fin_npv(cash_flows: i64, rate: i64) -> i64;
extern fn nuc_fin_irr(cash_flows: i64) -> i64;
extern fn nuc_fin_var(returns: i64, confidence: i64) -> i64;
extern fn nuc_fin_portfolio_opt(returns: i64, cov: i64, target_ret: i64, n_assets: i64) -> i64;

fn fin_black_scholes(S: i64, K: i64, T: i64, r: i64, sigma: i64, kind: i64) -> i64 {
    return nuc_fin_black_scholes(S, K, T, r, sigma, kind);
}
fn fin_greeks(S: i64, K: i64, T: i64, r: i64, sigma: i64) -> i64 { return nuc_fin_greeks(S, K, T, r, sigma); }
fn fin_greek_delta(h: i64) -> i64 { return nuc_fin_greeks_delta(h); }
fn fin_greek_gamma(h: i64) -> i64 { return nuc_fin_greeks_gamma(h); }
fn fin_greek_theta(h: i64) -> i64 { return nuc_fin_greeks_theta(h); }
fn fin_greek_vega(h: i64) -> i64 { return nuc_fin_greeks_vega(h); }
fn fin_greek_rho(h: i64) -> i64 { return nuc_fin_greeks_rho(h); }
fn fin_implied_vol(price: i64, S: i64, K: i64, T: i64, r: i64, kind: i64) -> i64 {
    return nuc_fin_implied_vol(price, S, K, T, r, kind);
}
fn fin_npv(cash_flows: i64, rate: i64) -> i64 { return nuc_fin_npv(cash_flows, rate); }
fn fin_irr(cash_flows: i64) -> i64 { return nuc_fin_irr(cash_flows); }
fn fin_var(returns: i64, confidence: i64) -> i64 { return nuc_fin_var(returns, confidence); }
fn fin_portfolio_opt(returns: i64, cov: i64, target_ret: i64, n_assets: i64) -> i64 {
    return nuc_fin_portfolio_opt(returns, cov, target_ret, n_assets);
}
