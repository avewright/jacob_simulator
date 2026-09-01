extends Node3D

# Two-deck garage you drive into. Local space: origin at the centre on the
# ground, entrance on the west face. The upper deck stops short of the north
# strip so the drive-up ramp has somewhere to climb.

const W := 26.0
const D := 18.0
const DECK_Y := 4.2
const SLAB := 0.4
const CLEAR := DECK_Y - SLAB      # headroom on the ground deck
# Upper deck covers z -9..4; the ramp climbs through the z 4..8 strip.
const DECK_Z1 := 4.4      # flush with RAMP_Z0 — no lip to catch a wheel
const RAMP_Z0 := 4.4
const RAMP_Z1 := 8.4
const RAMP_X0 := -11.0
const RAMP_X1 := 11.0

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
	# Ground pad, 0.15 proud, with a ramped lip at the entrance.
	_box(Vector3(0, 0.075, 0), Vector3(W, 0.15, D), _concrete, true)
	_lip(Vector3(-hx - 0.35, 0.02, 0.0), 6.0)

	# Perimeter: solid on three sides, west face open in the middle for the entry.
	_box(Vector3(0, CLEAR * 0.5, -hz), Vector3(W, CLEAR, 0.4), _concrete, true)
	_box(Vector3(0, CLEAR * 0.5, hz), Vector3(W, CLEAR, 0.4), _concrete, true)
	_box(Vector3(hx, CLEAR * 0.5, 0), Vector3(0.4, CLEAR, D), _concrete, true)
	var entry_half := 3.0
	var seg := (hz - entry_half) * 0.5
	_box(Vector3(-hx, CLEAR * 0.5, -(hz + entry_half) * 0.5), Vector3(0.4, CLEAR, seg * 2.0), _concrete, true)
	_box(Vector3(-hx, CLEAR * 0.5, (hz + entry_half) * 0.5), Vector3(0.4, CLEAR, seg * 2.0), _concrete, true)

	# Columns.
	for cx in [-8.0, 0.0, 8.0]:
		for cz in [-6.5, 0.0]:
			_box(Vector3(cx, CLEAR * 0.5, cz), Vector3(0.6, CLEAR, 0.6), _concrete, true)

	_stalls(0.16)


func _build_ramp() -> void:
	var run := RAMP_X1 - RAMP_X0
	var rise := DECK_Y - 0.15
	var length := sqrt(run * run + rise * rise)
	var ang := atan2(rise, run)
	var thick := 0.4
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3((RAMP_X0 + RAMP_X1) * 0.5, (0.15 + DECK_Y) * 0.5 - thick * 0.5 * cos(ang), (RAMP_Z0 + RAMP_Z1) * 0.5)
	# Rz(+a) tilts local +X upward, so the far (east) end is the top.
	body.rotation.z = ang
	var size := Vector3(length, thick, RAMP_Z1 - RAMP_Z0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(Color("8b8e90"), 0.92)
	body.add_child(mi)
	add_child(body)

	# Kerbs down both sides of the ramp so you cannot drop off it.
	for side in [RAMP_Z0 - 0.3, RAMP_Z1 + 0.3]:
		var k := StaticBody3D.new()
		k.collision_layer = 1
		k.collision_mask = 0
		k.position = Vector3((RAMP_X0 + RAMP_X1) * 0.5, (0.15 + DECK_Y) * 0.5 + 0.35, side)
		k.rotation.z = ang
		var ksize := Vector3(length, 0.5, 0.3)
		var kcol := CollisionShape3D.new()
		var kshape := BoxShape3D.new()
		kshape.size = ksize
		kcol.shape = kshape
		k.add_child(kcol)
		var kmi := MeshInstance3D.new()
		var kbox := BoxMesh.new()
		kbox.size = ksize
		kmi.mesh = kbox
		kmi.material_override = _kerb
		k.add_child(kmi)
		add_child(k)


func _build_upper() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	var depth := DECK_Z1 + hz
	_box(Vector3(0, DECK_Y - SLAB * 0.5, -hz + depth * 0.5), Vector3(W, SLAB, depth), _concrete, true)
	# Parapet around the open deck, with a gap where the ramp arrives.
	_box(Vector3(0, DECK_Y + 0.5, -hz), Vector3(W, 1.0, 0.3), _concrete, true)
	_box(Vector3(-hx, DECK_Y + 0.5, -hz + depth * 0.5), Vector3(0.3, 1.0, depth), _concrete, true)
	_box(Vector3(hx, DECK_Y + 0.5, -hz + depth * 0.5), Vector3(0.3, 1.0, depth), _concrete, true)
	_box(Vector3(0, DECK_Y + 0.5, DECK_Z1), Vector3(W - 8.0, 1.0, 0.3), _concrete, true)
	_stalls(DECK_Y + 0.01)


func _stalls(y: float) -> void:
	for row in 2:
		for stall in 5:
			var z := -7.5 + row * 5.4
			var x := -9.0 + stall * 4.5
			_box(Vector3(x, y, z), Vector3(0.1, 0.02, 4.6), _paint, false)


func _lip(at: Vector3, width: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	body.rotation_degrees.z = 12.0
	var size := Vector3(0.8, 0.12, width)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _concrete
	body.add_child(mi)
	add_child(body)


func _signage() -> void:
	var sign := Label3D.new()
	sign.text = "PARKING\nP"
	sign.position = Vector3(-W * 0.5 - 0.6, DECK_Y + 1.8, 0)
	sign.font_size = 72
	sign.modulate = Color("ffb703")
	sign.outline_modulate = Color.BLACK
	sign.outline_size = 8
	sign.rotation_degrees.y = -90.0
	add_child(sign)

	var up := Label3D.new()
	up.text = "UPPER DECK  ↑"
	up.position = Vector3(0, 2.4, RAMP_Z1 - 1.0)
	up.font_size = 34
	up.modulate = Color("f1faee")
	up.outline_modulate = Color.BLACK
	up.outline_size = 6
	up.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(up)

	for i in 3:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-8.0 + i * 8.0, CLEAR - 0.4, 0)
		lamp.light_energy = 1.5
		lamp.omni_range = 14.0
		lamp.light_color = Color("e8f0ff")
		add_child(lamp)


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
