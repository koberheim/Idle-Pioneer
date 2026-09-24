## What happened during one or more simulation steps. The live game turns these
## into animations and sounds; offline catch-up turns them into a summary.
class_name SimEvents
extends RefCounted

var gold_earned: float = 0.0
## resource id -> units sold / crafted / delivered
var sold: Dictionary = {}
var crafted: Dictionary = {}
var delivered: Dictionary = {}
## One entry per shipment unloaded at the capital: {colony, resource, qty}
var shipments: Array[Dictionary] = []
var discovered: Array[String] = []


func add(into: Dictionary, id: String, qty: float) -> void:
	into[id] = float(into.get(id, 0.0)) + qty


func is_empty() -> bool:
	return gold_earned == 0.0 and sold.is_empty() and crafted.is_empty() \
		and shipments.is_empty() and discovered.is_empty()
