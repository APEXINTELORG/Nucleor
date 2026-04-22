// rods/conv — 2D convolutions, pooling, batch norm, dropout (CNN building blocks)
#cfile "../runtime/conv_rt.c"

extern fn nuc_conv2d(input: i64, kernel: i64, C_in: i64, C_out: i64, H: i64, W: i64, kH: i64, kW: i64, stride: i64, pad: i64) -> i64;
extern fn nuc_conv2d_backward(grad_out: i64, input: i64, kernel: i64, C_in: i64, C_out: i64, H: i64, W: i64, kH: i64, kW: i64, stride: i64, pad: i64) -> i64;
extern fn nuc_conv2d_grad_input(h: i64) -> i64;
extern fn nuc_conv2d_grad_kernel(h: i64) -> i64;
extern fn nuc_maxpool2d(input: i64, C: i64, H: i64, W: i64, pool: i64, stride: i64) -> i64;
extern fn nuc_avgpool2d(input: i64, C: i64, H: i64, W: i64, pool: i64, stride: i64) -> i64;
extern fn nuc_batchnorm(x: i64, gamma: i64, beta: i64, mean: i64, var: i64, n: i64) -> i64;
extern fn nuc_dropout(x: i64, rate: i64, training: i64) -> i64;

fn conv_2d(input: i64, kern: i64, C_in: i64, C_out: i64, H: i64, W: i64, kH: i64, kW: i64, stride: i64, pad: i64) -> i64 {
    return nuc_conv2d(input, kern, C_in, C_out, H, W, kH, kW, stride, pad);
}
fn conv_2d_backward(go: i64, inp: i64, kern: i64, C_in: i64, C_out: i64, H: i64, W: i64, kH: i64, kW: i64, stride: i64, pad: i64) -> i64 {
    return nuc_conv2d_backward(go, inp, kern, C_in, C_out, H, W, kH, kW, stride, pad);
}
fn conv_grad_input(h: i64) -> i64 { return nuc_conv2d_grad_input(h); }
fn conv_grad_kernel(h: i64) -> i64 { return nuc_conv2d_grad_kernel(h); }
fn maxpool_2d(inp: i64, C: i64, H: i64, W: i64, pool: i64, stride: i64) -> i64 { return nuc_maxpool2d(inp, C, H, W, pool, stride); }
fn avgpool_2d(inp: i64, C: i64, H: i64, W: i64, pool: i64, stride: i64) -> i64 { return nuc_avgpool2d(inp, C, H, W, pool, stride); }
fn batchnorm(x: i64, gamma: i64, beta: i64, mean: i64, var: i64, n: i64) -> i64 { return nuc_batchnorm(x, gamma, beta, mean, var, n); }
fn dropout(x: i64, rate: i64, training: i64) -> i64 { return nuc_dropout(x, rate, training); }
