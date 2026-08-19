extends CanvasLayer

var _score: Label
var _clock: Label
var _banner: Label
var _charge: ColorRect
var _help: Label
var _pause: ColorRect
var _banner_t: float = 0.0


func _ready() -> void:
	layer = 20
	_build()
	call_deferred("_hook_match")


func _hook_match() -> void:
	var match_n := get_tree().get_first_node_in_group("soccer_match")
	if match_n == null:
		return
	if match_n.has_signal("score_changed"):
		match_n.score_changed.connect(_on_score)
	if match_n.has_signal("clock_changed"):
		match_n.clock_changed.connect(_on_clock)
	if match_n.has_signal("bannered"):
		match_n.bannered.connect(show_banner)
	_on_score(match_n.home_score, match_n.away_score)
	_on_clock(match_n.time_left)


func _process(delta: float) -> void:
	_banner_t = maxf(0.0, _banner_t - delta)
	_banner.visible = _banner_t > 0.0
	_pause.visible = GameState.is_paused
	var captain := get_tree().get_first_node_in_group("captain")
	if captain and "charge" in captain:
		_charge.scale.x = clampf(captain.charge / 1.05, 0.04, 1.0)
		_charge.color = Color("ffb703") if captain.charge < 0.85 else Color("ff3b3b")


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_t = 99.0 if text.contains("menu") else 1.6


func _on_score(home: int, away: int) -> void:
	_score.text = "HOME  %d  —  %d  AWAY" % [home, away]


func _on_clock(seconds: float) -> void:
	var s := maxi(0, int(ceil(seconds)))
	_clock.text = "%d:%02d" % [s / 60, s % 60]


func _build() -> void:
	_score = _label(Vector2(0, 18), 28, Color("ffb703"))
	_score.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_score.offset_top = 16
	_score.offset_bottom = 56
	_score.text = "HOME  0  —  0  AWAY"

	_clock = _label(Vector2(0, 56), 20, Color(0.92, 0.94, 0.88))
	_clock.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_clock.offset_top = 54
	_clock.offset_bottom = 84
	_clock.text = "3:00"

	_banner = _label(Vector2(0, 0), 36, Color.WHITE)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -280
	_banner.offset_right = 280
	_banner.offset_top = -40
	_banner.offset_bottom = 20
	_banner.visible = false

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.45)
	bar_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bg.offset_left = 40
	bar_bg.offset_right = -40
	bar_bg.offset_top = -54
	bar_bg.offset_bottom = -42
	add_child(bar_bg)

	_charge = ColorRect.new()
	_charge.color = Color("ffb703")
	_charge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_charge.pivot_offset = Vector2.ZERO
	bar_bg.add_child(_charge)

	_help = _label(Vector2(0, 0), 13, Color(0.75, 0.78, 0.7))
	_help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -36
	_help.offset_bottom = -8
	_help.text = "J / LMB kick (hold = Super Strike)   K / RMB punch   Space slam   Esc pause"

	_pause = ColorRect.new()
	_pause.color = Color(0, 0, 0, 0.55)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var pl := Label.new()
	pl.text = "PAUSED"
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pl.add_theme_font_size_override("font_size", 42)
	pl.add_theme_color_override("font_color", Color("ffb703"))
	_pause.add_child(pl)


func _label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l
