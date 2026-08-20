extends Node3D


func _ready() -> void:
	add_to_group("clothing_shop")
	_build()


func in_range(who: Node3D) -> bool:
	return who != null and who.global_position.distance_to(global_position) < 7.0


func _build() -> void:
	var brick := _mat(Color("8a5a44"), 0.82)
	var navy := _mat(Color("1d3557"), 0.45)
	var glass := _mat(Color(0.55, 0.75, 0.9, 0.35), 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cream := _mat(Color("f1faee"), 0.5)
	var gold := _mat(Color("e9c46a"), 0.4, 0.2)

	_box(Vector3(2.0, 1.9, 0.0), Vector3(4.0, 3.8, 6.2), brick)
	_box(Vector3(2.0, 3.9, 0.0), Vector3(4.4, 0.22, 6.6), navy)
	_box(Vector3(-0.12, 1.55, -1.5), Vector3(0.08, 2.2, 2.2), glass)
	_box(Vector3(-0.12, 1.55, 1.6), Vector3(0.08, 2.2, 2.0), glass)
	_box(Vector3(-0.18, 1.15, 0.05), Vector3(0.1, 2.3, 1.1), navy)
	_box(Vector3(-0.7, 3.35, 0.0), Vector3(1.6, 0.08, 6.4), navy)
	_box(Vector3(0.15, 0.55, -2.4), Vector3(0.35, 1.1, 0.35), cream)
	_box(Vector3(0.15, 0.55, 2.4), Vector3(0.35, 1.1, 0.35), cream)
	_box(Vector3(0.15, 1.2, -2.4), Vector3(0.5, 0.12, 0.5), gold)
	_box(Vector3(0.15, 1.2, 2.4), Vector3(0.5, 0.12, 0.5), gold)

	var sign := Label3D.new()
	sign.text = "MEN'S WEAR\n$%d" % GameState.CLOTHES_COST
	sign.position = Vector3(-0.35, 3.15, 0.0)
	sign.font_size = 64
	sign.modulate = Color("ffb703")
	sign.outline_modulate = Color.BLACK
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


func _box(pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
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
