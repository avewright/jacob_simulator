extends CanvasLayer

# Foosball. Top-down table, eight rods in the real interleaved order:
#
#   you   GK(1)  DEF(2)   .    MID(5)   .    ATT(3)   .      .
#   them    .      .    ATT(3)   .    MID(5)   .    DEF(2) GK(1)
#
# Your four rods slide together — A/D or the mouse — and Space kicks with
# whichever of your figures is close enough to reach the ball.

const W := 980.0          # table length, goal to goal
const H := 520.0          # table width, the direction rods slide
const GOAL := 150.0       # goal mouth, centred on H
const BALL_R := 9.0
const FIG_R := 15.0
const REACH := 26.0
const SLIDE := 2.1        # rod travel, full sweep per ~second
const STALL := 2.0        # seconds of a dead ball before it is re-served
const FRICTION := 0.55
const MAX_SPEED := 1150.0
const WIN := 5

# rod: [x fraction, figure count, is_player]
const RODS := [
	[1.0 / 9.0, 1, true], [2.0 / 9.0, 2, true], [3.0 / 9.0, 3, false],
	[4.0 / 9.0, 5, true], [5.0 / 9.0, 5, false], [6.0 / 9.0, 3, true],
	[7.0 / 9.0, 2, false], [8.0 / 9.0, 1, false],
]

var _view: Control
var _hud: Label
var _msg: Label

var _ball := Vector2(W * 0.5, H * 0.5)
var _vel := Vector2.ZERO
var _p_off: float = 0.0
var _a_off: float = 0.0
var _p_kick: float = 0.0
var _a_kick: float = 0.0
var _a_delay: float = 0.0
var _stall: float = 0.0
var _p_score: int = 0
var _a_score: int = 0
var _serve: float = 0.9
var _over: bool = false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_reset()


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
	if _serve > 0.0:
		_serve -= delta
		if _serve <= 0.0:
			_vel = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 340.0
			_msg.text = ""
		return

	# Your rods.
	var want: float = Input.get_axis("move_left", "move_right")
	if absf(want) < 0.01:
		want = Input.get_axis("move_forward", "move_back")
	_p_off = clampf(_p_off + want * SLIDE * delta, -1.0, 1.0)
	_p_kick = maxf(_p_kick - delta, 0.0)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("kick"):
		_p_kick = 0.14

	# Their rods track the ball, with a reaction delay and a little slop.
	_a_delay -= delta
	if _a_delay <= 0.0:
		_a_delay = randf_range(0.05, 0.16)
	var target: float = (_ball.y - H * 0.5) / (H * 0.5) + randf_range(-0.06, 0.06)
	_a_off = move_toward(_a_off, clampf(target, -1.0, 1.0), SLIDE * 0.82 * delta)
	_a_kick = maxf(_a_kick - delta, 0.0)

	# Ball.
	_vel *= pow(FRICTION, delta)
	_ball += _vel * delta
	if _ball.y < BALL_R:
		_ball.y = BALL_R
		_vel.y = absf(_vel.y) * 0.86
	elif _ball.y > H - BALL_R:
		_ball.y = H - BALL_R
		_vel.y = -absf(_vel.y) * 0.86

	_figures(delta)

	# Only rescue a ball that has actually died somewhere no rod can poke it —
	# roughly a fifth of the table. A slow ball beside a figure is still in play.
	if _vel.length() < 26.0 and not _reachable():
		_stall += delta
		if _stall >= STALL:
			_stall = 0.0
			_ball = Vector2(W * 0.5, H * 0.5)
			_vel = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 320.0
			_msg.text = "Dead ball — back to centre."
	else:
		_stall = 0.0

	# Goals and end walls.
	var in_mouth: bool = absf(_ball.y - H * 0.5) < GOAL * 0.5
	if _ball.x < BALL_R:
		if in_mouth:
			_goal(false)
			return
		_ball.x = BALL_R
		_vel.x = absf(_vel.x) * 0.86
	elif _ball.x > W - BALL_R:
		if in_mouth:
			_goal(true)
			return
		_ball.x = W - BALL_R
		_vel.x = -absf(_vel.x) * 0.86

	if _vel.length() > MAX_SPEED:
		_vel = _vel.normalized() * MAX_SPEED


## Could any rod reach the ball if it slid to meet it? Rods move freely in y,
## so in practice this comes down to the gaps in x between them and the dead
## zones behind each goal.
func _reachable() -> bool:
	var grab: float = FIG_R + BALL_R + REACH
	for rod in RODS:
		var rx: float = W * float(rod[0])
		if absf(_ball.x - rx) > grab:
			continue
		var count: int = int(rod[1])
		var reach_y: float = _travel(count) + grab
		for f in count:
			var base: float = H * (f + 1) / float(count + 1)
			if absf(_ball.y - base) <= reach_y:
				return true
	return false


## How far an n-man rod may slide before its outer figure leaves the table.
func _travel(count: int) -> float:
	return maxf(H / float(count + 1) - FIG_R, 0.0)


## Collide the ball against every figure, and let a kicking rod strike it.
func _figures(delta: float) -> void:
	for rod in RODS:
		var rx: float = W * float(rod[0])
		var count: int = int(rod[1])
		var mine: bool = bool(rod[2])
		var norm: float = _p_off if mine else _a_off
		var off: float = norm * _travel(count)
		var kicking: bool = (_p_kick > 0.0) if mine else (_a_kick > 0.0)
		for f in count:
			var fy: float = H * (f + 1) / float(count + 1) + off
			var to_ball: Vector2 = _ball - Vector2(rx, fy)
			var dist: float = to_ball.length()
			if dist > FIG_R + BALL_R + (REACH if kicking else 0.0):
				continue
			var dir: Vector2 = to_ball.normalized() if dist > 0.001 else Vector2(1, 0)
			if kicking:
				# Kick down the table, with the offset deciding the angle.
				var forward: float = 1.0 if mine else -1.0
				_vel = Vector2(forward, clampf(dir.y, -0.8, 0.8) * 0.9).normalized() * randf_range(720.0, 980.0)
				if mine:
					_p_kick = 0.0
				else:
					_a_kick = 0.0
				_ball = Vector2(rx, fy) + Vector2(forward, 0) * (FIG_R + BALL_R + 2.0)
				return
			# Otherwise the figure is a solid post.
			_ball = Vector2(rx, fy) + dir * (FIG_R + BALL_R)
			_vel = _vel.bounce(dir.orthogonal()) * 0.72

	# The keeper side that owns the half will poke at a loose ball.
	if _a_kick <= 0.0 and _ball.x > W * 0.55 and randf() < delta * 2.4:
		_a_kick = 0.14


func _goal(player_scored: bool) -> void:
	if player_scored:
		_p_score += 1
	else:
		_a_score += 1
	_hud.text = "YOU  %d          %d  OPS" % [_p_score, _a_score]
	if _p_score >= WIN or _a_score >= WIN:
		_over = true
		var won: bool = _p_score > _a_score
		_msg.text = "YOU WIN %d-%d" % [_p_score, _a_score] if won else "OPS TAKE IT %d-%d" % [_a_score, _p_score]
		if won:
			GameState.add_money(25)
			GameState.notice.emit("Won the foosball. $25 off Porter.")
		return
	_msg.text = "GOAL" if player_scored else "THEY SCORE"
	_reset()


func _reset() -> void:
	_ball = Vector2(W * 0.5, H * 0.5)
	_vel = Vector2.ZERO
	_serve = 0.9
	_stall = 0.0
	if _msg.text == "":
		_msg.text = "READY"


# ---------------------------------------------------------------- drawing

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("101418")
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	_hud = Label.new()
	_hud.text = "YOU  0          0  OPS"
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 30)
	_hud.add_theme_color_override("font_color", Color("ffb703"))
	col.add_child(_hud)

	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.draw.connect(_paint)
	col.add_child(_view)

	_msg = Label.new()
	_msg.text = "READY"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 22)
	_msg.add_theme_color_override("font_color", Color("f1faee"))
	col.add_child(_msg)

	var help := Label.new()
	help.text = "A / D slide your rods     SPACE kick     ESC leave     first to %d" % WIN
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("8b949e"))
	col.add_child(help)


## Table space is W x H; fit it into the control and centre it.
func _xf() -> Transform2D:
	var s: float = minf(_view.size.x / W, _view.size.y / H) * 0.94
	var origin := Vector2((_view.size.x - W * s) * 0.5, (_view.size.y - H * s) * 0.5)
	return Transform2D(0.0, Vector2(s, s), 0.0, origin)


func _paint() -> void:
	var t := _xf()
	var s: float = t.x.x

	_view.draw_set_transform_matrix(t)
	_view.draw_rect(Rect2(0, 0, W, H), Color("1f6b34"))
	_view.draw_rect(Rect2(0, 0, W, H), Color("0d3d1e"), false, 6.0)
	_view.draw_line(Vector2(W * 0.5, 0), Vector2(W * 0.5, H), Color("2f8f4a"), 3.0)
	_view.draw_circle(Vector2(W * 0.5, H * 0.5), 70.0, Color(1, 1, 1, 0.05))
	# Goal mouths.
	for gx in [0.0, W]:
		_view.draw_rect(Rect2(gx - 10.0, H * 0.5 - GOAL * 0.5, 20.0, GOAL), Color("11151a"))

	for rod in RODS:
		var rx: float = W * float(rod[0])
		var count: int = int(rod[1])
		var mine: bool = bool(rod[2])
		var norm: float = _p_off if mine else _a_off
		var off: float = norm * _travel(count)
		_view.draw_line(Vector2(rx, -14.0), Vector2(rx, H + 14.0), Color("9aa4ad"), 4.0)
		var tint := Color("e03131") if mine else Color("1d6fd0")
		var kicking: bool = (_p_kick > 0.0) if mine else (_a_kick > 0.0)
		for f in count:
			var fy: float = H * (f + 1) / float(count + 1) + off
			_view.draw_circle(Vector2(rx, fy), FIG_R, tint)
			if kicking:
				_view.draw_arc(Vector2(rx, fy), FIG_R + 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.55), 3.0)

	_view.draw_circle(_ball, BALL_R, Color("f8f4e6"))
	_view.draw_circle(_ball, BALL_R * 0.5, Color("d8d0b8"))
	_view.draw_set_transform_matrix(Transform2D())
	if s <= 0.0:
		return
