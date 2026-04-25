// t367_question_op_chain.nr — v0.3.91 regression fixture.
//
// Pins `?` operator chain semantics. Pre-v0.3.91, the kind-122
// (postfix `?`) lowering had its labels SWAPPED in ir_br_cond:
// when tag == 0 (Ok), control jumped to err_lbl which early-returned
// the Result; when tag != 0 (Err), control jumped to ok_lbl which
// extracted the payload. Net effect: the FIRST `?` in a chain
// short-circuited to early-return on Ok, breaking every subsequent
// step. divide(60,2)? returned Ok(30) early, so pipeline never
// computed divide(30, 3) or *10.
//
// Returns 100 on success: divide(60, 2)? = 30, divide(30, 3)? = 10,
// Ok(10 * 10) = Ok(100).

fn divide(a: i64, b: i64) -> Result<i64, str> {
    if b == 0 { return Err("zero"); };
    return Ok(a / b);
}

fn pipeline(a: i64) -> Result<i64, str> {
    let x: i64 = divide(a, 2)?;
    let y: i64 = divide(x, 3)?;
    return Ok(y * 10);
}

fn main() -> i64 {
    let r = pipeline(60);
    let v: i64 = match r {
        Ok(x) => return x,
        Err(_) => return -1,
    };
}
