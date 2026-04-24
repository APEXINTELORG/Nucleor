// rods/ahrs — verify rod wrapper compiles + links (v0.2.261 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (stationary IMU recovers identity orientation; tilted IMU
// converges to true tilt; gyro-only integration matches analytic
// quaternion).
import "stdlib/rods/ahrs.nr"

fn main() -> i64 {
    print("OK ahrs_smoke");
    return 0;
}
