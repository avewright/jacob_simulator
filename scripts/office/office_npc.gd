extends StaticBody3D

const RANGE := 3.2

var npc_name: String = "Coworker"
var lines: Array = []
var _next: int = 0


func setup(display_name: String, say: Array, shirt: Color) -> void:
	npc_name = display_name
	lines = say
	_build(shirt)


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


func _build(shirt: Color) -> void:
	var skin := _mat(Color("d9a884"), 0.8)
	var trousers := _mat(Color("2b3038"), 0.7)

	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.32
	caps.height = 1.72
	col.shape = caps
	col.position.y = 0.86
	add_child(col)

	_part(Vector3(0, 0.42, 0), Vector3(0.44, 0.84, 0.28), trousers)
	_part(Vector3(0, 1.15, 0), Vector3(0.56, 0.66, 0.32), _mat(shirt, 0.65))
	_part(Vector3(-0.36, 1.14, 0), Vector3(0.16, 0.62, 0.22), _mat(shirt, 0.65))
	_part(Vector3(0.36, 1.14, 0), Vector3(0.16, 0.62, 0.22), _mat(shirt, 0.65))
	_part(Vector3(0, 1.62, 0), Vector3(0.3, 0.32, 0.28), skin)

	var tag := Label3D.new()
	tag.text = npc_name
	tag.position = Vector3(0, 2.0, 0)
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
