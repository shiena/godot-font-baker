@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/font_baker/font_baker_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
