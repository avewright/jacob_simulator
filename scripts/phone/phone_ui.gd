extends CanvasLayer

# Jacob's phone. Drawn as a handset sitting in the middle of the screen —
# rounded body, dynamic island, status bar, home bar — with a home screen of
# apps and a working Messages app on top of GameState's threads.
#
# The world pauses underneath; the home bar or Esc backs out.

const BODY := Vector2(392.0, 812.0)     # a plausible handset aspect
const RADIUS := 54
const INK := Color("f2f2f7")
const DIM := Color("8e8e93")
const BLUE := Color("0a84ff")
const GREY := Color("2c2c2e")
const BG := Color("0b0b0d")

const APPS := [
	["Messages", "messages", Color("30d158")],
	["Clock", "clock", Color("1c1c1e")],
	["Salesforce", "crm", Color("0176d3")],
	["Wallet", "wallet", Color("1c1c1e")],
	["Maps", "maps", Color("34c759")],
	["Weather", "weather", Color("3a86ff")],
	["Camera", "camera", Color("48484a")],
	["Settings", "settings", Color("636366")],
]

var _screen: String = "home"
var _thread: String = ""
var _body: PanelContainer
var _page: VBoxContainer
var _status: Label
var _title: Label
var _back: Button


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.ensure_threads()
	_build()
	_show("home")


func _process(_delta: float) -> void:
	if _status:
		_status.text = "%s        ▪▪▪   ▮" % GameState.time_string()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("phone"):
		get_viewport().set_input_as_handled()
		if _screen == "home":
			_close()
		else:
			_show("home")


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ---------------------------------------------------------------- chrome

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.78)
	add_child(dim)

	_body = PanelContainer.new()
	_body.set_anchors_preset(Control.PRESET_CENTER)
	_body.offset_left = -BODY.x * 0.5
	_body.offset_right = BODY.x * 0.5
	_body.offset_top = -BODY.y * 0.5
	_body.offset_bottom = BODY.y * 0.5
	var shell := StyleBoxFlat.new()
	shell.bg_color = BG
	shell.set_corner_radius_all(RADIUS)
	shell.border_color = Color("3a3a3c")
	shell.set_border_width_all(5)
	shell.set_content_margin_all(0)
	shell.shadow_color = Color(0, 0, 0, 0.6)
	shell.shadow_size = 24
	_body.add_theme_stylebox_override("panel", shell)
	add_child(_body)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	_body.add_child(stack)

	# Status bar with the dynamic island sitting in it.
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_left", 26)
	top.add_theme_constant_override("margin_right", 26)
	top.add_theme_constant_override("margin_top", 14)
	top.add_theme_constant_override("margin_bottom", 2)
	stack.add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", INK)
	row.add_child(_status)

	var island := PanelContainer.new()
	island.set_anchors_preset(Control.PRESET_CENTER_TOP)
	island.offset_left = -58
	island.offset_right = 58
	island.offset_top = 12
	island.offset_bottom = 44
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color.BLACK
	isb.set_corner_radius_all(16)
	island.add_theme_stylebox_override("panel", isb)
	_body.add_child(island)

	# Header: back button and screen title.
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", 18)
	head.add_theme_constant_override("margin_right", 18)
	head.add_theme_constant_override("margin_top", 10)
	stack.add_child(head)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	head.add_child(hrow)
	_back = Button.new()
	_back.text = "‹"
	_back.flat = true
	_back.custom_minimum_size = Vector2(28, 28)
	_back.add_theme_color_override("font_color", BLUE)
	_back.add_theme_font_size_override("font_size", 24)
	_back.pressed.connect(_on_back)
	hrow.add_child(_back)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", INK)
	hrow.add_child(_title)

	# The page itself, scrollable.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 8)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_page)
	stack.add_child(scroll)

	# Home bar.
	var bar := Button.new()
	bar.text = "▁▁▁▁▁▁▁▁"
	bar.flat = true
	bar.custom_minimum_size = Vector2(0, 34)
	bar.add_theme_color_override("font_color", Color("6e6e73"))
	bar.pressed.connect(_on_back)
	stack.add_child(bar)


func _on_back() -> void:
	if _screen == "home":
		_close()
	elif _screen == "thread":
		_show("messages")
	else:
		_show("home")


func _clear() -> void:
	for c in _page.get_children():
		c.queue_free()


func _show(screen: String) -> void:
	_screen = screen
	_clear()
	_back.visible = screen != "home"
	match screen:
		"home": _title.text = ""; _home()
		"messages": _title.text = "Messages"; _messages()
		"thread": _title.text = _thread; _conversation()
		"clock": _title.text = "Clock"; _clock()
		"crm": _title.text = "Salesforce"; _crm()
		"wallet": _title.text = "Wallet"; _wallet()
		"maps": _title.text = "Maps"; _maps()
		"weather": _title.text = "Weather"; _weather()
		"camera": _title.text = "Camera"; _stub("The lens is smudged. It is always smudged.")
		_: _title.text = "Settings"; _stub("Everything is on. Nothing can be changed.")


# ---------------------------------------------------------------- screens

func _home() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	_page.add_child(grid)
	for app in APPS:
		grid.add_child(_icon(String(app[0]), String(app[1]), Color(app[2])))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	_page.add_child(spacer)

	var hint := Label.new()
	hint.text = "%d unread" % GameState.unread_texts() if GameState.unread_texts() > 0 else "No new messages"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", DIM)
	_page.add_child(hint)


func _icon(label: String, screen: String, tint: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 66)
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(17)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = tint.lightened(0.15)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	if screen == "messages":
		var n := GameState.unread_texts()
		b.text = str(n) if n > 0 else ""
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_show.bind(screen))
	box.add_child(b)
	var cap := Label.new()
	cap.text = label
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", INK)
	box.add_child(cap)
	return box


func _messages() -> void:
	var names := GameState.text_contacts()
	if names.is_empty():
		_stub("Nobody has texted you. Give it time.")
		return
	for who in names:
		var thread: Array = GameState.threads.get(who, [])
		if thread.is_empty():
			continue
		var last: Dictionary = thread[thread.size() - 1]
		var unread: int = GameState.unread_in(who)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 62)
		var dot := "●  " if unread > 0 else "     "
		b.text = "%s%s\n     %s" % [dot, who, _clip(String(last.get("body", "")), 38)]
		b.add_theme_color_override("font_color", INK)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GREY
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(_open_thread.bind(who))
		_page.add_child(b)


func _open_thread(who: String) -> void:
	_thread = who
	GameState.mark_read(who)
	_show("thread")


func _conversation() -> void:
	var thread: Array = GameState.threads.get(_thread, [])
	for entry in thread:
		var mine: bool = bool(entry.get("mine", false))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mine:
			var pad := Control.new()
			pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pad)
		var bubble := PanelContainer.new()
		bubble.custom_minimum_size = Vector2(0, 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = BLUE if mine else GREY
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(10)
		bubble.add_theme_stylebox_override("panel", sb)
		var text := Label.new()
		text.text = String(entry.get("body", ""))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(228, 0)
		text.add_theme_color_override("font_color", Color.WHITE if mine else INK)
		bubble.add_child(text)
		row.add_child(bubble)
		if not mine:
			var pad2 := Control.new()
			pad2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pad2)
		_page.add_child(row)

	# Canned replies, so the conversation goes both ways.
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 10)
	_page.add_child(sep)
	for reply in ["Yeah", "On my way", "Can't right now", "lol"]:
		var b := Button.new()
		b.text = reply
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_reply.bind(reply))
		_page.add_child(b)


func _reply(text: String) -> void:
	GameState.push_text(_thread, text, true, true)
	_show("thread")


func _clock() -> void:
	_line("Day %d" % GameState.day, 15, DIM)
	_line(GameState.time_string(), 44, INK)
	_line("Alarm 7:30 — you keep dismissing it.", 13, DIM)


func _crm() -> void:
	GameState.ensure_leads()
	var open_v: int = 0
	var won_v: int = 0
	for r in GameState.sales_leads:
		if r.status == "open" and r.converted:
			open_v += int(r.value)
		elif r.status == "won":
			won_v += int(r.value)
	_line("Pipeline", 13, DIM)
	_line("$%s open" % _money(open_v), 24, INK)
	_line("$%s closed won" % _money(won_v), 18, Color("30d158"))
	_line("", 10, DIM)
	_line("Calls %d    Emails %d" % [GameState.sales_calls, GameState.sales_emails], 15, INK)
	_line("Deals %d of %d" % [GameState.sales_deals, GameState.SALES_QUOTA], 15, INK)
	_line("", 10, DIM)
	_line("Read only. Log activity from your desk.", 12, DIM)


func _wallet() -> void:
	_line("Balance", 13, DIM)
	_line("$%s" % _money(GameState.money), 34, INK)
	_line("", 8, DIM)
	_line("Fuel %d%%" % int(round(GameState.fuel)), 15, INK)
	_line("Camry %d%%" % int(round(GameState.car_health)), 15, INK)
	_line("Sodas %d    Candy %d" % [GameState.sodas, GameState.candy], 15, DIM)


func _maps() -> void:
	for row in [
		"10000 Avalon — Kahua, 6th floor",
		"Chastain Place — home",
		"5955 Haterleigh Dr",
		"Whole Foods — across the avenue",
		"QT — north of the office",
		"Avalon Tennis Centre",
		"Super Strikers",
	]:
		_line(row, 15, INK)
	_line("", 8, DIM)
	_line("Rerouting. Rerouting. Rerouting.", 12, DIM)


func _weather() -> void:
	var night: bool = GameState.is_night()
	_line("Alpharetta", 13, DIM)
	_line("72°" if not night else "58°", 44, INK)
	_line("Clear" if not night else "Clear and dark", 16, DIM)
	_line("", 8, DIM)
	_line("Sunrise 6:00      Sunset 19:30", 13, DIM)


func _stub(text: String) -> void:
	_line(text, 15, DIM)


func _line(text: String, size: int, tint: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	_page.add_child(l)


func _clip(text: String, n: int) -> String:
	return text if text.length() <= n else text.substr(0, n - 1) + "…"


func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
