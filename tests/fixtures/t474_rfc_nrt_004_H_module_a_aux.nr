// Probe §H module A: declares pub fn error_kind_to_str.
pub enum AKind { AOne, ATwo }
pub fn error_kind_to_str(k: AKind) -> str {
    match k {
        AKind::AOne => return "a-one",
        AKind::ATwo => return "a-two",
    };
}
