## Child of Game. Gold, selling resources for gold, and the exponential colony
## cost curve (task R2). Reads/writes Game.run directly, same discipline as
## Inventory (task R1) - no cached local state.
extends Node

signal gold_changed(total: float)

const BASE_COLONY_COST: float = 100.0
const COLONY_COST_MULTIPLIER: float = 2.5

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


## Gold value of `amount` units of `id` at its base_value, before any sale.
##
## Deliberately does NOT apply Game.progression.production_multiplier() here,
## even though docs/GODOT_PLAN.md's original task R2 description mentions
## "applying the progression multiplier." That description predates task D3's
## effect-key design: the MVP's one upgrade (primitive_tools) is
## EFFECT_GLOBAL_PRODUCTION_MULTIPLIER - it makes colonies produce faster, which
## has nothing to do with what each unit sells for. Applying a production
## multiplier to sale price would be a bug, not a feature, so it's left out
## until (if) an actual gold-sale-multiplier upgrade effect exists to back it -
## see docs/CONVENTIONS.md "no system without a caller."
func sell_value(id: StringName, amount: float) -> float:
	var def: ResourceDef = Db.resource(id)
	if def == null:
		return 0.0
	return def.base_value * amount


## Exponential cost curve for founding the next colony: base * mult^founded,
## discounted by Settlement's prestige effect (§8 - "-7% colonist and colony
## cost per level").
## Matches the real Unity formula (EconomyManager.nextColonyCost) and Phase 7's
## MVP spec.
func next_colony_cost() -> float:
	var founded: int = Game.run.colonies_founded if Game.run != null else 0
	return BASE_COLONY_COST * pow(COLONY_COST_MULTIPLIER, founded) * Game.prestige.cost_discount_multiplier()
