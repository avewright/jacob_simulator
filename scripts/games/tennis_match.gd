extends Node3D

# Three-dimensional tennis, played on the court already standing in the world —
# the match seats itself onto it rather than building its own.
#
# The world pauses underneath and this runs on PROCESS_MODE_ALWAYS, so leaving
# puts you back exactly where you were.
#
# Court space: net at z = 0, you defend +Z, the opponent defends -Z, X lateral.
# Dimensions are the regulation ones the 3D courts were built to.
#
# Shots are aimed ballistically: given the lift and spin a stroke carries, the
# launch speed is solved so the ball lands on the chosen target. Aiming by
# direction alone and picking a speed made every overflown shot go wide as well
# as long, because the lateral offset scaled with the overshoot.

const LEN := 23.77
const DOUBLES := 10.97
const SINGLES := 8.23
const SERVICE := 6.40
const NET_H := 0.914
const NET_POST_H := 1.07
const COURT_GAP := 24.0

const BALL_R := 0.033
const GRAV := 15.0
const SPIN_G := 3.5           # extra gravity per unit of topspin
const DRAG := 0.28
const BOUNCE := 0.58
const SKID := 0.72
const NET_CORD := 0.55
const MIN_CONTACT := 0.16     # below this the ball is on your shoelaces

const RUN := 8.6
const REACH := 2.05
const AI_REACH := 2.40
const HIT_H := 2.6
const CHARGE_MAX := 0.55
const SWING_WINDOW := 0.22
const AI_RUN := 7.4

const GAMES_TO_WIN := 4
const POINTS := ["0", "15", "30", "40"]

enum Shot { DRIVE, TOPSPIN, SLICE, LOB }

# lift, spin, min speed, max speed
const STROKE := {
	Shot.DRIVE: [4.6, 0.4, 18.0, 30.0],
	Shot.TOPSPIN: [6.2, 1.5, 18.0, 32.0],
	Shot.SLICE: [3.9, -0.9, 15.0, 26.0],
	Shot.LOB: [10.5, 0.5, 10.0, 20.0],
}
const SHOT_NAMES := ["DRIVE", "TOPSPIN", "SLICE", "LOB"]

var _cam: Camera3D
var _prev_cam: Camera3D
var _hud: CanvasLayer
var _score_lab: Label
var _msg_lab: Label
var _shot_lab: Label
var _meter: ProgressBar

var _me: Node3D
var _foe: Node3D
var _ball: Node3D
var _shadow: MeshInstance3D
var _pin: MeshInstance3D
var _trail: Array[MeshInstance3D] = []
var _trail_at: int = 0

var _bpos := Vector3.ZERO
var _bvel := Vector3.ZERO
var _bspin: float = 0.0
var _live: bool = false
var _bounces: int = 0
var _last: int = 1
var _rally: int = 0

var _mp := Vector3(0, 0, LEN * 0.5 + 1.2)
var _fp := Vector3(0, 0, -LEN * 0.5 - 1.0)
var _charge: float = 0.0
var _charging: bool = false
var _swing: float = 0.0
var _swing_shot: int = Shot.DRIVE
var _foe_cool: float = 0.0

var _toss: float = 0.0
var _server: int = 1
var _deuce_side: bool = false

var _p_pts: int = 0
var _o_pts: int = 0
var _p_games: int = 0
var _o_games: int = 0
var _over: bool = false
var _wait: float = 1.4


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seat_on_court()
	_build_actors()
	_build_hud()
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_world_hud(false)
	_new_point("Your serve." if _server == 1 else "Their serve.")


## Sit on the east court of the tennis centre if it is in the scene.
func _seat_on_court() -> void:
	var courts := get_tree().get_first_node_in_group("tennis_courts") as Node3D
	if courts:
		global_position = courts.global_position + Vector3(COURT_GAP * 0.5, 0.0, 0.0)
		global_rotation = courts.global_rotation


func _exit_tree() -> void:
	_show_world_hud(true)
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.current = true


func _show_world_hud(shown: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var hud := scene.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = shown


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	var step: float = minf(delta, 1.0 / 30.0)
	if not _over:
		_run(step)
	_paint(step)


func _run(delta: float) -> void:
	_swing = maxf(_swing - delta, 0.0)
	_foe_cool = maxf(_foe_cool - delta, 0.0)
	_move_me(delta)

	if not _live:
		_wait -= delta
		if _wait <= 0.0:
			if _server == 1:
				_serve_input(delta)
			else:
				_ai_serve()
		return

	_move_foe(delta)
	_step_ball(delta)
	_try_hits()


func _move_me(delta: float) -> void:
	var mx: float = Input.get_axis("move_left", "move_right")
	var mz: float = Input.get_axis("move_forward", "move_back")
	var move := Vector3(mx, 0.0, mz)
	if move.length() > 1.0:
		move = move.normalized()
	_mp += move * RUN * delta
	_mp.x = clampf(_mp.x, -DOUBLES * 0.5 - 3.0, DOUBLES * 0.5 + 3.0)
	_mp.z = clampf(_mp.z, 0.6, LEN * 0.5 + 5.5)
	_me.position = _mp
	if move.length_squared() > 0.01:
		_me.rotation.y = lerp_angle(_me.rotation.y, atan2(move.x, move.z), 1.0 - exp(-12.0 * delta))


# ------------------------------------------------------------------ ballistics

## Speed that puts a ball hit from `y0` with this lift and spin down `dist`
## metres away, allowing for drag.
func _launch_speed(y0: float, lift: float, spin: float, dist: float, lo: float, hi: float) -> float:
	var g: float = GRAV + spin * SPIN_G
	var disc: float = maxf(lift * lift + 2.0 * g * maxf(y0 - BALL_R, 0.0), 0.0)
	var t: float = (lift + sqrt(disc)) / g
	var carry: float = maxf((1.0 - exp(-DRAG * t)) / DRAG, 0.05)
	return clampf(dist / carry, lo, hi)


## Serve is a two-press rhythm: toss, then strike near the apex.
func _serve_input(delta: float) -> void:
	if _toss <= 0.0:
		_msg_lab.text = "SPACE to toss"
		if Input.is_action_just_pressed("jump"):
			_toss = 1.15
			_bpos = _mp + Vector3(0.0, 1.5, -0.35)
			_bvel = Vector3(0.0, 6.4, 0.0)
			_bspin = 0.0
		return
	_toss -= delta
	_bvel.y -= GRAV * delta
	_bpos += _bvel * delta
	_msg_lab.text = "SPACE at the top"
	if Input.is_action_just_pressed("jump"):
		var quality: float = clampf(1.0 - absf(_bvel.y) / 5.0, 0.15, 1.0)
		_strike_serve(1, quality)
	elif _toss <= 0.0 or _bpos.y < 0.6:
		_msg_lab.text = "Missed the toss."
		_wait = 1.0
		_toss = 0.0


func _ai_serve() -> void:
	_bpos = _fp + Vector3(0.0, 2.6, 0.35)
	_strike_serve(-1, randf_range(0.55, 0.95))


func _strike_serve(who: int, quality: float) -> void:
	_live = true
	_bounces = 0
	_rally = 0
	_last = who
	_toss = 0.0
	# Into the diagonal box: the deuce court serves to the receiver's right.
	var box_x: float = SINGLES * 0.25 * (1.0 if _deuce_side else -1.0) * who
	var target := Vector3(box_x + randf_range(-0.8, 0.8), 0.0, -SERVICE * 0.62 * who)
	var flat := target - _bpos
	var dist: float = Vector2(flat.x, flat.z).length()
	var lift: float = lerpf(1.9, 0.45, quality)
	var speed: float = _launch_speed(_bpos.y, lift, 0.35, dist, 20.0, 36.0)
	_bspin = 0.35
	if dist < 0.05:
		_bvel = Vector3(0.0, lift, -speed * who)
	else:
		_bvel = Vector3(flat.x, 0.0, flat.z).normalized() * speed + Vector3.UP * lift
	_msg_lab.text = "Big serve!" if quality > 0.9 else ""


func _step_ball(delta: float) -> void:
	_bvel.y -= (GRAV + _bspin * SPIN_G) * delta
	var drag: float = 1.0 - DRAG * delta
	_bvel.x *= drag
	_bvel.z *= drag
	var prev := _bpos
	_bpos += _bvel * delta

	if signf(prev.z) != signf(_bpos.z) and absf(_bpos.x) < DOUBLES * 0.5 + 0.9:
		var span: float = maxf(absf(prev.z) + absf(_bpos.z), 0.001)
		var y_at: float = lerpf(prev.y, _bpos.y, absf(prev.z) / span)
		var cord: float = lerpf(NET_H, NET_POST_H, clampf(absf(_bpos.x) / (DOUBLES * 0.5), 0.0, 1.0))
		if y_at < cord:
			if y_at > cord - 0.09:
				_bvel *= NET_CORD
				_bvel.y = absf(_bvel.y) * 0.6 + 1.2
				_msg_lab.text = "Off the net!"
			else:
				_point(-_last, "Into the net.")
				return

	if _bpos.y <= BALL_R:
		_bpos.y = BALL_R
		_bvel.y = absf(_bvel.y) * BOUNCE + _bspin * 1.1
		_bvel.x *= SKID
		_bvel.z *= SKID
		_bspin *= 0.4
		_bounces += 1
		_mark_bounce(_bpos)
		if _bounces == 1 and not _in_bounds(_bpos):
			_point(-_last, "Out." if _rally > 0 else "Fault.")
			return
		if _bounces >= 2:
			_point(_last, "Two bounces.")
			return

	if absf(_bpos.z) > LEN * 0.5 + 11.0 or absf(_bpos.x) > DOUBLES * 0.5 + 9.0:
		_point(_last if _bounces > 0 else -_last, "Long.")


func _in_bounds(p: Vector3) -> bool:
	var pad: float = BALL_R + 0.03
	if _rally == 0:
		# A serve must find the diagonal box on the receiver's side.
		if signf(p.z) == signf(float(_last)) or absf(p.z) > SERVICE + pad:
			return false
		if absf(p.x) > SINGLES * 0.5 + pad:
			return false
		var want: float = SINGLES * 0.25 * (1.0 if _deuce_side else -1.0) * _last
		return signf(p.x) == signf(want) or absf(p.x) < 0.3
	return absf(p.x) <= SINGLES * 0.5 + pad and absf(p.z) <= LEN * 0.5 + pad


# ------------------------------------------------------------------ striking

func _try_hits() -> void:
	var held: bool = Input.is_action_pressed("jump")
	if held and _last != 1:
		_charging = true
		_charge = minf(_charge + get_process_delta_time(), CHARGE_MAX)
	elif _charging:
		_charging = false
		_swing = SWING_WINDOW
		_swing_shot = Shot.TOPSPIN if _charge > 0.28 else Shot.DRIVE
		if Input.is_action_pressed("sprint"):
			_swing_shot = Shot.SLICE
		elif Input.is_action_pressed("move_back") and _charge > 0.2:
			_swing_shot = Shot.LOB
		_shot_lab.text = SHOT_NAMES[_swing_shot]

	if _swing > 0.0 and _last != 1 and _can_reach(_bpos, _mp, REACH):
		_return_ball(1, _swing_shot, _charge / CHARGE_MAX)
		_charge = 0.0
		return

	if _last != -1 and _foe_cool <= 0.0 and _can_reach(_bpos, _fp, AI_REACH):
		var stretch: float = clampf(_flat_dist(_bpos, _fp) / AI_REACH, 0.0, 1.0)
		var wild: bool = randf() < 0.03 + 0.24 * stretch
		var pick: int = Shot.TOPSPIN
		var roll: float = randf()
		if roll < 0.18:
			pick = Shot.SLICE
		elif roll < 0.26:
			pick = Shot.LOB
		_return_ball(-1, pick, randf_range(0.45, 0.95), wild)


func _can_reach(ball: Vector3, who: Vector3, radius: float) -> bool:
	return ball.y > MIN_CONTACT and ball.y < HIT_H and _flat_dist(ball, who) < radius


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _return_ball(who: int, shot: int, power: float, wild: bool = false) -> void:
	_last = who
	_bounces = 0
	_rally += 1
	_swing = 0.0
	_foe_cool = 0.3

	var spec: Array = STROKE[shot]
	var lift: float = float(spec[0])
	var spin: float = float(spec[1])
	var lo: float = float(spec[2])
	var hi: float = float(spec[3])
	# A ball taken low needs extra lift or it goes straight into the tape.
	lift += clampf((1.0 - _bpos.y) * 2.2, 0.0, 2.6)
	# Power widens the usable speed window rather than overriding ballistics.
	hi = lerpf(lo + (hi - lo) * 0.55, hi, power)

	var from: Vector3 = _mp if who == 1 else _fp
	# Where you stand relative to the ball steers it across court.
	var steer: float = clampf((_bpos.x - from.x) * 2.2, -3.4, 3.4)
	if who == -1:
		steer = randf_range(-2.8, 2.8)
	var depth: float = LEN * 0.5 - randf_range(2.2, 4.2)
	if shot == Shot.SLICE:
		depth = LEN * 0.5 - randf_range(4.0, 5.6)
	elif shot == Shot.LOB:
		depth = LEN * 0.5 - randf_range(1.0, 2.2)
	if wild:
		steer = (1.0 if randf() < 0.5 else -1.0) * randf_range(4.8, 6.4)
		depth = LEN * 0.5 + randf_range(0.8, 3.0)

	var target := Vector3(steer, 0.0, -depth * who)
	var flat := target - _bpos
	var dist: float = Vector2(flat.x, flat.z).length()
	var speed: float = _launch_speed(_bpos.y, lift, spin, dist, lo, hi)
	_bspin = spin
	if dist < 0.05:
		_bvel = Vector3(0.0, lift, -speed * who)
	else:
		_bvel = Vector3(flat.x, 0.0, flat.z).normalized() * speed + Vector3.UP * lift
	if who == 1:
		_shot_lab.text = SHOT_NAMES[shot]


# ------------------------------------------------------------------ opponent

func _move_foe(delta: float) -> void:
	var aim := Vector3(_bpos.x, 0.0, -LEN * 0.5 + 1.8)
	if _bvel.z < -0.1:
		var t: float = (aim.z - _bpos.z) / _bvel.z
		aim.x = _bpos.x + _bvel.x * clampf(t, 0.0, 1.5) + randf_range(-0.9, 0.9)
	# Come in on a short ball, hang back on a deep one.
	if _bpos.z < -SERVICE * 0.4 and _bvel.z < 0.0:
		aim.z = -SERVICE * 0.6
	aim.x = clampf(aim.x, -DOUBLES * 0.5 - 1.5, DOUBLES * 0.5 + 1.5)
	var step: float = AI_RUN * delta
	_fp.x = move_toward(_fp.x, aim.x, step)
	_fp.z = move_toward(_fp.z, aim.z, step * 0.75)
	_foe.position = _fp
	_foe.rotation.y = PI


# ------------------------------------------------------------------ scoring

func _point(winner: int, why: String) -> void:
	_live = false
	_charge = 0.0
	_charging = false
	if winner == 1:
		_p_pts += 1
	else:
		_o_pts += 1
	_deuce_side = not _deuce_side
	if not _settle():
		_new_point("%s  %s" % [why, "Your point." if winner == 1 else "Their point."])
	_score_lab.text = _score_text()


func _settle() -> bool:
	if _p_pts >= 4 and _p_pts - _o_pts >= 2:
		_p_games += 1
		_p_pts = 0
		_o_pts = 0
		_server *= -1
		_deuce_side = false
	elif _o_pts >= 4 and _o_pts - _p_pts >= 2:
		_o_games += 1
		_p_pts = 0
		_o_pts = 0
		_server *= -1
		_deuce_side = false
	if _p_games >= GAMES_TO_WIN or _o_games >= GAMES_TO_WIN:
		_over = true
		var won: bool = _p_games > _o_games
		_msg_lab.text = "YOU WIN THE SET %d-%d" % [_p_games, _o_games] if won else "SET TO THEM %d-%d" % [_o_games, _p_games]
		if won:
			GameState.add_money(120)
			GameState.notice.emit("Took the set at Avalon. $120.")
		return true
	return false


func _new_point(msg: String) -> void:
	_live = false
	_toss = 0.0
	_rally = 0
	_bounces = 0
	_wait = 1.3
	_msg_lab.text = msg
	_shot_lab.text = ""
	_last = _server
	var side: float = 1.0 if _deuce_side else -1.0
	if _server == 1:
		_mp = Vector3(side * SINGLES * 0.28, 0.0, LEN * 0.5 + 0.7)
		_bpos = _mp + Vector3(0.0, 1.2, -0.35)
	else:
		_fp = Vector3(-side * SINGLES * 0.28, 0.0, -LEN * 0.5 - 0.7)
		_bpos = _fp + Vector3(0.0, 1.6, 0.35)
	_bvel = Vector3.ZERO
	_me.position = _mp
	_foe.position = _fp


func _score_text() -> String:
	var g := "Games  %d - %d" % [_p_games, _o_games]
	if _p_pts >= 3 and _o_pts >= 3:
		if _p_pts == _o_pts:
			return "%s      Deuce" % g
		return "%s      %s" % [g, "Advantage you" if _p_pts > _o_pts else "Advantage them"]
	return "%s      %s - %s" % [g, POINTS[mini(_p_pts, 3)], POINTS[mini(_o_pts, 3)]]


# ------------------------------------------------------------------ visuals

func _paint(delta: float) -> void:
	_ball.position = _bpos
	_shadow.position = Vector3(_bpos.x, 0.012, _bpos.z)
	var spread: float = 0.11 + _bpos.y * 0.035
	_shadow.scale = Vector3(spread, 1.0, spread)

	# Landing pin, so the flight is readable.
	if _live and _bvel.y < 0.0:
		var g: float = GRAV + _bspin * SPIN_G
		var disc: float = maxf(_bvel.y * _bvel.y + 2.0 * g * maxf(_bpos.y - BALL_R, 0.0), 0.0)
		var t: float = (_bvel.y + sqrt(disc)) / g
		_pin.visible = true
		_pin.position = Vector3(_bpos.x + _bvel.x * t, 0.014, _bpos.z + _bvel.z * t)
	else:
		_pin.visible = false

	if _live:
		var seg := _trail[_trail_at]
		seg.position = _bpos
		seg.visible = true
		var sm := seg.material_override as StandardMaterial3D
		if sm:
			sm.albedo_color.a = 0.55
		_trail_at = (_trail_at + 1) % _trail.size()
	for seg2 in _trail:
		var m := seg2.material_override as StandardMaterial3D
		if m:
			m.albedo_color.a = maxf(m.albedo_color.a - delta * 2.4, 0.0)

	# Camera behind you, aimed down court.
	var want := Vector3(_mp.x * 0.55, 5.4, LEN * 0.5 + 9.4)
	_cam.position = _cam.position.lerp(want, 1.0 - exp(-4.5 * delta))
	_cam.look_at(global_transform * Vector3(_bpos.x * 0.3, 1.0, -2.0), Vector3.UP)

	_meter.value = (_charge / CHARGE_MAX) * 100.0
	_meter.visible = _charging


func _mark_bounce(at: Vector3) -> void:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.36, 0.36)
	mark.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.9, 0.3, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override = m
	mark.rotation_degrees.x = -90.0
	mark.position = Vector3(at.x, 0.016, at.z)
	add_child(mark)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 1.6)
	tw.tween_callback(mark.queue_free)


func _build_actors() -> void:
	_me = _figure(Color("1c6fc9"), true)
	_foe = _figure(Color("b5342f"), false)
	_me.position = _mp
	_foe.position = _fp

	_ball = Node3D.new()
	add_child(_ball)
	var bm := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = BALL_R
	sp.height = BALL_R * 2.0
	bm.mesh = sp
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("d9f24a")
	bmat.emission_enabled = true
	bmat.emission = Color("d9f24a")
	bmat.emission_energy_multiplier = 0.5
	bm.material_override = bmat
	_ball.add_child(bm)

	_shadow = _decal(Color(0, 0, 0, 0.34), 1.0)
	_pin = _decal(Color(1.0, 0.85, 0.2, 0.55), 0.5)
	_pin.visible = false

	for i in 14:
		var seg := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = BALL_R * 0.8
		s.height = BALL_R * 1.6
		seg.mesh = s
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.85, 0.95, 0.3, 0.0)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		seg.material_override = sm
		seg.visible = false
		add_child(seg)
		_trail.append(seg)

	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.position = Vector3(0, 5.4, LEN * 0.5 + 9.4)
	add_child(_cam)
	_cam.current = true


## Jacob's own model for you; a plain stand-in opposite.
func _figure(tint: Color, is_jacob: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	if is_jacob:
		var look := Node3D.new()
		look.set_script(load("res://scripts/jacob_look.gd"))
		look.set("team_tint", tint)
		root.add_child(look)
		return root
	var body := MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.3
	caps.height = 1.7
	body.mesh = caps
	body.material_override = _mat(tint)
	body.position.y = 0.85
	root.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.32
	head.mesh = hs
	head.material_override = _mat(Color("d9a884"))
	head.position.y = 1.82
	root.add_child(head)
	return root


func _decal(tint: Color, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.rotation_degrees.x = -90.0
	add_child(mi)
	return mi


func _mat(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.7
	return m


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 30
	add_child(_hud)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 14
	top.add_theme_constant_override("separation", 4)
	_hud.add_child(top)

	_score_lab = Label.new()
	_score_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lab.add_theme_font_size_override("font_size", 30)
	_score_lab.add_theme_color_override("font_color", Color("ffb703"))
	top.add_child(_score_lab)

	_msg_lab = Label.new()
	_msg_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_lab.add_theme_font_size_override("font_size", 20)
	_msg_lab.add_theme_color_override("font_color", Color("f1faee"))
	top.add_child(_msg_lab)

	_shot_lab = Label.new()
	_shot_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shot_lab.add_theme_color_override("font_color", Color("9fe0ff"))
	top.add_child(_shot_lab)

	_meter = ProgressBar.new()
	_meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_meter.offset_left = -140
	_meter.offset_right = 140
	_meter.offset_top = -104
	_meter.offset_bottom = -84
	_meter.max_value = 100
	_meter.show_percentage = false
	_meter.visible = false
	_hud.add_child(_meter)

	var help := Label.new()
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 16
	help.offset_top = -78
	help.offset_right = 700
	help.offset_bottom = -12
	help.text = "WASD move    SPACE hold to charge, release to swing    SHIFT+release slice    S+release lob\nStand left or right of the ball to aim it across court    ESC leave    first to %d games" % GAMES_TO_WIN
	help.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 0.85))
	_hud.add_child(help)

	_score_lab.text = _score_text()
