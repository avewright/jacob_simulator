extends Node3D

# Chastain Place. White stucco townhomes around a paver courtyard with a
# circular planter island, tucked-under garages, exterior stair runs up to
# raised front doors, and tall chimneys — straight off the reference photos.
#
# Local space: origin at the centre of the courtyard on the ground. The street
# is toward +Z, so the entry drive comes in from there.
#
# Jacob and Jack have the front-left corner unit. Its garage opens for the
# Camry, and the front door opens on foot.

const UNIT_W := 7.0        # frontage of one townhome
const UNIT_D := 8.0        # depth
const EAVE := 6.6
const RIDGE := 9.4
const GAR_W := 4.0
const GAR_H := 2.5
const STOOP_Y := 3.0       # front door sits at first-floor level, over the garage
const T := 0.3

# Jacob's corner unit, in local space.
const HOME := Vector3(-15.0, 0.0, 12.0)

var _stucco: StandardMaterial3D
var _roof: StandardMaterial3D
var _trim: StandardMaterial3D
var _dark: StandardMaterial3D
var _glass: StandardMaterial3D
var _paver: StandardMaterial3D
var _shrub: StandardMaterial3D
var _wall_in: StandardMaterial3D

var _garage: AnimatableBody3D
var _front: AnimatableBody3D
var _g_open: float = 0.0
var _f_open: float = 0.0


func _ready() -> void:
	add_to_group("chastain_place")
	_make_mats()
	_ground()
	_perimeter()
	_row_west()
	_row_east()
	_row_back()
	_home_interior()
	_jacks_suburban()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var car := get_tree().get_first_node_in_group("camry") as Node3D

	var want_g := 0.0
	var g_probe := Vector3(HOME.x + UNIT_W * 0.5 + 1.5, 0, HOME.z)
	if car and GameState.in_car and _flat(car, g_probe) < 13.0:
		want_g = 1.0
	elif player and not GameState.in_car and _flat(player, g_probe) < 7.0:
		want_g = 1.0
	_g_open = move_toward(_g_open, want_g, 2.2 * delta)
	if _garage:
		_garage.position.y = GAR_H * 0.5 + _g_open * (GAR_H - 0.15)

	var want_f := 0.0
	if player and not GameState.in_car and _flat(player, Vector3(HOME.x + UNIT_W * 0.5 + 2.0, 0, 15.1)) < 6.5:
		want_f = 1.0
	_f_open = move_toward(_f_open, want_f, 3.0 * delta)
	if _front:
		_front.position.z = 15.1 - _f_open * 1.05


func _flat(who: Node3D, local_point: Vector3) -> float:
	var p := to_global(local_point)
	return Vector2(p.x - who.global_position.x, p.z - who.global_position.z).length()


func _make_mats() -> void:
	_stucco = _mat(Color("f2f0ea"), 0.88)
	_roof = _mat(Color("5c5f62"), 0.94)
	_trim = _mat(Color("e8e6df"), 0.7)
	_dark = _mat(Color("3a3e42"), 0.6)
	_paver = _mat(Color("9d968c"), 0.92)
	_shrub = _mat(Color("2f5f31"), 0.95)
	_wall_in = _mat(Color("efe9dd"), 0.85)
	_glass = _mat(Color(0.5, 0.66, 0.78, 0.5), 0.08, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


# ------------------------------------------------------------------ site

func _ground() -> void:
	# Paver courtyard, flush with the world ground so nothing trips a car.
	_box(Vector3(0, 0.012, 0), Vector3(42.0, 0.02, 38.0), _paver, false)
	# Entry drive out to the street.
	_box(Vector3(0, 0.014, 24.0), Vector3(9.0, 0.02, 14.0), _paver, false)

	# Circular planter island in the middle of the turning circle.
	var kerb := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 4.2
	ring.bottom_radius = 4.2
	ring.height = 0.5
	kerb.mesh = ring
	kerb.material_override = _trim
	kerb.position = Vector3(0, 0.25, 2.0)
	add_child(kerb)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0, 0.25, 2.0)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 4.2
	cyl.height = 0.5
	col.shape = cyl
	body.add_child(col)
	add_child(body)
	var soil := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.9
	disc.bottom_radius = 3.9
	disc.height = 0.06
	soil.mesh = disc
	soil.material_override = _mat(Color("5a4636"), 0.95)
	soil.position = Vector3(0, 0.52, 2.0)
	add_child(soil)
	for i in 6:
		var a := TAU * i / 6.0
		_bush(Vector3(sin(a) * 2.7, 0.62, 2.0 + cos(a) * 2.7), 0.5)
	_box(Vector3(0, 1.55, 2.0), Vector3(0.26, 2.1, 0.26), _mat(Color("4a311f"), 0.92), true)
	for k in 3:
		_globe(Vector3(0, 2.7 + k * 0.34, 2.0), 0.95 - k * 0.16, _mat(Color("2a5f26"), 0.9))


func _perimeter() -> void:
	# Low stucco wall along the street frontage, split for the entry drive.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 13.5, 0.9, 19.0), Vector3(15.0, 1.8, 0.5), _stucco, true)
		_box(Vector3(side * 13.5, 1.85, 19.0), Vector3(15.2, 0.14, 0.7), _trim, false)
		for i in 6:
			_bush(Vector3(side * 6.5 + side * i * 2.4, 0.45, 20.0), 0.62)
	# Pier either side of the gateway.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 5.4, 1.15, 19.0), Vector3(1.2, 2.3, 1.2), _stucco, true)
		_globe(Vector3(side * 5.4, 2.55, 19.0), 0.3, _mat(Color("ffe9a8"), 0.3))

	var sign := Label3D.new()
	sign.text = "CHASTAIN PLACE"
	sign.position = Vector3(-11.0, 1.15, 18.68)
	sign.font_size = 44
	sign.modulate = Color("4a4640")
	sign.rotation_degrees.y = 180.0
	add_child(sign)

	# Carriage lamps flanking the drive.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 7.4, 1.6, 16.0), Vector3(0.16, 3.2, 0.16), _dark, true)
		_globe(Vector3(side * 7.4, 3.4, 16.0), 0.26, _mat(Color("ffe9a8"), 0.3))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side * 7.4, 3.4, 16.0)
		lamp.light_color = Color("ffdba8")
		lamp.light_energy = 2.0
		lamp.omni_range = 12.0
		add_child(lamp)


# ------------------------------------------------------------------ rows

func _row_west() -> void:
	# Fronts face +X into the courtyard; the near unit is Jacob's and is built
	# separately so its doors and stoop line up without any rotation maths.
	for i in range(1, 4):
		_unit(Vector3(-15.0, 0, 12.0 - i * UNIT_W), -90.0, false)


func _row_east() -> void:
	for i in 4:
		_unit(Vector3(15.0, 0, 12.0 - i * UNIT_W), 90.0, false)


func _row_back() -> void:
	for i in 3:
		var x := -7.0 + i * UNIT_W
		_unit(Vector3(x, 0, -14.0), 180.0, false)


## One townhome. `yaw` turns the whole unit so its front faces the courtyard;
## the geometry below is authored facing -Z and rotated into place.
func _unit(at: Vector3, yaw: float, is_home: bool) -> void:
	var unit := Node3D.new()
	unit.position = at
	unit.rotation_degrees.y = yaw
	add_child(unit)

	var hw := UNIT_W * 0.5
	var hd := UNIT_D * 0.5

	# Massing: three storeys of white stucco.
	_at(unit, Vector3(0, EAVE * 0.5, 0), Vector3(UNIT_W, EAVE, UNIT_D), _stucco, not is_home)
	# Steep gable, ridge running across the frontage.
	_gable(unit, 0.0, UNIT_W + 0.5, hd + 0.3, RIDGE, EAVE)

	# Tall chimney on the party wall — the signature of these blocks.
	_at(unit, Vector3(hw - 0.5, 5.4, 0.6), Vector3(1.1, 10.8, 1.1), _stucco, true)
	_at(unit, Vector3(hw - 0.5, 10.95, 0.6), Vector3(1.35, 0.3, 1.35), _dark, false)

	# Tucked-under garage in the front elevation.
	_at(unit, Vector3(0, GAR_H * 0.5, -hd - 0.06), Vector3(GAR_W + 0.5, GAR_H + 0.4, 0.16), _trim, false)
	if not is_home:
		_at(unit, Vector3(0, GAR_H * 0.5, -hd - 0.12), Vector3(GAR_W, GAR_H, 0.12), _dark, false)
		for r in 4:
			_at(unit, Vector3(0, 0.35 + r * 0.6, -hd - 0.2), Vector3(GAR_W - 0.15, 0.05, 0.03), _mat(Color("3a3d40"), 0.6), false)

	# Raised stoop reached by an exterior stair run, as in the photos.
	_at(unit, Vector3(hw - 1.5, STOOP_Y - 0.08, -hd - 0.9), Vector3(2.4, 0.16, 1.8), _trim, true)
	for s in 10:
		var h := STOOP_Y * (10 - s) / 10.0
		_at(unit, Vector3(hw - 1.5, h * 0.5, -hd - 1.9 - s * 0.34), Vector3(2.0, h, 0.34), _trim, true)
	for side in [-1.1, 1.1]:
		_at(unit, Vector3(hw - 1.5 + side, STOOP_Y + 0.5, -hd - 1.4), Vector3(0.08, 1.0, 2.6), _dark, false)

	# Front door in the raised elevation.
	if not is_home:
		_at(unit, Vector3(hw - 1.5, STOOP_Y + 1.15, -hd - 0.06), Vector3(1.1, 2.3, 0.14), _dark, false)
	_at(unit, Vector3(hw - 1.5, STOOP_Y + 2.42, -hd - 0.1), Vector3(1.5, 0.18, 0.2), _trim, false)

	# Windows with dark shutters.
	for lvl in [STOOP_Y + 1.3, EAVE - 2.0]:
		for wx in [-hw + 1.6, -hw + 3.4]:
			_window(unit, Vector3(wx, lvl, -hd - 0.05))
	_window(unit, Vector3(hw - 1.5, EAVE - 2.0, -hd - 0.05))
	# Gable-end porthole, like the reference.
	_at(unit, Vector3(0, EAVE + 1.2, -hd - 0.05), Vector3(0.5, 0.5, 0.08), _dark, false)


func _gable(parent: Node3D, x_centre: float, width: float, half_depth: float, ridge_y: float, eave_y: float) -> void:
	for dir in [-1.0, 1.0]:
		var run := half_depth
		var rise := ridge_y - eave_y
		var slope := atan2(rise, run)
		# Rx(-slope) sends local +Z up; flip the sign for the far side.
		var ang := -slope if dir > 0.0 else slope
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(x_centre, (ridge_y + eave_y) * 0.5, dir * half_depth * 0.5)
		body.rotation.x = ang
		var size := Vector3(width, 0.24, sqrt(run * run + rise * rise))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
		mi.material_override = _roof
		body.add_child(mi)
		parent.add_child(body)


func _window(parent: Node3D, at: Vector3) -> void:
	_at(parent, at, Vector3(0.8, 1.15, 0.07), _trim, false)
	_at(parent, at + Vector3(0, 0, -0.03), Vector3(0.62, 0.98, 0.04), _glass, false)
	for sx in [-0.56, 0.56]:
		_at(parent, at + Vector3(sx, 0, 0.01), Vector3(0.22, 1.15, 0.05), _dark, false)


# ------------------------------------------------------------------ home

func _home_interior() -> void:
	# Jacob's unit, front face at x = -11.5 looking into the courtyard.
	# Authored directly in complex space so doors, stoop and slab all agree.
	var fx := HOME.x + UNIT_W * 0.5          # -11.5
	var bx := HOME.x - UNIT_W * 0.5          # -18.5
	var z0 := HOME.z - UNIT_D * 0.5          # 8.0
	var z1 := HOME.z + UNIT_D * 0.5          # 16.0
	var f1 := STOOP_Y                        # first-floor slab top, 3.0
	var dz := 15.1                           # front door centre

	# Shell.
	_box(Vector3(bx, EAVE * 0.5, HOME.z), Vector3(T, EAVE, UNIT_D), _stucco, true)
	_box(Vector3(HOME.x, EAVE * 0.5, z0), Vector3(UNIT_W, EAVE, T), _stucco, true)
	_box(Vector3(HOME.x, EAVE * 0.5, z1), Vector3(UNIT_W, EAVE, T), _stucco, true)

	# Front elevation, left open at the garage and the front door.
	_box(Vector3(fx, EAVE * 0.5, 9.0), Vector3(T, EAVE, 2.0), _stucco, true)
	_box(Vector3(fx, (GAR_H + EAVE) * 0.5, 12.0), Vector3(T, EAVE - GAR_H, 4.0), _stucco, true)
	_box(Vector3(fx, EAVE * 0.5, 14.25), Vector3(T, EAVE, 0.5), _stucco, true)
	_box(Vector3(fx, f1 * 0.5, dz), Vector3(T, f1, 1.2), _stucco, true)
	_box(Vector3(fx, (f1 + 2.3 + EAVE) * 0.5, dz), Vector3(T, EAVE - f1 - 2.3, 1.2), _stucco, true)
	_box(Vector3(fx, EAVE * 0.5, 15.85), Vector3(T, EAVE, 0.3), _stucco, true)

	_gable_at(HOME.x, HOME.z, UNIT_W + 0.5, UNIT_D * 0.5 + 0.3, RIDGE, EAVE)
	_box(Vector3(bx + 0.5, 5.4, 9.4), Vector3(1.1, 10.8, 1.1), _stucco, true)
	_box(Vector3(bx + 0.5, 10.95, 9.4), Vector3(1.35, 0.3, 1.35), _dark, false)

	# Garage floor, painted flush.
	_box(Vector3(HOME.x, 0.01, HOME.z), Vector3(UNIT_W, 0.02, UNIT_D), _mat(Color("b3b1a8"), 0.9), false)

	# First-floor slab, cut around the internal stair well at
	# x -18.5..-15.8, z 9.4..15.2.
	_box(Vector3(-13.65, f1 - 0.1, HOME.z), Vector3(4.3, 0.2, UNIT_D), _wall_in, true)
	_box(Vector3(-17.15, f1 - 0.1, 8.7), Vector3(2.7, 0.2, 1.4), _wall_in, true)
	_box(Vector3(-17.15, f1 - 0.1, 15.6), Vector3(2.7, 0.2, 0.8), _wall_in, true)
	_ramp_c(-17.15, 2.2, 14.8, 9.8, 0.02, f1 - 0.1)
	_box(Vector3(-15.8, f1 + 0.5, 12.3), Vector3(0.1, 1.0, 5.8), _mat(Color("5b4432"), 0.6), true)

	# Living room on the first floor, with two mattresses.
	_box(Vector3(-13.65, f1 + 0.04, HOME.z), Vector3(4.2, 0.03, 7.4), _mat(Color("7b6a58"), 0.9), false)
	_box(Vector3(-15.3, f1 + 0.45, 11.0), Vector3(0.85, 0.75, 2.4), _mat(Color("4a5a68"), 0.8), true)
	_box(Vector3(-13.8, f1 + 0.35, 11.0), Vector3(1.4, 0.1, 0.8), _mat(Color("5b4432"), 0.6), true)
	var screen := _mat(Color("101820"), 0.25)
	screen.emission_enabled = true
	screen.emission = Color("2a6df4")
	screen.emission_energy_multiplier = 1.1
	_box(Vector3(fx - 0.22, f1 + 1.1, 11.0), Vector3(0.06, 0.9, 1.6), screen, false)
	for bz in [9.2, 13.3]:
		_box(Vector3(-13.4, f1 + 0.25, bz), Vector3(2.2, 0.35, 0.95), _mat(Color("3d4e5c"), 0.85), true)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-14.0, f1 + 2.0, HOME.z)
	lamp.light_color = Color("ffe9c4")
	lamp.light_energy = 2.0
	lamp.omni_range = 12.0
	add_child(lamp)

	# Exterior stoop: a ramp, not treads, since nothing here can climb a step.
	# Decorative nosings sit on top so it still reads as a stair.
	_ramp_x(dz, 1.8, -5.0, -10.6, 0.02, f1)
	_box(Vector3(-10.95, f1 - 0.08, dz), Vector3(1.3, 0.16, 1.8), _trim, true)
	for st in 9:
		var t: float = (st + 1) / 10.0
		_box(Vector3(-5.0 - t * 5.6, 0.12 + t * f1, dz), Vector3(0.12, 0.06, 1.8), _trim, false)
	for side in [-0.95, 0.95]:
		_box(Vector3(-8.0, f1 * 0.5 + 0.9, dz + side), Vector3(6.4, 0.08, 0.08), _dark, false)

	# Garage surround and door.
	_box(Vector3(fx - 0.06, GAR_H * 0.5, 12.0), Vector3(0.16, GAR_H + 0.4, GAR_W + 0.5), _trim, false)
	_garage = _slider(Vector3(fx - 0.14, GAR_H * 0.5, 12.0), Vector3(0.12, GAR_H, GAR_W), _trim)
	for r in 4:
		var panel := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.03, 0.05, GAR_W - 0.15)
		panel.mesh = pb
		panel.material_override = _mat(Color("d9d5c9"), 0.7)
		panel.position = Vector3(-0.08, -0.95 + r * 0.62, 0)
		_garage.add_child(panel)

	# Front door and surround.
	_box(Vector3(fx - 0.05, f1 + 1.15, dz), Vector3(0.14, 2.5, 1.35), _trim, false)
	_front = _slider(Vector3(fx - 0.13, f1 + 1.15, dz), Vector3(0.12, 2.3, 1.1), _dark)

	_window_at(Vector3(fx - 0.02, f1 + 1.3, 9.6), true)
	_window_at(Vector3(fx - 0.02, EAVE - 1.6, 12.0), true)
	_box(Vector3(fx - 0.02, EAVE + 1.2, HOME.z), Vector3(0.08, 0.5, 0.5), _dark, false)

	var plate := Label3D.new()
	plate.text = "JACOB  &  JACK"
	plate.position = Vector3(fx + 0.4, f1 + 2.65, dz)
	plate.font_size = 26
	plate.modulate = Color("ffb703")
	plate.outline_modulate = Color.BLACK
	plate.outline_size = 6
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(plate)


## Ramp climbing along X at a fixed Z.
func _ramp_x(z_centre: float, width: float, x_from: float, x_to: float, y_from: float, y_to: float) -> void:
	var run := absf(x_to - x_from)
	var rise := absf(y_to - y_from)
	var slope := atan2(rise, run)
	var climbs := (x_to > x_from) == (y_to > y_from)
	var ang := slope if climbs else -slope
	var thick := 0.28
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3((x_from + x_to) * 0.5, (y_from + y_to) * 0.5 - thick * 0.5 * cos(ang), z_centre)
	body.rotation.z = ang
	var size := Vector3(sqrt(run * run + rise * rise), thick, width)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _trim
	body.add_child(mi)
	add_child(body)


## Gable in complex space, ridge running along X.
func _gable_at(x_centre: float, z_centre: float, width: float, half_depth: float, ridge_y: float, eave_y: float) -> void:
	for dir in [-1.0, 1.0]:
		var rise := ridge_y - eave_y
		var slope := atan2(rise, half_depth)
		var ang := -slope if dir > 0.0 else slope
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(x_centre, (ridge_y + eave_y) * 0.5, z_centre + dir * half_depth * 0.5)
		body.rotation.x = ang
		var size := Vector3(width, 0.24, sqrt(half_depth * half_depth + rise * rise))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
		mi.material_override = _roof
		body.add_child(mi)
		add_child(body)


func _window_at(at: Vector3, side_on: bool) -> void:
	var frame := Vector3(0.08, 1.35, 0.95) if side_on else Vector3(0.95, 1.35, 0.08)
	var pane := Vector3(0.05, 1.18, 0.78) if side_on else Vector3(0.78, 1.18, 0.05)
	_box(at, frame, _trim, false)
	_box(at, pane, _glass, false)
	for sx in [-0.68, 0.68]:
		var off := Vector3(0, 0, sx) if side_on else Vector3(sx, 0, 0)
		_box(at + off, Vector3(0.06, 1.35, 0.3) if side_on else Vector3(0.3, 1.35, 0.06), _dark, false)


func _ramp_c(x_centre: float, width: float, z_from: float, z_to: float, y_from: float, y_to: float) -> void:
	var run := absf(z_to - z_from)
	var rise := absf(y_to - y_from)
	var slope := atan2(rise, run)
	var climbs := (z_to > z_from) == (y_to > y_from)
	var ang := -slope if climbs else slope
	var thick := 0.28
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x_centre, (y_from + y_to) * 0.5 - thick * 0.5 * cos(ang), (z_from + z_to) * 0.5)
	body.rotation.x = ang
	var size := Vector3(width, thick, sqrt(run * run + rise * rise))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _wall_in
	body.add_child(mi)
	add_child(body)


func _jacks_suburban() -> void:
	# Parked at an angle across his own driveway, half on the kerb.
	var suv := Node3D.new()
	suv.position = Vector3(-6.2, 0.0, 11.4)
	suv.rotation_degrees.y = 24.0
	add_child(suv)

	var paint := _mat(Color("14161a"), 0.34, 0.3)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.5
	var glass := _mat(Color(0.1, 0.14, 0.18, 0.72), 0.05, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rubber := _mat(Color("111111"), 0.92)
	var chrome := _mat(Color("c8c8c8"), 0.22, 0.9)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 1.5, 5.6)
	col.shape = shape
	col.position.y = 1.05
	body.add_child(col)
	suv.add_child(body)

	_at(suv, Vector3(0, 1.05, 0), Vector3(2.1, 1.1, 5.6), paint, false)
	_at(suv, Vector3(0, 1.85, -0.35), Vector3(1.95, 0.62, 3.6), paint, false)
	_at(suv, Vector3(0, 1.85, 1.5), Vector3(1.85, 0.5, 0.06), glass, false)
	for sx in [-0.99, 0.99]:
		_at(suv, Vector3(sx, 1.85, -0.35), Vector3(0.05, 0.46, 3.4), glass, false)
	_at(suv, Vector3(0, 1.85, -2.16), Vector3(1.8, 0.5, 0.06), glass, false)
	_at(suv, Vector3(0, 0.75, 2.82), Vector3(2.0, 0.3, 0.12), chrome, false)
	_at(suv, Vector3(0, 0.75, -2.82), Vector3(2.0, 0.3, 0.12), chrome, false)
	for lx in [-0.72, 0.72]:
		_at(suv, Vector3(lx, 1.2, 2.8), Vector3(0.5, 0.26, 0.1), _mat(Color("fff3c4"), 0.2), false)
		_at(suv, Vector3(lx, 1.25, -2.8), Vector3(0.42, 0.3, 0.1), _mat(Color("cc2222"), 0.3), false)
	for wp in [Vector3(-1.0, 0.42, 1.75), Vector3(1.0, 0.42, 1.75), Vector3(-1.0, 0.42, -1.75), Vector3(1.0, 0.42, -1.75)]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.42
		cyl.height = 0.3
		wheel.mesh = cyl
		wheel.material_override = rubber
		wheel.rotation_degrees.z = 90.0
		wheel.position = wp
		suv.add_child(wheel)

	var tag := Label3D.new()
	tag.text = "Jack parked here. Again."
	tag.position = Vector3(0, 2.7, 0)
	tag.font_size = 24
	tag.modulate = Color("f1faee")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	suv.add_child(tag)


# ------------------------------------------------------------------ helpers

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


func _ramp_local(parent: Node3D, x_centre: float, width: float, z_from: float, z_to: float, y_from: float, y_to: float) -> void:
	var run := absf(z_to - z_from)
	var rise := absf(y_to - y_from)
	var slope := atan2(rise, run)
	var climbs := (z_to > z_from) == (y_to > y_from)
	var ang := -slope if climbs else slope
	var thick := 0.28
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x_centre, (y_from + y_to) * 0.5 - thick * 0.5 * cos(ang), (z_from + z_to) * 0.5)
	body.rotation.x = ang
	var size := Vector3(width, thick, sqrt(run * run + rise * rise))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _wall_in
	body.add_child(mi)
	parent.add_child(body)


func _bush(at: Vector3, r: float) -> void:
	_globe(at, r, _shrub)


func _globe(at: Vector3, r: float, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 1.8
	mi.mesh = sp
	mi.material_override = material
	mi.position = at
	add_child(mi)


func _at(parent: Node3D, centre: Vector3, size: Vector3, material: Material, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = centre
	parent.add_child(mi)
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
	parent.add_child(body)


func _box(centre: Vector3, size: Vector3, material: Material, solid: bool) -> void:
	_at(self, centre, size, material, solid)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
