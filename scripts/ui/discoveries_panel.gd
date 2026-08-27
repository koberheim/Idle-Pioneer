## The Discoveries tab - placeholder (direct request: a 5th tab reserved for
## a future upgrade tree, no content designed yet). Deliberately inert, same
## spirit as Balance's colonist-secondary-effect placeholder: present and
## obviously a stub, not silently missing.
extends Control


func _ready() -> void:
	var label := Label.new()
	label.text = "Discoveries - coming soon"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)


func refresh() -> void:
	pass
