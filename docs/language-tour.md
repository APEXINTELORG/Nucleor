# Nucleor Language Tour

A pragmatic walk through Nucleor by example. Read top to bottom; copy the snippets into a `.nr` file and `nuc build` them.

## Hello

```nr
fn main() -> i64 {
    print("Hello, Nucleor!");
    return 0;
}
```

`fn main() -> i64` is the entry point. Nucleor accepts both `i64` and `i32` return types for `main`.

## Variables

```nr
let x: i64 = 42;             // immutable
let mut counter: i64 = 0;    // mutable, reassignable
counter = counter + 1;
```

Nucleor is statically typed. Annotations after `:` are required for `let` bindings — no inference yet.

## Arithmetic

```nr
fn main() -> i64 {
    let a: i64 = 7;
    let b: i64 = 3;
    print(str_from_int(a + b));    // 10
    print(str_from_int(a - b));    // 4
    print(str_from_int(a * b));    // 21
    print(str_from_int(a / b));    // 2  (integer division)
    print(str_from_int(a - (a / b) * b));  // 1  (modulo via div)
    return 0;
}
```

Numeric literals are decimal `i64`. (Hex/binary literal support is planned.)

## Control flow

```nr
fn classify(n: i64) -> str {
    if n < 0 {
        return "negative";
    } else {
        if n == 0 {
            return "zero";
        } else {
            return "positive";
        };
    };
}
```

Note the trailing semicolons after blocks. `else if` is written as a nested `if` inside the `else` branch.

```nr
fn sum_to(n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 1;
    while i <= n {
        acc = acc + i;
        i = i + 1;
    };
    return acc;
}
```

`while` is the loop primitive. `for x in <expr>` over arrays and `Vec` already works (see `tests/features/forin_array.nr` and `tests/features/forin_vec.nr`):

```nr
let arr: [i32; 3] = [10, 20, 30];
let mut sum: i32 = 0;
for x in arr {
    sum = sum + x;
}
```

A more general iterator-trait `for` (over `HashMap` keys, ranges, lazy adapters) lands in v0.4 with RFC-0024.

## Strings

```nr
let s: str = str_concat("Hello, ", "world!");
print(s);                          // Hello, world!
print(str_substring(s, 0, 5));     // Hello
let n: i64 = str_len(s);           // 13
let c: i64 = str_char_at(s, 7);    // 119 (the byte 'w')
if str_eq(s, "Hello, world!") == 1 {
    print("equal");
};
```

The core string ops are runtime builtins. The `stdlib/rods/strings.nr` rod adds higher-level helpers like `strings_to_upper`, `strings_split`, `strings_contains`, etc.

## Vectors

```nr
let xs: Vec<i32> = Vec::new();
xs.push(10);
xs.push(20);
xs.push(30);
let n: i64 = vec_len(xs);          // 3
let first: i64 = vec_get(xs, 0);   // 10
```

The element type annotation is by convention `Vec<i32>` even when storing `i64` values — vectors are uniform 64-bit slots under the hood.

## Functions

```nr
fn greet(name: str) -> str {
    return str_concat("Hello, ", name);
}

fn add(a: i64, b: i64) -> i64 {
    return a + b;
}
```

Every function declares its parameter and return types. `fn main() -> i64` is the program entry point.

## Closures

```nr
let double: i64 = |x| x * 2;
let three_arg: i64 = |a, b, c| a + b + c;
let with_block: i64 = |x| { if x < 0 { return 0 - x; }; return x; };
let zero_arg: i64 = || 42;

fn apply(f: i64, x: i64) -> i64 {
    return f(x);
}

let r: i64 = apply(double, 21);    // 42
let r2: i64 = apply(|x| x + 1, 9); // 10
```

Closures are first-class values stored as `i64` (a function pointer / closure handle).

## Structs

```nr
struct Point {
    x: i64,
    y: i64
}

fn distance_sq(a: Point, b: Point) -> i64 {
    let dx: i64 = a.x - b.x;
    let dy: i64 = a.y - b.y;
    return dx * dx + dy * dy;
}

let origin: Point = Point { x: 0, y: 0 };
let p: Point = Point { x: 3, y: 4 };
print(str_from_int(distance_sq(origin, p)));    // 25

let mut q: Point = Point { x: 0, y: 0 };
q.x = 100;                                       // field assignment requires `mut`
```

Field access uses `.`. Struct construction uses `Type { field: value, ... }`.

## Enums

```nr
enum Option {
    None,
    Some(i64)
}

fn unwrap_or(o: Option, default: i64) -> i64 {
    match o {
        Option::None => { return default; },
        Option::Some(v) => { return v; },
    };
}

let r1: i64 = unwrap_or(Option::None, 99);     // 99
let r2: i64 = unwrap_or(Option::Some(42), 0);  // 42
```

Enums are tagged unions. Variant constructors are `EnumName::Variant` (or `EnumName::Variant(payload)`).
Function parameters that hold enum values must declare the enum type explicitly:
the type checker treats each enum as its own type, not interchangeable with `i64`.

## Imports

```nr
import "stdlib/rods/strings.nr"
import "stdlib/rods/json.nr"

fn main() -> i64 {
    if strings_starts_with("nucleor", "nuc") == 1 {
        print("yes");
    };
    let obj: i64 = json_object_new();
    json_object_set(obj, "lang", json_from_string("Nucleor"));
    print(json_stringify(obj));    // {"lang":"Nucleor"}
    return 0;
}
```

Paths are relative to the project root by default. Rods are documented in [rods-and-runtime.md](rods-and-runtime.md).

## C interop

```nr
#cfile "my_helper.c"

extern fn my_helper_add(a: i64, b: i64) -> i64;

fn main() -> i64 {
    print(str_from_int(my_helper_add(40, 2)));
    return 0;
}
```

`#cfile` tells the compiler to compile and link the named C source. `extern fn` declares its symbol on the Nucleor side. Exactly the same pattern works for any language that produces a static library — see [`stdlib/rods/rust.nr`](../stdlib/rods/rust.nr) for a Rust example using `#link`.

## Performance attributes

```nr
@law(commutative, associative, identity=0)
fn add(a: i64, b: i64) -> i64 { return a + b; }

@const_fn
fn square(x: i64) -> i64 { return x * x; }

@hot
fn dot(xs: Vec<i32>, ys: Vec<i32>, n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        acc = acc + vec_get(xs, i) * vec_get(ys, i);
        i = i + 1;
    };
    return acc;
}
```

- `@law(...)` declares algebraic laws the optimizer can use to rewrite call sites (identity elimination, reassociation, etc.).
- `@const_fn` marks a function as eligible for compile-time evaluation.
- `@hot` enforces no heap allocation, no string formatting, and no indirect dispatch in the function's body.

Run `nuc perf <file>.nr` to see what the optimizer found and what was rewritten.

See [language-reference.md](language-reference.md) for the full attribute catalog and grammar.
