# StormSystem — the mountain storm's gust events (Step 13, VESPER_PEAK §8.3): a deterministic gust
# schedule on the host clock (so every peer's gusts line up), exposing `gust` (0..1, eased swell)
# for snow density / fog (ZoneAtmosphere), the global shader parameter `wind_strength` (cable /
# tarp / lamp sway: wind_sway.gdshader; declared in project.godot [shader_globals]) and a gust
# swell sound on the Ambience bus.
# Authority: local presentation on every peer (time-derived; no messages).
class_name StormSystem
extends Node

signal gust_started(strength: float)

const PERIOD: float = 9.0  # one gust slot every 9 s on the host clock …
const CHANCE: float = 0.6  # … of which ~60 % carry a gust
const LENGTH: float = 4.5

@export var base_wind: float = 0.35
@export var seed_value: int = 1951

var gust: float = 0.0
var wind: float = 0.35
var gusts: int = 0
var forced_until: float = -1.0

var _last_slot: int = -1


static func slot_strength(slot: int, seed_v: int) -> float:
	# Hash → [0, 1); slots below CHANCE carry a gust of strength 0.5..1.
	var h: int = hash(Vector2i(slot, seed_v))
	var u: float = float(absi(h) % 10000) / 10000.0
	if u >= CHANCE:
		return 0.0
	return 0.5 + 0.5 * (u / CHANCE)


func clock() -> float:
	return Net.host_time() if Net.is_active() else float(Time.get_ticks_msec()) / 1000.0


# Debug: a full gust right now (local only).
func force_gust() -> void:
	forced_until = clock() + LENGTH


func _process(_delta: float) -> void:
	var t: float = clock()
	var slot: int = int(floor(t / PERIOD))
	var phase: float = t - float(slot) * PERIOD
	var s: float = slot_strength(slot, seed_value)
	var g: float = 0.0
	if s > 0.0 and phase < LENGTH:
		g = s * sin(PI * phase / LENGTH)
	if forced_until > t:
		g = maxf(g, sin(PI * clampf(1.0 - (forced_until - t) / LENGTH, 0.0, 1.0)))
	if slot != _last_slot:
		_last_slot = slot
		if s > 0.0:
			gusts += 1
			gust_started.emit(s)
			if Audio.has_event(&"amb_gust"):
				Audio.play_event(&"amb_gust")
	gust = g
	wind = base_wind + gust * 0.9
	RenderingServer.global_shader_parameter_set(&"wind_strength", wind)
