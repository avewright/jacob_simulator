extends Node3D

var yaw: float = 0.0
var pitch: float = 0.28
var distance: float = 7.4
var inspect: bool = false

@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group("camera_rig")
	arm.spring_length = distance
	arm.collision_mask = 0
	arm.margin = 0.2
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var start := _target()
	if start:
		global_position = start.global_position + Vector3(0, 1.55, 0)
		rotation.y = yaw
		arm.rotation.x = -pitch


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0034
		pitch = clampf(pitch + event.relative.y * 0.0034, -0.2, 1.15)
	elif event is InputEventMouseButton and not inspect:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.6, 3.2, 18.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.6, 3.2, 18.0)
	elif event.is_action_pressed("inspect"):
		inspect = not inspect
		distance = 2.4 if inspect else (9.2 if GameState.in_car else 7.6)
		pitch = 0.08 if inspect else 0.28
	elif event.is_action_pressed("toggle_wireframe"):
		var vp := get_viewport()
		if vp.debug_draw == Viewport.DEBUG_DRAW_WIREFRAME:
			vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
			GameState.notice.emit("Shaded view")
		else:
			vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
			GameState.notice.emit("Wireframe overlay")


func _physics_process(delta: float) -> void:
	var target := _target()
	if target == null:
		return
	var look_h := 1.55
	if inspect and not GameState.in_car:
		look_h = 1.68
		arm.spring_length = 2.4
		camera.fov = 38.0
	else:
		arm.spring_length = 10.5 if GameState.in_car else distance
		camera.fov = 62.0 if GameState.in_car else 58.0
		look_h = 1.45 if GameState.in_car else 1.5

	var desired := target.global_position + Vector3(0.0, look_h, 0.0)
	global_position = global_position.lerp(desired, 1.0 - exp(-8.0 * delta))
	if GameState.in_car and not inspect:
		# Camera looks down -Z; car nose is +Z, so aim the rig 180° from the car.
		yaw = lerp_angle(yaw, target.global_rotation.y + PI, 1.0 - exp(-2.4 * delta))
	rotation.y = yaw
	arm.rotation.x = -pitch


func _target() -> Node3D:
	if GameState.in_car:
		return get_tree().get_first_node_in_group("camry") as Node3D
	return get_tree().get_first_node_in_group("player") as Node3D
