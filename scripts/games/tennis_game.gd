extends CanvasLayer

# Tennis, played on a plan view of the same court the 3D scene is built from,
# so the markings mean what they look like.
#
# The ball is tracked in court metres plus a height, and arcs under gravity.
# A shot must land in the far court; two bounces or a ball out of the lines
# ends the point. Scoring is the real ladder, including deuce and advantage.

const LEN := 23.77
const DOUBLES := 10.97
const SINGLES := 8.23
const SERVICE := 6.40

const RUN := 7.2            # player movement, m/s
const REACH := 1.65         # how close you must be to play the ball
const HIT_H := 2.3          # highest ball you can reach
const GRAV := 9.8
const WIN_GAMES := 3
const RALLY_CAP := 30      # insurance: no point can hang forever
const POINTS := ["0", "15", "30", "40"]

var _view: Control
var _score_lab: Label
var _msg: Label

var _me := Vector2(0.0, LEN * 0.5 - 1.5)
var _foe := Vector2(0.0, -LEN * 0.5 + 1.5)
var _ball := Vector2(0.0, LEN * 0.5 - 2.0)
var _bvel := Vector2.ZERO
var _bh: float = 1.0
var _bvh: float = 0.0
var _bounces: int = 0
var _last_hit: int = 1      # 1 = me, -1 = them
var _live: bool = false
var _serve_timer: float = 1.0
var _swing: float = 0.0
var _foe_cool: float = 0.0
var _rally: int = 0

var _p_pts: int = 0
var _o_pts: int = 0
var _p_games: int = 0
var _o_games: int = 0
var _server: int = 1
var _over: bool = false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_new_point()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _process(delta: float) -> void:
	var step: float = minf(delta, 1.0 / 30.0)
	if not _over:
		_tick(step)
	if _view:
		_view.queue_redraw()


# ---------------------------------------------------------------- simulation

func _tick(delta: float) -> void:
	_swing = maxf(_swing - delta, 0.0)
	_foe_cool = maxf(_foe_cool - delta, 0.0)

	# You. Across the court on A/D, up and back on W/S.
	var mx: float = Input.get_axis("move_left", "move_right")
	var mz: float = Input.get_axis("move_forward", "move_back")
	_me.x = clampf(_me.x + mx * RUN * delta, -DOUBLES * 0.5 - 2.0, DOUBLES * 0.5 + 2.0)
	_me.y = clampf(_me.y + mz * RUN * delta, 0.9, LEN * 0.5 + 5.0)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("kick"):
		_swing = 0.18

	if not _live:
		_serve_timer -= delta
		if _serve_timer <= 0.0:
			_launch_serve()
		return

	_move_foe(delta)

	# Ball.
	_ball += _bvel * delta
	_bvh -= GRAV * delta
	_bh += _bvh * delta
	if _bh <= 0.0:
		_bh = 0.0
		_bvh = -_bvh * 0.62
		_bvel *= 0.76
		_bounces += 1
		if not _inside(_ball):
			_point(-_last_hit, "Out.")
			return
		if _bounces >= 2:
			_point(_last_hit, "Two bounces.")
			return

	_try_hit()

	# Past the baselines with nobody on it.
	if absf(_ball.y) > LEN * 0.5 + 9.0:
		_point(_last_hit if _bounces > 0 else -_last_hit, "Long.")
		return
	if _rally >= RALLY_CAP:
		_live = false
		_rally = 0
		_serve_timer = 1.2
		_msg.text = "Let — replay the point."


func _launch_serve() -> void:
	_live = true
	_bounces = 0
	_rally = 0
	_last_hit = _server
	var from_y: float = (LEN * 0.5 - 1.0) * _server
	_ball = Vector2(randf_range(-2.5, 2.5) * _server, from_y)
	_bh = 1.6
	_bvh = 2.4
	# Aim into the far service box.
	var aim := Vector2(randf_range(-SINGLES * 0.35, SINGLES * 0.35), -SERVICE * 0.55 * _server)
	_bvel = (aim - _ball).normalized() * randf_range(15.0, 18.0)
	_msg.text = ""


func _move_foe(delta: float) -> void:
	# Reads where the ball will cross their end and covers it, imperfectly.
	var aim: float = _ball.x
	if _bvel.y < 0.0:
		var t: float = (_foe.y - _ball.y) / minf(_bvel.y, -0.01)
		aim = _ball.x + _bvel.x * clampf(t, 0.0, 1.4)
	aim = clampf(aim + randf_range(-1.0, 1.0), -DOUBLES * 0.5, DOUBLES * 0.5)
	_foe.x = move_toward(_foe.x, aim, RUN * 0.75 * delta)
	_foe.y = move_toward(_foe.y, -LEN * 0.5 + 1.6, RUN * 0.5 * delta)


func _try_hit() -> void:
	# You, on a swing.
	if _swing > 0.0 and _last_hit != 1 and _bh < HIT_H and _ball.distance_to(_me) < REACH:
		_return_ball(1)
		return
	# Them, automatically, with a small cooldown so it is not instant.
	if _last_hit != -1 and _foe_cool <= 0.0 and _bh < HIT_H and _ball.distance_to(_foe) < REACH + 0.35:
		var stretch: float = clampf(_ball.distance_to(_foe) / (REACH + 0.35), 0.0, 1.0)
		_return_ball(-1, randf() < 0.06 + 0.42 * stretch)
		return


## Send the ball back. `who` is 1 for you, -1 for them.
func _return_ball(who: int, wild: bool = false) -> void:
	_last_hit = who
	_bounces = 0
	_rally += 1
	_swing = 0.0
	_foe_cool = 0.25
	if wild:
		# Stretched and dumped it: long, or wide of the tramlines.
		var side: float = 1.0 if randf() < 0.5 else -1.0
		var miss := Vector2(side * randf_range(4.6, 6.5), (LEN * 0.5 + randf_range(1.5, 4.5)) * -who)
		_bvel = (miss - _ball).normalized() * randf_range(17.0, 21.0)
		_bh = maxf(_bh, 0.35)
		_bvh = 4.2
		return
	var from: Vector2 = _me if who == 1 else _foe
	# Aim deep into the far court; your lateral offset from the ball steers it.
	var steer: float = clampf((_ball.x - from.x) * 1.5, -4.2, 4.2)
	if who == -1:
		steer = clampf(randf_range(-3.6, 3.6), -4.2, 4.2)
	var target := Vector2(clampf(steer, -SINGLES * 0.48, SINGLES * 0.48), -(LEN * 0.5 - randf_range(1.2, 4.0)) * who)
	var flat: Vector2 = target - _ball
	var speed: float = randf_range(17.0, 22.0) if who == 1 else randf_range(16.0, 21.0)
	_bvel = flat.normalized() * speed
	_bh = maxf(_bh, 0.35)
	_bvh = 4.2


func _inside(p: Vector2) -> bool:
	return absf(p.x) <= SINGLES * 0.5 + 0.05 and absf(p.y) <= LEN * 0.5 + 0.05


func _point(winner: int, why: String) -> void:
	_live = false
	if winner == 1:
		_p_pts += 1
	else:
		_o_pts += 1
	_settle_game()
	# _settle_game writes the result when the match ends; don't overwrite it.
	if not _over:
		_msg.text = "%s  %s" % [why, "Your point." if winner == 1 else "Their point."]
	_serve_timer = 1.3
	_score_lab.text = _score_text()


func _settle_game() -> void:
	if _p_pts >= 4 and _p_pts - _o_pts >= 2:
		_p_games += 1
		_p_pts = 0
		_o_pts = 0
		_server *= -1
	elif _o_pts >= 4 and _o_pts - _p_pts >= 2:
		_o_games += 1
		_p_pts = 0
		_o_pts = 0
		_server *= -1
	if _p_games >= WIN_GAMES or _o_games >= WIN_GAMES:
		_over = true
		var won: bool = _p_games > _o_games
		_msg.text = "YOU WIN %d-%d" % [_p_games, _o_games] if won else "YOU LOSE %d-%d" % [_o_games, _p_games]
		if won:
			GameState.add_money(60)
			GameState.notice.emit("Took the set. $60.")


func _score_text() -> String:
	var games := "Games  %d-%d" % [_p_games, _o_games]
	if _p_pts >= 3 and _o_pts >= 3:
		if _p_pts == _o_pts:
			return "%s     Deuce" % games
		return "%s     %s" % [games, "Advantage you" if _p_pts > _o_pts else "Advantage them"]
	return "%s     %s - %s" % [games, POINTS[mini(_p_pts, 3)], POINTS[mini(_o_pts, 3)]]


func _new_point() -> void:
	_live = false
	_serve_timer = 1.2
	_msg.text = "Your serve." if _server == 1 else "Their serve."
	_score_lab.text = _score_text()


# ---------------------------------------------------------------- drawing

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0d1a20")
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	_score_lab = Label.new()
	_score_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lab.add_theme_font_size_override("font_size", 28)
	_score_lab.add_theme_color_override("font_color", Color("ffb703"))
	col.add_child(_score_lab)

	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.draw.connect(_paint)
	col.add_child(_view)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 20)
	_msg.add_theme_color_override("font_color", Color("f1faee"))
	col.add_child(_msg)

	var help := Label.new()
	help.text = "WASD move     SPACE swing when the ball is close     ESC leave     first to %d games" % WIN_GAMES
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("8b949e"))
	col.add_child(help)


## Court metres to screen. Court runs up the screen, you at the bottom.
func _xf() -> Transform2D:
	var pad_w: float = DOUBLES + 9.0
	var pad_l: float = LEN + 9.0
	var s: float = minf(_view.size.x / pad_w, _view.size.y / pad_l) * 0.96
	return Transform2D(0.0, Vector2(s, s), 0.0, _view.size * 0.5)


func _paint() -> void:
	var t := _xf()
	_view.draw_set_transform_matrix(t)
	var hl: float = LEN * 0.5
	var hw: float = DOUBLES * 0.5
	var hs: float = SINGLES * 0.5

	_view.draw_rect(Rect2(-hw - 4.0, -hl - 4.0, DOUBLES + 8.0, LEN + 8.0), Color("1f4f6e"))
	_view.draw_rect(Rect2(-hw, -hl, DOUBLES, LEN), Color("2e6f5e"))

	var line := Color("f4f7f4")
	var lw: float = 0.09
	_view.draw_rect(Rect2(-hw, -hl, DOUBLES, LEN), line, false, lw)
	_view.draw_line(Vector2(-hs, -hl), Vector2(-hs, hl), line, lw)
	_view.draw_line(Vector2(hs, -hl), Vector2(hs, hl), line, lw)
	_view.draw_line(Vector2(-hs, -SERVICE), Vector2(hs, -SERVICE), line, lw)
	_view.draw_line(Vector2(-hs, SERVICE), Vector2(hs, SERVICE), line, lw)
	_view.draw_line(Vector2(0, -SERVICE), Vector2(0, SERVICE), line, lw)
	# Net.
	_view.draw_line(Vector2(-hw - 0.9, 0), Vector2(hw + 0.9, 0), Color("11161a"), 0.22)

	# Shadow under the ball, then the ball lifted by its height.
	_view.draw_circle(_ball, 0.16 + _bh * 0.03, Color(0, 0, 0, 0.3))
	_view.draw_circle(_ball - Vector2(0, _bh * 0.42), 0.19, Color("d9f24a"))

	_player(_me, Color("1d6fd0"), _swing > 0.0)
	_player(_foe, Color("e03131"), false)
	_view.draw_set_transform_matrix(Transform2D())


func _player(at: Vector2, tint: Color, swinging: bool) -> void:
	_view.draw_circle(at, 0.42, tint)
	if swinging:
		_view.draw_arc(at, REACH, 0.0, TAU, 28, Color(1, 1, 1, 0.5), 0.07)
	else:
		_view.draw_arc(at, REACH, 0.0, TAU, 28, Color(1, 1, 1, 0.14), 0.05)
