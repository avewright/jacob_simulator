extends CanvasLayer

# Jacob's phone. Drawn as a handset in the middle of the screen — rounded body,
# dynamic island, status bar, home bar — with a home screen of apps and a
# working Messages app over GameState's threads.
#
# The body is a plain Control, deliberately. The first cut used a
# PanelContainer, which sizes every child to fill it: the dynamic island got
# stretched to the full 392x812 and painted the whole phone black.

const BODY := Vector2(392.0, 812.0)
const RADIUS := 54
const INK := Color("f2f2f7")
const DIM := Color("8e8e93")
const BLUE := Color("0a84ff")
const GREY := Color("2c2c2e")
const BG := Color("101014")

const APPS := [
	["Messages", "messages", Color("30d158")],
	["Clock", "clock", Color("1c1c1e")],
	["Salesforce", "crm", Color("0176d3")],
	["Wallet", "wallet", Color("2c2c2e")],
	["Maps", "maps", Color("34c759")],
	["Hinge", "hinge", Color("c1121f")],
	["Weather", "weather", Color("3a86ff")],
	["Camera", "camera", Color("48484a")],
	["Settings", "settings", Color("636366")],
]

var _screen: String = "home"
var _thread: String = ""
var _root: Control
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
		_status.text = "  %s" % GameState.time_string()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("phone"):
		get_viewport().set_input_as_handled()
		_on_back()


func _close() -> void:
	GameState.is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ---------------------------------------------------------------- chrome

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.8)
	add_child(dim)

	# Plain Control: children are placed by their own anchors, so nothing gets
	# stretched over anything else.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.offset_left = -BODY.x * 0.5
	_root.offset_right = BODY.x * 0.5
	_root.offset_top = -BODY.y * 0.5
	_root.offset_bottom = BODY.y * 0.5
	add_child(_root)

	var shell := Panel.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(RADIUS)
	sb.border_color = Color("3a3a3c")
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	shell.add_theme_stylebox_override("panel", sb)
	_root.add_child(shell)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status.offset_left = 24
	_status.offset_top = 16
	_status.offset_right = 160
	_status.offset_bottom = 36
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", INK)
	_root.add_child(_status)

	var bars := Label.new()
	bars.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bars.offset_left = -108
	bars.offset_top = 16
	bars.offset_right = -22
	bars.offset_bottom = 36
	bars.text = "▪▪▪  ⌁  ▮"
	bars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bars.add_theme_font_size_override("font_size", 13)
	bars.add_theme_color_override("font_color", INK)
	_root.add_child(bars)

	var island := Panel.new()
	island.set_anchors_preset(Control.PRESET_CENTER_TOP)
	island.offset_left = -58
	island.offset_right = 58
	island.offset_top = 12
	island.offset_bottom = 44
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color.BLACK
	isb.set_corner_radius_all(16)
	island.add_theme_stylebox_override("panel", isb)
	_root.add_child(island)

	_back = Button.new()
	_back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back.offset_left = 14
	_back.offset_top = 50
	_back.offset_right = 46
	_back.offset_bottom = 84
	_back.text = "‹"
	_back.flat = true
	_back.add_theme_color_override("font_color", BLUE)
	_back.add_theme_color_override("font_hover_color", INK)
	_back.add_theme_font_size_override("font_size", 26)
	_back.pressed.connect(_on_back)
	_root.add_child(_back)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 48
	_title.offset_top = 54
	_title.offset_right = -20
	_title.offset_bottom = 84
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", INK)
	_root.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_right = -18
	scroll.offset_top = 92
	scroll.offset_bottom = -46
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 8)
	scroll.add_child(_page)

	var bar := Button.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 110
	bar.offset_right = -110
	bar.offset_top = -34
	bar.offset_bottom = -12
	bar.flat = true
	bar.text = "▂▂▂▂▂▂"
	bar.add_theme_color_override("font_color", Color("6e6e73"))
	bar.add_theme_color_override("font_hover_color", INK)
	bar.pressed.connect(_on_back)
	_root.add_child(bar)


func _on_back() -> void:
	if _screen == "home":
		_close()
	elif _screen == "thread":
		_show("messages")
	else:
		_show("home")


func _show(screen: String) -> void:
	_screen = screen
	for c in _page.get_children():
		c.queue_free()
	_back.visible = screen != "home"
	match screen:
		"home":
			_title.text = ""
			_home()
		"messages":
			_title.text = "Messages"
			_messages()
		"thread":
			_title.text = _thread
			_conversation()
		"clock":
			_title.text = "Clock"
			_clock()
		"crm":
			_title.text = "Salesforce"
			_crm()
		"wallet":
			_title.text = "Wallet"
			_wallet()
		"maps":
			_title.text = "Maps"
			_maps()
		"hinge":
			_title.text = "Hinge"
			_hinge()
		"weather":
			_title.text = "Weather"
			_weather()
		"camera":
			_title.text = "Camera"
			_stub("The lens is smudged. It is always smudged.")
		_:
			_title.text = "Settings"
			_stub("Everything is on. Nothing can be changed.")


# ---------------------------------------------------------------- screens

func _home() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	_page.add_child(grid)
	for app in APPS:
		grid.add_child(_icon(String(app[0]), String(app[1]), Color(app[2])))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	_page.add_child(gap)

	var n := GameState.unread_texts()
	var hint := Label.new()
	hint.text = "%d unread" % n if n > 0 else "No new messages"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", DIM)
	_page.add_child(hint)


func _icon(label: String, screen: String, tint: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(16)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = tint.lightened(0.18)
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
		b.custom_minimum_size = Vector2(0, 60)
		b.text = "%s%s\n    %s" % ["● " if unread > 0 else "   ", who, _clip(String(last.get("body", "")), 34)]
		b.add_theme_color_override("font_color", INK)
		b.add_theme_font_size_override("font_size", 14)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GREY
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", sb)
		var hb := sb.duplicate() as StyleBoxFlat
		hb.bg_color = GREY.lightened(0.1)
		b.add_theme_stylebox_override("hover", hb)
		b.pressed.connect(_open_thread.bind(who))
		_page.add_child(b)


func _open_thread(who: String) -> void:
	_thread = who
	GameState.mark_read(who)
	_show("thread")


func _conversation() -> void:
	for entry in GameState.threads.get(_thread, []):
		var mine: bool = bool(entry.get("mine", false))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mine:
			var pad := Control.new()
			pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pad)
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = BLUE if mine else GREY
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(10)
		bubble.add_theme_stylebox_override("panel", sb)
		var text := Label.new()
		text.text = String(entry.get("body", ""))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(212, 0)
		text.add_theme_font_size_override("font_size", 14)
		text.add_theme_color_override("font_color", Color.WHITE if mine else INK)
		bubble.add_child(text)
		row.add_child(bubble)
		if not mine:
			var pad2 := Control.new()
			pad2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pad2)
		_page.add_child(row)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_page.add_child(gap)
	for reply in ["Yeah", "On my way", "Can't right now", "lol"]:
		var b := Button.new()
		b.text = reply
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(_reply.bind(reply))
		_page.add_child(b)


func _reply(text: String) -> void:
	GameState.push_text(_thread, text, true, true)
	_show("thread")


func _clock() -> void:
	_line("Day %d" % GameState.day, 15, DIM)
	_line(GameState.time_string(), 42, INK)
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
	_line(" ", 8, DIM)
	_line("Calls %d    Emails %d" % [GameState.sales_calls, GameState.sales_emails], 15, INK)
	_line("Deals %d of %d" % [GameState.sales_deals, GameState.SALES_QUOTA], 15, INK)
	_line(" ", 8, DIM)
	_line("Read only. Log activity from your desk.", 12, DIM)


func _wallet() -> void:
	_line("Balance", 13, DIM)
	_line("$%s" % _money(GameState.money), 34, INK)
	_line(" ", 8, DIM)
	_line("Fuel %d%%" % int(round(GameState.fuel)), 15, INK)
	_line("Camry %d%%" % int(round(GameState.car_health)), 15, INK)
	_line("Sodas %d    Candy %d" % [GameState.sodas, GameState.candy], 15, DIM)


func _maps() -> void:
	var here := GameState.here()

	var view := Control.new()
	view.custom_minimum_size = Vector2(0, 208)
	view.draw.connect(func() -> void: _draw_map(view))
	_page.add_child(view)

	var place := GameState.nav_place()
	if place.is_empty():
		_line("Pick somewhere. The route follows the roads.", 13, DIM)
	else:
		var pts := Places.route(here, place["at"])
		_line("Routing to %s" % String(place["name"]), 15, INK)
		_line("%s  ·  %d stops" % [Places.distance_text(Places.route_length(pts)), pts.size() - 1], 13, DIM)
		var stop := Button.new()
		stop.text = "Stop navigation"
		stop.add_theme_color_override("font_color", Color("ff453a"))
		stop.pressed.connect(func() -> void:
			GameState.clear_nav()
			_show("maps"))
		_page.add_child(stop)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_page.add_child(gap)

	for p in Places.by_distance(here):
		_page.add_child(_place_row(p))


## One tappable destination. Tapping starts the route and puts the phone away,
## because you want to be looking at the street, not at this.
func _place_row(p: Dictionary) -> Control:
	var id := String(p["id"])
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.flat = true
	b.pressed.connect(func() -> void:
		GameState.set_nav(id)
		GameState.notice.emit("Maps: routing to %s." % String(p["name"]))
		_close())

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)

	var pin := Panel.new()
	pin.custom_minimum_size = Vector2(10, 10)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(p["tint"])
	psb.set_corner_radius_all(5)
	pin.add_theme_stylebox_override("panel", psb)
	row.add_child(pin)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_l := Label.new()
	name_l.text = String(p["name"])
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", BLUE if id == GameState.nav_id else INK)
	text.add_child(name_l)
	var note_l := Label.new()
	note_l.text = String(p["note"])
	note_l.add_theme_font_size_override("font_size", 11)
	note_l.add_theme_color_override("font_color", DIM)
	text.add_child(note_l)

	var far := Label.new()
	far.text = Places.distance_text(float(p["dist"]))
	far.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	far.add_theme_font_size_override("font_size", 12)
	far.add_theme_color_override("font_color", DIM)
	row.add_child(far)
	return b


## Street map: the road grid, every pin, you, and the live route.
func _draw_map(view: Control) -> void:
	var w: float = view.size.x
	if w < 8.0:
		return
	var h: float = view.size.y
	var span := 420.0
	var here := GameState.here()
	var mid := Places.flat(here)
	var place := GameState.nav_place()
	if not place.is_empty():
		mid = (mid + Places.flat(place["at"])) * 0.5
		span = maxf(span, Places.flat(here).distance_to(Places.flat(place["at"])) * 1.5)
	var s: float = minf(w, h) / span
	var to_screen := func(p: Vector2) -> Vector2:
		return Vector2(w * 0.5, h * 0.5) + (p - mid) * s

	view.draw_rect(Rect2(0, 0, w, h), Color("11150f"))
	for x in Places.ROADS_NS:
		var a: Vector2 = to_screen.call(Vector2(float(x), mid.y - span))
		var b: Vector2 = to_screen.call(Vector2(float(x), mid.y + span))
		view.draw_line(a, b, Color("2f3540"), maxf(28.0 * s, 2.0))
	for z in Places.ROADS_EW:
		var a2: Vector2 = to_screen.call(Vector2(mid.x - span, float(z)))
		var b2: Vector2 = to_screen.call(Vector2(mid.x + span, float(z)))
		view.draw_line(a2, b2, Color("2f3540"), maxf(14.0 * s, 2.0))

	if not place.is_empty():
		var pts := Places.route(here, place["at"])
		for i in range(1, pts.size()):
			view.draw_line(to_screen.call(pts[i - 1]), to_screen.call(pts[i]), BLUE, 3.0)

	for p in Places.PLACES:
		var at: Vector2 = to_screen.call(Places.flat(p["at"]))
		var live: bool = String(p["id"]) == GameState.nav_id
		view.draw_circle(at, 6.0 if live else 4.0, Color(p["tint"]))
		if live:
			view.draw_arc(at, 10.0, 0.0, TAU, 20, INK, 2.0)

	view.draw_circle(to_screen.call(Places.flat(here)), 5.0, INK)
	view.draw_arc(to_screen.call(Places.flat(here)), 8.0, 0.0, TAU, 20, BLUE, 2.0)


## One card at a time, the way the app works. Liking someone who likes you
## back drops their opener into Messages, so a match turns into a thread.
func _hinge() -> void:
	var matches: int = GameState.hinge_matches.size()
	var who := Hinge.next_unseen(GameState.hinge_seen)
	if who.is_empty():
		_line("You've seen everyone within 30 miles.", 15, INK)
		_line(" ", 8, DIM)
		_line("%d match%s. Try Messages." % [matches, "" if matches == 1 else "es"], 13, DIM)
		var reset := Button.new()
		reset.text = "Start over"
		reset.pressed.connect(func() -> void:
			GameState.hinge_seen.clear()
			_show("hinge"))
		_page.add_child(reset)
		return

	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = GREY
	csb.set_corner_radius_all(18)
	csb.content_margin_left = 14
	csb.content_margin_right = 14
	csb.content_margin_top = 14
	csb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", csb)
	_page.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var photo := Panel.new()
	photo.custom_minimum_size = Vector2(0, 168)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(who["tint"])
	psb.set_corner_radius_all(12)
	photo.add_theme_stylebox_override("panel", psb)
	col.add_child(photo)

	var mono := Label.new()
	mono.set_anchors_preset(Control.PRESET_FULL_RECT)
	mono.text = Hinge.initials(String(who["name"]))
	mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mono.add_theme_font_size_override("font_size", 76)
	mono.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	photo.add_child(mono)

	var head := Label.new()
	head.text = "%s, %d" % [String(who["name"]), int(who["age"])]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", INK)
	col.add_child(head)

	var job := Label.new()
	job.text = String(who["job"])
	job.add_theme_font_size_override("font_size", 12)
	job.add_theme_color_override("font_color", DIM)
	col.add_child(job)

	var prompt := Label.new()
	prompt.text = String(who["prompt"])
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", DIM)
	col.add_child(prompt)

	var answer := Label.new()
	answer.text = String(who["answer"])
	answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	answer.add_theme_font_size_override("font_size", 15)
	answer.add_theme_color_override("font_color", INK)
	col.add_child(answer)

	var id := String(who["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_page.add_child(row)
	row.add_child(_swipe_btn("✕  Pass", Color("8e8e93"), id, false))
	row.add_child(_swipe_btn("♥  Like", Color("ff375f"), id, true))

	var left: int = Hinge.PROFILES.size() - GameState.hinge_seen.size()
	_line("%d left nearby    ·    %d match%s" % [left, matches, "" if matches == 1 else "es"], 11, DIM)


func _swipe_btn(text: String, tint: Color, id: String, liked: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", tint)
	b.pressed.connect(func() -> void:
		var who := Hinge.profile(id)
		if GameState.hinge_swipe(id, liked):
			GameState.notice.emit("It's a match — %s sent you a message." % String(who["name"]))
		_show("hinge"))
	return b


func _weather() -> void:
	var night: bool = GameState.is_night()
	_line("Alpharetta", 13, DIM)
	_line("58°" if night else "72°", 42, INK)
	_line("Clear and dark" if night else "Clear", 16, DIM)
	_line(" ", 8, DIM)
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
