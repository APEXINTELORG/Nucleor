# Nucleor Design Notes

This directory contains design notes for major language, runtime, tooling, and
standard-library surfaces. They are useful for implementation context, but the
current user-facing contract lives in:

- [Language reference](../language-reference.md)
- [Feature inventory](../NUCLEOR_FEATURE_INVENTORY.md)
- [Error codes](../spec/Nucleor_Error_Codes.md)
- [Getting started](../getting-started.md)

When a design note and the language reference disagree, the language reference
wins for the public release.

## Index

### Runtime, Safety, And Real-Time

- [RFC-0001: Real-time attributes](RFC-0001-rt-attributes.md)
- [RFC-0002: Allocator types](RFC-0002-allocator-types.md)
- [RFC-0003: Typed coordinate frames](RFC-0003-typed-frames.md)
- [RFC-0004: `#[assume]`](RFC-0004-assume.md)
- [RFC-0005: Typed units](RFC-0005-units.md)
- [RFC-0006: Design by contract](RFC-0006-design-by-contract.md)
- [RFC-0007: Atomic and lock-free constraints](RFC-0007-atomic.md)
- [RFC-0008: Interrupt service routines](RFC-0008-isr.md)
- [RFC-0009: WCET analysis](RFC-0009-heptane-wcet.md)
- [RFC-0035: Sendable and actors](RFC-0035-sendable-actors.md)
- [RFC-0042: Auto-drop](RFC-0042-auto-drop.md)
- [RFC-0056: Deterministic replay](RFC-0056-deterministic-replay.md)
- [RFC-0057: Enclave types](RFC-0057-enclave-types.md)

### Language And Tooling

- [RFC-0015: Numeric types](RFC-0015-numeric-types.md)
- [RFC-0016: Result, Option, match, and `?`](RFC-0016-result-option-match.md)
- [RFC-0017: Collections](RFC-0017-collections.md)
- [RFC-0018: Modules](RFC-0018-modules.md)
- [RFC-0019: Package manager](RFC-0019-package-manager.md)
- [RFC-0020: Diagnostics](RFC-0020-diagnostics.md)
- [RFC-0021: Test framework](RFC-0021-test-framework.md)
- [RFC-0022: Cross-platform support](RFC-0022-cross-platform.md)
- [RFC-0023: Pattern matching](RFC-0023-pattern-matching.md)
- [RFC-0024: Iterators](RFC-0024-iterators.md)
- [RFC-0025: Closures](RFC-0025-closures.md)
- [RFC-0026: Trait objects](RFC-0026-trait-objects.md)
- [RFC-0027: Lifetimes](RFC-0027-lifetimes.md)
- [RFC-0028: Format strings](RFC-0028-format-strings.md)
- [RFC-0029: Documentation generator](RFC-0029-doc-generator.md)
- [RFC-0030: Async decision](RFC-0030-async-decision.md)
- [RFC-0031: Algebraic laws](RFC-0031-algebraic-laws.md)
- [RFC-0032: Effects](RFC-0032-effects.md)
- [RFC-0033: Effects in function types](RFC-0033-effects-in-function-types.md)
- [RFC-0034: Compile-time parameters](RFC-0034-compile-time-parameters.md)

### Interop, Hardware, And Frontier Surfaces

- [RFC-0010: DLPack](RFC-0010-dlpack.md)
- [RFC-0011: C++ interop](RFC-0011-nuc-cxx.md)
- [RFC-0012: C/C++ binding generator](RFC-0012-nuc-bindgen.md)
- [RFC-0013: URDF static frames](RFC-0013-urdf-static-frames.md)
- [RFC-0014: Maximum recursion depth](RFC-0014-max-depth.md)
- [RFC-0043: Fixed-point IR type](RFC-0043-fixed-point-IR-type.md)
- [RFC-0044: Per-binop overflow mode](RFC-0044-per-binop-overflow-mode.md)
- [RFC-0045: Differentiable attribute](RFC-0045-differentiable-attribute.md)
- [RFC-0046: Coordinate-frame types](RFC-0046-coordinate-frame-types.md)
- [RFC-0047: Seven-vector typed units](RFC-0047-typed-units-7vector.md)
- [RFC-0048: Hardware capability queries](RFC-0048-hardware-capability-queries.md)
- [RFC-0049: Memory-space type tags](RFC-0049-memory-space-type-tags.md)
- [RFC-0050: Energy and thermal attributes](RFC-0050-energy-thermal-attributes.md)
- [RFC-0051: Model provenance type](RFC-0051-model-provenance-type.md)
- [RFC-0052: Photonic compute types](RFC-0052-photonic-types.md)
- [RFC-0053: Neuromorphic compute types](RFC-0053-neuromorphic-types.md)
- [RFC-0054: Logical qubit type](RFC-0054-logical-qubit-type.md)
- [RFC-0055: Distributed collectives](RFC-0055-distributed-collectives.md)
- [RFC-0058: Post-quantum crypto stdlib](RFC-0058-pq-crypto-stdlib.md)
- [RFC-0059: Multi-level IR sketch](RFC-0059-multi-level-IR-sketch.md)
- [RFC-0062: Effects extension](RFC-0062-effects-extension.md)

### Generated Catalogs

- [Helper manifest schema](helper_manifest_schema.md)
- [Helper manifest](helper_manifest.toml)
- [Rod manifest schema](rod_manifest_schema.md)
- [Rod manifest](rod_manifest.toml)
