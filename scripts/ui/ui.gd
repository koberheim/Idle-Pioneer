## Shared look: palette, fonts, the theme, and small widget factories so every
## screen is built the same way.
class_name UI
extends RefCounted

const INK := Color("2c1e14")
const INK_SOFT := Color("6b5440")
const LIGHT := Color("f5e9cc")
const LIGHT_SOFT := Color("c9b48f")
const GOLD := Color("f5c850")
const GREEN := Color("3f7d32")
const RED := Color("a8382c")
const BLUE := Color("3b6db0")

const FONT_BODY := preload("res://assets/fonts/LibreBaskerville-Regular.ttf")
const FONT_TITLE := preload("res://assets/fonts/Almendra-Regular.ttf")

const SIZE_SMALL := 18
const SIZE_BODY := 22
const SIZE_BIG := 28
const SIZE_TITLE := 34

static var _theme: Theme
static var _tex_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D
	return _tex_cache[path]


static func icon(name: String) -> Texture2D:
	var path: String = "res://assets/sprites/icons/%s.png" % name
	if ResourceLoader.exists(path):
		return tex(path)
	return tex("res://assets/sprites/icons/crate.png")


static func frame(name: String, margin: float = 14.0, content: float = 14.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex("res://assets/sprites/ui/%s.png" % name)
	sb.set_texture_margin_all(8)
	sb.set_content_margin_all(content)
	sb.content_margin_top = content - 2.0
	sb.content_margin_bottom = content - 2.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = FONT_BODY
	t.default_font_size = SIZE_BODY

	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", frame("panel"))
	t.set_stylebox("panel", "Panel", frame("panel"))

	t.set_stylebox("normal", "Button", frame("button", 14, 10))
	t.set_stylebox("hover", "Button", frame("button_hover", 14, 10))
	t.set_stylebox("pressed", "Button", frame("button_pressed", 14, 10))
	t.set_stylebox("hover_pressed", "Button", frame("button_pressed", 14, 10))
	t.set_stylebox("disabled", "Button", frame("button_disabled", 14, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", LIGHT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", LIGHT)
	t.set_color("font_hover_pressed_color", "Button", LIGHT)
	t.set_color("font_disabled_color", "Button", Color("4a3e34"))
	t.set_color("font_focus_color", "Button", LIGHT)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 40)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.36, 0.26, 0.18, 0.7)
	grabber.set_corner_radius_all(3)
	var track := StyleBoxEmpty.new()
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", track)

	t.set_stylebox("background", "ProgressBar", bar_style(Color("2e241c"), Color("140e0a")))
	t.set_stylebox("fill", "ProgressBar", bar_style(Color("e0b03c"), Color("140e0a")))
	t.set_color("font_color", "ProgressBar", LIGHT)
	t.set_font_size("font_size", "ProgressBar", SIZE_SMALL)

	t.set_font_size("font_size", "RichTextLabel", SIZE_BODY)
	t.set_color("default_color", "RichTextLabel", INK)
	_theme = t
	return t


# --- Widget factories ---------------------------------------------------------

static func label(text: String = "", size: int = SIZE_BODY, color: Color = INK, title_font: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title_font:
		l.add_theme_font_override("font", FONT_TITLE)
	return l


static func wrap_label(text: String = "", size: int = SIZE_SMALL, color: Color = INK_SOFT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 10
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func icon_rect(texture: Texture2D, px: float = 32.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, style: String = "button", min_height: float = 64.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.focus_mode = Control.FOCUS_NONE
	if style != "button":
		b.add_theme_stylebox_override("normal", frame(style, 14, 10))
		b.add_theme_stylebox_override("hover", frame(style, 14, 10))
		b.add_theme_stylebox_override("pressed", frame(style + "_pressed", 14, 10))
		b.add_theme_stylebox_override("hover_pressed", frame(style + "_pressed", 14, 10))
		if style == "button_gold":
			b.add_theme_color_override("font_color", INK)
			b.add_theme_color_override("font_hover_color", INK)
			b.add_theme_color_override("font_pressed_color", INK)
	return b


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func card(style: String = "card") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(style))
	return p


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func bar(fill_style: String = "bar_fill") -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size.y = 22
	p.max_value = 1.0
	p.step = 0.0
	var colors: Dictionary = {"bar_fill": Color("e0b03c"), "bar_fill_blue": Color("5a8cd2"), "bar_fill_green": Color("60a848")}
	p.add_theme_stylebox_override("fill", bar_style(colors.get(fill_style, Color("e0b03c")), Color("140e0a")))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func bar_style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.border_width_top = 3
	sb.shadow_size = 0
	sb.anti_aliasing = false
	return sb


## Cost shown with a gold coin: "[coin] 1.23K".
static func cost_text(amount: float) -> String:
	return Format.num(amount)


## Which settlement sprite a colony shows; it grows as it is developed.
static func colony_sprite_name(c: RunState.ColonyState) -> String:
	if c.tier == 0:
		return "capital"
	var total: int = c.prod_level + c.cargo_level + c.speed_level + c.colonists * 3
	if total >= 60:
		return "colony_3"
	if total >= 15:
		return "colony_2"
	return "colony_1"


static func nation_color(nation_id: String) -> Color:
	return Color(str(Content.nation(nation_id).get("color", "#888888")))
