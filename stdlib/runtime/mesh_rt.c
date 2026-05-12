// mesh_rt.c — Triangular Mesh for FEM for Nucleor
// Structured mesh generation, stiffness assembly, VTK export.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/mesh_rt.c -o target/mesh_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ms_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ms_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } MSVec;

typedef struct {
    int n_nodes, n_elements;
    double *node_x, *node_y;
    int *elem;  // flat [n_elements * 3] — triangle vertices
    int *boundary; // 1 if boundary node
    int Nx, Ny;  // grid dimensions
} Mesh;

// ================================================================
//  Generate structured rectangular mesh (quad → 2 triangles each)
// ================================================================

long long nuc_mesh_rect(long long Nx, long long Ny, long long Lx_bits, long long Ly_bits) {
    int nx = (int)Nx, ny = (int)Ny;
    double Lx = _ms_i2f(Lx_bits), Ly = _ms_i2f(Ly_bits);
    int nn = (nx + 1) * (ny + 1);
    int ne = nx * ny * 2;

    Mesh *m = (Mesh *)calloc(1, sizeof(Mesh));
    m->n_nodes = nn; m->n_elements = ne;
    m->Nx = nx; m->Ny = ny;
    m->node_x = (double *)malloc(nn * sizeof(double));
    m->node_y = (double *)malloc(nn * sizeof(double));
    m->elem = (int *)malloc(ne * 3 * sizeof(int));
    m->boundary = (int *)calloc(nn, sizeof(int));

    double dx = Lx / nx, dy = Ly / ny;
    for (int j = 0; j <= ny; j++) {
        for (int i = 0; i <= nx; i++) {
            int idx = j * (nx + 1) + i;
            m->node_x[idx] = i * dx;
            m->node_y[idx] = j * dy;
            if (i == 0 || i == nx || j == 0 || j == ny) m->boundary[idx] = 1;
        }
    }

    int ei = 0;
    for (int j = 0; j < ny; j++) {
        for (int i = 0; i < nx; i++) {
            int n0 = j * (nx + 1) + i;
            int n1 = n0 + 1;
            int n2 = (j + 1) * (nx + 1) + i;
            int n3 = n2 + 1;
            // Triangle 1: n0, n1, n3
            m->elem[ei * 3] = n0; m->elem[ei * 3 + 1] = n1; m->elem[ei * 3 + 2] = n3; ei++;
            // Triangle 2: n0, n3, n2
            m->elem[ei * 3] = n0; m->elem[ei * 3 + 1] = n3; m->elem[ei * 3 + 2] = n2; ei++;
        }
    }
    return (long long)m;
}

long long nuc_mesh_n_nodes(long long h) { return ((Mesh *)(void *)h)->n_nodes; }
long long nuc_mesh_n_elements(long long h) { return ((Mesh *)(void *)h)->n_elements; }

long long nuc_mesh_node_x(long long h, long long id) {
    Mesh *m = (Mesh *)(void *)h;
    return _ms_f2i(m->node_x[(int)id]);
}
long long nuc_mesh_node_y(long long h, long long id) {
    Mesh *m = (Mesh *)(void *)h;
    return _ms_f2i(m->node_y[(int)id]);
}

long long nuc_mesh_elem_node(long long h, long long elem_id, long long local) {
    Mesh *m = (Mesh *)(void *)h;
    return m->elem[(int)elem_id * 3 + (int)local];
}

long long nuc_mesh_is_boundary(long long h, long long node_id) {
    return ((Mesh *)(void *)h)->boundary[(int)node_id];
}

// ================================================================
//  Boundary nodes list
// ================================================================

long long nuc_mesh_boundary_nodes(long long h) {
    Mesh *m = (Mesh *)(void *)h;
    MSVec *v = (MSVec *)malloc(sizeof(MSVec));
    v->len = 0; v->cap = m->n_nodes / 4 + 16;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    for (int i = 0; i < m->n_nodes; i++) {
        if (m->boundary[i]) {
            if (v->len >= v->cap) { v->cap *= 2; v->data = (long long *)realloc(v->data, v->cap * sizeof(long long)); }
            v->data[v->len++] = i;
        }
    }
    return (long long)v;
}

// ================================================================
//  Assemble Laplacian stiffness matrix (returns flat Vec [nn*nn])
// ================================================================

long long nuc_mesh_assemble_laplacian(long long h) {
    Mesh *m = (Mesh *)(void *)h;
    int nn = m->n_nodes;
    double *K = (double *)calloc((size_t)nn * nn, sizeof(double));

    for (int e = 0; e < m->n_elements; e++) {
        int n0 = m->elem[e * 3], n1 = m->elem[e * 3 + 1], n2 = m->elem[e * 3 + 2];
        double x0 = m->node_x[n0], y0 = m->node_y[n0];
        double x1 = m->node_x[n1], y1 = m->node_y[n1];
        double x2 = m->node_x[n2], y2 = m->node_y[n2];

        double area2 = fabs((x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0));
        if (area2 < 1e-30) continue;
        double area = area2 * 0.5;

        // Gradient of shape functions
        double b[3], c[3];
        b[0] = y1 - y2; b[1] = y2 - y0; b[2] = y0 - y1;
        c[0] = x2 - x1; c[1] = x0 - x2; c[2] = x1 - x0;

        int nodes[3] = {n0, n1, n2};
        for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++)
                K[nodes[i] * nn + nodes[j]] += (b[i] * b[j] + c[i] * c[j]) / (4 * area);
    }

    MSVec *result = (MSVec *)malloc(sizeof(MSVec));
    result->len = nn * nn; result->cap = result->len;
    result->data = (long long *)malloc(result->len * sizeof(long long));
    for (int i = 0; i < nn * nn; i++) result->data[i] = _ms_f2i(K[i]);
    free(K);
    return (long long)result;
}

// ================================================================
//  Save VTK file (for ParaView visualization)
// ================================================================

void nuc_mesh_save_vtk(long long h, long long field_h, const char *path) {
    Mesh *m = (Mesh *)(void *)h;
    MSVec *field = (MSVec *)(void *)field_h;
    if (!m || !path) return;
    FILE *f = fopen(path, "w");
    if (!f) return;

    fprintf(f, "# vtk DataFile Version 3.0\nNucleor Mesh\nASCII\nDATASET UNSTRUCTURED_GRID\n");
    fprintf(f, "POINTS %d double\n", m->n_nodes);
    for (int i = 0; i < m->n_nodes; i++)
        fprintf(f, "%.10f %.10f 0.0\n", m->node_x[i], m->node_y[i]);

    fprintf(f, "CELLS %d %d\n", m->n_elements, m->n_elements * 4);
    for (int i = 0; i < m->n_elements; i++)
        fprintf(f, "3 %d %d %d\n", m->elem[i * 3], m->elem[i * 3 + 1], m->elem[i * 3 + 2]);

    fprintf(f, "CELL_TYPES %d\n", m->n_elements);
    for (int i = 0; i < m->n_elements; i++) fprintf(f, "5\n");

    if (field && field->len >= m->n_nodes) {
        fprintf(f, "POINT_DATA %d\nSCALARS field double 1\nLOOKUP_TABLE default\n", m->n_nodes);
        for (int i = 0; i < m->n_nodes; i++) fprintf(f, "%.10f\n", _ms_i2f(field->data[i]));
    }
    fclose(f);
}

void nuc_mesh_free(long long h) {
    Mesh *m = (Mesh *)(void *)h;
    if (!m) return;
    free(m->node_x); free(m->node_y); free(m->elem); free(m->boundary); free(m);
}
