## Runtime state for one recipe's continuous auto-craft process (rework
## task: continuous crafting, docs/GAME_DESIGN.md §6).
##
## Two independent ways to produce a recipe's output, per explicit direction
## in conversation:
##  - craft_now(): "click to craft one" - instant, one batch, exactly the
##    existing Crafting.craft() behaviour. Works regardless of auto_craft.
##  - tick(delta) + auto_craft: "set on auto craft" - a background timer using
##    the recipe's own craft_seconds as the cycle length, producing one batch
##    per completed cycle for as long as ingredients hold out.
##
## tick() is safe for ANY delta, including a multi-hour/day offline gap: it
## reuses ProductionCycle's exact-math catch-up (one division, not a
## per-second loop) to work out how many whole cycles elapsed, then attempts
## to craft that many batches, stopping the moment ingredients run out. That
## stop is a real limitation worth stating plainly: if other systems would
## also have produced more of those ingredients partway through the same
## offline gap, this doesn't re-check mid-gap - it only knows what's in stock
## right now. Good enough to never fabricate resources or lose a craft that
## genuinely had the materials for it; not a full replay of everything else
## that happened during the gap.
class_name CraftingStation
extends RefCounted

var recipe_id: StringName
var auto_craft: bool = false
var cycle: ProductionCycle


func _init(p_recipe_id: StringName) -> void:
	recipe_id = p_recipe_id
	var recipe: RecipeDef = Db.recipe(recipe_id)
	var seconds: float = recipe.craft_seconds if recipe != null else 1.0
	if seconds <= 0.0:
		seconds = 1.0
	cycle = ProductionCycle.new(seconds)


func can_craft_now() -> bool:
	return Crafting.can_craft(recipe_id)


## The manual action - independent of auto_craft and of the cycle timer below.
func craft_now() -> bool:
	return Crafting.craft(recipe_id)


## No-op unless auto_craft is on. See the class doc for the offline-catch-up
## behaviour and its documented limitation.
##
## When a cycle completes but the craft fails (out of ingredients), that
## cycle's time is handed back to the timer rather than spent - the station
## pauses exactly where it was blocked instead of silently losing progress.
## Without this, a station that's out of materials for an hour would still
## burn through full cycles doing nothing, and once materials returned it
## would have to wait out another whole cycle before crafting again, instead
## of resuming right away like a paused (not reset) timer should.
func tick(delta: float) -> void:
	if not auto_craft:
		return
	var cycles_elapsed: int = cycle.advance(delta)
	for i in range(cycles_elapsed):
		if not Crafting.craft(recipe_id):
			var unspent_cycles: int = cycles_elapsed - i
			cycle.accumulated += unspent_cycles * cycle.cycle_seconds
			break
