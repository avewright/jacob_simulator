extends CharacterBody3D

const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.0
const ACCEL := 32.0
const FRICTION := 42.0
const JUMP_VELOCITY := 5.0
const TURN_SPEED := 7.2
const CAR_RANGE := 10.0

@onready var visuals: JacobLook = $Visuals

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam: Node3D


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	_cam = get_tree().get_first_node_in_group("camera_rig")
	if GameState.load_from_save:
		global_position = GameState.saved_player
	_set_on_foot(true)
	visuals.set_clothed(GameState.has_clothes)
	GameState.clothes_changed.connect(visuals.set_clothed)


func _physics_process(delta: float) -> void:
	if GameState.in_car or GameState.is_paused:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := _cam_wish(input_dir)
	var sprinting := Input.is_action_pressed("sprint")
	var max_speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length_squared() > 0.001:
		planar = planar.move_toward(wish * max_speed, ACCEL * delta)
		var target_yaw := atan2(wish.x, wish.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))
	else:
		planar = planar.move_toward(Vector3.ZERO, FRICTION * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	move_and_slide()
	global_position.x = clampf(global_position.x, -360.0, 360.0)
	global_position.z = clampf(global_position.z, -360.0, 360.0)
	visuals.animate(velocity, is_on_floor(), sprinting, wish.length_squared() > 0.001, delta)
	_update_prompt()
	if Input.is_action_just_pressed("interact"):
		if _try_enter_car():
			return
		var missions := get_tree().get_first_node_in_group("mission_system")
		if missions and missions.has_method("try_interact"):
			missions.try_interact()


func _cam_wish(input_dir: Vector2) -> Vector3:
	if input_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	var look := Vector3.FORWARD
	if _cam:
		look = -_cam.global_transform.basis.z
	look.y = 0.0
	if look.length_squared() < 0.0001:
		look = Vector3.FORWARD
	else:
		look = look.normalized()
	var right := look.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var wish := look * -input_dir.y + right * input_dir.x
	if wish.length_squared() > 0.0001:
		return wish.normalized()
	return Vector3.ZERO


func _update_prompt() -> void:
	var car := get_tree().get_first_node_in_group("camry")
	if car and car.has_method("in_enter_range") and car.in_enter_range():
		GameState.prompt = "E  Enter Camry"
		return
	var shop := get_tree().get_first_node_in_group("clothing_shop") as Node3D
	if shop and not GameState.has_clothes and global_position.distance_to(shop.global_position) < 7.0:
		GameState.prompt = "E  Buy clothes — $%d" % GameState.CLOTHES_COST
		return
	GameState.prompt = ""


func _try_enter_car() -> bool:
	var car := get_tree().get_first_node_in_group("camry")
	if car and car.has_method("try_enter"):
		return bool(car.try_enter())
	return false


func _set_on_foot(enabled: bool) -> void:
	visible = enabled
	collision_layer = 2 if enabled else 0
	collision_mask = 1 if enabled else 0
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if not enabled:
		GameState.prompt = ""


func enter_car() -> void:
	_set_on_foot(false)


func exit_car(at: Vector3, yaw: float) -> void:
	global_position = at
	visuals.rotation.y = yaw
	velocity = Vector3.ZERO
	_set_on_foot(true)
