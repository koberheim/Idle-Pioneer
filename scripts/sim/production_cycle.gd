## Pure accumulate-and-catch-up timer (task P1). The single most valuable
## algorithm salvaged from the Unity project (docs/GODOT_MIGRATION_ANALYSIS.md
## §A2, ColonyProduction.TickProduction): accumulate elapsed time, compute how
## many whole cycles that covers by division, keep the remainder.
##
## This MUST stay arithmetic - never a `while accumulated >= cycle_seconds: ...`
## loop. That loop is exactly what forced Unity to disable offline progress
## entirely (docs/GODOT_MIGRATION_ANALYSIS.md §E3): an 8-hour absence at a 1-second
## cycle is 28,800 loop iterations if done the naive way, and the fix was never
## shipped. Here it's one division, regardless of how long the gap was.
class_name ProductionCycle
extends RefCounted

var cycle_seconds: float = 1.0
var accumulated: float = 0.0


func _init(initial_cycle_seconds: float = 1.0) -> void:
	cycle_seconds = initial_cycle_seconds


## Advances the clock by `delta` seconds and returns how many whole cycles
## completed. Any leftover time short of a full cycle stays in `accumulated`
## for the next call - never dropped, never batched into a loop.
func advance(delta: float) -> int:
	if delta <= 0.0:
		return 0
	if cycle_seconds <= 0.0:
		push_error("ProductionCycle.advance: cycle_seconds must be > 0, got %f" % cycle_seconds)
		return 0

	accumulated += delta
	var cycles: int = int(floor(accumulated / cycle_seconds))
	accumulated -= cycles * cycle_seconds
	return cycles
