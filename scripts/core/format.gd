## Number and time formatting for display.
class_name Format
extends RefCounted

## Named suffixes up to decillions; beyond that, scientific notation.
const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

## "standard" (K, M, B... then scientific past decillions) or "scientific"
## (from a million up). Set from the player's setting.
static var notation: String = "standard"


## 999 -> "999", 1234 -> "1.23K", 12345 -> "12.3K", 1.5e9 -> "1.50B".
static func num(value: float, small_decimals: int = 0) -> String:
	if is_nan(value):
		return "0"
	var sign: String = "-" if value < 0.0 else ""
	var v: float = absf(value)
	if is_inf(v):
		return sign + "∞"
	if v >= 1e36 or (notation == "scientific" and v >= 1e6):
		return sign + sci(v)
	if v < 1000.0:
		if small_decimals > 0 and v < 100.0 and not is_equal_approx(v, roundf(v)):
			return sign + (("%." + str(small_decimals) + "f") % v)
		return sign + str(int(floor(v)))
	var mag: int = 0
	while v >= 1000.0 and mag < SUFFIXES.size() - 1:
		v /= 1000.0
		mag += 1
	var body: String
	if v >= 100.0:
		body = "%d" % int(floor(v))
	elif v >= 10.0:
		body = "%.1f" % (floor(v * 10.0) / 10.0)
	else:
		body = "%.2f" % (floor(v * 100.0) / 100.0)
	return sign + body + SUFFIXES[mag]


## 1.23e45 style, with the mantissa always in [1, 10).
static func sci(v: float) -> String:
	var e: int = int(floor(log(v) / log(10.0)))
	var m: float = v / pow(10.0, e)
	if m >= 9.995:
		m /= 10.0
		e += 1
	elif m < 1.0:
		m *= 10.0
		e -= 1
	return "%.2fe%d" % [floor(m * 100.0) / 100.0, e]


static func rate(value: float) -> String:
	if value < 10.0:
		return "%.2f" % value
	if value < 1000.0:
		return "%.1f" % value
	return num(value)


static func duration(seconds: float) -> String:
	var s: int = int(seconds)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %02ds" % [s / 60, s % 60]
	if s < 86400:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%dd %dh" % [s / 86400, (s % 86400) / 3600]


## A multiplier without trailing zeros: 2 -> "2", 1.5 -> "1.5".
static func mult(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2).rstrip("0").rstrip(".")
