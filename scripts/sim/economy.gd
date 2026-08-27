## Child of Game. Gold and selling resources for gold (task R2). Reads/writes
## Game.run directly, same discipline as Inventory (task R1) - no cached
## local state.
extends Node

signal gold_changed(total: float)

## Read-only - gold changes only through add_gold()/try_spend()/sell(), so
## every change reliably emits gold_changed and updates lifetime_gold_earned.
var gold: float:
	get:
		return Game.run.gold if Game.run != null else 0.0


func add_gold(amount: float) -> void:
	if Game.run == null:
		push_error("Economy.add_gold: no active run")
		return
	if amount <= 0.0:
		push_error("Economy.add_gold: amount must be > 0, got %f" % amount)
		return

	Game.run.gold += amount
	Game.run.lifetime_gold_earned_this_run += amount
	Game.meta.lifetime_gold_earned += amount
	gold_changed.emit(Game.run.gold)

	# PLACEHOLDER earning method for Influence (rework: typed colonist
	# roster) - see BalanceDef.influence_earn_rate_per_gold's doc comment.
	Game.colonists.earn_influence_from_gold(amount)


## Deducts `amount` if (and only if) that much gold is available. Returns false
## and changes nothing on insufficient funds - same atomicity contract as
## Inventory.try_remove (task R1).
func try_spend(amount: float) -> bool:
	if Game.run == null:
		push_error("Economy.try_spend: no active run")
		return false
	if amount <= 0.0:
		push_error("Economy.try_spend: amount must be > 0, got %f" % amount)
		return false
	if Game.run.gold < amount:
		return false

	Game.run.gold -= amount
	gold_changed.emit(Game.run.gold)
	return true


## Sells `amount` of `id` for gold at sell_value(). Goes through
## Game.inventory.try_remove rather than touching Game.run.inventory directly -
## per docs/GODOT_PLAN.md task R2's explicit regression-risk note, bypassing
## Inventory here would skip its `changed` signal and silently desync any UI
## subscribed to it. Returns false (stock unchanged, no gold added) if the sale
## can't go through - insufficient stock or an unknown resource id, both
## already handled loudly by Inventory.try_remove.
func sell(id: StringName, amount: float) -> bool:
	var value: float = sell_value(id, amount)
	if not Game.inventory.try_remove(id, amount):
		return false
	add_gold(value)
	return true


## Gold value of `amount` units of `id` at its base_value, adjusted only by
## the chosen nation's gold-sell bonus (direct request - recovered from the
## Unity project's NationalityData, see NationDef's class doc).
##
## Deliberately does NOT apply Game.progression.production_multiplier() here,
## even though docs/GODOT_PLAN.md's original task R2 description mentions
## "applying the progression multiplier." That description predates task D3's
## effect-key design: the MVP's one upgrade (primitive_tools) is
## EFFECT_GLOBAL_PRODUCTION_MULTIPLIER - it makes colonies produce faster, which
## has nothing to do with what each unit sells for. Applying a production
## multiplier to sale price would be a bug, not a feature - the nation bonus
## is the first *actual* gold-sale multiplier this project has, which is
## exactly the exception that comment already carved out room for.
func sell_value(id: StringName, amount: float) -> float:
	var def: ResourceDef = Db.resource(id)
	if def == null:
		return 0.0
	return def.base_value * amount * Game.nation_gold_sell_multiplier()
