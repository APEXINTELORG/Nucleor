# Nucleor Language Tour

A pragmatic walk through Nucleor by example. Read top to bottom; copy the snippets into a `.nr` file and `nuc build` them.

> **Looking for a comprehensive list of what's shipped vs deferred?**
> See [`v0.4_FEATURE_AUDIT_2026-04-30.md`](v0.4_FEATURE_AUDIT_2026-04-30.md) —
> RFC-by-RFC reference of every feature surface and its current state.
> For migration from v0.2, see [`migrations/v0.2-to-v0.4.md`](migrations/v0.2-to-v0.4.md).

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

Numeric literals default to `i64`. The lexer accepts decimal
(`42`), hex (`0xFF` → `255`), binary (`0b1010` → `10`), and
underscored (`1_000_000`) forms. RFC-0015 width / signedness
suffixes (`100u8`, `1.5f32`) parse and type-check. **Since
v0.4.238 strict-mode integer arithmetic is the default** —
`+`, `-`, `*` panic on overflow rather than wrapping silently.
Use `wrapping { ... }` / `saturating { ... }` / `checked { ... }`
blocks for intentional wrap behavior, or set
`NUCLEOR_INT_STRICT_INTRIN=0` at compile time to opt out
globally. NUM-001 mixed-width-arithmetic warnings are emitted
directly during type-check.

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

## Pattern matching (RFC-0023)

The basic `match` above handles enum variants. Nucleor's pattern
language extends to ranges, guards, captures, slice patterns, and
struct destructuring:

```nr
// Range patterns + or-patterns + wildcards.
let class: str = match c {
    '0'..='9'         => "digit",
    'a'..='z' | 'A'..='Z' => "letter",
    _                 => "other",
};

// Guards — additional condition after the pattern.
let bucket: i32 = match x {
    n if n < 0    => 1,
    n if n == 0   => 2,
    n if n < 100  => 3,
    _             => 4,
};

// @-bindings — capture the matched value while still pattern-checking.
let v: i32 = match score {
    n @ 1..=10  => n,
    n @ 11..=99 => n * 2,
    _           => 0,
};

// Slice patterns on Vec.
let v: Vec<i32> = build_vec();
let head_tail: i32 = match v {
    [a, .., b] => a + b,    // ≥2 elements
    [single]   => single,
    []         => 0,
    _          => -1,
};

// Struct destructuring + same-name enum or-patterns.
struct Point { x: i32, y: i32 }
enum Sign { Pos(i32), Neg(i32) }

let r: i32 = match p {
    Point { x, y } => x + y,
};

let n: i32 = match s {
    Sign::Pos(n) | Sign::Neg(n) => n,    // both arms bind n
};
```

Field-equality literal patterns like `Point { x: 0 }` are deferred
to v0.5+ — express the same intent with a guard:
`Point { x, y } if x == 0 && y == 0 => ...`. Trying the unsupported
form halts cleanly with `MATCH-012`.

## Generics (RFC-0024)

Functions, structs, and enums all accept type parameters:

```nr
fn id<T>(x: T) -> T { return x; }

struct Pair<A, B> { first: A, second: B }

enum Maybe<T> { Some(T), None }

fn unwrap_or<T>(o: Maybe<T>, dflt: T) -> T {
    match o {
        Maybe::Some(v) => v,
        Maybe::None    => dflt,
    }
}
```

The compiler monomorphizes per call site. **Deferred to v0.5+:**
trait-bound combinations (`T: Foo + Bar`), associated types,
user-implementable `Iterator` trait. Bound check (`T: Trait`)
already fires `TYP-025` at call sites where the concrete type
doesn't `impl Trait`.

## Result, Option, and `?` (RFC-0016)

```nr
enum LowErr { Boom }
enum HighErr { Boomy }

impl From<LowErr> for HighErr {
    fn from(e: LowErr) -> HighErr { return HighErr::Boomy; }
}

fn lower() -> Result<i32, LowErr> { return Err(LowErr::Boom); }

fn higher() -> Result<i32, HighErr> {
    let x: i32 = lower()?;     // auto-converts LowErr → HighErr via From
    return Ok(x);
}
```

`?` propagates the error and applies `From::from` automatically when
the source and target error types differ. Without an `impl From`, the
compiler halts cleanly with `TRAIT-001`.

## Real-time function attributes (RFC-0001)

```nr
#[no_panic]
fn safe(x: i32) -> i32 { return x + 1; }

#[no_alloc]
fn rt_path(slot: i32) -> i32 { /* compiler rejects Vec::new etc. */ ... }

#[deadline = 1ms]
fn fast() -> i32 { return 42; }

#[no_alloc, no_panic, deadline = 500us]
fn isr(/* hot ISR path */) { ... }
```

Attributes compose. Violations produce diagnostics: `RT-001` for
allocation in `#[no_alloc]`, `RT-002` for panicking calls in
`#[no_panic]`, `RT-008` for direct recursion in `#[deadline]`
without a `#[max_depth = N]` opt-out (RFC-0014).

## Atomics (RFC-0007 partial)

```nr
import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let h: i64 = atomic_new(0);
    atomic_store_v(h, 42);
    let v: i64 = atomic_load_v(h);
    print_int(v as i32);          // 42
    atomic_drop(h);
    0
}
```

Sequentially-consistent `AtomicI64` ops — load, store, fetch-add,
fetch-sub, fetch-and / or / xor, CAS — backed by Win32
`Interlocked*` and C11 stdatomic. **Deferred to v0.5.0+:** the
`#[atomic]` attribute, `Atomic<T>` for non-i64 widths,
Relaxed/Acquire/Release ordering variants, and SPSC/MPMC lock-free
queues built on top.

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
