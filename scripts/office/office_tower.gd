extends Node3D

# 10000 Building, Avalon — Kahua's offices. Local space: origin at the building
# centre on the ground, west wall (the entrance) at x = -W/2. Three physical
# levels, labelled the way the elevator panel labels them.
#
# Stair shaft is a hole cut through every slab above the lobby, with switchback
# ramps inside it. Ramps, not steps: CharacterBody3D has no step climbing.

const W := 26.0
const D := 22.0
const T := 0.45
const SLAB := 0.4
const ROOF_Y := 27.0
const BASE_Y := 4.6        # storefront band height
const BAND := 2.85         # apparent floor-to-floor on the facade
const DOOR_W := 2.8
const DOOR_H := 2.7
const OPEN_RANGE := 5.0
const SLIDE_SPEED := 3.6

# Stair shaft footprint (local): x 5..13, z -11..-1
const STAIR_X0 := 5.0
const STAIR_X1 := 13.0
const STAIR_Z0 := -11.0
const STAIR_Z1 := -4.2      # hole edge; z -4.2..-2.6 is the landing inside
const DOOR_Z := -2.6        # stairwell wall line
const SD_W := 2.2           # stairwell door width
# Elevator core: x 9..13, z 5..11, doors on its west face.
const LIFT_X := 9.0
const LIFT_Z := 8.0

const FLOORS := [
	{"name": "LOBBY", "y": 0.2},
	{"name": "4TH FLOOR", "y": 5.6},
	{"name": "6TH FLOOR", "y": 11.0},
]

var _leaves: Array[AnimatableBody3D] = []
var _stair_doors: Array = []      # [{leaf, y, shut_x}]
var _open: float = 0.0
var _shell: StandardMaterial3D
var _stone: StandardMaterial3D
var _curtain: StandardMaterial3D
var _spandrel: StandardMaterial3D
var _mullion: StandardMaterial3D
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
	_build_stairwell()
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

	# Stairwell doors open for whoever is on that floor and close behind them.
	for door in _stair_doors:
		var leaf: AnimatableBody3D = door.leaf
		var near := 0.0
		if player and not GameState.in_car:
			var here := to_local(player.global_position)
			if absf(here.y - float(door.y)) < 2.6 and Vector2(here.x - float(door.shut_x), here.z - DOOR_Z).length() < 3.4:
				near = 1.0
		var want_x: float = float(door.shut_x) + near * (SD_W - 0.12)
		leaf.position.x = move_toward(leaf.position.x, want_x, (SD_W + 0.4) * delta)


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
	_stone = _mat(Color("b09a92"), 0.65)
	_curtain = _mat(Color("16383f"), 0.1, 0.8)
	_spandrel = _mat(Color("0e2429"), 0.2, 0.5)
	_mullion = _mat(Color("6f7a80"), 0.4, 0.5)
	_slabmat = _mat(Color("4a4f57"), 0.85)
	_trim = _mat(Color("c9a227"), 0.35, 0.6)
	_glass = _mat(Color(0.42, 0.62, 0.78, 0.45), 0.06, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


## Clads one elevation. `ns` true means the face lies in the XY plane at
## z = out_v; false means the YZ plane at x = out_v.
## Clads one elevation the way the reference reads: alternating bays of warm
## precast with punched windows and recessed blue-green curtain wall, over a
## clear storefront base, under a projecting cornice.
##
## `door_half` reserves a gap at u = 0 across the base so nothing covers the way
## in. `ns` true means the face lies in the XY plane at z = out_v.
func _clad(ns: bool, out_v: float, length: float, bays: int, storefront: bool, door_half: float = 0.0) -> void:
	var away := signf(out_v)
	var half := length * 0.5
	var step := length / float(bays)
	var top := ROOF_Y - 0.6

	for i in bays:
		var u := -half + step * (i + 0.5)
		var w := step - 0.9
		# Alternate: stone bays carry punched windows, glass bays are recessed.
		if i % 2 == 0:
			_face_box(ns, u, (BASE_Y + top) * 0.5, out_v + away * 0.12, w, top - BASE_Y, 0.26, _stone)
			_punch(ns, u, w, out_v + away * 0.27)
		else:
			_face_box(ns, u, (BASE_Y + top) * 0.5, out_v + away * 0.02, w, top - BASE_Y, 0.16, _curtain)
			var rows := int((top - BASE_Y) / BAND)
			for r in range(1, rows + 1):
				_face_box(ns, u, BASE_Y + r * BAND, out_v + away * 0.1, w, 0.16, 0.2, _mullion)

	# Precast piers between the bays, running the full height.
	for i in range(bays + 1):
		var u := -half + i * step
		if door_half > 0.0 and absf(u) < door_half + 0.8:
			_face_box(ns, u, (BASE_Y + ROOF_Y) * 0.5, out_v + away * 0.22, 1.3, ROOF_Y - BASE_Y, 0.4, _stone)
			continue
		_face_box(ns, u, ROOF_Y * 0.5, out_v + away * 0.22, 1.3, ROOF_Y, 0.4, _stone)

	# Storefront base: taller, clearer glazing with a stone sill and a canopy.
	if door_half > 0.0:
		var side := (half - 0.7 - door_half) * 0.5
		for dir in [-1.0, 1.0]:
			_face_box(ns, dir * (door_half + side), BASE_Y * 0.5 + 0.1, out_v + away * 0.06, side * 2.0, BASE_Y - 0.2, 0.2, _glass)
		# Surround and canopy over the entrance.
		_face_box(ns, 0.0, DOOR_H + 0.35, out_v + away * 0.3, door_half * 2.0 + 1.4, 0.6, 0.6, _trim)
		for dir in [-1.0, 1.0]:
			_face_box(ns, dir * (door_half + 0.35), DOOR_H * 0.5, out_v + away * 0.3, 0.7, DOOR_H, 0.6, _trim)
		_face_box(ns, 0.0, DOOR_H + 1.3, out_v + away * 1.0, door_half * 2.0 + 3.0, 0.25, 2.2, _stone)
	elif storefront:
		_face_box(ns, 0.0, BASE_Y * 0.5 + 0.1, out_v + away * 0.06, length - 3.0, BASE_Y - 0.2, 0.2, _glass)
		_face_box(ns, 0.0, BASE_Y + 0.45, out_v + away * 0.5, length - 1.0, 0.35, 1.3, _stone)

	# Spandrel band capping the base, and the cornice.
	_face_box(ns, 0.0, BASE_Y - 0.15, out_v + away * 0.16, length - 1.0, 0.5, 0.3, _spandrel)
	_face_box(ns, 0.0, top + 0.5, out_v + away * 0.16, length - 1.0, 0.7, 0.3, _spandrel)
	_face_box(ns, 0.0, ROOF_Y + 0.45, out_v + away * 0.6, length + 2.0, 0.9, 1.5, _stone)


## Grid of punched windows across a precast bay.
func _punch(ns: bool, u: float, w: float, out_v: float) -> void:
	var cols := maxi(1, int(w / 2.1))
	var rows := int((ROOF_Y - 0.6 - BASE_Y) / BAND)
	var gap := w / float(cols)
	for r in range(rows):
		var y := BASE_Y + 0.9 + r * BAND
		if y + 1.5 > ROOF_Y - 0.6:
			break
		for c in range(cols):
			var cu := u - w * 0.5 + gap * (c + 0.5)
			_face_box(ns, cu, y + 0.75, out_v, 1.15, 1.5, 0.1, _curtain)
			_face_box(ns, cu, y + 1.6, out_v + 0.02, 1.35, 0.12, 0.14, _trim)


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
	_clad(false, hx, D, 5, true)
	_clad(false, -hx, D, 5, false, DOOR_W * 0.5 + 0.35)

	# Louvred trellis over the north-west corner, as in the photo.
	for i in 7:
		_box(Vector3(-hx + 1.2 + i * 0.75, ROOF_Y + 1.5, -hz + 2.4), Vector3(0.12, 0.5, 5.4), _mat(Color("3c4247"), 0.6, 0.3), false)
	_box(Vector3(-hx + 3.4, ROOF_Y + 1.0, -hz + 2.4), Vector3(5.6, 0.18, 5.6), _mat(Color("3c4247"), 0.6, 0.3), false)
	for cx in [-hx + 0.9, -hx + 5.9]:
		for cz in [-hz + 0.2, -hz + 4.8]:
			_box(Vector3(cx, ROOF_Y + 0.7, cz), Vector3(0.22, 1.8, 0.22), _mat(Color("3c4247"), 0.6, 0.3), false)

	# Clear of the cladding: piers reach x = hx + 0.33 and the cornice
	# x = hx + 1.15, so anything closer than that renders half-buried.
	var sign := Label3D.new()
	sign.text = "10000 AVALON"
	sign.position = Vector3(-hx - 1.9, ROOF_Y - 3.4, 0)
	sign.font_size = 72
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

		var label := Label3D.new()
		label.text = FLOORS[i].name
		label.position = Vector3(-W * 0.5 + 1.2, top + 3.0, 0)
		label.font_size = 64
		label.modulate = Color("ffb703")
		label.outline_modulate = Color.BLACK
		label.outline_size = 8
		label.rotation_degrees.y = -90.0
		add_child(label)

	var tenant := Label3D.new()
	tenant.text = "KAHUA"
	tenant.position = Vector3(-W * 0.5 - 1.6, DOOR_H + 1.9, 0.0)
	tenant.font_size = 56
	tenant.modulate = Color("f1faee")
	tenant.outline_modulate = Color.BLACK
	tenant.outline_size = 8
	tenant.rotation_degrees.y = -90.0
	add_child(tenant)

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
		_ramp(6.8, 2.6, STAIR_Z1, -9.8, base, mid, stone)
		_box(Vector3(9.0, mid - SLAB * 0.5, -10.35), Vector3(7.6, SLAB, 1.5), stone, true)
		_ramp(11.2, 2.6, -9.8, STAIR_Z1, mid, top, stone)
		# Handrails down both flights and round the half landing.
		for lane in [[6.8, STAIR_Z1, -9.8, base, mid], [11.2, -9.8, STAIR_Z1, mid, top]]:
			for side in [-1.45, 1.45]:
				_rail(float(lane[0]) + side, float(lane[1]), float(lane[2]), float(lane[3]) + 0.95, float(lane[4]) + 0.95, stone)
		_box(Vector3(9.0, mid + 0.95, -10.95), Vector3(7.6, 0.08, 0.08), _trim, false)


## Concrete enclosure round the stair shaft, with a door onto each floor.
func _build_stairwell() -> void:
	var wall := _mat(Color("7e8388"), 0.9)
	var frame := _mat(Color("b7bcc0"), 0.5, 0.25)
	var leaf_mat := _mat(Color("55606d"), 0.55, 0.2)

	for i in FLOORS.size():
		var y: float = FLOORS[i].y
		var h := 4.9
		# West wall, keeping you from stepping into the shaft off the floor.
		_box(Vector3(STAIR_X0, y + h * 0.5, (STAIR_Z0 + STAIR_Z1) * 0.5),
			Vector3(0.25, h, STAIR_Z1 - STAIR_Z0), wall, true)
		# Wall onto the floor, split for the doorway.
		var gap_lo := 8.0
		var gap_hi := gap_lo + SD_W
		_box(Vector3((STAIR_X0 + gap_lo) * 0.5, y + h * 0.5, DOOR_Z),
			Vector3(gap_lo - STAIR_X0, h, 0.25), wall, true)
		_box(Vector3((gap_hi + STAIR_X1) * 0.5, y + h * 0.5, DOOR_Z),
			Vector3(STAIR_X1 - gap_hi, h, 0.25), wall, true)
		_box(Vector3((gap_lo + gap_hi) * 0.5, y + DOOR_H + (h - DOOR_H) * 0.5, DOOR_Z),
			Vector3(SD_W, h - DOOR_H, 0.25), wall, true)

		# Frame, sign, and a leaf that slides aside as you walk up.
		for fx in [gap_lo - 0.09, gap_hi + 0.09]:
			_box(Vector3(fx, y + DOOR_H * 0.5, DOOR_Z), Vector3(0.18, DOOR_H + 0.2, 0.34), frame, false)
		_box(Vector3((gap_lo + gap_hi) * 0.5, y + DOOR_H + 0.09, DOOR_Z), Vector3(SD_W + 0.36, 0.18, 0.34), frame, false)

		var shut_x: float = (gap_lo + gap_hi) * 0.5
		var leaf := AnimatableBody3D.new()
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position = Vector3(shut_x, y + DOOR_H * 0.5, DOOR_Z)
		var size := Vector3(SD_W - 0.06, DOOR_H - 0.06, 0.1)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		leaf.add_child(col)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
		mi.material_override = leaf_mat
		leaf.add_child(mi)
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(SD_W - 0.5, 0.08, 0.08)
		bar.mesh = bb
		bar.material_override = frame
		bar.position = Vector3(0, -0.1, -0.09)
		leaf.add_child(bar)
		add_child(leaf)
		_stair_doors.append({"leaf": leaf, "y": y, "shut_x": shut_x})

		var sign := Label3D.new()
		sign.text = "STAIRS"
		sign.position = Vector3(shut_x, y + DOOR_H + 0.45, DOOR_Z + 0.25)
		sign.font_size = 22
		sign.modulate = Color("f1faee")
		sign.outline_modulate = Color.BLACK
		sign.outline_size = 5
		add_child(sign)

		# Landing light inside the shaft.
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(9.0, y + 3.4, -6.5)
		lamp.light_color = Color("dfe8f0")
		lamp.light_energy = 1.7
		lamp.omni_range = 11.0
		lamp.shadow_enabled = false
		add_child(lamp)


func _rail(x: float, z_a: float, z_b: float, y_a: float, y_b: float, material: Material) -> void:
	var run := absf(z_b - z_a)
	var rise := absf(y_b - y_a)
	var slope := atan2(rise, run)
	var climbs := (z_b > z_a) == (y_b > y_a)
	var ang := -slope if climbs else slope
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, sqrt(run * run + rise * rise))
	mi.mesh = box
	mi.material_override = material
	mi.position = Vector3(x, (y_a + y_b) * 0.5, (z_a + z_b) * 0.5)
	mi.rotation.x = ang
	add_child(mi)


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

## Suspended ceiling with a recessed light grid, plus skirting round the walls.
## Applied per level so every floor reads as a room rather than a shell.
func _ceiling(y: float, height: float) -> void:
	var tile := _mat(Color("d8d6cf"), 0.9)
	var rail := _mat(Color("9aa0a6"), 0.6, 0.2)
	var panel := _mat(Color("fdf8e8"), 0.3)
	panel.emission_enabled = true
	panel.emission = Color("fff6e0")
	panel.emission_energy_multiplier = 1.5
	var top := y + height
	# Solid: without collision the spring arm sails straight through and you
	# end up looking at the floor from above the ceiling.
	var west_w := STAIR_X0 + W * 0.5
	_box(Vector3(-W * 0.5 + west_w * 0.5, top - 0.06, 0), Vector3(west_w, 0.12, D - 1.2), tile, true)
	var east_d := D * 0.5 - STAIR_Z1
	_box(Vector3((STAIR_X0 + STAIR_X1) * 0.5, top - 0.06, STAIR_Z1 + east_d * 0.5),
		Vector3(STAIR_X1 - STAIR_X0, 0.12, east_d), tile, true)
	# T-bar grid.
	for gx in range(-2, 3):
		_box(Vector3(gx * 5.0, top - 0.14, 0), Vector3(0.08, 0.05, D - 1.4), rail, false)
	for gz in range(-2, 3):
		_box(Vector3(0, top - 0.14, gz * 4.4), Vector3(W - 1.4, 0.05, 0.08), rail, false)
	# Recessed panels.
	for px in [-8.0, -2.0, 4.0]:
		for pz in [-6.0, 0.0, 6.0]:
			_box(Vector3(px, top - 0.15, pz), Vector3(2.4, 0.06, 1.1), panel, false)
	# Skirting.
	var skirt := _mat(Color("6f7378"), 0.7)
	for sz in [-D * 0.5 + 0.3, D * 0.5 - 0.3]:
		_box(Vector3(0, y + 0.08, sz), Vector3(W - 1.0, 0.16, 0.06), skirt, false)
	for sx in [-W * 0.5 + 0.3, W * 0.5 - 0.3]:
		_box(Vector3(sx, y + 0.08, 0), Vector3(0.06, 0.16, D - 1.0), skirt, false)


## Framed print on a wall.
func _art(at: Vector3, size: Vector2, tint: Color, face_x: bool) -> void:
	var frame := _mat(Color("2b2f36"), 0.5)
	var canvas := _mat(tint, 0.75)
	if face_x:
		_box(at, Vector3(0.05, size.y + 0.1, size.x + 0.1), frame, false)
		_box(at + Vector3(0.03, 0, 0), Vector3(0.02, size.y, size.x), canvas, false)
	else:
		_box(at, Vector3(size.x + 0.1, size.y + 0.1, 0.05), frame, false)
		_box(at + Vector3(0, 0, 0.03), Vector3(size.x, size.y, 0.02), canvas, false)


## Keyboard, mouse, mug and a paper stack, so a desk looks worked at.
func _desk_clutter(at: Vector3, y_top: float) -> void:
	_box(at + Vector3(-0.15, y_top + 0.02, 0.28), Vector3(0.44, 0.02, 0.16), _mat(Color("2b3038"), 0.5), false)
	_box(at + Vector3(0.22, y_top + 0.02, 0.3), Vector3(0.07, 0.03, 0.11), _mat(Color("3c434b"), 0.4), false)
	_box(at + Vector3(-0.62, y_top + 0.05, 0.1), Vector3(0.09, 0.1, 0.09), _mat(Color("e8e4da"), 0.45), false)
	_box(at + Vector3(0.72, y_top + 0.02, 0.05), Vector3(0.22, 0.03, 0.3), _mat(Color("f4f2ea"), 0.8), false)
	_box(at + Vector3(0.74, y_top + 0.04, 0.02), Vector3(0.2, 0.02, 0.28), _mat(Color("eceadf"), 0.8), false)


func _fit_lobby() -> void:
	var y: float = FLOORS[0].y
	_ceiling(y, 4.9)
	var wood := _mat(Color("6b4a2f"), 0.6)
	var stone := _mat(Color("d8dbe0"), 0.5)
	var couch := _mat(Color("2f4858"), 0.75)

	# Reception desk facing the doors, with a raised transaction top.
	_box(Vector3(-6.0, y + 0.55, 0), Vector3(1.0, 1.1, 5.0), wood, true)
	_box(Vector3(-6.0, y + 1.14, 0), Vector3(1.4, 0.08, 5.4), stone, true)
	_box(Vector3(-6.55, y + 0.62, 0), Vector3(0.06, 1.2, 5.1), _mat(Color("cfd3d8"), 0.4, 0.3), false)
	_box(Vector3(-5.8, y + 1.28, -1.4), Vector3(0.06, 0.36, 0.6), _mat(Color("101820"), 0.25), false)
	_box(Vector3(-5.85, y + 1.24, 0.9), Vector3(0.16, 0.03, 0.22), _mat(Color("2b3038"), 0.5), false)
	_art(Vector3(-12.6, y + 2.4, -4.0), Vector2(1.8, 1.2), Color("2f4858"), true)
	_art(Vector3(-12.6, y + 2.4, 4.0), Vector2(1.8, 1.2), Color("6b4a5a"), true)

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
	dir.text = "KAHUA\nLOBBY — RECEPTION\n4TH — OPERATIONS\n6TH — SALES FLOOR"
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
		"schedule": [
			{"from": 7.0, "to": 12.5, "at": Vector3(-4.8, y, 0)},
			{"from": 12.5, "to": 13.2, "at": Vector3(-9.0, y, -5.0),
				"say": ["Lunch. Sit down. I won't bite unless the day gets worse.",
					"I take it out here. Better view, occasionally."]},
			{"from": 13.2, "to": 18.0, "at": Vector3(-4.8, y, 0)},
		],
		"shirt": Color("8c2f47"),
		"hair": Color("14100f"),
		"lanyard": Color("c9a227"),
		"mug": true,
		"lines": [
			"There he is. I was starting to think I'd have to come find you.",
			"Sixth floor, sweetheart. I'd walk you up, but somebody has to sit here looking bored.",
			"You know you're the only reason I take the early shift.",
			"That shirt. Somebody dressed you well today. Was it you? Please say it was you.",
			"Go close something impressive so I have an excuse to congratulate you properly.",
			"If Ralph asks, you were here at nine. If anyone else asks, I've never met you.",
			"Badge in. Slowly. I've got nowhere to be.",
		],
	})


func _fit_fourth() -> void:
	var y: float = FLOORS[1].y
	_ceiling(y, 4.9)
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

	_foosball(Vector3(6.0, y, 6.5))

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
			"schedule": [
				{"from": 9.5, "to": 13.0, "at": Vector3(-9.4, y, 3.0)},
				{"from": 13.0, "to": 13.8, "at": Vector3(-8.0, y, -8.0),
					"say": ["I eat facing the wall. It's quieter."]},
				{"from": 13.8, "to": 18.0, "at": Vector3(-9.4, y, 3.0)},
			],
			"shirt": Color("46506b"),
			"hair": Color("6b4f2a"),
			"glasses": true,
			"beard": Color("55401f"),
			"mug": true,
			"build": "broad",
			"lines": [
				"Mm. Kind of in the middle of something.",
				"You want six. This is four. Those are different numbers.",
				"I'd explain but you'd need a lot of context.",
			],
		},
		{
			"name": "Collin — Data",
			"pos": Vector3(-4.6, y, 6.4),
			"schedule": [
				{"from": 10.0, "to": 19.5, "at": Vector3(-4.6, y, 6.4)},
			],
			"shirt": Color("3f6b52"),
			"hair": Color("c96a2a"),
			"glasses": true,
			"build": "slim",
			"lanyard": Color("3f6b52"),
			"lines": [
				"Yeah, no, I'm heads-down right now.",
				"Did Porter send you? Porter sends everyone.",
				"I saw your pipeline. No notes. Well — some notes.",
			],
		},
		{
			"name": "Wei — Infrastructure",
			"pos": Vector3(0.4, y, 3.0),
			"schedule": [
				{"from": 11.0, "to": 22.0, "at": Vector3(0.4, y, 3.0),
					"say": ["Deploy window is at eleven. At night. Obviously.",
						"I'm here late because someone is always here late.",
						"Prod's on fire. Always is."]},
			],
			"shirt": Color("55606d"),
			"skin": Color("e8c9a0"),
			"hair": Color("100d0c"),
			"glasses": true,
			"headset": true,
			"mug": true,
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
	_ceiling(y, 4.9)
	var wood := _mat(Color("6b4a2f"), 0.6)
	var grey := _mat(Color("3f4650"), 0.55)
	var screen := _mat(Color("101820"), 0.25)
	screen.emission_enabled = true
	screen.emission = Color("2a6df4")
	screen.emission_energy_multiplier = 1.4
	var plant := _mat(Color("2f6d34"), 0.9)

	for spot in [Vector3(-9.0, y, -5.0), Vector3(-9.0, y, 0.0), Vector3(-9.0, y, 5.0),
			Vector3(-3.0, y, -5.0), Vector3(-3.0, y, 5.0)]:
		_desk(spot, wood, screen, spot.z == -5.0 and is_equal_approx(spot.x, -9.0))
		_desk_clutter(spot, 0.8)
	_art(Vector3(-12.6, y + 2.5, 2.0), Vector2(2.2, 1.3), Color("1d3557"), true)
	_art(Vector3(-12.6, y + 2.5, -3.0), Vector2(1.6, 1.1), Color("2a9d8f"), true)

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
			"schedule": [
				{"from": 7.5, "to": 12.0, "at": Vector3(2.0, y, -6.0)},
				{"from": 12.0, "to": 13.0, "at": Vector3(2.4, y, 7.2),
					"say": ["Lunch is a meeting with yourself. Still a meeting.",
						"The Godfather eats at his desk. Today the desk is a table."]},
				{"from": 13.0, "to": 18.5, "at": Vector3(-2.0, y, -4.0)},
			],
			"shirt": Color("7b2d3b"),
			"tie": Color("2a2f36"),
			"build": "broad",
			"mug": true,
			"lines": [
				"You know what they call me? The SDR Godfather. Say it back to me.",
				"Quota is %d closed. That's not a stretch goal, that's table stakes." % GameState.SALES_QUOTA,
				"Let's circle back on your pipeline hygiene. And by circle back I mean now.",
				"I need you to double-click on why Brightline went dark. Peel the onion.",
				"Cold calls beat emails. That's not opinion, that's the playbook. My playbook.",
				"Don't pitch before you've asked a question. That's Godfather rule one.",
				"We're not selling software. We're selling outcomes. Write that down.",
				"I've been doing this since before you had a LinkedIn. Move the needle.",
				"Low-hanging fruit is still fruit. Go shake the tree.",
				"When I ran the floor in Duluth we closed on a handshake. Different game now.",
			],
		},
		{
			"name": "Ayden — Senior SDR",
			"pos": Vector3(-6.2, y, 0.0),
			"schedule": [
				{"from": 8.5, "to": 11.5, "at": Vector3(-6.2, y, 0.0)},
				{"from": 11.5, "to": 12.2, "at": Vector3(1.2, y, 7.6),
					"say": ["Coffee number four. I can hear colours.",
						"Ralph said 'peel the onion' twice before ten."]},
				{"from": 12.2, "to": 17.5, "at": Vector3(-6.2, y, 0.0)},
			],
			"shirt": Color("1d3557"),
			"hair": Color("0d0b0a"),
			"headset": true,
			"lanyard": Color("0176d3"),
			"build": "slim",
			"lines": [
				"Order matters: rapport, then a question, then the pitch, then ask for it.",
				"If a lead goes cold, email them a couple times before you call again.",
				"I closed Brightline on a Tuesday. Never doubt a Tuesday.",
			],
		},
		{
			"name": "Tyler — Sales Ops",
			"pos": Vector3(2.0, y, 6.0),
			"schedule": [
				{"from": 8.0, "to": 12.5, "at": Vector3(2.0, y, 6.0)},
				{"from": 12.5, "to": 13.4, "at": Vector3(3.0, y, 8.2),
					"say": ["Lunch is just a stand-up with sandwiches, partner.",
						"I like to eat where the synergy is."]},
				{"from": 13.4, "to": 19.0, "at": Vector3(2.0, y, 6.0)},
			],
			"shirt": Color("9c5f45"),
			"hat": "cowboy",
			"hair": Color("5b4432"),
			"beard": Color("4a3526"),
			"lines": [
				"Well howdy. Let's take this offline and align on next steps, partner.",
				"I reckon we oughta socialise that deck 'fore we boil the ocean with it.",
				"Convert the lead 'fore you close it. That there's low-hanging fruit, son.",
				"I tidy the pipeline every Friday. Don't make Friday worse, partner.",
				"We got some real blue-sky thinking to do on the back half. Yeehaw.",
				"That's a paradigm shift right there, and I don't say that lightly.",
				"Let's put a pin in it, run it up the flagpole, see who salutes.",
				"Ain't no I in team, but there's an I in pipeline. Two of 'em.",
				"I'll ping you async so we can right-size the ask. Giddy up.",
				"Fella asked me for a quick sync. Weren't quick. Weren't a sync.",
			],
		},
		{
			"name": "Fiona — SDR",
			"pos": Vector3(-6.2, y, 5.0),
			"schedule": [
				{"from": 9.0, "to": 12.4, "at": Vector3(-6.2, y, 5.0)},
				{"from": 12.4, "to": 13.2, "at": Vector3(0.6, y, 8.0),
					"say": ["If Ralph says Godfather again I'm going to the roof.",
						"Don't sit there. That's Tyler's chair. He's named it."]},
				{"from": 13.2, "to": 17.0, "at": Vector3(-6.2, y, 5.0)},
			],
			"shirt": Color("2a9d8f"),
			"hair": Color("e0c169"),
			"headset": true,
			"lanyard": Color("2a9d8f"),
			"lines": [
				"Don't spam one lead with email. After about three they stop reading.",
				"Closing under seventy percent is a coin flip. I've lost good leads that way.",
				"Coffee's by the window. It's not good, but it's there.",
			],
		},
	]:
		_npc(spec)


## Foosball table. Cabinet, eight rods with figures in two strips, goal
## mouths and bead counters — laid out so a match minigame can drive the rods.
func _foosball(at: Vector3) -> void:
	var cab := _mat(Color("3a2a1c"), 0.7)
	var pitch := _mat(Color("1f6b34"), 0.85)
	var chrome := _mat(Color("c9ccd0"), 0.25, 0.85)
	var red := _mat(Color("c1272d"), 0.5)
	var blue := _mat(Color("1d4e89"), 0.5)

	var tw := 1.42        # play area across (x)
	var td := 0.78        # play area deep (z)
	var top := 0.92       # playing surface height

	# Cabinet: surface, side rails, end walls, legs.
	_box(at + Vector3(0, top - 0.03, 0), Vector3(tw, 0.06, td), pitch, true)
	for dx in [-tw * 0.5 - 0.06, tw * 0.5 + 0.06]:
		_box(at + Vector3(dx, top + 0.04, 0), Vector3(0.12, 0.22, td + 0.24), cab, true)
	for dz in [-td * 0.5 - 0.06, td * 0.5 + 0.06]:
		_box(at + Vector3(0, top + 0.04, dz), Vector3(tw + 0.24, 0.22, 0.12), cab, true)
	_box(at + Vector3(0, top - 0.16, 0), Vector3(tw + 0.24, 0.2, td + 0.24), cab, true)
	for lx in [-tw * 0.5 + 0.06, tw * 0.5 - 0.06]:
		for lz in [-td * 0.5 + 0.06, td * 0.5 - 0.06]:
			_box(at + Vector3(lx, (top - 0.26) * 0.5, lz), Vector3(0.09, top - 0.26, 0.09), cab, true)

	# Pitch markings.
	_box(at + Vector3(0, top + 0.01, 0), Vector3(0.02, 0.01, td - 0.04), _mat(Color("f1faee"), 0.6), false)
	for gz in [-td * 0.5 - 0.05, td * 0.5 + 0.05]:
		_box(at + Vector3(0, top + 0.02, gz), Vector3(0.34, 0.1, 0.04), _mat(Color("11151a"), 0.4), false)

	# Eight rods: red on 1/3/5/7, blue on 2/4/6/8, with figures per rod.
	var counts := [1, 2, 5, 3, 3, 5, 2, 1]
	for i in 8:
		var rx: float = -tw * 0.5 + tw * (i + 1) / 9.0
		var side_red := i % 2 == 0
		_box(at + Vector3(rx, top + 0.11, 0), Vector3(0.03, 0.03, td + 0.62), chrome, false)
		for h in [-1.0, 1.0]:
			_box(at + Vector3(rx, top + 0.11, h * (td * 0.5 + 0.34)), Vector3(0.05, 0.05, 0.14), cab, false)
		var n: int = counts[i]
		for f in n:
			var fz: float = -td * 0.4 + (td * 0.8) * (f + 0.5) / float(n)
			var body := red if side_red else blue
			_box(at + Vector3(rx, top + 0.06, fz), Vector3(0.045, 0.13, 0.05), body, false)
			_box(at + Vector3(rx, top + 0.14, fz), Vector3(0.06, 0.05, 0.06), body, false)

	# Bead score counters on the long rail.
	for team in 2:
		for b in 5:
			var bx: float = -0.42 + team * 0.6 + b * 0.055
			_box(at + Vector3(bx, top + 0.2, -td * 0.5 - 0.13), Vector3(0.04, 0.04, 0.04),
				red if team == 0 else blue, false)

	var spot := Node3D.new()
	spot.name = "FoosballSpot"
	spot.position = at + Vector3(0, 0, td * 0.5 + 0.9)
	spot.add_to_group("activity")
	spot.set_script(load("res://scripts/activity_spot.gd"))
	add_child(spot)
	spot.setup("foosball", "E  Play foosball", "Nobody on ops will play you. Yet.")

	var tag := Label3D.new()
	tag.text = "FOOSBALL"
	tag.position = at + Vector3(0, top + 0.75, 0)
	tag.font_size = 26
	tag.modulate = Color("ffb703")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)


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
