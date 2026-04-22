// Phase 5c: Trait with default method implementation

trait HasId {
    fn id(self) -> i32;
    fn double_id(self) -> i32 {
        self.id() * 2
    }
}

struct Item {
    value: i32,
}

impl HasId for Item {
    fn id(self) -> i32 {
        self.value
    }
}

fn main() -> i32 {
    let item: Item = Item { value: 21 };
    print_int(item.id());
    0
}
