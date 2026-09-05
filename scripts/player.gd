extends CharacterBody3D

const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.0
const ACCEL := 32.0
const FRICTION := 42.0
const JUMP_VELOCITY := 5.0
const TURN_SPEED := 7.2
const KNOCK_TIME := 2.4
const GETUP_AT := 0.9
const WAVE_TIME := 1.6
const HELLOS := [
	preload("res://assets/audio/voice/hi_1.wav"),
	preload("res://assets/audio/voice/hi_2.wav"),
	preload("res://assets/audio/voice/hi_3.wav"),
]
const OW := preload("res://assets/audio/voice/hit.wav")

const RUSH_SPIN := 5.4          # how fast he corkscrews, rad/sec
const RUSH_HOP := 0.34          # seconds between hops
const SUGAR_START := preload("res://assets/audio/sugar/sugar_start.wav")
const SUGAR_LOOP := preload("res://assets/audio/sugar/sugar_loop.wav")
const SUGAR_END := preload("res://assets/audio/sugar/sugar_end.wav")
const RUSH_YELLS := [
	preload("res://assets/audio/sugar/rush_1.wav"),
	preload("res://assets/audio/sugar/rush_2.wav"),
	preload("res://assets/audio/sugar/rush_3.wav"),
]
const CRASH_LINE := preload("res://assets/audio/sugar/crash_1.wav")

@onready var visuals: JacobLook = $Visuals

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam: Node3D
var _knocked: float = 0.0
var _roll: float = 0.0
var _wave: float = 0.0
var _voice: AudioStreamPlayer3D
var _rush: float = 0.0
var _rush_angle: float = 0.0
var _rush_hop: float = 0.0
var _rush_yell: float = 0.0
var _buzz: AudioStreamPlayer3D
var _rush_at: float = -1.0      # hour today the spontaneous rush fires
var _rush_day: int = -1


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	if GameState.load_from_save:
		global_position = GameState.saved_player
	_voice = AudioStreamPlayer3D.new()
	_voice.volume_db = 2.0
	_voice.max_distance = 30.0
	add_child(_voice)
	_buzz = AudioStreamPlayer3D.new()
	_buzz.volume_db = -4.0
	_buzz.max_distance = 26.0
	var loop_stream := SUGAR_LOOP.duplicate()
	if loop_stream is AudioStreamWAV:
		(loop_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_buzz.stream = loop_stream
	add_child(_buzz)
	_schedule_rush()
	GameState.day_changed.connect(func(_d: int) -> void: _schedule_rush())
	_set_on_foot(true)
	visuals.set_clothed(GameState.has_clothes)
	GameState.clothes_changed.connect(visuals.set_clothed)


func _physics_process(delta: float) -> void:
	if GameState.in_car or GameState.is_paused:
		return
	if _knocked > 0.0:
		_process_knockdown(delta)
		return
	_check_spontaneous_rush()
	if _rush > 0.0:
		_process_rush(delta)
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
	if global_position.y < -8.0:
		_recover()
	visuals.animate(velocity, is_on_floor(), sprinting, wish.length_squared() > 0.001, delta)
	_tick_wave(delta)
	if Input.is_action_just_pressed("wave"):
		_start_wave()
	_update_prompt()
	if Input.is_action_just_pressed("interact"):
		if _arcade_in_range():
			GameState.enter_arcade()
			return
		var pump := _near("gas_pump")
		if pump:
			pump.use()
			return
		var spot := _near("activity")
		if spot:
			spot.use()
			return
		var shop := _near("store_counter")
		if shop and String(shop.prompt()) != "":
			shop.buy()
			return
		var desk := _near("sales_terminal")
		if desk:
			desk.open()
			return
		var mate := _near("office_npc")
		if mate:
			mate.talk()
			return
		var lift := _near("elevator")
		if lift:
			lift.open()
			return
		if _try_enter_car():
			return
		var missions := get_tree().get_first_node_in_group("mission_system")
		if missions and missions.has_method("try_interact"):
			missions.try_interact()


## Once a day, unprompted, for ten seconds.
func _schedule_rush() -> void:
	_rush_day = GameState.day
	_rush_at = randf_range(9.0, 21.0)


func _check_spontaneous_rush() -> void:
	if _rush_day != GameState.day or _rush_at < 0.0:
		return
	if GameState.clock < _rush_at:
		return
	_rush_at = -1.0
	sugar_rush(10.0, "Something in you just snapped. SUGAR RUSH.")


## Take the controls away and let him corkscrew. Called by the shop counters
## too, for a shorter burst.
func sugar_rush(seconds: float, why: String) -> void:
	if _knocked > 0.0:
		return
	var fresh: bool = _rush <= 0.0
	_rush = maxf(_rush, seconds)
	if not fresh:
		return
	_rush_angle = visuals.rotation.y
	_rush_hop = 0.0
	_rush_yell = 0.6
	_wave = 0.0
	visuals.wave_arm(0.0, 0.0)
	_say(SUGAR_START)
	if _buzz:
		_buzz.play()
	GameState.prompt = ""
	GameState.notice.emit(why)


func _process_rush(delta: float) -> void:
	_rush -= delta
	_rush_angle += RUSH_SPIN * delta

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		_rush_hop -= delta
		if _rush_hop <= 0.0:
			_rush_hop = RUSH_HOP
			velocity.y = JUMP_VELOCITY * randf_range(0.8, 1.15)

	var wish := Vector3(sin(_rush_angle), 0.0, cos(_rush_angle))
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	planar = planar.move_toward(wish * SPRINT_SPEED, ACCEL * 1.4 * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	move_and_slide()
	global_position.x = clampf(global_position.x, -360.0, 360.0)
	global_position.z = clampf(global_position.z, -360.0, 360.0)
	if global_position.y < -8.0:
		_recover()

	visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(wish.x, wish.z), 1.0 - exp(-14.0 * delta))
	visuals.wave_arm(1.9 + sin(_rush_angle * 3.0) * 0.7, sin(_rush_angle * 5.0) * 0.6)
	visuals.animate(velocity, is_on_floor(), true, true, delta)

	_rush_yell -= delta
	if _rush_yell <= 0.0:
		_rush_yell = randf_range(2.6, 4.0)
		_say(RUSH_YELLS[randi() % RUSH_YELLS.size()])

	if _rush <= 0.0:
		_rush = 0.0
		visuals.wave_arm(0.0, 0.0)
		if _buzz:
			_buzz.stop()
		_say(SUGAR_END)
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if _rush <= 0.0 and _voice and not _voice.playing:
				_say(CRASH_LINE))
		GameState.notice.emit("...that's worn off.")


func _start_wave() -> void:
	if _wave > 0.0 or _knocked > 0.0:
		return
	_wave = WAVE_TIME
	_say(HELLOS[randi() % HELLOS.size()])


func _tick_wave(delta: float) -> void:
	if _wave <= 0.0:
		return
	_wave -= delta
	# BusinessMan only ships Idle/Walk/Run, so the wave is driven on the arm
	# bone directly rather than through an animation clip.
	var t := 1.0 - (_wave / WAVE_TIME)
	var swing := sin(t * PI * 3.0) * 0.5
	visuals.wave_arm(clampf(sin(t * PI) * 2.6, 0.0, 2.6), swing)
	if _wave <= 0.0:
		_wave = 0.0
		visuals.wave_arm(0.0, 0.0)


func _say(stream: AudioStream) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.play()


func hit_by_car(forward: Vector3, speed: float) -> void:
	if _knocked > 0.0 or GameState.in_car:
		return
	var push := Vector3(forward.x, 0.0, forward.z)
	if push.length_squared() < 0.0001:
		push = -visuals.global_transform.basis.z
	push = push.normalized()
	_knocked = KNOCK_TIME
	_rush = 0.0
	if _buzz:
		_buzz.stop()
	_wave = 0.0
	visuals.wave_arm(0.0, 0.0)
	_roll = randf_range(-2.2, 2.2)
	_say(OW)
	velocity = push * clampf(speed * 0.85, 7.0, 17.0) + Vector3.UP * 5.4
	GameState.prompt = ""
	GameState.notice.emit("Hit by a car!")


func _process_knockdown(delta: float) -> void:
	_knocked -= delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	# Skid to a stop once he lands, then hold before getting up.
	var drag: float = 14.0 if is_on_floor() else 2.5
	planar = planar.move_toward(Vector3.ZERO, drag * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	move_and_slide()

	var down := _knocked > GETUP_AT
	var rate: float = 10.0 if down else 7.0
	var pitch: float = -PI * 0.5 if down else 0.0
	var roll: float = _roll if down else 0.0
	var weight := 1.0 - exp(-rate * delta)
	visuals.rotation.x = lerp_angle(visuals.rotation.x, pitch, weight)
	visuals.rotation.z = lerp_angle(visuals.rotation.z, roll, weight)
	visuals.animate(Vector3.ZERO, is_on_floor(), false, false, delta)
	if _knocked <= 0.0:
		_knocked = 0.0
		visuals.rotation.x = 0.0
		visuals.rotation.z = 0.0


func _recover() -> void:
	# Fell out of the world. Put him back on the pavement rather than forever.
	global_position = Vector3(16.0, 0.5, 3.2)
	velocity = Vector3.ZERO
	GameState.notice.emit("Whoa. Back on solid ground.")


func _camera_rig() -> Node3D:
	# CameraRig sits after Jacob in main.tscn, so it has not joined the group
	# yet when _ready() runs here. Resolve on first use instead.
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_tree().get_first_node_in_group("camera_rig") as Node3D
	return _cam


func _cam_wish(input_dir: Vector2) -> Vector3:
	if input_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	var look := Vector3.FORWARD
	var rig := _camera_rig()
	if rig:
		look = -rig.global_transform.basis.z
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
	var pump := _near("gas_pump")
	if pump:
		GameState.prompt = String(pump.prompt())
		return
	var spot := _near("activity")
	if spot:
		GameState.prompt = String(spot.prompt())
		return
	var counter := _near("store_counter")
	if counter:
		var text := String(counter.prompt())
		if text != "":
			GameState.prompt = text
			return
	if _arcade_in_range():
		GameState.prompt = "E  Play Super Strikers"
		return
	if _near("sales_terminal"):
		GameState.prompt = "E  Start your shift"
		return
	var mate := _near("office_npc")
	if mate:
		GameState.prompt = "E  Talk to %s" % String(mate.npc_name).split(" —")[0]
		return
	if _near("elevator"):
		GameState.prompt = "E  Elevator"
		return
	GameState.prompt = ""


func _near(group: String) -> Node3D:
	for n in get_tree().get_nodes_in_group(group):
		var node := n as Node3D
		if node and node.has_method("in_range") and node.in_range(self):
			return node
	return null


func _arcade_in_range() -> bool:
	var arcade := get_tree().get_first_node_in_group("soccer_arcade")
	return arcade != null and arcade.has_method("in_range") and arcade.in_range(self)


func _try_enter_car() -> bool:
	var car := get_tree().get_first_node_in_group("camry")
	if car and car.has_method("try_enter"):
		return bool(car.try_enter())
	return false


func _set_on_foot(enabled: bool) -> void:
	visible = enabled
	collision_layer = 2 if enabled else 0
	# world + vehicle, so traffic and the Camry are solid to Jacob on foot.
	collision_mask = 5 if enabled else 0
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
