extends Node3D

# Local space matches _build_office() in world_builder.gd: 22 x 16 shell,
# west wall (the WORK NORTH POINT entrance) at x = -11, floor top at y = 0.2.
const FLOOR := 0.2
const DOOR_W := 2.8
const DOOR_H := 2.7
const OPEN_RANGE := 5.0
const SLIDE_SPEED := 3.6

var _leaves: Array[AnimatableBody3D] = []
var _open: float = 0.0


func _ready() -> void:
	add_to_group("office")
	_build_doors()
	_build_furniture()
	_build_staff()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var want := 0.0
	if player and not GameState.in_car:
		var door := global_position + Vector3(-11.0, 0.0, 0.0)
		var flat := Vector2(door.x - player.global_position.x, door.z - player.global_position.z)
		want = 1.0 if flat.length() < OPEN_RANGE else 0.0
	_open = move_toward(_open, want, SLIDE_SPEED * delta)
	var shift := _open * (DOOR_W * 0.5 + 0.05)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		_leaves[i].position.z = side * (DOOR_W * 0.25 + shift)


func _build_doors() -> void:
	# CharacterBody3D has no step climbing, so the 0.2 floor slab would stop
	# Jacob dead in the doorway. A 16-degree threshold ramp lets him walk in.
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	ramp.position = Vector3(-11.3, 0.04, 0.0)
	ramp.rotation_degrees.z = 15.9
	var ramp_size := Vector3(0.78, 0.12, DOOR_W)
	var rcol := CollisionShape3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = ramp_size
	rcol.shape = rshape
	ramp.add_child(rcol)
	var rmi := MeshInstance3D.new()
	var rbox2 := BoxMesh.new()
	rbox2.size = ramp_size
	rmi.mesh = rbox2
	rmi.material_override = _mat(Color("55606d"), 0.75)
	ramp.add_child(rmi)
	add_child(ramp)

	var glass := _mat(Color(0.62, 0.82, 0.9, 0.42), 0.05, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 2:
		var leaf := AnimatableBody3D.new()
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position = Vector3(-11.0, FLOOR, 0.0)

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
		mi.material_override = glass
		mi.position.y = size.y * 0.5
		leaf.add_child(mi)

		# Brass rail down the leading edge so the doors read as doors.
		var rail := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(0.16, size.y, 0.09)
		rail.mesh = rbox
		rail.material_override = _mat(Color("c9a227"), 0.35, 0.6)
		rail.position = Vector3(0, size.y * 0.5, (DOOR_W * 0.25 - 0.05) * (-1.0 if i == 0 else 1.0))
		leaf.add_child(rail)

		add_child(leaf)
		_leaves.append(leaf)


func _build_furniture() -> void:
	var wood := _mat(Color("6b4a2f"), 0.6)
	var grey := _mat(Color("3f4650"), 0.55)
	var screen := _mat(Color("101820"), 0.25)
	screen.emission_enabled = true
	screen.emission = Color("2a6df4")
	screen.emission_energy_multiplier = 1.4
	var plant := _mat(Color("2f6d34"), 0.9)

	# Jacob's workstation — the one you can actually sit down at.
	_desk(Vector3(-6.0, 0, -5.0), wood, screen, true)
	# Coworker desks.
	_desk(Vector3(-6.0, 0, 0.0), wood, screen, false)
	_desk(Vector3(-6.0, 0, 5.0), wood, screen, false)
	_desk(Vector3(0.5, 0, -5.0), wood, screen, false)

	# Break corner.
	_box(Vector3(8.0, 0.74, 6.2), Vector3(1.2, 0.06, 1.2), grey, true, true)
	_box(Vector3(8.0, 0.37, 6.2), Vector3(0.16, 0.72, 0.16), grey, true, true)
	_box(Vector3(9.6, 0, 6.2), Vector3(0.42, 1.3, 0.42), _mat(Color("dfe7ee"), 0.4), true)
	for pz in [6.6, -6.6]:
		_box(Vector3(-9.6, 0, pz), Vector3(0.6, 0.5, 0.6), _mat(Color("8a5a44"), 0.8), true)
		_box(Vector3(-9.6, 0.5, pz), Vector3(0.8, 1.2, 0.8), plant, false)

	# Whiteboard on the north wall with the quota on it.
	_box(Vector3(0.0, 1.4, -7.6), Vector3(4.4, 1.6, 0.1), _mat(Color("f4f7fa"), 0.4), true)
	var board := Label3D.new()
	board.text = "Q3 QUOTA\n%d DEALS" % GameState.SALES_QUOTA
	board.position = Vector3(0.0, 2.2, -7.5)
	board.font_size = 40
	board.modulate = Color("1d3557")
	add_child(board)


func _desk(at: Vector3, wood: Material, screen: Material, is_jacobs: bool) -> void:
	_box(at + Vector3(0, 0.72, 0), Vector3(2.4, 0.08, 1.2), wood, true, true)
	_box(at + Vector3(-1.1, 0.36, 0), Vector3(0.1, 0.72, 1.1), wood, true, true)
	_box(at + Vector3(1.1, 0.36, 0), Vector3(0.1, 0.72, 1.1), wood, true, true)
	# Monitor.
	_box(at + Vector3(0.2, 0.82, 0), Vector3(0.1, 0.2, 0.4), _mat(Color("22262c"), 0.5), false, true)
	_box(at + Vector3(0.2, 1.12, 0), Vector3(0.06, 0.5, 0.86), screen, false, true)
	# Chair.
	_box(at + Vector3(-0.95, 0.44, 0), Vector3(0.55, 0.08, 0.55), _mat(Color("2b3038"), 0.7), true, true)
	_box(at + Vector3(-1.2, 0.78, 0), Vector3(0.08, 0.6, 0.55), _mat(Color("2b3038"), 0.7), true, true)

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
	tag.position = at + Vector3(0.2, 1.72, 0)
	tag.font_size = 30
	tag.modulate = Color("ffb703")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)


func _build_staff() -> void:
	var staff := [
		{
			"name": "Dana — Floor Manager",
			"pos": Vector3(8.0, 0, -6.0),
			"shirt": Color("7b2d3b"),
			"lines": [
				"Quota is %d closed deals. Sit at your desk and dial." % GameState.SALES_QUOTA,
				"Cold calls beat emails. Emails just keep you warm.",
				"Don't pitch before you've asked them a question. They hang up.",
			],
		},
		{
			"name": "Marcus — Senior Rep",
			"pos": Vector3(-4.2, 0, 0.0),
			"shirt": Color("1d3557"),
			"lines": [
				"Trick is the order: rapport, then a question, then the pitch, then ask for it.",
				"If a lead goes cold, email them a couple times before you call again.",
				"I closed Brightline on a Tuesday. Never doubt a Tuesday.",
			],
		},
		{
			"name": "Priya — SDR",
			"pos": Vector3(-4.2, 0, 5.0),
			"shirt": Color("2a9d8f"),
			"lines": [
				"Don't spam the same lead with email. After about three they stop reading.",
				"Closing under seventy percent interest is a coin flip. I've lost good leads that way.",
				"Coffee's by the window. It's not good, but it's there.",
			],
		},
	]
	for s in staff:
		_npc(s)


func _npc(spec: Dictionary) -> void:
	var npc := StaticBody3D.new()
	npc.collision_layer = 1
	npc.collision_mask = 0
	npc.position = spec.pos
	npc.add_to_group("office_npc")
	npc.set_script(load("res://scripts/office/office_npc.gd"))
	add_child(npc)
	npc.setup(spec.name, spec.lines, spec.shirt)


func _box(at: Vector3, size: Vector3, material: Material, solid: bool, centred: bool = false) -> MeshInstance3D:
	var pos := at + Vector3(0, FLOOR, 0)
	if not centred:
		pos.y += size.y * 0.5
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		add_child(body)
	return mi


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
