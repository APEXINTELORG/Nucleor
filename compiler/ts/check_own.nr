// =====================================================
// OWNERSHIP CHECKER (S11.5)
// =====================================================
#[manual_drop]
fn own_revents_vec(o: Vec<i32>) -> Vec<i32> {
    return own_get_type(o, "__revents");
}



