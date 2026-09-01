extends Node3D

# 5955 Haterleigh Dr. Two-storey traditional off the reference photo, and
# hollow: walk in the front door, or drive the Camry into the garage.
#
# Local space: origin at the centre of the plot on the ground, front facing -Z
# (the street). Interior is built from wall segments rather than solid blocks
# so the rooms are actually enterable.

const H2 := 6.4          # eave line / second-floor plate
const RIDGE := 8.7
const T := 0.28          # interior wall thickness
const UP_Y := 3.3        # first-floor ceiling / second-floor level
const DOOR_W := 1.4
const DOOR_H := 2.3
const GARAGE_W := 7.2
const GARAGE_H := 2.6
const NEAR := 5.0

var _siding: StandardMaterial3D
var _brick: StandardMaterial3D
var _trim: StandardMaterial3D
var _roof: StandardMaterial3D
var _glass: StandardMaterial3D
var _shutter: StandardMaterial3D
var _door_mat: StandardMaterial3D
var _drive: StandardMaterial3D
var _shrub: StandardMaterial3D
var _floor: StandardMaterial3D
var _wall_in: StandardMaterial3D

var _front_door: AnimatableBody3D
var _garage_door: AnimatableBody3D
var _front_open: float = 0.0
var _garage_open: float = 0.0


func _ready() -> void:
	add_to_group("haterleigh_house")
	_make_mats()
	_build_envelope()
	_build_roofs()
	_build_doors()
	_build_ground_floor()
	_build_upstairs()
	_build_facade_detail()
	_build_grounds()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var car := get_tree().get_first_node_in_group("camry") as Node3D

	# Front door: opens for Jacob on foot.
	var want_front := 0.0
	if player and not GameState.in_car and _flat(player, Vector3(1.0, 0, -5.2)) < NEAR:
		want_front = 1.0
	_front_open = move_toward(_front_open, want_front, 3.0 * delta)
	if _front_door:
		# Slides sideways into the wall, not backwards through it.
		_front_door.position.x = 0.9 - _front_open * (DOOR_W - 0.05)

	# Garage door: opens for the car, and for Jacob on foot.
	var want_garage := 0.0
	var probe := Vector3(7.0, 0, -3.0)
	if car and GameState.in_car and _flat(car, probe) < 11.0:
		want_garage = 1.0
	elif player and not GameState.in_car and _flat(player, probe) < 6.0:
		want_garage = 1.0
	_garage_open = move_toward(_garage_open, want_garage, 2.2 * delta)
	if _garage_door:
		_garage_door.position.y = GARAGE_H * 0.5 + _garage_open * (GARAGE_H - 0.15)


func _flat(who: Node3D, local_point: Vector3) -> float:
	var p := to_global(local_point)
	return Vector2(p.x - who.global_position.x, p.z - who.global_position.z).length()


func _make_mats() -> void:
	_siding = _mat(Color("c2b393"), 0.85)
	_brick = _mat(Color("9c5f45"), 0.9)
	_trim = _mat(Color("f2efe6"), 0.6)
	_roof = _mat(Color("4a4640"), 0.95)
	_shutter = _mat(Color("2b2f33"), 0.7)
	_door_mat = _mat(Color("39312c"), 0.5)
	_drive = _mat(Color("b9b7ad"), 0.92)
	_shrub = _mat(Color("2f5f31"), 0.95)
	_floor = _mat(Color("8a6b4a"), 0.7)
	_wall_in = _mat(Color("ece5d8"), 0.85)
	_glass = _mat(Color(0.55, 0.72, 0.84, 0.55), 0.08, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


# ------------------------------------------------------------------ envelope

func _build_envelope() -> void:
	# Main block: x -9..3, z -5..5. Garage wing: x 3..11, z -3..5.
	# Floors are painted on, not raised: a slab even 0.06 proud is a vertical
	# lip at the doorway, and neither Jacob nor the Camry can climb one.
	_box(Vector3(-3.0, 0.01, 0.0), Vector3(12.0, 0.02, 10.0), _floor, false)
	_box(Vector3(7.0, 0.01, 1.0), Vector3(8.0, 0.02, 8.0), _mat(Color("b3b1a8"), 0.9), false)

	# Second floor, built around the stair opening at x 0.3..3, z -0.9..4.8.
	_box(Vector3(-4.35, UP_Y - 0.1, 0.0), Vector3(9.3, 0.2, 10.0), _floor, true)
	_box(Vector3(1.65, UP_Y - 0.1, -2.95), Vector3(2.7, 0.2, 4.1), _floor, true)
	# Railing along the open side of the stair well.
	_box(Vector3(0.3, UP_Y + 0.5, 1.95), Vector3(0.1, 1.0, 5.7), _mat(Color("5b4432"), 0.6), true)
	# Ceiling over the whole thing.
	_box(Vector3(-3.0, H2 - 0.1, 0.0), Vector3(12.0, 0.2, 10.0), _wall_in, true)
	_box(Vector3(7.0, 4.5, 1.0), Vector3(8.0, 0.2, 8.0), _wall_in, true)

	# Main block exterior walls, with the front door gap in the -Z wall.
	_wall_x(-9.0, -5.0, 5.0, 0.0, H2)          # west
	_wall_x(3.0, -5.0, -3.0, 0.0, H2)          # east, north of the garage
	_wall_z(5.0, -9.0, 3.0, 0.0, H2)           # back
	# Front wall in two pieces either side of the door.
	_wall_z(-5.0, -9.0, 0.2, 0.0, H2)
	_wall_z(-5.0, 1.6, 3.0, 0.0, H2)
	_box(Vector3(0.9, (DOOR_H + H2) * 0.5, -5.0), Vector3(1.4, H2 - DOOR_H, T), _siding, true)

	# Garage wing walls, with the door gap in the -Z wall.
	_wall_x(11.0, -3.0, 5.0, 0.0, 4.6)
	_wall_z(5.0, 3.0, 11.0, 0.0, 4.6)
	_wall_z(-3.0, 3.0, 3.4, 0.0, 4.6)
	_wall_z(-3.0, 10.6, 11.0, 0.0, 4.6)
	_box(Vector3(7.0, (GARAGE_H + 4.6) * 0.5, -3.0), Vector3(GARAGE_W, 4.6 - GARAGE_H, T), _brick, true)
	# Door between the garage and the house.
	_box(Vector3(3.0, 2.3, 3.6), Vector3(T, 4.6, 2.8), _wall_in, true)
	_box(Vector3(3.0, (DOOR_H + 4.6) * 0.5, 1.2), Vector3(T, 4.6 - DOOR_H, 2.0), _wall_in, true)
	_box(Vector3(3.0, 2.3, -0.6), Vector3(T, 4.6, 1.6), _wall_in, true)

	# Cladding skins so the outside still reads as siding and brick.
	_skin(Vector3(-3.0, H2 * 0.5, -5.2), Vector3(12.4, H2, 0.16), _siding)
	_skin(Vector3(-3.0, H2 * 0.5, 5.2), Vector3(12.4, H2, 0.16), _siding)
	_skin(Vector3(-9.2, H2 * 0.5, 0.0), Vector3(0.16, H2, 10.4), _siding)
	_skin(Vector3(7.0, 2.3, -3.2), Vector3(8.4, 4.6, 0.16), _brick)
	_skin(Vector3(7.0, 2.3, 5.2), Vector3(8.4, 4.6, 0.16), _brick)
	_skin(Vector3(11.2, 2.3, 1.0), Vector3(0.16, 4.6, 8.4), _brick)
	_skin(Vector3(-3.0, 0.35, -5.3), Vector3(12.4, 0.7, 0.14), _brick)

	# Entry gable projection, and the chimney.
	_box(Vector3(1.0, H2 * 0.5, -5.7), Vector3(4.4, H2, 1.2), _siding, false)
	_box(Vector3(10.2, 4.6, 3.0), Vector3(1.3, 9.2, 1.3), _brick, true)
	_box(Vector3(10.2, 9.35, 3.0), Vector3(1.6, 0.3, 1.6), _mat(Color("6d6a63"), 0.9), false)


## Wall running along Z at a fixed X.
func _wall_x(x: float, z0: float, z1: float, y0: float, y1: float) -> void:
	_box(Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(T, y1 - y0, z1 - z0), _wall_in, true)


## Wall running along X at a fixed Z.
func _wall_z(z: float, x0: float, x1: float, y0: float, y1: float) -> void:
	_box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z), Vector3(x1 - x0, y1 - y0, T), _wall_in, true)


func _skin(centre: Vector3, size: Vector3, material: Material) -> void:
	_box(centre, size, material, false)


func _build_roofs() -> void:
	_slope_z(-3.0, 12.8, 0.0, -5.6, RIDGE, H2, _roof)
	_slope_z(-3.0, 12.8, 0.0, 5.6, RIDGE, H2, _roof)
	_slope_x(-6.5, 3.0, 1.0, -1.4, 7.9, H2 - 0.2, _roof)
	_slope_x(-6.5, 3.0, 1.0, 3.4, 7.9, H2 - 0.2, _roof)
	_box(Vector3(1.0, (H2 + 7.9) * 0.5 - 0.1, -6.4), Vector3(4.6, 1.7, 0.14), _siding, false)
	_disc(Vector3(1.0, H2 + 0.75, -6.5), 0.42, _trim)

	_slope_z(7.0, 8.8, 1.0, -4.8, 6.9, 4.6, _roof)
	_slope_z(7.0, 8.8, 1.0, 4.8, 6.9, 4.6, _roof)
	_box(Vector3(7.0, 5.75, -3.25), Vector3(8.4, 2.3, 0.14), _brick, false)
	_disc(Vector3(7.0, 5.6, -3.35), 0.34, _trim)


# ------------------------------------------------------------------ doors

func _build_doors() -> void:
	# Front door — slides aside as you walk up.
	_front_door = _slider(Vector3(0.9, DOOR_H * 0.5, -5.0), Vector3(DOOR_W, DOOR_H, 0.12), _door_mat)
	var knob := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	knob.mesh = s
	knob.material_override = _mat(Color("c9a227"), 0.3, 0.7)
	knob.position = Vector3(0.52, 0.0, -0.09)
	knob.name = "Knob"
	_front_door.add_child(knob)

	# Garage door — rolls up when you pull in.
	_garage_door = _slider(Vector3(7.0, GARAGE_H * 0.5, -3.0), Vector3(GARAGE_W, GARAGE_H, 0.12), _trim)
	for r in 4:
		var panel := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(GARAGE_W - 0.1, 0.04, 0.03)
		panel.mesh = pb
		panel.material_override = _mat(Color("d9d5c9"), 0.7)
		panel.position = Vector3(0, -0.95 + r * 0.62, -0.08)
		_garage_door.add_child(panel)


func _slider(at: Vector3, size: Vector3, material: Material) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = false
	body.position = at
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	body.add_child(mi)
	add_child(body)
	return body


# ------------------------------------------------------------------ interior

func _build_ground_floor() -> void:
	var rug := _mat(Color("6d4b52"), 0.9)
	var sofa := _mat(Color("4a5a68"), 0.8)
	var wood := _mat(Color("5b4432"), 0.6)
	var counter := _mat(Color("2f3338"), 0.4)

	# Family room, front-left.
	_box(Vector3(-5.0, 0.17, -1.6), Vector3(6.2, 0.03, 5.4), rug, false)
	_box(Vector3(-7.6, 0.55, -1.6), Vector3(0.9, 0.78, 2.8), sofa, true)
	_box(Vector3(-8.2, 1.05, -1.6), Vector3(0.3, 0.8, 2.8), sofa, true)
	_box(Vector3(-5.0, 0.55, -4.0), Vector3(2.6, 0.78, 0.9), sofa, true)
	_box(Vector3(-5.0, 0.42, -1.6), Vector3(1.6, 0.12, 0.9), wood, true)
	# TV on the wall.
	_box(Vector3(-2.2, 1.5, -1.6), Vector3(0.12, 1.0, 1.8), _mat(Color("15181c"), 0.3), false)
	var screen := _mat(Color("101820"), 0.25)
	screen.emission_enabled = true
	screen.emission = Color("2a6df4")
	screen.emission_energy_multiplier = 1.1
	_box(Vector3(-2.28, 1.5, -1.6), Vector3(0.03, 0.86, 1.62), screen, false)
	# Fireplace.
	_box(Vector3(-5.0, 0.75, 4.7), Vector3(2.2, 1.5, 0.4), _brick, true)
	_box(Vector3(-5.0, 0.55, 4.5), Vector3(1.2, 0.9, 0.2), _mat(Color("14100e"), 0.9), false)

	# Kitchen, back-right of the main block.
	_box(Vector3(1.4, 0.62, 3.4), Vector3(3.0, 0.92, 0.7), counter, true)
	_box(Vector3(1.4, 1.1, 4.6), Vector3(3.0, 1.9, 0.6), _mat(Color("d8d3c6"), 0.6), true)
	_box(Vector3(-0.6, 0.62, 1.6), Vector3(0.7, 0.92, 2.2), counter, true)
	_box(Vector3(2.2, 0.9, 1.4), Vector3(0.8, 1.8, 0.7), _mat(Color("b9bcc0"), 0.35, 0.7), true)
	# Dining table.
	_box(Vector3(-0.4, 0.74, -3.4), Vector3(1.8, 0.08, 1.1), wood, true)
	for tx in [-1.1, 0.3]:
		for tz in [-3.9, -2.9]:
			_box(Vector3(tx, 0.37, tz), Vector3(0.1, 0.74, 0.1), wood, false)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-4.0, 2.7, 0.0)
	lamp.light_color = Color("ffe9c4")
	lamp.light_energy = 2.2
	lamp.omni_range = 14.0
	add_child(lamp)
	var klamp := OmniLight3D.new()
	klamp.position = Vector3(1.0, 2.7, 2.6)
	klamp.light_color = Color("fff4dd")
	klamp.light_energy = 1.6
	klamp.omni_range = 10.0
	add_child(klamp)


func _build_upstairs() -> void:
	var carpet := _mat(Color("7d7466"), 0.95)
	var bed := _mat(Color("3d4e5c"), 0.85)
	var wood := _mat(Color("5b4432"), 0.6)

	# Stairs climb the well from the back of the house up to the landing edge.
	_ramp_z(1.6, 2.2, 4.4, -0.9, 0.02, UP_Y, _wall_in)

	# Landing runs west from the stair head to the bedroom door.
	_box(Vector3(-5.0, UP_Y + 0.03, 0.0), Vector3(7.6, 0.03, 9.4), carpet, false)
	_wall_x(-2.0, -4.6, 4.6, UP_Y, H2 - 0.2)
	_box(Vector3(-2.0, UP_Y + (DOOR_H + H2 - UP_Y) * 0.5 - 0.1, 1.0), Vector3(T, H2 - UP_Y - DOOR_H, 1.6), _wall_in, true)

	_box(Vector3(-6.0, UP_Y + 0.3, 1.4), Vector3(2.0, 0.6, 2.4), bed, true)
	_box(Vector3(-6.0, UP_Y + 0.75, 0.3), Vector3(2.0, 0.9, 0.15), wood, true)
	_box(Vector3(-8.2, UP_Y + 0.32, -1.2), Vector3(0.5, 0.64, 0.5), wood, true)
	_box(Vector3(-5.0, UP_Y + 0.6, -4.2), Vector3(2.2, 1.2, 0.6), wood, true)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-5.0, UP_Y + 2.4, 0.0)
	lamp.light_color = Color("ffe9c4")
	lamp.light_energy = 1.9
	lamp.omni_range = 13.0
	add_child(lamp)


# ------------------------------------------------------------------ outside

func _build_facade_detail() -> void:
	_box(Vector3(1.0, 0.09, -6.4), Vector3(4.0, 0.18, 1.4), _trim, true)
	for cx in [-0.6, 2.6]:
		_box(Vector3(cx, 1.55, -6.9), Vector3(0.22, 2.9, 0.22), _trim, true)
	_box(Vector3(1.0, 3.1, -6.6), Vector3(4.2, 0.3, 1.6), _trim, false)
	for i in 3:
		var y := 0.135 - i * 0.045
		_box(Vector3(1.0, y * 0.5, -7.25 - i * 0.34), Vector3(3.4, y, 0.34), _trim, true)

	# Bay window on the family-room wall.
	_box(Vector3(-5.0, 1.5, -5.55), Vector3(3.0, 2.2, 0.9), _trim, false)
	_box(Vector3(-5.0, 1.55, -6.02), Vector3(2.4, 1.7, 0.08), _glass, false)
	_box(Vector3(-5.0, 2.68, -5.55), Vector3(3.3, 0.22, 1.1), _roof, false)

	for wx in [-6.6, -2.4, 1.0]:
		_window(Vector3(wx, 4.55, -5.28), wx != 1.0)
	_window(Vector3(-9.28, 4.55, -2.0), false, true)
	_window(Vector3(-9.28, 1.7, 2.0), false, true)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.0, 2.6, -6.4)
	lamp.light_color = Color("ffd9a0")
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	add_child(lamp)


func _window(at: Vector3, shutters: bool, side: bool = false) -> void:
	var frame := Vector3(1.1, 1.5, 0.1)
	var pane := Vector3(0.92, 1.32, 0.06)
	if side:
		frame = Vector3(0.1, 1.5, 1.1)
		pane = Vector3(0.06, 1.32, 0.92)
	_box(at, frame, _trim, false)
	_box(at + (Vector3(0, 0, -0.03) if not side else Vector3(-0.03, 0, 0)), pane, _glass, false)
	if not shutters:
		return
	for sx in [-0.78, 0.78]:
		_box(at + Vector3(sx, 0, 0.01), Vector3(0.34, 1.5, 0.08), _shutter, false)


func _build_grounds() -> void:
	# Driveway runs from the garage door out to the kerb.
	_box(Vector3(7.0, 0.02, -14.0), Vector3(8.4, 0.04, 22.0), _drive, false)
	_box(Vector3(2.6, 0.02, -8.2), Vector3(1.4, 0.04, 3.6), _drive, false)

	for i in 6:
		var x := -7.6 + i * 1.35
		var r := 0.42 + (i % 3) * 0.07
		var bush := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = r
		sp.height = r * 1.7
		bush.mesh = sp
		bush.material_override = _shrub
		bush.position = Vector3(x, r * 0.7, -6.2)
		add_child(bush)

	_box(Vector3(-10.5, 1.7, -11.0), Vector3(0.5, 3.4, 0.5), _mat(Color("4a311f"), 0.92), true)
	for k in 3:
		var canopy := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 1.5 + k * 0.18
		cs.height = 2.2
		canopy.mesh = cs
		canopy.material_override = _mat(Color("2a5f26"), 0.9)
		canopy.position = Vector3(-10.5, 3.6 + k * 0.55, -11.0)
		add_child(canopy)

	_box(Vector3(1.6, 0.6, -22.2), Vector3(0.12, 1.2, 0.12), _mat(Color("2b2b2b"), 0.5), true)
	_box(Vector3(1.6, 1.32, -22.2), Vector3(0.24, 0.24, 0.5), _mat(Color("1f1f1f"), 0.4, 0.3), false)
	_label("5955", Vector3(1.6, 1.72, -22.2), 28, Color("f1faee"), Color.BLACK)

	_box(Vector3(-4.0, 1.4, -22.6), Vector3(0.1, 2.8, 0.1), _mat(Color("3a3a3a"), 0.5), true)
	_label("HATERLEIGH DR", Vector3(-4.0, 2.95, -22.6), 34, Color("1d7d3a"), Color.WHITE)


func _label(text: String, at: Vector3, size: int, tint: Color, outline: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.font_size = size
	l.modulate = tint
	l.outline_modulate = outline
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)


# ------------------------------------------------------------------ helpers

func _disc(at: Vector3, radius: float, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.1
	mi.mesh = cyl
	mi.material_override = material
	mi.rotation_degrees.x = 90.0
	mi.position = at
	add_child(mi)


## Walkable ramp climbing along Z. Same normalised convention as the office.
func _ramp_z(x_centre: float, width: float, z_from: float, z_to: float, y_from: float, y_to: float, material: Material) -> void:
	var run := absf(z_to - z_from)
	var rise := absf(y_to - y_from)
	var length := sqrt(run * run + rise * rise)
	var slope := atan2(rise, run)
	var climbs := (z_to > z_from) == (y_to > y_from)
	var ang := -slope if climbs else slope
	var thick := 0.3
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x_centre, (y_from + y_to) * 0.5 - thick * 0.5 * cos(ang), (z_from + z_to) * 0.5)
	body.rotation.x = ang
	var size := Vector3(width, thick, length)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	body.add_child(mi)
	add_child(body)


func _slope_z(x_centre: float, width: float, ridge_z: float, eave_z: float, ridge_y: float, eave_y: float, material: Material) -> void:
	var run := absf(eave_z - ridge_z)
	var rise := absf(ridge_y - eave_y)
	var slope := atan2(rise, run)
	var climbs := (eave_z > ridge_z) == (eave_y > ridge_y)
	var ang := -slope if climbs else slope
	_plane(Vector3(x_centre, (ridge_y + eave_y) * 0.5, (ridge_z + eave_z) * 0.5),
		Vector3(width, 0.22, sqrt(run * run + rise * rise)), Vector3(ang, 0, 0), material)


func _slope_x(z_centre: float, depth: float, ridge_x: float, eave_x: float, ridge_y: float, eave_y: float, material: Material) -> void:
	var run := absf(eave_x - ridge_x)
	var rise := absf(ridge_y - eave_y)
	var slope := atan2(rise, run)
	var climbs := (eave_x > ridge_x) == (eave_y > ridge_y)
	var ang := slope if climbs else -slope
	_plane(Vector3((ridge_x + eave_x) * 0.5, (ridge_y + eave_y) * 0.5, z_centre),
		Vector3(sqrt(run * run + rise * rise), 0.22, depth), Vector3(0, 0, ang), material)


func _plane(centre: Vector3, size: Vector3, euler: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	body.rotation = euler
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	body.add_child(mi)
	add_child(body)


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
