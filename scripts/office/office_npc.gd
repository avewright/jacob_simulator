extends StaticBody3D

# A person you can talk to. Built from boxes, but enough of them to read as a
# body: neck, collar, sleeves ending in hands, belt, legs, shoes, and a face
# with eyes and a brow so they are not blank.
#
# `spec` keys — name, lines, shirt. Optional: hair (Color; omit for bald),
# skin, trousers, glasses (bool), hat ("cowboy"), tie (Color), lanyard (Color),
# beard (Color), mug (bool), headset (bool), build ("slim"|"broad").

const RANGE := 3.2
const WALK := 1.5

var npc_name: String = "Coworker"
var lines: Array = []
## Optional day plan. Each slot is {from, to, at, say?} in hours and parent
## space; outside every slot the person has gone home.
var schedule: Array = []

var _next: int = 0
var _home := Vector3.ZERO
var _here: bool = true
var _slot: Dictionary = {}
var _col: CollisionShape3D
var _tag: Label3D


func setup(spec: Dictionary) -> void:
	npc_name = String(spec.get("name", "Coworker"))
	lines = spec.get("lines", [])
	schedule = spec.get("schedule", [])
	_home = position
	_build(spec)
	if not schedule.is_empty():
		set_process(true)
		_settle()
	else:
		set_process(false)


func _process(delta: float) -> void:
	var want := _slot_for(GameState.clock)
	if want != _slot:
		_slot = want
	if _slot.is_empty():
		_present(false)
		return
	_present(true)
	var target: Vector3 = _slot.get("at", _home)
	var before := position
	position = position.move_toward(target, WALK * delta)
	var moved := position - before
	if moved.length_squared() > 0.000001:
		rotation.y = lerp_angle(rotation.y, atan2(moved.x, moved.z), 1.0 - exp(-8.0 * delta))


## The slot covering this hour, or an empty dictionary if they are off.
func _slot_for(hour: float) -> Dictionary:
	for entry in schedule:
		var from: float = float(entry.get("from", 0.0))
		var to: float = float(entry.get("to", 24.0))
		if from <= to:
			if hour >= from and hour < to:
				return entry
		elif hour >= from or hour < to:      # slot wraps past midnight
			return entry
	return {}


## Put them straight where they should be, rather than walking in from spawn.
func _settle() -> void:
	_slot = _slot_for(GameState.clock)
	if _slot.is_empty():
		_present(false)
		return
	_present(true)
	position = _slot.get("at", _home)


func _present(yes: bool) -> void:
	if yes == _here:
		return
	_here = yes
	visible = yes
	if _col:
		_col.disabled = not yes
	if _tag:
		_tag.visible = yes


func in_range(who: Node3D) -> bool:
	if who == null or not _here:
		return false
	# The tower stacks people directly above each other, so height has to count
	# or you get prompted for whoever is one floor up.
	if absf(who.global_position.y - global_position.y) > 2.5:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func talk() -> void:
	# A slot can carry its own lines — what they say at lunch differs from
	# what they say at their desk.
	var say: Array = _slot.get("say", []) if not _slot.is_empty() else []
	if say.is_empty():
		say = lines
	if say.is_empty():
		return
	GameState.notice.emit("%s: %s" % [npc_name.split(" —")[0], say[_next % say.size()]])
	_next += 1


func _build(spec: Dictionary) -> void:
	var skin_tint: Color = spec.get("skin", Color("d9a884"))
	var skin := _mat(skin_tint, 0.78)
	var dark_skin := _mat(skin_tint.darkened(0.16), 0.78)
	var trousers := _mat(spec.get("trousers", Color("2b3038")), 0.72)
	var shirt_tint: Color = spec.get("shirt", Color("1d3557"))
	var shirt := _mat(shirt_tint, 0.62)
	var shade := _mat(shirt_tint.darkened(0.22), 0.62)
	var shoe := _mat(Color("1b1a18"), 0.5)

	var broad: bool = String(spec.get("build", "")) == "broad"
	var slim: bool = String(spec.get("build", "")) == "slim"
	var w: float = 0.62 if broad else (0.5 if slim else 0.56)

	_col = CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.34
	caps.height = 1.74
	_col.shape = caps
	_col.position.y = 0.87
	add_child(_col)

	# Legs, with a break at the knee so they are not one slab.
	for lx in [-0.13, 0.13]:
		_part(Vector3(lx, 0.24, 0), Vector3(0.19, 0.48, 0.21), trousers)
		_part(Vector3(lx, 0.62, 0), Vector3(0.21, 0.32, 0.23), trousers)
		_part(Vector3(lx, 0.05, 0.035), Vector3(0.2, 0.1, 0.3), shoe)

	# Hips and belt.
	_part(Vector3(0, 0.86, 0), Vector3(w - 0.06, 0.2, 0.27), trousers)
	_part(Vector3(0, 0.96, 0), Vector3(w - 0.04, 0.05, 0.28), _mat(Color("2a221c"), 0.5))

	# Torso, tapering to the shoulders.
	_part(Vector3(0, 1.14, 0), Vector3(w, 0.3, 0.29), shirt)
	_part(Vector3(0, 1.38, 0), Vector3(w + 0.03, 0.22, 0.3), shirt)
	# Collar and the shadow under it.
	_part(Vector3(0, 1.5, 0.02), Vector3(w - 0.14, 0.06, 0.26), shade)

	# Arms: sleeve, forearm, hand.
	for side in [-1.0, 1.0]:
		var ax: float = side * (w * 0.5 + 0.07)
		_part(Vector3(ax, 1.34, 0), Vector3(0.14, 0.32, 0.19), shirt)
		_part(Vector3(ax, 1.08, 0.01), Vector3(0.12, 0.26, 0.17), shade)
		_part(Vector3(ax, 0.92, 0.02), Vector3(0.11, 0.12, 0.15), skin)

	# Neck and head.
	_part(Vector3(0, 1.56, 0), Vector3(0.13, 0.09, 0.13), dark_skin)
	_part(Vector3(0, 1.71, 0), Vector3(0.28, 0.31, 0.27), skin)
	_part(Vector3(0, 1.61, 0.135), Vector3(0.12, 0.05, 0.03), dark_skin)   # jaw shadow

	# Eyes and brow, so a face reads from a couple of metres away.
	var white := _mat(Color("f3efe6"), 0.4)
	var pupil := _mat(Color("15100c"), 0.35)
	for ex in [-0.062, 0.062]:
		_part(Vector3(ex, 1.75, 0.137), Vector3(0.055, 0.04, 0.02), white)
		_part(Vector3(ex, 1.75, 0.146), Vector3(0.024, 0.026, 0.012), pupil)
	if spec.has("hair"):
		_part(Vector3(0, 1.795, 0.13), Vector3(0.19, 0.022, 0.03), _mat(Color(spec.hair).darkened(0.2), 0.85))

	if spec.has("beard"):
		var beard := _mat(spec.beard, 0.88)
		_part(Vector3(0, 1.635, 0.11), Vector3(0.2, 0.09, 0.09), beard)
		for sx in [-0.115, 0.115]:
			_part(Vector3(sx, 1.68, 0.06), Vector3(0.05, 0.14, 0.16), beard)

	# Hair. No "hair" key at all means bald.
	if spec.has("hair"):
		var hair := _mat(spec.hair, 0.86)
		_part(Vector3(0, 1.885, 0), Vector3(0.3, 0.07, 0.29), hair)
		_part(Vector3(0, 1.8, -0.14), Vector3(0.3, 0.2, 0.05), hair)
		for sx in [-0.145, 0.145]:
			_part(Vector3(sx, 1.79, -0.01), Vector3(0.045, 0.2, 0.27), hair)
		_part(Vector3(0, 1.845, 0.115), Vector3(0.26, 0.09, 0.06), hair)   # fringe

	if spec.get("glasses", false):
		var frame := _mat(Color("22262c"), 0.35, 0.25)
		for ex in [-0.062, 0.062]:
			_part(Vector3(ex, 1.75, 0.152), Vector3(0.085, 0.075, 0.012), frame)
		_part(Vector3(0, 1.75, 0.152), Vector3(0.045, 0.012, 0.012), frame)
		for sx in [-0.115, 0.115]:
			_part(Vector3(sx, 1.75, 0.09), Vector3(0.012, 0.012, 0.13), frame)

	if spec.has("tie"):
		var tie := _mat(spec.tie, 0.55)
		_part(Vector3(0, 1.46, 0.15), Vector3(0.06, 0.07, 0.03), tie)
		_part(Vector3(0, 1.3, 0.152), Vector3(0.075, 0.28, 0.025), tie)

	if spec.has("lanyard"):
		var cord := _mat(spec.lanyard, 0.8)
		for sx in [-0.075, 0.075]:
			_part(Vector3(sx, 1.42, 0.13), Vector3(0.018, 0.18, 0.02), cord)
		_part(Vector3(0, 1.26, 0.15), Vector3(0.09, 0.13, 0.012), _mat(Color("f1faee"), 0.4))
		_part(Vector3(0, 1.29, 0.157), Vector3(0.07, 0.03, 0.008), _mat(Color("9aa4b2"), 0.4))

	if spec.get("headset", false):
		var band := _mat(Color("1f2429"), 0.4)
		_part(Vector3(0, 1.9, -0.01), Vector3(0.29, 0.025, 0.03), band)
		for sx in [-0.15, 0.15]:
			_part(Vector3(sx, 1.79, 0), Vector3(0.035, 0.09, 0.09), band)
		_part(Vector3(0.115, 1.68, 0.09), Vector3(0.09, 0.02, 0.02), band)
		_part(Vector3(0.07, 1.67, 0.135), Vector3(0.035, 0.035, 0.035), _mat(Color("3d444b"), 0.4))

	if spec.get("mug", false):
		_part(Vector3(0.34, 1.0, 0.09), Vector3(0.09, 0.11, 0.09), _mat(Color("e8e4da"), 0.45))
		_part(Vector3(0.4, 1.0, 0.09), Vector3(0.025, 0.06, 0.02), _mat(Color("e8e4da"), 0.45))

	if String(spec.get("hat", "")) == "cowboy":
		var felt := _mat(Color("6b4a2f"), 0.9)
		var band2 := _mat(Color("3b2a1c"), 0.8)
		# Brim, sides turned up, then the crown with its pinch.
		_part(Vector3(0, 1.905, 0), Vector3(0.66, 0.045, 0.6), felt)
		for sx in [-0.32, 0.32]:
			_part(Vector3(sx, 1.94, 0), Vector3(0.06, 0.07, 0.5), felt)
		_part(Vector3(0, 2.0, 0), Vector3(0.3, 0.17, 0.28), felt)
		_part(Vector3(0, 2.06, 0), Vector3(0.09, 0.06, 0.26), band2)
		_part(Vector3(0, 1.945, 0), Vector3(0.33, 0.045, 0.31), band2)
		# Boots and a big buckle.
		for bx in [-0.13, 0.13]:
			_part(Vector3(bx, 0.09, 0.03), Vector3(0.21, 0.18, 0.32), felt)
			_part(Vector3(bx, 0.26, -0.01), Vector3(0.2, 0.2, 0.22), felt)
		_part(Vector3(0, 0.96, 0.145), Vector3(0.11, 0.08, 0.02), _mat(Color("d9b24a"), 0.3, 0.7))

	_tag = Label3D.new()
	_tag.text = npc_name
	_tag.position = Vector3(0, 2.2, 0)
	_tag.font_size = 28
	_tag.modulate = Color("f1faee")
	_tag.outline_modulate = Color.BLACK
	_tag.outline_size = 6
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_tag)


func _part(at: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	add_child(mi)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
