## The permanent roster of colonial governors:
## commission new ones and promote existing ones with Liberty.
class_name GovernorRoster
extends VBoxContainer

const TYPE_ICONS: Dictionary = {"prod": "pick", "cargo": "crate", "speed": "speed"}

var _commission: Dictionary = {}
var _list: VBoxContainer
var _count: int = -1
var _rows: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var intro := UI.wrap_label("Governors serve for life. Post one to a colony to multiply its production, cargo or route speed. They stay with you through every declaration of independence.", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	add_child(intro)
	var row := UI.hbox(8)
	for t: Dictionary in Content.governor_types:
		var type_id: String = t["id"]
		var b := BuyButton.new(func() -> bool: return Game.commission_governor(type_id))
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(0)
		v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		v.offset_top = 6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := UI.label(str(t["title"]), UI.SIZE_SMALL, UI.LIGHT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(title)
		b.add_child(v)
		# Push the cost row to the bottom half of the button.
		(b.get_child(0) as Control).offset_top = 36
		_commission[type_id] = b
		row.add_child(b)
	add_child(row)
	_list = UI.vbox(8)
	add_child(_list)


func refresh() -> void:
	var meta: MetaState = Game.meta
	var cost: int = Balance.governor_commission_cost(meta)
	for type_id: String in _commission.keys():
		(_commission[type_id] as BuyButton).set_cost(str(cost), meta.liberty >= cost, "liberty")
	if meta.governors.size() != _count:
		_count = meta.governors.size()
		_rebuild()
	for gid: int in _rows.keys():
		_update_row(gid)


func _rebuild() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	_rows.clear()
	for g: Dictionary in Game.meta.governors:
		var gid: int = g["id"]
		var card := UI.card("card")
		var row := UI.hbox(10)
		card.add_child(row)
		row.add_child(UI.icon_rect(UI.icon(str(TYPE_ICONS.get(g["type"], "star"))), 44))
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := UI.label(str(g["name"]), UI.SIZE_BODY, UI.INK)
		var info := UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.x = 10
		v.add_child(name_l)
		v.add_child(info)
		row.add_child(v)
		var promote := BuyButton.new(func() -> bool: return Game.promote_governor(gid))
		promote.custom_minimum_size = Vector2(150, 64)
		row.add_child(promote)
		card.set_meta("info", info)
		card.set_meta("promote", promote)
		_rows[gid] = card
		_list.add_child(card)


func _update_row(gid: int) -> void:
	var card: Control = _rows[gid]
	var g: Dictionary = Game.meta.governor(gid)
	var t: Dictionary = Content.governor_type(str(g["type"]))
	var rank: int = g["rank"]
	var posted: String = ""
	if Game.run != null:
		var at: String = Game.run.colony_of_governor(gid)
		if at != "":
			posted = "  ·  at " + Content.colony_name(Game.run.nation_id, Content.colony_index(at))
	(card.get_meta("info") as Label).text = "%s %s  ·  ×%s %s%s" % [t.get("title", ""), "★".repeat(rank), Format.rate(Balance.governor_multiplier_for_rank(rank)), t.get("desc", ""), posted]
	var cost: int = Balance.governor_rank_cost(rank)
	var b: BuyButton = card.get_meta("promote")
	if cost < 0:
		b.set_cost("Max", false, "")
	else:
		b.set_cost(str(cost), Game.meta.liberty >= cost, "liberty")
