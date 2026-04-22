// base64.nr — base64 round-trip
import "stdlib/rods/base64.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let encoded: str = b64_encode("Hello, Nucleor!");
    if str_eq(encoded, "SGVsbG8sIE51Y2xlb3Ih") != 1 {
        print(str_concat("FAIL base64: encode = ", encoded));
        fail = fail + 1;
    };

    let decoded: str = b64_decode(encoded);
    if str_eq(decoded, "Hello, Nucleor!") != 1 {
        print(str_concat("FAIL base64: decode = ", decoded));
        fail = fail + 1;
    };

    if fail == 0 { print("OK base64"); return 0; };
    return 1;
}
