// tf_rt.c — Hierarchical coordinate-frame transform tree.
//
// ROS-style "tf" tree: each frame has an integer ID, a parent ID,
// and a pose `(t, q)` expressed in the parent frame. The root has
// parent ID = -1. Lookup between any two frames composes
// transforms along the path through the tree.
//
// Convention: each stored pose `(t_i, q_i)` is the transform that
// takes a point in frame `i` to its parent's frame:
//
//   p_parent = q_i · p_i · q_i⁻¹ + t_i
//
// To get from frame `A` to frame `B`:
//
//   T_root_A = compose of (T_A_parent_A, T_parent_A_grand_A, ...) up to root
//   T_root_B = same from B
//   T_AB    = T_root_A⁻¹ · T_root_B
//   p_B     = T_AB⁻¹ · p_A     (or equivalently apply the transform other way)
//
// More precisely, `tf_lookup(source, target, t_out, q_out)` writes
// the pose of `target` expressed in `source`'s frame, i.e. the
// transform that takes a point known in `target` and gives its
// coordinates in `source`. This matches ROS `lookupTransform(source,
// target)` semantics.
//
// Workflow:
//   1. nuc_tf_new(max_frames)
//   2. nuc_tf_add_frame(h, frame_id, parent_id, t_ptr, q_ptr) for each
//      (root: parent_id = -1)
//   3. nuc_tf_set_pose(h, frame_id, t_ptr, q_ptr) to update poses live
//   4. nuc_tf_lookup(h, source_id, target_id, t_out_ptr, q_out_ptr)
//   5. nuc_tf_free(h)
//
// Limitations (string-keyed frames / time-stamped buffer / lazy
// caching land in v0.6 if needed):
// - Integer frame IDs only — caller manages name→id mapping. Use
//   the `hashmap_str.nr` rod for the mapping.
// - Single tree only (no disconnected forest). Frames whose parent
//   chain doesn't reach the root return failure on lookup.
// - No time stamps or interpolation buffer. For temporally-evolving
//   transforms use `nuc_tf_set_pose` between calls.
// - Brute-force ancestor walk per lookup: `O(depth)`. For very deep
//   trees consider caching the world-space pose per frame externally.
//
// Compile: clang -c stdlib/runtime/tf_rt.c -o target/tf.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct {
    int parent;       // -1 if root
    int registered;   // 1 if this slot is in use
    double t[3];
    double q[4];      // unit quaternion (w, x, y, z)
    int stamp_valid;
    double stamp;
    int prev_valid;
    double prev_stamp;
    double prev_t[3];
    double prev_q[4];
} _TFFrame;

typedef struct {
    int max_frames;
    _TFFrame *frames;
} NTF;

static void _q_normalize(double *q) {
    double n = sqrt(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3]);
    if (n > 1e-12) { q[0]/=n; q[1]/=n; q[2]/=n; q[3]/=n; }
    else { q[0]=1; q[1]=q[2]=q[3]=0; }
}
static void _q_mul(const double *a, const double *b, double *o) {
    o[0] = a[0]*b[0] - a[1]*b[1] - a[2]*b[2] - a[3]*b[3];
    o[1] = a[0]*b[1] + a[1]*b[0] + a[2]*b[3] - a[3]*b[2];
    o[2] = a[0]*b[2] - a[1]*b[3] + a[2]*b[0] + a[3]*b[1];
    o[3] = a[0]*b[3] + a[1]*b[2] - a[2]*b[1] + a[3]*b[0];
}
static void _q_conj(const double *q, double *o) {
    o[0]=q[0]; o[1]=-q[1]; o[2]=-q[2]; o[3]=-q[3];
}
static void _q_rotate(const double *q, const double *v, double *o) {
    double tx = 2.0*(q[2]*v[2] - q[3]*v[1]);
    double ty = 2.0*(q[3]*v[0] - q[1]*v[2]);
    double tz = 2.0*(q[1]*v[1] - q[2]*v[0]);
    o[0] = v[0] + q[0]*tx + (q[2]*tz - q[3]*ty);
    o[1] = v[1] + q[0]*ty + (q[3]*tx - q[1]*tz);
    o[2] = v[2] + q[0]*tz + (q[1]*ty - q[2]*tx);
}
// T_out = T1 * T2  (apply T2 first)
static void _se3_compose(const double *t1, const double *q1,
                          const double *t2, const double *q2,
                          double *t_out, double *q_out)
{
    double t2_rot[3];
    _q_rotate(q1, t2, t2_rot);
    t_out[0] = t2_rot[0] + t1[0];
    t_out[1] = t2_rot[1] + t1[1];
    t_out[2] = t2_rot[2] + t1[2];
    _q_mul(q1, q2, q_out);
    _q_normalize(q_out);
}
// T_inv = T^-1
static void _se3_inverse(const double *t, const double *q, double *t_out, double *q_out) {
    double q_inv[4]; _q_conj(q, q_inv);
    double neg_t[3] = { -t[0], -t[1], -t[2] };
    _q_rotate(q_inv, neg_t, t_out);
    q_out[0] = q_inv[0]; q_out[1] = q_inv[1]; q_out[2] = q_inv[2]; q_out[3] = q_inv[3];
}

static void _q_nlerp(const double *a, const double *b, double u, double *out) {
    double bb[4] = { b[0], b[1], b[2], b[3] };
    double dot = a[0]*bb[0] + a[1]*bb[1] + a[2]*bb[2] + a[3]*bb[3];
    if (dot < 0.0) {
        bb[0] = -bb[0]; bb[1] = -bb[1]; bb[2] = -bb[2]; bb[3] = -bb[3];
    }
    out[0] = a[0] + u * (bb[0] - a[0]);
    out[1] = a[1] + u * (bb[1] - a[1]);
    out[2] = a[2] + u * (bb[2] - a[2]);
    out[3] = a[3] + u * (bb[3] - a[3]);
    _q_normalize(out);
}

static int _frame_pose_at(_TFFrame *f, double stamp, double *t_out, double *q_out) {
    if (!f || !f->registered) return 0;
    if (!f->stamp_valid || !f->prev_valid) {
        t_out[0] = f->t[0]; t_out[1] = f->t[1]; t_out[2] = f->t[2];
        q_out[0] = f->q[0]; q_out[1] = f->q[1]; q_out[2] = f->q[2]; q_out[3] = f->q[3];
        return 1;
    }
    double a = f->prev_stamp, b = f->stamp;
    if (a > b) {
        double tmp = a; a = b; b = tmp;
    }
    if (stamp < a - 1e-9 || stamp > b + 1e-9) return 0;
    double denom = f->stamp - f->prev_stamp;
    double u = (fabs(denom) > 1e-12) ? ((stamp - f->prev_stamp) / denom) : 1.0;
    if (u < 0.0) u = 0.0;
    if (u > 1.0) u = 1.0;
    for (int i = 0; i < 3; i++) {
        t_out[i] = f->prev_t[i] + u * (f->t[i] - f->prev_t[i]);
    }
    _q_nlerp(f->prev_q, f->q, u, q_out);
    return 1;
}

// Walk frame `f` up to root, accumulating into `(t_out, q_out)`
// the transform `T_root_f` such that p_root = T_root_f · p_f.
//
// Iteratively: at each step, T_root_f = T_root_parent · T_parent_f.
// Starting from f, T_root_f = T_root_f.parent · T_parent_f. Going up,
// we accumulate from root downward.
//
// Cleaner: walk DOWN by collecting ancestors first, then compose.
//
// We allocate a small stack of 64 (more than typical robot
// trees ever need); fail returns 0.
//
// Returns 1 on success (writes T_root_f into out), 0 on cycle / disconnect.
static int _root_to_frame(NTF *p, int f, double *t_out, double *q_out) {
    int chain[64];
    int n_chain = 0;
    int cur = f;
    while (cur != -1) {
        if (n_chain >= 64) return 0;     // tree too deep
        if (cur < 0 || cur >= p->max_frames) return 0;
        if (!p->frames[cur].registered) return 0;
        chain[n_chain++] = cur;
        cur = p->frames[cur].parent;
    }
    // chain[0..n_chain-1] = f, parent(f), ..., root.
    // T_root_f = T_root_chain[n-1] (root) · T_chain[n-1]_chain[n-2] · ... · T_chain[1]_chain[0].
    // But for the root, T_root_root = identity. So we start with identity and
    // compose each frame's pose-in-parent right-to-left from root downward.
    t_out[0] = 0; t_out[1] = 0; t_out[2] = 0;
    q_out[0] = 1; q_out[1] = 0; q_out[2] = 0; q_out[3] = 0;
    for (int i = n_chain - 1; i >= 0; i--) {
        int idx = chain[i];
        double t_new[3], q_new[4];
        _se3_compose(t_out, q_out,
                      p->frames[idx].t, p->frames[idx].q,
                      t_new, q_new);
        t_out[0] = t_new[0]; t_out[1] = t_new[1]; t_out[2] = t_new[2];
        q_out[0] = q_new[0]; q_out[1] = q_new[1]; q_out[2] = q_new[2]; q_out[3] = q_new[3];
    }
    return 1;
}

static int _root_to_frame_at(NTF *p, int f, double stamp, double *t_out, double *q_out) {
    int chain[64];
    int n_chain = 0;
    int cur = f;
    while (cur != -1) {
        if (n_chain >= 64) return 0;
        if (cur < 0 || cur >= p->max_frames) return 0;
        if (!p->frames[cur].registered) return 0;
        chain[n_chain++] = cur;
        cur = p->frames[cur].parent;
    }
    t_out[0] = 0; t_out[1] = 0; t_out[2] = 0;
    q_out[0] = 1; q_out[1] = 0; q_out[2] = 0; q_out[3] = 0;
    for (int i = n_chain - 1; i >= 0; i--) {
        int idx = chain[i];
        double tf_t[3], tf_q[4];
        if (!_frame_pose_at(&p->frames[idx], stamp, tf_t, tf_q)) return 0;
        double t_new[3], q_new[4];
        _se3_compose(t_out, q_out, tf_t, tf_q, t_new, q_new);
        t_out[0] = t_new[0]; t_out[1] = t_new[1]; t_out[2] = t_new[2];
        q_out[0] = q_new[0]; q_out[1] = q_new[1]; q_out[2] = q_new[2]; q_out[3] = q_new[3];
    }
    return 1;
}

// === API ===

long long nuc_tf_new(long long max_frames_) {
    int n = (int)max_frames_;
    if (n <= 0) return 0;
    NTF *p = (NTF *)calloc(1, sizeof(NTF));
    p->max_frames = n;
    p->frames = (_TFFrame *)calloc(n, sizeof(_TFFrame));
    return (long long)(size_t)p;
}

// Add (or re-add) a frame with given parent and pose-in-parent.
// `t_ptr` is double[3], `q_ptr` is double[4]. parent_id = -1 for root.
// Returns 1 on success, 0 on bad input.
long long nuc_tf_add_frame(long long h, long long frame_id_, long long parent_id_,
                            long long t_ptr, long long q_ptr)
{
    NTF *p = (NTF *)(void *)(size_t)h;
    if (!p) return 0;
    int fid = (int)frame_id_, pid = (int)parent_id_;
    if (fid < 0 || fid >= p->max_frames) return 0;
    if (pid != -1 && (pid < 0 || pid >= p->max_frames || !p->frames[pid].registered)) return 0;
    if (fid == pid) return 0;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (!t || !q) return 0;
    p->frames[fid].registered = 1;
    p->frames[fid].parent = pid;
    p->frames[fid].t[0] = t[0]; p->frames[fid].t[1] = t[1]; p->frames[fid].t[2] = t[2];
    p->frames[fid].q[0] = q[0]; p->frames[fid].q[1] = q[1];
    p->frames[fid].q[2] = q[2]; p->frames[fid].q[3] = q[3];
    _q_normalize(p->frames[fid].q);
    p->frames[fid].stamp_valid = 0;
    p->frames[fid].prev_valid = 0;
    return 1;
}

long long nuc_tf_add_frame_at(long long h, long long frame_id_, long long parent_id_,
                              long long stamp_b, long long t_ptr, long long q_ptr)
{
    long long ok = nuc_tf_add_frame(h, frame_id_, parent_id_, t_ptr, q_ptr);
    if (!ok) return 0;
    NTF *p = (NTF *)(void *)(size_t)h;
    int fid = (int)frame_id_;
    p->frames[fid].stamp = 0.0;
    memcpy(&p->frames[fid].stamp, &stamp_b, sizeof(double));
    p->frames[fid].stamp_valid = 1;
    p->frames[fid].prev_valid = 0;
    return 1;
}

// Update pose of an already-registered frame.
long long nuc_tf_set_pose(long long h, long long frame_id_,
                            long long t_ptr, long long q_ptr)
{
    NTF *p = (NTF *)(void *)(size_t)h;
    if (!p) return 0;
    int fid = (int)frame_id_;
    if (fid < 0 || fid >= p->max_frames || !p->frames[fid].registered) return 0;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (!t || !q) return 0;
    p->frames[fid].t[0] = t[0]; p->frames[fid].t[1] = t[1]; p->frames[fid].t[2] = t[2];
    p->frames[fid].q[0] = q[0]; p->frames[fid].q[1] = q[1];
    p->frames[fid].q[2] = q[2]; p->frames[fid].q[3] = q[3];
    _q_normalize(p->frames[fid].q);
    p->frames[fid].stamp_valid = 0;
    p->frames[fid].prev_valid = 0;
    return 1;
}

long long nuc_tf_set_pose_at(long long h, long long frame_id_, long long stamp_b,
                             long long t_ptr, long long q_ptr)
{
    NTF *p = (NTF *)(void *)(size_t)h;
    if (!p) return 0;
    int fid = (int)frame_id_;
    if (fid < 0 || fid >= p->max_frames || !p->frames[fid].registered) return 0;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (!t || !q) return 0;

    _TFFrame *f = &p->frames[fid];
    if (f->stamp_valid) {
        f->prev_valid = 1;
        f->prev_stamp = f->stamp;
        f->prev_t[0] = f->t[0]; f->prev_t[1] = f->t[1]; f->prev_t[2] = f->t[2];
        f->prev_q[0] = f->q[0]; f->prev_q[1] = f->q[1];
        f->prev_q[2] = f->q[2]; f->prev_q[3] = f->q[3];
    }
    f->stamp = 0.0;
    memcpy(&f->stamp, &stamp_b, sizeof(double));
    f->stamp_valid = 1;
    f->t[0] = t[0]; f->t[1] = t[1]; f->t[2] = t[2];
    f->q[0] = q[0]; f->q[1] = q[1]; f->q[2] = q[2]; f->q[3] = q[3];
    _q_normalize(f->q);
    return 1;
}

// Lookup the pose of `target` expressed in `source`'s frame.
// Writes the resulting transform to (t_out, q_out). ROS semantics:
// `T_source_target` such that `p_source = T_source_target · p_target`.
//
// Returns 1 on success, 0 if either frame is unregistered or
// disconnected from the tree.
long long nuc_tf_lookup(long long h, long long source_id_, long long target_id_,
                         long long t_out_ptr, long long q_out_ptr)
{
    NTF *p = (NTF *)(void *)(size_t)h;
    if (!p) return 0;
    int s = (int)source_id_, t_id = (int)target_id_;
    if (s < 0 || s >= p->max_frames || !p->frames[s].registered) return 0;
    if (t_id < 0 || t_id >= p->max_frames || !p->frames[t_id].registered) return 0;
    double *t_out = (double *)(void *)(size_t)t_out_ptr;
    double *q_out = (double *)(void *)(size_t)q_out_ptr;
    if (!t_out || !q_out) return 0;

    double t_src_root[3], q_src_root[4];
    double t_tgt_root[3], q_tgt_root[4];
    if (!_root_to_frame(p, s,    t_src_root, q_src_root)) return 0;
    if (!_root_to_frame(p, t_id, t_tgt_root, q_tgt_root)) return 0;
    // T_source_target = T_root_source⁻¹ · T_root_target
    double t_src_inv[3], q_src_inv[4];
    _se3_inverse(t_src_root, q_src_root, t_src_inv, q_src_inv);
    _se3_compose(t_src_inv, q_src_inv, t_tgt_root, q_tgt_root, t_out, q_out);
    return 1;
}

long long nuc_tf_lookup_at(long long h, long long source_id_, long long target_id_,
                           long long stamp_b, long long t_out_ptr, long long q_out_ptr)
{
    NTF *p = (NTF *)(void *)(size_t)h;
    if (!p) return 0;
    int s = (int)source_id_, t_id = (int)target_id_;
    if (s < 0 || s >= p->max_frames || !p->frames[s].registered) return 0;
    if (t_id < 0 || t_id >= p->max_frames || !p->frames[t_id].registered) return 0;
    double *t_out = (double *)(void *)(size_t)t_out_ptr;
    double *q_out = (double *)(void *)(size_t)q_out_ptr;
    if (!t_out || !q_out) return 0;
    double stamp = 0.0;
    memcpy(&stamp, &stamp_b, sizeof(double));

    double t_src_root[3], q_src_root[4];
    double t_tgt_root[3], q_tgt_root[4];
    if (!_root_to_frame_at(p, s,    stamp, t_src_root, q_src_root)) return 0;
    if (!_root_to_frame_at(p, t_id, stamp, t_tgt_root, q_tgt_root)) return 0;
    double t_src_inv[3], q_src_inv[4];
    _se3_inverse(t_src_root, q_src_root, t_src_inv, q_src_inv);
    _se3_compose(t_src_inv, q_src_inv, t_tgt_root, q_tgt_root, t_out, q_out);
    return 1;
}

void nuc_tf_free(long long h) {
    NTF *p = (NTF *)(void *)(size_t)h;
    if (!p) return;
    if (p->frames) free(p->frames);
    free(p);
}
