## Child of Game. The shared, limited colonist pool (docs/GAME_DESIGN.md §4:
## "Every colonist is either producing raw goods or converting them" - called
## out as the central tension of the whole game).
##
## A colonist is bought once (via next_colonist_cost(), §6's cost curve) and
## then assigned to exactly one "site" - a colony (gathering) or a workshop
## (crafting, task #32). This class doesn't know or care which: it just tracks
## how many are owned in total and how many are currently assigned to each
## site id, and enforces the one rule that makes the tension real - you can
## never assign more colonists than you've actually bought.
extends Node

signal colonist_purchased(total_owned: int)

var _assignments: Dictionary = {}  # StringName (site id) -> int


func colonists_owned() -> int:
	return Game.run.colonists_owned if Game.run != null else 0


func total_assigned() -> int:
	var total: int = 0
	for count: int in _assignments.values():
		total += count
	return total


## How many colonists are bought but not currently assigned anywhere -
## the pool available to hand out.
func colonists_idle() -> int:
	return colonists_owned() - total_assigned()


func assigned_to(site_id: StringName) -> int:
	return int(_assignments.get(site_id, 0))


## Cost of the next colonist, before any prestige discount. The curve itself
## lives in Balance (§6's full formula also multiplies by a Settlement-branch
## discount from Progression - not applied here yet, since the real prestige
## system doesn't exist until a later rework; that hookup is a one-line
## change here when it does, not a reason to touch every caller).
func next_colonist_cost() -> float:
	return Balance.next_colonist_cost(colonists_owned())


func buy_colonist() -> bool:
	if Game.run == null:
		push_error("Colonists.buy_colonist: no active run")
		return false

	if not Game.economy.try_spend(next_colonist_cost()):
		return false

	Game.run.colonists_owned += 1
	colonist_purchased.emit(Game.run.colonists_owned)
	return true


## Moves `count` idle colonists onto `site_id`. Returns false and changes
## nothing if there aren't enough idle colonists to cover it - never a
## partial assignment.
func assign(site_id: StringName, count: int) -> bool:
	if count <= 0:
		push_error("Colonists.assign: count must be > 0, got %d" % count)
		return false
	if count > colonists_idle():
		return false

	_assignments[site_id] = assigned_to(site_id) + count
	return true


## Moves `count` colonists off of `site_id` back into the idle pool. Returns
## false and changes nothing if `site_id` doesn't have that many assigned.
func unassign(site_id: StringName, count: int) -> bool:
	if count <= 0:
		push_error("Colonists.unassign: count must be > 0, got %d" % count)
		return false

	var current: int = assigned_to(site_id)
	if count > current:
		return false

	var remaining: int = current - count
	if remaining <= 0:
		_assignments.erase(site_id)
	else:
		_assignments[site_id] = remaining
	return true


func clear_assignments() -> void:
	_assignments.clear()
