extends Node3D

# Lilli's Bakery. Shopfront with an awning, a display case you can walk up to,
# a prep bench at the back where Lilli works, and ovens behind that.
#
# Local space: origin at the centre of the floor, shopfront facing -Z (the
# street), counter across the middle.

const W := 20.0
const D := 16.0
const H := 5.0
const T := 0.4
const DOOR_W := 2.4
const DOOR_H := 2.6
const OPEN_RANGE := 5.0

var _leaves: Array[AnimatableBody3D] = []
var _open: float = 0.0

var _brick: StandardMaterial3D
var _cream: StandardMaterial3D
var _wood: StandardMaterial3D
var _tile: StandardMaterial3D
var _glass: StandardMaterial3D
var _steel: StandardMaterial3D
var _pink: StandardMaterial3D


func _ready() -> void:
	add_to_group("bakery")
	_make_mats()
	_shell()
	_front()
	_interior()
	_staff()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var want := 0.0
	if player and not GameState.in_car:
		var door := to_global(Vector3(0, 0, -D * 0.5))
		var flat := Vector2(door.x - player.global_position.x, door.z - player.global_position.z)
		want = 1.0 if flat.length() < OPEN_RANGE else 0.0
	_open = move_toward(_open, want, 3.4 * delta)
	var shift := _open * (DOOR_W * 0.5 + 0.05)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		_leaves[i].position.x = side * (DOOR_W * 0.25 + shift)


func _make_mats() -> void:
	_brick = _mat(Color("9c5f45"), 0.9)
	_cream = _mat(Color("f2e6d0"), 0.8)
	_wood = _mat(Color("7a5233"), 0.7)
	_tile = _mat(Color("d8ccb8"), 0.6)
	_steel = _mat(Color("b8bcc0"), 0.35, 0.7)
	_pink = _mat(Color("d988a8"), 0.6)
	_glass = _mat(Color(0.72, 0.84, 0.88, 0.35), 0.05, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _shell() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	_box(Vector3(0, 0.01, 0), Vector3(W, 0.02, D), _tile, false)
	_box(Vector3(-hx, H * 0.5, 0), Vector3(T, H, D), _brick, true)
	_box(Vector3(hx, H * 0.5, 0), Vector3(T, H, D), _brick, true)
	_box(Vector3(0, H * 0.5, hz), Vector3(W, H, T), _brick, true)
	_box(Vector3(0, H - 0.1, 0), Vector3(W, 0.2, D), _cream, true)
	_box(Vector3(0, H + 0.35, 0), Vector3(W + 0.8, 0.5, D + 0.8), _brick, true)


func _front() -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	var gap := DOOR_W * 0.5
	# Shopfront: door in the middle, big windows either side.
	for side in [-1.0, 1.0]:
		var seg := hx - gap
		_box(Vector3(side * (gap + hx) * 0.5, H * 0.5, -hz), Vector3(seg, H, T), _brick, true)
		# Window punched out of that wall, with a sill and mullions.
		_box(Vector3(side * (gap + hx) * 0.5, 1.9, -hz - 0.06), Vector3(seg - 1.6, 2.2, 0.1), _glass, false)
		_box(Vector3(side * (gap + hx) * 0.5, 0.72, -hz - 0.12), Vector3(seg - 1.4, 0.16, 0.3), _cream, false)
		for m in 3:
			var mx: float = side * (gap + hx) * 0.5 - (seg - 1.6) * 0.5 + (seg - 1.6) * (m + 1) / 4.0
			_box(Vector3(mx, 1.9, -hz - 0.1), Vector3(0.08, 2.2, 0.08), _cream, false)
	_box(Vector3(0, (DOOR_H + H) * 0.5, -hz), Vector3(DOOR_W, H - DOOR_H, T), _brick, true)

	# Striped awning over the whole front.
	for i in 9:
		var ax: float = -hx + 1.0 + i * 2.25
		_box(Vector3(ax, 3.5, -hz - 0.9), Vector3(2.25, 0.14, 2.0), _pink if i % 2 == 0 else _cream, false)
	_box(Vector3(0, 3.66, -hz - 1.85), Vector3(W + 0.4, 0.22, 0.16), _wood, false)
	for sx in [-hx + 0.6, hx - 0.6]:
		_box(Vector3(sx, 3.2, -hz - 1.0), Vector3(0.1, 0.75, 0.1), _wood, false)

	# Doors.
	for i in 2:
		var leaf := AnimatableBody3D.new()
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position = Vector3(0.0, 0.0, -hz)
		var size := Vector3(DOOR_W * 0.5, DOOR_H - 0.15, 0.1)
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
		rb.size = Vector3(0.08, size.y, 0.14)
		rail.mesh = rb
		rail.material_override = _wood
		rail.position = Vector3((DOOR_W * 0.25 - 0.05) * (-1.0 if i == 0 else 1.0), size.y * 0.5, 0)
		leaf.add_child(rail)
		add_child(leaf)
		_leaves.append(leaf)

	var sign := Label3D.new()
	sign.text = "LILLI'S BAKERY"
	sign.position = Vector3(0, 4.3, -hz - 0.3)
	sign.font_size = 64
	sign.modulate = Color("8c3b52")
	sign.outline_modulate = Color("f2e6d0")
	sign.outline_size = 10
	sign.rotation_degrees.y = 180.0
	add_child(sign)

	var hours := Label3D.new()
	hours.text = "FRESH DAILY"
	hours.position = Vector3(0, 2.95, -hz - 0.3)
	hours.font_size = 24
	hours.modulate = Color("f2e6d0")
	hours.outline_modulate = Color("5a2a38")
	hours.outline_size = 6
	hours.rotation_degrees.y = 180.0
	add_child(hours)


func _interior() -> void:
	# Display case across the shop, glass front, trays of pastries inside.
	_box(Vector3(-2.0, 0.5, -1.5), Vector3(12.0, 1.0, 0.9), _wood, true)
	_box(Vector3(-2.0, 1.04, -1.5), Vector3(12.4, 0.08, 1.1), _tile, false)
	_box(Vector3(-2.0, 0.72, -1.98), Vector3(11.8, 0.6, 0.06), _glass, false)
	var treats := [Color("d9a441"), Color("c2703a"), Color("e8c78a"), Color("a8523f"), Color("efd9a0")]
	for i in 10:
		var tx: float = -7.4 + i * 1.2
		_box(Vector3(tx, 0.62, -1.5), Vector3(0.9, 0.06, 0.6), _steel, false)
		for j in 3:
			_box(Vector3(tx - 0.28 + j * 0.28, 0.7, -1.5 + (0.14 if j % 2 == 0 else -0.1)),
				Vector3(0.2, 0.11, 0.2), _mat(treats[(i + j) % treats.size()], 0.7), false)

	# Till end of the counter.
	_box(Vector3(5.2, 1.2, -1.5), Vector3(0.5, 0.32, 0.4), _mat(Color("2b3038"), 0.5), false)
	_box(Vector3(5.2, 1.38, -1.62), Vector3(0.42, 0.1, 0.06), _mat(Color("101820"), 0.3), false)

	# Bread shelving on the back wall.
	for s in 3:
		var sy: float = 1.2 + s * 0.72
		_box(Vector3(-6.0, sy, 7.4), Vector3(7.0, 0.08, 0.9), _wood, true)
		for b in 6:
			_box(Vector3(-9.0 + b * 1.15, sy + 0.19, 7.4), Vector3(0.75, 0.3, 0.55),
				_mat(Color("c08b4e").lightened(0.05 * (b % 3)), 0.85), false)

	# Prep bench where the work happens.
	_box(Vector3(3.0, 0.45, 4.0), Vector3(6.0, 0.9, 1.6), _steel, true)
	_box(Vector3(3.0, 0.92, 4.0), Vector3(6.2, 0.06, 1.75), _mat(Color("e8e2d4"), 0.5), false)
	_box(Vector3(1.4, 1.0, 4.0), Vector3(0.5, 0.1, 0.5), _mat(Color("f4efe3"), 0.9), false)
	_box(Vector3(2.6, 1.02, 4.1), Vector3(0.55, 0.14, 0.16), _wood, false)
	for fx in [4.6, 5.3]:
		_box(Vector3(fx, 1.05, 3.7), Vector3(0.28, 0.2, 0.28), _mat(Color("cfc4a8"), 0.9), false)

	# Ovens.
	for oz in [6.6, 3.4]:
		_box(Vector3(8.2, 0.85, oz), Vector3(2.4, 1.7, 2.2), _steel, true)
		_box(Vector3(7.0, 0.95, oz), Vector3(0.1, 1.0, 1.6), _mat(Color("2a2f34"), 0.35), false)
		_box(Vector3(6.94, 1.5, oz), Vector3(0.08, 0.09, 1.2), _steel, false)
		var glow := _mat(Color("ff9d3c"), 0.4)
		glow.emission_enabled = true
		glow.emission = Color("ff8a2a")
		glow.emission_energy_multiplier = 1.6
		_box(Vector3(6.96, 0.95, oz), Vector3(0.03, 0.7, 1.2), glow, false)

	# Flour sacks and a couple of café tables by the window.
	for i in 3:
		_box(Vector3(-8.6, 0.3, 2.0 + i * 0.9), Vector3(0.8, 0.6, 0.7), _mat(Color("e3dac3"), 0.95), true)
	for tx in [-6.5, -2.5]:
		_box(Vector3(tx, 0.72, -5.6), Vector3(1.1, 0.08, 1.1), _wood, true)
		_box(Vector3(tx, 0.36, -5.6), Vector3(0.14, 0.72, 0.14), _steel, true)
		for cz in [-6.6, -4.6]:
			_box(Vector3(tx, 0.44, cz), Vector3(0.5, 0.06, 0.5), _wood, true)
			_box(Vector3(tx, 0.22, cz), Vector3(0.1, 0.44, 0.1), _steel, false)

	for i in 4:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-6.0 + i * 4.0, H - 0.9, 0.0)
		lamp.light_color = Color("ffe2b0")
		lamp.light_energy = 2.2
		lamp.omni_range = 13.0
		lamp.shadow_enabled = false
		add_child(lamp)

	var spot := Node3D.new()
	spot.name = "BakeSpot"
	spot.position = Vector3(3.0, 0, 2.4)
	spot.add_to_group("activity")
	spot.set_script(load("res://scripts/activity_spot.gd"))
	add_child(spot)
	spot.setup("bakery", "E  Help Lilli bake", "The oven is cold.")

	var tag := Label3D.new()
	tag.text = "E  —  BAKE WITH LILLI"
	tag.position = Vector3(3.0, 2.1, 2.4)
	tag.font_size = 32
	tag.modulate = Color("d988a8")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 7
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)


func _staff() -> void:
	var lilli := StaticBody3D.new()
	lilli.collision_layer = 1
	lilli.collision_mask = 0
	lilli.position = Vector3(-2.0, 0, 0.2)
	lilli.rotation_degrees.y = 180.0
	lilli.add_to_group("office_npc")
	lilli.set_script(load("res://scripts/office/office_npc.gd"))
	add_child(lilli)
	lilli.setup({
		"name": "Lilli — Baker",
		"shirt": Color("f2e6d0"),
		"hair": Color("6b4a2f"),
		"skin": Color("e7c3a0"),
		"trousers": Color("8c3b52"),
		"lines": [
			"You can help if you wash your hands. That wasn't a question.",
			"Croissants are just butter with a lamination problem.",
			"The six o'clock bake is the one that matters. The rest is admin.",
			"If it looks rustic it was an accident. Tell nobody.",
			"Take an apron. Don't take the last almond one, that's spoken for.",
		],
		"schedule": [
			{"from": 5.0, "to": 12.0, "at": Vector3(-2.0, 0, 0.2)},
			{"from": 12.0, "to": 13.0, "at": Vector3(-4.5, 0, -4.6),
				"say": ["Sitting down for eleven minutes. Time me."]},
			{"from": 13.0, "to": 18.0, "at": Vector3(1.2, 0, 5.6),
				"say": ["Afternoon bake. Stay on that side of the bench."]},
		],
	})


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
