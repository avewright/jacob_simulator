extends Node3D

const RANGE := 3.0

var kind: String = "soda"


func setup(counter_kind: String) -> void:
	kind = counter_kind


func in_range(who: Node3D) -> bool:
	if who == null:
		return false
	if absf(who.global_position.y - global_position.y) > 2.5:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func prompt() -> String:
	match kind:
		"soda": return "E  Buy a soda — $%d" % GameState.SODA_PRICE
		"candy": return "E  Buy candy — $%d" % GameState.CANDY_PRICE
		_:
			if GameState.has_clothes:
				return ""
			return "E  Buy clothes — $%d" % GameState.CLOTHES_COST


func buy() -> void:
	match kind:
		"soda":
			if GameState.spend_money(GameState.SODA_PRICE):
				GameState.sodas += 1
				_rush("Soda. That's %d today." % GameState.sodas)
			else:
				GameState.notice.emit("Not enough for a soda.")
		"candy":
			if GameState.spend_money(GameState.CANDY_PRICE):
				GameState.candy += 1
				_rush("Candy. That's %d today." % GameState.candy)
			else:
				GameState.notice.emit("Not enough for candy.")
		_:
			GameState.buy_clothes()


## Sugar goes straight to his legs.
func _rush(line: String) -> void:
	GameState.notice.emit(line)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("sugar_rush"):
		player.sugar_rush(5.0, "SUGAR RUSH")
