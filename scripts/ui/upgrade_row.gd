## One upgrade track: icon, name and level, what the next purchase changes,
## and a buy button. Built once and updated in place.
class_name UpgradeRow
extends PanelContainer

var title: Label
var detail: Label
var buy: BuyButton
var icon: TextureRect
var _mile_box: HBoxContainer
var _mile_bar: ProgressBar
var _mile_label: Label


func _init(icon_name: String, action: Callable) -> void:
	add_theme_stylebox_override("panel", UI.frame("card", 14, 12))
	var row := UI.hbox(12)
	add_child(row)
	icon = UI.icon_rect(UI.icon(icon_name), 48)
	row.add_child(icon)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title = UI.label("", UI.SIZE_BODY, UI.INK)
	detail = UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.resized.connect(detail.update_minimum_size)
	detail.custom_minimum_size.x = 10
	text.add_child(title)
	text.add_child(detail)
	# Progress toward the next milestone, where the track's output doubles.
	_mile_box = UI.hbox(6)
	_mile_box.visible = false
	var medal := UI.icon_rect(UI.icon("milestone"), 22)
	_mile_box.add_child(medal)
	_mile_bar = UI.bar("bar_fill")
	_mile_bar.custom_minimum_size = Vector2(90, 12)
	_mile_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mile_box.add_child(_mile_bar)
	_mile_label = UI.label("", UI.SIZE_MIN, UI.INK_SOFT)
	_mile_box.add_child(_mile_label)
	text.add_child(_mile_box)
	row.add_child(text)
	buy = BuyButton.new(action)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)


## Shows how far `level` is toward the next milestone and what it will give.
func set_milestone(level: int, reward: String) -> void:
	_mile_box.visible = true
	var prev: int = Balance.prev_milestone(level)
	var next: int = Balance.next_milestone(level)
	_mile_bar.value = float(level - prev) / float(maxi(1, next - prev))
	var t: String = "%s at Lv %d" % [reward, next]
	if _mile_label.text != t:
		_mile_label.text = t


func set_values(p_title: String, p_detail: String, cost: float, affordable: bool) -> void:
	if title.text != p_title:
		title.text = p_title
	if detail.text != p_detail:
		detail.text = p_detail
	buy.set_cost(Format.num(cost), affordable)
