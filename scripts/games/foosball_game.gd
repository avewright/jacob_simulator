extends CanvasLayer

# Foosball with rods that actually rotate.
#
# A figure is a post while its rod is upright. Kicking swings the rod, sweeping
# the foot forward through an arc; if the foot catches the ball it is struck
# with the foot's own velocity, so timing and where the ball sits on the arc
# both matter. Sliding while you swing angles the shot.
#
# Rods run in the real order out from your goal — GK 3, DEF 2, MID 5, ATT 3 a
# side, interleaved — and you drive two at a time: the defensive pair while the
# ball is in your half, the attacking pair once it crosses over.

const W := 1180.0          # table length, goal to goal
const H := 620.0           # table width, the direction rods slide
const GOAL := 216.0
const BALL_R := 8.0
const FIG_R := 11.0
const FOOT := 40.0         # how far a foot reaches at full swing
const WALL_BOUNCE := 0.62
const ROLL := 0.80         # fraction of speed kept per second
const MAX_SPEED := 1500.0
const SLIDE := 2.4         # normalised rod sweeps per second
const SWING_BACK := -0.55
const SWING_THROUGH := 1.35
const SWING_RATE := 19.0
const STALL := 2.2
const TRAP := 300.0        # below this against a figure, the rod has the ball
const WIN := 5

# x fraction, figure count, is_player
const RODS := [
	[1.0 / 9.0, 3, true], [2.0 / 9.0, 2, true], [3.0 / 9.0, 3, false],
	[4.0 / 9.0, 5, true], [5.0 / 9.0, 5, false], [6.0 / 9.0, 3, true],
	[7.0 / 9.0, 2, false], [8.0 / 9.0, 3, false],
]
const MY_BACK := [0, 1]
const MY_FRONT := [3, 5]
const AI_FRONT := [2, 4]
const AI_BACK := [6, 7]

# react, track, lead, window, power, error, purse, blurb
const FOES := {
	"Jase Dobblestein": [0.42, 0.40, 0.15, 0.22, 0.60, 0.46, 15, "Plays one-handed. Talks the entire time."],
	"Wei Tan": [0.16, 0.85, 0.65, 0.55, 0.88, 0.14, 45, "Office champion. Beat Ralph 10-2."],
	"Kirby Bach": [0.03, 1.45, 1.00, 0.95, 1.00, 0.012, 150, "Nobody has taken a game off him."],
}

var _view: Control
var _hud: Label
var _sub: Label
var _msg: Label
var _picker: ColorRect

var _foe_name: String = "Wei Tan"
var _react: float = 0.16
var _track: float = 0.85
var _lead: float = 0.65
var _window: float = 0.55
var _power: float = 0.88
var _error: float = 0.14
var _purse: int = 45

var _off: Array[float] = []
var _ang: Array[float] = []
var _spin_rate: Array[float] = []
var _kicking: Array[bool] = []
var _prev_off: Array[float] = []
var _off_vel: Array[float] = []

var _ball := Vector2(W * 0.5, H * 0.5)
var _bvel := Vector2.ZERO
var _curl: float = 0.0
var _stall: float = 0.0
var _serve: float = 1.0
var _think: float = 0.0
var _ai_target: float = 0.0
var _p_score: int = 0
var _a_score: int = 0
var _shots: int = 0
var _over: bool = false
var _started: bool = false
var _flash: float = 0.0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in RODS.size():
		_off.append(0.0)
		_ang.append(0.0)
		_spin_rate.append(0.0)
		_kicking.append(false)
		_prev_off.append(0.0)
		_off_vel.append(0.0)
	_build()


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
	_flash = maxf(_flash - step, 0.0)
	if _started and not _over:
		_tick(step)
	if _view:
		_view.queue_redraw()


func _choose(foe: String) -> void:
	var spec: Array = FOES[foe]
	_foe_name = foe
	_react = float(spec[0])
	_track = float(spec[1])
	_lead = float(spec[2])
	_window = float(spec[3])
	_power = float(spec[4])
	_error = float(spec[5])
	_purse = int(spec[6])
	_picker.visible = false
	_started = true
	_sub.text = "vs %s  —  first to %d" % [_foe_name, WIN]
	_hud.text = "YOU  0          0  %s" % _short()
	_reset("READY")


func _short() -> String:
	return _foe_name.split(" ")[0].to_upper()


# ---------------------------------------------------------------- simulation

func _tick(delta: float) -> void:
	for i in RODS.size():
		_prev_off[i] = _off[i]
	_drive_rods(delta)
	# Lateral speed of each rod, in table units — this is what lets a rod carry
	# a trapped ball sideways instead of just letting it sit there.
	for i in RODS.size():
		_off_vel[i] = (_off[i] - _prev_off[i]) / maxf(delta, 0.0001) * _travel(int(RODS[i][1]))
	_swing_rods(delta)

	if _serve > 0.0:
		_serve -= delta
		if _serve <= 0.0:
			_bvel = Vector2(randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)).normalized() * 420.0
			_msg.text = ""
		return

	_ball += _bvel * delta
	_bvel *= pow(ROLL, delta)
	if _ball.y < BALL_R:
		_ball.y = BALL_R
		_bvel.y = absf(_bvel.y) * WALL_BOUNCE
		_curl *= 0.5
	elif _ball.y > H - BALL_R:
		_ball.y = H - BALL_R
		_bvel.y = -absf(_bvel.y) * WALL_BOUNCE
		_curl *= 0.5
	# Side-spin curls the roll a little before it dies off.
	_bvel.y += _curl * 40.0 * delta
	_curl *= pow(0.25, delta)

	_collide()

	var in_mouth: bool = absf(_ball.y - H * 0.5) < GOAL * 0.5
	if _ball.x < BALL_R:
		if in_mouth:
			_goal(false)
			return
		_ball.x = BALL_R
		_bvel.x = absf(_bvel.x) * WALL_BOUNCE
	elif _ball.x > W - BALL_R:
		if in_mouth:
			_goal(true)
			return
		_ball.x = W - BALL_R
		_bvel.x = -absf(_bvel.x) * WALL_BOUNCE

	if _bvel.length() > MAX_SPEED:
		_bvel = _bvel.normalized() * MAX_SPEED

	# Only rescue a ball that has died where no rod can poke it.
	if _bvel.length() < 24.0 and not _reachable():
		_stall += delta
		if _stall >= STALL:
			_reset("Dead ball — back to centre.")
	else:
		_stall = 0.0


## Whichever of a side's two pairs has a rod nearer the ball. A fixed halfway
## threshold left each MID rod undriven in exactly the zone it stands in, so a
## ball resting against one was stuck with nobody able to move it.
func _hand_for(a: Array, b: Array) -> Array:
	return a if _pair_dist(a) <= _pair_dist(b) else b


func _pair_dist(pair: Array) -> float:
	var best: float = INF
	for i in pair:
		best = minf(best, absf(_ball.x - W * float(RODS[i][0])))
	return best


func _my_hand() -> Array:
	return _hand_for(MY_BACK, MY_FRONT)


func _ai_hand() -> Array:
	return _hand_for(AI_BACK, AI_FRONT)


func _drive_rods(delta: float) -> void:
	var mine: Array = _my_hand()
	var want: float = Input.get_axis("move_left", "move_right")
	if absf(want) < 0.01:
		want = Input.get_axis("move_forward", "move_back")
	for i in mine:
		_off[i] = clampf(_off[i] + want * SLIDE * delta, -1.0, 1.0)
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("kick"):
		for i in mine:
			_start_kick(i)

	# The opponent reads the ball as well as its difficulty allows.
	_think -= delta
	if _think <= 0.0:
		_think = _react
		var predict: float = _ball.y
		if _bvel.x > 20.0:
			var lane: float = W * float(RODS[AI_BACK[1]][0])
			var t: float = clampf((lane - _ball.x) / maxf(_bvel.x, 1.0), 0.0, 0.9)
			predict = _ball.y + _bvel.y * t * _lead
		_ai_target = clampf((predict - H * 0.5) / (H * 0.5) + randf_range(-_error, _error), -1.0, 1.0)

	var theirs: Array = _ai_hand()
	for i in theirs:
		_off[i] = move_toward(_off[i], _ai_target, SLIDE * _track * delta)
		var urgency: float = _window
		if _bvel.length() < 90.0:
			urgency = maxf(_window, 0.7)     # loose ball: get a boot on it
		if not _kicking[i] and _can_strike(i) and randf() < urgency * delta * 26.0:
			_start_kick(i)
	# Idle rods drift back to centre so they keep covering.
	for i in RODS.size():
		if i in mine or i in theirs:
			continue
		_off[i] = move_toward(_off[i], 0.0, SLIDE * 0.5 * delta)


func _start_kick(rod: int) -> void:
	if _kicking[rod]:
		return
	_kicking[rod] = true
	_ang[rod] = SWING_BACK
	_spin_rate[rod] = SWING_RATE


func _swing_rods(delta: float) -> void:
	for i in RODS.size():
		if not _kicking[i]:
			_ang[i] = move_toward(_ang[i], 0.0, 9.0 * delta)
			_spin_rate[i] = 0.0
			continue
		_ang[i] += _spin_rate[i] * delta
		if _ang[i] >= SWING_THROUGH:
			_ang[i] = SWING_THROUGH
			_kicking[i] = false
			_spin_rate[i] = 0.0


## Is the ball roughly in front of this rod, where a swing could catch it?
func _can_strike(rod: int) -> bool:
	var rx: float = W * float(RODS[rod][0])
	var toward: float = 1.0 if bool(RODS[rod][2]) else -1.0
	var ahead: float = (_ball.x - rx) * toward
	return ahead > -FOOT * 0.6 and ahead < FOOT + FIG_R + BALL_R + 6.0


## Rod travel is about half the figure spacing, as on a real table. Letting a
## rod sweep its full half-width put the whole goal mouth inside one figure's
## reach, so the keeper never had to read anything.
func _travel(count: int) -> float:
	return H / float(count + 1) * 0.55


func _fig_y(count: int, f: int, off: float) -> float:
	return H * (f + 1) / float(count + 1) + off * _travel(count)


## Where a figure's foot sits, given how far its rod has swung.
func _foot_x(rod: int) -> float:
	var rx: float = W * float(RODS[rod][0])
	var toward: float = 1.0 if bool(RODS[rod][2]) else -1.0
	return rx + sin(_ang[rod]) * FOOT * toward


func _collide() -> void:
	for rod in RODS.size():
		var spec: Array = RODS[rod]
		var count: int = int(spec[1])
		var mine: bool = bool(spec[2])
		var toward: float = 1.0 if mine else -1.0
		var fx: float = _foot_x(rod)
		# Foot speed along the table, from the rod's angular velocity.
		var foot_v: float = cos(_ang[rod]) * FOOT * _spin_rate[rod]
		for f in count:
			var fy: float = _fig_y(count, f, _off[rod])
			var to_ball: Vector2 = _ball - Vector2(fx, fy)
			var dist: float = to_ball.length()
			if dist > FIG_R + BALL_R:
				continue
			var dir: Vector2 = to_ball.normalized() if dist > 0.001 else Vector2(toward, 0.0)
			_ball = Vector2(fx, fy) + dir * (FIG_R + BALL_R)
			if _kicking[rod] and absf(foot_v) > 60.0:
				# Struck. The foot's own speed goes into the ball, and where it
				# met the figure turns that into an angle.
				var aim: float = clampf(dir.y, -0.85, 0.85)
				var pace: float = absf(foot_v) * (1.0 if mine else _power)
				_bvel = Vector2(toward, aim * 1.15).normalized() * clampf(pace, 420.0, MAX_SPEED)
				_curl = aim * 2.0
				_kicking[rod] = false
				_ang[rod] = SWING_THROUGH
				if mine:
					_shots += 1
				return
			# A slow ball against the face of a figure is under control: it
			# rides along with the rod so you can walk it across the goal and
			# pick your angle before you shoot.
			if absf(dir.x) > 0.4 and _bvel.length() < TRAP:
				_bvel = Vector2(_bvel.x * 0.18, _off_vel[rod])
				return
			# Otherwise it is a post and the ball rebounds off it.
			_bvel = _bvel.bounce(dir.orthogonal()) * 0.84
			return


## Could any rod reach the ball if it slid to meet it?
func _reachable() -> bool:
	var grab: float = FIG_R + BALL_R + FOOT
	for rod in RODS.size():
		var rx: float = W * float(RODS[rod][0])
		if absf(_ball.x - rx) > grab:
			continue
		var count: int = int(RODS[rod][1])
		var span: float = _travel(count) + grab
		for f in count:
			if absf(_ball.y - H * (f + 1) / float(count + 1)) <= span:
				return true
	return false


func _goal(mine: bool) -> void:
	if mine:
		_p_score += 1
	else:
		_a_score += 1
	_flash = 0.8
	_hud.text = "YOU  %d          %d  %s" % [_p_score, _a_score, _short()]
	if _p_score >= WIN or _a_score >= WIN:
		_over = true
		if _p_score > _a_score:
			_msg.text = "YOU BEAT %s  %d-%d" % [_foe_name.to_upper(), _p_score, _a_score]
			GameState.add_money(_purse)
			GameState.notice.emit("Beat %s at foosball. $%d." % [_short().capitalize(), _purse])
		else:
			_msg.text = "%s WINS  %d-%d" % [_foe_name.to_upper(), _a_score, _p_score]
		return
	_reset("GOAL" if mine else "%s SCORES" % _short())


func _reset(msg: String) -> void:
	_ball = Vector2(W * 0.5, H * 0.5)
	_bvel = Vector2.ZERO
	_curl = 0.0
	_serve = 0.95
	_stall = 0.0
	_msg.text = msg
	for i in RODS.size():
		_kicking[i] = false
		_ang[i] = 0.0
		_spin_rate[i] = 0.0


# ---------------------------------------------------------------- chrome

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0d1116")
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	_hud = Label.new()
	_hud.text = "YOU  0          0  —"
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 32)
	_hud.add_theme_color_override("font_color", Color("ffb703"))
	col.add_child(_hud)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color("9aa4b2"))
	col.add_child(_sub)

	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.draw.connect(_paint)
	col.add_child(_view)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 22)
	_msg.add_theme_color_override("font_color", Color("f1faee"))
	col.add_child(_msg)

	var help := Label.new()
	help.text = "A / D slide     SPACE kick     you drive the back pair in your half, the front pair in theirs     ESC leave"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("6f7987"))
	col.add_child(help)

	_build_picker()


func _build_picker() -> void:
	_picker = ColorRect.new()
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.color = Color(0.03, 0.04, 0.06, 0.96)
	add_child(_picker)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -320
	box.offset_right = 320
	box.offset_top = -200
	box.offset_bottom = 200
	box.add_theme_constant_override("separation", 12)
	_picker.add_child(box)

	var title := Label.new()
	title.text = "WHO ARE YOU PLAYING?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("ffb703"))
	box.add_child(title)

	var tiers: Array[String] = ["Jase Dobblestein", "Wei Tan", "Kirby Bach"]
	var labels: Array[String] = ["EASY", "MEDIUM", "HARD"]
	for i in tiers.size():
		var who: String = tiers[i]
		var spec: Array = FOES[who]
		var b := Button.new()
		b.text = "%s  —  %s        $%d\n%s" % [labels[i], who, int(spec[6]), String(spec[7])]
		b.custom_minimum_size = Vector2(0, 76)
		b.pressed.connect(_choose.bind(who))
		box.add_child(b)

	var quit := Button.new()
	quit.text = "LEAVE  (Esc)"
	quit.custom_minimum_size = Vector2(0, 38)
	quit.pressed.connect(_close)
	box.add_child(quit)


## Table space is W x H; fit it into the control and centre it.
func _xf() -> Transform2D:
	var s: float = minf(_view.size.x / W, _view.size.y / H) * 0.95
	return Transform2D(0.0, Vector2(s, s), 0.0,
		Vector2((_view.size.x - W * s) * 0.5, (_view.size.y - H * s) * 0.5))


func _paint() -> void:
	if _view.size.x < 1.0:
		return
	_view.draw_set_transform_matrix(_xf())

	_view.draw_rect(Rect2(-20, -20, W + 40, H + 40), Color("46301f"))
	_view.draw_rect(Rect2(0, 0, W, H), Color("1f7038"))
	_view.draw_rect(Rect2(0, 0, W, H), Color("15522a"), false, 5.0)
	_view.draw_line(Vector2(W * 0.5, 0), Vector2(W * 0.5, H), Color("2f8f4a"), 3.0)
	_view.draw_arc(Vector2(W * 0.5, H * 0.5), 82.0, 0.0, TAU, 40, Color("2f8f4a"), 3.0)
	for gx in [0.0, W]:
		_view.draw_rect(Rect2(gx - 14.0, H * 0.5 - GOAL * 0.5, 28.0, GOAL), Color("11151a"))
		_view.draw_rect(Rect2(gx - 14.0, H * 0.5 - GOAL * 0.5, 28.0, GOAL), Color("ffb703"), false, 3.0)

	var mine: Array = _my_hand()
	for rod in RODS.size():
		var spec: Array = RODS[rod]
		var rx: float = W * float(spec[0])
		var count: int = int(spec[1])
		var is_mine: bool = bool(spec[2])
		var active: bool = rod in mine
		_view.draw_line(Vector2(rx, -24.0), Vector2(rx, H + 24.0),
			Color("d8dde3") if active else Color("6d757e"), 5.0 if active else 3.5)
		var fx: float = _foot_x(rod)
		var tint := Color("e03131") if is_mine else Color("2a6fd0")
		if active:
			tint = tint.lightened(0.22)
		for f in count:
			var fy: float = _fig_y(count, f, _off[rod])
			# Body sits on the rod; the foot swings out ahead of it.
			_view.draw_line(Vector2(rx, fy), Vector2(fx, fy), tint.darkened(0.3), 7.0)
			_view.draw_circle(Vector2(fx, fy), FIG_R, tint)
			_view.draw_circle(Vector2(rx, fy), FIG_R * 0.55, tint.darkened(0.35))
			if active:
				_view.draw_arc(Vector2(fx, fy), FIG_R + 5.0, 0.0, TAU, 18, Color(1, 1, 1, 0.4), 2.0)

	if _flash > 0.0:
		_view.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, _flash * 0.35))

	_view.draw_circle(_ball, BALL_R + 2.0, Color(0, 0, 0, 0.35))
	_view.draw_circle(_ball, BALL_R, Color("f8f4e6"))
	_view.draw_set_transform_matrix(Transform2D())
