## A signature drawn in ink: the player's own hand from a Declaration.
## Strokes are stored as flat [x0, y0, x1, y1, ...] arrays in 0..1000 units
## of the pad they were written on, whose width/height ratio is `aspect`.
class_name SignatureView
extends Control

const INK := Color(0.12, 0.08, 0.2)
const SCALE := 1000.0

var strokes: Array = []
var aspect: float = 4.0


func _init(p_strokes: Array = [], p_aspect: float = 4.0) -> void:
	strokes = p_strokes
	aspect = p_aspect
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 96)


func _draw() -> void:
	# Fit the pad into this control, keeping its proportions, centred.
	var w: float = size.x
	var h: float = size.y
	var pw: float = minf(w, h * aspect)
	var ph: float = pw / aspect
	var origin := Vector2((w - pw) * 0.5, (h - ph) * 0.5)
	draw_ink(self, strokes, origin, Vector2(pw, ph) / SCALE, maxf(1.5, ph / 40.0))


## Draws normalized strokes onto `ci` at `origin`, scaled by `scale`.
static func draw_ink(ci: CanvasItem, p_strokes: Array, origin: Vector2, scale: Vector2, width: float) -> void:
	for s: Variant in p_strokes:
		var flat: Array = s
		var pts := PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			pts.append(origin + Vector2(float(flat[i]), float(flat[i + 1])) * scale)
		if pts.size() == 1:
			ci.draw_circle(pts[0], width * 0.5, INK)
		elif pts.size() >= 2:
			ci.draw_polyline(pts, INK, width, true)
