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
//     ... (parent/child/dynamics ignored — see limitations)
//   </joint>
//
// **Limitations** (the v0.5 ship is intentionally minimal; the
// follow-on URDF compliance pass lands in v0.6):
// - Linear-chain assumption: joints are loaded in source order
//   from base to tip; <parent>/<child> link relationships are
//   *not* used to reconstruct the topology. Branching trees
//   (e.g., humanoid robots) are flattened to the source-order
//   sequence — wrong for those, fine for serial arms.
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
        // Find the joint element's closing `</joint>` or `/>` (self-closing — rare).
        const char *jend = strstr(jstart, "</joint>");
        if (!jend) jend = end;

        // Grow joints array if needed.
        if (u->n_joints >= u->cap_joints) {
            u->cap_joints *= 2;
            u->joints = (_URDFJoint *)realloc(u->joints,
                                              u->cap_joints * sizeof(_URDFJoint));
        }
        _URDFJoint *j = &u->joints[u->n_joints];
        memset(j, 0, sizeof(*j));
        // Defaults: identity transform, z-axis revolute.
        j->axis[2] = 1.0;
        j->joint_type = _URDF_REVOLUTE;

        // Parse name + type from the joint opening tag.
        const char *open_close = strchr(jstart, '>');
        if (!open_close || open_close > jend) { cursor = jend + 8; continue; }
        char buf[128];
        if (_find_attr(jstart - 1, open_close, "name", buf, sizeof(buf))) {
            int nlen = (int)strlen(buf);
            if (nlen >= (int)sizeof(j->name)) nlen = sizeof(j->name) - 1;
            memcpy(j->name, buf, nlen); j->name[nlen] = '\0';
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
        cursor = jend + 8;  // past "</joint>"
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

// Build an FK chain handle from the parsed URDF, treating the
// joint sequence as a serial chain (linear-topology assumption).
// Returns the FK chain handle, or 0 on failure.
long long nuc_urdf_to_fk_chain(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u) return 0;
    long long ch = nuc_fk_chain_new();
    if (!ch) return 0;
    for (int i = 0; i < u->n_joints; i++) {
        _URDFJoint *j = &u->joints[i];
        double q[4];
        _rpy_to_quat(j->rpy[0], j->rpy[1], j->rpy[2], q);
        // Map URDF joint type → FK joint type. URDF "revolute" /
        // "continuous" → FK_REVOLUTE (0); URDF "prismatic" → 1;
        // URDF "fixed" → 2.
        nuc_fk_chain_add_joint(ch,
            (long long)j->joint_type,
            _f2i(j->xyz[0]), _f2i(j->xyz[1]), _f2i(j->xyz[2]),
            _f2i(q[0]), _f2i(q[1]), _f2i(q[2]), _f2i(q[3]),
            _f2i(j->axis[0]), _f2i(j->axis[1]), _f2i(j->axis[2]));
    }
    return ch;
}

void nuc_urdf_free(long long h) {
    NURDF *u = (NURDF *)(void *)(size_t)h;
    if (!u) return;
    if (u->joints) free(u->joints);
    free(u);
}
