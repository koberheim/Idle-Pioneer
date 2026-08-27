## The Crafting tab. One card per recipe in a 2-column grid: its inputs and
## output, a "Craft One" button (instant, exactly Crafting.craft()), and an
## Auto-Craft toggle (CraftingStation - rework task: continuous crafting).
##
## Direct request: only discovered recipes are listed (Game.discoveries -
## see its class doc), in the order discovered, not the full authored
## recipe table up front.
##
## Built entirely in code, same pattern as ColoniesPanel - see that class
## doc for why.
extends Control

const ICON_SIZE := Vector2(40, 40)

var _grid: GridContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The grid must never need horizontal scrolling (direct request) - a
	# disabled scroll mode is a hard guarantee of that, not just a hope that
	# every card's content stays narrow enough on its own.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# No initial refresh() here - see ColoniesPanel's class doc: MainScreen
	# calls it once real boot state (new_run()/a loaded save) exists.


func refresh() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	for id: StringName in Game.discoveries.discovered_recipes():
		var recipe: RecipeDef = Db.recipe(id)
		if recipe != null:
			_grid.add_child(_build_row(recipe))


func _build_row(recipe: RecipeDef) -> Control:
	var row := PanelContainer.new()
	# A GridContainer sizes each column to its widest cell's minimum size -
	# without an explicit cap here, one long recipe description would widen
	# its whole column past half the screen and force horizontal scrolling
	# (the exact bug being fixed). SIZE_EXPAND_FILL alone isn't enough since
	# it only controls how leftover space is distributed, not the minimum.
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.x = 0
	var vbox := VBoxContainer.new()
	row.add_child(vbox)

	var output_def: ResourceDef = Db.resource(recipe.output_id)
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var icon_texture: Texture2D = recipe.icon
	if icon_texture == null and output_def != null:
		icon_texture = output_def.icon
	header.add_child(_make_icon_or_placeholder(icon_texture, recipe.id))

	var label := Label.new()
	label.text = "%s: %s -> %d %s (%.1fs)" % [
		recipe.display_name, _inputs_text(recipe), recipe.output_amount,
		output_def.display_name if output_def != null else String(recipe.output_id),
		recipe.craft_seconds,
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


## No recipe art exists yet (RecipeDef.icon is unset everywhere) - a flat
## colored square, keyed off the recipe's id so it's stable and visually
## distinct per recipe, stands in until real sprites are authored.
func _make_icon_or_placeholder(texture: Texture2D, recipe_id: StringName) -> Control:
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return icon

	var placeholder := ColorRect.new()
	placeholder.custom_minimum_size = ICON_SIZE
	placeholder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hash_val: int = hash(recipe_id)
	placeholder.color = Color.from_hsv(float(hash_val % 360) / 360.0, 0.45, 0.75)
	return placeholder


func _inputs_text(recipe: RecipeDef) -> String:
	var parts: Array[String] = []
	for ingredient: RecipeIngredient in recipe.inputs:
		var ing_def: ResourceDef = Db.resource(ingredient.resource_id)
		parts.append("%d %s" % [
			ingredient.amount, ing_def.display_name if ing_def != null else String(ingredient.resource_id)
		])
	return ", ".join(parts)
