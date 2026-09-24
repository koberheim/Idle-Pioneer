## A nation's colonial-era flag, drawn in flat pixel blocks.
class_name Flag
extends Control

var nation_id: String = ""


func _init(p_nation: String = "") -> void:
	nation_id = p_nation
	custom_minimum_size = Vector2(72, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var white := Color("f2eee2")
	var red := Color("b8312a")
	var blue := Color("24488f")
	var gold := Color("e8b830")
	match nation_id:
		"english":
			draw_rect(Rect2(0, 0, w, h), white)
			draw_rect(Rect2(w * 0.4, 0, w * 0.2, h), red)
			draw_rect(Rect2(0, h * 0.38, w, h * 0.24), red)
		"french":
			draw_rect(Rect2(0, 0, w, h), blue)
			for p: Vector2 in [Vector2(0.3, 0.32), Vector2(0.7, 0.32), Vector2(0.5, 0.7)]:
				var c := Vector2(w * p.x, h * p.y)
				draw_rect(Rect2(c - Vector2(3, 6), Vector2(6, 12)), gold)
				draw_rect(Rect2(c - Vector2(6, 1), Vector2(12, 4)), gold)
		"spanish":
			draw_rect(Rect2(0, 0, w, h), white)
			draw_line(Vector2(4, 2), Vector2(w - 4, h - 2), red, 7.0)
			draw_line(Vector2(w - 4, 2), Vector2(4, h - 2), red, 7.0)
		"dutch":
			draw_rect(Rect2(0, 0, w, h / 3.0), Color("e07b1a"))
			draw_rect(Rect2(0, h / 3.0, w, h / 3.0), white)
			draw_rect(Rect2(0, h * 2.0 / 3.0, w, h / 3.0 + 1), blue)
		"portuguese":
			draw_rect(Rect2(0, 0, w, h), white)
			var s := Rect2(w * 0.34, h * 0.18, w * 0.32, h * 0.64)
			draw_rect(s, red)
			draw_rect(s.grow(-4), white)
			draw_rect(Rect2(s.position + Vector2(s.size.x * 0.38, 7), Vector2(s.size.x * 0.24, s.size.y - 14)), blue)
		"swedish":
			draw_rect(Rect2(0, 0, w, h), Color("2c64b0"))
			draw_rect(Rect2(w * 0.3, 0, w * 0.16, h), gold)
			draw_rect(Rect2(0, h * 0.4, w, h * 0.2), gold)
		_:
			draw_rect(Rect2(0, 0, w, h), UI.nation_color(nation_id))
	draw_rect(Rect2(0, 0, w, h), Color("2c1e14"), false, 3.0)
