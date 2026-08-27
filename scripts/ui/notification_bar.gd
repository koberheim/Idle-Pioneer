## A one-line, self-clearing toast strip (docs/GAME_DESIGN.md §11 Phase 7:
## "notifications when shipments land"). Queues messages and shows one at a
## time for DISPLAY_SECONDS each, hiding entirely once the queue drains -
## deliberately not a list/log, since the rest of the interface already
## shows live state on every refresh; this is only for "something just
## happened" moments a 0.25s poll would otherwise blow past silently.
extends PanelContainer

const DISPLAY_SECONDS: float = 3.0

var _label: Label
var _queue: Array[Dictionary] = []  # {"text": String, "duration": float}
var _elapsed: float = 0.0
var _current_duration: float = DISPLAY_SECONDS


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	visible = false
	set_process(false)


## `duration` lets a rarer, more important message (e.g. the offline-progress
## summary) stay up longer than the routine shipment-landed toast.
func push(text: String, duration: float = DISPLAY_SECONDS) -> void:
	_queue.append({"text": text, "duration": duration})
	if not visible:
		_show_next()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _current_duration:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		set_process(false)
		return
	var entry: Dictionary = _queue.pop_front()
	_label.text = entry["text"]
	_current_duration = entry["duration"]
	_elapsed = 0.0
	visible = true
	set_process(true)
