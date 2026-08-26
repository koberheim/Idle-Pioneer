## One individually-owned colonist (rework: typed colonist roster). Plain
## data with no behaviour of its own - `Colonists` (the Game child) owns
## every rule about recruiting, upgrading, and assigning these; this class
## just holds the state, same split as every other runtime-state class in
## this project (e.g. `Colony` holds levels, `Balance` holds the formulas
## that use them).
##
## Replaces the earlier flat, anonymous colonist pool (a count + a
## site-id-keyed assignment dict) with individual, addressable colonists -
## each has its own type (fixed for its lifetime), its own level (raised by
## upgrading, at its own cost), and is assigned to at most one colony at a
## time, in the slot matching its type.
class_name Colonist
extends RefCounted

## Which of a colony's three tracks this colonist boosts. Matches Colony's
## own three upgrade tracks (production_level/cargo_level/speed_level) and
## Colonies.gd's per-slot exclusivity rule: a colony can never hold two
## colonists of the same type at once.
enum Type { RESOURCE, CARGO, SPEED }

## Stable per-run id (RunState.next_colonist_id hands these out) - what
## Colonists' roster is keyed by, and what save data references.
var id: StringName = &""

var type: Type = Type.RESOURCE

## Starts at 1 - a freshly recruited colonist is already useful, not inert
## until its first upgrade. Raised by Colonists.upgrade(), at a cost that
## scales with this specific colonist's own level.
var level: int = 1

## Empty StringName means idle (bought, not yet assigned anywhere).
var assigned_colony_id: StringName = &""


static func type_from_string(name: String) -> Type:
	match name:
		"cargo":
			return Type.CARGO
		"speed":
			return Type.SPEED
		_:
			return Type.RESOURCE


static func type_to_string(t: Type) -> String:
	match t:
		Type.CARGO:
			return "cargo"
		Type.SPEED:
			return "speed"
		_:
			return "resource"


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"type": type_to_string(type),
		"level": level,
		"assigned_colony_id": String(assigned_colony_id),
	}


static func from_dict(d: Dictionary) -> Colonist:
	var c := Colonist.new()
	c.id = StringName(d.get("id", ""))
	c.type = type_from_string(String(d.get("type", "resource")))
	c.level = int(d.get("level", 1))
	c.assigned_colony_id = StringName(d.get("assigned_colony_id", ""))
	return c
