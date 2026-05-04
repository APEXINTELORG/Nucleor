# RFC-0057 — Enclave Types `@enclave`, `@attested`, `Secret<T>` + Info-Flow Labels

**Status:** Draft (frontier — V2.12, language + rod split)
**Date:** 2026-05-03

## Motivation

Confidential computing (Intel TDX, AMD SEV-SNP, Apple Secure Enclave, NVIDIA H100 confidential GPU, Arm CCA) lets adopters run sensitive workloads with hardware-attested isolation: the OS / hypervisor / cloud operator can't see the data. The frontier writeup positions enclave types as a first-class language form — code in `@enclave(gpu0) { ... }` blocks is verified-isolated; data flowing through `Secret<T>` is verified-not-leaked.

Nucleor today has capability tokens (`SchedulerCap`/`RandomCap`/`FsCap`/`NetCap`) for permission gating, and a partial taint-as-analysis pass. This RFC promotes both to typed info-flow labels with hardware-enclave attestation hooks.

## Language-level surface

```nucleor
struct Secret<T> { value: T }      // can only be read inside @enclave or with declassify()
struct Public<T> { value: T }      // default, no restriction
struct Confidential<T> { value: T }
struct ExportControlled<T> { value: T, license: ExportLicense }

@enclave(tdx)
fn process_pii(input: Secret<UserData>) -> Secret<Insights> {
    // body sees Secret<UserData> as T directly (auto-unwrap inside enclave)
    // any output must also be Secret<...> — type-checker enforces non-leak
}

@attested(quote_required=true)
fn handshake() -> AttestationQuote { ... }

let raw: UserData = declassify(secret, justification="user_consent_v3");
// declassify is a sanctioned downgrade — logged + auditable
```

Key info-flow rules:
- `Secret<T>` cannot flow into `Public<T>` — type-check rejects with TYP-IFC-001.
- A `Secret<T>` value can only be unwrapped inside an `@enclave(...)` fn body OR via `declassify(s, justification=...)` (logged).
- `@enclave(<engine>)` fn bodies have automatic `Secret<T>` unwrap-on-read; outputs auto-wrap.
- `@attested` fns produce a hardware-signed attestation quote at call time.
- Mixing `Secret<T>` and `Public<U>` in the same expression promotes result to `Secret<R>` (taint-flow).

## Rod-level surface (`std.security` extensions)

- `enclave::create(engine: TDX | SEV_SNP | SecureEnclave | H100Confidential) -> EnclaveHandle`
- `enclave::attest(handle) -> AttestationQuote`
- `enclave::verify_quote(quote, expected_measurements) -> Result<(), AttestationFailure>`
- `secret::wrap(t: T) -> Secret<T>`
- `secret::declassify(s: Secret<T>, justification: str) -> T` (logged)
- `secret::zeroize(s: &mut Secret<T>)` (constant-time wipe)
- `constant_time::eq(a: &Secret<bytes>, b: &Secret<bytes>) -> bool`

## Implementation

V2.12 ship:
- **Parser:** `Secret<T>` / `Public<T>` / `Confidential<T>` / `ExportControlled<T>` as wrapper types. `@enclave(<engine>)` and `@attested` attributes.
- **Type-check:** info-flow propagation — Secret-tainted expressions promote result type. Cross-flow Secret→Public rejected with TYP-IFC-001.
- **Codegen:** at enclave-fn entry, emit `__nucleor_enclave_enter_<engine>`. At exit, `__nucleor_enclave_exit_<engine>`. Today STUB helpers (no real TDX/SEV/SecureEnclave hardware dispatch); adopters get the type-system safety without the hardware isolation until vendor backends ship.
- **Stdlib:** `enclave::*` + `secret::*` + `constant_time::*` ops.

## Cost

V2.12 ship: ~600 LOC compiler (info-flow type propagation + attribute parsing) + ~800 LOC stdlib (`std.security` extensions). NO hardware backend.

Hardware backends (TDX, SEV-SNP, SecureEnclave, H100 Confidential): future v2.x ships per vendor.

## Hot-path risk

None. Wrapper types are zero-cost.

## Frontier connection

Direct frontier writeup §3.2.7 "Confidential / enclave execution typed." Pairs with **RFC-0058 PQ crypto** (the attestation quote should use ML-DSA signatures going forward).

## Closure criteria

- `Secret<UserData>` and `UserData` are distinct types.
- `Secret<T> + Public<U>` produces `Secret<R>` (taint-flow).
- `declassify(s, justification=...)` works and logs the justification.
- Direct flow `Secret → Public` rejects with TYP-IFC-001.
- `@enclave(tdx)` fn body auto-unwraps Secret values for read.
- Round-2 self-host fixed-point holds.
