extends GutTest

var _saved_meta: MetaState
var _saved_run: RunState
var _saved_path: String
var _saved_balance: Dictionary


func before_each() -> void:
	_saved_balance = Balance.k.duplicate()
	Balance.k["market_up_mult"] = 1.0
	Balance.k["market_down_mult"] = 1.0
	_saved_path = Game.save_path
	Game.save_path = "user://test_game_save.json"
	_saved_meta = Game.meta
	_saved_run = Game.run
	Game.meta = MetaState.new()
	Game.run = RunState.create("french", WorldMap.STYLE_RANDOM, 1)
	Game.buy_amount = 1


func after_each() -> void:
	SaveIO.delete(Game.save_path)
	Game.save_path = _saved_path
	Game.meta = _saved_meta
	Game.run = _saved_run
	Balance.k = _saved_balance


func _cap() -> RunState.ColonyState:
	return Game.run.capital()


func test_upgrade_spends_gold_and_raises_level() -> void:
	Game.run.gold = 1000.0
	var cost: float = Balance.colony_upgrade_cost(Game.run, "prod", _cap())
	assert_true(Game.upgrade_colony("c0", "prod"))
	assert_eq(_cap().prod_level, 1)
	assert_almost_eq(Game.run.gold, 1000.0 - cost, 0.001)


func test_upgrade_fails_without_gold() -> void:
	Game.run.gold = 1.0
	assert_false(Game.upgrade_colony("c0", "prod"))
	assert_eq(_cap().prod_level, 0)


func test_buy_max_buys_as_many_as_affordable() -> void:
	Game.run.gold = 10000.0
	Game.buy_amount = -1
	assert_true(Game.upgrade_colony("c0", "prod"))
	assert_gt(_cap().prod_level, 5)
	assert_true(Game.run.gold < Balance.colony_upgrade_cost(Game.run, "prod", _cap()))


func test_colonies_land_on_their_pre_rolled_sites_with_nation_discount() -> void:
	Game.run.gold = 1e9
	var expected_site: int = Game.run.world.colony_order[1]
	var before: float = Game.run.gold
	assert_true(Game.found_colony())
	assert_eq(Game.run.colonies[1].site, expected_site)
	# French colonies cost 20% less.
	assert_almost_eq(before - Game.run.gold, Balance.v("found_cost_first") * 0.8, 0.01)


func test_map_holds_at_most_25_colonies() -> void:
	Game.run.gold = 1e300
	var n: int = 0
	while Game.found_colony():
		n += 1
	assert_eq(Game.run.colonies.size(), int(Balance.v("max_colonies")))
	assert_false(Game.found_colony())


func test_colonists_are_a_shared_pool() -> void:
	Game.run.gold = 1e6
	Game.found_colony()
	assert_true(Game.recruit_colonists())
	assert_eq(Game.run.colonists_idle(), 1)
	assert_true(Game.assign_to_colony("c1", 1))
	assert_false(Game.assign_to_colony("c0", 1), "no idle colonist left")
	assert_true(Game.assign_to_colony("c1", -1))
	assert_eq(Game.run.colonists_idle(), 1)


func test_staffing_a_workshop_holds_its_inputs() -> void:
	Game.run.gold = 1e6
	Game.run.discovered.append("timber")
	assert_true(Game.build_workshop("lumber"))
	Game.recruit_colonists()
	assert_true(Game.assign_to_workshop("lumber", 1))
	assert_true(Game.run.is_held("timber"))


func test_workshop_locked_until_inputs_discovered() -> void:
	Game.run.gold = 1e9
	assert_false(Game.build_workshop("salt_cod"))


func test_only_offered_fathers_can_join() -> void:
	var offered: Array[Dictionary] = Balance.fathers_offered(Game.run)
	assert_eq(offered.size(), int(Balance.v("fathers_offered_per_tier")) * 4)
	var not_offered: String = ""
	for f: Dictionary in Content.fathers:
		if not offered.has(f):
			not_offered = f["id"]
			break
	Game.run.gold = 1e15
	for key: String in ["lumber", "charcoal", "tar"]:
		Game.run.warehouse[key] = 1e6
	assert_false(Game.join_father(not_offered))
	var first: Dictionary = offered[0]
	assert_true(Game.join_father(first["id"]))
	assert_false(Game.join_father(first["id"]), "only once")


func test_freeman_brings_free_colonists() -> void:
	Game.run.gold = 1e15
	Game.run.warehouse["cloth"] = 1e6
	if not Game.father_offered("freeman"):
		pass_test("not offered on this map")
		return
	var before: int = Game.run.colonists_owned
	assert_true(Game.join_father("freeman"))
	assert_eq(Game.run.colonists_owned, before + 5)


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


func test_liberty_reforms_have_rising_costs_and_no_cap() -> void:
	Game.meta.liberty = 100000
	var last: int = 0
	for i in 12:
		var cost: int = Balance.liberty_upgrade_cost(Game.meta, "industry")
		assert_gte(cost, last)
		last = cost
		assert_true(Game.buy_liberty_upgrade("industry"))
	assert_eq(Game.meta.level("industry"), 12)


func test_state_round_trips_through_dict() -> void:
	Game.run.gold = 1234.5
	Game.run.gold = 1e6
	Game.found_colony()
	Game.run.gold = 1234.5
	var c1 := Game.run.colony("c1")
	c1.cargo_level = 3
	c1.trip = 0.4
	Game.run.hold["cod"] = true
	Game.run.workshop("lumber").built = true
	Game.meta.upgrades["navigation"] = 2
	var json: String = JSON.stringify({"meta": Game.meta.to_dict(), "run": Game.run.to_dict()})
	var parsed: Dictionary = JSON.parse_string(json)
	var run2 := RunState.from_dict(parsed["run"])
	var meta2 := MetaState.from_dict(parsed["meta"])
	assert_almost_eq(run2.gold, 1234.5, 0.001)
	assert_eq(run2.colony("c1").cargo_level, 3)
	assert_eq(run2.colony("c1").site, c1.site)
	assert_eq(run2.world.sites.size(), Game.run.world.sites.size(), "the map regenerates identically")
	assert_eq(run2.resource_of(run2.colony("c1")), Game.run.resource_of(c1))
	assert_true(run2.is_held("cod"))
	assert_eq(meta2.level("navigation"), 2)


func test_old_saves_without_a_map_start_fresh() -> void:
	assert_null(RunState.from_dict({"gold": 5.0, "colonies": []}))


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


func test_charter_consumes_goods_and_boosts_colony() -> void:
	var cap := _cap()
	var before: float = Balance.production_rate(Game.run, Game.meta, cap)
	assert_false(Game.charter_colony("c0"), "needs lumber")
	Game.run.warehouse["lumber"] = 1000.0
	assert_true(Game.charter_colony("c0"))
	assert_eq(cap.charter, 1)
	assert_almost_eq(Game.run.stock_of("lumber"), 850.0, 0.01)
	assert_almost_eq(Balance.production_rate(Game.run, Game.meta, cap), before * 1.5, 0.001)


func test_governors_are_permanent_and_boost_their_post() -> void:
	Game.meta.liberty = 100
	assert_true(Game.commission_governor("prod"))
	var gid: int = Game.meta.governors[0]["id"]
	var cap := _cap()
	var before: float = Balance.production_rate(Game.run, Game.meta, cap)
	assert_true(Game.post_governor("c0", gid))
	assert_almost_eq(Balance.production_rate(Game.run, Game.meta, cap), before * 1.5, 0.001)
	assert_true(Game.promote_governor(gid))
	assert_almost_eq(Balance.production_rate(Game.run, Game.meta, cap), before * 2.0, 0.001)
	Game.run.gold = 1e6
	Game.found_colony()
	assert_true(Game.post_governor("c1", gid))
	assert_eq(Game.run.governor_at("c0"), -1, "a governor holds one post at a time")
	Game.run.lifetime_gold = Balance.v("independence_gold")
	Game.run.crafted["muskets"] = 1
	Game.declare_independence()
	assert_eq(Game.meta.governors.size(), 1, "governors survive independence")


func test_market_is_deterministic_and_rotates() -> void:
	Balance.k = _saved_balance.duplicate()
	var a: Dictionary = Balance.market_state(Game.run).duplicate(true)
	var b: Dictionary = Balance.market_state(Game.run)
	assert_eq(a["up"], b["up"])
	assert_eq((a["up"] as Array).size(), int(Balance.v("market_up_count")))
	for id: Variant in a["down"]:
		assert_false((a["up"] as Array).has(id))
	var id0: String = a["up"][0]
	assert_almost_eq(Balance.sell_price(Game.run, Game.meta, id0), Content.price(id0) * Balance.v("market_up_mult"), 0.001)
	Game.run.play_seconds += Balance.v("market_period_seconds") * 3.0
	assert_ne(Balance.market_state(Game.run)["period"], a["period"])


func test_treasure_pays_out() -> void:
	Game.run.gold = 0.0
	var got: float = Game.collect_treasure()
	assert_gt(got, 0.0)
	assert_almost_eq(Game.run.gold, got, 0.001)
