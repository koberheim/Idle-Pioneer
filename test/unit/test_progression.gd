## Tests for Progression (task P5). Same Game.run/Game.meta reset discipline
## as the other sim tests (Game.meta matters here too, via Game.economy).
##
## The real primitive_tools upgrade (task D5: 50 gold, +25% global production,
## no prerequisites, no resource costs) exercises the id-based public API.
## Prerequisite-gating, resource-cost-gating, and two-upgrade stacking all use
## hand-built UpgradeDef objects instead - MVP's real content has exactly one
## upgrade with neither prerequisites nor resource costs (Phase 7's deliberate
## scope cut), so Db has nothing to test those paths against.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.meta = MetaState.new()


func after_each() -> void:
	Game.run = null
	Game.meta = MetaState.new()


func _make_upgrade(
	id: StringName,
	gold_cost: int,
	effect: StringName = UpgradeDef.EFFECT_GLOBAL_PRODUCTION_MULTIPLIER,
	magnitude: float = 1.0
) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = id
	u.gold_cost = gold_cost
	u.effect = effect
	u.magnitude = magnitude
	return u


func test_is_purchased_false_initially() -> void:
	assert_false(Game.progression.is_purchased(&"primitive_tools"))


func test_can_purchase_false_with_insufficient_gold() -> void:
	assert_false(Game.progression.can_purchase(&"primitive_tools"))  # 0 gold, costs 50


func test_can_purchase_true_with_enough_gold() -> void:
	Game.economy.add_gold(50.0)
	assert_true(Game.progression.can_purchase(&"primitive_tools"))


func test_can_purchase_false_for_unknown_upgrade_id() -> void:
	assert_false(Game.progression.can_purchase(&"does_not_exist"))


func test_purchase_deducts_gold_and_marks_purchased() -> void:
	Game.economy.add_gold(50.0)
	var ok: bool = Game.progression.purchase(&"primitive_tools")
	assert_true(ok)
	assert_almost_eq(Game.economy.gold, 0.0, 0.0001)
	assert_true(Game.progression.is_purchased(&"primitive_tools"))


func test_purchase_emits_upgrade_purchased() -> void:
	Game.economy.add_gold(50.0)
	watch_signals(Game.progression)
	Game.progression.purchase(&"primitive_tools")
	assert_signal_emitted_with_parameters(Game.progression, "upgrade_purchased", [&"primitive_tools"])


func test_purchase_fails_and_deducts_nothing_with_insufficient_gold() -> void:
	Game.economy.add_gold(10.0)  # needs 50
	var ok: bool = Game.progression.purchase(&"primitive_tools")
	assert_false(ok)
	assert_almost_eq(Game.economy.gold, 10.0, 0.0001, "a failed purchase must not touch gold")
	assert_false(Game.progression.is_purchased(&"primitive_tools"))


func test_double_purchase_is_rejected_and_does_not_double_charge() -> void:
	Game.economy.add_gold(100.0)
	Game.progression.purchase(&"primitive_tools")
	var second: bool = Game.progression.purchase(&"primitive_tools")
	assert_false(second)
	assert_almost_eq(Game.economy.gold, 50.0, 0.0001, "only the first purchase should have charged gold")


func test_production_multiplier_is_one_with_no_purchases() -> void:
	assert_almost_eq(Game.progression.production_multiplier(), 1.0, 0.0001)


func test_production_multiplier_reflects_the_purchased_upgrade() -> void:
	Game.economy.add_gold(50.0)
	Game.progression.purchase(&"primitive_tools")
	assert_almost_eq(Game.progression.production_multiplier(), 1.25, 0.0001)


## The literal acceptance criterion from docs/GODOT_PLAN.md task P5: stacking
## two upgrades multiplies (1.25 x 1.2 = 1.5), tested against the core stacking
## math directly since MVP's real Db content has only one upgrade to stack.
func test_combined_production_multiplier_stacks_two_upgrades_multiplicatively() -> void:
	var a: UpgradeDef = _make_upgrade(&"a", 0, UpgradeDef.EFFECT_GLOBAL_PRODUCTION_MULTIPLIER, 1.25)
	var b: UpgradeDef = _make_upgrade(&"b", 0, UpgradeDef.EFFECT_GLOBAL_PRODUCTION_MULTIPLIER, 1.2)
	# GDScript does not coerce an untyped array literal to Array[UpgradeDef]
	# when passed directly as an argument (only on a typed var declaration) -
	# found by this test failing with "does not have the same element type"
	# on first run, not reasoned out in advance.
	var upgrades: Array[UpgradeDef] = [a, b]
	var combined: float = Game.progression._combined_production_multiplier(upgrades)
	assert_almost_eq(combined, 1.5, 0.0001)


func test_purchase_upgrade_blocked_by_an_unmet_prerequisite() -> void:
	var base: UpgradeDef = _make_upgrade(&"base_upgrade", 0)
	var advanced: UpgradeDef = _make_upgrade(&"advanced_upgrade", 0)
	advanced.prerequisite_ids = [&"base_upgrade"]

	assert_false(Game.progression.can_purchase_upgrade(advanced), "base_upgrade hasn't been purchased yet")

	# purchase_upgrade() (the object-level API) doesn't record purchases by id -
	# only purchase(id) does, since "which id" is meaningless for a bare
	## UpgradeDef. Simulate the prerequisite being satisfied the same way
	# purchase(id) would record it.
	Game.run.upgrades_purchased.append(&"base_upgrade")
	assert_true(Game.progression.can_purchase_upgrade(advanced), "base_upgrade is now purchased")


func test_purchase_upgrade_respects_resource_costs() -> void:
	var costly := _make_upgrade(&"costly_upgrade", 0)
	var cost := RecipeIngredient.new()
	cost.resource_id = &"timber"
	cost.amount = 10
	costly.resource_costs = [cost]

	assert_false(Game.progression.can_purchase_upgrade(costly), "no timber yet")

	Game.inventory.add(&"timber", 10.0)
	assert_true(Game.progression.can_purchase_upgrade(costly))

	var ok: bool = Game.progression.purchase_upgrade(costly)
	assert_true(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001)


func test_purchase_upgrade_with_insufficient_resource_cost_consumes_nothing() -> void:
	var costly := _make_upgrade(&"costly_upgrade", 0)
	var cost := RecipeIngredient.new()
	cost.resource_id = &"timber"
	cost.amount = 10
	costly.resource_costs = [cost]

	Game.inventory.add(&"timber", 3.0)  # not enough
	var ok: bool = Game.progression.purchase_upgrade(costly)
	assert_false(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 3.0, 0.0001, "a failed purchase must not touch stock")


## The single most important test in this task, per docs/GODOT_PLAN.md's own
## framing of P5: proof that a purchased upgrade actually changes what a
## Colony produces, not just that Progression's own methods report the right
## numbers in isolation. Colony.tick() (task P2) reads
## Game.progression.production_multiplier() on every call - this exercises
## that real wiring end to end.
func test_purchasing_primitive_tools_increases_a_colonys_next_tick_output() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.economy.add_gold(25.0)  # exactly enough for the first colonist
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)

	colony.tick(5.0)  # no upgrade purchased yet
	var baseline: float = colony.local_stock.get(&"cod", 0.0)
	assert_almost_eq(baseline, 5.0, 0.0001)

	Game.economy.add_gold(50.0)
	Game.progression.purchase(&"primitive_tools")

	colony.collect()  # clear the baseline tick's output so the next tick is isolated
	colony.tick(5.0)  # one more tick, now with the upgrade active
	var boosted: float = colony.local_stock.get(&"cod", 0.0)

	assert_gt(boosted, baseline, "purchasing the upgrade should have increased output")
	assert_almost_eq(boosted, baseline * 1.25, 0.0001)
