## Renders the real game in a scripted state and saves a screenshot. Dev tool.
##   godot --path . res://tools/shot.tscn -- scenario=map out=C:/tmp/map.png
extends Node

var scenario: String = "map"
var map_style: String = WorldMap.STYLE_RANDOM
var out_path: String = "user://shot.png"
var save_name: String = "shot_save"
var main: Control


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("scenario="):
			scenario = arg.substr(9)
		elif arg.begins_with("out="):
			out_path = arg.substr(4)
		elif arg.begins_with("map="):
			map_style = arg.substr(4)
		elif arg.begins_with("save="):
			save_name = arg.substr(5).validate_filename()
			if save_name == "" or save_name.begins_with("save"):
				save_name = "shot_save"
		elif arg.begins_with("winsize="):
			# Store screenshots: an exact pixel size, even taller than the desktop
			# (a borderless window isn't clamped to the screen like a framed one).
			var wh: PackedStringArray = arg.substr(8).split("x")
			get_window().borderless = true
			get_window().position = Vector2i.ZERO
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	# Never the player's save.json: a scratch file, nameable so parallel runs don't collide.
	Game.save_path = "user://%s.json" % save_name
	SaveIO.delete(Game.save_path)
	Game.meta = MetaState.new()
	Game.meta.music_on = false
	Game.meta.sfx_on = false
	if scenario.begins_with("store_"):
		_seed_store()
	elif scenario == "fresh":
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
	if scenario.begins_with("store_"):
		await _stage_store()
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
	if scenario.begins_with("store_"):
		# No floating "+gold" numbers drifting over the town names: hold the
		# world still (no new shipments) and clear the ones in flight.
		Game.pause("shot")
		await _frames(1)
		var mvf: MapView = main.get("_map")
		(mvf.get("_floaters") as Array).clear()
		mvf.set("_pending_gold", 0.0)
		(mvf.get("_labels") as Control).queue_redraw()
		(mvf.get("_dynamic") as Node2D).queue_redraw()
		await _frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("saved ", out_path, " ", img.get_size())
	SaveIO.delete(Game.save_path)
	get_tree().quit()


# --- Store screenshots (tools/store/build_store.py) --------------------------
# A plausible late-game expedition: the 5th, a dozen colonies, most workshops
# running, Congress half full, a few studies and relics. Rich but readable.

func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback


func _seed_store() -> void:
	var meta: MetaState = Game.meta
	meta.tips_on = false
	meta.runs_completed = 4
	meta.lifetime_liberty = 214
	meta.liberty = 23
	meta.best_run_gold = 5.6e9
	meta.upgrades = {"industry": 6, "navigation": 3, "settlement": 5, "commerce": 5, "manufacture": 4}
	for f: String in ["ledger", "relics", "almanac", "specializations", "research"]:
		meta.hints_seen.append("unlock_" + f)
	meta.almanacs = 2
	meta.best_colonies = 16
	meta.record_relics_claimed = [5, 10, 15]
	meta.record_almanac_claimed = 16
	for id: String in ["kite_key", "franklin_stove", "armonica", "bifocals", "poor_richard",
			"tea_chest", "common_sense", "revere_lantern", "orrery", "chronometer",
			"mayflower_compact", "bay_psalm", "pine_tree_shilling", "long_rifle",
			"conestoga_wheel", "octant", "bill_of_lading", "try_pot"]:
		meta.relics.append(id)
	meta.stats = {"gold_earned": 1.83e10, "shipments": 41250, "land_colonies": 38, "sea_colonies": 21,
		"father_franklin": 3, "father_washington": 2, "fathers_joined": 41, "studies": 37,
		"delivered_furs": 88000, "seconds_played": 151200, "land_leagues": 412000,
		"sea_leagues": 167000, "app_opens": 64, "upgrades_bought": 9800, "specializations": 9}
	var names: Array = ["John Winthrop", "Samuel de Champlain", "Eliza Lucas", "Peter Minuit", "Johan Printz"]
	var types: Array = ["prod", "cargo", "speed", "prod", "cargo"]
	var ranks: Array = [4, 3, 3, 2, 1]
	for i in names.size():
		meta.governors.append({"id": i + 1, "name": names[i], "type": types[i], "rank": ranks[i]})
	meta.next_governor_id = names.size() + 1
	meta.favor_ready_unix = 0.0
	meta.ad_skip_ready_unix = 0.0

	Game.run = RunState.create(_arg("nation", "english"), map_style, int(_arg("seed", "7")))
	var run: RunState = Game.run
	var count: int = int(_arg("colonies", "11"))
	for i in count - 1:
		run.found_next()
	for c: RunState.ColonyState in run.colonies:
		var t: int = c.tier
		var lv: float = float(_arg("lv", "1.0"))
		c.prod_level = maxi(10, int((52 - t * 3) * lv))
		c.cargo_level = maxi(6, int((34 - t * 2) * lv))
		c.speed_level = maxi(2, int((10 - t / 2) * lv))
		c.colonists = 3 - t % 3
		if t >= 1 and t <= 5:
			c.charter = 3 if t <= 2 else (2 if t <= 4 else 1)
			c.spec = str(Balance.specs_offered(run, c)[t % 2]["id"])
	run.colonists_owned = 64
	for i in mini(4, run.colonies.size() - 1):
		run.governors["c%d" % (i + 1)] = i + 1
	# Work the colonies until their goods are known, then open the workshops
	# those goods allow, and repeat (crafted goods unlock further recipes).
	var ev := SimEvents.new()
	for c: RunState.ColonyState in run.colonies:
		var rid: String = run.resource_of(c)
		if not run.discovered.has(rid):
			run.discovered.append(rid)
	var built: int = 0
	for pass_i in 4:
		for def: Dictionary in Content.recipes:
			var w: RunState.WorkshopState = run.workshop(def["id"])
			if w.built or built >= 16 or not Game.workshop_unlocked(def["id"]):
				continue
			w.built = true
			w.level = maxi(5, int((34 - built * 2) * float(_arg("lv", "1.0"))))
			w.colonists = 2 + built % 3
			built += 1
			if not run.discovered.has(def["id"]):
				run.discovered.append(def["id"])
	for id: String in run.discovered:
		run.warehouse[id] = run.stock_of(id) + 900.0
	run.warehouse["muskets"] = 14.0
	run.hold["timber"] = true
	run.hold["pig_iron"] = true
	# Congress: the first tiers seated, a few still to invite.
	var offered: Array[Dictionary] = Balance.fathers_offered(run)
	var seated: int = 0
	for f: Dictionary in offered:
		if int(f.get("tier", 1)) <= 2 and seated < 7:
			run.fathers.append(str(f["id"]))
			seated += 1
	# The Philosophical Society: early studies in every branch.
	var studied: int = 0
	for pass_i in 3:
		for d: Dictionary in Content.research:
			if studied >= 16 or int(d.get("tier", 1)) > 2:
				continue
			var id: String = str(d["id"])
			if Balance.study_block(run, meta, id) == "":
				run.research[id] = 1
				studied += 1
	run.research_version += 1
	for i in 240:
		Sim.step(run, meta, 1.0, ev)
	run.gold = 2.47e9
	run.lifetime_gold = 1.86e10
	run.play_seconds = 2.0 * 3600.0 + 41.0 * 60.0
	run.colonies[1].stock = 0.0
	if OS.get_cmdline_user_args().has("verbose=1"):
		for c: RunState.ColonyState in run.colonies:
			print("%s %s rate=%.0f trip=%.1fs thr=%.0f" % [c.id, run.resource_of(c), Balance.production_rate(run, meta, c), Balance.round_trip_seconds(run, meta, c), Balance.route_throughput(run, meta, c)])
	Game.running = true
	Game.save()


func _stage_store() -> void:
	match scenario:
		"store_map":
			var mv: MapView = main.get("_map")
			mv.zoom_by(float(_arg("zoom", "1.0")))
		"store_sheet":
			main.call("_open_colony", _arg("colony", "c1"))
		"store_spec":
			main.call("_open_colony", _arg("colony", "c1"))
			await _frames(10)
			var sheet: Control = main.get("_sheet")
			var sc: ScrollContainer = sheet.get("_scroll")
			sc.scroll_vertical = int(_arg("scroll", "2000"))
		"store_workshops":
			main.call("_select_tab", 1)
		"store_europe":
			main.call("_select_tab", 2)
		"store_congress":
			main.call("_select_tab", 3)
			await _frames(10)
			var p: Page = main.get("_pages")[3]
			p.scroll.scroll_vertical = int(_arg("scroll", "0"))
		"store_declare":
			main.call("_select_tab", 3)
			await _frames(5)
			main.call("_show_independence")
			await _frames(int(_arg("wait", "200")))
			if _arg("sign", "1") == "1":
				# The quill touches the page: signature, seal and the Liberty earned.
				for o: Node in main.get("_overlay").get_children():
					if o is IndependenceOverlay:
						o.call("_on_sign")
				await _frames(170)
		"store_research":
			main.call("_select_tab", 1)
			await _frames(5)
			var rs := ResearchScreen.new()
			main.get("_overlay").add_child(rs)
			await _frames(10)
			var br: String = _arg("branch", "")
			if br != "":
				rs.call("_show_branch", br)
				await _frames(5)
		"store_ledger":
			main.call("_select_tab", 4)
			await _frames(10)
			var lp: Page = main.get("_pages")[4]
			lp.scroll.scroll_vertical = int(_arg("scroll", "0"))
		"store_nation":
			pass
	await _frames(int(_arg("settle", "0")))



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
		var vw: float = l.get_viewport_rect().size.x
		if l.get_global_rect().end.x > vw + 1.0 and l.get_global_rect().position.x < vw:
			print("OFFSCREEN '%s' ends at %.0f of %.0f" % [l.text.left(40), l.get_global_rect().end.x, vw])
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
