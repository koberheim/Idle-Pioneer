## Renders the real game in a scripted state and saves a screenshot. Dev tool.
##   godot --path . res://tools/shot.tscn -- scenario=map out=C:/tmp/map.png
extends Node

var scenario: String = "map"
var out_path: String = "user://shot.png"
var main: Control


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("scenario="):
			scenario = arg.substr(9)
		elif arg.begins_with("out="):
			out_path = arg.substr(4)
	Game.save_path = "user://shot_save.json"
	SaveIO.delete(Game.save_path)
	Game.meta = MetaState.new()
	Game.meta.music_on = false
	Game.meta.sfx_on = false
	if scenario == "fresh":
		Game.start_run("dutch")
	elif scenario != "nation" and scenario != "reforms":
		_seed_state()
	if scenario == "reforms":
		Game.meta.liberty = 14
		Game.meta.runs_completed = 1
		Game.save()
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(20)
	match scenario:
		"sheet":
			main.call("_open_colony", "fishery")
		"found":
			main.call("_open_colony", "indigo_reach")
		"capital":
			main.call("_open_colony", "capital")
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
		"late":
			for i in 10:
				Game.run.colonies[i].founded = true
			Game.run.discovered.append_array(["furs", "whale_oil", "silver", "coats"])
			main.call("_open_colony", "horse_ranch")
			await _frames(20)
		"treasure":
			var mv: MapView = main.get("_map")
			mv.set("_treasure_timer", 0.0)
			await _frames(30)
		"settings":
			main.call("_show_settings")
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	Game.run = RunState.create("english", rng)
	var run: RunState = Game.run
	for i in 5:
		run.colonies[i].founded = true
		run.colonies[i].prod_level = 8 + i * 6
		run.colonies[i].cargo_level = 3 + i * 4
		run.colonies[i].speed_level = 2 + i * 3
		run.colonies[i].colonists = i % 3
	run.colonies[1].stock = 400.0
	run.colonists_owned = 9
	run.gold = 2.4e6
	run.lifetime_gold = 3.1e7
	for id: String in ["planks", "salt_cod", "cigars"]:
		run.workshop(id).built = true
	run.workshop("planks").colonists = 2
	run.workshop("planks").level = 4
	run.workshop("salt_cod").colonists = 1
	run.hold["timber"] = true
	run.hold["cod"] = true
	run.fathers.append("minuit")
	Game.meta.liberty = 12
	Game.meta.governors.append({"id": 1, "name": "John Winthrop", "type": "prod", "rank": 2})
	Game.meta.governors.append({"id": 2, "name": "Jean Talon", "type": "cargo", "rank": 1})
	Game.meta.next_governor_id = 3
	run.governors["fishery"] = 1
	run.colonies[1].charter = 1
	run.warehouse["salt_cod"] = 90.0
	run.warehouse["timber"] = 320.0
	run.warehouse["planks"] = 45.0
	var ev := SimEvents.new()
	for i in 30:
		Sim.step(run, Game.meta, 1.0, ev)
	Game.running = true
	Game.save()
