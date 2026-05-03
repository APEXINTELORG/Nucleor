# RFC-0008 — `#[isr]` Interrupt Service Routine Attribute

| Field | Value |
|---|---|
| **Number** | 0008 |
| **Title** | `#[isr]` — interrupt service routine attribute for embedded targets |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.6.0 ("Embedded + AI Inference") |
| **Depends on** | RFC-0001 (RT attributes), RFC-0007 (atomic) |

---

## 1. Summary

Add `#[isr(vector = "TIM2", priority = 3)]` attribute that:
- Implies `#[no_alloc, no_panic, no_dyn]` plus a strict
  no-blocking-call rule (RFC-0007's `#[atomic]`)
- Generates target-specific interrupt-vector wiring (Cortex-M
  vector table entry, RISC-V trap handler, etc.)
- Enforces "no call to non-`#[isr_safe]` function"
- Enables target-specific calling conventions (e.g., the `interrupt`
  attribute on ARM)

```nucleor
use mcu::stm32f4 as mcu;

#[isr(vector = mcu::Vector::TIM2)]
fn timer_overflow() {
    let count = TICK_COUNT.fetch_add(1, Ordering::Relaxed);
    mcu::tim2().clear_pending();
}

#[isr(vector = mcu::Vector::USART1, priority = 4)]
fn uart_rx() {
    let byte = mcu::usart1().read();
    let _ = RX_QUEUE.try_push(byte);   // SpscQueue
}
```

This is the **embedded extension** of the RT-attribute family.
Together with v0.6's `--profile=embedded`, lets Nucleor target Cortex-M
and RISC-V MCUs with first-class compiler support.

---

## 2. Motivation

Every embedded developer writes interrupt handlers. In C, this is
attribute-tagged on the compiler (`__attribute__((interrupt))`) and
the linker manually populates the vector table. In Rust embedded,
the `cortex-m-rt` crate provides macros.

Nucleor v0.6 wants to be a credible embedded language. ISR support
is mandatory.

Prior art:
- **C** — `__attribute__((interrupt))` (GCC), `__interrupt` (IAR/Keil)
- **Rust embedded** — `#[interrupt]` macro from `cortex-m-rt`/PAC
  crates
- **Ada/SPARK** — `pragma Interrupt_Handler`, `pragma Attach_Handler`
- **Zig** — `callconv(.Interrupt)` in fn signature

Nucleor models on Rust embedded — proven design.

---

## 3. Design

### 3.0 v0.6 first-pass surface

The v0.6 compiler spike freezes the smallest useful, host-safe ISR
substrate before full embedded sysroots land:

- `#[isr]` and `#[isr(...)]` are recovered by the existing
  source-level attribute scanner.
- ISR functions must have no params and no return value
  (`fn() -> void` surface; no explicit return value in current
  source syntax). Violations emit `ISR-001`.
- `#[isr]` inherits `#[no_alloc]` and `#[no_panic]` diagnostics.
- `#[isr]` rejects deadline-wrapper composition with `ISR-002`.
- The compiler keeps ISR roots alive during DCE and emits a stable
  LLVM IR marker comment: `; nucleor.isr target=<target> fn @name
  interrupt_cc`. Full vector-table and target ABI lowering remain
  the follow-on embedded sysroot work.
- First-pass targets are `cortex-m4f` and `rv32imac`, selected with
  `NUCLEOR_ISR_TARGET` when needed. Explicit unsupported target
  requests fail closed with `ISR-003`.

### 3.1 Attribute syntax

```nucleor
#[isr(vector = TARGET_SPECIFIC_NAME)]
fn handler() { ... }

#[isr(vector = TIM2, priority = 3)]
fn handler() { ... }

#[isr(vector = ExternalInterrupt::EXTI0, priority = 0, edge_triggered)]
fn handler() { ... }
```

Vector names come from the target's MCU PAC (Peripheral Access Crate).
Standard set per architecture, ships in `stdlib/embedded/<target>/vectors.nr`.

### 3.2 Implied attributes

`#[isr]` ultimately implies:
- `#[no_alloc]` — no allocation
- `#[no_panic]` — no panic (panic = MCU lockup)
- `#[no_dyn]` — no dynamic dispatch
- `#[atomic]` — no blocking

Plus a new ISR-specific rule:
- **No call to a non-`#[isr_safe]` function.** Most functions are
  `#[isr_safe]` if they satisfy the above. Stdlib audit manifest
  marks each function.

The v0.6 first pass implements the no-allocation and no-panic
inheritance now. It deliberately rejects `#[deadline]` composition:
deadline wrappers measure wall-time function calls, while ISR latency
belongs to target interrupt timing and vector tooling.

### 3.3 Vector table generation

The compiler generates the MCU vector table from `#[isr]`-annotated
functions:

```c
// Generated linker section
__attribute__((section(".vectors")))
const void* vectors[] = {
    &__stack_top,
    &reset_handler,
    &nmi_handler,
    &hard_fault_handler,
    // ... up to vector 16 ...
    &timer_overflow,    // TIM2 → user's #[isr(vector=TIM2)]
    &uart_rx,           // USART1 → user's #[isr(vector=USART1)]
    // ...
};
```

The user does not manually populate the vector table. Compiler does
it from attributes.

### 3.4 Calling-convention plumbing

ISRs on ARM and RISC-V have target-specific calling conventions
(save additional registers, return via specific instruction). The
codegen uses the target's `interrupt` LLVM attribute.

### 3.5 Critical sections

`#[isr]` functions can disable interrupts via `cpu::disable_interrupts()`
and `cpu::enable_interrupts()`. The compiler tracks this via a
`#[may_disable_interrupts]` audit flag — code that calls disable
without re-enabling produces a warning (not error, since temporary
disable is sometimes intentional for the rest of the function).

For data shared between ISR and non-ISR code, RFC-0007's
`Atomic<T>` is the recommended pattern (no critical sections needed).

### 3.6 Stack budget

Each ISR has a stack-usage budget. The compiler emits a static
stack-frame-size annotation per function; in `--profile=embedded`,
it errors if total ISR stack > configured budget (default 256
bytes per ISR).

```
error[ISR-002]: ISR stack frame exceeds budget
  --> src/handlers.nr:14:1
   |
14 | #[isr(vector = TIM2)]
15 | fn timer_overflow() {
16 |     let buf: [u8; 1024] = [0; 1024];   // 1024-byte stack frame
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ exceeds ISR stack budget (256 B)
   |
   = help: move buf to a static or thread-local
```

### 3.7 Composition with `Atomic<T>` (RFC-0007)

Standard pattern:

```nucleor
static TICK_COUNT: Atomic<u32> = Atomic::new(0);

#[isr(vector = SysTick)]
fn systick() {
    TICK_COUNT.fetch_add(1, Ordering::Relaxed);
}

#[no_alloc]
fn read_ticks() -> u32 {
    TICK_COUNT.load(Ordering::Relaxed)
}
```

### 3.8 Diagnostics

| Code | Meaning |
|---|---|
| ISR-001 | `#[isr]` function is not `fn() -> void` |
| ISR-002 | `#[isr]` combined with `#[deadline]` |
| ISR-003 | Target does not support `#[isr]` yet |
| ISR-004 | Vector name not recognized for target architecture |
| ISR-005 | Two ISRs assigned to the same vector |
| ISR-006 | Priority out of range for target NVIC |
| ISR-007 | Malformed `prio` attribute (negative / string / missing value) — v0.6.32 |
| ISR-008 | `#[isr]` applied to a non-fn item — v0.6.31 (orig. ISR-004; renamed in v0.6.32 because ISR-004 is reserved for "Vector name not recognized") |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `#[isr(vector=…, priority=…)]` | ~150 |
| Type checker | "no non-isr_safe call" rule + stack-budget check | ~200 |
| Codegen | Target-specific calling convention; vector-table emission | ~350 |
| Stdlib | `stdlib/embedded/cortex_m4f/vectors.nr`, `stdlib/embedded/rv32imac/vectors.nr` | ~600 |
| Linker scripts | Per-target `.ld` files for Cortex-M4F, RP2040, ESP32-C6, RV32IMAC | ~400 |
| Diagnostics | ISR-001…006 | ~150 |
| **Total** | | **~1850** |

---

## 5. Alternatives considered

- **Macro-based (Rust-embedded model)** — works but loses
  compile-time analysis. Attribute is cleaner.
- **Inline asm trap entry** — too target-specific; let LLVM handle.
- **No language support, document the convention** — defeats v0.6's
  embedded credibility goal.

## 6. Open questions

1. Multi-target ISR (one fn for multiple vectors)? Recommend allow
   via array: `#[isr(vector = [TIM2, TIM3])]`.
2. Nested-interrupt enable? Cortex-M supports it. Recommend opt-in
   via `#[isr(nested)]`.
3. FreeRTOS / Zephyr ISR convention difference (xPortStartScheduler
   etc.)? Add `#[isr(rtos = "freertos")]` variant.
4. Default deadline for ISRs? Recommend 10 µs as floor; project can
   override.

## 7. Definition of done

- [ ] `#[isr]` parses with vector + priority + flags
- [ ] Vector table generated for at least Cortex-M4F and RV32IMAC
- [ ] Linker scripts ship for both targets
- [ ] ISR-001…006 diagnostics fire correctly
- [ ] Demo: blinky on STM32F4 via Nucleor `#[isr]` + SysTick
- [ ] CHANGELOG documents `#[isr]`

## 8. Future extensions

- Cortex-M55/M85 with vector-table-relocation
- ARMv8-R for safety-critical (cars, planes)
- AVR / MSP430 (lower-tier MCUs) — community contribution
- DMA-trigger handlers (semantic similar to ISRs)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.6 schedule and `--profile=embedded`
- [ ] LOC budget ~1850 fits
- [ ] Pitch survives ("first-class ISR support, attribute-driven
      vector table, integrates with RT and atomic attributes")
