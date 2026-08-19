extends Node3D

var yaw: float = PI
var pitch: float = 0.32
var distance: float = 9.4

@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group("camera_rig")
	arm.spring_length = distance
	arm.collision_mask = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0032
		pitch = clampf(pitch + event.relative.y * 0.0032, -0.05, 1.05)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.55, 5.0, 16.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.55, 5.0, 16.0)


func _physics_process(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("captain") as Node3D
	if target == null:
		return
	var look_at := target.global_position + Vector3(0, 1.45, 0)
	var ball := get_tree().get_first_node_in_group("soccer_ball") as Node3D
	if ball:
		look_at = look_at.lerp(ball.global_position + Vector3(0, 0.8, 0), 0.18)
	global_position = global_position.lerp(look_at, 1.0 - exp(-9.0 * delta))
	rotation.y = yaw
	arm.spring_length = distance
	arm.rotation.x = -pitch
	camera.fov = 60.0
