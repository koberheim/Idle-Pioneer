## Pure number-formatting helper (docs/GAME_DESIGN.md §11 Phase 7: "£1.2M,
## not £1200000"). Stateless, so a plain static utility rather than an
## autoload - nothing here needs Balance.tres or any other boot-order
## dependency, unlike Balance/Db.
class_name Format
extends RefCounted

const _SUFFIXES: Array[String] = ["K", "M", "B", "T", "Qa", "Qi"]


## Abbreviates a currency-scale number: under 1000 shows with `decimals`
## places (0 by default - most displayed amounts here are whole-unit
## currency/counts), at or above 1000 always shows one decimal place with a
## magnitude suffix regardless of `decimals` (1,000 -> "1.0K",
## 1,250,000 -> "1.3M") - the point of abbreviating is losing sub-unit
## precision anyway. Magnitudes beyond the last known suffix keep stepping
## by "Qi" powers rather than breaking, since idle games are exactly the
## genre where numbers eventually run past any fixed table.
static func number(value: float, decimals: int = 0) -> String:
	var sign: String = "-" if value < 0.0 else ""
	var v: float = absf(value)

	if v < 1000.0:
		return "%s%s" % [sign, ("%." + str(decimals) + "f") % v]

	var magnitude: int = 0
	while v >= 1000.0 and magnitude < _SUFFIXES.size():
		v /= 1000.0
		magnitude += 1

	# Past the last named suffix, keep dividing and report the excess
	# magnitude as a numeric multiplier on the largest named one instead of
	# silently freezing at "999Qi".
	var extra_steps: int = 0
	while v >= 1000.0:
		v /= 1000.0
		extra_steps += 1

	var suffix: String = _SUFFIXES[magnitude - 1]
	if extra_steps > 0:
		suffix = "%s^%d" % [suffix, extra_steps]

	return "%s%.1f%s" % [sign, v, suffix]
