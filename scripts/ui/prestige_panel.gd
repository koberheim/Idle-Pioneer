## The Prestige tab. Top to bottom: this run's Progression upgrades (gold,
## resets every run - Db.all_upgrades()), the Declare Independence section
## (gate progress, projected payout, the button itself), and the three
## permanent Liberty-funded branches (Industry/Navigation/Settlement -
## Prestige, rework task: real prestige system).
##
## Built entirely in code, same pattern as ColoniesPanel - see that class
## doc for why.
extends Control

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

	_list.add_child(_section_label("This Run's Upgrades"))
	for def: UpgradeDef in Db.all_upgrades():
		_list.add_child(_build_progression_row(def))

	_list.add_child(HSeparator.new())
	_list.add_child(_section_label("Declare Independence"))
	_list.add_child(_build_declare_section())

	_list.add_child(HSeparator.new())
	_list.add_child(_section_label("Liberty: %d" % Game.prestige.liberty()))
	_list.add_child(_build_branch_row(
		"Industry (+15%% production/level)", Game.prestige.industry_level(), Balance.industry_max_level(),
		Game.prestige.next_industry_cost(), Game.prestige.can_purchase_industry(), Game.prestige.purchase_industry
	))
	_list.add_child(_build_branch_row(
		"Navigation (+12%% speed & cargo/level)", Game.prestige.navigation_level(), Balance.navigation_max_level(),
		Game.prestige.next_navigation_cost(), Game.prestige.can_purchase_navigation(), Game.prestige.purchase_navigation
	))
	_list.add_child(_build_branch_row(
		"Settlement (-7%% colonist/colony cost per level)", Game.prestige.settlement_level(), Balance.settlement_max_level(),
		Game.prestige.next_settlement_cost(), Game.prestige.can_purchase_settlement(), Game.prestige.purchase_settlement
	))


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _build_progression_row(def: UpgradeDef) -> Control:
	var row := HBoxContainer.new()

	if def.icon != null:
		var icon := TextureRect.new()
		icon.texture = def.icon
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(icon)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	if Game.progression.is_purchased(def.id):
		label.text = "%s - purchased" % def.display_name
	else:
		label.text = "%s (%dg)" % [def.display_name, def.gold_cost]
		var buy := Button.new()
		buy.text = "Buy"
		buy.disabled = not Game.progression.can_purchase(def.id)
		buy.pressed.connect(func() -> void:
			Game.progression.purchase(def.id)
			refresh()
		)
		row.add_child(buy)

	return row


func _build_declare_section() -> Control:
	var box := VBoxContainer.new()

	var earned: float = Game.prestige.lifetime_gold_earned_this_run()
	var progress := Label.new()
	progress.text = "This run has earned %.0f gold" % earned
	box.add_child(progress)

	var payout := Label.new()
	payout.text = "Projected Liberty payout: %d" % Game.prestige.projected_liberty_payout()
	box.add_child(payout)

	var button := Button.new()
	var can_declare: bool = Game.prestige.can_declare_independence()
	button.text = "Declare Independence"
	button.disabled = not can_declare
	button.pressed.connect(func() -> void:
		Game.prestige.declare_independence()
		refresh()
	)
	box.add_child(button)

	return box


func _build_branch_row(
	label_text: String, level: int, max_level: int, cost: float, can_purchase: bool, purchase_fn: Callable
) -> Control:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = "%s - level %d/%d" % [label_text, level, max_level]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	if level >= max_level:
		var maxed := Label.new()
		maxed.text = "Maxed"
		row.add_child(maxed)
	else:
		var buy := Button.new()
		buy.text = "Buy (%d Liberty)" % int(round(cost))
		buy.disabled = not can_purchase
		buy.pressed.connect(func() -> void:
			purchase_fn.call()
			refresh()
		)
		row.add_child(buy)

	return row
