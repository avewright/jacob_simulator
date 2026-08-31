extends Node3D

const RANGE := 2.6
const UI := preload("res://scenes/office/sales_ui.tscn")

var _open_ui: CanvasLayer


func in_range(who: Node3D) -> bool:
	if who == null or _open_ui != null:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func open() -> void:
	if _open_ui != null:
		return
	_open_ui = UI.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(_open_ui)
	_open_ui.tree_exited.connect(func() -> void: _open_ui = null)
