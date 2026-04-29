// EXPECT: error[TYP-014] cannot call
// v0.4.122: calling a non-callable typed binding (`s(args)` for
// `s: str`, or any primitive numeric / bool / Vec) silently
// lowered to an indirect call that interpreted the value's bits
// as a function pointer — SIGSEGV at runtime. Adopters who typo'd
// a fn name into a string-typed variable name (or vice versa)
// got a runtime crash with no compile-time signal. Now halts at
// codegen time with TYP-014 listing the binding's actual type.

fn main() -> i32 {
    let s: str = "hello";
    s(42);
    0
}
