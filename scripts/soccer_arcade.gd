extends Node3D

const RANGE := 7.0


func _ready() -> void:
	add_to_group("soccer_arcade")
	_build()


func in_range(who: Node3D) -> bool:
	if who == null:
		return false
	if absf(who.global_position.y - global_position.y) > 3.0:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func _build() -> void:
	var wall := _mat(Color("14202e"), 0.7)
	var trim := _mat(Color("2a9d8f"), 0.35, 0.25)
	var turf := _mat(Color("2f7d32"), 0.95)
	var glass := _mat(Color(0.4, 0.75, 0.85, 0.4), 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var neon := _mat(Color("ffb703"), 0.3)
	neon.emission_enabled = true
	neon.emission = Color("ffb703")
	neon.emission_energy_multiplier = 3.0

	# Turf apron out front so the entrance reads as a pitch, not a parking lot.
	_mesh(Vector3(0, 0.03, 6.0), Vector3(16.0, 0.06, 9.0), turf)
	_mesh(Vector3(0, 0.05, 6.0), Vector3(0.18, 0.02, 9.0), _mat(Color("f1faee"), 0.6))

	# Shell: back and side walls, roof, glass front with a doorway gap.
	_box(Vector3(0, 0, -4.2), Vector3(16.0, 6.0, 0.4), wall)
	_box(Vector3(-7.8, 0, 0), Vector3(0.4, 6.0, 8.4), wall)
	_box(Vector3(7.8, 0, 0), Vector3(0.4, 6.0, 8.4), wall)
	_box(Vector3(0, 6.0, 0), Vector3(16.8, 0.4, 9.2), trim)
	_box(Vector3(-5.1, 0, 4.2), Vector3(5.4, 4.4, 0.3), glass)
	_box(Vector3(5.1, 0, 4.2), Vector3(5.4, 4.4, 0.3), glass)
	_box(Vector3(0, 4.4, 4.2), Vector3(16.0, 1.6, 0.3), wall)
	_box(Vector3(0, 0, 4.2), Vector3(0.3, 3.0, 0.3), trim)
	_box(Vector3(-2.6, 3.1, 4.35), Vector3(0.22, 0.5, 0.12), neon)
	_box(Vector3(2.6, 3.1, 4.35), Vector3(0.22, 0.5, 0.12), neon)

	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 3.4, 5.4)
	glow.light_color = Color("ffb703")
	glow.light_energy = 2.2
	glow.omni_range = 14.0
	add_child(glow)

	var sign := Label3D.new()
	sign.text = "SUPER STRIKERS"
	sign.position = Vector3(0, 5.1, 4.5)
	sign.font_size = 72
	sign.modulate = Color("ffb703")
	sign.outline_modulate = Color.BLACK
	sign.outline_size = 10
	add_child(sign)

	var tag := Label3D.new()
	tag.name = "EnterTag"
	tag.text = "E  PLAY SUPER STRIKERS"
	tag.position = Vector3(0, 2.4, 5.6)
	tag.font_size = 44
	tag.modulate = Color("f1faee")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)


func _box(pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	add_child(body)


func _mesh(pos: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
