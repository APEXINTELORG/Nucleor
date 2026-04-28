// v0.4.28 RFC-0028 phase 5 — width spec dispatch
fn main() -> i64 {
    let n: i64 = 42;
    let s: str = "hi";
    let pi: f64 = 3.14159;

    // Right-align (default for numerics) width 6
    println!("[{:>6}]", n);     // [    42]
    // Left-align width 6
    println!("[{:<6}]", n);     // [42    ]
    // Center width 6
    println!("[{:^6}]", n);     // [  42  ]
    // Zero-pad width 5 (numeric default right-align with '0' fill)
    println!("[{:05}]", n);     // [00042]
    // Default-align width 6 numeric (no align given => right)
    println!("[{:6}]", n);      // [    42]

    // String left-align by default
    println!("[{:8}]", s);      // [hi      ]
    // Right-align string explicitly
    println!("[{:>8}]", s);     // [      hi]
    // Center string
    println!("[{:^8}]", s);     // [   hi   ]

    // Combination: width + precision
    println!("[{:>10.3}]", pi); // [     3.142]
    println!("[{:<10.3}]", pi); // [3.142     ]
    println!("[{:^10.3}]", pi); // [  3.142   ]

    return 0;
}
