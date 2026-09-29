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
		Game.start_run("french", map_style)
	elif scenario != "nation" and scenario != "reforms":
		_seed_state()
	if scenario == "reforms":
		Game.meta.liberty = 14
		Game.meta.runs_completed = 1
		Game.save()
	if scenario.begins_with("ledger") or scenario in ["spec", "relic"] or scenario.begins_with("research"):
		Game.meta.runs_completed = 3
		Game.meta.almanacs = 2
		Game.meta.stats = {"gold_earned": 4.2e9, "shipments": 812, "land_colonies": 9, "sea_colonies": 4, "father_franklin": 2, "delivered_furs": 5400, "seconds_played": 30000, "land_leagues": 12000, "sea_leagues": 3100, "app_opens": 17}
		for id: String in ["kite_key", "franklin_stove", "armonica", "bifocals", "poor_richard", "tea_chest", "octant", "long_rifle", "mayflower_compact"]:
			Game.meta.relics.append(id)
		Game.save()
	if scenario == "away":
		# Pretend the player left three hours ago.
		Game.meta.max_seen_unix = 0.0
		Game.save()
		var d: Dictionary = SaveIO.read(Game.save_path)
		d["saved_unix"] = Time.get_unix_time_from_system() - 3.0 * 3600.0
		d["meta"]["max_seen_unix"] = 0.0
		var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		for c: RunState.ColonyState in Game.run.colonies:
			c.prod_level = 200
	if OS.get_cmdline_user_args().has("large=1"):
		Game.meta.large_ui = true
		Game.save()
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	if scenario == "away":
		await _frames(1)
		var img0: Image = get_viewport().get_texture().get_image()
		img0.save_png(out_path.replace(".png", "_early.png"))
	await _frames(20)
	match scenario:
		"sheet":
			main.call("_open_colony", "c1")
		"found":
			main.call("_open_next_site")
		"capital":
			main.call("_open_colony", "c0")
		"nogov":
			Game.meta.governors.clear()
			Game.run.governors.clear()
			main.call("_open_colony", "c1")
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
			Game.run.warehouse["muskets"] = 3.0
			main.call("_select_tab", 3)
			await _frames(5)
			main.call("_show_independence")
			await _frames(200)
		"offline":
			var ev := SimEvents.new()
			ev.gold_earned = 123456.0
			ev.add_shipment("c1", "timber", 40.0, 212)
			ev.crafted["planks"] = 400.0
			main.call("_on_offline", 7300.0, ev)
		"treasure":
			var mv: MapView = main.get("_map")
			mv.set("_treasure_timer", 0.0)
			await _frames(30)
		"settings":
			main.call("_show_settings")
		"research", "research2":
			for id: String in ["crop_rotation", "improved_husbandry"]:
				if not Content.study(id).is_empty():
					Game.run.research[id] = 1
			Game.run.research_version += 1
			Game.run.warehouse["flour"] = 500.0
			Game.run.warehouse["lumber"] = 500.0
			main.call("_select_tab", 1)
			await _frames(5)
			var rs := ResearchScreen.new()
			main.get("_overlay").add_child(rs)
			await _frames(10)
			if scenario == "research2":
				rs.call("_show_branch", "navigation")
				await _frames(5)
				var sc2: ScrollContainer = rs.get("_scroll")
				sc2.scroll_vertical = 1400
		"consult":
			main.call("_on_consult")
		"bigbar":
			Game.meta.liberty = 23456789
			Game.run.colonists_owned = 4800
			Game.run.gold = 1.23e40
			main.call("_refresh")
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
	if OS.get_cmdline_user_args().has("clipcheck=1"):
		_check_clipping(get_tree().root)
	if OS.get_cmdline_user_args().has("burst=1"):
		# Several frames in a row, to catch layout jitter.
		for i in 6:
			await _frames(3)
			var fi: Image = get_viewport().get_texture().get_image()
			fi.save_png(out_path.replace(".png", "_f%d.png" % i))
			var sheet: Control = main.get("_sheet")
			print("frame ", i, " sheet ", sheet.position, " ", sheet.size)
			if i == 0:
				_dump_wide(main, 0)
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


func _dump_wide(n: Node, depth: int) -> void:
	if n is Control:
		var c: Control = n
		var w: float = c.get_combined_minimum_size().x
		if w > 640.0:
			var t: String = (c as Label).text.left(40) if c is Label else ((c as Button).text.left(30) if c is Button else "")
			print("  ".repeat(depth), c.get_class(), " ", c.name, " min_w=", w, " ", t)
	for ch: Node in n.get_children():
		_dump_wide(ch, depth + 1)


## Prints every visible label whose wrapped text needs more lines than fit.
func _check_clipping(n: Node) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		var l: Label = n
		var pr: Control = l.get_parent() as Control
		var card: Node = l.get_parent()
		while card != null and not (card is PanelContainer):
			card = card.get_parent()
		if card != null:
			var cr: Rect2 = (card as Control).get_global_rect()
			var lr: Rect2 = l.get_global_rect()
			if lr.end.y > cr.end.y - 2.0 or lr.end.x > cr.end.x + 1.0:
				print("CARD-OVERFLOW '%s' label=%s card=%s" % [l.text.left(40), lr, cr])
				var a: Node = l
				while a != card.get_parent():
					var ac: Control = a as Control
					print("    ", ac.get_class(), " rect=", ac.get_global_rect(), " min=", ac.get_combined_minimum_size(), " custom=", ac.custom_minimum_size)
					a = a.get_parent()
		if pr != null and l.get_global_rect().end.y > pr.get_global_rect().end.y + 1.0:
			print("OVERFLOW by %.0f '%s' parent=%s %s" % [l.get_global_rect().end.y - pr.get_global_rect().end.y, l.text.left(50), pr.get_class(), pr.get_parent().get_class()])
		if l.get_line_count() > l.get_visible_line_count():
			print("CLIPPED lines %d/%d h=%.0f min=%.0f w=%.0f '%s'" % [l.get_visible_line_count(), l.get_line_count(), l.size.y, l.get_combined_minimum_size().y, l.size.x, l.text.left(50)])
	for c: Node in n.get_children():
		_check_clipping(c)
