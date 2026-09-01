extends Node3D

const RANGE := 2.6
const UI := preload("res://scenes/office/elevator_ui.tscn")

var tower: Node3D
var index: int = 0

var _open_ui: CanvasLayer


func setup(owner_tower: Node3D, floor_index: int) -> void:
	tower = owner_tower
	index = floor_index
	_build()


func in_range(who: Node3D) -> bool:
	if who == null or _open_ui != null:
		return false
	# Same shaft on every floor, so height has to count here.
	if absf(who.global_position.y - global_position.y) > 2.5:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func open() -> void:
	if _open_ui != null:
		return
	_open_ui = UI.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(_open_ui)
	_open_ui.setup(tower, index)
	_open_ui.tree_exited.connect(func() -> void: _open_ui = null)


func _build() -> void:
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.34, 0.24)
	plate.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("1b2028")
	m.emission_enabled = true
	m.emission = Color("ffb703")
	m.emission_energy_multiplier = 0.8
	plate.material_override = m
	plate.position = Vector3(0, 1.25, 0)
	add_child(plate)
