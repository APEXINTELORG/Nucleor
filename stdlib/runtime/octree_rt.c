// octree_rt.c — Sparse octree for 3D occupancy grids and broad-
// phase collision pruning.
//
// An octree recursively subdivides 3D space into 8 cube-shaped
// children (octants). For occupancy mapping, each leaf stores
// a binary occupied/free state (or a probability for full
// occupancy-grid SLAM). For collision pruning, the tree's depth
// gives a hierarchical bounding-volume description of the
// occupied space.
//
// This implementation is a straightforward "linear octree":
// nodes stored in a flat array, children referenced by index.
// Insertion and lookup are both O(depth). The resolution at
// the leaf level is `(root_size / 2^max_depth)`.
//
// Foundation for:
// - Occupancy-grid SLAM (octomap-style probabilistic mapping
//   from depth sensors).
// - Collision broad-phase: prune motion-plan checks against a
//   precomputed octree of the static environment.
// - Voxel-based collision detection in cluttered scenes.
//
// Limitations (probabilistic occupancy + log-odds storage +
// raycast-based occupancy update land in v0.6 if needed):
// - Binary occupancy only (occupied / free / unknown).
// - No raycast-based "carve" (clear cells along the ray).
// - No prune-on-merge (sibling cells with same value stay
//   subdivided).
//
// Compile: clang -c stdlib/runtime/octree_rt.c -o target/octree.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define _OCT_UNKNOWN 0
#define _OCT_FREE    1
#define _OCT_OCCUPIED 2

typedef struct {
    int children[8];   // -1 = no child / leaf at this level
    int state;         // _OCT_UNKNOWN / FREE / OCCUPIED
} _OctNode;

typedef struct {
    int n_nodes;
    int cap_nodes;
    _OctNode *nodes;
    double center[3];   // world-frame center of the root cube
    double half_size;   // world-frame half-side of the root cube
    int max_depth;
} NOct;

// Index 0 is the root.
long long nuc_oct_new(
    long long cx_b, long long cy_b, long long cz_b,
    long long half_size_b, long long max_depth)
{
    NOct *o = (NOct *)calloc(1, sizeof(NOct));
    o->cap_nodes = 16;
    o->nodes = (_OctNode *)calloc(o->cap_nodes, sizeof(_OctNode));
    o->n_nodes = 1;  // root
    for (int i = 0; i < 8; i++) o->nodes[0].children[i] = -1;
    o->nodes[0].state = _OCT_UNKNOWN;
    o->center[0] = _i2f(cx_b);
    o->center[1] = _i2f(cy_b);
    o->center[2] = _i2f(cz_b);
    o->half_size = _i2f(half_size_b);
    o->max_depth = (int)max_depth;
    return (long long)(size_t)o;
}

// Compute the child octant index (0-7) for a point relative to a
// node center. Convention: bit 0 = x>cx, bit 1 = y>cy, bit 2 = z>cz.
static int _octant(double px, double py, double pz,
                   double cx, double cy, double cz) {
    int idx = 0;
    if (px > cx) idx |= 1;
    if (py > cy) idx |= 2;
    if (pz > cz) idx |= 4;
    return idx;
}

// Compute a child's center given its parent's center, half-size,
// and the octant index.
static void _child_center(double cx, double cy, double cz, double half,
                          int oct, double *out_cx, double *out_cy, double *out_cz) {
    double q = half * 0.5;
    *out_cx = cx + ((oct & 1) ? q : -q);
    *out_cy = cy + ((oct & 2) ? q : -q);
    *out_cz = cz + ((oct & 4) ? q : -q);
}

// Allocate a new node and return its index.
static int _alloc_node(NOct *o) {
    if (o->n_nodes >= o->cap_nodes) {
        o->cap_nodes *= 2;
        o->nodes = (_OctNode *)realloc(o->nodes, o->cap_nodes * sizeof(_OctNode));
    }
    int idx = o->n_nodes++;
    for (int i = 0; i < 8; i++) o->nodes[idx].children[i] = -1;
    o->nodes[idx].state = _OCT_UNKNOWN;
    return idx;
}

// Insert a point with the given occupancy value (1 = occupied,
// 0 = free). Walks down to the maximum depth, allocating
// intermediate nodes as needed.
long long nuc_oct_insert(long long h, long long x_b, long long y_b, long long z_b,
                        long long occupied)
{
    NOct *o = (NOct *)(void *)(size_t)h;
    if (!o) return -1;
    double px = _i2f(x_b), py = _i2f(y_b), pz = _i2f(z_b);
    // Verify the point is inside the root cube.
    double rcx = o->center[0], rcy = o->center[1], rcz = o->center[2];
    double rh = o->half_size;
    if (px < rcx - rh || px > rcx + rh) return -1;
    if (py < rcy - rh || py > rcy + rh) return -1;
    if (pz < rcz - rh || pz > rcz + rh) return -1;

    int target_state = occupied ? _OCT_OCCUPIED : _OCT_FREE;
    int node_idx = 0;
    double cx = rcx, cy = rcy, cz = rcz;
    double half = rh;
    for (int d = 0; d < o->max_depth; d++) {
        int oct = _octant(px, py, pz, cx, cy, cz);
        int child = o->nodes[node_idx].children[oct];
        if (child < 0) {
            child = _alloc_node(o);
            o->nodes[node_idx].children[oct] = child;
        }
        node_idx = child;
        _child_center(cx, cy, cz, half, oct, &cx, &cy, &cz);
        half *= 0.5;
    }
    o->nodes[node_idx].state = target_state;
    return 0;
}

// Query the occupancy state at a point. Returns:
//   0 = unknown / outside tree
//   1 = free
//   2 = occupied
long long nuc_oct_query(long long h, long long x_b, long long y_b, long long z_b)
{
    NOct *o = (NOct *)(void *)(size_t)h;
    if (!o) return 0;
    double px = _i2f(x_b), py = _i2f(y_b), pz = _i2f(z_b);
    double rcx = o->center[0], rcy = o->center[1], rcz = o->center[2];
    double rh = o->half_size;
    if (px < rcx - rh || px > rcx + rh) return 0;
    if (py < rcy - rh || py > rcy + rh) return 0;
    if (pz < rcz - rh || pz > rcz + rh) return 0;

    int node_idx = 0;
    double cx = rcx, cy = rcy, cz = rcz;
    double half = rh;
    for (int d = 0; d < o->max_depth; d++) {
        int oct = _octant(px, py, pz, cx, cy, cz);
        int child = o->nodes[node_idx].children[oct];
        if (child < 0) {
            // Return the deepest node's state we reached.
            return (long long)o->nodes[node_idx].state;
        }
        node_idx = child;
        _child_center(cx, cy, cz, half, oct, &cx, &cy, &cz);
        half *= 0.5;
    }
    return (long long)o->nodes[node_idx].state;
}

// Total node count (useful for memory diagnostics).
long long nuc_oct_node_count(long long h) {
    NOct *o = (NOct *)(void *)(size_t)h;
    return o ? (long long)o->n_nodes : 0;
}

// Resolution at the leaf level: root_size / 2^max_depth.
long long nuc_oct_leaf_resolution(long long h) {
    NOct *o = (NOct *)(void *)(size_t)h;
    if (!o) return _f2i(0.0);
    double r = (2.0 * o->half_size);
    for (int i = 0; i < o->max_depth; i++) r *= 0.5;
    return _f2i(r);
}

void nuc_oct_free(long long h) {
    NOct *o = (NOct *)(void *)(size_t)h;
    if (!o) return;
    if (o->nodes) free(o->nodes);
    free(o);
}
