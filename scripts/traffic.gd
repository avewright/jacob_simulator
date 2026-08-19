extends Node3D

const COLORS := [
	Color("3a86ff"), Color("ff0055"), Color("ffd166"),
	Color("06d6a0"), Color("7a5cff"), Color.WHITE, Color("444444"),
]

var _cars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 8:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.75, 0.55, 3.8)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[i % COLORS.size()]
		mat.roughness = 0.32
		mat.metallic = 0.22
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.4
		mesh.material_override = mat
		var cabin := MeshInstance3D.new()
		var cbox := BoxMesh.new()
		cbox.size = Vector3(1.55, 0.42, 1.6)
		cabin.mesh = cbox
		cabin.position = Vector3(0, 0.42, -0.15)
		cabin.material_override = mat
		mesh.add_child(cabin)
		var along_ns := rng.randf() < 0.5
		var pos := Vector3.ZERO
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		if along_ns:
			pos = Vector3([0.0, -140.0, 90.0][rng.randi_range(0, 2)], 0.55, rng.randf_range(-300, 300))
		else:
			pos = Vector3(rng.randf_range(-300, 300), 0.55, [-48.0, 48.0, 160.0][rng.randi_range(0, 2)])
		mesh.position = pos
		add_child(mesh)
		_cars.append({
			"mesh": mesh,
			"ns": along_ns,
			"dir": dir,
			"speed": 12.0 + rng.randf() * 8.0,
		})


func _process(delta: float) -> void:
	for car in _cars:
		var mesh: MeshInstance3D = car.mesh
		if car.ns:
			mesh.position.z += car.dir * car.speed * delta
			mesh.rotation.y = 0.0 if car.dir > 0.0 else PI
			if absf(mesh.position.z) > 340.0:
				car.dir *= -1.0
		else:
			mesh.position.x += car.dir * car.speed * delta
			mesh.rotation.y = PI * 0.5 if car.dir > 0.0 else -PI * 0.5
			if absf(mesh.position.x) > 340.0:
				car.dir *= -1.0
