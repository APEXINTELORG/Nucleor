// Probe §H module B: also declares pub fn error_kind_to_str (same name, different param type).
pub enum BKind { BOne, BTwo }
pub fn error_kind_to_str(k: BKind) -> str {
    match k {
        BKind::BOne => return "b-one",
        BKind::BTwo => return "b-two",
    };
}
