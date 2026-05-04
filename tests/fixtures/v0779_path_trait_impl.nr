// v0.7.83 fixture — path-qualified trait name in impl block.
// Pre-fix: `impl fmt::Display for Status` surfaced as wrong-class
// `error[NR020]: expected '{', got token 46` because parse_impl_block
// read the first path segment as the impl target, then `::` landed
// where expect_tok(52) expected `{`. Now the `::` path prefix is
// consumed and the final segment used as the trait/type name.
//
// Covers: single-segment (`fmt::Display`), multi-segment
// (`std::fmt::Display`), and the common unqualified form.

trait Display {
    fn show(&self) -> str;
}

trait Debug {
    fn debug_str(&self) -> str;
}

enum Color { Red, Green, Blue }

impl Display for Color {
    fn show(&self) -> str {
        match self {
            Color::Red => "red",
            Color::Green => "green",
            Color::Blue => "blue",
        }
    }
}

impl fmt::Display for Color {
    fn show_fmt(&self) -> str {
        return "Color";
    }
}

impl std::fmt::Display for Color {
    fn show_std(&self) -> str {
        return "Color-std";
    }
}

impl std::fmt::Debug for Color {
    fn debug_str(&self) -> str {
        return "Color::*";
    }
}

fn main() -> i64 {
    let c: Color = Color::Green;
    let s: str = c.show();
    let f: str = c.show_fmt();
    let d: str = c.show_std();
    let db: str = c.debug_str();
    // green=5, Color=5, Color-std=9, Color::*=8 — sum lengths = 27
    let total: i64 = str_len(s) as i64 + str_len(f) as i64 + str_len(d) as i64 + str_len(db) as i64;
    return total;
}
