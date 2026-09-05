extends Node

# Drives the clock, the sun, the sky and the street lighting.
#
# One game hour per SECONDS_PER_HOUR of real time, so a full 24-hour cycle runs
# in 24 real minutes at the default. NPC routines can hang off GameState.clock
# and the hour_changed signal without knowing anything about this node.

const SECONDS_PER_HOUR := 60.0
const SUNRISE := 6.0
const SUNSET := 19.5
const MAX_ELEVATION := 72.0

var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _last_hour: int = -1
var _lamps_lit: bool = false


func _ready() -> void:
	add_to_group("day_night")
	var root := get_parent()
	_sun = root.get_node_or_null("Sun") as DirectionalLight3D
	_fill = root.get_node_or_null("Fill") as DirectionalLight3D
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment
		if _env and _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_apply()


func _process(delta: float) -> void:
	if GameState.is_paused:
		return
	GameState.advance_clock(delta / SECONDS_PER_HOUR)
	_apply()


func _apply() -> void:
	var h: float = GameState.clock
	# Fraction of the way from sunrise to sunset; outside that we are in night.
	var t := (h - SUNRISE) / (SUNSET - SUNRISE)
	var daylight := clampf(sin(clampf(t, 0.0, 1.0) * PI), 0.0, 1.0)
	var up := t > 0.0 and t < 1.0

	if _sun:
		var elev := deg_to_rad(MAX_ELEVATION) * daylight
		_sun.rotation = Vector3(-maxf(elev, 0.02), deg_to_rad(-50.0 + t * 100.0), 0.0)
		_sun.light_energy = 1.45 * daylight if up else 0.0
		# Warm at the horizon, neutral overhead.
		_sun.light_color = Color("ff9d5c").lerp(Color("fff7ea"), clampf(daylight * 1.6, 0.0, 1.0))
		_sun.visible = up and daylight > 0.01

	if _fill:
		# Stands in for moonlight once the sun is down.
		_fill.light_energy = lerpf(0.34, 0.1, daylight)
		_fill.light_color = Color("9fb6ff").lerp(Color("bfd0ff"), daylight)

	if _sky:
		_sky.sky_top_color = Color("05070f").lerp(Color("2a63b8"), daylight)
		_sky.sky_horizon_color = Color("101726").lerp(Color("c9d8e6"), clampf(daylight * 1.4, 0.0, 1.0))
		_sky.ground_bottom_color = Color("05060a").lerp(Color("1e3314"), daylight)
		_sky.ground_horizon_color = Color("0b0e16").lerp(Color("7f8c6b"), daylight)

	if _env:
		_env.tonemap_exposure = lerpf(1.5, 1.05, daylight)
		_env.fog_light_color = Color("0b1020").lerp(Color("b3c4d8"), daylight)
		_env.ambient_light_energy = lerpf(0.35, 1.0, daylight)

	var want_lit := daylight < 0.14
	if want_lit != _lamps_lit:
		_lamps_lit = want_lit
		for lamp in get_tree().get_nodes_in_group("street_lamp"):
			if lamp.has_method("set_lit"):
				lamp.set_lit(want_lit)

	var hour := int(h)
	if hour != _last_hour:
		_last_hour = hour
		GameState.hour_changed.emit(hour)
