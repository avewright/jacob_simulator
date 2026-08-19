extends Node3D

signal score_changed(home: int, away: int)
signal clock_changed(seconds: float)
signal bannered(text: String)

const HALF := 180.0
const HALF_W := 23.0
const HALF_L := 35.0
const GOAL_W := 8.0

const STRIKER := preload("res://scenes/soccer/striker.tscn")
const BALL := preload("res://scenes/soccer/ball.tscn")

var home_score: int = 0
var away_score: int = 0
var time_left: float = HALF
var play_on: bool = false
var kickoff_t: float = 1.8
var ended: bool = false

var ball: RigidBody3D


func _ready() -> void:
	add_to_group("soccer_match")
	GameState.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_pitch()
	_spawn_sides()
	ball = BALL.instantiate() as RigidBody3D
	add_child(ball)
	_kickoff(true)
	call_deferred("banner", "KICK OFF")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.is_paused = not GameState.is_paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if GameState.is_paused else Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
	elif event.is_action_pressed("interact") and (GameState.is_paused or ended):
		get_tree().change_scene_to_file("res://scenes/soccer/soccer_title.tscn")


func _process(delta: float) -> void:
	if GameState.is_paused or ended:
		return
	if kickoff_t > 0.0:
		kickoff_t -= delta
		if kickoff_t <= 0.0:
			play_on = true
			if ball:
				ball.freeze = false
		return
	time_left = maxf(0.0, time_left - delta)
	clock_changed.emit(time_left)
	if time_left <= 0.0:
		_end_match()
		return
	_check_goals()
	_contain_ball()


func banner(text: String) -> void:
	bannered.emit(text)


func _kickoff(center_home: bool) -> void:
	play_on = false
	kickoff_t = 1.6
	for node in get_tree().get_nodes_in_group("striker"):
		if node.has_method("reset_to_spawn"):
			node.reset_to_spawn()
	if ball:
		ball.carrier = null
		ball.freeze = true
		ball.linear_velocity = Vector3.ZERO
		ball.global_position = Vector3(0, 0.45, -1.2 if center_home else 1.2)
	score_changed.emit(home_score, away_score)
	clock_changed.emit(time_left)


func _check_goals() -> void:
	if ball == null or ball.carrier:
		return
	var p := ball.global_position
	if absf(p.x) > GOAL_W * 0.5 or p.y > 3.1:
		return
	if p.z > HALF_L + 0.35:
		_goal(true)
	elif p.z < -HALF_L - 0.35:
		_goal(false)


func _goal(home: bool) -> void:
	if home:
		home_score += 1
	else:
		away_score += 1
	banner("GOAL")
	score_changed.emit(home_score, away_score)
	_kickoff(not home)


func _end_match() -> void:
	ended = true
	play_on = false
	if home_score == away_score:
		banner("DRAW — E for menu")
	elif home_score > away_score:
		banner("HOME WINS — E for menu")
	else:
		banner("AWAY WINS — E for menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _contain_ball() -> void:
	if ball == null or ball.carrier:
		return
	var p := ball.global_position
	if p.y < -2.0 or absf(p.x) > HALF_W + 8.0 or absf(p.z) > HALF_L + 10.0:
		ball.global_position = Vector3(0, 0.5, 0)
		ball.linear_velocity = Vector3.ZERO


func _spawn_sides() -> void:
	_spawn(Vector3(0, 0, -10), 0, false, false, true)
	_spawn(Vector3(7, 0, -16), 0, true, false, false)
	_spawn(Vector3(0, 0, -31.5), 0, true, true, false)
	_spawn(Vector3(-5, 0, 12), 1, true, false, false)
	_spawn(Vector3(6, 0, 17), 1, true, false, false)
	_spawn(Vector3(0, 0, 31.5), 1, true, true, false)


func _spawn(pos: Vector3, team: int, ai: bool, keeper: bool, captain: bool) -> void:
	var s := STRIKER.instantiate()
	s.team = team
	s.is_ai = ai
	s.is_keeper = keeper
	s.is_captain = captain
	s.position = pos
	add_child(s)


func _build_pitch() -> void:
	_setup_env()
	_box(Vector3(0, -0.2, 0), Vector3(HALF_W * 2 + 8, 0.4, HALF_L * 2 + 10), Color(0.16, 0.38, 0.18), true)
	_paint_turf()
	_wall(Vector3(-HALF_W - 0.4, 1.2, 0), Vector3(0.8, 2.4, HALF_L * 2 + 2))
	_wall(Vector3(HALF_W + 0.4, 1.2, 0), Vector3(0.8, 2.4, HALF_L * 2 + 2))
	_wall(Vector3(0, 1.2, -HALF_L - 1.2), Vector3(HALF_W * 2 + 2, 2.4, 0.8), true)
	_wall(Vector3(0, 1.2, HALF_L + 1.2), Vector3(HALF_W * 2 + 2, 2.4, 0.8), true)
	_goal_frame(Vector3(0, 0, -HALF_L))
	_goal_frame(Vector3(0, 0, HALF_L))
	_line(Vector3(0, 0.03, 0), Vector3(HALF_W * 2 - 1.2, 0.02, 0.12), Color.WHITE)
	_line(Vector3(0, 0.03, 0), Vector3(0.12, 0.02, HALF_L * 2 - 1.0), Color.WHITE)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)


func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.68, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _paint_turf() -> void:
	for i in 9:
		var z := -HALF_L + 4.0 + i * 7.8
		var dark := i % 2 == 0
		_box(
			Vector3(0, 0.01, z),
			Vector3(HALF_W * 2 - 0.6, 0.02, 7.6),
			Color(0.14, 0.46, 0.18) if dark else Color(0.2, 0.54, 0.22),
			false
		)


func _goal_frame(origin: Vector3) -> void:
	var post := Color(0.95, 0.95, 0.92)
	_box(origin + Vector3(-GOAL_W * 0.5, 1.5, 0), Vector3(0.16, 3.0, 0.16), post, true)
	_box(origin + Vector3(GOAL_W * 0.5, 1.5, 0), Vector3(0.16, 3.0, 0.16), post, true)
	_box(origin + Vector3(0, 3.0, 0), Vector3(GOAL_W + 0.16, 0.16, 0.16), post, true)


func _wall(pos: Vector3, size: Vector3, has_mouth: bool = false) -> void:
	if has_mouth:
		var gap := GOAL_W * 0.5 + 0.6
		var side := (size.x * 0.5 - gap) * 0.5 + gap
		_box(pos + Vector3(-side, 0, 0), Vector3(size.x * 0.5 - gap, size.y, size.z), Color(0.75, 0.2, 0.12), true)
		_box(pos + Vector3(side, 0, 0), Vector3(size.x * 0.5 - gap, size.y, size.z), Color(0.75, 0.2, 0.12), true)
		_box(pos + Vector3(0, 2.7, 0), Vector3(GOAL_W + 1.2, 0.6, size.z), Color(0.75, 0.2, 0.12), true)
		return
	_box(pos, size, Color(0.12, 0.45, 0.7), true)


func _line(pos: Vector3, size: Vector3, color: Color) -> void:
	_box(pos, size, color, false)


func _box(pos: Vector3, size: Vector3, color: Color, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.add_child(mi)
		add_child(body)
	else:
		mi.position = pos
		add_child(mi)
