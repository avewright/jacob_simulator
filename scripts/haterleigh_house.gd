extends Node3D

# 5955 Haterleigh Dr. Two-storey traditional off the reference photo: tan
# siding over a brick garage wing, front-gabled entry with a half-round vent,
# bay window left of the door, chimney on the garage side.
#
# Local space: origin at the centre of the plot on the ground, front facing -Z
# (the street). Drop it in facing the road and the driveway runs out the front.

const H1 := 3.2          # first-floor plate
const H2 := 6.4          # second-floor plate / eave line
const RIDGE := 8.7

var _siding: StandardMaterial3D
var _brick: StandardMaterial3D
var _trim: StandardMaterial3D
var _roof: StandardMaterial3D
var _glass: StandardMaterial3D
var _shutter: StandardMaterial3D
var _door: StandardMaterial3D
var _drive: StandardMaterial3D
var _shrub: StandardMaterial3D


func _ready() -> void:
	add_to_group("haterleigh_house")
	_make_mats()
	_build_massing()
	_build_roofs()
	_build_entry()
	_build_windows()
	_build_grounds()


func _make_mats() -> void:
	_siding = _mat(Color("c2b393"), 0.85)
	_brick = _mat(Color("9c5f45"), 0.9)
	_trim = _mat(Color("f2efe6"), 0.6)
	_roof = _mat(Color("4a4640"), 0.95)
	_shutter = _mat(Color("2b2f33"), 0.7)
	_door = _mat(Color("39312c"), 0.5)
	_drive = _mat(Color("b9b7ad"), 0.92)
	_shrub = _mat(Color("2f5f31"), 0.95)
	_glass = _mat(Color(0.55, 0.72, 0.84, 0.55), 0.08, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_massing() -> void:
	# Main two-storey block, siding.
	_box(Vector3(-3.0, H2 * 0.5, 0.0), Vector3(12.0, H2, 10.0), _siding, true)
	# Garage wing, brick, single storey with a taller gable over it.
	_box(Vector3(7.0, 2.3, 1.0), Vector3(8.0, 4.6, 8.0), _brick, true)
	# Brick skirt under the siding, as in the photo.
	_box(Vector3(-3.0, 0.35, -5.05), Vector3(12.0, 0.7, 0.2), _brick, false)

	# Entry gable projection.
	_box(Vector3(1.0, H2 * 0.5, -5.6), Vector3(4.4, H2, 1.4), _siding, true)

	# Chimney on the far side of the garage.
	_box(Vector3(10.2, 4.6, 3.0), Vector3(1.3, 9.2, 1.3), _brick, true)
	_box(Vector3(10.2, 9.35, 3.0), Vector3(1.6, 0.3, 1.6), _mat(Color("6d6a63"), 0.9), false)


func _build_roofs() -> void:
	# Main hip: ridge runs along X, slopes falling to -Z and +Z.
	_slope_z(-3.0, 12.6, 0.0, -5.4, RIDGE, H2, _roof)
	_slope_z(-3.0, 12.6, 0.0, 5.4, RIDGE, H2, _roof)
	# Front-facing gable over the entry: ridge along Z, slopes to -X and +X.
	_slope_x(-6.4, 3.0, 1.0, -1.4, 7.9, H2 - 0.2, _roof)
	_slope_x(-6.4, 3.0, 1.0, 3.4, 7.9, H2 - 0.2, _roof)
	# Gable face with the half-round vent.
	_box(Vector3(1.0, (H2 + 7.9) * 0.5 - 0.1, -6.3), Vector3(4.6, 1.7, 0.14), _siding, false)
	var vent := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.1
	vent.mesh = cyl
	vent.material_override = _trim
	vent.rotation_degrees.x = 90.0
	vent.position = Vector3(1.0, H2 + 0.75, -6.4)
	add_child(vent)

	# Garage wing gable, ridge along X.
	_slope_z(7.0, 8.6, 1.0, -4.6, 6.9, 4.6, _roof)
	_slope_z(7.0, 8.6, 1.0, 4.6, 6.9, 4.6, _roof)
	_box(Vector3(7.0, 5.75, -3.05), Vector3(8.2, 2.3, 0.14), _brick, false)
	var round_vent := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.34
	rc.bottom_radius = 0.34
	rc.height = 0.1
	round_vent.mesh = rc
	round_vent.material_override = _trim
	round_vent.rotation_degrees.x = 90.0
	round_vent.position = Vector3(7.0, 5.6, -3.15)
	add_child(round_vent)


func _build_entry() -> void:
	# Portico slab + columns in front of the door.
	_box(Vector3(1.0, 0.09, -6.9), Vector3(4.0, 0.18, 1.4), _trim, true)
	for cx in [-0.6, 2.6]:
		_box(Vector3(cx, 1.55, -7.4), Vector3(0.22, 2.9, 0.22), _trim, true)
	_box(Vector3(1.0, 3.1, -7.1), Vector3(4.2, 0.3, 1.6), _trim, false)

	# Door and sidelight.
	_box(Vector3(0.9, 1.15, -6.34), Vector3(1.0, 2.3, 0.12), _door, false)
	_box(Vector3(0.9, 2.42, -6.34), Vector3(1.0, 0.16, 0.14), _trim, false)
	var knob := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	knob.mesh = s
	knob.material_override = _mat(Color("c9a227"), 0.3, 0.7)
	knob.position = Vector3(1.28, 1.15, -6.44)
	add_child(knob)

	# Steps down to the walk.
	for i in 3:
		var y := 0.135 - i * 0.045
		_box(Vector3(1.0, y * 0.5, -7.75 - i * 0.34), Vector3(3.4, y, 0.34), _trim, true)

	# Two garage doors.
	for gx in [4.6, 8.6]:
		_box(Vector3(gx, 1.25, -2.96), Vector3(3.2, 2.5, 0.14), _trim, false)
		for r in 4:
			_box(Vector3(gx, 0.35 + r * 0.6, -2.88), Vector3(3.1, 0.05, 0.03), _mat(Color("d9d5c9"), 0.7), false)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.0, 2.6, -6.9)
	lamp.light_color = Color("ffd9a0")
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	add_child(lamp)


func _build_windows() -> void:
	# Bay window, left of the entry.
	_box(Vector3(-4.4, 1.5, -5.5), Vector3(3.0, 2.2, 1.0), _trim, true)
	_box(Vector3(-4.4, 1.55, -6.02), Vector3(2.4, 1.7, 0.08), _glass, false)
	_box(Vector3(-4.4, 2.68, -5.5), Vector3(3.3, 0.22, 1.2), _roof, false)

	# Upper-floor windows on the front, with shutters.
	for wx in [-6.4, -2.2, 1.0]:
		_window(Vector3(wx, 4.55, -5.06), wx != 1.0)
	# Side windows.
	_window(Vector3(-9.06, 4.55, -2.0), false, true)
	_window(Vector3(-9.06, 1.7, 2.0), false, true)


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
	# Driveway out to the street (which lies toward -Z).
	_box(Vector3(6.6, 0.02, -15.0), Vector3(8.0, 0.04, 18.0), _drive, false)
	_box(Vector3(2.4, 0.02, -8.6), Vector3(1.4, 0.04, 3.6), _drive, false)

	# Shrub line along the front, like the photo.
	for i in 6:
		var x := -7.4 + i * 1.35
		var r := 0.42 + (i % 3) * 0.07
		var bush := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = r
		sp.height = r * 1.7
		bush.mesh = sp
		bush.material_override = _shrub
		bush.position = Vector3(x, r * 0.7, -6.0)
		add_child(bush)

	# Front tree.
	_box(Vector3(-9.5, 1.7, -11.0), Vector3(0.5, 3.4, 0.5), _mat(Color("4a311f"), 0.92), true)
	for k in 3:
		var canopy := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 1.5 + k * 0.18
		cs.height = 2.2
		canopy.mesh = cs
		canopy.material_override = _mat(Color("2a5f26"), 0.9)
		canopy.position = Vector3(-9.5, 3.6 + k * 0.55, -11.0)
		add_child(canopy)

	# Mailbox at the kerb.
	_box(Vector3(2.0, 0.6, -22.2), Vector3(0.12, 1.2, 0.12), _mat(Color("2b2b2b"), 0.5), true)
	_box(Vector3(2.0, 1.32, -22.2), Vector3(0.24, 0.24, 0.5), _mat(Color("1f1f1f"), 0.4, 0.3), false)

	var number := Label3D.new()
	number.text = "5955"
	number.position = Vector3(2.0, 1.72, -22.2)
	number.font_size = 28
	number.modulate = Color("f1faee")
	number.outline_modulate = Color.BLACK
	number.outline_size = 5
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(number)

	# Street sign at the kerb.
	_box(Vector3(-4.0, 1.4, -22.6), Vector3(0.1, 2.8, 0.1), _mat(Color("3a3a3a"), 0.5), true)
	var street := Label3D.new()
	street.text = "HATERLEIGH DR"
	street.position = Vector3(-4.0, 2.95, -22.6)
	street.font_size = 34
	street.modulate = Color("1d7d3a")
	street.outline_modulate = Color.WHITE
	street.outline_size = 7
	street.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(street)


# ------------------------------------------------------------------ helpers

## Roof plane whose ridge runs along X, falling from `ridge_y` at z = ridge_z
## to `eave_y` at z = eave_z.
func _slope_z(x_centre: float, width: float, ridge_z: float, eave_z: float, ridge_y: float, eave_y: float, material: Material) -> void:
	var run := absf(eave_z - ridge_z)
	var rise := absf(ridge_y - eave_y)
	var slope := atan2(rise, run)
	var climbs := (eave_z > ridge_z) == (eave_y > ridge_y)
	var ang := -slope if climbs else slope
	_plane(Vector3(x_centre, (ridge_y + eave_y) * 0.5, (ridge_z + eave_z) * 0.5),
		Vector3(width, 0.22, sqrt(run * run + rise * rise)), Vector3(ang, 0, 0), material)


## Roof plane whose ridge runs along Z, falling from `ridge_y` at x = ridge_x
## to `eave_y` at x = eave_x.
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
