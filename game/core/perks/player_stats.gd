# PlayerStats — the generic stat-modifier stack of one player (DEVELOPMENT_PLAN Step 10 scope 1).
# Sources (a perk id, a power-up, a debug override ...) each contribute a list of StatModifiers;
# `value(stat, base)` folds them over the component's base number (PlayerTuning / WeaponDefinition).
# Every peer holds the same stack for every player (perks replicate), so the owner's prediction
# (reload, fire rate, movement, spread) and the host's validation (fire rate, health, damage,
# revive time, weapon slots) agree.
# Stats (base value in brackets):
#   max_health [tuning]  reload_speed [1] (time divisor: reload, raise/lower, ADS)
#   fire_rate [1]  double_tap [0] (hitscan bullets hit twice)  move_speed [1]
#   sprint_duration [tuning]  sprint_recharge [1] (recharge-rate multiplier)  revive_time [tuning]
#   hip_spread [1]  aim_snap [0] (seconds; 0 = off)  headshot_bonus [1]  weapon_slots [0] (extra)
#   self_revive [0]  equipment_speed [1]  no_sprint [0] (flag: a CarryItem carrier, Step 14)
# Authority: derived data; the host's copy decides, every peer computes the same.
class_name PlayerStats
extends RefCounted

signal changed

const MAX_HEALTH: StringName = &"max_health"
const RELOAD_SPEED: StringName = &"reload_speed"
const FIRE_RATE: StringName = &"fire_rate"
const DOUBLE_TAP: StringName = &"double_tap"
const MOVE_SPEED: StringName = &"move_speed"
const SPRINT_DURATION: StringName = &"sprint_duration"
const SPRINT_RECHARGE: StringName = &"sprint_recharge"
const REVIVE_TIME: StringName = &"revive_time"
const HIP_SPREAD: StringName = &"hip_spread"
const AIM_SNAP: StringName = &"aim_snap"
const HEADSHOT_BONUS: StringName = &"headshot_bonus"
const WEAPON_SLOTS: StringName = &"weapon_slots"
const SELF_REVIVE: StringName = &"self_revive"
const EQUIPMENT_SPEED: StringName = &"equipment_speed"
const NO_SPRINT: StringName = &"no_sprint"

var _sources: Dictionary = {}  # StringName source -> Array[StatModifier]
var _order: Array[StringName] = []  # sources in the order they were added


func set_source(source: StringName, mods: Array) -> void:
	if not _sources.has(source):
		_order.append(source)
	var list: Array[StatModifier] = []
	for m: Variant in mods:
		if m is StatModifier:
			list.append(m as StatModifier)
	_sources[source] = list
	changed.emit()


func clear_source(source: StringName) -> void:
	if not _sources.has(source):
		return
	_sources.erase(source)
	_order.erase(source)
	changed.emit()


func clear() -> void:
	if _sources.is_empty():
		return
	_sources.clear()
	_order.clear()
	changed.emit()


func has_source(source: StringName) -> bool:
	return _sources.has(source)


func sources() -> Array[StringName]:
	return _order.duplicate()


# Folds every modifier of `stat` over `base`: SET (last wins), then MUL, then ADD.
func value(stat: StringName, base: float) -> float:
	var v: float = base
	var mul: float = 1.0
	var add: float = 0.0
	for src: StringName in _order:
		for m: StatModifier in _sources[src]:
			if m.stat != stat:
				continue
			match m.op:
				StatModifier.Op.SET:
					v = m.value
				StatModifier.Op.MUL:
					mul *= m.value
				StatModifier.Op.ADD:
					add += m.value
	return v * mul + add


func flag(stat: StringName) -> bool:
	return value(stat, 0.0) > 0.0
