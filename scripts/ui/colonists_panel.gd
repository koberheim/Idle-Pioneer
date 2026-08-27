## The Colonists tab (direct request - replaces the old Prestige tab slot;
## Prestige moved to the top-right menu). Everything about owning and
## staffing colonists lives here now: recruiting, upgrading, and assigning/
## unassigning to a founded colony's matching slot. Previously split between
## a recruit row and per-colony assignment controls embedded in
## ColoniesPanel - that panel now only shows a read-only summary of who's
## assigned where.
##
## Built entirely in code, same pattern as ColoniesPanel - see that class
## doc for why.
extends Control

const TYPE_LABELS: Dictionary = {
	Colonist.Type.RESOURCE: "Resource",
	Colonist.Type.CARGO: "Cargo",
	Colonist.Type.SPEED: "Speed",
}

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

	if Game.run == null:
		return

	_list.add_child(_build_summary_row())
	_list.add_child(_build_recruit_row())
	_list.add_child(HSeparator.new())

	for colonist: Colonist in Game.colonists.all():
		_list.add_child(_build_colonist_row(colonist))


func _build_summary_row() -> Control:
	var label := Label.new()
	label.text = "Influence: %s   Colonists owned: %d   Idle: %d" % [
		Format.number(Game.colonists.influence(), 1), Game.colonists.colonists_owned(), Game.colonists.idle_colonists().size()
	]
	return label


func _build_recruit_row() -> Control:
	var row := HBoxContainer.new()
	var cost: float = Game.colonists.next_recruit_cost()
	for type: Colonist.Type in [Colonist.Type.RESOURCE, Colonist.Type.CARGO, Colonist.Type.SPEED]:
		var button := Button.new()
		button.text = "Recruit %s (%s)" % [TYPE_LABELS[type], Format.number(cost, 1)]
		button.disabled = Game.colonists.influence() < cost
		button.pressed.connect(func() -> void:
			Game.colonists.recruit(type)
			refresh()
		)
		row.add_child(button)
	return row


func _build_colonist_row(colonist: Colonist) -> Control:
	var box := VBoxContainer.new()

	var header := HBoxContainer.new()
	box.add_child(header)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s - level %d" % [TYPE_LABELS[colonist.type], colonist.level]
	header.add_child(label)

	var upgrade_cost: float = Game.colonists.next_upgrade_cost(colonist.id)
	var upgrade_button := Button.new()
	upgrade_button.text = "Upgrade (%s)" % Format.number(upgrade_cost, 1)
	upgrade_button.disabled = Game.colonists.influence() < upgrade_cost
	upgrade_button.pressed.connect(func() -> void:
		Game.colonists.upgrade(colonist.id)
		refresh()
	)
	header.add_child(upgrade_button)

	if colonist.assigned_colony_id == &"":
		box.add_child(_build_assignment_options(colonist))
	else:
		box.add_child(_build_assigned_status(colonist))

	return box


## One "Assign to X" button per founded colony that has an empty slot of
## this colonist's own type - usually a handful of colonies at most, so a
## flat button row is simpler than an OptionButton + separate confirm step.
func _build_assignment_options(colonist: Colonist) -> Control:
	var row := HBoxContainer.new()

	var any_target := false
	for colony: Colony in Game.colonies.all():
		if Game.colonists.colonist_at(colony.colony_id, colonist.type) != null:
			continue
		any_target = true
		var button := Button.new()
		button.text = "Assign to %s" % _colony_display_name(colony)
		button.pressed.connect(func() -> void:
			Game.colonists.assign(colonist.id, colony.colony_id)
			refresh()
		)
		row.add_child(button)

	if not any_target:
		var label := Label.new()
		label.text = "Idle - no founded colony needs a %s colonist right now" % TYPE_LABELS[colonist.type]
		row.add_child(label)

	return row


func _build_assigned_status(colonist: Colonist) -> Control:
	var row := HBoxContainer.new()

	var colony: Colony = Game.colonies.get_colony(colonist.assigned_colony_id)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "Assigned to %s" % (_colony_display_name(colony) if colony != null else String(colonist.assigned_colony_id))
	row.add_child(label)

	var unassign_button := Button.new()
	unassign_button.text = "Unassign"
	unassign_button.pressed.connect(func() -> void:
		Game.colonists.unassign(colonist.id)
		refresh()
	)
	row.add_child(unassign_button)

	return row


func _colony_display_name(colony: Colony) -> String:
	var tier_def: ColonyDef = Db.colony(colony.tier_id)
	return tier_def.display_name if tier_def != null else String(colony.tier_id)
