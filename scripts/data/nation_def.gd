## Content definition for a playable nation (direct request: the player
## picks one of several nations at the start of a run, each with a unique
## mechanical bonus). Recovers the original Unity project's own
## `NationalityData` ScriptableObject and its 6 authored assets
## (Assets/03_Data/Nationalities/*.asset) - the same 6 multiplier fields,
## carried over as-is, since they already map cleanly onto systems this
## project already has (a per-colony production rate, land/sea route speed,
## colony founding cost, sell value, and Liberty payout).
##
## Worth noting for anyone tracing this back to the Unity source: only one
## of the six nations' bonuses (Dutch, extraction rate) was ever actually
## wired into Unity gameplay, and even that one was dead code in practice -
## ColonyProduction.cs checked `chosenNationality.nationalityName == "Dutch"`
## directly rather than reading the multiplier field generically, and
## nationalityName was left blank in every asset, so the check could never
## actually pass. The other five nations' bonuses existed only as
## unread data. This rebuild wires all six for real.
class_name NationDef
extends Resource

## Stable identifier. Must match the .tres filename (enforced by Db). Never
## reference a nation by array index or file path - only this.
@export var id: StringName = &""

@export var display_name: String = ""
@export var color: Color = Color.WHITE

## One-line flavor text for the nation-picker screen - what the bonus does,
## in plain language (e.g. "+15% production from every colony").
@export var bonus_description: String = ""

## Each multiplier defaults to 1.0 (no effect) - every real nation sets
## exactly one of these away from 1.0, matching the original data exactly,
## but nothing here enforces "only one" the way is_valid() enforces id/name;
## a future nation combining bonuses is a content choice, not a code change.
@export var ship_speed_multiplier: float = 1.0
@export var wagon_speed_multiplier: float = 1.0
@export var colony_cost_multiplier: float = 1.0
@export var gold_sell_multiplier: float = 1.0
@export var extraction_rate_multiplier: float = 1.0
@export var liberty_generation_multiplier: float = 1.0


func is_valid() -> bool:
	if id == &"" or display_name == "":
		return false
	for value: float in [
		ship_speed_multiplier, wagon_speed_multiplier, colony_cost_multiplier,
		gold_sell_multiplier, extraction_rate_multiplier, liberty_generation_multiplier,
	]:
		if value <= 0.0:
			return false
	return true
