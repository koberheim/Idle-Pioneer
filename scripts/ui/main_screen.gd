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

var _refresh_elapsed: float = 0.0
var _auto_save_elapsed: float = 0.0


func _ready() -> void:
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

	refresh_all()


func _select_tab(page: Control) -> void:
	for p: Control in [_colonies_panel, _market_panel, _crafting_panel, _prestige_panel]:
		p.visible = p == page


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
	_gold_label.text = "Gold: %.0f" % Game.economy.gold
	_liberty_label.text = "Liberty: %d" % Game.prestige.liberty()
	_colonies_panel.refresh()
	_market_panel.refresh()
	_crafting_panel.refresh()
	_prestige_panel.refresh()
