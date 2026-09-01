extends CanvasLayer

const GOLD := Color("ffb703")

var _money: Label
var _fuel: Label
var _health: Label
var _state: Label
var _speed: Label
var _objective: Label
var _notice: Label
var _prompt: Label
var _minimap: Control
var _pause_root: Control
var _notice_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.money_changed.connect(func(v: int) -> void: _money.text = "$%d" % v)
	GameState.fuel_changed.connect(func(v: float) -> void: _fuel.text = "%d%%" % int(round(v)))
	GameState.car_health_changed.connect(_on_car_health)
	GameState.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	GameState.notice.connect(_flash)
	GameState.paused_changed.connect(_on_paused)
	GameState.prompt_changed.connect(func(t: String) -> void: _prompt.text = t)
	_money.text = "$%d" % GameState.money
	_fuel.text = "%d%%" % int(round(GameState.fuel))
	_objective.text = GameState.objective
	_on_car_health(GameState.car_health)


func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			_notice.visible = false
	if GameState.is_paused:
		return
	if GameState.in_car:
		_state.text = "IN CAMRY"
	elif GameState.has_clothes:
		_state.text = "ON FOOT"
	else:
		_state.text = "IN UNDERWEAR"
	_speed.text = ("%d mph" % int(round(GameState.speed_mph))) if GameState.in_car else ""
	_minimap.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.is_paused:
			_resume()
		else:
			GameState.set_paused(true)


func _on_car_health(v: float) -> void:
	_health.text = "CAR %d%%" % int(round(v))
	if v <= 0.0:
		_health.add_theme_color_override("font_color", Color("ff3b30"))
	elif v <= 25.0:
		_health.add_theme_color_override("font_color", Color("ff7a1a"))
	elif v <= 60.0:
		_health.add_theme_color_override("font_color", Color("ffd166"))
	else:
		_health.add_theme_color_override("font_color", GOLD)


func _flash(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_time = 3.2


func _on_paused(value: bool) -> void:
	_pause_root.visible = value


func _resume() -> void:
	GameState.set_paused(false)


func _save_quit() -> void:
	GameState.save_game()
	GameState.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


func _build() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 48
	top.add_theme_constant_override("separation", 10)
	add_child(top)

	_money = _pill(top, "$420")
	_fuel = _pill(top, "78%")
	_health = _pill(top, "100%")
	_state = _pill(top, "ON FOOT")
	_speed = _pill(top, "")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_objective = Label.new()
	_objective.add_theme_color_override("font_color", GOLD)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_objective)

	_notice = Label.new()
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -320
	_notice.offset_right = 320
	_notice.offset_top = 56
	_notice.offset_bottom = 88
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color.WHITE)
	_notice.visible = false
	add_child(_notice)

	var help := Label.new()
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 14
	help.offset_top = -92
	help.offset_right = 420
	help.offset_bottom = -14
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -220
	_prompt.offset_right = 220
	_prompt.offset_top = -120
	_prompt.offset_bottom = -80
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", GOLD)
	add_child(_prompt)

	help.text = "WASD move / drive   Mouse steers\nShift sprint  Space jump / handbrake  Q wave\nE Camry / clothes / arcade   R new Camry   Esc pause"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.85))
	add_child(help)

	_minimap = Control.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -176
	_minimap.offset_top = 56
	_minimap.offset_right = -16
	_minimap.offset_bottom = 216
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)

	_pause_root = ColorRect.new()
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_root.color = Color(0.02, 0.02, 0.05, 0.72)
	_pause_root.visible = false
	_pause_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -140
	box.offset_right = 140
	box.offset_top = -90
	box.offset_bottom = 90
	box.add_theme_constant_override("separation", 12)
	_pause_root.add_child(box)

	var pause_title := Label.new()
	pause_title.text = "PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 28)
	pause_title.add_theme_color_override("font_color", GOLD)
	box.add_child(pause_title)

	box.add_child(_pbtn("RESUME", _resume))
	box.add_child(_pbtn("SAVE + TITLE", _save_quit))


func _pill(parent: Control, text: String) -> Label:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_color_override("font_color", GOLD)
	wrap.add_child(lab)
	parent.add_child(wrap)
	return lab


func _pbtn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b


func _draw_minimap() -> void:
	var s := 160.0 / 780.0
	_minimap.draw_rect(Rect2(0, 0, 160, 160), Color("1e3a1e"))
	_minimap.draw_rect(Rect2((0 + 390) * s - 14 * s, 0, 28 * s, 160), Color("2a2e36"))
	for z in [-48.0, 48.0, 160.0]:
		_minimap.draw_rect(Rect2(0, (z + 390) * s - 7 * s, 160, 14 * s), Color("2a2e36"))
	for x in [-140.0, 90.0]:
		_minimap.draw_rect(Rect2((x + 390) * s - 7 * s, 0, 14 * s, 160), Color("2a2e36"))

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var car := get_tree().get_first_node_in_group("camry") as Node3D
	for m in get_tree().get_nodes_in_group("mission_marker"):
		if m is Node3D:
			var p: Vector3 = m.global_position
			_minimap.draw_circle(Vector2((p.x + 390) * s, (p.z + 390) * s), 4, Color("ffb703"))
	if car:
		_minimap.draw_circle(Vector2((car.global_position.x + 390) * s, (car.global_position.z + 390) * s), 4, Color("c1121f"))
	if player and not GameState.in_car:
		_minimap.draw_circle(Vector2((player.global_position.x + 390) * s, (player.global_position.z + 390) * s), 3, Color("0d4aa6"))
