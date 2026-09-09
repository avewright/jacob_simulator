extends AnimatableBody3D

# Evan. Grounds crew for the City of Alpharetta, on a riding mower, doing the
# verges. He picks a patch of open grass, drives to it, picks another, and
# leaves cut stripes behind him the whole way.
#
# AnimatableBody3D with sync_to_physics off: he is solid to walk into, but the
# transform we write each frame is the one that sticks. A StaticBody moved every
# frame would thrash the physics server, and sync_to_physics would read the old
# transform straight back and undo the drive.

const SPEED := 3.4
const TURN := 1.5              # rad/s
const ARRIVE := 3.5
const STRIPE_EVERY := 1.1      # metres between cut marks
const MAX_STRIPES := 420       # oldest gets recycled, so this never grows
const HAIL_RANGE := 11.0
const HAIL_GAP := 22.0

const LINES := [
	"Morning. Mind the clippings.",
	"City's got me doing every verge from here to Windward.",
	"You want straight lines you gotta commit to the first pass.",
	"Blade's due a sharpen. She'll hold.",
	"Deck's set at three inches. Anything shorter and it burns.",
	"Somebody parked on the grass again. Not naming names.",
	"Twelve acres today. Twelve. And they call it a half day.",
]

var _target := Vector3.ZERO
var _heading: float = 0.0
var _since_stripe: float = 0.0
var _last_stripe := Vector3.ZERO
var _stripes: Array[MeshInstance3D] = []
var _stripe_at: int = 0
var _hail_cool: float = 0.0
var _stuck: float = 0.0
var _rng := RandomNumberGenerator.new()
var _wheels: Array[Node3D] = []
var _stripe_mat: StandardMaterial3D
var _world: Node = null


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	add_to_group("evan")
	_rng.randomize()
	_stripe_mat = StandardMaterial3D.new()
	_stripe_mat.albedo_color = Color("6f9a3e")
	_stripe_mat.roughness = 0.95
	_build_mower()
	_build_evan()
	_collider()
	_heading = rotation.y
	_last_stripe = global_position
	_target = global_position


func _physics_process(delta: float) -> void:
	if GameState.is_paused:
		return
	if global_position.distance_to(_target) < ARRIVE:
		_pick_target()
	_drive(delta)
	_hail(delta)


# ------------------------------------------------------------------ driving

func _builder() -> Node:
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("world_builder")
	return _world


## Can he get there? Roads included — crossing a street is fine.
func _drivable(world: Node, x: float, z: float, clearance: float) -> bool:
	if world == null or not world.has_method("is_drivable"):
		return true
	return world.is_drivable(x, z, clearance)


## Is there grass to cut there? Somewhere worth heading for.
func _grass(world: Node, x: float, z: float, clearance: float) -> bool:
	if world == null or not world.has_method("is_mowable"):
		return true
	return world.is_mowable(x, z, clearance)


## Somewhere on open grass, preferring a patch a decent distance off so he
## actually crosses town rather than shuffling on the spot.
##
## The endpoint has to be grass — that is the point of going — but the line
## only has to be drivable, so a verge across the street is fair game. Checking
## the whole line matters: picking on the endpoint alone sends him at buildings
## he then bounces off, and he spends half his time nosed into a wall.
func _pick_target() -> void:
	var world := _builder()
	for attempt in 40:
		var ang := _rng.randf() * TAU
		var far := _rng.randf_range(28.0, 110.0)
		var p := global_position + Vector3(cos(ang) * far, 0.0, sin(ang) * far)
		p.x = clampf(p.x, -280.0, 280.0)
		p.z = clampf(p.z, -280.0, 280.0)
		if not _grass(world, p.x, p.z, 3.0):
			continue
		var steps := maxi(3, int(far / 8.0))
		var clear := true
		for k in range(1, steps + 1):
			var t := float(k) / float(steps)
			var q := global_position.lerp(p, t)
			if not _drivable(world, q.x, q.z, 2.6):
				clear = false
				break
		if not clear:
			continue
		_target = Vector3(p.x, 0.0, p.z)
		_stuck = 0.0
		return
	# Nothing open in reach: creep forward and try again next arrival.
	_target = global_position + Vector3(sin(_heading), 0.0, cos(_heading)) * 12.0


func _drive(delta: float) -> void:
	var to := _target - global_position
	var want := atan2(to.x, to.z)
	_heading = _turn_toward(_heading, want, TURN * delta)

	var facing := absf(wrapf(want - _heading, -PI, PI))
	# Slow into a turn rather than carving sideways across the grass.
	var speed: float = SPEED * clampf(1.2 - facing, 0.25, 1.0)
	var step := Vector3(sin(_heading), 0.0, cos(_heading)) * speed * delta

	var world := _builder()
	var ahead := global_position + step.normalized() * 2.6
	if not _drivable(world, ahead.x, ahead.z, 2.2):
		# About to run onto tarmac or into a wall. Peel off toward whichever
		# side is actually open rather than always swinging the same way.
		_stuck += delta
		var left := global_position + Vector3(sin(_heading - 0.9), 0.0, cos(_heading - 0.9)) * 2.6
		var right := global_position + Vector3(sin(_heading + 0.9), 0.0, cos(_heading + 0.9)) * 2.6
		var go_left := _drivable(world, left.x, left.z, 2.2) and not _drivable(world, right.x, right.z, 2.2)
		_heading += TURN * delta * (-1.6 if go_left else 1.6)
		if _stuck > 0.6:
			_pick_target()
		return
	_stuck = 0.0

	global_position += step
	global_position.y = 0.0
	rotation.y = _heading

	for i in _wheels.size():
		_wheels[i].rotate_x(speed * delta * (2.6 if i < 2 else 4.4))

	_since_stripe += step.length()
	if _since_stripe >= STRIPE_EVERY:
		# Blade only goes down on grass. No stripes across the tarmac.
		if _grass(world, global_position.x, global_position.z, 0.6):
			_cut(global_position)
		_since_stripe = 0.0


func _turn_toward(from: float, to: float, most: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -most, most)


## A cut stripe on the grass. Recycled once the pool is full so an afternoon of
## mowing does not slowly fill the scene with meshes.
func _cut(at: Vector3) -> void:
	var mi: MeshInstance3D
	if _stripes.size() < MAX_STRIPES:
		mi = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.2, 0.02, STRIPE_EVERY + 0.5)
		mi.mesh = box
		mi.material_override = _stripe_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(mi)
		_stripes.append(mi)
	else:
		mi = _stripes[_stripe_at]
		_stripe_at = (_stripe_at + 1) % MAX_STRIPES
	mi.global_position = Vector3(at.x, 0.03, at.z)
	mi.rotation.y = _heading
	_last_stripe = at


func _hail(delta: float) -> void:
	_hail_cool = maxf(_hail_cool - delta, 0.0)
	if _hail_cool > 0.0:
		return
	# GameState.here() rather than the player node: Jacob stays parked where he
	# got in, so in the car that position is stale and Evan would shout at a
	# spot you left ten minutes ago.
	if global_position.distance_to(GameState.here()) > HAIL_RANGE:
		return
	GameState.notice.emit("Evan: %s" % LINES[_rng.randi_range(0, LINES.size() - 1)])
	_hail_cool = HAIL_GAP


# ------------------------------------------------------------------ the build

func _collider() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.8, 2.4)
	col.shape = shape
	col.position.y = 0.9
	add_child(col)


func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(centre: Vector3, size: Vector3, material: Material, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = centre
	mi.rotation.y = yaw
	add_child(mi)
	return mi


func _wheel(centre: Vector3, radius: float, width: float) -> void:
	var hub := Node3D.new()
	hub.position = centre
	add_child(hub)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = width
	cyl.radial_segments = 14
	mi.mesh = cyl
	mi.material_override = _mat(Color("15171a"), 0.9)
	mi.rotation.z = PI * 0.5
	hub.add_child(mi)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = radius * 0.45
	rc.bottom_radius = radius * 0.45
	rc.height = width + 0.03
	rc.radial_segments = 10
	rim.mesh = rc
	rim.material_override = _mat(Color("c9c9cc"), 0.4, 0.6)
	rim.rotation.z = PI * 0.5
	hub.add_child(rim)
	_wheels.append(hub)


## Green zero-turn rider: cutting deck out front, engine and grass box behind
## the seat, the whole thing about the size of a quad bike.
func _build_mower() -> void:
	var green := _mat(Color("2f6b2a"), 0.6)
	var dark := _mat(Color("1d2b1c"), 0.7)
	var steel := _mat(Color("9aa0a6"), 0.4, 0.6)
	var seat := _mat(Color("16181b"), 0.75)
	var amber := _mat(Color("e6a020"), 0.5)

	# Cutting deck, low and forward, with the chute on the right.
	_box(Vector3(0, 0.22, 1.05), Vector3(1.55, 0.26, 0.95), green)
	_box(Vector3(0, 0.09, 1.05), Vector3(1.62, 0.06, 1.0), dark)
	_box(Vector3(0.82, 0.24, 0.95), Vector3(0.28, 0.24, 0.5), green, 0.35)
	# Chassis and footplate.
	_box(Vector3(0, 0.42, 0.1), Vector3(0.95, 0.14, 1.9), dark)
	_box(Vector3(0, 0.5, 0.62), Vector3(0.8, 0.05, 0.7), steel)
	# Engine cowl and grass box behind the seat.
	_box(Vector3(0, 0.62, -0.75), Vector3(1.0, 0.55, 0.85), green)
	_box(Vector3(0, 0.98, -0.78), Vector3(0.86, 0.2, 0.7), dark)
	_box(Vector3(0.3, 1.06, -0.62), Vector3(0.09, 0.34, 0.09), steel)
	# Seat.
	_box(Vector3(0, 0.66, -0.1), Vector3(0.62, 0.12, 0.55), seat)
	_box(Vector3(0, 0.95, -0.36), Vector3(0.62, 0.5, 0.12), seat)
	# Steering column and wheel.
	_box(Vector3(0, 0.78, 0.55), Vector3(0.1, 0.55, 0.1), dark, 0.0)
	var wheel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.14
	tor.outer_radius = 0.2
	wheel.mesh = tor
	wheel.material_override = dark
	wheel.position = Vector3(0, 1.04, 0.6)
	wheel.rotation.x = deg_to_rad(72.0)
	add_child(wheel)
	# Roll bar, because the city insists.
	_box(Vector3(-0.42, 1.35, -0.5), Vector3(0.08, 1.0, 0.08), amber)
	_box(Vector3(0.42, 1.35, -0.5), Vector3(0.08, 1.0, 0.08), amber)
	_box(Vector3(0, 1.82, -0.5), Vector3(0.92, 0.08, 0.08), amber)

	_wheel(Vector3(-0.58, 0.36, -0.62), 0.36, 0.24)
	_wheel(Vector3(0.58, 0.36, -0.62), 0.36, 0.24)
	_wheel(Vector3(-0.5, 0.2, 0.72), 0.2, 0.16)
	_wheel(Vector3(0.5, 0.2, 0.72), 0.2, 0.16)


## Evan on the seat: blond, pale, city polo and shorts, hands on the wheel.
func _build_evan() -> void:
	var skin := _mat(Color("f0c9a8"), 0.75)
	var hair := _mat(Color("e3c06a"), 0.8)
	var polo := _mat(Color("3d6b8f"), 0.8)
	var shorts := _mat(Color("6f6a58"), 0.85)
	var boot := _mat(Color("3a2c22"), 0.8)

	var sit := Vector3(0, 0, -0.1)
	# Torso, leaning very slightly forward into the wheel.
	_box(sit + Vector3(0, 1.06, 0.02), Vector3(0.46, 0.56, 0.28), polo)
	_box(sit + Vector3(0, 0.78, 0.06), Vector3(0.44, 0.16, 0.3), shorts)
	# Thighs forward to the footplate, shins down to it.
	_box(sit + Vector3(-0.14, 0.76, 0.36), Vector3(0.17, 0.16, 0.6), shorts)
	_box(sit + Vector3(0.14, 0.76, 0.36), Vector3(0.17, 0.16, 0.6), shorts)
	_box(sit + Vector3(-0.14, 0.6, 0.64), Vector3(0.15, 0.36, 0.16), skin)
	_box(sit + Vector3(0.14, 0.6, 0.64), Vector3(0.15, 0.36, 0.16), skin)
	_box(sit + Vector3(-0.14, 0.43, 0.7), Vector3(0.16, 0.1, 0.3), boot)
	_box(sit + Vector3(0.14, 0.43, 0.7), Vector3(0.16, 0.1, 0.3), boot)
	# Arms out to the wheel.
	_box(sit + Vector3(-0.29, 1.12, 0.3), Vector3(0.13, 0.13, 0.52), polo, -0.18)
	_box(sit + Vector3(0.29, 1.12, 0.3), Vector3(0.13, 0.13, 0.52), polo, 0.18)
	_box(sit + Vector3(-0.19, 1.1, 0.66), Vector3(0.11, 0.11, 0.14), skin)
	_box(sit + Vector3(0.19, 1.1, 0.66), Vector3(0.11, 0.11, 0.14), skin)
	# Head, and a blond mop with a bit of shape to it.
	_box(sit + Vector3(0, 1.45, 0.02), Vector3(0.14, 0.14, 0.14), skin)
	_box(sit + Vector3(0, 1.62, 0.02), Vector3(0.26, 0.28, 0.25), skin)
	_box(sit + Vector3(0, 1.78, 0.02), Vector3(0.28, 0.1, 0.27), hair)
	_box(sit + Vector3(0, 1.72, -0.1), Vector3(0.28, 0.16, 0.09), hair)
	_box(sit + Vector3(-0.15, 1.72, 0.0), Vector3(0.05, 0.16, 0.22), hair)
	_box(sit + Vector3(0.15, 1.72, 0.0), Vector3(0.05, 0.16, 0.22), hair)
	_box(sit + Vector3(0, 1.74, 0.13), Vector3(0.24, 0.09, 0.06), hair)

	var tag := Label3D.new()
	tag.text = "Evan — City Grounds"
	tag.position = Vector3(0, 2.15, -0.5)
	tag.font_size = 26
	tag.modulate = Color("d8e8c0")
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 6
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
