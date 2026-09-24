extends GutTest

var _saved_meta: MetaState
var _saved_run: RunState
var _saved_path: String


func before_each() -> void:
	_saved_path = Game.save_path
	Game.save_path = "user://test_game_save.json"
	_saved_meta = Game.meta
	_saved_run = Game.run
	Game.meta = MetaState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Game.run = RunState.create("french", rng)
	Game.buy_amount = 1


func after_each() -> void:
	SaveIO.delete(Game.save_path)
	Game.save_path = _saved_path
	Game.meta = _saved_meta
	Game.run = _saved_run


func test_upgrade_spends_gold_and_raises_level() -> void:
	Game.run.gold = 1000.0
	var cost: float = Balance.colony_upgrade_cost("prod", Game.run.colony("capital"))
	assert_true(Game.upgrade_colony("capital", "prod"))
	assert_eq(Game.run.colony("capital").prod_level, 1)
	assert_almost_eq(Game.run.gold, 1000.0 - cost, 0.001)


func test_upgrade_fails_without_gold() -> void:
	Game.run.gold = 1.0
	assert_false(Game.upgrade_colony("capital", "prod"))
	assert_eq(Game.run.colony("capital").prod_level, 0)


func test_buy_max_buys_as_many_as_affordable() -> void:
	Game.run.gold = 10000.0
	Game.buy_amount = -1
	assert_true(Game.upgrade_colony("capital", "prod"))
	var lvl: int = Game.run.colony("capital").prod_level
	assert_gt(lvl, 5)
	assert_true(Game.run.gold < Balance.colony_upgrade_cost("prod", Game.run.colony("capital")))


func test_colonies_found_in_order_with_nation_discount() -> void:
	Game.run.gold = 1e9
	assert_false(Game.found_colony("plantation"), "cannot skip ahead")
	var before: float = Game.run.gold
	assert_true(Game.found_colony("fishery"))
	# French colonies cost 20% less.
	assert_almost_eq(before - Game.run.gold, 250.0 * 0.8, 0.01)


func test_colonists_are_a_shared_pool() -> void:
	Game.run.gold = 1e6
	Game.run.colony("fishery").founded = true
	assert_true(Game.recruit_colonists())
	assert_eq(Game.run.colonists_idle(), 1)
	assert_true(Game.assign_to_colony("fishery", 1))
	assert_false(Game.assign_to_colony("capital", 1), "no idle colonist left")
	assert_true(Game.assign_to_colony("fishery", -1))
	assert_eq(Game.run.colonists_idle(), 1)


func test_staffing_a_workshop_holds_its_inputs() -> void:
	Game.run.gold = 1e6
	Game.run.discovered.append("timber")
	assert_true(Game.build_workshop("planks"))
	Game.recruit_colonists()
	assert_true(Game.assign_to_workshop("planks", 1))
	assert_true(Game.run.is_held("timber"))


func test_workshop_locked_until_inputs_discovered() -> void:
	Game.run.gold = 1e9
	assert_false(Game.build_workshop("salt_cod"))


func test_father_costs_gold_and_goods() -> void:
	Game.run.gold = 1000.0
	Game.run.warehouse["timber"] = 200.0
	assert_true(Game.join_father("minuit"))
	assert_almost_eq(Game.run.gold, 600.0, 0.01)
	assert_almost_eq(Game.run.stock_of("timber"), 50.0, 0.01)
	assert_false(Game.join_father("minuit"), "only once")


func test_declaring_independence_wipes_run_and_keeps_meta() -> void:
	Game.run.lifetime_gold = Balance.v("independence_gold") * 4.0
	Game.run.crafted["muskets"] = 1
	Game.meta.upgrades["industry"] = 2
	var paid: int = Game.declare_independence()
	assert_eq(paid, int(floor(Balance.v("liberty_base") * 2.0)))
	assert_null(Game.run)
	assert_eq(Game.meta.liberty, paid)
	assert_eq(Game.meta.runs_completed, 1)
	assert_eq(Game.meta.level("industry"), 2)


func test_independence_needs_muskets() -> void:
	Game.run.lifetime_gold = Balance.v("independence_gold") * 2.0
	assert_false(Balance.independence_ready(Game.run))
	assert_eq(Game.declare_independence(), 0)
	assert_not_null(Game.run)


func test_liberty_upgrade_costs_follow_table() -> void:
	Game.meta.liberty = 10
	assert_true(Game.buy_liberty_upgrade("industry"))
	assert_eq(Game.meta.liberty, 7)
	assert_true(Game.buy_liberty_upgrade("industry"))
	assert_eq(Game.meta.liberty, 2)
	assert_false(Game.buy_liberty_upgrade("industry"))


func test_state_round_trips_through_dict() -> void:
	Game.run.gold = 1234.5
	Game.run.colony("fishery").founded = true
	Game.run.colony("fishery").cargo_level = 3
	Game.run.colony("fishery").trip = 0.4
	Game.run.hold["cod"] = true
	Game.run.fathers.append("minuit")
	Game.run.workshop("planks").built = true
	Game.meta.upgrades["navigation"] = 2
	var json: String = JSON.stringify({"meta": Game.meta.to_dict(), "run": Game.run.to_dict()})
	var parsed: Dictionary = JSON.parse_string(json)
	var run2 := RunState.from_dict(parsed["run"])
	var meta2 := MetaState.from_dict(parsed["meta"])
	assert_eq(run2.to_dict(), RunState.from_dict(Game.run.to_dict()).to_dict())
	assert_almost_eq(run2.gold, 1234.5, 0.001)
	assert_eq(run2.colony("fishery").cargo_level, 3)
	assert_eq(run2.colony("fishery").site, Game.run.colony("fishery").site)
	assert_true(run2.is_held("cod"))
	assert_eq(meta2.level("navigation"), 2)


func test_corrupt_save_falls_back_to_backup() -> void:
	var path := "user://test_save.json"
	SaveIO.delete(path)
	assert_true(SaveIO.write(path, {"meta": {"liberty": 5}}))
	assert_true(SaveIO.write(path, {"meta": {"liberty": 6}}))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var data: Dictionary = SaveIO.read(path)
	assert_eq(int(data["meta"]["liberty"]), 5)
	SaveIO.delete(path)


func test_format_numbers() -> void:
	assert_eq(Format.num(999.0), "999")
	assert_eq(Format.num(1234.0), "1.23K")
	assert_eq(Format.num(12345.0), "12.3K")
	assert_eq(Format.num(1.5e9), "1.50B")
	assert_eq(Format.num(999999.0), "999K")
