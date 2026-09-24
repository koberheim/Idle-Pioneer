## Dev tool: builds maps and writes flat-colour previews with site numbers.
##   godot --headless --path . res://tools/map_preview.tscn -- out=C:/tmp seeds=1,2,3
extends Node

const COLORS := [
	Color("1d3f78"), Color("3c7fa8"), Color("9a9a78"), Color("2f5e3e"), Color("4f8a38"), Color("98a84a"),
	Color("7aa84a"), Color("c0a860"), Color("4f6a4a"), Color("3f9a4a"), Color("8a7a50"), Color("6a6460"),
]


func _ready() -> void:
	var out: String = "user://"
	var seeds: Array = [1, 2, 3]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("seeds="):
			seeds = Array(arg.substr(6).split(","))
	for s: Variant in seeds:
		_render(WorldMap.STYLE_RANDOM, int(s), out)
	_render(WorldMap.STYLE_NORTH_AMERICA, 1, out)
	get_tree().quit()


func _render(style: String, seed_value: int, out: String) -> void:
	var t0: int = Time.get_ticks_msec()
	var m := WorldMap.build(style, seed_value)
	var ms: int = Time.get_ticks_msec() - t0
	var sc: int = 6
	var img := Image.create(WorldMap.W * sc, WorldMap.H * sc, false, Image.FORMAT_RGBA8)
	for y in WorldMap.H:
		for x in WorldMap.W:
			img.fill_rect(Rect2i(x * sc, y * sc, sc, sc), COLORS[m.t_at(x, y)])
	for n in m.colony_order.size():
		var s: Dictionary = m.sites[m.colony_order[n]]
		var col: Color = Color.RED if s["route"] == "sea" else Color.YELLOW
		if n == 0:
			col = Color.WHITE
		img.fill_rect(Rect2i(int(s["x"]) * sc - 2, int(s["y"]) * sc - 2, sc + 4, sc + 4), Color.BLACK)
		img.fill_rect(Rect2i(int(s["x"]) * sc, int(s["y"]) * sc, sc, sc), col)
		var r: Dictionary = m.route(m.colony_order[n])
		for p: Vector2 in r["points"]:
			img.set_pixel(int(p.x) * sc + sc / 2, int(p.y) * sc + sc / 2, Color.WHITE)
	var path: String = "%s/map_%s_%d.png" % [out, style, seed_value]
	img.save_png(path)
	var res: Dictionary = {}
	for n in m.colony_order.size():
		var rid: String = m.sites[m.colony_order[n]]["resource"]
		res[rid] = int(res.get(rid, 0)) + 1
	print("%s seed %d: %d ms, %d sites, order %d, resources %s" % [style, seed_value, ms, m.sites.size(), m.colony_order.size(), res])
	var first: PackedStringArray = []
	for n in mini(10, m.colony_order.size()):
		first.append(str(m.sites[m.colony_order[n]]["resource"]))
	print("   first colonies: ", ", ".join(first))
