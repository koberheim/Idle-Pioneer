## Child of Game. The real prestige system (docs/GAME_DESIGN.md §8 -
## "Declaring Independence"), replacing the earlier unwired "doubloons"
## placeholder. Owns Liberty (the permanent currency) and the three permanent
## upgrade branches it buys - Industry, Navigation, Settlement.
##
## Liberty and the branch levels persist in Game.meta (they must survive a
## reset - that's the entire point of prestige currency), while every actual
## number - costs, bonuses, the gate threshold, the payout formula - lives in
## Balance, same split every other subsystem in this project uses (Colony
## holds state, Balance holds formulas).
##
## declare_independence() IS the reset: it pays out Liberty based on this
## run's lifetime earnings, then calls Game.new_run() - the same structural
## reset boundary every other prestige-adjacent thing in this codebase
## already goes through. Nothing here duplicates what new_run() already
## clears.
extends Node

signal liberty_changed(total: int)
signal declared_independence(liberty_awarded: int)
signal branch_purchased(branch: StringName, new_level: int)

const BRANCH_INDUSTRY: StringName = &"industry"
const BRANCH_NAVIGATION: StringName = &"navigation"
const BRANCH_SETTLEMENT: StringName = &"settlement"


func liberty() -> int:
	return Game.meta.liberty


## What §8's gate/payout actually reads - this run's lifetime earnings, which
## only ever grows, not current on-hand gold (Game.economy.gold), which can
## be spent down to zero without affecting this.
func lifetime_gold_earned_this_run() -> float:
	return Game.run.lifetime_gold_earned_this_run if Game.run != null else 0.0


func can_declare_independence() -> bool:
	return Game.run != null and Balance.prestige_gate_met(lifetime_gold_earned_this_run())


## What declare_independence() would pay out right now - the "projected
## Liberty" figure §8's confirmation screen is supposed to show before the
## player commits. Scaled by the chosen nation's Liberty bonus, if any
## (direct request - recovered from the Unity project's NationalityData,
## see NationDef's class doc) - applied after Balance's own formula rather
## than to lifetime_gold_earned_this_run() beforehand, since it's a bonus to
## the payout itself, not a claim the run actually earned more gold.
func projected_liberty_payout() -> int:
	var base: int = Balance.prestige_liberty_payout(lifetime_gold_earned_this_run())
	return int(round(float(base) * Game.nation_liberty_generation_multiplier()))


## Pays out Liberty for this run's earnings, then wipes the run (Game.new_run()
## on the same map) - the reset itself. Returns 0 and changes nothing if the
## gate hasn't been met.
func declare_independence() -> int:
	if not can_declare_independence():
		return 0

	var awarded: int = projected_liberty_payout()
	var map_id: StringName = Game.run.map_id

	_update_stats(lifetime_gold_earned_this_run(), Time.get_unix_time_from_system() - Game.run.started_at_unix)

	Game.meta.liberty += awarded
	Game.meta.lifetime_liberty_earned += awarded
	Game.meta.runs_completed += 1

	Game.new_run(map_id)

	declared_independence.emit(awarded)
	liberty_changed.emit(Game.meta.liberty)
	return awarded


## Updates Game.meta.stats (docs/GAME_DESIGN.md §9) with this run's results,
## keeping whichever is better - never overwritten downward by a weaker run.
func _update_stats(run_gold: float, run_seconds: int) -> void:
	var stats: Dictionary = Game.meta.stats
	if run_gold > float(stats.get("best_run_gold", 0.0)):
		stats["best_run_gold"] = run_gold

	var fastest: int = int(stats.get("fastest_run_seconds", 0))
	if fastest <= 0 or (run_seconds > 0 and run_seconds < fastest):
		stats["fastest_run_seconds"] = run_seconds

	Game.meta.stats = stats


func industry_level() -> int:
	return int(Game.meta.upgrades.get(BRANCH_INDUSTRY, 0))


func navigation_level() -> int:
	return int(Game.meta.upgrades.get(BRANCH_NAVIGATION, 0))


func settlement_level() -> int:
	return int(Game.meta.upgrades.get(BRANCH_SETTLEMENT, 0))


func next_industry_cost() -> float:
	return Balance.next_industry_cost(industry_level())


func next_navigation_cost() -> float:
	return Balance.next_navigation_cost(navigation_level())


func next_settlement_cost() -> float:
	return Balance.next_settlement_cost(settlement_level())


func can_purchase_industry() -> bool:
	return industry_level() < Balance.industry_max_level() and liberty() >= next_industry_cost()


func can_purchase_navigation() -> bool:
	return navigation_level() < Balance.navigation_max_level() and liberty() >= next_navigation_cost()


func can_purchase_settlement() -> bool:
	return settlement_level() < Balance.settlement_max_level() and liberty() >= next_settlement_cost()


func purchase_industry() -> bool:
	if not can_purchase_industry():
		return false
	return _purchase(BRANCH_INDUSTRY, next_industry_cost(), industry_level())


func purchase_navigation() -> bool:
	if not can_purchase_navigation():
		return false
	return _purchase(BRANCH_NAVIGATION, next_navigation_cost(), navigation_level())


func purchase_settlement() -> bool:
	if not can_purchase_settlement():
		return false
	return _purchase(BRANCH_SETTLEMENT, next_settlement_cost(), settlement_level())


func _purchase(branch: StringName, cost: float, current_level: int) -> bool:
	var spent: int = int(round(cost))
	if liberty() < spent:
		return false
	Game.meta.liberty -= spent
	var new_level: int = current_level + 1
	Game.meta.upgrades[branch] = new_level
	branch_purchased.emit(branch, new_level)
	liberty_changed.emit(Game.meta.liberty)
	return true


## +15% production per Industry level. Combined with Progression's run-scoped
## multiplier at the call site (Colony.production_rate()) - see that
## function's comment for why they're not merged here.
func production_multiplier() -> float:
	return Balance.industry_production_multiplier(industry_level())


func speed_multiplier() -> float:
	return Balance.navigation_speed_multiplier(navigation_level())


func cargo_multiplier() -> float:
	return Balance.navigation_cargo_multiplier(navigation_level())


## Settlement's colonist/colony cost discount, already floored at Balance's
## configured maximum. 1.0 (no discount) at Settlement level 0.
func cost_discount_multiplier() -> float:
	return Balance.settlement_cost_multiplier(settlement_level())
