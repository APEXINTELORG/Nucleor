// urdf_rt.c — Minimal URDF (Unified Robot Description Format)
// parser. URDF is XML-based; this parser uses simple substring
// extraction rather than a full XML parser, so it tolerates the
// common formatting variations of hand-written and ROS-exported
// URDF files but is not strictly XML-compliant (no DTDs, no
// namespaces, no CDATA sections, no entity references besides
// the obvious ones).
//
// Supported per-joint attributes:
//   <joint name="..." type="revolute|prismatic|fixed|continuous">
//     <origin xyz="x y z" rpy="r p y"/>     (RPY = roll-pitch-yaw)
//     <axis xyz="x y z"/>
//     <limit lower="..." upper="..." effort="..." velocity="..."/>
//     <parent link="..."/>
//     <child link="..."/>
//     ... (dynamics ignored — see limitations)
//   </joint>
//
// **Limitations** (the v0.5 ship is intentionally minimal; the
// follow-on URDF compliance pass lands in v0.6):
// - FK export remains serial-chain only. <parent>/<child> link
//   relationships are parsed and used to order serial trees, and
//   branching/forest topologies are refused by urdf_to_fk_chain
//   instead of being silently flattened.
// - Continuous joints are treated as revolute (no distinction).
// - Mesh / visual / collision / inertial subtrees are skipped.
// - Includes (xacro <xacro:include>) are NOT resolved — the
//   caller must pre-process xacro to plain URDF first.
//
// Compile: clang -c stdlib/runtime/urdf_rt.c -o target/urdf.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define _URDF_REVOLUTE  0
#define _URDF_PRISMATIC 1
#define _URDF_FIXED     2

typedef struct {
    int joint_type;
    double xyz[3];
    double rpy[3];
    double axis[3];
    double lo, hi;
    int has_limit;
    char name[64];
    char parent_link[64];
    char child_link[64];
    int has_parent_link;
    int has_child_link;
} _URDFJoint;

typedef struct {
    int n_joints;
    int cap_joints;
    _URDFJoint *joints;
} NURDF;

// === Tiny string-search helpers ===
//
// Each `_find_attr_*` looks for `<elem ... attr="value" ...>` and
// returns the value parsed as the appropriate type. Returns -1
// (not found) or the requested value. Doesn't malloc; uses static
// scratch buffers.

static int _starts_with(const char *s, const char *prefix) {
    while (*prefix) { if (*s++ != *prefix++) return 0; }
    return 1;
}

static const char *_skip_ws(const char *s) {
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    return s;
}

// Find element opening: returns pointer to character after `<NAME `
// (i.e., positioned at the attribute list), or NULL if not found.
static const char *_find_elem(const char *src, const char *end, const char *name) {
    int nlen = (int)strlen(name);
    while (src < end - nlen - 1) {
        if (*src == '<' && _starts_with(src + 1, name)) {
            char nx = src[1 + nlen];
            if (nx == ' ' || nx == '>' || nx == '\t' || nx == '\n' || nx == '/') {
                return src + 1 + nlen;
            }
        }
        src++;
    }
    return NULL;
}

// Find attr `name="..."` within the element-attribute region.
// `end` bounds the region (typically the element closing `>` or
// the next `<`). On success, fills `out` with the attribute value
// (NUL-terminated, max `out_cap-1` chars) and returns 1; else 0.
static int _find_attr(const char *src, const char *end, const char *name,
                      char *out, int out_cap) {
    int nlen = (int)strlen(name);
    while (src < end - nlen - 2) {
        // Match start of token boundary + attr name + '='.
        if ((src == NULL) || (src > end - nlen - 2)) break;
        if ((src[0] == ' ' || src[0] == '\t' || src[0] == '\n' || src[0] == '\r')
            && _starts_with(src + 1, name) && src[1 + nlen] == '=') {
            const char *q = src + 2 + nlen;
            if (*q != '"' && *q != '\'') { src++; continue; }
            char quote = *q;
            q++;
            const char *end_quote = q;
            while (end_quote < end && *end_quote != quote) end_quote++;
            int len = (int)(end_quote - q);
            if (len >= out_cap) len = out_cap - 1;
            memcpy(out, q, len);
            out[len] = '\0';
            return 1;
        }
        src++;
    }
    return 0;
}

// Parse "x y z" into 3 doubles. Returns count parsed (0..3).
static int _parse_3d(const char *s, double *out) {
    int n = 0;
    char *endp;
    while (n < 3) {
        while (*s == ' ' || *s == '\t') s++;
        if (*s == '\0') break;
        out[n++] = strtod(s, &endp);
        if (endp == s) break;
        s = endp;
    }
    return n;
}

// Convert RPY (roll-pitch-yaw) to quaternion (w, x, y, z).
// Convention: rotation order = R_z(yaw) * R_y(pitch) * R_x(roll),
// applied to a vector as q · v · q^-1.
static void _rpy_to_quat(double r, double p, double y, double *q_out) {
    double cr = cos(r * 0.5), sr = sin(r * 0.5);
    double cp = cos(p * 0.5), sp = sin(p * 0.5);
    double cy = cos(y * 0.5), sy = sin(y * 0.5);
    q_out[0] = cy * cp * cr + sy * sp * sr;  // w
    q_out[1] = cy * cp * sr - sy * sp * cr;  // x
    q_out[2] = sy * cp * sr + cy * sp * cr;  // y
    q_out[3] = sy * cp * cr - cy * sp * sr;  // z
}

static int _copy_attr_value(char *dst, int dst_cap, const char *src) {
    if (!dst || dst_cap <= 0 || !src) return 0;
    int n = (int)strlen(src);
    if (n >= dst_cap) n = dst_cap - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
    return n > 0;
}

static int _topology_available(NURDF *u) {
    if (!u || u->n_joints <= 0) return 0;
    for (int i = 0; i < u->n_joints; i++) {
        if (!u->joints[i].has_parent_link || !u->joints[i].has_child_link) return 0;
    }
    return 1;
}

static int _joint_parent_index(NURDF *u, int i) {
    if (!u || i < 0 || i >= u->n_joints) return -2;
    _URDFJoint *j = &u->joints[i];
    if (!j->has_parent_link) return i == 0 ? -1 : i - 1;
    for (int k = 0; k < u->n_joints; k++) {
        if (k == i) continue;
        if (u->joints[k].has_child_link &&
            strcmp(u->joints[k].child_link, j->parent_link) == 0) {
            return k;
        }
    }
    return -1;
}

static int _joint_child_count(NURDF *u, int parent_idx) {
    if (!u || parent_idx < -1 || parent_idx >= u->n_joints) return 0;
    int n = 0;
    for (int i = 0; i < u->n_joints; i++) {
        if (_joint_parent_index(u, i) == parent_idx) n++;
    }
    return n;
}

static int _first_child_index(NURDF *u, int parent_idx) {
    if (!u || parent_idx < -1 || parent_idx >= u->n_joints) return -1;
    for (int i = 0; i < u->n_joints; i++) {
        if (_joint_parent_index(u, i) == parent_idx) return i;
    }
    return -1;
}

static int _has_branching(NURDF *u) {
    if (!_topology_available(u)) return 0;
    if (_joint_child_count(u, -1) > 1) return 1;
    for (int i = 0; i < u->n_joints; i++) {
        if (_joint_child_count(u, i) > 1) return 1;
    }
    return 0;
}

static int _topology_is_serial(NURDF *u) {
    if (!u) return 0;
    if (!_topology_available(u)) return 1;
    if (u->n_joints == 0) return 1;
    if (_joint_child_count(u, -1) != 1) return 0;
    int cur = _first_child_index(u, -1);
    int visited = 0;
    while (cur >= 0 && visited <= u->n_joints) {
        visited++;
        int n_child = _joint_child_count(u, cur);
        if (n_child > 1) return 0;
        cur = n_child == 1 ? _first_child_index(u, cur) : -1;
    }
    return visited == u->n_joints;
}

// === URDF rod surface ===

long long nuc_urdf_new(void) {
    NURDF *u = (NURDF *)calloc(1, sizeof(NURDF));
    u->cap_joints = 8;
    u->joints = (_URDFJoint *)calloc(u->cap_joints, sizeof(_URDFJoint));
    return (long long)(size_t)u;
}

// Parse a URDF string. The URDF source is provided as a raw text
// buffer (caller-owned, NUL-terminated). Joints are appended in
// source-order. Returns the number of joints parsed (≥ 0) or -1
// on bad input.
long long nuc_urdf_parse(long long h, long long src_ptr) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u) return -1;
    const char *src = (const char *)(void *)(size_t)src_ptr;
    if (!src) return -1;
    int slen = (int)strlen(src);
    const char *end = src + slen;

    const char *cursor = src;
    int parsed = 0;
    while (cursor < end) {
        const char *jstart = _find_elem(cursor, end, "joint");
        if (!jstart) break;
        // Audit fix HIGH-LAYER9B-007 (2026-05-08): handle self-closing
        // `<joint .../>` and detect a genuinely missing `</joint>` close
        // tag. Prior code fell back to `jend = end`, which silently
        // absorbed every subsequent sibling element (`<link>`, `<joint>`,
        // ...) into the current malformed joint. Now self-closing tags
        // bound `jend` at the `/>`, and a truly unclosed tag (no `</joint>`
        // and no self-close `/>` inside the open tag) signals end-of-input
        // for that joint and stops the scan to avoid silent absorption.
        const char *open_end_tag = strchr(jstart, '>');
        // Detect self-close: `/>` immediately precedes the first `>`.
        int self_closed = 0;
        if (open_end_tag && open_end_tag > jstart && *(open_end_tag - 1) == '/') {
            self_closed = 1;
        }
        const char *jend;
        int advance_past_close;
        if (self_closed) {
            // Self-closing joint: `<joint name="..." .../>` — bound jend
            // to the `>` so subsequent siblings are reachable. Advance
            // cursor by 1 (past `>`).
            jend = open_end_tag;
            advance_past_close = 1;
        } else {
            const char *close = strstr(jstart, "</joint>");
            if (!close) {
                // Genuinely malformed: no `</joint>` and not self-closing.
                // Stop scanning to avoid the silent-absorption hazard.
                break;
            }
            jend = close;
            advance_past_close = 8;  // strlen("</joint>")
        }

        // Grow joints array if needed.
        if (u->n_joints >= u->cap_joints) {
            u->cap_joints *= 2;
            u->joints = (_URDFJoint *)realloc(u->joints,
                                              u->cap_joints * sizeof(_URDFJoint));
        }
        _URDFJoint *j = &u->joints[u->n_joints];
        memset(j, 0, sizeof(*j));
        // Audit fix CRIT-LAYER9B-001 (CRITICAL, 2026-05-08): URDF spec
        // default joint axis is `(1, 0, 0)` (x-axis) per
        // http://wiki.ros.org/urdf/XML/joint — prior `(0, 0, 1)` produced
        // wrong FK end-effector poses for any URDF lacking explicit
        // `<axis>`. Now matches spec and ROS robot_description loaders.
        j->axis[0] = 1.0;
        j->joint_type = _URDF_REVOLUTE;

        // Parse name + type from the joint opening tag.
        const char *open_close = strchr(jstart, '>');
        if (!open_close || open_close > jend) { cursor = jend + advance_past_close; continue; }
        char buf[128];
        if (_find_attr(jstart - 1, open_close, "name", buf, sizeof(buf))) {
            _copy_attr_value(j->name, (int)sizeof(j->name), buf);
        }
        if (_find_attr(jstart - 1, open_close, "type", buf, sizeof(buf))) {
            if (strcmp(buf, "revolute") == 0 || strcmp(buf, "continuous") == 0)
                j->joint_type = _URDF_REVOLUTE;
            else if (strcmp(buf, "prismatic") == 0)
                j->joint_type = _URDF_PRISMATIC;
            else if (strcmp(buf, "fixed") == 0)
                j->joint_type = _URDF_FIXED;
        }

        // <origin xyz="..." rpy="..."/>
        const char *org = _find_elem(open_close, jend, "origin");
        if (org) {
            const char *org_close = strchr(org, '>');
            if (org_close && org_close < jend) {
                if (_find_attr(org - 1, org_close, "xyz", buf, sizeof(buf))) {
                    _parse_3d(buf, j->xyz);
                }
                if (_find_attr(org - 1, org_close, "rpy", buf, sizeof(buf))) {
                    _parse_3d(buf, j->rpy);
                }
            }
        }
        // <axis xyz="..."/>
        const char *ax = _find_elem(open_close, jend, "axis");
        if (ax) {
            const char *ax_close = strchr(ax, '>');
            if (ax_close && ax_close < jend) {
                if (_find_attr(ax - 1, ax_close, "xyz", buf, sizeof(buf))) {
                    _parse_3d(buf, j->axis);
                }
            }
        }
        // <parent link="..."/> and <child link="..."/>
        const char *par = _find_elem(open_close, jend, "parent");
        if (par) {
            const char *par_close = strchr(par, '>');
            if (par_close && par_close < jend) {
                if (_find_attr(par - 1, par_close, "link", buf, sizeof(buf))) {
                    j->has_parent_link = _copy_attr_value(j->parent_link,
                        (int)sizeof(j->parent_link), buf);
                }
            }
        }
        const char *child = _find_elem(open_close, jend, "child");
        if (child) {
            const char *child_close = strchr(child, '>');
            if (child_close && child_close < jend) {
                if (_find_attr(child - 1, child_close, "link", buf, sizeof(buf))) {
                    j->has_child_link = _copy_attr_value(j->child_link,
                        (int)sizeof(j->child_link), buf);
                }
            }
        }
        // <limit lower="..." upper="..."/>
        const char *lim = _find_elem(open_close, jend, "limit");
        if (lim) {
            const char *lim_close = strchr(lim, '>');
            if (lim_close && lim_close < jend) {
                if (_find_attr(lim - 1, lim_close, "lower", buf, sizeof(buf))) {
                    j->lo = strtod(buf, NULL);
                    j->has_limit = 1;
                }
                if (_find_attr(lim - 1, lim_close, "upper", buf, sizeof(buf))) {
                    j->hi = strtod(buf, NULL);
                    j->has_limit = 1;
                }
            }
        }

        u->n_joints++;
        parsed++;
        cursor = jend + advance_past_close;  // past "</joint>" or past "/>"
    }
    return (long long)parsed;
}

long long nuc_urdf_joint_count(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    return u ? (long long)u->n_joints : 0;
}

long long nuc_urdf_joint_type(long long h, long long i) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints) return -1;
    return (long long)u->joints[i].joint_type;
}

long long nuc_urdf_joint_axis(long long h, long long i, long long dim) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints || dim < 0 || dim > 2) return _f2i(0.0);
    return _f2i(u->joints[i].axis[dim]);
}

long long nuc_urdf_joint_origin_xyz(long long h, long long i, long long dim) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints || dim < 0 || dim > 2) return _f2i(0.0);
    return _f2i(u->joints[i].xyz[dim]);
}

long long nuc_urdf_joint_origin_rpy(long long h, long long i, long long dim) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints || dim < 0 || dim > 2) return _f2i(0.0);
    return _f2i(u->joints[i].rpy[dim]);
}

long long nuc_urdf_joint_limit_lo(long long h, long long i) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints) return _f2i(0.0);
    return _f2i(u->joints[i].lo);
}

long long nuc_urdf_joint_limit_hi(long long h, long long i) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints) return _f2i(0.0);
    return _f2i(u->joints[i].hi);
}

long long nuc_urdf_joint_has_limit(long long h, long long i) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u || i < 0 || i >= (long long)u->n_joints) return 0;
    return (long long)u->joints[i].has_limit;
}

long long nuc_urdf_has_topology(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    return _topology_available(u) ? 1LL : 0LL;
}

long long nuc_urdf_joint_parent_index(long long h, long long i) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    return (long long)_joint_parent_index(u, (int)i);
}

long long nuc_urdf_joint_child_count(long long h, long long parent_index) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    return (long long)_joint_child_count(u, (int)parent_index);
}

long long nuc_urdf_has_branching(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    return _has_branching(u) ? 1LL : 0LL;
}

long long nuc_urdf_topology_is_serial(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    return _topology_is_serial(u) ? 1LL : 0LL;
}

// === FK chain integration ===
//
// Forward-declare the FK chain runtime symbols (defined in
// fk_chain_rt.c). The URDF rod imports fk_chain.nr so they get
// linked in.
long long nuc_fk_chain_new(void);
long long nuc_fk_chain_add_joint(
    long long ch, long long joint_type,
    long long off_x_bits, long long off_y_bits, long long off_z_bits,
    long long off_qw_bits, long long off_qx_bits, long long off_qy_bits, long long off_qz_bits,
    long long axis_x_bits, long long axis_y_bits, long long axis_z_bits);

static long long _append_fk_joint(long long ch, _URDFJoint *j) {
    double q[4];
    _rpy_to_quat(j->rpy[0], j->rpy[1], j->rpy[2], q);
    return nuc_fk_chain_add_joint(ch,
        (long long)j->joint_type,
        _f2i(j->xyz[0]), _f2i(j->xyz[1]), _f2i(j->xyz[2]),
        _f2i(q[0]), _f2i(q[1]), _f2i(q[2]), _f2i(q[3]),
        _f2i(j->axis[0]), _f2i(j->axis[1]), _f2i(j->axis[2]));
}

// Build an FK chain handle from the parsed URDF, treating the
// joint sequence as a serial chain. When parent/child link metadata
// is available, serial trees are ordered by topology and branching
// or forest topologies are refused instead of silently flattened.
// Returns the FK chain handle, or 0 on failure/refused topology.
long long nuc_urdf_to_fk_chain(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u) return 0;
    int topo = _topology_available(u);
    if (topo && !_topology_is_serial(u)) return 0;
    long long ch = nuc_fk_chain_new();
    if (!ch) return 0;
    if (!topo) {
        for (int i = 0; i < u->n_joints; i++) {
            _append_fk_joint(ch, &u->joints[i]);
        }
    } else {
        int cur = _first_child_index(u, -1);
        while (cur >= 0) {
            _append_fk_joint(ch, &u->joints[cur]);
            cur = _first_child_index(u, cur);
        }
    }
    return ch;
}

void nuc_urdf_free(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u) return;
    if (u->joints) free(u->joints);
    free(u);
}
