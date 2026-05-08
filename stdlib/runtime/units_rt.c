// units_rt.c — Physical Unit Conversion for Nucleor
// Length, mass, time, temperature, pressure, energy, force, frequency.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/units_rt.c -o target/units_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _un_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _un_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// Unit IDs
#define U_M   1   // meters
#define U_KM  2   // kilometers
#define U_CM  3   // centimeters
#define U_MM  4   // millimeters
#define U_IN  5   // inches
#define U_FT  6   // feet
#define U_MI  7   // miles
#define U_KG  10  // kilograms
#define U_G   11  // grams
#define U_LB  12  // pounds
#define U_OZ  13  // ounces
#define U_S   20  // seconds
#define U_MS  21  // milliseconds
#define U_US  22  // microseconds
#define U_MIN 23  // minutes
#define U_HR  24  // hours
#define U_DAY 25  // days
#define U_K   30  // Kelvin
#define U_C   31  // Celsius
#define U_F   32  // Fahrenheit
#define U_PA  40  // Pascal
#define U_KPA 41  // kiloPascal
#define U_ATM 42  // atmospheres
#define U_BAR 43  // bar
#define U_PSI 44  // psi
#define U_J   50  // Joules
#define U_KJ  51  // kiloJoules
#define U_CAL 52  // calories
#define U_EV  53  // electron volts
#define U_KWH 54  // kilowatt-hours
#define U_N   60  // Newtons
#define U_KN  61  // kiloNewtons
#define U_LBF 62  // pound-force
#define U_HZ  70  // Hertz
#define U_KHZ 71  // kiloHertz
#define U_MHZ 72  // megaHertz
#define U_GHZ 73  // gigaHertz
#define U_RAD 80  // radians
#define U_DEG 81  // degrees
#define U_V   90  // Volts
#define U_MV  91  // milliVolts
#define U_A   92  // Amperes
#define U_MA  93  // milliAmperes

static double to_si(double val, int unit) {
    switch (unit) {
        case U_M: return val;
        case U_KM: return val * 1000;
        case U_CM: return val * 0.01;
        case U_MM: return val * 0.001;
        case U_IN: return val * 0.0254;
        case U_FT: return val * 0.3048;
        case U_MI: return val * 1609.344;
        case U_KG: return val;
        case U_G:  return val * 0.001;
        case U_LB: return val * 0.45359237;
        case U_OZ: return val * 0.028349523;
        case U_S:  return val;
        case U_MS: return val * 0.001;
        case U_US: return val * 1e-6;
        case U_MIN: return val * 60;
        case U_HR: return val * 3600;
        case U_DAY: return val * 86400;
        case U_K:  return val;
        case U_C:  return val + 273.15;
        case U_F:  return (val - 32) * 5.0 / 9.0 + 273.15;
        case U_PA: return val;
        case U_KPA: return val * 1000;
        case U_ATM: return val * 101325;
        case U_BAR: return val * 100000;
        case U_PSI: return val * 6894.757;
        case U_J:  return val;
        case U_KJ: return val * 1000;
        case U_CAL: return val * 4.184;
        case U_EV: return val * 1.602176634e-19;
        case U_KWH: return val * 3600000;
        case U_N:  return val;
        case U_KN: return val * 1000;
        case U_LBF: return val * 4.448222;
        case U_HZ: return val;
        case U_KHZ: return val * 1000;
        case U_MHZ: return val * 1e6;
        case U_GHZ: return val * 1e9;
        case U_RAD: return val;
        case U_DEG: return val * 3.14159265358979323846 / 180.0;
        case U_V:  return val;
        case U_MV: return val * 0.001;
        case U_A:  return val;
        case U_MA: return val * 0.001;
        default: return val;
    }
}

static double from_si(double si_val, int unit) {
    switch (unit) {
        case U_M: return si_val;
        case U_KM: return si_val / 1000;
        case U_CM: return si_val / 0.01;
        case U_MM: return si_val / 0.001;
        case U_IN: return si_val / 0.0254;
        case U_FT: return si_val / 0.3048;
        case U_MI: return si_val / 1609.344;
        case U_KG: return si_val;
        case U_G:  return si_val / 0.001;
        case U_LB: return si_val / 0.45359237;
        case U_OZ: return si_val / 0.028349523;
        case U_S:  return si_val;
        case U_MS: return si_val / 0.001;
        case U_US: return si_val / 1e-6;
        case U_MIN: return si_val / 60;
        case U_HR: return si_val / 3600;
        case U_DAY: return si_val / 86400;
        case U_K:  return si_val;
        case U_C:  return si_val - 273.15;
        case U_F:  return (si_val - 273.15) * 9.0 / 5.0 + 32;
        case U_PA: return si_val;
        case U_KPA: return si_val / 1000;
        case U_ATM: return si_val / 101325;
        case U_BAR: return si_val / 100000;
        case U_PSI: return si_val / 6894.757;
        case U_J:  return si_val;
        case U_KJ: return si_val / 1000;
        case U_CAL: return si_val / 4.184;
        case U_EV: return si_val / 1.602176634e-19;
        case U_KWH: return si_val / 3600000;
        case U_N:  return si_val;
        case U_KN: return si_val / 1000;
        case U_LBF: return si_val / 4.448222;
        case U_HZ: return si_val;
        case U_KHZ: return si_val / 1000;
        case U_MHZ: return si_val / 1e6;
        case U_GHZ: return si_val / 1e9;
        case U_RAD: return si_val;
        case U_DEG: return si_val * 180.0 / 3.14159265358979323846;
        case U_V:  return si_val;
        case U_MV: return si_val / 0.001;
        case U_A:  return si_val;
        case U_MA: return si_val / 0.001;
        default: return si_val;
    }
}

// Lane 6 / F-NUM-002 (audit 2026-05-08): wire SI dimensional check
// into the conversion path. Pre-fix `nuc_unit_convert(100, Pa, m)`
// silently returned 100. RFC-0005 §1 explicitly motivates catching
// the Mars Climate Orbiter bug class — the runtime now does so by
// rejecting cross-dimensional conversions with diagnostic
// `UNIT-DIM-001`.
//
// `unit_category` returns the SI dimension category for each known
// unit ID. Two units may be converted iff they share a category.
// The integer ranges follow the U_* macros above (length=1..7,
// mass=10..13, time=20..25, temperature=30..32, pressure=40..44,
// energy=50..54, force=60..62, frequency=70..73, angle=80..81,
// voltage=90..91, current=92..93). Ranges are mutually exclusive
// (kept disjoint as the unit table grows).
//
// Categories:
//   1 = length, 2 = mass, 3 = time, 4 = temperature, 5 = pressure,
//   6 = energy, 7 = force, 8 = frequency, 9 = angle, 10 = voltage,
//   11 = current, 0 = unknown.
static int unit_category(int u) {
    if (u >= 1 && u <= 7)   return 1;   // length
    if (u >= 10 && u <= 13) return 2;   // mass
    if (u >= 20 && u <= 25) return 3;   // time
    if (u >= 30 && u <= 32) return 4;   // temperature
    if (u >= 40 && u <= 44) return 5;   // pressure
    if (u >= 50 && u <= 54) return 6;   // energy
    if (u >= 60 && u <= 62) return 7;   // force
    if (u >= 70 && u <= 73) return 8;   // frequency
    if (u >= 80 && u <= 81) return 9;   // angle
    if (u >= 90 && u <= 91) return 10;  // voltage
    if (u >= 92 && u <= 93) return 11;  // current
    return 0;
}

static const char *unit_category_name(int cat) {
    switch (cat) {
        case 1:  return "length";
        case 2:  return "mass";
        case 3:  return "time";
        case 4:  return "temperature";
        case 5:  return "pressure";
        case 6:  return "energy";
        case 7:  return "force";
        case 8:  return "frequency";
        case 9:  return "angle";
        case 10: return "voltage";
        case 11: return "current";
        default: return "unknown";
    }
}

long long nuc_unit_convert(long long val_bits, long long from, long long to) {
    int from_id = (int)from;
    int to_id = (int)to;
    int cat_from = unit_category(from_id);
    int cat_to = unit_category(to_id);
    /* Reject unknown unit IDs early (F-NUM-012 stop-gap). */
    if (cat_from == 0 || cat_to == 0) {
        fprintf(stderr,
            "PANIC: UNIT-DIM-002: unknown unit ID in unit_convert (from=%d to=%d)\n",
            from_id, to_id);
        fflush(stderr);
        exit(1);
    }
    if (cat_from != cat_to) {
        fprintf(stderr,
            "PANIC: UNIT-DIM-001: incompatible dimensions <%s> -> <%s> in unit_convert\n",
            unit_category_name(cat_from), unit_category_name(cat_to));
        fflush(stderr);
        exit(1);
    }
    double val = _un_i2f(val_bits);
    double si = to_si(val, from_id);
    double result = from_si(si, to_id);
    return _un_f2i(result);
}

// Auto-scale with SI prefix
const char *nuc_unit_si_prefix(long long val_bits, const char *unit) {
    double val = _un_i2f(val_bits);
    const char *prefixes[] = {"f", "p", "n", "u", "m", "", "k", "M", "G", "T"};
    double scales[] = {1e-15, 1e-12, 1e-9, 1e-6, 1e-3, 1, 1e3, 1e6, 1e9, 1e12};
    int best = 5;
    double absval = fabs(val);
    for (int i = 0; i < 10; i++) {
        double scaled = absval / scales[i];
        if (scaled >= 1 && scaled < 1000) { best = i; break; }
    }
    char *buf = (char *)malloc(64);
    snprintf(buf, 64, "%.3f %s%s", val / scales[best], prefixes[best], unit ? unit : "");
    return buf;
}
