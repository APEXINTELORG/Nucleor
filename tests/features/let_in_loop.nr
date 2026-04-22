// Tests that `let` inside a while loop reinitializes each iteration.
// This was a bug: LICM would hoist `let mut x = false` out of the loop
// when the reassignment `x = true` was inside an if-branch (nested Assign
// invisible to the shallow mutation scan).

fn main() -> i32 {
    let mut i: i32 = 0;
    let mut bad: i32 = 0;
    while i < 5 {
        let mut found: bool = false;
        // Only set found=true on iteration 2 (i==2)
        if i == 2 {
            found = true;
        }
        // On iterations 0,1,3,4 found must be false.
        // If Let was hoisted, found stays true after iteration 2.
        if found {
            bad = bad + 1;
        }
        i = i + 1;
    }
    // bad should be exactly 1 (only iteration 2)
    if bad == 1 {
        0
    } else {
        1
    }
}
