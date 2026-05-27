// =====================================================
// OWNERSHIP CHECKER (S11.5)
// =====================================================
#[manual_drop]
fn own_revents_vec(o: Vec<i32>) -> Vec<i32> {
    return own_get_type(o, "__revents");
}
fn check_expr(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if nid < 0 { return 0; };
    if nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    let source_text: str = own_source(own);
    let diag_vec: Vec<i32> = own_diags(own);
    if kind == 1 || kind == 2 || kind == 71 { return 0; }; // literals
    if kind == 3 {
        // IDENT — check for use-after-move
        let vname: str = node_field(pool, nid, 1);
        let state: i64 = own_get(own, vname);
        if state == 2 {
            let ln: i64 = find_in_source(source_text, fn_name, vname);
            let col: i64 = find_column_in_source(source_text, fn_name, vname);
            let d_idx: i64 = diag_add_ex(diag_vec, "error", "ownership", "OWN-001", str_concat("use of moved variable '", str_concat(vname, "'")), fn_name, ln, col, "");
            // Add child note: where was it moved?
            let moved_by: str = own_get_type(own, str_concat("__moved_by_", vname));
            if str_len(moved_by) > 0 {
                let d: Vec<i32> = diag_get(diag_vec, d_idx - 1);
                let move_line: i64 = find_in_source(source_text, fn_name, moved_by);
                vec_set(d, 10, str_concat("'", str_concat(vname, str_concat("' was moved here by call to '", str_concat(moved_by, "'")))));
                vec_set(d, 11, move_line);
            };
            return 1;
        };
        return 0;
    };
    if kind == 4 {
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        warns = warns + check_expr(pool, node_field(pool, nid, 3), own, structs, enums, fn_name);
        return warns;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    if kind == 7 {
        // CALL — check args, move Move-type idents
        let callee_name: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        review_acc_call_edge(own, fn_name, callee_name, ac);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if str_eq(callee_name, "arena_destroy") == 1 {
                    let arena_key: str = str_concat("@arena:", aname);
                    if own_has_shared_overlap(own, arena_key) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-012", str_concat("cannot destroy arena '", str_concat(aname, "': live arena references still exist")), aname);
                    };
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), callee_name); review_acc_move(own, fn_name, aname, str_concat("call_arg:", callee_name));
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 8 {
        // METHOD — check receiver (don't move it) and args
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let method_name: str = node_field(pool, nid, 2);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), method_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 9 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    if kind == 10 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        return warns;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + check_expr(pool, list_get(pool, items, ii), own, structs, enums, fn_name);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 12 {
        let qual_name: str = str_concat(node_field(pool, nid, 1), str_concat("::", node_field(pool, nid, 2)));
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), qual_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 34 {
        // STRUCT_INIT — check field init exprs
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            let init_nid: i64 = list_get(pool, inits, ii);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            warns = warns + check_expr(pool, val_nid, own, structs, enums, fn_name);
            if node_kind(pool, val_nid) == 3 {
                let vn: str = node_field(pool, val_nid, 1);
                let vt: str = own_get_type(own, vn);
                if own_binding_move_type(vt, pool, structs, enums) == 1 { own_set(own, vn, 2); };
            };
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 52 {
        let cur_scope: i64 = own_get_i(own, "cur_scope");
        own_set_i(own, "cur_scope", cur_scope + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, cur_scope + 1);
        own_set_i(own, "cur_scope", cur_scope);
        return warns;
    };
    if kind == 42 { return 0; }; // closure — skip for now
    return warns;
}

fn check_stmt(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    let scope_depth: i64 = own_get_i(own, "cur_scope");
    let source_text: str = own_source(own);
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let is_mut: i64 = node_field(pool, nid, 2);
        let mut tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        own_set_mutable(own, vname, is_mut);
        own_set_scope(own, vname, scope_depth);
        own_set_param(own, vname, 0);
        if init >= 0 {
            if str_len(tstr) == 0 && node_kind(pool, init) == 34 { tstr = node_field(pool, init, 1); };
            if str_len(tstr) == 0 && node_kind(pool, init) == 3 { tstr = own_get_type(own, node_field(pool, init, 1)); };
            warns = warns + check_expr(pool, init, own, structs, enums, fn_name);
            if type_is_ref(tstr) == 1 {
                if node_kind(pool, init) == 90 || node_kind(pool, init) == 91 {
                    warns = warns + own_register_borrow_expr(pool, init, own, fn_name, vname, scope_depth, 1);
                } else if node_kind(pool, init) == 7 && str_eq(node_field(pool, init, 1), "arena_alloc") == 1 {
                    let a_args: i64 = node_field(pool, init, 2);
                    if list_len(pool, a_args) > 0 && node_kind(pool, list_get(pool, a_args, 0)) == 3 {
                        let arena_name: str = node_field(pool, list_get(pool, a_args, 0), 1);
                        let arena_key: str = str_concat("@arena:", arena_name);
                        own_inc_shared(own, arena_key);
                        own_set_ref_target(own, vname, arena_key);
                        own_set_ref_kind(own, vname, 0);
                        own_set_scope(own, vname, scope_depth);
                    };
                } else if node_kind(pool, init) == 3 {
                    let src: str = node_field(pool, init, 1);
                    let st: str = own_get_type(own, src);
                    if type_is_ref(st) == 1 {
                        own_copy_ref_binding(own, src, vname, scope_depth);
                        if type_is_mut_ref(st) == 1 {
                            own_set_ref_target(own, src, "");
                            own_set_ref_kind(own, src, 0);
                            own_set(own, src, 2);
                        };
                    };
                };
                let escape_root: str = expr_escape_root(pool, init, own);
                if str_len(escape_root) > 0 && own_get_scope(own, escape_root) > scope_depth {
                    warns = warns + own_diag(own, fn_name, "OWN-010", str_concat("cannot let reference to inner-scope value '", str_concat(escape_root, "' escape its scope")), escape_root);
                };
            } else if node_kind(pool, init) == 3 {
                let src: str = node_field(pool, init, 1);
                let mut st: str = own_get_type(own, src);
                let hinted_box: str = own_box_hint(own, fn_name, vname);
                if str_len(hinted_box) > 0 && str_eq(type_base_name(st), "Box") == 0 { st = hinted_box; };
                if str_len(st) == 0 { st = tstr; };
                if own_binding_move_type(st, pool, structs, enums) == 1 {
                    if own_has_shared_overlap(own, src) == 1 || own_has_mut_overlap(own, src) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(src, "': value is borrowed")), src);
                    } else {
                        own_set(own, src, 2);
                        review_acc_move(own, fn_name, src, "let_binding");
                    };
                };
            };
            own_set(own, vname, 1);
            review_acc_init(own, fn_name, vname, tstr, is_copy_type(tstr, pool, structs, enums));
        } else {
            own_set(own, vname, 0);
        };
        own_set_type(own, vname, tstr);
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        warns = warns + check_expr(pool, rhs, own, structs, enums, fn_name);
        if node_kind(pool, lhs) == 3 {
            let lname: str = node_field(pool, lhs, 1);
            if own_get_mutable(own, lname) == 0 && own_get_param(own, lname) == 0 {
                warns = warns + own_diag(own, fn_name, "OWN-008", str_concat("cannot assign to immutable binding '", str_concat(lname, "'")), lname);
            };
            own_release_ref(own, lname);
            if node_kind(pool, rhs) == 90 || node_kind(pool, rhs) == 91 {
                warns = warns + own_register_borrow_expr(pool, rhs, own, fn_name, lname, scope_depth, 1);
                let escape_root: str = expr_escape_root(pool, rhs, own);
                if str_len(escape_root) > 0 && own_get_scope(own, escape_root) > scope_depth {
                    warns = warns + own_diag(own, fn_name, "OWN-010", str_concat("cannot let reference to inner-scope value '", str_concat(escape_root, "' escape its scope")), escape_root);
                };
            } else if node_kind(pool, rhs) == 3 {
                let src: str = node_field(pool, rhs, 1);
                let mut st: str = own_get_type(own, src);
                let hinted_box: str = own_box_hint(own, fn_name, lname);
                if str_len(hinted_box) > 0 && str_eq(type_base_name(st), "Box") == 0 { st = hinted_box; };
                if str_len(st) == 0 { st = own_get_type(own, lname); };
                if type_is_ref(st) == 1 {
                    own_copy_ref_binding(own, src, lname, scope_depth);
                    if type_is_mut_ref(st) == 1 {
                        own_set_ref_target(own, src, "");
                        own_set_ref_kind(own, src, 0);
                        own_set(own, src, 2);
                    };
                } else if own_binding_move_type(st, pool, structs, enums) == 1 {
                    if own_has_shared_overlap(own, src) == 1 || own_has_mut_overlap(own, src) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(src, "': value is borrowed")), src);
                    } else {
                        own_set(own, src, 2);
                        review_acc_move(own, fn_name, src, "assignment");
                    };
                };
            };
            own_set(own, lname, 1);
            review_acc_revive(own, fn_name, lname);
            return warns;
        };
        if node_kind(pool, lhs) == 9 {
            let recv: i64 = node_field(pool, lhs, 1);
            if node_kind(pool, recv) == 3 && type_is_shared_ref(own_get_type(own, node_field(pool, recv, 1))) == 1 {
                let rname: str = node_field(pool, recv, 1);
                warns = warns + own_diag(own, fn_name, "OWN-006", str_concat("cannot assign through shared reference '", str_concat(rname, "'")), rname);
                return warns;
            };
            let mut recv_is_mut_ref: i64 = 0;
            if node_kind(pool, recv) == 3 && type_is_mut_ref(own_get_type(own, node_field(pool, recv, 1))) == 1 { recv_is_mut_ref = 1; };
            if recv_is_mut_ref == 0 {
                let key: str = expr_borrow_key(pool, lhs, own);
                if own_has_shared_overlap(own, key) == 1 || own_has_mut_overlap(own, key) == 1 {
                    let root: str = expr_root_name(pool, lhs, own);
                    warns = warns + own_diag(own, fn_name, "OWN-007", str_concat("cannot assign to borrowed location '", str_concat(key, "'")), root);
                };
            };
        };
        return warns;
    };
    if kind == 22 {
        let val: i64 = node_field(pool, nid, 1);
        if val >= 0 {
            warns = warns + check_expr(pool, val, own, structs, enums, fn_name);
            let escape_root: str = expr_escape_root(pool, val, own);
            if str_len(escape_root) > 0 && own_get_param(own, escape_root) == 0 {
                warns = warns + own_diag(own, fn_name, "OWN-009", str_concat("cannot return reference to local value '", str_concat(escape_root, "'")), escape_root);
            };
        };
        return warns;
    };
    if kind == 23 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        review_acc_branch_fork(own, fn_name);
        let snap: Vec<i32> = own_snapshot(own);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        let then_state: Vec<i32> = own_snapshot(own);
        own_restore(own, snap);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            own_set_i(own, "cur_scope", scope_depth + 1);
            warns = warns + check_stmts(pool, enode, own, structs, enums, fn_name);
            own_release_scope(own, scope_depth + 1);
            own_set_i(own, "cur_scope", scope_depth);
        };
        let else_state: Vec<i32> = own_snapshot(own);
        own_merge_moved(own, then_state, else_state);
        review_acc_branch_merge(own, fn_name, "conservative");
        return warns;
    };
    if kind == 24 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        return warns;
    };
    if kind == 25 {
        return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
    };
    if kind == 28 {
        let loop_var: str = node_field(pool, nid, 1);
        own_set(own, loop_var, 1);
        own_set_type(own, loop_var, "i64");
        own_set_mutable(own, loop_var, 1);
        own_set_scope(own, loop_var, scope_depth + 1);
        own_set_param(own, loop_var, 0);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 4), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        return warns;
    };
    if kind == 49 {
        let loop_var: str = node_field(pool, nid, 1);
        own_set(own, loop_var, 1);
        own_set_type(own, loop_var, "Vec");
        own_set_mutable(own, loop_var, 1);
        own_set_scope(own, loop_var, scope_depth + 1);
        own_set_param(own, loop_var, 0);
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 3), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        return warns;
    };
    if kind == 38 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let snap: Vec<i32> = own_snapshot(own);
        let mut has_wildcard: i64 = 0;
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_nid: i64 = list_get(pool, arms, ai);
            own_restore(own, snap);
            let ename: str = node_field(pool, arm_nid, 1);
            if str_eq(ename, "__wild") { has_wildcard = 1; };
            let binding: str = node_field(pool, arm_nid, 3);
            if str_len(binding) > 0 {
                own_set(own, binding, 1);
                own_set_type(own, binding, "i64");
                own_set_mutable(own, binding, 0);
                own_set_scope(own, binding, scope_depth + 1);
                own_set_param(own, binding, 0);
            };
            own_set_i(own, "cur_scope", scope_depth + 1);
            warns = warns + check_stmts(pool, node_field(pool, arm_nid, 4), own, structs, enums, fn_name);
            own_release_scope(own, scope_depth + 1);
            own_set_i(own, "cur_scope", scope_depth);
            ai = ai + 1;
        };
        if has_wildcard == 0 && ac > 0 {
            let first_arm: i64 = list_get(pool, arms, 0);
            let first_ename: str = node_field(pool, first_arm, 1);
            if str_eq(first_ename, "__int") == 0 && str_eq(first_ename, "__str") == 0 && str_eq(first_ename, "__wild") == 0 {
                let ei: i64 = enum_find(pool, enums, first_ename);
                if ei >= 0 {
                    let e_nid: i64 = vec_get(enums, ei);
                    let vlist: i64 = node_field(pool, e_nid, 2);
                    let vcnt: i64 = list_len(pool, vlist);
                    if ac < vcnt {
                        let src: str = source_text;
                        let ln: i64 = find_in_source(src, fn_name, "match");
                        diag_add(own_diags(own), "warning", "type", "TYP-001", str_concat("non-exhaustive match: ", str_concat(str_from_int(ac), str_concat(" arms for enum with ", str_concat(str_from_int(vcnt), " variants")))), fn_name, ln);
                        warns = warns + 1;
                    };
                };
            };
        };
        return warns;
    };
    return warns;
}

#[manual_drop]
fn check_fn(pool: Vec<i32>, fn_nid: i64, structs: Vec<i32>, enums: Vec<i32>, diags: Vec<i32>, source: str, review_path: str, review_filter: str) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    review_on_checker_enter(review_path, "ownership", fn_name, review_filter);
    let pc: i64 = list_len(pool, plist);
    let mut own: Vec<i32> = own_new();
    own_set_type(own, "__diags", diags);
    own_set_type(own, "__source", source);
    own_set_type(own, "__shared_keys", Vec::new());
    own_set_type(own, "__mut_keys", Vec::new());
    own_set_type(own, "__scope_keys", Vec::new());
    own_set_i(own, "cur_scope", 0);
    // S12b: review event accumulator (removable)
    let mut revents: Vec<i32> = Vec::new();
    own_set_type(own, "__revents", revents);
    own_set_type(own, "__review", review_path);
    let mut pi: i64 = 0;
    let mut param_desc: i64 = sb_new();
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ptype: str = node_field(pool, pnid, 2);
        own_set(own, pname, 1);
        own_set_type(own, pname, ptype);
        own_set_mutable(own, pname, 0);
        own_set_scope(own, pname, 0);
        own_set_param(own, pname, 1);
        if type_is_ref(ptype) == 1 {
            own_set_ref_target(own, pname, pname);
            if type_is_mut_ref(ptype) == 1 { own_set_ref_kind(own, pname, 1); }
            else { own_set_ref_kind(own, pname, 0); };
        };
        review_acc_init(own, fn_name, pname, ptype, is_copy_type(ptype, pool, structs, enums));
        if pi > 0 { sb_append(param_desc, ","); };
        sb_append(param_desc, str_concat(pname, str_concat(":", ptype)));
        pi = pi + 1;
    };
    review_acc_fn_sig(own, fn_name, sb_to_str(param_desc));
    let w: i64 = check_stmts(pool, body, own, structs, enums, fn_name);
    let rtype: str = node_field(pool, fn_nid, 3);
    if type_is_ref(rtype) == 1 {
        let body_cnt: i64 = list_len(pool, body);
        if body_cnt > 0 {
            let last_stmt: i64 = list_get(pool, body, body_cnt - 1);
            let last_kind: i64 = node_kind(pool, last_stmt);
            if last_kind == 25 || last_kind == 23 || last_kind == 52 {
                let mut escape_root: str = "";
                if last_kind == 25 { escape_root = expr_escape_root(pool, node_field(pool, last_stmt, 1), own); }
                else { escape_root = expr_escape_root(pool, last_stmt, own); };
                if str_len(escape_root) > 0 && own_get_param(own, escape_root) == 0 {
                    own_diag(own, fn_name, "OWN-009", str_concat("cannot return reference to local value '", str_concat(escape_root, "'")), escape_root);
                };
            };
        };
    };
    // S12b: flush accumulated review events (removable)
    // If filter=findings, only flush for functions with findings > 0
    if str_len(review_path) > 0 && review_filter_allows_checker(review_filter, "ownership") == 1 && review_filter_allows_function(review_filter, fn_name) == 1 {
        let mut should_flush: i64 = 1;
        if str_eq(review_filter, "findings") && w == 0 { should_flush = 0; };
        if should_flush == 1 {
            let rev: Vec<i32> = own_revents_vec(own);
            let mut ri: i64 = 0;
            while ri < vec_len(rev) { review_emit(review_path, vec_get(rev, ri)); ri = ri + 1; };
        };
    };
    review_on_checker_exit(review_path, "ownership", fn_name, w, review_filter);
    return w;
}

