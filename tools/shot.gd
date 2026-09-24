## Renders the real game in a scripted state and saves a screenshot. Dev tool.
##   godot --path . res://tools/shot.tscn -- scenario=map out=C:/tmp/map.png
extends Node

var scenario: String = "map"
var map_style: String = WorldMap.STYLE_RANDOM
var out_path: String = "user://shot.png"
var main: Control


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("scenario="):
			scenario = arg.substr(9)
		elif arg.begins_with("out="):
			out_path = arg.substr(4)
		elif arg.begins_with("map="):
			map_style = arg.substr(4)
	Game.save_path = "user://shot_save.json"
	SaveIO.delete(Game.save_path)
	Game.meta = MetaState.new()
	Game.meta.music_on = false
	Game.meta.sfx_on = false
	if scenario == "fresh":
		Game.start_run("dutch", map_style)
	elif scenario != "nation" and scenario != "reforms":
		_seed_state()
	if scenario == "reforms":
		Game.meta.liberty = 14
		Game.meta.runs_completed = 1
		Game.save()
	if scenario.begins_with("ledger") or scenario in ["spec", "relic"]:
		Game.meta.runs_completed = 3
		Game.meta.almanacs = 2
		Game.meta.stats = {"gold_earned": 4.2e9, "shipments": 812, "land_colonies": 9, "sea_colonies": 4, "father_franklin": 2, "delivered_furs": 5400, "seconds_played": 30000, "land_leagues": 12000, "sea_leagues": 3100, "app_opens": 17}
		for id: String in ["kite_key", "franklin_stove", "armonica", "bifocals", "poor_richard", "tea_chest", "octant", "long_rifle", "mayflower_compact"]:
			Game.meta.relics.append(id)
		Game.save()
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(20)
	match scenario:
		"sheet":
			main.call("_open_colony", "c1")
		"found":
			main.call("_open_next_site")
		"capital":
			main.call("_open_colony", "c0")
		"overview":
			main.call("_show_overview")
		"tip":
			await _frames(200)
		"zoomout":
			var mv0: MapView = main.get("_map")
			mv0.zoom_by(0.4)
		"zoomin":
			var mv1: MapView = main.get("_map")
			mv1.zoom_by(2.2)
		"workshops":
			main.call("_select_tab", 1)
		"europe":
			main.call("_select_tab", 2)
		"congress":
			main.call("_select_tab", 3)
		"congress2":
			main.call("_select_tab", 3)
			await _frames(10)
			var p: Page = main.get("_pages")[3]
			p.scroll.scroll_vertical = 900
		"independence":
			Game.run.lifetime_gold = 3e9
			Game.run.crafted["muskets"] = 3
			main.call("_select_tab", 3)
			await _frames(5)
			main.call("_show_independence")
			await _frames(200)
		"offline":
			var ev := SimEvents.new()
			ev.gold_earned = 123456.0
			ev.shipments.append({})
			ev.crafted["planks"] = 400.0
			main.call("_on_offline", 7300.0, ev)
		"treasure":
			var mv: MapView = main.get("_map")
			mv.set("_treasure_timer", 0.0)
			await _frames(30)
		"settings":
			main.call("_show_settings")
		"ledger":
			main.call("_select_tab", 4)
		"ledger2":
			main.call("_select_tab", 4)
			await _frames(10)
			var lp: Page = main.get("_pages")[4]
			lp.scroll.scroll_vertical = 1500
		"spec":
			Game.run.colony("c1").charter = 1
			main.call("_open_colony", "c1")
			await _frames(10)
			var sheet: Control = main.get("_sheet")
			var sc: ScrollContainer = sheet.get("_scroll")
			sc.scroll_vertical = 2000
		"relic":
			main.call("_on_relic", "orrery", "treasure")
	await _frames(40)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("saved ", out_path, " ", img.get_size())
	SaveIO.delete(Game.save_path)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seed_state() -> void:
	Game.run = RunState.create("english", map_style, 7)
	var run: RunState = Game.run
	for i in 5:
		run.found_next()
	for i in run.colonies.size():
		var c: RunState.ColonyState = run.colonies[i]
		c.prod_level = 8 + i * 6
		c.cargo_level = 3 + i * 4
		c.speed_level = 2 + i * 3
		c.colonists = i % 3
	run.colonies[1].stock = 4000.0
	run.colonists_owned = 9
	run.gold = 2.4e6
	run.lifetime_gold = 3.1e7
	for id: String in ["lumber", "charcoal", "tar"]:
		run.workshop(id).built = true
	run.workshop("lumber").colonists = 2
	run.workshop("lumber").level = 4
	run.hold["timber"] = true
	run.fathers.append(Balance.fathers_offered(run)[0]["id"])
	Game.meta.liberty = 12
	Game.meta.governors.append({"id": 1, "name": "John Winthrop", "type": "prod", "rank": 2})
	Game.meta.governors.append({"id": 2, "name": "Jean Talon", "type": "cargo", "rank": 1})
	Game.meta.next_governor_id = 3
	run.governors["c1"] = 1
	run.colonies[1].charter = 1
	run.warehouse["timber"] = 320.0
	run.warehouse["lumber"] = 45.0
	var ev := SimEvents.new()
	for i in 30:
		Sim.step(run, Game.meta, 1.0, ev)
	Game.running = true
	Game.meta.hints_seen.append("tip_welcome")
	Game.save()
