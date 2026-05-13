# Safety

Nucleor includes language features, runtime rods, examples, and native runtime
helpers that can be used in robotics, control, real-time-style checks,
simulation, and hardware integration. This repository does not provide a
certified safety system.

## Certification Boundary

- Nucleor is not certified under functional-safety, medical, aviation,
  automotive, industrial-control, or robotics safety standards.
- No compiler diagnostic, attribute, standard-library rod, runtime helper,
  example, or release artifact is a safety certification, risk assessment, or
  regulatory approval.
- The Apache License warranty and liability terms apply. See [LICENSE](LICENSE).

## Robotics And Physical Systems

Do not use Nucleor as the sole safety mechanism for any robot, vehicle,
actuator, medical device, aircraft, industrial machine, or other system where
software failure could cause injury, property damage, or environmental harm.

Before connecting Nucleor-generated software to physical hardware, users are
responsible for appropriate engineering controls, including:

- Hazard analysis and risk assessment for the intended system and operating
  environment.
- Simulation, offline replay, bench testing, staged hardware bring-up, and
  target-hardware validation.
- Emergency stop, power isolation, physical guarding, actuator limits, watchdogs,
  manual override, and independent safety interlocks where appropriate.
- Compliance review for applicable laws, standards, site rules, and industry
  requirements.

## Real-Time And Determinism

Nucleor's real-time attributes and diagnostics are engineering checks, not
complete proof of hard real-time safety:

- `#[no_alloc]`, `#[no_panic]`, `#[isr]`, and `#[deadline]` can catch important
  classes of mistakes, but they are not complete compile-time guarantees.
- RT-004 is a heuristic deadline estimate, not certified worst-case execution
  time analysis.
- Hard real-time deployments need target-specific timing measurement, external
  WCET or schedulability analysis where required, and validation on the exact
  hardware, compiler, operating system, and build profile used in production.

## Standard Library Surfaces

Several standard-library rods expose queryable limitation strings, such as
`chomp_limitations()`, `topp_limitations()`, `thread_limitations()`,
`qsim_limitations()`, and related subsystem-specific helpers. Treat those
limitations as part of the public contract for the current release.

Simulation, planning, optimization, quantum, ML, and control rods may be useful
building blocks, but they do not replace system-level validation, independent
safety controls, or domain-specific certification work.

## Untrusted Code

Nucleor does not currently sandbox compilation or execution. Treat untrusted
Nucleor source and generated binaries with the same care as native code. Report
security vulnerabilities through [SECURITY.md](SECURITY.md).

## Release Artifacts

For release packages, verify checksums and Authenticode signatures when
available. Unsigned Windows release candidates must be treated as
signing-pending artifacts, not final signed trust artifacts.

This document is safety guidance for users and integrators. It is not legal,
regulatory, certification, or engineering approval for any specific deployment.
