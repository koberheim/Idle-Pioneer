## Child of Game. Upgrade purchase state and the production multiplier
## purchased upgrades grant (task P5).
##
## docs/GODOT_PLAN.md calls this task out specifically: "The whole point [...]
## Do not close this task until a test proves a colony's output changes."
## Unity shipped ten ResearchManager methods - including
## GetProductionMultiplier - that nothing ever called
## (docs/GODOT_MIGRATION_ANALYSIS.md §E3). Colony.tick() (task P2) already
## reads Game.progression.production_multiplier() on every production tick, so
## this class existing and being correct is what closes that loop - see
## test_progression.gd's test_purchasing_primitive_tools_increases_a_colonys_
## next_tick_output for the end-to-end proof.
##
## can_purchase(id)/purchase(id) resolve through Db and delegate to
## can_purchase_upgrade(upgrade)/purchase_upgrade(upgrade), which operate on a
## UpgradeDef directly - the same split Crafting (task P4) uses, for the same
## reason: MVP's real content (task D5) has exactly one upgrade with no
## prerequisites and no resource costs (Phase 7's deliberate scope cut), so
## prerequisite-gating and resource-cost-gating are only testable against
## hand-built UpgradeDef objects, not through Db.
extends Node

signal upgrade_purchased(id: StringName)


func is_purchased(id: StringName) -> bool:
	return Game.run != null and Game.run.upgrades_purchased.has(id)


func can_purchase(id: StringName) -> bool:
	if is_purchased(id):
		return false
	return can_purchase_upgrade(Db.upgrade(id))


func purchase(id: StringName) -> bool:
	# The "already purchased" check lives here, not in can_purchase_upgrade -
	# it's an id-level fact (which id is in Game.run.upgrades_purchased), not
	# something a bare UpgradeDef object knows about. purchase_upgrade() below
	# does its own can_purchase_upgrade() check, so this only checks it once,
	# not twice.
	if is_purchased(id):
		return false
	if not purchase_upgrade(Db.upgrade(id)):
		return false
	Game.run.upgrades_purchased.append(id)
	upgrade_purchased.emit(id)
	return true


func can_purchase_upgrade(upgrade: UpgradeDef) -> bool:
	if Game.run == null or upgrade == null:
		return false

	for prereq_id: StringName in upgrade.prerequisite_ids:
		if not is_purchased(prereq_id):
			return false

	if Game.economy.gold < upgrade.gold_cost:
		return false

	for cost: RecipeIngredient in upgrade.resource_costs:
		if not Game.inventory.has(cost.resource_id, cost.amount):
			return false

	return true


## Deducts gold and resource costs only - does NOT mark the upgrade purchased
## or emit upgrade_purchased (purchase(id) does both of those, since "which id
## was purchased" only makes sense at the id layer). Verifies everything (via
## can_purchase_upgrade) before consuming anything, same atomicity discipline
## as Crafting.craft_recipe (task P4).
func purchase_upgrade(upgrade: UpgradeDef) -> bool:
	if not can_purchase_upgrade(upgrade):
		return false

	# A free upgrade (gold_cost 0 - see UpgradeDef's is_valid(), task D3, which
	# deliberately allows this) has nothing to spend. Economy.try_spend()
	# rejects a zero amount as invalid input (task R2), which is correct for
	# Economy's own contract but would wrongly block a legitimate free
	# purchase here - found by test_purchase_upgrade_respects_resource_costs
	# actually exercising a 0-gold-cost upgrade, not reasoned out in advance.
	if upgrade.gold_cost > 0:
		if not Game.economy.try_spend(upgrade.gold_cost):
			# Shouldn't be reachable - can_purchase_upgrade() already verified
			# gold >= gold_cost, and nothing else runs between that check and
			# this call in single-threaded GDScript. Guarded anyway rather
			# than assumed.
			push_error("Progression.purchase_upgrade: try_spend failed after can_purchase_upgrade() passed")
			return false

	for cost: RecipeIngredient in upgrade.resource_costs:
		if not Game.inventory.try_remove(cost.resource_id, cost.amount):
			push_error(
				"Progression.purchase_upgrade: try_remove failed for '%s' after can_purchase_upgrade() passed" % cost.resource_id
			)
			return false

	return true


## Multiplicative stacking across every purchased upgrade whose effect is
## EFFECT_GLOBAL_PRODUCTION_MULTIPLIER (docs/GODOT_MIGRATION_ANALYSIS.md §4:
## "Base 1.0 x bonus x bonus x ..."). Upgrades with a different effect key
## (none exist yet beyond this one) simply don't contribute here - each effect
## key is only ever interpreted by the one system it's meant for.
func production_multiplier() -> float:
	if Game.run == null:
		return 1.0

	var upgrades: Array[UpgradeDef] = []
	for id: StringName in Game.run.upgrades_purchased:
		var upgrade: UpgradeDef = Db.upgrade(id)
		if upgrade != null:
			upgrades.append(upgrade)

	return _combined_production_multiplier(upgrades)


static func _combined_production_multiplier(upgrades: Array[UpgradeDef]) -> float:
	var multiplier: float = 1.0
	for upgrade: UpgradeDef in upgrades:
		if upgrade != null and upgrade.effect == UpgradeDef.EFFECT_GLOBAL_PRODUCTION_MULTIPLIER:
			multiplier *= upgrade.magnitude
	return multiplier
