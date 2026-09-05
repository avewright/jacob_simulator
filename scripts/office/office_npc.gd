extends StaticBody3D

const RANGE := 3.2

var npc_name: String = "Coworker"
var lines: Array = []
var _next: int = 0


## `spec` keys: name, lines, shirt. Optional: hair (Color; omit for bald),
## hat ("cowboy"), glasses (bool), skin (Color), trousers (Color).
func setup(spec: Dictionary) -> void:
	npc_name = String(spec.get("name", "Coworker"))
	lines = spec.get("lines", [])
	_build(spec)


func in_range(who: Node3D) -> bool:
	if who == null:
		return false
	# The tower stacks people directly above each other, so height has to count
	# or you get prompted for whoever is one floor up.
	if absf(who.global_position.y - global_position.y) > 2.5:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func talk() -> void:
	if lines.is_empty():
		return
	GameState.notice.emit("%s: %s" % [npc_name.split(" —")[0], lines[_next % lines.size()]])
	_next += 1


func _build(spec: Dictionary) -> void:
	var skin := _mat(spec.get("skin", Color("d9a884")), 0.8)
	var trousers := _mat(spec.get("trousers", Color("2b3038")), 0.7)
	var shirt := _mat(spec.get("shirt", Color("1d3557")), 0.65)

	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.32
	caps.height = 1.72
	col.shape = caps
	col.position.y = 0.86
	add_child(col)

	_part(Vector3(0, 0.42, 0), Vector3(0.44, 0.84, 0.28), trousers)
	_part(Vector3(0, 1.15, 0), Vector3(0.56, 0.66, 0.32), shirt)
	_part(Vector3(-0.36, 1.14, 0), Vector3(0.16, 0.62, 0.22), shirt)
	_part(Vector3(0.36, 1.14, 0), Vector3(0.16, 0.62, 0.22), shirt)
	_part(Vector3(0, 1.62, 0), Vector3(0.3, 0.32, 0.28), skin)

	# Hair. No "hair" key at all means bald — Ralph stays bald.
	if spec.has("hair"):
		var hair := _mat(spec.hair, 0.85)
		_part(Vector3(0, 1.79, 0), Vector3(0.32, 0.09, 0.3), hair)
		_part(Vector3(0, 1.68, -0.145), Vector3(0.32, 0.24, 0.05), hair)
		_part(Vector3(-0.155, 1.68, 0), Vector3(0.05, 0.24, 0.3), hair)
		_part(Vector3(0.155, 1.68, 0), Vector3(0.05, 0.24, 0.3), hair)

	if spec.get("glasses", false):
		var frame := _mat(Color("22262c"), 0.4)
		_part(Vector3(-0.085, 1.65, 0.145), Vector3(0.11, 0.09, 0.02), frame)
		_part(Vector3(0.085, 1.65, 0.145), Vector3(0.11, 0.09, 0.02), frame)
		_part(Vector3(0, 1.65, 0.145), Vector3(0.07, 0.02, 0.02), frame)

	if spec.get("hat", "") == "cowboy":
		var felt := _mat(Color("6b4a2f"), 0.9)
		# Wide brim, then the crown with its pinched dent.
		_part(Vector3(0, 1.82, 0), Vector3(0.62, 0.05, 0.58), felt)
		_part(Vector3(0, 1.93, 0), Vector3(0.3, 0.2, 0.28), felt)
		_part(Vector3(0, 1.87, 0), Vector3(0.33, 0.05, 0.31), _mat(Color("3b2a1c"), 0.8))
		# Boots to finish the look.
		for bx in [-0.13, 0.13]:
			_part(Vector3(bx, 0.12, 0.02), Vector3(0.17, 0.24, 0.32), felt)

	var tag := Label3D.new()
	tag.text = npc_name
	tag.position = Vector3(0, 2.12, 0)
	tag.font_size = 28
	tag.modulate = Color("f1faee")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)


func _part(at: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	add_child(mi)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
