extends Node3D

# North Point tower. Local space: origin at the building centre on the ground,
# west wall (the entrance) at x = -W/2. Three physical levels, labelled the way
# the elevator panel labels them.
#
# Stair shaft is a hole cut through every slab above the lobby, with switchback
# ramps inside it. Ramps, not steps: CharacterBody3D has no step climbing.

const W := 26.0
const D := 22.0
const T := 0.45
const SLAB := 0.4
const ROOF_Y := 16.4
const DOOR_W := 2.8
const DOOR_H := 2.7
const OPEN_RANGE := 5.0
const SLIDE_SPEED := 3.6

# Stair shaft footprint (local): x 5..13, z -11..-1
const STAIR_X0 := 5.0
const STAIR_X1 := 13.0
const STAIR_Z0 := -11.0
const STAIR_Z1 := -1.0
# Elevator core: x 9..13, z 5..11, doors on its west face.
const LIFT_X := 9.0
const LIFT_Z := 8.0

const FLOORS := [
	{"name": "LOBBY", "y": 0.2},
	{"name": "4TH FLOOR", "y": 5.6},
	{"name": "6TH FLOOR", "y": 11.0},
]

var _leaves: Array[AnimatableBody3D] = []
var _open: float = 0.0
var _shell: StandardMaterial3D
var _stone: StandardMaterial3D
var _curtain: StandardMaterial3D
var _spandrel: StandardMaterial3D
var _slabmat: StandardMaterial3D
var _glass: StandardMaterial3D
var _trim: StandardMaterial3D


func _ready() -> void:
	add_to_group("office")
	_make_mats()
	_build_shell()
	_build_entrance()
	_build_slabs()
	_build_stairs()
	_build_core()
	_fit_lobby()
	_fit_fourth()
	_fit_sixth()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var want := 0.0
	if player and not GameState.in_car:
		var door := global_position + Vector3(-W * 0.5, 0.0, 0.0)
		var flat := Vector2(door.x - player.global_position.x, door.z - player.global_position.z)
		want = 1.0 if flat.length() < OPEN_RANGE and player.global_position.y < 3.0 else 0.0
	_open = move_toward(_open, want, SLIDE_SPEED * delta)
	var shift := _open * (DOOR_W * 0.5 + 0.05)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		_leaves[i].position.z = side * (DOOR_W * 0.25 + shift)


func floor_y(index: int) -> float:
	return FLOORS[clampi(index, 0, FLOORS.size() - 1)].y


func floor_name(index: int) -> String:
	return FLOORS[clampi(index, 0, FLOORS.size() - 1)].name


func floor_count() -> int:
	return FLOORS.size()


## Where the elevator drops you off on a given floor, in world space.
func landing(index: int) -> Vector3:
	return global_position + Vector3(LIFT_X - 2.2, floor_y(index), LIFT_Z)


# ------------------------------------------------------------------ shell

func _make_mats() -> void:
	# Palette off the reference: warm grey-pink precast piers against a dark
	# blue-green reflective curtain wall.
	_shell = _mat(Color("a3928c"), 0.72)
	_stone = _mat(Color("b0a099"), 0.6)
	_curtain = _mat(Color("15343a"), 0.12, 0.75)
	_spandrel = _mat(Color("0e2429"), 0.2, 0.5)
	_slabmat = _mat(Color("4a4f57"), 0.85)
	_trim = _mat(Color("c9a227"), 0.35, 0.6)
	_glass = _mat(Color(0.42, 0.62, 0.78, 0.45), 0.06, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


## Clads one elevation. `ns` true means the face lies in the XY plane at
## z = out_v; false means the YZ plane at x = out_v.
## `door_half` reserves a gap of that half-width at u = 0 across the whole
## ground band, so nothing is drawn over the entrance.
func _clad(ns: bool, out_v: float, length: float, bays: int, storefront: bool, door_half: float = 0.0) -> void:
	var away := signf(out_v)
	var half := length * 0.5
	var step := length / float(bays)
	var sill := DOOR_H + 0.5

	# Recessed glass field behind the piers.
	if door_half <= 0.0:
		_face_box(ns, 0.0, ROOF_Y * 0.5 + 0.3, out_v + away * 0.02, length - 0.6, ROOF_Y - 0.6, 0.18, _curtain)
	else:
		# Above the entrance, then two flanking panels beside it.
		_face_box(ns, 0.0, (sill + ROOF_Y - 0.3) * 0.5, out_v + away * 0.02, length - 0.6, ROOF_Y - 0.3 - sill, 0.18, _curtain)
		var side := (half - 0.3 - door_half) * 0.5
		for dir in [-1.0, 1.0]:
			_face_box(ns, dir * (door_half + side), sill * 0.5, out_v + away * 0.02, side * 2.0, sill, 0.18, _curtain)

	# Precast piers, skipping any that would land across the doorway.
	for i in range(bays + 1):
		var u := -half + i * step
		if door_half > 0.0 and absf(u) < door_half + 0.75:
			_face_box(ns, u, (sill + ROOF_Y) * 0.5, out_v + away * 0.16, 1.5, ROOF_Y - sill, 0.34, _stone)
			continue
		_face_box(ns, u, ROOF_Y * 0.5, out_v + away * 0.16, 1.5, ROOF_Y, 0.34, _stone)

	# Spandrel band at each floor line, plus one at the parapet.
	for f in FLOORS:
		if door_half > 0.0 and f.y < sill:
			continue
		_face_box(ns, 0.0, f.y - 0.35, out_v + away * 0.1, length - 3.4, 0.9, 0.26, _spandrel)
	_face_box(ns, 0.0, ROOF_Y - 1.1, out_v + away * 0.1, length - 3.4, 0.9, 0.26, _spandrel)

	if door_half > 0.0:
		# Entrance surround so the way in reads at a glance.
		_face_box(ns, 0.0, sill + 0.25, out_v + away * 0.3, door_half * 2.0 + 1.2, 0.5, 0.5, _trim)
		for dir in [-1.0, 1.0]:
			_face_box(ns, dir * (door_half + 0.3), sill * 0.5, out_v + away * 0.3, 0.6, sill, 0.5, _trim)
		_face_box(ns, 0.0, sill + 1.1, out_v + away * 0.95, door_half * 2.0 + 2.2, 0.22, 1.9, _stone)

	if storefront:
		# Taller, clearer glazing at street level with a canopy over it.
		_face_box(ns, 0.0, 1.7, out_v + away * 0.22, length - 4.0, 3.2, 0.14, _glass)
		_face_box(ns, 0.0, 3.55, out_v + away * 0.75, length - 3.0, 0.22, 1.7, _stone)

	# Overhanging cornice, the flat cap in the photo.
	_face_box(ns, 0.0, ROOF_Y + 0.3, out_v + away * 0.5, length + 1.6, 0.7, 1.3, _stone)


func _face_box(ns: bool, u: float, y: float, out_v: float, su: float, sy: float, so: float, material: Material) -> void:
	if ns:
		_box(Vector3(u, y, out_v), Vector3(su, sy, so), material, false)
	else:
		_box(Vector3(out_v, y, u), Vector3(so, sy, su), material, false)


func _build_shell() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	# North / south / east walls run the full height.
	_box(Vector3(0, ROOF_Y * 0.5, -hz), Vector3(W, ROOF_Y, T), _shell, true)
	_box(Vector3(0, ROOF_Y * 0.5, hz), Vector3(W, ROOF_Y, T), _shell, true)
	_box(Vector3(hx, ROOF_Y * 0.5, 0), Vector3(T, ROOF_Y, D), _shell, true)
	# Roof.
	_box(Vector3(0, ROOF_Y + SLAB * 0.5, 0), Vector3(W + 0.8, SLAB, D + 0.8), _slabmat, true)
	# Ground slab.
	_box(Vector3(0, 0.1, 0), Vector3(W, 0.2, D), _slabmat, true)

	# Curtain wall. Decoration only — the structural walls above carry collision.
	_clad(true, -hz, W, 5, true)
	_clad(true, hz, W, 5, true)
	_clad(false, hx, D, 4, true)
	_clad(false, -hx, D, 4, false, DOOR_W * 0.5 + 0.35)

	# Louvred trellis over the north-west corner, as in the photo.
	for i in 7:
		_box(Vector3(-hx + 1.2 + i * 0.75, ROOF_Y + 1.5, -hz + 2.4), Vector3(0.12, 0.5, 5.4), _mat(Color("3c4247"), 0.6, 0.3), false)
	_box(Vector3(-hx + 3.4, ROOF_Y + 1.0, -hz + 2.4), Vector3(5.6, 0.18, 5.6), _mat(Color("3c4247"), 0.6, 0.3), false)
	for cx in [-hx + 0.9, -hx + 5.9]:
		for cz in [-hz + 0.2, -hz + 4.8]:
			_box(Vector3(cx, ROOF_Y + 0.7, cz), Vector3(0.22, 1.8, 0.22), _mat(Color("3c4247"), 0.6, 0.3), false)

	var sign := Label3D.new()
	sign.text = "NORTH POINT"
	sign.position = Vector3(-hx - 0.3, ROOF_Y - 1.6, 0)
	sign.font_size = 96
	sign.modulate = Color("ffb703")
	sign.outline_modulate = Color.BLACK
	sign.outline_size = 10
	sign.rotation_degrees.y = -90.0
	add_child(sign)


func _build_entrance() -> void:
	var west := -W * 0.5
	var hz := D * 0.5
	var gap := DOOR_W * 0.5
	var seg := hz - gap
	# Wall either side of the doorway, full height.
	_box(Vector3(west, ROOF_Y * 0.5, -(gap + hz) * 0.5), Vector3(T, ROOF_Y, seg), _shell, true)
	_box(Vector3(west, ROOF_Y * 0.5, (gap + hz) * 0.5), Vector3(T, ROOF_Y, seg), _shell, true)
	# Header over the doorway.
	_box(Vector3(west, (DOOR_H + ROOF_Y) * 0.5, 0), Vector3(T, ROOF_Y - DOOR_H, DOOR_W + 0.2), _shell, true)

	# Threshold ramp — the ground slab is 0.2 proud of the pavement.
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	ramp.position = Vector3(west - 0.3, 0.04, 0.0)
	ramp.rotation_degrees.z = 15.9
	var rsize := Vector3(0.78, 0.12, DOOR_W)
	var rcol := CollisionShape3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = rsize
	rcol.shape = rshape
	ramp.add_child(rcol)
	var rmi := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = rsize
	rmi.mesh = rbox
	rmi.material_override = _mat(Color("55606d"), 0.75)
	ramp.add_child(rmi)
	add_child(ramp)

	for i in 2:
		var leaf := AnimatableBody3D.new()
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position = Vector3(west, 0.2, 0.0)
		var size := Vector3(0.12, DOOR_H - 0.3, DOOR_W * 0.5)
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
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.16, size.y, 0.09)
		rail.mesh = rb
		rail.material_override = _trim
		rail.position = Vector3(0, size.y * 0.5, (DOOR_W * 0.25 - 0.05) * (-1.0 if i == 0 else 1.0))
		leaf.add_child(rail)
		add_child(leaf)
		_leaves.append(leaf)


func _build_slabs() -> void:
	# Every slab above the lobby is built as two boxes so the stair shaft stays open.
	for i in range(1, FLOORS.size()):
		var top: float = FLOORS[i].y
		var cy := top - SLAB * 0.5
		var west_w := STAIR_X0 + W * 0.5
		_box(Vector3(-W * 0.5 + west_w * 0.5, cy, 0), Vector3(west_w, SLAB, D), _slabmat, true)
		var east_d := D * 0.5 - STAIR_Z1
		_box(Vector3((STAIR_X0 + STAIR_X1) * 0.5, cy, STAIR_Z1 + east_d * 0.5), Vector3(STAIR_X1 - STAIR_X0, SLAB, east_d), _slabmat, true)
		# Railing along the open edge of the shaft.
		_box(Vector3(STAIR_X0, top + 0.5, (STAIR_Z0 + STAIR_Z1) * 0.5), Vector3(0.12, 1.0, STAIR_Z1 - STAIR_Z0), _trim, true)

		var label := Label3D.new()
		label.text = FLOORS[i].name
		label.position = Vector3(-W * 0.5 + 1.2, top + 3.0, 0)
		label.font_size = 64
		label.modulate = Color("ffb703")
		label.outline_modulate = Color.BLACK
		label.outline_size = 8
		label.rotation_degrees.y = -90.0
		add_child(label)

	var lobby_label := Label3D.new()
	lobby_label.text = "LOBBY"
	lobby_label.position = Vector3(-W * 0.5 + 1.2, 3.6, 0)
	lobby_label.font_size = 64
	lobby_label.modulate = Color("ffb703")
	lobby_label.outline_modulate = Color.BLACK
	lobby_label.outline_size = 8
	lobby_label.rotation_degrees.y = -90.0
	add_child(lobby_label)


func _build_stairs() -> void:
	var stone := _mat(Color("6d737c"), 0.8)
	for i in range(FLOORS.size() - 1):
		var base: float = FLOORS[i].y
		var top: float = FLOORS[i + 1].y
		var mid := (base + top) * 0.5
		# Up the west lane going -z, landing, then back down the east lane going +z.
		_ramp(6.8, 2.6, STAIR_Z1, -8.8, base, mid, stone)
		_box(Vector3(9.0, mid - SLAB * 0.5, -9.6), Vector3(7.6, SLAB, 1.8), stone, true)
		_ramp(11.2, 2.6, -8.8, STAIR_Z1, mid, top, stone)


func _build_core() -> void:
	var core := _mat(Color("3c424b"), 0.6, 0.25)
	var hz := D * 0.5
	# Solid shaft from ground to roof.
	_box(Vector3((LIFT_X + STAIR_X1) * 0.5, ROOF_Y * 0.5, (5.0 + hz) * 0.5), Vector3(STAIR_X1 - LIFT_X, ROOF_Y, hz - 5.0), core, true)

	for i in FLOORS.size():
		var y: float = FLOORS[i].y
		# Door face + call panel on every floor.
		_box(Vector3(LIFT_X - 0.06, y + 1.35, LIFT_Z), Vector3(0.1, 2.7, 2.2), _trim, false)
		_box(Vector3(LIFT_X - 0.09, y + 1.35, LIFT_Z), Vector3(0.06, 2.5, 2.0), _mat(Color("11161c"), 0.3), false)

		var panel := Node3D.new()
		panel.name = "ElevatorPanel%d" % i
		panel.position = Vector3(LIFT_X - 1.4, y, LIFT_Z)
		panel.add_to_group("elevator")
		panel.set_script(load("res://scripts/office/elevator_panel.gd"))
		add_child(panel)
		panel.setup(self, i)

		var tag := Label3D.new()
		tag.text = FLOORS[i].name
		tag.position = Vector3(LIFT_X - 0.2, y + 3.0, LIFT_Z)
		tag.font_size = 30
		tag.modulate = Color("f1faee")
		tag.outline_modulate = Color.BLACK
		tag.outline_size = 6
		tag.rotation_degrees.y = -90.0
		add_child(tag)

		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-2.0, y + 4.2, 0)
		lamp.light_energy = 2.0
		lamp.omni_range = 22.0
		lamp.light_color = Color("fff4dd")
		add_child(lamp)


# ------------------------------------------------------------------ fit-out

func _fit_lobby() -> void:
	var y: float = FLOORS[0].y
	var wood := _mat(Color("6b4a2f"), 0.6)
	var stone := _mat(Color("d8dbe0"), 0.5)
	var couch := _mat(Color("2f4858"), 0.75)

	# Reception desk facing the doors.
	_box(Vector3(-6.0, y + 0.55, 0), Vector3(1.0, 1.1, 5.0), wood, true)
	_box(Vector3(-6.0, y + 1.14, 0), Vector3(1.4, 0.08, 5.4), stone, true)

	# Waiting area.
	_box(Vector3(-9.5, y + 0.22, -5.0), Vector3(1.0, 0.44, 3.2), couch, true)
	_box(Vector3(-10.0, y + 0.62, -5.0), Vector3(0.2, 0.8, 3.2), couch, true)
	_box(Vector3(-9.5, y + 0.22, 5.0), Vector3(1.0, 0.44, 3.2), couch, true)
	_box(Vector3(-10.0, y + 0.62, 5.0), Vector3(0.2, 0.8, 3.2), couch, true)
	_box(Vector3(-6.5, y + 0.2, -5.0), Vector3(1.0, 0.4, 1.0), stone, true)

	for pz in [-9.0, 9.0]:
		_box(Vector3(-11.5, y + 0.25, pz), Vector3(0.6, 0.5, 0.6), _mat(Color("8a5a44"), 0.8), true)
		_box(Vector3(-11.5, y + 1.1, pz), Vector3(0.8, 1.2, 0.8), _mat(Color("2f6d34"), 0.9), false)

	var dir := Label3D.new()
	dir.text = "LOBBY\n4TH — OPERATIONS\n6TH — SALES FLOOR"
	dir.position = Vector3(-5.2, y + 2.6, 0)
	dir.font_size = 40
	dir.modulate = Color("ffb703")
	dir.outline_modulate = Color.BLACK
	dir.outline_size = 6
	dir.rotation_degrees.y = -90.0
	add_child(dir)

	_npc({
		"name": "Myriam — Front Desk",
		"pos": Vector3(-4.8, y, 0),
		"shirt": Color("8c2f47"),
		"hair": Color("14100f"),
		"lines": [
			"Well. Look who finally walked in. Sales is on six — but you knew that.",
			"You clean up nice for someone who was in his underwear last week.",
			"I'll buzz you up. Not because I have to. Because I like you.",
			"If Ralph asks, you were here at nine. That's between us.",
			"Six. Go on. I'll still be here when you come back down.",
		],
	})


func _fit_fourth() -> void:
	var y: float = FLOORS[1].y
	var part := _mat(Color("9aa3ad"), 0.8)
	var wood := _mat(Color("6b4a2f"), 0.6)

	# Cubicle farm. Everything here stays west of the stair shaft (x < 5).
	for cx in [-10.0, -5.0, 0.0]:
		for cz in [0.0, 6.0]:
			_box(Vector3(cx, y + 0.75, cz), Vector3(2.6, 0.06, 1.4), wood, true)
			_box(Vector3(cx, y + 0.6, cz - 1.0), Vector3(2.8, 1.2, 0.1), part, true)
			_box(Vector3(cx - 1.4, y + 0.6, cz), Vector3(0.1, 1.2, 2.0), part, true)

	# Meeting room in the north-west corner, clear of the shaft.
	_box(Vector3(-3.0, y + 1.4, -8.0), Vector3(0.14, 2.8, 6.0), _glass, true)
	_box(Vector3(-8.0, y + 1.4, -5.0), Vector3(10.0, 2.8, 0.14), _glass, true)
	_box(Vector3(-8.0, y + 0.79, -8.0), Vector3(4.0, 0.08, 2.0), wood, true)

	var tag := Label3D.new()
	tag.text = "OPERATIONS"
	tag.position = Vector3(-12.4, y + 3.4, 0)
	tag.font_size = 48
	tag.modulate = Color("9aa4b2")
	tag.rotation_degrees.y = -90.0
	add_child(tag)

	for spec in [
		{
			"name": "Porter — Systems",
			"pos": Vector3(-9.4, y, 3.0),
			"shirt": Color("46506b"),
			"hair": Color("6b4f2a"),
			"glasses": true,
			"lines": [
				"Mm. Kind of in the middle of something.",
				"You want six. This is four. Those are different numbers.",
				"I'd explain but you'd need a lot of context.",
			],
		},
		{
			"name": "Collin — Data",
			"pos": Vector3(-4.6, y, 6.4),
			"shirt": Color("3f6b52"),
			"hair": Color("c96a2a"),
			"glasses": true,
			"lines": [
				"Yeah, no, I'm heads-down right now.",
				"Did Porter send you? Porter sends everyone.",
				"I saw your pipeline. No notes. Well — some notes.",
			],
		},
		{
			"name": "Wei — Infrastructure",
			"pos": Vector3(0.4, y, 3.0),
			"shirt": Color("55606d"),
			"skin": Color("e8c9a0"),
			"hair": Color("100d0c"),
			"glasses": true,
			"lines": [
				"Busy. Prod's on fire. Always is.",
				"You're the sales guy. Sales guys break things and leave.",
				"Ask me again after the deploy. Don't, actually.",
			],
		},
	]:
		_npc(spec)


func _fit_sixth() -> void:
	var y: float = FLOORS[2].y
	var wood := _mat(Color("6b4a2f"), 0.6)
	var grey := _mat(Color("3f4650"), 0.55)
	var screen := _mat(Color("101820"), 0.25)
	screen.emission_enabled = true
	screen.emission = Color("2a6df4")
	screen.emission_energy_multiplier = 1.4
	var plant := _mat(Color("2f6d34"), 0.9)

	_desk(Vector3(-9.0, y, -5.0), wood, screen, true)
	_desk(Vector3(-9.0, y, 0.0), wood, screen, false)
	_desk(Vector3(-9.0, y, 5.0), wood, screen, false)
	_desk(Vector3(-3.0, y, -5.0), wood, screen, false)
	_desk(Vector3(-3.0, y, 5.0), wood, screen, false)

	# Break corner.
	_box(Vector3(2.0, y + 0.77, 8.0), Vector3(1.2, 0.06, 1.2), grey, true)
	_box(Vector3(2.0, y + 0.4, 8.0), Vector3(0.16, 0.72, 0.16), grey, true)
	_box(Vector3(3.6, y + 0.85, 8.0), Vector3(0.42, 1.3, 0.42), _mat(Color("dfe7ee"), 0.4), true)
	for pz in [9.5, -9.5]:
		_box(Vector3(-11.8, y + 0.25, pz), Vector3(0.6, 0.5, 0.6), _mat(Color("8a5a44"), 0.8), true)
		_box(Vector3(-11.8, y + 1.1, pz), Vector3(0.8, 1.2, 0.8), plant, false)

	# Printer / copier bay.
	_box(Vector3(-11.6, y + 0.55, -2.0), Vector3(0.9, 1.1, 1.4), _mat(Color("32373d"), 0.5), true)
	_box(Vector3(-11.6, y + 1.16, -2.0), Vector3(0.95, 0.12, 1.45), _mat(Color("1b1f24"), 0.4), false)
	# Filing cabinets along the back wall.
	for fz in [-8.4, -7.0, 6.4, 7.8]:
		_box(Vector3(-12.0, y + 0.62, fz), Vector3(0.7, 1.24, 1.1), _mat(Color("6a7078"), 0.5, 0.2), true)
	# Coffee machine and mugs by the break table.
	_box(Vector3(3.6, y + 1.05, 8.0), Vector3(0.5, 0.4, 0.45), _mat(Color("22262c"), 0.4), false)
	# Standing whiteboard by the desks.
	_box(Vector3(-6.0, y + 1.5, -9.0), Vector3(3.0, 1.4, 0.08), _mat(Color("f4f7fa"), 0.4), true)
	_box(Vector3(-6.0, y + 0.4, -9.0), Vector3(0.1, 0.8, 0.1), _mat(Color("42484f"), 0.5), false)

	_box(Vector3(0.0, y + 2.2, -10.6), Vector3(4.4, 1.6, 0.1), _mat(Color("f4f7fa"), 0.4), true)
	var board := Label3D.new()
	board.text = "Q3 QUOTA\n%d DEALS" % GameState.SALES_QUOTA
	board.position = Vector3(0.0, y + 2.2, -10.5)
	board.font_size = 40
	board.modulate = Color("1d3557")
	add_child(board)

	var tag := Label3D.new()
	tag.text = "SALES FLOOR"
	tag.position = Vector3(-12.4, y + 3.4, 0)
	tag.font_size = 48
	tag.modulate = Color("ffb703")
	tag.rotation_degrees.y = -90.0
	add_child(tag)

	for spec in [
		{
			"name": "Ralph — Floor Manager",
			"pos": Vector3(2.0, y, -6.0),
			"shirt": Color("7b2d3b"),
			"lines": [
				"Quota is %d closed deals. Sit down and dial." % GameState.SALES_QUOTA,
				"Cold calls beat emails. Emails just keep you warm.",
				"Don't pitch before you've asked them a question. They hang up.",
			],
		},
		{
			"name": "Ayden — Senior SDR",
			"pos": Vector3(-6.2, y, 0.0),
			"shirt": Color("1d3557"),
			"hair": Color("0d0b0a"),
			"lines": [
				"Order matters: rapport, then a question, then the pitch, then ask for it.",
				"If a lead goes cold, email them a couple times before you call again.",
				"I closed Brightline on a Tuesday. Never doubt a Tuesday.",
			],
		},
		{
			"name": "Tyler — Sales Ops",
			"pos": Vector3(2.0, y, 6.0),
			"shirt": Color("9c5f45"),
			"hat": "cowboy",
			"hair": Color("5b4432"),
			"lines": [
				"Convert the lead 'fore you try to close it. Button's right there, son.",
				"Probability isn't the stage. You can be at Negotiation and still be at thirty percent.",
				"I tidy the pipeline every Friday. Don't make Friday worse, partner.",
			],
		},
		{
			"name": "Fiona — SDR",
			"pos": Vector3(-6.2, y, 5.0),
			"shirt": Color("2a9d8f"),
			"hair": Color("e0c169"),
			"lines": [
				"Don't spam one lead with email. After about three they stop reading.",
				"Closing under seventy percent is a coin flip. I've lost good leads that way.",
				"Coffee's by the window. It's not good, but it's there.",
			],
		},
	]:
		_npc(spec)


func _desk(at: Vector3, wood: Material, screen: Material, is_jacobs: bool) -> void:
	_box(at + Vector3(0, 0.76, 0), Vector3(2.4, 0.08, 1.2), wood, true)
	_box(at + Vector3(-1.1, 0.4, 0), Vector3(0.1, 0.72, 1.1), wood, true)
	_box(at + Vector3(1.1, 0.4, 0), Vector3(0.1, 0.72, 1.1), wood, true)
	_box(at + Vector3(0.2, 0.9, 0), Vector3(0.1, 0.2, 0.4), _mat(Color("22262c"), 0.5), false)
	_box(at + Vector3(0.2, 1.2, 0), Vector3(0.06, 0.5, 0.86), screen, false)
	_box(at + Vector3(-0.95, 0.48, 0), Vector3(0.55, 0.08, 0.55), _mat(Color("2b3038"), 0.7), true)
	_box(at + Vector3(-1.2, 0.82, 0), Vector3(0.08, 0.6, 0.55), _mat(Color("2b3038"), 0.7), true)

	if not is_jacobs:
		return
	var marker := Node3D.new()
	marker.name = "SalesTerminal"
	marker.position = at + Vector3(-0.9, 0, 0)
	marker.add_to_group("sales_terminal")
	marker.set_script(load("res://scripts/office/sales_terminal.gd"))
	add_child(marker)

	var tag := Label3D.new()
	tag.text = "YOUR DESK"
	tag.position = at + Vector3(0.2, 1.8, 0)
	tag.font_size = 30
	tag.modulate = Color("ffb703")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)


func _npc(spec: Dictionary) -> void:
	var npc := StaticBody3D.new()
	npc.collision_layer = 1
	npc.collision_mask = 0
	npc.position = spec.pos
	npc.add_to_group("office_npc")
	npc.set_script(load("res://scripts/office/office_npc.gd"))
	add_child(npc)
	npc.setup(spec)


# ------------------------------------------------------------------ helpers

func _ramp(x_centre: float, width: float, z_from: float, z_to: float, y_from: float, y_to: float, material: Material) -> void:
	var run := absf(z_to - z_from)
	var rise := absf(y_to - y_from)
	var length := sqrt(run * run + rise * rise)
	# Keep |ang| under 90 so the slab never flips: work out the slope magnitude,
	# then pick the sign from which way the ramp actually climbs. Rx(-slope)
	# sends local +Z upward, Rx(+slope) sends it downward.
	var slope := atan2(rise, run)
	var climbs_with_z := (z_to > z_from) == (y_to > y_from)
	var ang := -slope if climbs_with_z else slope
	var thick := 0.35
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
