## What happened during one or more simulation steps. The live game turns these
## into animations and sounds; offline catch-up turns them into a summary.
class_name SimEvents
extends RefCounted

var gold_earned: float = 0.0
## resource id -> units sold / crafted / delivered
var sold: Dictionary = {}
var crafted: Dictionary = {}
var delivered: Dictionary = {}
## Shipments unloaded at the capital, one entry per colony per batch of
## events: {colony, resource, qty, trips}. `trips` counts every voyage.
var shipments: Array[Dictionary] = []
var trips: int = 0
var _ship_index: Dictionary = {}
var discovered: Array[String] = []


func add_shipment(colony_id: String, resource_id: String, qty: float, count: int = 1) -> void:
	trips += count
	if _ship_index.has(colony_id):
		var e: Dictionary = shipments[_ship_index[colony_id]]
		e["qty"] = float(e["qty"]) + qty
		e["trips"] = int(e["trips"]) + count
		return
	_ship_index[colony_id] = shipments.size()
	shipments.append({"colony": colony_id, "resource": resource_id, "qty": qty, "trips": count})


func add(into: Dictionary, id: String, qty: float) -> void:
	into[id] = float(into.get(id, 0.0)) + qty


func is_empty() -> bool:
	return gold_earned == 0.0 and sold.is_empty() and crafted.is_empty() \
		and shipments.is_empty() and discovered.is_empty()
