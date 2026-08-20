extends Node3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var resume_car := GameState.load_from_save and GameState.in_car
	if not GameState.load_from_save:
		GameState.in_car = false
	GameState.apply_saved_transforms()
	if resume_car:
		var car := get_tree().get_first_node_in_group("camry")
		if car and car.has_method("try_enter"):
			car.try_enter()
	if GameState.has_clothes:
		GameState.notice.emit("You're next to the Camry. E to drive. Walk into WORK.")
	else:
		GameState.notice.emit("You woke up in your underwear. Buy clothes before work.")
