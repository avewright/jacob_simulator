extends Control

const GOLD := Color("ffb703")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("050508")
	add_child(bg)

	var bar := ColorRect.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 8
	bar.color = GOLD
	add_child(bar)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -280
	root.offset_right = 280
	root.offset_top = -220
	root.offset_bottom = 240
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var badge := Label.new()
	badge.text = "GODOT 4.7  •  FORWARD+  •  METAL  •  JOLT"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", GOLD)
	root.add_child(badge)

	var title := Label.new()
	title.text = "JACOB SIMULATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", GOLD)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Alpharetta — wake up in your underwear, buy clothes, go to work."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	root.add_child(sub)

	root.add_child(_btn("NEW GAME", _new_game))
	var cont := _btn("CONTINUE", _continue)
	cont.disabled = not GameState.has_save()
	root.add_child(cont)
	root.add_child(_btn("QUIT", _quit))

	var help := Label.new()
	help.text = "WASD move  •  Shift sprint  •  E enter Camry  •  Mouse look  •  Esc pause"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
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


func _new_game() -> void:
	GameState.reset_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		_new_game()


func _quit() -> void:
	get_tree().quit()
