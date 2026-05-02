// RFC-0024 / Track Y where-clause closure (v0.6.10).
//
// Closes probe finding 2026-05-01-generic-T-trait-bound-where-clause-and-ref-still-broken.md.
// Track Y (v0.5.31) covered the inline `<T: Trait>` form. This fixture
// locks the `where T: Trait` form — the parser now splices `?Trait`
// markers into the gparams list during where-clause processing
// (parse_where_clause_into_gparams) so lower_fn captures them exactly
// like the inline form.
//
// Pre-v0.6.10: `fn ps<T>(x: T) -> i64 where T: Show { x.show() }` link-
// failed with `error[TYP-005]: undefined function 'vec_show'` because
// `skip_where_clause` discarded the bound silently.
// Post-v0.6.10: `ps(A { v: 1 })` dispatches to `A::show()` returning 101.

trait Show {
    fn show(self) -> i64;
}

// Single Show impl so Track Y's ambiguity guard (TYP-007) doesn't
// fire — the v0.5.31 closure path requires exactly one concrete
// impl for the bound. Multi-impl monomorphization is forward-roadmap
// (v0.9 with RFC-0034 [] params).
struct A { v: i64 }

impl Show for A { fn show(self) -> i64 { self.v + 100 } }

fn ps<T>(x: T) -> i64 where T: Show {
    return x.show();
}

fn main() -> i32 {
    let a: A = A { v: 1 };
    let r: i64 = ps(a);
    if r != 101 { return 1; };
    print("OK rfc0024_generic_trait_bound_where_clause");
    return 0;
}
