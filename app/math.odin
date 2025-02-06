package app

import "base:intrinsics"
import "core:math"

ceil_to_multiple :: proc(value: $T, multiple: T) -> f64 where intrinsics.type_is_numeric(T) {
	return math.ceil(f64(value) / f64(multiple)) * f64(multiple)
}
