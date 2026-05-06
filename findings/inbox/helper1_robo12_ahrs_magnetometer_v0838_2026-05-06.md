# Helper1 ROBO-12 AHRS Magnetometer Yaw Correction (v0838, 2026-05-06)

## Summary

ROBO-12 Phase 1 is implemented. The AHRS rod now exposes a 9-DOF Mahony update
path:

```nucleor
ahrs_update_mag(h, gyro_ptr, accel_ptr, mag_ptr, dt_bits)
```

The runtime uses the existing accelerometer tilt correction and adds a
magnetometer heading correction. The magnetometer contract is intentionally
explicit: callers provide a calibrated body-frame magnetic vector, and the
runtime treats world +X as the reference magnetic field.

## Files Changed

- `stdlib/runtime/ahrs_rt.c`
- `stdlib/rods/ahrs.nr`
- `tests/features/ahrs_magnetometer_yaw_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

Direct build/run:

```powershell
.\bin\nucleor.exe build tests\features\ahrs_magnetometer_yaw_smoke.nr -o helper1_ahrs_mag_yaw --no-cache
.\target\helper1_ahrs_mag_yaw.exe
```

Focused verify:

```bash
bash tools/verify.sh --only "test features/ahrs_magnetometer_yaw_smoke"
bash tools/verify.sh --only "test features/ahrs_smoke"
bash tools/verify.sh --only "test features/robo_limitations_smoke"
```

All focused fixture runs passed.

## Remaining Work

This does not claim full production inertial navigation closure. Remaining
ROBO-12 gaps:

- local magnetic declination and calibration helpers;
- stronger high-dynamics accel/mag rejection policy;
- Madgwick filter variant;
- real sensor-noise and bias model validation.
