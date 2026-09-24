## One upgrade track: icon, name and level, what the next purchase changes,
## and a buy button. Built once and updated in place.
class_name UpgradeRow
extends PanelContainer

var title: Label
var detail: Label
var buy: BuyButton
var icon: TextureRect


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
	detail.custom_minimum_size.x = 10
	text.add_child(title)
	text.add_child(detail)
	row.add_child(text)
	buy = BuyButton.new(action)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)


func set_values(p_title: String, p_detail: String, cost: float, affordable: bool) -> void:
	if title.text != p_title:
		title.text = p_title
	if detail.text != p_detail:
		detail.text = p_detail
	buy.set_cost(Format.num(cost), affordable)
