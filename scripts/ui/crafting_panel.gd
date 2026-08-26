## The Crafting tab. One row per recipe: its inputs and output, a "Craft
## One" button (instant, exactly Crafting.craft()), and an Auto-Craft toggle
## (CraftingStation - rework task: continuous crafting).
##
## Built entirely in code, same pattern as ColoniesPanel - see that class
## doc for why.
extends Control

const ICON_SIZE := Vector2(40, 40)

var _list: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# No initial refresh() here - see ColoniesPanel's class doc: MainScreen
	# calls it once real boot state (new_run()/a loaded save) exists.


func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for recipe: RecipeDef in Db.all_recipes():
		_list.add_child(_build_row(recipe))


func _build_row(recipe: RecipeDef) -> Control:
	var row := PanelContainer.new()
	var vbox := VBoxContainer.new()
	row.add_child(vbox)

	var output_def: ResourceDef = Db.resource(recipe.output_id)
	var header := HBoxContainer.new()
	vbox.add_child(header)

	if output_def != null and output_def.icon != null:
		var icon := TextureRect.new()
		icon.texture = output_def.icon
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		header.add_child(icon)

	var label := Label.new()
	label.text = "%s: %s -> %d %s (%.1fs)" % [
		recipe.display_name, _inputs_text(recipe), recipe.output_amount,
		output_def.display_name if output_def != null else String(recipe.output_id),
		recipe.craft_seconds,
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var craft_button := Button.new()
	craft_button.text = "Craft One"
	craft_button.disabled = not Crafting.can_craft(recipe.id)
	craft_button.pressed.connect(func() -> void:
		Crafting.craft(recipe.id)
		refresh()
	)
	buttons.add_child(craft_button)

	var station: CraftingStation = Game.crafting_stations.get_or_create(recipe.id)
	var auto_toggle := Button.new()
	auto_toggle.toggle_mode = true
	auto_toggle.button_pressed = station.auto_craft
	auto_toggle.text = "Auto-Craft: ON" if station.auto_craft else "Auto-Craft: OFF"
	auto_toggle.pressed.connect(func() -> void:
		station.auto_craft = not station.auto_craft
		refresh()
	)
	buttons.add_child(auto_toggle)

	return row


func _inputs_text(recipe: RecipeDef) -> String:
	var parts: Array[String] = []
	for ingredient: RecipeIngredient in recipe.inputs:
		var ing_def: ResourceDef = Db.resource(ingredient.resource_id)
		parts.append("%d %s" % [
			ingredient.amount, ing_def.display_name if ing_def != null else String(ingredient.resource_id)
		])
	return ", ".join(parts)
