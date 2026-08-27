## Root of the real game screen (rework task: UI) - the first screen that
## actually boots the game rather than exercising it through tests. Loads an
## existing save if one exists, otherwise starts a fresh run; starts the
## live simulation clock; and periodically refreshes every tab so numbers
## that change every frame (production, shipping, crafting) stay current
## without needing a signal wired for each one individually.
##
## Only one map exists (mvp_coast, task F1) - there's no map-select screen
## to route through yet, so a fresh run always starts there.
##
## Layout, direct request: the map fills the entire screen behind
## everything else; the 5 tabs (Colonies/Market/Crafting/Colonists/
## Discoveries) collapse to a plain strip pinned to the bottom edge; tapping
## one slides a content sheet up to cover ~45% of the screen (tapping the
## same tab again slides it back down). MapArea/TopBar/NotificationBar all
## stay full-width and manage their own vertical slot via anchors - only
## SheetPanel and TabBarPanel need pixel-precise manual positioning, since
## their height (SheetPanel) and vertical offset (both) change at runtime as
## the sheet opens and closes.
##
## Prestige and Save moved out of the tab strip entirely, direct request -
## into a small popup opened from a Menu button in the top-right corner
## (MenuPopup), the way a typical app's overflow menu works. Prestige keeps
## its own panel script/content unchanged; only where it lives moved.
extends Control

const MAP_ID: StringName = &"mvp_coast"
const REFRESH_INTERVAL_SECONDS: float = 0.25
const AUTO_SAVE_INTERVAL_SECONDS: float = 30.0

const TAB_BAR_HEIGHT: float = 56.0
const SHEET_HEIGHT_RATIO: float = 0.45
const SLIDE_SECONDS: float = 0.25

@onready var _gold_label: Label = %GoldLabel
@onready var _liberty_label: Label = %LibertyLabel
@onready var _map_view: MapView = %MapArea
@onready var _colonies_panel: Control = %Colonies
@onready var _market_panel: Control = %Market
@onready var _crafting_panel: Control = %Crafting
@onready var _colonists_panel: Control = %Colonists
@onready var _discoveries_panel: Control = %Discoveries
@onready var _prestige_panel: Control = %Prestige
@onready var _save_button: Button = %SaveButton
@onready var _notification_bar: PanelContainer = %NotificationBar
@onready var _menu_button: Button = %MenuButton
@onready var _menu_popup: PanelContainer = %MenuPopup

## TabContainer's stock tab bar left-aligns tabs to their content width
## instead of spreading them evenly - these are plain SIZE_EXPAND_FILL
## buttons in a ButtonGroup (allow_unpress = true, so tapping the open tab
## again deselects it) driving the sliding sheet below instead.
@onready var _colonies_tab_button: Button = %ColoniesTabButton
@onready var _market_tab_button: Button = %MarketTabButton
@onready var _crafting_tab_button: Button = %CraftingTabButton
@onready var _colonists_tab_button: Button = %ColonistsTabButton
@onready var _discoveries_tab_button: Button = %DiscoveriesTabButton
@onready var _sheet_panel: PanelContainer = %SheetPanel
@onready var _tab_bar_panel: PanelContainer = %TabBarPanel

var _refresh_elapsed: float = 0.0
var _auto_save_elapsed: float = 0.0

var _sheet_height: float = 0.0  # current animated height; 0 = fully closed
var _sheet_tween: Tween
var _active_page: Control = null


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
	_menu_button.pressed.connect(func() -> void: _menu_popup.visible = not _menu_popup.visible)

	_colonies_tab_button.toggled.connect(func(pressed: bool) -> void: _on_tab_toggled(pressed, _colonies_panel))
	_market_tab_button.toggled.connect(func(pressed: bool) -> void: _on_tab_toggled(pressed, _market_panel))
	_crafting_tab_button.toggled.connect(func(pressed: bool) -> void: _on_tab_toggled(pressed, _crafting_panel))
	_colonists_tab_button.toggled.connect(func(pressed: bool) -> void: _on_tab_toggled(pressed, _colonists_panel))
	_discoveries_tab_button.toggled.connect(func(pressed: bool) -> void: _on_tab_toggled(pressed, _discoveries_panel))

	_map_view.slot_selected.connect(_on_map_slot_selected)

	Game.routes.shipment_delivered.connect(_on_shipment_delivered)
	Game.prestige.declared_independence.connect(_on_declared_independence)

	_layout_sheet()
	refresh_all()


## Starts closed (map fills the whole screen, nothing selected) - opening a
## tab is always a deliberate tap, never the default state.
func _on_tab_toggled(pressed: bool, page: Control) -> void:
	if pressed:
		_active_page = page
		for p: Control in [_colonies_panel, _market_panel, _crafting_panel, _colonists_panel, _discoveries_panel]:
			p.visible = p == page
		_animate_sheet_to(_target_sheet_height())
	else:
		_active_page = null
		_animate_sheet_to(0.0)


## Tapping a colony marker on the map opens the Colonies tab (the one place
## a colony's live stats and controls actually live) and scrolls straight
## to that colony's row, so the tap actually lands on something instead of
## just landing "somewhere in the list."
func _on_map_slot_selected(slot_index: int) -> void:
	if not _colonies_tab_button.button_pressed:
		_colonies_tab_button.button_pressed = true
	_colonies_panel.scroll_to_slot(slot_index)


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


func _target_sheet_height() -> float:
	return get_viewport_rect().size.y * SHEET_HEIGHT_RATIO


func _animate_sheet_to(target: float) -> void:
	if _sheet_tween != null:
		_sheet_tween.kill()
	_sheet_tween = create_tween()
	_sheet_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_sheet_tween.tween_method(_set_sheet_height, _sheet_height, target, SLIDE_SECONDS)


func _set_sheet_height(height: float) -> void:
	_sheet_height = height
	_layout_sheet()


## TabBarPanel stays pinned to the screen's bottom edge always; SheetPanel
## sits directly above it and grows upward from that fixed line as
## _sheet_height animates toward its target - the "slides up from behind
## the tab strip" effect, without moving the tab strip itself.
func _layout_sheet() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_tab_bar_panel.position = Vector2(0.0, viewport_size.y - TAB_BAR_HEIGHT)
	_tab_bar_panel.size = Vector2(viewport_size.x, TAB_BAR_HEIGHT)
	_sheet_panel.position = Vector2(0.0, viewport_size.y - TAB_BAR_HEIGHT - _sheet_height)
	_sheet_panel.size = Vector2(viewport_size.x, _sheet_height)


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
	_map_view.refresh()
	_colonies_panel.refresh()
	_market_panel.refresh()
	_crafting_panel.refresh()
	_colonists_panel.refresh()
	_discoveries_panel.refresh()
	_prestige_panel.refresh()
