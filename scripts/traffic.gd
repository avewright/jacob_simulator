extends Node3D

const COLORS := [
	Color("3a86ff"), Color("ff0055"), Color("ffd166"),
	Color("06d6a0"), Color("7a5cff"), Color.WHITE, Color("444444"),
]
# Road centre + asphalt width. Lane centre sits a quarter width off the
# middle line, so a car never straddles the yellow dashes.
const ROADS_NS := [[0.0, 28.0], [-140.0, 14.0], [90.0, 12.0]]
const ROADS_EW := [[-48.0, 14.0], [48.0, 14.0], [160.0, 12.0]]

var _cars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 8:
		var along_ns := rng.randf() < 0.5
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		var road: Array = (ROADS_NS if along_ns else ROADS_EW)[rng.randi_range(0, 2)]
		var lane: float = road[1] * 0.25

		var car := AnimatableBody3D.new()
		car.collision_layer = 4
		car.collision_mask = 0
		# sync_to_physics makes the body read its transform back from the physics
		# server, which silently discards the position we write each frame.
		car.sync_to_physics = false
		car.add_to_group("traffic")

		var shape := BoxShape3D.new()
		shape.size = Vector3(1.75, 0.55, 3.8)
		var col := CollisionShape3D.new()
		col.shape = shape
		car.add_child(col)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[i % COLORS.size()]
		mat.roughness = 0.32
		mat.metallic = 0.22
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.4

		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.75, 0.55, 3.8)
		mesh.mesh = box
		mesh.material_override = mat
		car.add_child(mesh)

		var cabin := MeshInstance3D.new()
		var cbox := BoxMesh.new()
		cbox.size = Vector3(1.55, 0.42, 1.6)
		cabin.mesh = cbox
		cabin.position = Vector3(0, 0.42, -0.15)
		cabin.material_override = mat
		car.add_child(cabin)

		# Only watches for Jacob on foot; the Camry collides with the body itself.
		var hit := Area3D.new()
		hit.collision_layer = 0
		hit.collision_mask = 2
		var hcol := CollisionShape3D.new()
		var hshape := BoxShape3D.new()
		hshape.size = Vector3(2.1, 1.6, 4.1)
		hcol.shape = hshape
		hit.add_child(hcol)
		car.add_child(hit)

		var entry := {
			"car": car,
			"ns": along_ns,
			"dir": dir,
			"axis": road[0],
			"lane": lane,
			"speed": 12.0 + rng.randf() * 8.0,
		}
		hit.body_entered.connect(_on_hit.bind(entry))

		if along_ns:
			car.position = Vector3(road[0], 0.55, rng.randf_range(-300, 300))
		else:
			car.position = Vector3(rng.randf_range(-300, 300), 0.55, road[0])
		add_child(car)
		_place(entry)
		_cars.append(entry)


func _physics_process(delta: float) -> void:
	for entry in _cars:
		var car: AnimatableBody3D = entry.car
		var turned := false
		if entry.ns:
			car.position.z += entry.dir * entry.speed * delta
			if absf(car.position.z) > 340.0:
				entry.dir *= -1.0
				turned = true
		else:
			car.position.x += entry.dir * entry.speed * delta
			if absf(car.position.x) > 340.0:
				entry.dir *= -1.0
				turned = true
		_place(entry)
		if turned:
			# Swapping lanes is a jump, not motion — don't interpolate across it.
			car.reset_physics_interpolation()


func _place(entry: Dictionary) -> void:
	# right = forward.cross(UP), so the lane offset always lands on the car's
	# own right-hand side and flips with it when it turns around.
	var car: AnimatableBody3D = entry.car
	var forward := Vector3(0, 0, entry.dir) if entry.ns else Vector3(entry.dir, 0, 0)
	var right := forward.cross(Vector3.UP)
	if entry.ns:
		car.position.x = entry.axis + right.x * entry.lane
		car.rotation.y = 0.0 if entry.dir > 0.0 else PI
	else:
		car.position.z = entry.axis + right.z * entry.lane
		car.rotation.y = PI * 0.5 if entry.dir > 0.0 else -PI * 0.5


func _on_hit(body: Node3D, entry: Dictionary) -> void:
	if not body.is_in_group("player") or not body.has_method("hit_by_car"):
		return
	var forward := Vector3(0, 0, entry.dir) if entry.ns else Vector3(entry.dir, 0, 0)
	body.hit_by_car(forward, entry.speed)
