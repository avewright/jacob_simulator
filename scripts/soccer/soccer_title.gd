extends Control

const GOLD := Color("ffb703")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("06100a")
	add_child(bg)

	var bar := ColorRect.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 8
	bar.color = GOLD
	add_child(bar)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -300
	root.offset_right = 300
	root.offset_top = -240
	root.offset_bottom = 260
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var badge := Label.new()
	badge.text = "ARCADE SOCCER  •  3v3  •  BIG HITS"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", GOLD)
	root.add_child(badge)

	var title := Label.new()
	title.text = "SUPER STRIKERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GOLD)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "3D strikers. Punch. Kick. Body slam. Score."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.86, 0.9, 0.8))
	root.add_child(sub)

	root.add_child(_btn("KICK OFF", _play))
	if GameState.soccer_from_world:
		root.add_child(_btn("LEAVE ARCADE", GameState.leave_arcade))
	else:
		root.add_child(_btn("JACOB SIMULATOR", _jacob))
		root.add_child(_btn("QUIT", get_tree().quit))

	var help := Label.new()
	help.text = "WASD move  •  J / LMB kick (hold to charge)  •  K punch  •  Space slam"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.6, 0.65, 0.55))
	root.add_child(help)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", Color.BLACK)
	b.add_theme_color_override("font_hover_color", Color.BLACK)
	b.add_theme_font_size_override("font_size", 18)
	return b


func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/soccer/match.tscn")


func _jacob() -> void:
	GameState.reset_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
