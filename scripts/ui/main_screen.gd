## Root of the real game screen (rework task: UI) - the first screen that
## actually boots the game rather than exercising it through tests. Loads an
## existing save if one exists, otherwise starts a fresh run; starts the
## live simulation clock; and periodically refreshes every tab so numbers
## that change every frame (production, shipping, crafting) stay current
## without needing a signal wired for each one individually.
##
## Only one map exists (mvp_coast, task F1) - there's no map-select screen
## to route through yet, so a fresh run always starts there.
extends Control

const MAP_ID: StringName = &"mvp_coast"
const REFRESH_INTERVAL_SECONDS: float = 0.25
const AUTO_SAVE_INTERVAL_SECONDS: float = 30.0

@onready var _gold_label: Label = %GoldLabel
@onready var _liberty_label: Label = %LibertyLabel
@onready var _colonies_panel: Control = %Colonies
@onready var _market_panel: Control = %Market
@onready var _crafting_panel: Control = %Crafting
@onready var _prestige_panel: Control = %Prestige
@onready var _save_button: Button = %SaveButton

## TabContainer's stock tab bar left-aligns tabs to their content width
## instead of spreading them evenly - these are plain SIZE_EXPAND_FILL
## buttons in a ButtonGroup driving manual page visibility instead.
@onready var _colonies_tab_button: Button = %ColoniesTabButton
@onready var _market_tab_button: Button = %MarketTabButton
@onready var _crafting_tab_button: Button = %CraftingTabButton
@onready var _prestige_tab_button: Button = %PrestigeTabButton
@onready var _notification_bar: PanelContainer = %NotificationBar

var _refresh_elapsed: float = 0.0
var _auto_save_elapsed: float = 0.0


func _ready() -> void:
	# Connected before load() rather than after - offline_progress_applied
	# fires synchronously from inside load() itself, so connecting any later
	# would miss it entirely.
	SaveSystem.offline_progress_applied.connect(_on_offline_progress_applied)

	if SaveSystem.has_save():
		SaveSystem.load()
	else:
		Game.new_run(MAP_ID)

	Game.simulation.start()
	_save_button.pressed.connect(SaveSystem.save)

	_colonies_tab_button.pressed.connect(func() -> void: _select_tab(_colonies_panel))
	_market_tab_button.pressed.connect(func() -> void: _select_tab(_market_panel))
	_crafting_tab_button.pressed.connect(func() -> void: _select_tab(_crafting_panel))
	_prestige_tab_button.pressed.connect(func() -> void: _select_tab(_prestige_panel))

	Game.routes.shipment_delivered.connect(_on_shipment_delivered)
	Game.prestige.declared_independence.connect(_on_declared_independence)

	refresh_all()


func _select_tab(page: Control) -> void:
	for p: Control in [_colonies_panel, _market_panel, _crafting_panel, _prestige_panel]:
		p.visible = p == page


func _on_shipment_delivered(colony: Colony, cargo: Dictionary) -> void:
	var tier_def: ColonyDef = Db.colony(colony.tier_id)
	var colony_name: String = tier_def.display_name if tier_def != null else String(colony.tier_id)
	_notification_bar.push("%s delivered: %s" % [colony_name, _cargo_summary(cargo)])


## docs/GAME_DESIGN.md §11 Phase 7: "offline summary." Only shown when time
## away actually produced gold - a save reloaded seconds after being written
## (the common case, opening a fresh editor run right after saving) has
## nothing worth announcing.
func _on_offline_progress_applied(elapsed_seconds: float, gold_earned: float) -> void:
	if gold_earned <= 0.0:
		return
	_notification_bar.push(
		"Welcome back! Earned %s gold while away (%s)" % [Format.number(gold_earned), _format_duration(elapsed_seconds)],
		6.0
	)


func _format_duration(seconds: float) -> String:
	var total: int = int(seconds)
	var hours: int = total / 3600
	var minutes: int = (total % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm" % minutes
	return "%ds" % total


## docs/GAME_DESIGN.md §11 Phase 7: "a real Independence sequence" - the
## moment the run actually resets deserves more than silently swapping
## numbers, even without a dedicated cutscene screen.
func _on_declared_independence(liberty_awarded: int) -> void:
	_notification_bar.push(
		"Independence declared! Earned %s Liberty. A new frontier awaits." % Format.number(liberty_awarded),
		6.0
	)


func _cargo_summary(cargo: Dictionary) -> String:
	var parts: Array[String] = []
	for id: StringName in cargo.keys():
		var def: ResourceDef = Db.resource(id)
		var name: String = def.display_name if def != null else String(id)
		parts.append("%s %s" % [Format.number(float(cargo[id]), 1), name])
	return ", ".join(parts)


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL_SECONDS:
		_refresh_elapsed = 0.0
		refresh_all()

	_auto_save_elapsed += delta
	if _auto_save_elapsed >= AUTO_SAVE_INTERVAL_SECONDS:
		_auto_save_elapsed = 0.0
		SaveSystem.save()


func _notification(what: int) -> void:
	# Save on close so quitting never loses progress - the one action a
	# player takes that a 0.25s refresh timer can't be relied on to precede.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.save()
		get_tree().quit()


func refresh_all() -> void:
	_gold_label.text = "Gold: %s" % Format.number(Game.economy.gold)
	_liberty_label.text = "Liberty: %s" % Format.number(Game.prestige.liberty())
	_colonies_panel.refresh()
	_market_panel.refresh()
	_crafting_panel.refresh()
	_prestige_panel.refresh()
