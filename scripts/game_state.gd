extends Node

signal money_changed(amount: int)
signal fuel_changed(amount: float)
signal in_car_changed(value: bool)
signal objective_changed(text: String)
signal notice(text: String)
signal paused_changed(value: bool)
signal missions_changed
signal prompt_changed(text: String)
signal clothes_changed(value: bool)
signal car_health_changed(amount: float)

const SAVE_PATH := "user://save.json"
const START_MONEY := 420
const START_FUEL := 78.0
const CLOTHES_COST := 80
const SALES_QUOTA := 3
const LEAD_POOL := [
	["Alicia Vance", "Brightline Logistics", 42000],
	["Tom Okafor", "Redstone Dental Group", 18000],
	["Marguerite Kelly", "Peachtree Supply Co", 27500],
	["Devon Park", "Nimbus Freight", 61000],
	["Sana Rahman", "Atlas Property Mgmt", 33000],
	["Bill Trainer", "Trainer & Sons HVAC", 12500],
]

var money: int = START_MONEY:
	set(value):
		money = value
		money_changed.emit(money)

var fuel: float = START_FUEL:
	set(value):
		fuel = clampf(value, 0.0, 100.0)
		fuel_changed.emit(fuel)

var in_car: bool = false:
	set(value):
		in_car = value
		in_car_changed.emit(in_car)

var speed_mph: float = 0.0
var car_health: float = 100.0:
	set(value):
		car_health = clampf(value, 0.0, 100.0)
		car_health_changed.emit(car_health)
var has_clothes: bool = false:
	set(value):
		if has_clothes == value:
			return
		has_clothes = value
		clothes_changed.emit(has_clothes)
var objective: String = "You're in your underwear. Buy clothes, then go to work.":
	set(value):
		objective = value
		objective_changed.emit(objective)

var sales_leads: Array = []
var sales_calls: int = 0
var sales_emails: int = 0
var sales_deals: int = 0

var missions_done: Dictionary = {}
var is_paused: bool = false
var load_from_save: bool = false
# Set when Super Strikers is launched from the arcade in the Jacob world, so
# the soccer scenes return to main.tscn instead of quitting to their own title.
var soccer_from_world: bool = false
var saved_player: Vector3 = Vector3(16.0, 0.0, 3.2)
var saved_car: Vector3 = Vector3(16.0, 0.0, 0.0)
var saved_car_yaw: float = 0.0
var prompt: String = "":
	set(value):
		if prompt == value:
			return
		prompt = value
		prompt_changed.emit(prompt)

func _ready() -> void:
	_bind_input()
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


func _bind_input() -> void:
	_action("move_forward", [KEY_W, KEY_UP])
	_action("move_back", [KEY_S, KEY_DOWN])
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("sprint", [KEY_SHIFT])
	_action("jump", [KEY_SPACE])
	_action("interact", [KEY_E])
	_action("inspect", [KEY_C])
	_action("toggle_wireframe", [KEY_V])
	_action("pause", [KEY_ESCAPE])
	_action("reset_car", [KEY_R])
	_action("kick", [KEY_J])
	_action("punch", [KEY_K, KEY_F])
	_action("slam", [KEY_L, KEY_SPACE])


func _action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, existing)
	for keycode in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func reset_new_game() -> void:
	load_from_save = false
	money = START_MONEY
	fuel = START_FUEL
	in_car = false
	speed_mph = 0.0
	car_health = 100.0
	sales_leads = []
	sales_calls = 0
	sales_emails = 0
	sales_deals = 0
	missions_done = {}
	saved_player = Vector3(16.0, 0.0, 3.2)
	saved_car = Vector3(16.0, 0.0, 0.0)
	saved_car_yaw = 0.0
	prompt = ""
	has_clothes = false
	objective = "You're in your underwear. Buy clothes, then go to work."
	missions_changed.emit()


func ensure_leads() -> void:
	if not sales_leads.is_empty():
		return
	for row in LEAD_POOL:
		sales_leads.append({
			"contact": row[0],
			"company": row[1],
			"value": row[2],
			"interest": 20,
			"stage": 0,
			"emails": 0,
			"status": "open",
		})


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func mark_mission(id: String) -> void:
	missions_done[id] = true
	missions_changed.emit()
	save_game()


func is_mission_done(id: String) -> bool:
	return missions_done.get(id, false)


func add_money(delta: int) -> void:
	money = money + delta


func spend_money(cost: int) -> bool:
	if money < cost:
		return false
	money = money - cost
	return true


func buy_clothes() -> bool:
	if has_clothes:
		notice.emit("You already have clothes.")
		return false
	if not spend_money(CLOTHES_COST):
		notice.emit("Need $%d for clothes." % CLOTHES_COST)
		return false
	has_clothes = true
	mark_mission("clothes")
	notice.emit("Dressed. HR will let you clock in.")
	return true


func consume_fuel(amount: float) -> void:
	fuel = fuel - amount


func enter_arcade() -> void:
	# Stash where Jacob and the Camry are standing, then hand off to Super Strikers.
	save_game()
	soccer_from_world = true
	is_paused = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/soccer/soccer_title.tscn")


func leave_arcade() -> void:
	# The autoload still holds the stashed transforms, so no disk read is needed.
	soccer_from_world = false
	is_paused = false
	get_tree().paused = false
	load_from_save = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func set_paused(value: bool) -> void:
	is_paused = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(value)


func save_game() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var car := get_tree().get_first_node_in_group("camry") as Node3D
	if player:
		saved_player = player.global_position
	if car:
		saved_car = car.global_position
		saved_car_yaw = car.global_rotation.y
	var data := {
		"money": money,
		"fuel": fuel,
		"missions_done": missions_done,
		"player": [saved_player.x, saved_player.y, saved_player.z],
		"car": [saved_car.x, saved_car.y, saved_car.z],
		"car_yaw": saved_car_yaw,
		"in_car": in_car,
		"objective": objective,
		"has_clothes": has_clothes,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	money = int(data.get("money", START_MONEY))
	fuel = float(data.get("fuel", START_FUEL))
	missions_done = data.get("missions_done", {})
	var p: Array = data.get("player", [16.0, 0.0, 4.0])
	var c: Array = data.get("car", [16.0, 0.0, 0.2])
	saved_player = Vector3(float(p[0]), float(p[1]), float(p[2]))
	saved_car = Vector3(float(c[0]), float(c[1]), float(c[2]))
	saved_car_yaw = float(data.get("car_yaw", PI))
	in_car = bool(data.get("in_car", false))
	objective = String(data.get("objective", objective))
	has_clothes = bool(data.get("has_clothes", true))
	load_from_save = true
	missions_changed.emit()
	return true


func apply_saved_transforms() -> void:
	if not load_from_save:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var car := get_tree().get_first_node_in_group("camry") as Node3D
	if player:
		player.global_position = saved_player
	if car:
		car.global_position = saved_car
		car.global_rotation.y = saved_car_yaw
	load_from_save = false
