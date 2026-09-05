extends Node3D

# Whole Foods, across the road from 10000 Avalon. A proper big-box store you
# walk into: sliding entrance, aisles, chillers, a checkout run.
#
# Local space: origin at the centre of the slab on the ground. The car park and
# the entrance are toward +X (the road side).

const W := 44.0
const D := 30.0
const H := 8.0
const T := 0.5
const DOOR_W := 5.0
const DOOR_H := 3.2
const OPEN_RANGE := 6.0

const SODA_PRICE := 3
const CANDY_PRICE := 2

var _leaves: Array[AnimatableBody3D] = []
var _open: float = 0.0

var _brick: StandardMaterial3D
var _panel: StandardMaterial3D
var _floor_m: StandardMaterial3D
var _shelf: StandardMaterial3D
var _chill: StandardMaterial3D
var _glass: StandardMaterial3D
var _green: StandardMaterial3D


func _ready() -> void:
	add_to_group("whole_foods")
	_make_mats()
	_shell()
	_entrance()
	_interior()
	_car_park()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var want := 0.0
	if player and not GameState.in_car:
		var door := to_global(Vector3(W * 0.5, 0, 0))
		var flat := Vector2(door.x - player.global_position.x, door.z - player.global_position.z)
		want = 1.0 if flat.length() < OPEN_RANGE else 0.0
	_open = move_toward(_open, want, 3.6 * delta)
	var shift := _open * (DOOR_W * 0.5 + 0.05)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		_leaves[i].position.z = side * (DOOR_W * 0.25 + shift)


func _make_mats() -> void:
	_brick = _mat(Color("6f4a3a"), 0.9)
	_panel = _mat(Color("e6e2d8"), 0.8)
	_floor_m = _mat(Color("d6d2c8"), 0.55)
	_shelf = _mat(Color("8a7f70"), 0.75)
	_chill = _mat(Color("cfd8dc"), 0.35, 0.35)
	_green = _mat(Color("00674b"), 0.6)
	_glass = _mat(Color(0.55, 0.72, 0.82, 0.4), 0.06, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _shell() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	_box(Vector3(0, 0.01, 0), Vector3(W, 0.02, D), _floor_m, false)

	_box(Vector3(-hx, H * 0.5, 0), Vector3(T, H, D), _brick, true)
	_box(Vector3(0, H * 0.5, -hz), Vector3(W, H, T), _brick, true)
	_box(Vector3(0, H * 0.5, hz), Vector3(W, H, T), _brick, true)
	# Front elevation: glazing either side of the sliding doors.
	var gap := DOOR_W * 0.5
	var seg := hz - gap
	_box(Vector3(hx, H * 0.5, -(gap + hz) * 0.5), Vector3(T, H, seg), _brick, true)
	_box(Vector3(hx, H * 0.5, (gap + hz) * 0.5), Vector3(T, H, seg), _brick, true)
	_box(Vector3(hx, (DOOR_H + H) * 0.5, 0), Vector3(T, H - DOOR_H, DOOR_W + 0.3), _brick, true)
	for dir in [-1.0, 1.0]:
		_box(Vector3(hx + 0.1, 2.2, dir * 8.0), Vector3(0.2, 3.6, 8.0), _glass, false)

	_box(Vector3(0, H + 0.3, 0), Vector3(W + 1.0, 0.6, D + 1.0), _panel, true)
	# Parapet band and entrance canopy.
	_box(Vector3(0, H + 1.1, hz + 0.2), Vector3(W + 1.0, 1.0, 0.5), _green, false)
	_box(Vector3(hx + 0.3, H + 1.1, 0), Vector3(0.5, 1.0, D + 1.0), _green, false)
	_box(Vector3(hx + 2.0, DOOR_H + 0.6, 0), Vector3(4.4, 0.3, DOOR_W + 6.0), _green, false)
	for cz in [-4.6, 4.6]:
		_box(Vector3(hx + 3.8, DOOR_H * 0.5, cz), Vector3(0.28, DOOR_H + 0.6, 0.28), _panel, true)

	_label("WHOLE FOODS", Vector3(hx + 0.6, H + 1.1, 0), 96, Color("f1faee"), -90.0)
	_label("M A R K E T", Vector3(hx + 0.6, H + 0.2, 0), 44, Color("bfe3d0"), -90.0)


func _entrance() -> void:
	# Threshold ramp — the slab is painted flush, so this only smooths the sill.
	for i in 2:
		var leaf := AnimatableBody3D.new()
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position = Vector3(W * 0.5, 0.0, 0.0)
		var size := Vector3(0.14, DOOR_H - 0.2, DOOR_W * 0.5)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position.y = size.y * 0.5
		leaf.add_child(col)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
		mi.material_override = _glass
		mi.position.y = size.y * 0.5
		leaf.add_child(mi)
		add_child(leaf)
		_leaves.append(leaf)


func _interior() -> void:
	# Aisles running across the store, with a clear run in from the doors.
	for a in 4:
		var x := 10.0 - a * 8.0
		for dz in [-1.0, 1.0]:
			_box(Vector3(x, 1.0, dz * 6.5), Vector3(1.4, 2.0, 9.0), _shelf, true)
			for lvl in 3:
				_box(Vector3(x, 0.5 + lvl * 0.62, dz * 6.5), Vector3(1.55, 0.08, 9.1), _panel, false)

	# Chiller run along the back wall.
	for i in 6:
		var z := -12.0 + i * 4.6
		_box(Vector3(-20.0, 1.2, z), Vector3(1.6, 2.4, 4.2), _chill, true)
		_box(Vector3(-19.1, 1.3, z), Vector3(0.1, 1.8, 3.6), _glass, false)

	# Produce tables near the doors.
	for pz in [-9.0, 9.0]:
		_box(Vector3(17.0, 0.45, pz), Vector3(3.0, 0.9, 4.0), _shelf, true)
		_box(Vector3(17.0, 0.94, pz), Vector3(3.2, 0.08, 4.2), _green, false)

	# Checkout run.
	for i in 3:
		var z := -4.0 + i * 4.0
		_box(Vector3(19.5, 0.5, z), Vector3(1.2, 1.0, 2.6), _panel, true)
		_box(Vector3(19.5, 1.04, z), Vector3(1.4, 0.08, 2.8), _mat(Color("2f3338"), 0.4), false)

	for i in 6:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-16.0 + i * 7.0, H - 1.4, 0)
		lamp.light_color = Color("fff6e2")
		lamp.light_energy = 2.4
		lamp.omni_range = 22.0
		lamp.shadow_enabled = false
		add_child(lamp)

	# The two counters you can actually buy from.
	_counter(Vector3(6.0, 0, 11.0), "soda", "SODAS", Color("c62828"))
	_counter(Vector3(-2.0, 0, 11.0), "candy", "CANDY", Color("f9a825"))
	# Apparel rail, so the opening objective still has somewhere to happen.
	_counter(Vector3(-14.0, 0, 11.0), "clothes", "APPAREL", Color("1d3557"))


func _counter(at: Vector3, kind: String, label: String, tint: Color) -> void:
	_box(at + Vector3(0, 0.5, 0), Vector3(4.4, 1.0, 1.2), _shelf, true)
	_box(at + Vector3(0, 1.05, 0), Vector3(4.6, 0.1, 1.4), _mat(tint, 0.5), false)
	for i in 3:
		_box(at + Vector3(-1.4 + i * 1.4, 1.28, 0), Vector3(0.5, 0.36, 0.5), _mat(tint, 0.55), false)

	var stand := Node3D.new()
	stand.name = "Counter_" + kind
	stand.position = at + Vector3(0, 0, 1.6)
	stand.add_to_group("store_counter")
	stand.set_script(load("res://scripts/store_counter.gd"))
	add_child(stand)
	stand.setup(kind)

	_label(label, at + Vector3(0, 2.4, 0), 40, tint.lightened(0.35), 0.0)


func _car_park() -> void:
	var tarmac := _mat(Color("4c4f53"), 0.94)
	var paint := _mat(Color("e8e8e0"), 0.7)
	_box(Vector3(W * 0.5 + 21.0, 0.008, 0), Vector3(42.0, 0.016, D + 8.0), tarmac, false)
	for row in 2:
		for stall in 9:
			var z := -16.0 + stall * 4.0
			var x := W * 0.5 + 8.0 + row * 13.0
			_box(Vector3(x, 0.02, z), Vector3(5.0, 0.02, 0.12), paint, false)
	for cz in [-13.0, 13.0]:
		_box(Vector3(W * 0.5 + 22.0, 3.0, cz), Vector3(0.22, 6.0, 0.22), _mat(Color("2a2a2a"), 0.4, 0.3), true)


func _label(text: String, at: Vector3, size: int, tint: Color, yaw: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.font_size = size
	l.modulate = tint
	l.outline_modulate = Color.BLACK
	l.outline_size = 8
	if yaw == 0.0:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		l.rotation_degrees.y = yaw
	add_child(l)


func _box(centre: Vector3, size: Vector3, material: Material, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = centre
	add_child(mi)
	if not solid:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
