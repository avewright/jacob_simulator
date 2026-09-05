extends Node3D

# A place where a minigame will eventually live. Holds the interaction so the
# spot is discoverable now; swap `use()` for the real launch later.

const RANGE := 4.5

const GAMES := {
	"foosball": "res://scenes/games/foosball.tscn",
	"tennis": "res://scenes/games/tennis_match.tscn",
}

var kind: String = ""
var prompt_text: String = ""
var pending: String = ""

var _open: Node


func setup(activity_kind: String, prompt_label: String, placeholder: String) -> void:
	kind = activity_kind
	prompt_text = prompt_label
	pending = placeholder


func in_range(who: Node3D) -> bool:
	if who == null or _open != null:
		return false
	if absf(who.global_position.y - global_position.y) > 2.5:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func prompt() -> String:
	return prompt_text


func use() -> void:
	var path: String = String(GAMES.get(kind, ""))
	if path == "" or not ResourceLoader.exists(path):
		GameState.notice.emit(pending)
		return
	var scene := load(path) as PackedScene
	if scene == null:
		GameState.notice.emit(pending)
		return
	# Tennis is a 3D match, foosball a 2D console — take whatever the scene is.
	_open = scene.instantiate()
	get_tree().current_scene.add_child(_open)
	_open.tree_exited.connect(func() -> void: _open = null)
