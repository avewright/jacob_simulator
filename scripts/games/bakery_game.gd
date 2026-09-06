extends CanvasLayer

# Lilli's bake. Six timed prep steps, each its own small mouse game, each
# scored out of 100, then a star grade on the average.
#
# You play Lilli, not Jacob — he is holding the door.
#
#   CRACK     click as the marker crosses the middle of the bar, three times
#   WHISK     circle the mouse in the bowl to build the batter
#   ROLL      sweep the pin across the dough until every band is flat
#   CUT       click inside each cutter ring before the timer runs out
#   BAKE      pull the tray out as the gauge reaches the window
#   DECORATE  click the marked spots to place cherries
#
# Everything is drawn in one Control so there is no layout to go wrong.

const STEPS := ["CRACK", "WHISK", "ROLL", "CUT", "BAKE", "DECORATE"]
const HINTS := {
	"CRACK": "Click as the marker crosses the middle. Three eggs.",
	"WHISK": "Circle the mouse inside the bowl. Keep going.",
	"ROLL": "Sweep left and right across the dough until it is even.",
	"CUT": "Click inside each ring before time runs out.",
	"BAKE": "Watch the gauge. Click inside the window to pull the tray.",
	"DECORATE": "Click each marked spot to place a cherry.",
}
const STEP_TIME := 11.0
const CREAM := Color("f6ecd9")
const CRUST := Color("c08b4e")
const BERRY := Color("8c3b52")
const PINK := Color("d988a8")

var _view: Control
var _title: Label
var _hint: Label
var _tally: Label

var _step: int = -1
var _t: float = 0.0
var _score: float = 0.0
var _scores: Array[float] = []
var _done: bool = false
var _intro: float = 1.6

# per-step state
var _marker: float = 0.0
var _dir: float = 1.0
var _eggs: int = 0
var _whisk: float = 0.0
var _last_ang: float = 0.0
var _bands: Array[float] = []
var _rings: Array = []
var _gauge: float = 0.0
var _pulled: bool = false
var _spots: Array = []
var _flash: float = 0.0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_begin(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
		return
	if _done or _intro > 0.0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(_mouse())


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _process(delta: float) -> void:
	var step: float = minf(delta, 1.0 / 30.0)
	_flash = maxf(_flash - step, 0.0)
	if _intro > 0.0:
		_intro -= step
	elif not _done:
		_tick(step)
	if _view:
		_view.queue_redraw()


# ---------------------------------------------------------------- steps

func _begin(i: int) -> void:
	_step = i
	_t = STEP_TIME
	_score = 0.0
	_intro = 1.4
	_flash = 0.0
	var step: String = STEPS[i]
	_title.text = "%d / %d    %s" % [i + 1, STEPS.size(), step]
	_hint.text = String(HINTS[step])
	match step:
		"CRACK":
			_marker = 0.0
			_dir = 1.0
			_eggs = 0
		"WHISK":
			_whisk = 0.0
			_last_ang = 0.0
		"ROLL":
			_bands.clear()
			for b in 12:
				_bands.append(0.0)
		"CUT":
			_rings.clear()
			for r in 6:
				_rings.append({
					"at": Vector2(randf_range(180.0, 780.0), randf_range(180.0, 420.0)),
					"cut": false,
				})
		"BAKE":
			_gauge = 0.0
			_pulled = false
		"DECORATE":
			_spots.clear()
			for s in 7:
				var a: float = TAU * s / 7.0
				_spots.append({
					"at": Vector2(480.0, 300.0) + Vector2(sin(a), cos(a)) * randf_range(90.0, 150.0),
					"done": false,
				})


func _tick(delta: float) -> void:
	_t -= delta
	match STEPS[_step]:
		"CRACK":
			_marker += _dir * delta * 1.35
			if _marker > 1.0:
				_marker = 1.0
				_dir = -1.0
			elif _marker < 0.0:
				_marker = 0.0
				_dir = 1.0
			if _eggs >= 3:
				_finish()
				return
		"WHISK":
			var c := Vector2(480.0, 300.0)
			var m: Vector2 = _mouse() - c
			if m.length() > 60.0 and m.length() < 220.0:
				var ang: float = m.angle()
				var d: float = wrapf(ang - _last_ang, -PI, PI)
				if absf(d) < 0.9:
					_whisk += absf(d)
				_last_ang = ang
			else:
				_last_ang = m.angle()
			_score = clampf(_whisk / (TAU * 7.0) * 100.0, 0.0, 100.0)
			if _score >= 100.0:
				_finish()
				return
		"ROLL":
			var m: Vector2 = _mouse()
			if m.y > 200.0 and m.y < 400.0:
				var n: float = float(_bands.size())
				var idx: int = int(clampf((m.x - 180.0) / 600.0 * n, 0.0, n - 1.0))
				_bands[idx] = minf(_bands[idx] + delta * 2.6, 1.0)
			var sum: float = 0.0
			for b: float in _bands:
				sum += b
			_score = sum / float(_bands.size()) * 100.0
			if _score >= 99.0:
				_finish()
				return
		"CUT":
			var got: int = 0
			for r: Dictionary in _rings:
				if r["cut"]:
					got += 1
			_score = float(got) / float(_rings.size()) * 100.0
			if got == _rings.size():
				_finish()
				return
		"BAKE":
			if not _pulled:
				_gauge = minf(_gauge + delta * 0.14, 1.2)
				if _gauge >= 1.2:
					_score = 0.0
					_finish()
					return
		"DECORATE":
			var placed: int = 0
			for s: Dictionary in _spots:
				if s["done"]:
					placed += 1
			_score = float(placed) / float(_spots.size()) * 100.0
			if placed == _spots.size():
				_finish()
				return
	if _t <= 0.0:
		_finish()


func _click(at: Vector2) -> void:
	match STEPS[_step]:
		"CRACK":
			# Nearer the middle of the sweep is a cleaner crack.
			var off: float = absf(_marker - 0.5) * 2.0
			var got: float = clampf((1.0 - off) * 130.0 - 22.0, 0.0, 100.0)
			_score = (_score * _eggs + got) / float(_eggs + 1)
			_eggs += 1
			_flash = 0.25
		"CUT":
			for r: Dictionary in _rings:
				if not r["cut"] and at.distance_to(r["at"]) < 46.0:
					r["cut"] = true
					_flash = 0.2
					return
		"BAKE":
			if _pulled:
				return
			_pulled = true
			# The window sits at 0.78..0.94; dead centre is a perfect bake.
			var d: float = absf(_gauge - 0.86)
			_score = clampf(100.0 - d * 480.0, 0.0, 100.0)
			_flash = 0.3
			_finish()
		"DECORATE":
			for s: Dictionary in _spots:
				if not s["done"] and at.distance_to(s["at"]) < 40.0:
					s["done"] = true
					_flash = 0.15
					return


func _finish() -> void:
	# Cracking is scored as an average per egg, so an egg you never got to
	# has to count against you or idling out would read as a clean run.
	if STEPS[_step] == "CRACK":
		_score *= clampf(_eggs / 3.0, 0.0, 1.0)
	_scores.append(clampf(_score, 0.0, 100.0))
	if _step + 1 < STEPS.size():
		_begin(_step + 1)
		return
	_done = true
	var total: float = 0.0
	for s: float in _scores:
		total += s
	var avg: float = total / float(_scores.size())
	var stars: int = 3 if avg >= 82.0 else (2 if avg >= 60.0 else 1)
	var payouts: Array[int] = [0, 25, 55, 110]
	var purse: int = payouts[stars]
	GameState.add_money(purse)
	_title.text = "%s    %d%%" % ["★".repeat(stars) + "☆".repeat(3 - stars), int(round(avg))]
	_hint.text = "Lilli pays you $%d. Esc to leave." % purse
	GameState.notice.emit("Baked with Lilli — %d stars, $%d." % [stars, purse])
	_tally.text = _breakdown()


func _breakdown() -> String:
	var parts: Array[String] = []
	for i in _scores.size():
		parts.append("%s %d" % [STEPS[i], int(round(_scores[i]))])
	return "   ".join(parts)


# ---------------------------------------------------------------- drawing

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("2a1c20")
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var who := Label.new()
	who.text = "LILLI'S BAKERY   —   you are Lilli"
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", 16)
	who.add_theme_color_override("font_color", PINK)
	col.add_child(who)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", CREAM)
	col.add_child(_title)

	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.draw.connect(_paint)
	col.add_child(_view)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", CREAM)
	col.add_child(_hint)

	_tally = Label.new()
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally.add_theme_color_override("font_color", Color("b79b86"))
	col.add_child(_tally)


## The board is 960x600; fit it to the control and centre it.
func _xf() -> Transform2D:
	var s: float = minf(_view.size.x / 960.0, _view.size.y / 600.0) * 0.96
	return Transform2D(0.0, Vector2(s, s), 0.0,
		Vector2((_view.size.x - 960.0 * s) * 0.5, (_view.size.y - 600.0 * s) * 0.5))


## Mouse position in board coordinates. The board is drawn through _xf(), so
## the raw control-space position has to come back through its inverse.
func _mouse() -> Vector2:
	if _view == null or _view.size.x < 1.0:
		return Vector2(480, 300)
	return _xf().affine_inverse() * _view.get_local_mouse_position()


func _paint() -> void:
	if _view.size.x < 1.0:
		return
	_view.draw_set_transform_matrix(_xf())
	_view.draw_rect(Rect2(0, 0, 960, 600), Color("3a2a2c"))
	_view.draw_rect(Rect2(24, 24, 912, 552), Color("6b4a34"))
	_view.draw_rect(Rect2(36, 36, 888, 528), Color("e8dcc4"))

	if _done:
		_view.draw_set_transform_matrix(Transform2D())
		return

	# Timer strip.
	var frac: float = clampf(_t / STEP_TIME, 0.0, 1.0)
	_view.draw_rect(Rect2(36, 36, 888.0 * frac, 12), BERRY if frac < 0.3 else PINK)

	match STEPS[_step]:
		"CRACK": _draw_crack()
		"WHISK": _draw_whisk()
		"ROLL": _draw_roll()
		"CUT": _draw_cut()
		"BAKE": _draw_bake()
		"DECORATE": _draw_decorate()

	if _intro > 0.0:
		_view.draw_rect(Rect2(36, 36, 888, 528), Color(0.12, 0.08, 0.09, clampf(_intro, 0.0, 0.8)))
	if _flash > 0.0:
		_view.draw_rect(Rect2(36, 36, 888, 528), Color(1, 1, 1, _flash * 0.5))
	_view.draw_set_transform_matrix(Transform2D())


func _draw_crack() -> void:
	_view.draw_rect(Rect2(180, 380, 600, 26), Color("cbb99a"))
	_view.draw_rect(Rect2(180 + 264, 380, 72, 26), Color("7fbf6a"))
	var mx: float = 180.0 + _marker * 600.0
	_view.draw_rect(Rect2(mx - 4, 368, 8, 50), BERRY)
	for e in 3:
		var c := Vector2(360.0 + e * 120.0, 240.0)
		if e < _eggs:
			_view.draw_circle(c, 34.0, Color("f3d98a"))
			_view.draw_circle(c, 15.0, Color("e8a12c"))
		else:
			_view.draw_circle(c, 30.0, CREAM)
			_view.draw_circle(c + Vector2(-8, -8), 9.0, Color("fffaf0"))


func _draw_whisk() -> void:
	var c := Vector2(480, 300)
	_view.draw_circle(c, 220.0, Color("cbb99a"))
	_view.draw_circle(c, 205.0, Color("f6ecd9"))
	var fill: float = clampf(_score / 100.0, 0.0, 1.0)
	_view.draw_circle(c, 60.0 + 140.0 * fill, Color("e9c877"))
	_view.draw_arc(c, 205.0, 0.0, TAU * fill, 64, CRUST, 8.0)
	_view.draw_circle(_mouse(), 12.0, BERRY)


func _draw_roll() -> void:
	var n := _bands.size()
	for i in n:
		var x: float = 180.0 + 600.0 * i / float(n)
		var w: float = 600.0 / float(n)
		var h: float = lerpf(120.0, 46.0, _bands[i])
		_view.draw_rect(Rect2(x, 300.0 - h * 0.5, w - 2.0, h), Color("efd9a0").lerp(Color("e3c37e"), _bands[i]))
	var mx: float = clampf(_mouse().x, 180.0, 780.0)
	_view.draw_rect(Rect2(mx - 12, 190, 24, 220), Color("a8763f"))
	_view.draw_circle(Vector2(mx, 186), 14.0, Color("8a5f31"))
	_view.draw_circle(Vector2(mx, 414), 14.0, Color("8a5f31"))


func _draw_cut() -> void:
	_view.draw_rect(Rect2(150, 150, 660, 300), Color("efd9a0"))
	for r: Dictionary in _rings:
		var at: Vector2 = r["at"]
		if r["cut"]:
			_view.draw_circle(at, 40.0, Color("d8bd82"))
			_view.draw_arc(at, 40.0, 0.0, TAU, 30, CRUST, 5.0)
		else:
			_view.draw_arc(at, 42.0, 0.0, TAU, 30, BERRY, 4.0)
			_view.draw_arc(at, 30.0, 0.0, TAU, 24, Color(0.55, 0.23, 0.32, 0.5), 2.0)


func _draw_bake() -> void:
	_view.draw_rect(Rect2(300, 140, 360, 300), Color("6b5340"))
	_view.draw_rect(Rect2(320, 160, 320, 260), Color("2a1e18"))
	var heat: float = clampf(_gauge, 0.0, 1.2) / 1.2
	_view.draw_rect(Rect2(320, 160, 320, 260), Color(1.0, 0.55, 0.2, 0.15 + heat * 0.45))
	_view.draw_rect(Rect2(380, 330, 200, 44), Color("d8bd82").lerp(Color("8a5426"), clampf(_gauge, 0.0, 1.0)))
	# Gauge with the window marked on it.
	_view.draw_rect(Rect2(700, 150, 40, 290), Color("cbb99a"))
	_view.draw_rect(Rect2(700, 150 + 290 * (1.0 - 0.94), 40, 290 * 0.16), Color("7fbf6a"))
	var gy: float = 150.0 + 290.0 * (1.0 - clampf(_gauge, 0.0, 1.0))
	_view.draw_rect(Rect2(692, gy - 3, 56, 6), BERRY)


func _draw_decorate() -> void:
	var c := Vector2(480, 300)
	_view.draw_circle(c, 190.0, Color("e3c37e"))
	_view.draw_circle(c, 172.0, Color("f6ecd9"))
	_view.draw_circle(c, 150.0, PINK.lightened(0.25))
	for s: Dictionary in _spots:
		var at: Vector2 = s["at"]
		if s["done"]:
			_view.draw_circle(at, 15.0, BERRY)
			_view.draw_circle(at + Vector2(-4, -4), 5.0, Color("d8697f"))
		else:
			_view.draw_arc(at, 20.0, 0.0, TAU, 22, Color(0.55, 0.23, 0.32, 0.65), 3.0)
