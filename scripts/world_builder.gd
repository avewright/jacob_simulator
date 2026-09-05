extends Node3D

# Road centre + asphalt width, matching the _roads() calls below.
const ROADS_NS := [[0.0, 28.0], [-140.0, 14.0], [90.0, 12.0]]
const ROADS_EW := [[-48.0, 14.0], [48.0, 14.0], [160.0, 12.0]]
const SIDEWALK := 2.4

var _rng := RandomNumberGenerator.new()
var _buildings: Array[Dictionary] = []
var _office_mat: StandardMaterial3D
var _brick_mat: StandardMaterial3D
var _house_mats: Array[StandardMaterial3D] = []
var _roof_mat: StandardMaterial3D
var _asphalt: StandardMaterial3D
var _concrete: StandardMaterial3D
var _paint: StandardMaterial3D
var _yellow: StandardMaterial3D
var _glass: StandardMaterial3D
var _desk: StandardMaterial3D
var _carpet: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 400400
	_make_mats()
	_ground()
	_roads()
	_work_campus()
	_city()
	_trees()
	_streetlights()
	_parked_cars()
	_pickups()


func _make_mats() -> void:
	_asphalt = _tex_mat(_noise_img(256, Color("2a2e34"), Color("3a3e46"), 0.18), 0.92, 0.05)
	_concrete = _mat(Color("7a7872"), 0.9)
	_paint = _mat(Color("e8e8e8"), 0.35)
	_yellow = _mat(Color("e6c200"), 0.4)
	_roof_mat = _mat(Color("2a2a2e"), 0.7, 0.15)
	_office_mat = _facade_mat(Color("4a5664"), Color("8ec6e8"), true)
	_brick_mat = _facade_mat(Color("6a4534"), Color("1a2230"), false)
	_glass = _mat(Color(0.45, 0.7, 0.85, 0.35), 0.08, 0.2)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_desk = _mat(Color("5a3d2a"), 0.7)
	_carpet = _mat(Color("3a3344"), 0.95)
	for c in [Color("5c4a3c"), Color("4e5a42"), Color("6b5344"), Color("6e5a50")]:
		_house_mats.append(_facade_mat(c, Color("1c2836"), false))


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _tex_mat(tex: Texture2D, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_scale = Vector3(40, 40, 1)
	return m


func _noise_img(size: int, a: Color, b: Color, jitter: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var n := fposmod(sin(x * 0.37 + y * 0.21) * 43758.5453, 1.0)
			var stripe := 0.08 if (x + y) % 17 < 2 else 0.0
			img.set_pixel(x, y, a.lerp(b, clampf(n * jitter + stripe, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _facade_mat(base: Color, window: Color, office: bool) -> StandardMaterial3D:
	var w := 128 if office else 64
	var h := 256 if office else 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var cols := 6 if office else 3
	var rows := 10 if office else 3
	var cw := w / cols
	var rh := h / rows
	for row in rows:
		for col in cols:
			if not office and row == rows - 1 and col == 1:
				continue
			var lit := office and ((row * 7 + col * 3) % 5 == 0)
			var wc := Color("f0d48a") if lit else window
			var x0 := col * cw + 3
			var y0 := row * rh + 3
			for y in range(y0, mini(y0 + rh - 6, h)):
				for x in range(x0, mini(x0 + cw - 6, w)):
					img.set_pixel(x, y, wc)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.55 if office else 0.78
	m.metallic = 0.12 if office else 0.0
	if office:
		m.clearcoat_enabled = true
		m.clearcoat = 0.25
	return m


func _static_box(pos: Vector3, size: Vector3, material: Material, occlude: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mi)
	var roof := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(size.x + 0.6, 0.35, size.z + 0.6)
	roof.mesh = rbox
	roof.position.y = size.y * 0.5 + 0.12
	roof.material_override = _roof_mat
	body.add_child(roof)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	if occlude:
		var occ := OccluderInstance3D.new()
		var box_occ := BoxOccluder3D.new()
		box_occ.size = size
		occ.occluder = box_occ
		body.add_child(occ)
	add_child(body)
	_buildings.append({"x": pos.x, "z": pos.z, "w": size.x, "d": size.z})
	return body


func _mesh_box(pos: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = material
	add_child(mi)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	mi.mesh = plane
	var grass := _tex_mat(_noise_img(256, Color("2d5a28"), Color("4a7a32"), 0.45), 0.95)
	grass.uv1_scale = Vector3(80, 80, 1)
	mi.material_override = grass
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(800, 1, 800)
	col.shape = shape
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)


func _roads() -> void:
	_road(Vector3(0, 0, 0), Vector3(28, 0.1, 780), true)
	_road(Vector3(0, 0, -48), Vector3(780, 0.1, 14), false)
	_road(Vector3(0, 0, 48), Vector3(780, 0.1, 14), false)
	_road(Vector3(0, 0, 160), Vector3(780, 0.1, 12), false)
	_road(Vector3(-140, 0, 0), Vector3(14, 0.1, 780), false)
	_road(Vector3(90, 0, 0), Vector3(12, 0.1, 780), false)


func _road(pos: Vector3, size: Vector3, highway: bool) -> void:
	_mesh_box(pos + Vector3(0, 0.05, 0), size, _asphalt)
	var walk_w := 2.4
	if size.x > size.z:
		_curb(Vector3(pos.x, 0.08, pos.z - size.z * 0.5 - walk_w * 0.5), Vector3(size.x, 0.12, walk_w))
		_curb(Vector3(pos.x, 0.08, pos.z + size.z * 0.5 + walk_w * 0.5), Vector3(size.x, 0.12, walk_w))
	else:
		_curb(Vector3(pos.x - size.x * 0.5 - walk_w * 0.5, 0.08, pos.z), Vector3(walk_w, 0.12, size.z))
		_curb(Vector3(pos.x + size.x * 0.5 + walk_w * 0.5, 0.08, pos.z), Vector3(walk_w, 0.12, size.z))
	if highway:
		var i := -360.0
		while i < 360.0:
			if absf(i) > 18.0:
				_mesh_box(Vector3(pos.x, 0.11, i), Vector3(0.22, 0.04, 5.5), _yellow)
			i += 13.0
	elif size.x > size.z:
		var i := -size.x * 0.45
		while i < size.x * 0.45:
			_mesh_box(Vector3(pos.x + i, 0.11, pos.z), Vector3(3.2, 0.04, 0.16), _paint)
			i += 7.0


func _curb(pos: Vector3, size: Vector3) -> void:
	_mesh_box(pos, size, _concrete)


func _work_campus() -> void:
	_mesh_box(Vector3(18, 0.04, 0), Vector3(28, 0.08, 30), _asphalt)
	for row in 2:
		for stall in 4:
			var z := -10.0 + stall * 6.5
			var x := 10.0 + row * 8.0
			_mesh_box(Vector3(x, 0.09, z), Vector3(5.2, 0.02, 0.08), _paint)
			_mesh_box(Vector3(x, 0.09, z + 2.6), Vector3(5.2, 0.02, 0.08), _paint)
	# Office tower and garage are their own scenes; just reserve their plots
	# and point at the door.
	_sign(Vector3(31.0, 3.4, 0), "WORK\nNORTH POINT")


func _wall(pos: Vector3, size: Vector3) -> void:
	_static_box_raw(pos, size, _office_mat)


func _static_box_raw(pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


func _hedge(pos: Vector3, size: Vector3) -> void:
	_static_box_raw(pos, size, _mat(Color("1a4a1c"), 0.9)).add_to_group("smashable")


func _sign(pos: Vector3, text: String) -> void:
	_static_box_raw(pos + Vector3(0, -2.4, 0), Vector3(0.18, 2.4, 0.18), _mat(Color("222222"), 0.4, 0.2))
	var lab := Label3D.new()
	lab.text = text
	lab.position = pos
	lab.font_size = 72
	lab.modulate = Color("ffb703")
	lab.outline_modulate = Color.BLACK
	lab.outline_size = 8
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)


func _city() -> void:
	for gx in range(-5, -1):
		for gz in range(-3, 4):
			var x := gx * 28.0 - 20.0
			var z := gz * 32.0
			if _blocked(x, z):
				continue
			_static_box(Vector3(x, 0, z), Vector3(16 + _rng.randf() * 6, 18 + _rng.randf() * 22, 14 + _rng.randf() * 6), _office_mat, true)
	for gx in range(4, 8):
		for gz in range(-2, 4):
			var x := gx * 26.0
			var z := gz * 30.0 + 10.0
			if _blocked(x, z):
				continue
			_static_box(Vector3(x, 0, z), Vector3(12 + _rng.randf() * 5, 8 + _rng.randf() * 8, 12 + _rng.randf() * 5), _brick_mat, true)
	for gx in range(-10, 11):
		for gz in range(-10, 11):
			var x := gx * 30.0 + 8.0
			var z := gz * 30.0 + 8.0
			if _blocked(x, z):
				continue
			if _rng.randf() < 0.28:
				continue
			var too_close := false
			for b in _buildings:
				if Vector2(b.x - x, b.z - z).length() < 20.0:
					too_close = true
					break
			if too_close:
				continue
			var lot := Vector3(x, 0.02, z)
			_mesh_box(lot, Vector3(16, 0.04, 16), _mat(Color("355c30"), 0.95))
			_mesh_box(lot + Vector3(-5.5, 0.03, 0), Vector3(4.2, 0.05, 10), _asphalt)
			_static_box(Vector3(x + 1.5, 0, z), Vector3(8.5 + _rng.randf() * 2, 5.2 + _rng.randf() * 2.2, 7.5 + _rng.randf() * 2), _house_mats[abs(gx + gz) % _house_mats.size()])


func _blocked(x: float, z: float) -> bool:
	if _on_road(x, z):
		return true
	if x > 2.0 and x < 58.0 and absf(z) < 22.0:
		return true
	# Super Strikers arcade plot.
	if x > 14.0 and x < 48.0 and z > -40.0 and z < -20.0:
		return true
	# North Point tower plot.
	if x > 30.0 and x < 62.0 and absf(z) < 14.0:
		return true
	# Parking garage plot.
	if x > 30.0 and x < 62.0 and z > 16.0 and z < 40.0:
		return true
	# 5955 Haterleigh Dr and its lot.
	if x > 44.0 and x < 84.0 and z > 56.0 and z < 96.0:
		return true
	# Chastain Place, north of the office across the z=-48 road.
	if x > 34.0 and x < 88.0 and z > -102.0 and z < -54.0:
		return true
	return false


func _on_road(x: float, z: float) -> bool:
	for rx in [0.0, -140.0, 90.0]:
		if absf(x - rx) < 18.0:
			return true
	for rz in [-48.0, 48.0, 160.0]:
		if absf(z - rz) < 12.0:
			return true
	return false


func _on_pavement(x: float, z: float, margin: float = 1.2) -> bool:
	# Tight test against the real asphalt + sidewalk, unlike the conservative
	# _on_road() used to keep buildings off whole blocks.
	for r in ROADS_NS:
		if absf(x - r[0]) < r[1] * 0.5 + SIDEWALK + margin:
			return true
	for r in ROADS_EW:
		if absf(z - r[0]) < r[1] * 0.5 + SIDEWALK + margin:
			return true
	return false


func _tree_collider(x: float, z: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x, 1.6, z)
	body.add_to_group("smashable")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 3.2
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 3.2
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.55
	canopy_mesh.height = 2.4
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	var canopy_mm := MultiMesh.new()
	canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_mm.use_colors = true
	canopy_mm.mesh = canopy_mesh
	var spots: Array[Vector3] = []
	var i := -320.0
	while i <= 320.0:
		if absf(i) > 24.0:
			# Verge trees flank the avenue; skip where a cross street cuts through.
			for side in [-19.0, 19.0]:
				var vx: float = side + _rng.randf_range(-0.8, 0.8)
				if _on_pavement(vx, i) or _blocked(vx, i):
					continue
				spots.append(Vector3(vx, 0, i))
		i += 14.0
	for n in 70:
		var x := _rng.randf_range(-300, 300)
		var z := _rng.randf_range(-300, 300)
		if _blocked(x, z) or _on_pavement(x, z):
			continue
		spots.append(Vector3(x, 0, z))
	trunk_mm.instance_count = spots.size()
	canopy_mm.instance_count = spots.size() * 3
	var greens := [Color("1a5a22"), Color("23702a"), Color("0f4a18")]
	var idx := 0
	for s in spots:
		_tree_collider(s.x, s.z)
		trunk_mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(s.x, 1.6, s.z)))
		for k in 3:
			var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(1.0 + k * 0.12, 0.85, 1.0 + k * 0.12)), Vector3(s.x + _rng.randf_range(-0.4, 0.4), 3.1 + k * 0.7, s.z + _rng.randf_range(-0.4, 0.4)))
			canopy_mm.set_instance_transform(idx * 3 + k, xf)
			canopy_mm.set_instance_color(idx * 3 + k, greens[k])
		idx += 1
	var trunk_i := MultiMeshInstance3D.new()
	trunk_i.multimesh = trunk_mm
	trunk_i.material_override = _mat(Color("4a311f"), 0.92)
	add_child(trunk_i)
	var canopy_i := MultiMeshInstance3D.new()
	canopy_i.multimesh = canopy_mm
	var canopy_mat := _mat(Color.WHITE, 0.86)
	canopy_mat.vertex_color_use_as_albedo = true
	canopy_i.material_override = canopy_mat
	add_child(canopy_i)


func _streetlights() -> void:
	# Each post is its own body now so the Camry can flatten it.
	var lamp_scene := load("res://scripts/street_lamp.gd")
	var i := -300.0
	while i <= 300.0:
		if absf(i) < 22.0:
			i += 36.0
			continue
		for side in [-16.0, 16.0]:
			var post := StaticBody3D.new()
			post.set_script(lamp_scene)
			post.position = Vector3(side, 0, i)
			# Arm points in toward the carriageway.
			post.rotation_degrees.y = 0.0 if side < 0.0 else 180.0
			add_child(post)
		i += 36.0


func _parked_cars() -> void:
	var colors := [Color("2b4c7e"), Color("c4c4c4"), Color("1f1f1f"), Color("8a2a2a")]
	for i in 3:
		var z := -8.0 + i * 6.5
		if i == 1:
			continue
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.7, 0.5, 3.6)
		body.mesh = box
		var mat := _mat(colors[i], 0.3, 0.25)
		mat.clearcoat_enabled = true
		body.material_override = mat
		body.position = Vector3(10.0, 0.4, z)
		add_child(body)


func _pickups() -> void:
	for i in 16:
		var x := _rng.randf_range(-22, 22)
		var z := _rng.randf_range(-300, 300)
		if _rng.randf() < 0.6:
			x = _rng.randf_range(-300, 300)
			z = [-48.0, 48.0, 160.0, 0.0][_rng.randi_range(0, 3)] + _rng.randf_range(-6, 6)
		if _blocked(x, z) and absf(x) > 8.0:
			continue
		var area := Area3D.new()
		area.collision_layer = 8
		area.collision_mask = 6
		area.position = Vector3(x, 0.55, z)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.14, 0.45)
		mi.mesh = box
		var mat := _mat(Color("00c853"), 0.4)
		mat.emission_enabled = true
		mat.emission = Color("00c853")
		mat.emission_energy_multiplier = 1.4
		mi.material_override = mat
		area.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.2
		col.shape = shape
		area.add_child(col)
		area.body_entered.connect(_on_pickup.bind(area))
		add_child(area)


func _on_pickup(body: Node3D, area: Area3D) -> void:
	if area == null or not is_instance_valid(area):
		return
	if not (body.is_in_group("player") or body.is_in_group("camry")):
		return
	GameState.add_money(45)
	GameState.notice.emit("+$45")
	area.queue_free()
