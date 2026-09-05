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
				GameState.notice.emit("Soda. That's %d today." % GameState.sodas)
			else:
				GameState.notice.emit("Not enough for a soda.")
		"candy":
			if GameState.spend_money(GameState.CANDY_PRICE):
				GameState.candy += 1
				GameState.notice.emit("Candy. That's %d today." % GameState.candy)
			else:
				GameState.notice.emit("Not enough for candy.")
		_:
			GameState.buy_clothes()
