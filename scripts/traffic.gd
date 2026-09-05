extends Node3D

# Right-hand traffic on the grid. Cars are built from a shared body plan with
# per-type proportions, so a sedan, a hatch, a pickup and a Suburban all read
# differently at a glance.
#
# One of them drives badly on purpose.

const COLORS := [
	Color("3a86ff"), Color("ff0055"), Color("ffd166"),
	Color("06d6a0"), Color("7a5cff"), Color.WHITE, Color("444444"),
]
# Road centre + asphalt width. Lane centre sits a quarter width off the middle
# line, so a car never straddles the yellow dashes.
const ROADS_NS := [[0.0, 28.0], [-140.0, 14.0], [90.0, 12.0]]
const ROADS_EW := [[-48.0, 14.0], [48.0, 14.0], [160.0, 12.0]]

# length, width, body height, cabin length, cabin height, ride height, wheel r
const TYPES := {
	"sedan":    [4.4, 1.78, 0.62, 2.0, 0.5, 0.30, 0.32],
	"hatch":    [3.8, 1.72, 0.60, 1.9, 0.5, 0.28, 0.30],
	"pickup":   [5.4, 1.95, 0.78, 1.7, 0.6, 0.42, 0.38],
	"van":      [5.0, 1.92, 1.30, 3.2, 0.4, 0.34, 0.34],
	"suburban": [5.7, 2.05, 1.05, 3.6, 0.62, 0.44, 0.40],
}

var _cars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var kinds := ["sedan", "hatch", "pickup", "sedan", "van", "hatch", "sedan", "pickup"]
	for i in 8:
		var along_ns := rng.randf() < 0.5
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		var road: Array = (ROADS_NS if along_ns else ROADS_EW)[rng.randi_range(0, 2)]
		var lane: float = road[1] * 0.25
		var kind: String = kinds[i]

		var car := AnimatableBody3D.new()
		car.collision_layer = 4
		car.collision_mask = 0
		# sync_to_physics makes the body read its transform back from the physics
		# server, which silently discards the position we write each frame.
		car.sync_to_physics = false
		car.add_to_group("traffic")
		_build(car, kind, COLORS[i % COLORS.size()])

		# Only watches for Jacob on foot; the Camry collides with the body itself.
		var hit := Area3D.new()
		hit.collision_layer = 0
		hit.collision_mask = 2
		var hcol := CollisionShape3D.new()
		var hshape := BoxShape3D.new()
		var spec: Array = TYPES[kind]
		hshape.size = Vector3(spec[1] + 0.35, 1.8, spec[0] + 0.3)
		hcol.shape = hshape
		hcol.position.y = 0.9
		hit.add_child(hcol)
		car.add_child(hit)

		var entry := {
			"car": car,
			"ns": along_ns,
			"dir": dir,
			"axis": road[0],
			"lane": lane,
			"speed": 12.0 + rng.randf() * 8.0,
			"base": 12.0 + rng.randf() * 8.0,
			"erratic": false,
			"wander": 0.0,
			"phase": rng.randf() * TAU,
			"next": 0.0,
		}
		entry.speed = entry.base
		hit.body_entered.connect(_on_hit.bind(entry))

		if along_ns:
			car.position = Vector3(road[0], 0.0, rng.randf_range(-300, 300))
		else:
			car.position = Vector3(rng.randf_range(-300, 300), 0.0, road[0])
		add_child(car)
		_place(entry)
		_cars.append(entry)

	# The bad driver: a black Suburban on the main avenue that weaves inside its
	# lane, changes its mind about speed, and occasionally lunges.
	var bad := AnimatableBody3D.new()
	bad.collision_layer = 4
	bad.collision_mask = 0
	bad.sync_to_physics = false
	bad.add_to_group("traffic")
	_build(bad, "suburban", Color("14161a"))
	var bhit := Area3D.new()
	bhit.collision_layer = 0
	bhit.collision_mask = 2
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(2.4, 1.9, 6.0)
	bcol.shape = bshape
	bcol.position.y = 0.95
	bhit.add_child(bcol)
	bad.add_child(bhit)
	var bad_entry := {
		"car": bad,
		"ns": true,
		"dir": 1.0,
		"axis": 0.0,
		"lane": 7.0,
		"speed": 18.0,
		"base": 18.0,
		"erratic": true,
		"wander": 0.0,
		"phase": 0.0,
		"next": 2.0,
	}
	bhit.body_entered.connect(_on_hit.bind(bad_entry))
	bad.position = Vector3(0, 0, -60.0)
	add_child(bad)
	_place(bad_entry)
	_cars.append(bad_entry)


func _physics_process(delta: float) -> void:
	for entry in _cars:
		var car: AnimatableBody3D = entry.car
		if entry.erratic:
			_drive_badly(entry, delta)
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


## Weave, surge and brake. Kept inside the lane half-width so it stays on its
## own side of the road — it drives badly, not head-on.
func _drive_badly(entry: Dictionary, delta: float) -> void:
	entry.phase += delta * 1.7
	entry.wander = sin(entry.phase) * 2.1 + sin(entry.phase * 2.3) * 0.9
	entry.next -= delta
	if entry.next <= 0.0:
		entry.next = randf_range(1.2, 3.5)
		# Sometimes floors it, sometimes forgets it is driving.
		if randf() < 0.35:
			entry.base = randf_range(3.0, 7.0)
		else:
			entry.base = randf_range(16.0, 27.0)
		entry.phase += randf_range(-1.0, 1.0)
	entry.speed = move_toward(entry.speed, entry.base, 14.0 * delta)


func _place(entry: Dictionary) -> void:
	# right = forward.cross(UP), so the lane offset always lands on the car's
	# own right-hand side and flips with it when it turns around.
	var car: AnimatableBody3D = entry.car
	var forward := Vector3(0, 0, entry.dir) if entry.ns else Vector3(entry.dir, 0, 0)
	var right := forward.cross(Vector3.UP)
	var drift: float = entry.wander
	if entry.ns:
		car.position.x = entry.axis + right.x * entry.lane + drift
		car.rotation.y = 0.0 if entry.dir > 0.0 else PI
	else:
		car.position.z = entry.axis + right.z * entry.lane + drift
		car.rotation.y = PI * 0.5 if entry.dir > 0.0 else -PI * 0.5
	if entry.erratic:
		# Lean the nose into the weave so it looks like steering, not sliding.
		car.rotation.y += cos(entry.phase) * 0.12 * (1.0 if entry.dir > 0.0 else -1.0)


func _on_hit(body: Node3D, entry: Dictionary) -> void:
	if not body.is_in_group("player") or not body.has_method("hit_by_car"):
		return
	var forward := Vector3(0, 0, entry.dir) if entry.ns else Vector3(entry.dir, 0, 0)
	body.hit_by_car(forward, entry.speed)


# ------------------------------------------------------------------ shapes

func _build(car: AnimatableBody3D, kind: String, tint: Color) -> void:
	var spec: Array = TYPES[kind]
	var length: float = spec[0]
	var width: float = spec[1]
	var body_h: float = spec[2]
	var cab_len: float = spec[3]
	var cab_h: float = spec[4]
	var ride: float = spec[5]
	var wheel_r: float = spec[6]

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, body_h + cab_h, length)
	col.shape = shape
	col.position.y = ride + (body_h + cab_h) * 0.5
	car.add_child(col)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.roughness = 0.32
	paint.metallic = 0.25
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.45
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.11, 0.15, 0.19, 0.72)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.06
	glass.metallic = 0.35
	var rubber := _mat(Color("111111"), 0.92)
	var chrome := _mat(Color("c3c6ca"), 0.25, 0.85)
	var head := _mat(Color("fff3c4"), 0.2)
	head.emission_enabled = true
	head.emission = Color("fff3c4")
	head.emission_energy_multiplier = 1.2
	var tail := _mat(Color("cc2222"), 0.3)
	tail.emission_enabled = true
	tail.emission = Color("cc2222")
	tail.emission_energy_multiplier = 1.4

	var body_y := ride + body_h * 0.5
	_part(car, Vector3(0, body_y, 0), Vector3(width, body_h, length), paint)

	# Cabin: set back on a pickup, stretched over the rear on a van or Suburban.
	var cab_z := 0.0
	if kind == "pickup":
		cab_z = length * 0.16
	elif kind == "van" or kind == "suburban":
		cab_z = -length * 0.06
	var cab_y := ride + body_h + cab_h * 0.5
	_part(car, Vector3(0, cab_y, cab_z), Vector3(width - 0.16, cab_h, cab_len), paint)
	# Glazing.
	_part(car, Vector3(0, cab_y, cab_z + cab_len * 0.5), Vector3(width - 0.3, cab_h - 0.1, 0.06), glass)
	_part(car, Vector3(0, cab_y, cab_z - cab_len * 0.5), Vector3(width - 0.3, cab_h - 0.12, 0.06), glass)
	for sx in [-1.0, 1.0]:
		_part(car, Vector3(sx * (width * 0.5 - 0.09), cab_y, cab_z), Vector3(0.05, cab_h - 0.16, cab_len - 0.3), glass)

	if kind == "pickup":
		# Bed walls behind the cab.
		var bed_z := -length * 0.22
		var bed_len := length * 0.42
		for sx in [-1.0, 1.0]:
			_part(car, Vector3(sx * (width * 0.5 - 0.07), body_y + body_h * 0.42, bed_z), Vector3(0.12, 0.34, bed_len), paint)
		_part(car, Vector3(0, body_y + body_h * 0.42, bed_z - bed_len * 0.5), Vector3(width, 0.34, 0.12), paint)
	if kind == "suburban":
		# Roof rails and a step bar, so it reads as the big one.
		for sx in [-1.0, 1.0]:
			_part(car, Vector3(sx * (width * 0.5 - 0.26), ride + body_h + cab_h + 0.05, cab_z), Vector3(0.08, 0.08, cab_len - 0.5), chrome)
			_part(car, Vector3(sx * (width * 0.5 + 0.03), ride * 0.55, 0), Vector3(0.1, 0.1, length * 0.5), chrome)

	# Bumpers, lights, plate.
	_part(car, Vector3(0, ride + 0.14, length * 0.5), Vector3(width, 0.22, 0.12), chrome)
	_part(car, Vector3(0, ride + 0.14, -length * 0.5), Vector3(width, 0.22, 0.12), chrome)
	for lx in [-1.0, 1.0]:
		_part(car, Vector3(lx * width * 0.33, body_y + body_h * 0.12, length * 0.5 + 0.02), Vector3(width * 0.24, 0.2, 0.08), head)
		_part(car, Vector3(lx * width * 0.33, body_y + body_h * 0.12, -length * 0.5 - 0.02), Vector3(width * 0.2, 0.22, 0.08), tail)

	var wz := length * 0.32
	for wp in [Vector3(-1.0, 0, 1.0), Vector3(1.0, 0, 1.0), Vector3(-1.0, 0, -1.0), Vector3(1.0, 0, -1.0)]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = wheel_r
		cyl.bottom_radius = wheel_r
		cyl.height = 0.26
		wheel.mesh = cyl
		wheel.material_override = rubber
		wheel.rotation_degrees.z = 90.0
		wheel.position = Vector3(wp.x * (width * 0.5 - 0.09), wheel_r, wp.z * wz)
		car.add_child(wheel)
		var rim := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = wheel_r * 0.6
		disc.bottom_radius = wheel_r * 0.6
		disc.height = 0.28
		rim.mesh = disc
		rim.material_override = chrome
		rim.rotation_degrees.z = 90.0
		rim.position = wheel.position
		car.add_child(rim)


func _part(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
