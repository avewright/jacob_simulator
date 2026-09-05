extends Node3D

# Works from the driver's seat or on foot. Filling is what the QT mission was
# always meant to be; the mission marker just points you here.

const RANGE := 5.0
const COST := 40


func in_range(who: Node3D) -> bool:
	if who == null:
		return false
	if absf(who.global_position.y - global_position.y) > 3.0:
		return false
	var flat := Vector2(global_position.x - who.global_position.x, global_position.z - who.global_position.z)
	return flat.length() < RANGE


func prompt() -> String:
	if GameState.fuel >= 99.5:
		return "Tank's full"
	return "E  Fill up — $%d" % COST


func use() -> void:
	if GameState.fuel >= 99.5:
		GameState.notice.emit("Tank's already full.")
		return
	if not GameState.spend_money(COST):
		GameState.notice.emit("Need $%d to fill up." % COST)
		return
	GameState.fuel = 100.0
	GameState.mark_mission("qt")
	GameState.notice.emit("Filled up. That's $%d." % COST)
