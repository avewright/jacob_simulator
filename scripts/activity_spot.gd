extends Node3D

# A place where a minigame will eventually live. Holds the interaction so the
# spot is discoverable now; swap `use()` for the real launch later.

const RANGE := 3.4

var kind: String = ""
var prompt_text: String = ""
var pending: String = ""


func setup(activity_kind: String, prompt_label: String, placeholder: String) -> void:
	kind = activity_kind
	prompt_text = prompt_label
	pending = placeholder


func in_range(who: Node3D) -> bool:
	if who == null:
		return false
	if absf(who.global_position.y - global_position.y) > 2.5:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func prompt() -> String:
	return prompt_text


func use() -> void:
	GameState.notice.emit(pending)
