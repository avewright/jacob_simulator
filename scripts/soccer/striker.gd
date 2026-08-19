extends CharacterBody3D

enum Team { HOME, AWAY }

const WALK_SPEED := 7.4
const SPRINT_SPEED := 10.6
const KEEPER_SPEED := 6.4
const ACCEL := 38.0
const FRICTION := 30.0
const TURN_SPEED := 14.0
const CHARGE_MAX := 1.05

@export var team: Team = Team.HOME
@export var is_ai: bool = false
@export var is_keeper: bool = false
@export var is_captain: bool = false

@onready var visuals: JacobLook = $Visuals

var stunned: float = 0.0
var has_ball: bool = false
var facing: Vector3 = Vector3(0, 0, 1)
var punch_cd: float = 0.0
var slam_cd: float = 0.0
var slam_air: bool = false
var charge: float = 0.0
var charging: bool = false
var kick_cd: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam: Node3D
var _spawn: Vector3


func _ready() -> void:
	add_to_group("striker")
	if is_captain:
		add_to_group("player")
		add_to_group("captain")
	_spawn = global_position
	_cam = get_tree().get_first_node_in_group("camera_rig")
	facing = Vector3(0, 0, 1) if team == Team.HOME else Vector3(0, 0, -1)
	if visuals:
		var tint := Color(0.2, 0.42, 0.88) if team == Team.HOME else Color(0.82, 0.16, 0.16)
		if is_keeper:
			tint = tint.darkened(0.25)
		visuals.apply_team(tint)


func facing_dir() -> Vector3:
	return facing


func set_has_ball(value: bool) -> void:
	has_ball = value


func can_take_ball() -> bool:
	return stunned <= 0.0 and not is_keeper


func reset_to_spawn() -> void:
	global_position = _spawn
	velocity = Vector3.ZERO
	stunned = 0.0
	has_ball = false
	charge = 0.0
	charging = false
	slam_air = false


func hit(knock: Vector3, stun_time: float) -> void:
	stunned = maxf(stunned, stun_time)
	velocity += knock
	velocity.y = maxf(velocity.y, 2.2)
	charging = false
	charge = 0.0
	var ball := _ball()
	if has_ball and ball:
		ball.loose(knock * 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if is_ai or GameState.is_paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			charging = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_punch()


func _physics_process(delta: float) -> void:
	punch_cd = maxf(0.0, punch_cd - delta)
	slam_cd = maxf(0.0, slam_cd - delta)
	kick_cd = maxf(0.0, kick_cd - delta)
	stunned = maxf(0.0, stunned - delta)

	if not is_on_floor():
		velocity.y -= _gravity * 1.15 * delta
	elif slam_air:
		slam_air = false
		_slam_impact()

	var wish := Vector3.ZERO
	var sprinting := false
	if stunned <= 0.0 and not GameState.is_paused:
		if is_ai:
			wish = _ai_wish()
			sprinting = wish.length_squared() > 0.4
			_ai_acts(delta)
		else:
			wish = _player_wish()
			sprinting = Input.is_action_pressed("sprint")
			_player_acts(delta)

	var max_speed := KEEPER_SPEED if is_keeper else (SPRINT_SPEED if sprinting else WALK_SPEED)
	if stunned > 0.0:
		max_speed = 1.4
		wish = Vector3.ZERO

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length_squared() > 0.001:
		wish = wish.normalized()
		planar = planar.move_toward(wish * max_speed, ACCEL * delta)
		facing = wish
		var target_yaw := atan2(wish.x, wish.z)
		if visuals:
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_yaw, TURN_SPEED * delta)
	else:
		planar = planar.move_toward(Vector3.ZERO, FRICTION * delta)

	if not slam_air:
		velocity.x = planar.x
		velocity.z = planar.z
	move_and_slide()

	if visuals:
		visuals.animate(velocity, is_on_floor(), sprinting or slam_air, wish.length_squared() > 0.001, delta)


func _player_wish() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis: Basis = _cam.global_transform.basis if _cam else global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	var wish := forward * -input_dir.y + right * input_dir.x
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	return wish


func _player_acts(_delta: float) -> void:
	if Input.is_action_just_pressed("kick") or (charging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		charging = true
	if charging:
		charge = minf(CHARGE_MAX, charge + _delta)
		if Input.is_action_just_released("kick") or (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_action_pressed("kick")):
			_release_kick()
	if Input.is_action_just_pressed("punch"):
		_try_punch()
	if Input.is_action_just_pressed("slam") or Input.is_action_just_pressed("jump"):
		_try_slam()


func _release_kick() -> void:
	var power := lerpf(11.0, 24.0, charge / CHARGE_MAX)
	var loft := lerpf(2.2, 5.4, charge / CHARGE_MAX)
	var super_shot := charge >= 0.85
	charge = 0.0
	charging = false
	_do_kick(power, loft, super_shot)


func _do_kick(power: float, loft: float, super_shot: bool) -> void:
	if kick_cd > 0.0:
		return
	kick_cd = 0.22
	var ball := _ball()
	if has_ball and ball:
		var boost := 1.35 if super_shot else 1.0
		ball.release(facing * power * boost + Vector3.UP * loft)
		var match_n := _match()
		if match_n and super_shot:
			match_n.banner("SUPER STRIKE")
		return
	if ball and global_position.distance_to(ball.global_position) < 2.4:
		ball.release(facing * power * 0.72 + Vector3.UP * loft * 0.7)
		return
	_strike_nearby(facing * 7.0, 0.55, 1.9)


func _try_punch() -> void:
	if punch_cd > 0.0 or stunned > 0.0:
		return
	punch_cd = 0.55
	_strike_nearby(facing * 9.5 + Vector3.UP * 2.4, 1.15, 2.15)


func _try_slam() -> void:
	if slam_cd > 0.0 or stunned > 0.0 or not is_on_floor():
		return
	slam_cd = 1.6
	slam_air = true
	velocity = facing * 13.5 + Vector3.UP * 7.2


func _slam_impact() -> void:
	_strike_nearby(facing * 14.0 + Vector3.UP * 4.0, 1.65, 3.1)
	var match_n := _match()
	if match_n and not is_ai:
		match_n.banner("BODY SLAM")


func _strike_nearby(knock: Vector3, stun_time: float, reach: float) -> void:
	for node in get_tree().get_nodes_in_group("striker"):
		if node == self or not node.has_method("hit"):
			continue
		if node.team == team:
			continue
		var to: Vector3 = node.global_position - global_position
		to.y = 0.0
		if to.length() > reach:
			continue
		if to.length_squared() > 0.001 and to.normalized().dot(facing) < 0.12:
			continue
		node.hit(knock, stun_time)


func _ai_wish() -> Vector3:
	var ball := _ball()
	if ball == null:
		return Vector3.ZERO
	if is_keeper:
		return _keeper_wish(ball)
	var goal := _attack_goal()
	if has_ball:
		return goal - global_position
	if ball.carrier:
		var carrier := ball.carrier as Node3D
		if carrier and carrier.get("team") == team:
			var support: Vector3 = goal * 0.35 + carrier.global_position * 0.4
			support.x += 5.0 if global_position.x >= 0.0 else -5.0
			return support - global_position
		if carrier:
			return carrier.global_position - global_position
	return ball.global_position - global_position


func _keeper_wish(ball: RigidBody3D) -> Vector3:
	var tx := clampf(ball.global_position.x, -6.2, 6.2)
	var tz := clampf(ball.global_position.z, -34.5, -27.0) if team == Team.HOME else clampf(ball.global_position.z, 27.0, 34.5)
	var target := Vector3(tx, 0.0, tz)
	if ball.global_position.distance_to(global_position) < 5.5 and not ball.carrier:
		return ball.global_position - global_position
	return target - global_position


func _ai_acts(delta: float) -> void:
	var ball := _ball()
	if ball == null:
		return
	if has_ball:
		charge = minf(CHARGE_MAX, charge + delta * 0.9)
		var to_goal := _attack_goal() - global_position
		to_goal.y = 0.0
		if to_goal.length() < 15.0 and facing.dot(to_goal.normalized()) > 0.55:
			_do_kick(lerpf(12.0, 22.0, charge / CHARGE_MAX), 3.4, charge > 0.8)
			charge = 0.0
		return
	if is_keeper:
		if ball.global_position.distance_to(global_position) < 3.2 and not ball.carrier:
			ball.possess(self)
			var clear := Vector3(0, 4.2, 18.0 if team == Team.HOME else -18.0)
			ball.release(clear + facing * 4.0)
		return
	var threat := ball.carrier as Node3D
	if threat and threat.get("team") != team:
		var d := global_position.distance_to(threat.global_position)
		if d < 2.1:
			_try_punch()
		elif d < 4.2 and slam_cd <= 0.0 and randf() < 0.018:
			_try_slam()


func _attack_goal() -> Vector3:
	return Vector3(0, 0, 34.0) if team == Team.HOME else Vector3(0, 0, -34.0)


func _ball() -> RigidBody3D:
	return get_tree().get_first_node_in_group("soccer_ball") as RigidBody3D


func _match() -> Node:
	return get_tree().get_first_node_in_group("soccer_match")
