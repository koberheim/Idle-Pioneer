## The nation-picker screen, shown once, before a fresh run's very first
## frame (direct request - docs/GAME_DESIGN.md predates this feature
## entirely; the 6 nations and their bonuses are recovered from the
## original Unity project, see NationDef's class doc). Never shown again
## once a save exists - loading an existing save skips straight past this,
## same as it always has.
##
## Full-screen overlay on top of everything else in MainScreen (same
## pattern as MenuPopup/NotificationBar) rather than a separate scene -
## keeps Main.tscn's own structure untouched and reuses the "MainScreen
## owns every overlay" convention already established this session.
extends PanelContainer

signal nation_chosen(nation_id: StringName)

var _list: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var title := Label.new()
	title.text = "Choose Your Nation"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)
	_list.add_child(HSeparator.new())

	for def: NationDef in Db.all_nations():
		_list.add_child(_build_nation_button(def))


func _build_nation_button(def: NationDef) -> Control:
	var button := Button.new()
	button.text = "%s\n%s" % [def.display_name, def.bonus_description]
	button.custom_minimum_size.y = 64
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var swatch := StyleBoxFlat.new()
	swatch.bg_color = def.color
	swatch.corner_radius_top_left = 4
	swatch.corner_radius_top_right = 4
	swatch.corner_radius_bottom_left = 4
	swatch.corner_radius_bottom_right = 4
	swatch.content_margin_left = 14.0
	swatch.content_margin_top = 8.0
	swatch.content_margin_right = 14.0
	swatch.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", swatch)

	button.pressed.connect(func() -> void:
		nation_chosen.emit(def.id)
	)
	return button
