// t374_env_get_or.nr — v0.3.98 regression fixture.
//
// Pins the env_get_or runtime helper. Pre-v0.3.98, env_get_or
// wasn't registered as a callable runtime helper — Rust users
// reaching for the canonical `env::var(name).unwrap_or("default")`
// idiom hit clang link errors on `@env_get_or undefined`.
//
// Returns 7 = len of "default" when the env var isn't set.
// Verifies env_get_or returns the default fallback string.

fn main() -> i64 {
    let path: str = env_get_or("__NUCLEOR_TEST_NEVER_SET__", "default");
    return str_len(path);
}
