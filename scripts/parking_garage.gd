extends Node3D

# Two-deck garage. Local space: origin at the centre on the ground, both
# entrances on the west face.
#
# Circulation is deliberately turn-free: the ramp lane lines up with its own
# opening, so you drive straight in and straight up. The earlier version made
# you hook 90 degrees into a 2 m gap between the wall and the ramp foot, which
# is not something a 4.35 m car can do.

const W := 26.0
const D := 22.0
const DECK_Y := 4.2
const SLAB := 0.4
const CLEAR := DECK_Y - SLAB

# Ramp lane: its own opening on the west face, climbing all the way east.
const RAMP_Z0 := 3.4
const RAMP_Z1 := 8.4
const RAMP_X0 := -13.6      # starts outside the wall line, at ground level
const RAMP_X1 := 7.0
# Ground entrance lane, kept clear of every column.
const GATE_Z0 := -4.5
const GATE_Z1 := 0.5

var _concrete: StandardMaterial3D
var _paint: StandardMaterial3D
var _kerb: StandardMaterial3D


func _ready() -> void:
	add_to_group("parking_garage")
	_concrete = _mat(Color("9a9d9f"), 0.9)
	_paint = _mat(Color("e8e8e0"), 0.7)
	_kerb = _mat(Color("c9a227"), 0.5, 0.3)
	_build_ground()
	_build_ramp()
	_build_upper()
	_signage()


func _build_ground() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	# Deck markings only — no raised pad. The old 0.15 slab presented a vertical
	# lip across the whole west face, which is what was registering a crash
	# every time you drove in.
	_box(Vector3(0, 0.012, 0), Vector3(W, 0.02, D), _mat(Color("86898b"), 0.93), false)

	# North, south and east walls.
	_box(Vector3(0, CLEAR * 0.5, -hz), Vector3(W, CLEAR, 0.4), _concrete, true)
	_box(Vector3(0, CLEAR * 0.5, hz), Vector3(W, CLEAR, 0.4), _concrete, true)
	_box(Vector3(hx, CLEAR * 0.5, 0), Vector3(0.4, CLEAR, D), _concrete, true)

	# West face: solid except the two lanes.
	_west_wall(-hz, GATE_Z0)
	_west_wall(GATE_Z1, RAMP_Z0)
	_west_wall(RAMP_Z1, hz)

	# Columns, placed between the parking bays and clear of both lanes.
	for cx in [-7.0, 0.0, 7.0]:
		for cz in [-8.2, 2.4]:
			_box(Vector3(cx, CLEAR * 0.5, cz), Vector3(0.5, CLEAR, 0.5), _concrete, true)

	_stalls(0.03, -7.6)


func _west_wall(z_from: float, z_to: float) -> void:
	var depth := z_to - z_from
	if depth <= 0.05:
		return
	_box(Vector3(-W * 0.5, CLEAR * 0.5, z_from + depth * 0.5), Vector3(0.4, CLEAR, depth), _concrete, true)


func _build_ramp() -> void:
	var run := RAMP_X1 - RAMP_X0
	var rise := DECK_Y
	var length := sqrt(run * run + rise * rise)
	var ang := atan2(rise, run)
	var thick := 0.4
	# Rz(+a) tilts local +X upward, so the east end is the top.
	_tilted(Vector3((RAMP_X0 + RAMP_X1) * 0.5, DECK_Y * 0.5 - thick * 0.5 * cos(ang), (RAMP_Z0 + RAMP_Z1) * 0.5),
		Vector3(length, thick, RAMP_Z1 - RAMP_Z0), ang, _mat(Color("8b8e90"), 0.92))

	# Kerbs down both sides so you cannot slide off the edge mid-climb.
	for side in [RAMP_Z0 - 0.25, RAMP_Z1 + 0.25]:
		_tilted(Vector3((RAMP_X0 + RAMP_X1) * 0.5, DECK_Y * 0.5 + 0.3, side),
			Vector3(length, 0.45, 0.25), ang, _kerb)

	# Landing at the top of the ramp, level with the deck it feeds.
	_box(Vector3(9.9, DECK_Y - SLAB * 0.5, (RAMP_Z0 + RAMP_Z1) * 0.5), Vector3(5.8, SLAB, RAMP_Z1 - RAMP_Z0), _concrete, true)


func _build_upper() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	# Main deck stops where the ramp lane begins.
	var depth := RAMP_Z0 + hz
	_box(Vector3(0, DECK_Y - SLAB * 0.5, -hz + depth * 0.5), Vector3(W, SLAB, depth), _concrete, true)

	# Parapets. The south run leaves a gap at x 5..13 where the ramp arrives.
	_box(Vector3(0, DECK_Y + 0.55, -hz), Vector3(W, 1.1, 0.3), _concrete, true)
	_box(Vector3(-hx, DECK_Y + 0.55, -hz + depth * 0.5), Vector3(0.3, 1.1, depth), _concrete, true)
	var run := 18.0
	_box(Vector3(-hx + run * 0.5, DECK_Y + 0.55, RAMP_Z0), Vector3(run, 1.1, 0.3), _concrete, true)
	# Wrap the landing.
	_box(Vector3(hx, DECK_Y + 0.55, (RAMP_Z0 + RAMP_Z1) * 0.5), Vector3(0.3, 1.1, RAMP_Z1 - RAMP_Z0), _concrete, true)
	_box(Vector3(9.9, DECK_Y + 0.55, RAMP_Z1), Vector3(5.8, 1.1, 0.3), _concrete, true)

	_stalls(DECK_Y + 0.02, -7.6)


func _stalls(y: float, z_row: float) -> void:
	for stall in 6:
		var x := -10.5 + stall * 4.2
		_box(Vector3(x, y, z_row), Vector3(0.1, 0.02, 4.6), _paint, false)
	# Aisle centre line.
	_box(Vector3(0, y, -2.0), Vector3(W - 3.0, 0.02, 0.1), _paint, false)


func _tilted(centre: Vector3, size: Vector3, ang: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	body.rotation.z = ang
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


func _signage() -> void:
	var sign := Label3D.new()
	sign.text = "PARKING"
	sign.position = Vector3(-W * 0.5 - 0.6, DECK_Y + 1.9, -2.0)
	sign.font_size = 64
	sign.modulate = Color("ffb703")
	sign.outline_modulate = Color.BLACK
	sign.outline_size = 8
	sign.rotation_degrees.y = -90.0
	add_child(sign)

	var up := Label3D.new()
	up.text = "UPPER DECK  ↑"
	up.position = Vector3(-W * 0.5 - 0.6, 2.9, (RAMP_Z0 + RAMP_Z1) * 0.5)
	up.font_size = 40
	up.modulate = Color("f1faee")
	up.outline_modulate = Color.BLACK
	up.outline_size = 6
	up.rotation_degrees.y = -90.0
	add_child(up)

	var ground := Label3D.new()
	ground.text = "GROUND"
	ground.position = Vector3(-W * 0.5 - 0.6, 2.9, (GATE_Z0 + GATE_Z1) * 0.5)
	ground.font_size = 34
	ground.modulate = Color("f1faee")
	ground.outline_modulate = Color.BLACK
	ground.outline_size = 6
	ground.rotation_degrees.y = -90.0
	add_child(ground)

	for i in 3:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-8.0 + i * 8.0, CLEAR - 0.4, -2.0)
		lamp.light_energy = 1.6
		lamp.omni_range = 15.0
		lamp.light_color = Color("e8f0ff")
		add_child(lamp)
	var deck_lamp := OmniLight3D.new()
	deck_lamp.position = Vector3(0, DECK_Y + 3.0, -2.0)
	deck_lamp.light_energy = 1.2
	deck_lamp.omni_range = 20.0
	add_child(deck_lamp)


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
