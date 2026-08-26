## Child of Game. Owns the roster of individually-owned, typed colonists
## (rework: typed colonist roster - replaces the earlier flat, anonymous
## pool, a headcount plus a site-id-keyed assignment dict).
##
## Each colonist is recruited as one of three types (Colonist.Type.RESOURCE/
## CARGO/SPEED, matching a colony's own three tracks - docs/GAME_DESIGN.md
## §4's "central tension," now with real shape to it) and can be assigned to
## at most one colony at a time, specifically to that colony's slot for its
## own type - never two Resource colonists at one colony. Colony reads
## colonist_at(colony_id, type) to find its own assigned colonist (or null,
## which correctly means "unstaffed, base rate only" - see Balance's
## colonist_primary_multiplier doc) for each of its three formulas.
##
## The roster lives directly on Game.run.colonist_roster (plain dicts, via
## Colonist.to_dict()/from_dict()) - this class is the only thing that reads
## or writes it, and there is deliberately no separate live-object cache to
## remember to clear on new_run() the way Colonies/Routes/CraftingStations
## need: swapping Game.run wholesale already resets the roster to empty,
## for free.
extends Node

signal colonist_recruited(colonist: Colonist)
signal colonist_upgraded(colonist: Colonist)
signal influence_changed(total: float)


func _roster_dicts() -> Array[Dictionary]:
	return Game.run.colonist_roster if Game.run != null else []


func all() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for d: Dictionary in _roster_dicts():
		out.append(Colonist.from_dict(d))
	return out


func colonists_owned() -> int:
	return _roster_dicts().size()


func get_colonist(colonist_id: StringName) -> Colonist:
	for d: Dictionary in _roster_dicts():
		if StringName(d.get("id", "")) == colonist_id:
			return Colonist.from_dict(d)
	return null


func idle_colonists() -> Array[Colonist]:
	var out: Array[Colonist] = []
	for c: Colonist in all():
		if c.assigned_colony_id == &"":
			out.append(c)
	return out


## The colonist (if any) assigned to `colony_id` whose type matches - what
## Colony reads for each of its three formulas. Null (not an error - a
## colony is allowed to have an empty slot) if no match.
func colonist_at(colony_id: StringName, type: Colonist.Type) -> Colonist:
	for c: Colonist in all():
		if c.assigned_colony_id == colony_id and c.type == type:
			return c
	return null


func influence() -> float:
	return Game.run.influence if Game.run != null else 0.0


## PLACEHOLDER earning hook - see BalanceDef.influence_earn_rate_per_gold's
## doc comment. Called from Economy.add_gold().
func earn_influence_from_gold(gold_amount: float) -> void:
	if Game.run == null:
		return
	Game.run.influence += gold_amount * Balance.influence_earn_rate_per_gold()
	influence_changed.emit(Game.run.influence)


func next_recruit_cost() -> float:
	return Balance.next_colonist_recruit_cost(colonists_owned(), Game.prestige.cost_discount_multiplier())


## Spends Influence and adds a new, idle, level-1 colonist of `type` to the
## roster. Returns null (and changes nothing) on insufficient Influence.
func recruit(type: Colonist.Type) -> Colonist:
	if Game.run == null:
		push_error("Colonists.recruit: no active run")
		return null

	var cost: float = next_recruit_cost()
	if Game.run.influence < cost:
		return null
	Game.run.influence -= cost

	var colonist := Colonist.new()
	colonist.id = StringName("colonist_%d" % Game.run.next_colonist_id)
	Game.run.next_colonist_id += 1
	colonist.type = type
	colonist.level = 1
	colonist.assigned_colony_id = &""

	Game.run.colonist_roster.append(colonist.to_dict())
	colonist_recruited.emit(colonist)
	return colonist


func next_upgrade_cost(colonist_id: StringName) -> float:
	var c: Colonist = get_colonist(colonist_id)
	if c == null:
		return 0.0
	return Balance.next_colonist_upgrade_cost(c.level, Game.prestige.cost_discount_multiplier())


## Spends Influence and raises `colonist_id` by one level. Returns false
## (and changes nothing) if the colonist doesn't exist or Influence is short.
func upgrade(colonist_id: StringName) -> bool:
	var c: Colonist = get_colonist(colonist_id)
	if c == null:
		return false

	var cost: float = Balance.next_colonist_upgrade_cost(c.level, Game.prestige.cost_discount_multiplier())
	if Game.run.influence < cost:
		return false
	Game.run.influence -= cost

	c.level += 1
	_write_back(c)
	colonist_upgraded.emit(c)
	return true


## Assigns `colonist_id` to `colony_id`'s slot for its own type. Returns
## false and changes nothing if the colonist doesn't exist, is already
## assigned somewhere, or that colony's slot for this type is already
## occupied by a different colonist.
func assign(colonist_id: StringName, colony_id: StringName) -> bool:
	var c: Colonist = get_colonist(colonist_id)
	if c == null or c.assigned_colony_id != &"":
		return false
	if colonist_at(colony_id, c.type) != null:
		return false

	c.assigned_colony_id = colony_id
	_write_back(c)
	return true


func unassign(colonist_id: StringName) -> bool:
	var c: Colonist = get_colonist(colonist_id)
	if c == null or c.assigned_colony_id == &"":
		return false

	c.assigned_colony_id = &""
	_write_back(c)
	return true


## Convenience for the UI's "assign" button on an empty slot: hands
## `colony_id` its highest-level idle colonist of `type`, if any exists.
## Returns false (nothing changed) if no matching idle colonist exists or
## the slot is already filled.
func assign_best(colony_id: StringName, type: Colonist.Type) -> bool:
	var best: Colonist = null
	for c: Colonist in idle_colonists():
		if c.type == type and (best == null or c.level > best.level):
			best = c
	if best == null:
		return false
	return assign(best.id, colony_id)


func _write_back(colonist: Colonist) -> void:
	var roster: Array[Dictionary] = Game.run.colonist_roster
	for i: int in range(roster.size()):
		if StringName(roster[i].get("id", "")) == colonist.id:
			roster[i] = colonist.to_dict()
			return
