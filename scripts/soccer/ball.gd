extends RigidBody3D

const PICKUP_RANGE := 1.15

var carrier: CharacterBody3D
var lockout: float = 0.0


func _ready() -> void:
	add_to_group("soccer_ball")
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.96, 0.96, 0.94)
		mat.roughness = 0.35
		mesh.material_override = mat


func facing_of(body: CharacterBody3D) -> Vector3:
	if body.has_method("facing_dir"):
		return body.facing_dir()
	var f := -body.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.001 else Vector3.FORWARD


func possess(who: CharacterBody3D) -> void:
	if carrier == who:
		return
	if carrier and carrier.has_method("set_has_ball"):
		carrier.set_has_ball(false)
	carrier = who
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if who.has_method("set_has_ball"):
		who.set_has_ball(true)


func release(impulse: Vector3) -> void:
	if carrier and carrier.has_method("set_has_ball"):
		carrier.set_has_ball(false)
	carrier = null
	freeze = false
	lockout = 0.28
	apply_central_impulse(impulse)


func loose(nudge: Vector3 = Vector3.ZERO) -> void:
	release(nudge + Vector3(0, 1.4, 0))


func _physics_process(delta: float) -> void:
	lockout = maxf(0.0, lockout - delta)
	if carrier and is_instance_valid(carrier):
		var f := facing_of(carrier)
		global_position = carrier.global_position + f * 0.88 + Vector3(0, 0.4, 0)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	carrier = null
	if lockout > 0.0:
		return
	_try_pickup()


func _try_pickup() -> void:
	var best: CharacterBody3D
	var best_d := PICKUP_RANGE
	for node in get_tree().get_nodes_in_group("striker"):
		var s := node as CharacterBody3D
		if s == null or not s.has_method("can_take_ball"):
			continue
		if not s.can_take_ball():
			continue
		var d := global_position.distance_to(s.global_position + Vector3(0, 0.4, 0))
		if d < best_d:
			best_d = d
			best = s
	if best:
		possess(best)
