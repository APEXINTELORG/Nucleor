// Nucleor stdlib: borrow_checker
// Borrow and ownership tracking for bootstrap type checker.
// Models move/borrow/drop state per variable.

// Variable state
const VAR_LIVE: i32 = 0;
const VAR_MOVED: i32 = 1;
const VAR_BORROWED: i32 = 2;
const VAR_MUT_BORROWED: i32 = 3;
const VAR_DROPPED: i32 = 4;

fn state_name(s: i32) -> str {
    if s == VAR_LIVE { "live" }
    else if s == VAR_MOVED { "moved" }
    else if s == VAR_BORROWED { "borrowed" }
    else if s == VAR_MUT_BORROWED { "mut_borrowed" }
    else if s == VAR_DROPPED { "dropped" }
    else { "unknown" }
}

// Can we read this variable?
fn can_read(state: i32) -> bool {
    state == VAR_LIVE || state == VAR_BORROWED
}

// Can we write to this variable?
fn can_write(state: i32) -> bool {
    state == VAR_LIVE
}

// Can we move this variable?
fn can_move(state: i32) -> bool {
    state == VAR_LIVE
}

// Can we borrow this variable?
fn can_borrow_shared(state: i32) -> bool {
    state == VAR_LIVE || state == VAR_BORROWED
}

fn can_borrow_mut(state: i32) -> bool {
    state == VAR_LIVE
}

// Transition functions
fn do_move(state: i32) -> i32 {
    if can_move(state) { VAR_MOVED }
    else { state }
}

fn do_borrow(state: i32) -> i32 {
    if can_borrow_shared(state) { VAR_BORROWED }
    else { state }
}

fn do_mut_borrow(state: i32) -> i32 {
    if can_borrow_mut(state) { VAR_MUT_BORROWED }
    else { state }
}

fn do_drop(state: i32) -> i32 {
    VAR_DROPPED
}

fn do_unborrow(state: i32) -> i32 {
    if state == VAR_BORROWED || state == VAR_MUT_BORROWED { VAR_LIVE }
    else { state }
}

// Error detection
fn is_use_after_move(state: i32) -> bool {
    state == VAR_MOVED
}

fn is_use_after_drop(state: i32) -> bool {
    state == VAR_DROPPED
}

fn is_borrow_conflict(state: i32, want_mut: bool) -> bool {
    if want_mut { state == VAR_BORROWED || state == VAR_MUT_BORROWED }
    else { state == VAR_MUT_BORROWED }
}

fn main() -> i32 {
    // State transitions
    let s0: i32 = VAR_LIVE;
    print(state_name(s0));
    print_bool(can_read(s0));
    print_bool(can_move(s0));

    let s1: i32 = do_borrow(s0);
    print(state_name(s1));
    print_bool(can_read(s1));
    print_bool(can_move(s1));
    print_bool(can_borrow_shared(s1));
    print_bool(can_borrow_mut(s1));

    let s2: i32 = do_unborrow(s1);
    let s3: i32 = do_move(s2);
    print(state_name(s3));
    print_bool(is_use_after_move(s3));

    // Conflict detection
    print_bool(is_borrow_conflict(VAR_BORROWED, true));
    print_bool(is_borrow_conflict(VAR_BORROWED, false));
    print_bool(is_borrow_conflict(VAR_MUT_BORROWED, false));
    0
}
