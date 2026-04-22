// Nucleor stdlib: effect_system
// Effect tracking and enforcement for bootstrap compiler.
// Models the capability-based effect system.

// Effect categories (bit flags for fast set operations)
const EFF_IO: i32 = 1;
const EFF_NET: i32 = 2;
const EFF_FS: i32 = 4;
const EFF_SYNC: i32 = 8;
const EFF_RAND: i32 = 16;
const EFF_MEM: i32 = 32;
const EFF_UNSAFE: i32 = 64;
const EFF_AUTODIFF: i32 = 128;
const EFF_ALL: i32 = 255;
const EFF_NONE: i32 = 0;

// Pure = all effects denied
fn pure_denied() -> i32 {
    EFF_ALL
}

fn has_effect(set: i32, eff: i32) -> bool {
    let masked: i32 = set / eff;
    masked % 2 == 1
}

fn add_effect(set: i32, eff: i32) -> i32 {
    if has_effect(set, eff) { set }
    else { set + eff }
}

fn remove_effect(set: i32, eff: i32) -> i32 {
    if has_effect(set, eff) { set - eff }
    else { set }
}

fn effects_subset(a: i32, b: i32) -> bool {
    // Every effect in a is also in b
    let mut remaining: i32 = a;
    let mut check: i32 = 1;
    let mut ok: bool = true;
    while check <= 128 {
        if has_effect(remaining, check) {
            if !has_effect(b, check) {
                ok = false;
            };
        };
        check = check * 2;
    };
    ok
}

// Check if calling a function with required_effects is legal under denied_effects
fn call_legal(required: i32, denied: i32) -> bool {
    // No required effect may be in the denied set
    let mut check: i32 = 1;
    let mut legal: bool = true;
    while check <= 128 {
        if has_effect(required, check) && has_effect(denied, check) {
            legal = false;
        };
        check = check * 2;
    };
    legal
}

fn main() -> i32 {
    // Basic set operations
    let s: i32 = add_effect(EFF_NONE, EFF_IO);
    let s2: i32 = add_effect(s, EFF_FS);
    print_bool(has_effect(s2, EFF_IO));
    print_bool(has_effect(s2, EFF_FS));
    print_bool(has_effect(s2, EFF_NET));

    // Subset check
    print_bool(effects_subset(EFF_IO, s2));
    print_bool(effects_subset(EFF_NET, s2));

    // Pure function: all effects denied
    let denied: i32 = pure_denied();
    print_bool(call_legal(EFF_NONE, denied));
    print_bool(call_legal(EFF_IO, denied));
    print_bool(call_legal(EFF_IO, EFF_NONE));

    // Restricts block: deny specific effects
    let restricted: i32 = add_effect(EFF_NONE, EFF_NET);
    print_bool(call_legal(EFF_IO, restricted));
    print_bool(call_legal(EFF_NET, restricted));
    0
}
