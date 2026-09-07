class_name Places
extends RefCounted

# Every destination the phone's Maps app can navigate to.
#
# ---------------------------------------------------------------------------
# TO ADD A NEW PLACE: add one dictionary to PLACES below. That is the whole
# job — it appears in Maps, on the minimap, and in the routing automatically.
#
#   id      unique short key, used when something wants to set the destination
#   name    what Maps shows in the list
#   note    the grey second line, e.g. what it is or who is there
#   at      where to steer you. Put it at the door, on the street side, not at
#           the middle of the building — the arrow points here.
#   radius  how close counts as arrived. Bigger for car parks and campuses.
#   tint    pin colour on the maps
# ---------------------------------------------------------------------------
#
# Road grid, mirrored from world_builder.gd. Routing runs along these, so a
# route reads like driving directions rather than a straight line through
# three buildings.

const ROADS_NS := [0.0, -140.0, 90.0]
const ROADS_EW := [-48.0, 48.0, 160.0]
const DIRECT := 45.0        # closer than this, just go straight there

const PLACES := [
	{
		"id": "office", "name": "10000 Avalon", "note": "Kahua — sales on 6",
		"at": Vector3(30.0, 0.0, 0.0), "radius": 14.0, "tint": Color("0176d3"),
	},
	{
		"id": "chastain", "name": "Chastain Place", "note": "Home — you and Jack",
		"at": Vector3(61.0, 0.0, -66.0), "radius": 16.0, "tint": Color("e07a5f"),
	},
	{
		"id": "bakery", "name": "Lilli's Bakery", "note": "Bake with Lilli",
		"at": Vector3(30.0, 0.0, 59.0), "radius": 14.0, "tint": Color("d988a8"),
	},
	{
		"id": "haterleigh", "name": "5955 Haterleigh Dr", "note": "Front door or garage",
		"at": Vector3(62.0, 0.0, 71.0), "radius": 14.0, "tint": Color("b08968"),
	},
	{
		"id": "wholefoods", "name": "Whole Foods", "note": "Clothes, candy, soda",
		"at": Vector3(-39.0, 0.0, 10.0), "radius": 16.0, "tint": Color("3f7d3f"),
	},
	{
		"id": "qt", "name": "QT", "note": "Fuel",
		"at": Vector3(30.0, 0.0, -26.0), "radius": 16.0, "tint": Color("d90429"),
	},
	{
		"id": "garage", "name": "Avalon Parking Deck", "note": "Drive in off the west face",
		"at": Vector3(30.0, 0.0, 28.0), "radius": 16.0, "tint": Color("8d99ae"),
	},
	{
		"id": "arcade", "name": "Super Strikers", "note": "The soccer cabinet",
		"at": Vector3(-38.0, 0.0, -22.0), "radius": 14.0, "tint": Color("ffb703"),
	},
	{
		"id": "tennis", "name": "Avalon Tennis Centre", "note": "Courts and a match",
		"at": Vector3(124.0, 0.0, -76.0), "radius": 20.0, "tint": Color("6a994e"),
	},
]


static func get_place(id: String) -> Dictionary:
	for p in PLACES:
		if String(p["id"]) == id:
			return p
	return {}


static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Places nearest first, each with a "dist" added, so Maps can list them the
## way you would actually pick one.
static func by_distance(from: Vector3) -> Array:
	var out: Array = []
	for p in PLACES:
		var d: Dictionary = p.duplicate()
		d["dist"] = flat(from).distance_to(flat(p["at"]))
		out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	return out


# ------------------------------------------------------------------ routing

static func _nearest_line(v: float, lines: Array) -> float:
	var best: float = float(lines[0])
	for l in lines:
		if absf(float(l) - v) < absf(best - v):
			best = float(l)
	return best


## Snap a point onto the nearest road centreline. Returns [point, is_ns, line],
## where is_ns says the road runs north-south (fixed x) and line is its x or z.
static func _onto_grid(p: Vector2) -> Array:
	var ns: float = _nearest_line(p.x, ROADS_NS)
	var ew: float = _nearest_line(p.y, ROADS_EW)
	if absf(ns - p.x) <= absf(ew - p.y):
		return [Vector2(ns, p.y), true, ns]
	return [Vector2(p.x, ew), false, ew]


## Waypoints from `from` to `to`, following the road grid. Short hops go
## straight — nobody drives to the end of the street and back for 30 metres.
static func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var a := flat(from)
	var b := flat(to)
	var pts := PackedVector2Array([a])
	if a.distance_to(b) > DIRECT:
		var ga := _onto_grid(a)
		var gb := _onto_grid(b)
		var pa: Vector2 = ga[0]
		var pb: Vector2 = gb[0]
		pts.append(pa)
		if bool(ga[1]) != bool(gb[1]):
			# One north-south, one east-west: they cross once.
			if bool(ga[1]):
				pts.append(Vector2(float(ga[2]), float(gb[2])))
			else:
				pts.append(Vector2(float(gb[2]), float(ga[2])))
		elif float(ga[2]) != float(gb[2]):
			# Parallel roads: cross over on whichever link road is least detour.
			var links: Array = ROADS_EW if bool(ga[1]) else ROADS_NS
			var best: float = float(links[0])
			var best_cost: float = INF
			for l in links:
				var cost: float = 0.0
				if bool(ga[1]):
					cost = absf(float(l) - pa.y) + absf(float(l) - pb.y)
				else:
					cost = absf(float(l) - pa.x) + absf(float(l) - pb.x)
				if cost < best_cost:
					best_cost = cost
					best = float(l)
			if bool(ga[1]):
				pts.append(Vector2(pa.x, best))
				pts.append(Vector2(pb.x, best))
			else:
				pts.append(Vector2(best, pa.y))
				pts.append(Vector2(best, pb.y))
		pts.append(pb)
	pts.append(b)
	# Drop any waypoint that repeats the one before it.
	var clean := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		if pts[i].distance_to(clean[clean.size() - 1]) > 0.5:
			clean.append(pts[i])
	return clean


static func route_length(pts: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## The point to actually steer at: the next waypoint you have not reached.
static func next_waypoint(pts: PackedVector2Array, at: Vector3) -> Vector2:
	var here := flat(at)
	for i in range(1, pts.size()):
		if here.distance_to(pts[i]) > 8.0:
			return pts[i]
	return pts[pts.size() - 1]


static func distance_text(m: float) -> String:
	if m < 950.0:
		return "%d m" % int(round(m / 5.0) * 5.0)
	return "%.1f km" % (m / 1000.0)
