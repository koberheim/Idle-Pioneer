## Autoload: the running game. Owns state and the four gameplay subsystems below.
## Skeleton only (task F4) - MetaState/RunState wiring lands in tasks G1-G3.
extends Node

@onready var economy: Node = $Economy
@onready var inventory: Node = $Inventory
@onready var colonies: Node = $Colonies
@onready var progression: Node = $Progression


func _ready() -> void:
	pass
