extends CharacterBody3D

const MAX_SPEED := 26.0
const REVERSE_SPEED := 8.0
const ACCEL := 16.0
const BRAKE := 36.0
const COAST := 10.0
const STEER_RATE := 1.85
const ENTER_DIST := 5.0
const EXIT_SPEED := 2.4
const MAX_HEALTH := 100.0
# Below this closing speed it is a scrape, not a crash.
const CRASH_MIN_SPEED := 4.5
const DAMAGE_PER_MPS := 3.4
const CRASH_COOLDOWN := 0.4
const SMOKE_AT := 60.0
const FIRE_AT := 25.0
const RESPAWN_DELAY := 7.0
const ENGINE_SFX := preload("res://assets/audio/truck_town/engine.wav")
const IMPACT_SFX := preload("res://assets/audio/truck_town/impact_1.wav")
const SEDAN_PATH := "res://assets/vehicles/sedan.glb"

var _speed: float = 0.0
var _yaw: float = 0.0
var _prev_speed: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _engine: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _enter_frame: int = -100
var _sedan_instance: Node3D = null
var health: float = MAX_HEALTH
var _crash_cooldown: float = 0.0
var _smoke: GPUParticles3D
var _fire: GPUParticles3D
var _fire_light: OmniLight3D
var _boom: GPUParticles3D
var _boom_light: OmniLight3D
var _boom_flash: float = 0.0


func _ready() -> void:
	add_to_group("camry")
	_yaw = rotation.y
	_setup_audio()
	_build()
	_build_damage_fx()
	_set_health(MAX_HEALTH)
	if GameState.load_from_save:
		global_position = GameState.saved_car
		_yaw = GameState.saved_car_yaw
		rotation.y = _yaw
	_make_enter_zone()


func _physics_process(delta: float) -> void:
	_tick_fx(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if GameState.is_paused:
		_speed = move_toward(_speed, 0.0, BRAKE * delta)
		_apply_move()
		return

	GameState.speed_mph = absf(_speed) * 2.237 if GameState.in_car else 0.0

	if not GameState.in_car:
		_speed = move_toward(_speed, 0.0, COAST * 2.4 * delta)
		if Input.is_action_just_pressed("reset_car"):
			_reset_near_player()
		_apply_move()
		return

	GameState.prompt = "E  Exit Camry" if absf(_speed) < EXIT_SPEED else "Stop to get out"
	if Input.is_action_just_pressed("interact") and absf(_speed) < EXIT_SPEED:
		var missions := get_tree().get_first_node_in_group("mission_system")
		if missions and missions.has_method("try_interact") and missions.try_interact():
			return
		try_exit()
		_apply_move()
		return

	var throttle := Input.get_axis("move_back", "move_forward")
	var steer := Input.get_axis("move_right", "move_left")
	var fuel_scale := 0.0 if GameState.fuel <= 0.0 else (0.55 if GameState.fuel < 18.0 else 1.0)
	var handbrake := Input.is_action_pressed("jump")

	if handbrake:
		_speed = move_toward(_speed, 0.0, BRAKE * 1.4 * delta)
	elif throttle > 0.05:
		_speed = move_toward(_speed, MAX_SPEED * fuel_scale * throttle, ACCEL * delta)
	elif throttle < -0.05:
		if _speed > 0.6:
			_speed = move_toward(_speed, 0.0, BRAKE * delta)
		else:
			_speed = move_toward(_speed, -REVERSE_SPEED * fuel_scale, ACCEL * 0.7 * delta)
	else:
		_speed = move_toward(_speed, 0.0, COAST * delta)

	var steer_power := STEER_RATE * clampf(absf(_speed) / 8.0, 0.15, 1.0)
	if absf(_speed) > 0.4:
		_yaw += steer * steer_power * signf(_speed) * delta
	if handbrake and absf(_speed) > 4.0:
		_yaw += steer * 1.8 * signf(_speed) * delta

	if absf(_speed) > 0.8 and GameState.fuel > 0.0:
		GameState.consume_fuel(0.7 * delta)

	_apply_move()
	global_position.x = clampf(global_position.x, -350.0, 350.0)
	global_position.z = clampf(global_position.z, -350.0, 350.0)


func _apply_move() -> void:
	rotation.y = _yaw
	var planar := Vector3(sin(_yaw), 0.0, cos(_yaw)) * _speed
	velocity.x = planar.x
	velocity.z = planar.z
	var before := Vector2(velocity.x, velocity.z)
	move_and_slide()
	_check_crash(before)
	if _engine:
		_update_audio()


func _check_crash(before: Vector2) -> void:
	if _crash_cooldown > 0.0 or health <= 0.0:
		return
	var worst := 0.0
	var what := "a wall"
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var flat := Vector2(n.x, n.z)
		# A near-vertical normal is the road, not something we drove into.
		if flat.length_squared() < 0.04:
			continue
		var closing := -before.dot(flat.normalized())
		if closing > worst:
			worst = closing
			what = _describe(c.get_collider())
	if worst < CRASH_MIN_SPEED:
		return
	_crash(worst, what)


func _describe(collider: Object) -> String:
	var n := collider as Node
	if n == null:
		return "something"
	if n.is_in_group("traffic"):
		return "another car"
	if n.is_in_group("smashable"):
		return "a tree"
	return "a wall"


func _crash(impact: float, what: String) -> void:
	_crash_cooldown = CRASH_COOLDOWN
	_speed *= 0.12
	velocity.x = 0.0
	velocity.z = 0.0
	if _impact:
		_impact.pitch_scale = randf_range(0.85, 1.15)
		_impact.play()
	_set_health(health - (impact - CRASH_MIN_SPEED) * DAMAGE_PER_MPS)
	if health > 0.0:
		GameState.notice.emit("Hit %s — Camry at %d%%." % [what, int(round(health))])


func _set_health(value: float) -> void:
	health = clampf(value, 0.0, MAX_HEALTH)
	GameState.car_health = health
	if _smoke:
		_smoke.emitting = health <= SMOKE_AT and health > 0.0
	if _fire:
		_fire.emitting = health <= FIRE_AT and health > 0.0
	if _fire_light:
		_fire_light.visible = health <= FIRE_AT and health > 0.0
	if health <= 0.0:
		_explode()


func _tick_fx(delta: float) -> void:
	if _crash_cooldown > 0.0:
		_crash_cooldown -= delta
	if _fire_light and _fire_light.visible:
		_fire_light.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.021) * 0.9
	if _boom_flash > 0.0:
		_boom_flash -= delta
		if _boom_light:
			_boom_light.light_energy = maxf(_boom_flash, 0.0) * 26.0
			_boom_light.visible = _boom_flash > 0.0


func _explode() -> void:
	_speed = 0.0
	velocity = Vector3.ZERO
	if _smoke:
		_smoke.emitting = false
	if _fire:
		_fire.emitting = false
	if _fire_light:
		_fire_light.visible = false
	if _boom:
		_boom.restart()
		_boom.emitting = true
	_boom_flash = 0.6
	if _impact:
		_impact.pitch_scale = 0.55
		_impact.play()
	if GameState.in_car:
		var player := get_tree().get_first_node_in_group("player")
		var out := global_position + global_transform.basis.x * 3.2
		out.y = maxf(global_position.y, 0.0)
		GameState.in_car = false
		GameState.prompt = ""
		if player and player.has_method("exit_car"):
			player.exit_car(out, _yaw)
		if player and player.has_method("hit_by_car"):
			player.hit_by_car(global_transform.basis.x, 11.0)
	GameState.notice.emit("The Camry blew up. R for a new one.")
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn_wreck)


func _respawn_wreck() -> void:
	if health > 0.0:
		return
	_reset_near_player()


func _setup_audio() -> void:
	_engine = AudioStreamPlayer3D.new()
	var engine_stream := ENGINE_SFX.duplicate()
	if engine_stream is AudioStreamWAV:
		(engine_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_engine.stream = engine_stream
	_engine.volume_db = -8.0
	_engine.max_distance = 40.0
	add_child(_engine)
	_impact = AudioStreamPlayer3D.new()
	_impact.stream = IMPACT_SFX
	_impact.volume_db = -4.0
	add_child(_impact)


func _update_audio() -> void:
	if GameState.in_car and absf(_speed) > 0.35:
		if not _engine.playing:
			_engine.play()
		var target_pitch := 0.55 + absf(_speed) / 16.0
		_engine.pitch_scale = lerpf(_engine.pitch_scale, target_pitch, 0.2)
	elif _engine.playing:
		_engine.stop()
	if absf(_speed - _prev_speed) > 6.0 and _impact and not _impact.playing:
		_impact.play()
	_prev_speed = _speed


func in_enter_range() -> bool:
	if GameState.in_car:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	# Ignore Y — parking lot is flat. Handles car fallen through world.
	var d2 := Vector2(global_position.x, global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	return d2 <= ENTER_DIST


func try_enter() -> bool:
	if GameState.in_car:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	if not in_enter_range():
		return false
	if health <= 0.0:
		GameState.notice.emit("The Camry is wrecked. Press R to call a new one.")
		return false
	_lock_player_in()
	_enter_frame = Engine.get_physics_frames()
	GameState.in_car = true
	var tag := get_node_or_null("EnterTag") as Label3D
	if tag:
		tag.visible = false
	GameState.notice.emit("Camry — W gas, S brake, Space handbrake, E to exit.")
	return true


func try_exit() -> void:
	if not GameState.in_car:
		return
	# Prevent enter+exit on same frame (both listen to E)
	if Engine.get_physics_frames() - _enter_frame < 2:
		return
	if absf(_speed) > EXIT_SPEED:
		GameState.notice.emit("Stop the Camry before getting out.")
		return
	var player := get_tree().get_first_node_in_group("player")
	var side := global_transform.basis.x * 2.4
	var at := global_position + side
	at.y = maxf(global_position.y, 0.0)
	GameState.in_car = false
	GameState.prompt = ""
	var tag := get_node_or_null("EnterTag") as Label3D
	if tag:
		tag.visible = true
	_speed = 0.0
	if player and player.has_method("exit_car"):
		player.exit_car(at, _yaw)
	GameState.notice.emit("On foot.")


func _lock_player_in() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("enter_car"):
		player.enter_car()


func _reset_near_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_speed = 0.0
	velocity = Vector3.ZERO
	global_position = player.global_position + Vector3(4.0, 0.2, 0.0)
	_yaw = player.rotation.y
	rotation.y = _yaw
	_crash_cooldown = CRASH_COOLDOWN
	_set_health(MAX_HEALTH)
	GameState.notice.emit("Fresh Camry delivered.")


func _build_damage_fx() -> void:
	_smoke = _particles(24, 1.7, Color(0.22, 0.22, 0.24, 0.7), 1.15, 2.4, 0.7, false)
	_smoke.position = Vector3(0, 0.85, 1.55)
	add_child(_smoke)

	_fire = _particles(30, 0.55, Color(1.0, 0.55, 0.12, 0.9), 0.9, 1.5, 0.45, true)
	_fire.position = Vector3(0, 0.8, 1.55)
	add_child(_fire)

	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 1.1, 1.55)
	_fire_light.light_color = Color("ff7a1a")
	_fire_light.omni_range = 9.0
	_fire_light.visible = false
	add_child(_fire_light)

	_boom = _particles(90, 1.1, Color(1.0, 0.72, 0.2, 1.0), 6.0, 13.0, 1.1, true)
	_boom.position = Vector3(0, 0.9, 0)
	_boom.one_shot = true
	_boom.explosiveness = 1.0
	_boom.emitting = false
	add_child(_boom)

	_boom_light = OmniLight3D.new()
	_boom_light.position = Vector3(0, 1.4, 0)
	_boom_light.light_color = Color("ffd08a")
	_boom_light.omni_range = 26.0
	_boom_light.visible = false
	add_child(_boom_light)


func _particles(count: int, life: float, tint: Color, vmin: float, vmax: float, size: float, additive: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.emitting = false
	# World space so smoke and flame trail behind a moving wreck.
	p.local_coords = false

	var lift := 1.2 if additive else 0.5
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, lift, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = tint
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = tint
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	p.draw_pass_1 = quad
	return p


func _make_enter_zone() -> void:
	var area := Area3D.new()
	area.name = "EnterZone"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 5.5
	col.shape = sphere
	col.position.y = 0.8
	area.add_child(col)
	add_child(area)


func _build() -> void:
	var paint := _mat(Color("8a0f18"), 0.32, 0.35, 0.85)
	var dark := _mat(Color("141414"), 0.55, 0.2)
	var chrome := _mat(Color("c8c8c8"), 0.22, 0.9)
	var glass := _mat(Color(0.12, 0.16, 0.2, 0.72), 0.05, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var light := _mat(Color("fff3c4"), 0.2)
	light.emission_enabled = true
	light.emission = Color("fff3c4")
	light.emission_energy_multiplier = 2.0
	var tail := _mat(Color("ff2222"), 0.3)
	tail.emission_enabled = true
	tail.emission = Color("ff2222")
	tail.emission_energy_multiplier = 2.2
	var rubber := _mat(Color("111111"), 0.92)

	var tag := Label3D.new()
	tag.name = "EnterTag"
	tag.text = "E  GET IN"
	tag.position = Vector3(0, 2.05, 0)
	tag.font_size = 56
	tag.modulate = Color("ffb703")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_modulate = Color.BLACK
	tag.outline_size = 8
	add_child(tag)

	# Try to instance Quaternius sedan.glb (170K) when it exists.
	var use_sedan := false
	if FileAccess.file_exists(SEDAN_PATH) or ResourceLoader.exists(SEDAN_PATH):
		var res = null
		# load() is runtime-safe; if import missing it returns null without crashing.
		if ResourceLoader.exists(SEDAN_PATH):
			res = load(SEDAN_PATH)
		if res is PackedScene:
			var inst = (res as PackedScene).instantiate()
			if inst is Node3D:
				var sedan := inst as Node3D
				sedan.name = "Sedan"
				# Quaternius NormalCar1 ships raw Blender Z-up: length runs along Y
				# (front = +Y), up is -Z, wheel contact at z = -0.00603. Rx +90 maps
				# -Z up to +Y and +Y front to +Z, the way _apply_move() drives.
				var base_len := 4.220717430114746
				var target_len := 4.35
				var s_len := target_len / base_len
				sedan.scale = Vector3(s_len, s_len, s_len)
				sedan.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				# Body origin rests on the ground, so drop the wheels onto y = 0.
				var wheel_contact := 0.006029833573848009
				sedan.position = Vector3(0.0, -wheel_contact * s_len, 0.0)
				add_child(sedan)
				_sedan_instance = sedan
				_set_shadows_recursive(sedan, true)
				use_sedan = true
			else:
				if inst:
					inst.queue_free()

	# Procedural fallback — always built, hidden when sedan is active.
	var proc_root := Node3D.new()
	proc_root.name = "Procedural"
	add_child(proc_root)

	_add_box(proc_root, Vector3(1.92, 0.52, 4.35), Vector3(0, 0.58, 0.05), paint)
	_add_box(proc_root, Vector3(1.86, 0.18, 0.62), Vector3(0, 0.44, 1.95), paint)
	_add_box(proc_root, Vector3(1.86, 0.22, 0.55), Vector3(0, 0.48, -1.95), paint)
	_add_box(proc_root, Vector3(1.62, 0.48, 1.85), Vector3(0, 1.02, -0.18), paint)
	var windshield := _add_box(proc_root, Vector3(1.52, 0.04, 1.05), Vector3(0, 1.08, 0.72), glass)
	windshield.rotation_degrees.x = 28.0
	_add_box(proc_root, Vector3(1.52, 0.04, 0.72), Vector3(0, 1.06, -0.95), glass)
	_add_box(proc_root, Vector3(0.04, 0.36, 1.2), Vector3(-0.80, 0.98, -0.12), glass)
	_add_box(proc_root, Vector3(0.04, 0.36, 1.2), Vector3(0.80, 0.98, -0.12), glass)
	_add_box(proc_root, Vector3(0.24, 0.14, 0.14), Vector3(-0.68, 0.58, 2.22), light)
	_add_box(proc_root, Vector3(0.24, 0.14, 0.14), Vector3(0.68, 0.58, 2.22), light)
	_add_box(proc_root, Vector3(0.32, 0.12, 0.08), Vector3(-0.68, 0.58, -2.20), tail)
	_add_box(proc_root, Vector3(0.32, 0.12, 0.08), Vector3(0.68, 0.58, -2.20), tail)
	_add_box(proc_root, Vector3(1.94, 0.06, 0.10), Vector3(0, 0.36, 2.24), chrome)
	_add_box(proc_root, Vector3(1.94, 0.06, 0.10), Vector3(0, 0.36, -2.22), chrome)
	_add_box(proc_root, Vector3(1.70, 0.05, 1.6), Vector3(0, 0.34, 0.15), dark)
	var shadow := _add_box(proc_root, Vector3(2.1, 0.02, 4.5), Vector3(0, 0.03, 0), _mat(Color(0, 0, 0, 0.35), 1.0))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for p in [Vector3(-0.84, 0.30, 1.32), Vector3(0.84, 0.30, 1.32), Vector3(-0.84, 0.30, -1.32), Vector3(0.84, 0.30, -1.32)]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.33
		cyl.bottom_radius = 0.33
		cyl.height = 0.26
		wheel.mesh = cyl
		wheel.material_override = rubber
		wheel.rotation_degrees.z = 90
		wheel.position = p
		proc_root.add_child(wheel)
		var rim := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.2
		disc.bottom_radius = 0.2
		disc.height = 0.28
		rim.mesh = disc
		rim.material_override = chrome
		rim.rotation_degrees.z = 90
		rim.position = p
		proc_root.add_child(rim)

	if use_sedan:
		proc_root.visible = false


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _set_shadows_recursive(root: Node, enabled: bool) -> void:
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for c in n.get_children():
			stack.append(c)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func _mat(color: Color, roughness: float, metallic: float = 0.0, clearcoat: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if clearcoat > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = clearcoat
		m.clearcoat_roughness = 0.25
	return m
