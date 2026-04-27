// Probe §G via nuc test (harness path) — struct-typed enum payload
// field access in block-body match arms emits %r.-1 invalid SSA.
pub struct ErrInfo {
    kind: str,
    message: str,
}

pub enum Outcome {
    Ok(i64),
    Err(ErrInfo),
}

#[test]
fn struct_payload_field_access() {
    let info: ErrInfo = ErrInfo { kind: "bad", message: "something went wrong" };
    let r: Outcome = Outcome::Err(info);
    match r {
        Outcome::Ok(v) => assert!(false, "wrong arm"),
        Outcome::Err(e) => {
            let msg: str = e.message;
            assert!(str_eq(msg, "something went wrong") == 1, "msg should match");
        },
    };
}
