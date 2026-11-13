# BalanceModel — Step 16 balance tooling (DEVELOPMENT_PLAN Step 16 scope 1). A deterministic,
# data-driven model of a run built from the shipped content (RoundCurve, ZombieArchetypes,
# WeaponDefinitions, PointsRules, the Relic Box pool) and a documented "competent player":
#   * weapon tiering — sustained time-to-kill per zombie by round, "viable until" round per weapon
#     (TTK <= VIABLE_TTK s), grouped wall-buy / box / upgraded / wonder
#   * economy pacing — points per round and a purchase plan (VESPER_PEAK §2.4) -> the rounds of
#     the GAME_DESIGN §6.3 milestones, solo and co-op (shared doors)
#   * the round 20/30/40/50/60 curve, special rounds, the Warden, traps, perks
# Used by tests/unit/test_balance.gd (targets as assertions) and tests/balance/balance_report.gd
# (`tools/run_sim.sh balance` -> .test-results/sim/balance.md). Not shipped (tests/ is excluded).
extends RefCounted

const VIABLE_TTK: float = 2.5  # s per zombie, sustained (reload included): a full 24-zombie train in ~1 min
const WALL_BUYS: Array[StringName] = [
	&"m14", &"coachgun", &"mp40", &"model37", &"m16", &"kar98k", &"grease_gun", &"revolver"
]
const WONDER: Array[StringName] = [&"ray_pistol", &"lazarus_conduit"]

# Competent-player assumptions (GAME_DESIGN §6.3 "competent play").
var headshot_ratio: float = 0.35
var melee_rounds: int = 2  # knife most kills in rounds 1..N (classic point building)
var melee_fraction: float = 0.6
var planks_early: int = 8  # repaired planks per round, rounds 1..8
var planks_late: int = 3
var drops_per_round: float = 2.2  # AC-10.3 measurement (solo, rounds 1-10)
var pellet_hit: float = 0.6  # share of shotgun pellets that land at training range
var splash_targets: float = 3.0  # zombies caught per explosive / plasma shot in a train
var chain_targets: int = 6  # zombies in arc range for the Conduit

var curve: RoundCurve = null
var zombie: ZombieArchetype = null
var galvanic: ZombieArchetype = null
var warden: ZombieArchetype = null
var box_pool: RelicBoxPool = null
var _weapons: Dictionary = {}


func _init() -> void:
	curve = load("res://content/rounds/default_round_curve.tres") as RoundCurve
	zombie = load("res://content/enemies/zombie/zombie.tres") as ZombieArchetype
	galvanic = load("res://content/enemies/galvanic/galvanic.tres") as ZombieArchetype
	warden = load("res://content/enemies/warden/warden.tres") as ZombieArchetype
	box_pool = load("res://content/box/relic_box_pool.tres") as RelicBoxPool


func weapon(id: StringName) -> WeaponDefinition:
	if not _weapons.has(id):
		var s: String = String(id)
		var folder: String = s.trim_suffix("_up") if s.ends_with("_up") else s
		_weapons[id] = load("res://content/weapons/%s/%s.tres" % [folder, s]) as WeaponDefinition
	return _weapons[id]


func upgraded(w: WeaponDefinition) -> WeaponDefinition:
	if w.upgraded != null:
		return w.upgraded
	var path: String = "res://content/weapons/%s/%s_up.tres" % [w.id, w.id]
	return weapon(StringName(String(w.id) + "_up")) if ResourceLoader.exists(path) else null


func hp(r: int) -> float:
	return zombie.health_for_round(r)


# --- weapons ------------------------------------------------------------------------------------


func is_area(w: WeaponDefinition) -> bool:
	return w.splash_damage_centre > 0.0 or w.chain_jumps > 0 or w.impact_splash_damage > 0.0


# Expected damage one trigger pull deals to one zombie (headshot mix, pellets that land).
func damage_per_shot(w: WeaponDefinition) -> float:
	if w.behavior == &"melee":
		return w.damage
	var per: float = w.damage * ((1.0 - headshot_ratio) * w.torso_multiplier + headshot_ratio * w.head_multiplier)
	if w.pellets > 1:
		per *= w.pellets * pellet_hit
	return per


# Expected zombies affected per shot and the damage each takes (area weapons).
func area_damage(w: WeaponDefinition) -> Vector2:
	if w.chain_jumps > 0:
		var targets: int = mini(w.chain_jumps + 1, chain_targets)
		var total: float = 0.0
		var d: float = w.damage
		for i: int in targets:
			total += d
			if i >= w.chain_full_jumps:
				d *= w.chain_falloff
		return Vector2(targets, total / targets)
	var splash: float = maxf(w.splash_damage_centre, w.impact_splash_damage)
	var edge: float = w.splash_damage_edge if w.splash_damage_centre > 0.0 else w.impact_splash_damage * 0.5
	return Vector2(splash_targets, w.damage + (splash + edge) * 0.5)


# Seconds per shot, sustained over a full magazine and its reload.
func cycle_per_shot(w: WeaponDefinition) -> float:
	if w.behavior == &"melee":
		return w.melee_time
	var mag: int = maxi(w.mag_size, 1)
	var reload: float = w.reload_empty_time
	if w.reload_per_shell:
		reload = w.reload_start_time + w.shell_insert_time * mag + w.reload_end_time
	return (mag * w.fire_interval() + reload) / mag


func seconds_per_kill(w: WeaponDefinition, r: int) -> float:
	var h: float = hp(r)
	if is_area(w):
		var a: Vector2 = area_damage(w)
		return ceilf(h / maxf(a.y, 1.0)) * cycle_per_shot(w) / a.x
	return ceilf(h / maxf(damage_per_shot(w), 1.0)) * cycle_per_shot(w)


# Last round (1..max_round) at which the weapon kills a zombie within VIABLE_TTK seconds.
func viable_until(w: WeaponDefinition, max_round: int = 80, dps_scale: float = 1.0) -> int:
	var last: int = 0
	for r: int in range(1, max_round + 1):
		if seconds_per_kill(w, r) / dps_scale <= VIABLE_TTK:
			last = r
	return last


func box_weapons() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in box_pool.item_ids:
		if id != &"decoy" and not WONDER.has(id):
			out.append(id)
	return out


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var v: Array = values.duplicate()
	v.sort()
	var n: int = v.size()
	return float(v[n / 2]) if n % 2 == 1 else (float(v[n / 2 - 1]) + float(v[n / 2])) * 0.5


# Weapon tiers: id -> {viable, viable_up, tier}.
func tier_table() -> Dictionary:
	var out: Dictionary = {}
	var ids: Array[StringName] = []
	for id: StringName in WALL_BUYS + box_weapons() + WONDER:
		if not ids.has(id):
			ids.append(id)
	for id: StringName in ids:
		var w: WeaponDefinition = weapon(id)
		var tier: String = "wonder" if WONDER.has(id) else ("wall" if WALL_BUYS.has(id) else "box")
		var up: WeaponDefinition = upgraded(w)
		(
			out
			. merge(
				{
					id:
					{
						"tier": tier,
						"viable": viable_until(w),
						"viable_up": viable_until(up) if up != null else 0,
						"ttk_r10": snappedf(seconds_per_kill(w, 10), 0.01),
						"ttk_r20": snappedf(seconds_per_kill(w, 20), 0.01),
						"ttk_up_r30": snappedf(seconds_per_kill(up, 30), 0.01) if up != null else 0.0,
					}
				}
			)
		)
	return out


func tier_medians() -> Dictionary:
	var t: Dictionary = tier_table()
	var groups: Dictionary = {"wall": [], "box": [], "wall_up": [], "box_up": [], "wonder": [], "wonder_up": []}
	for id: StringName in t:
		var row: Dictionary = t[id]
		(groups[row["tier"]] as Array).append(row["viable"])
		(groups[row["tier"] + "_up"] as Array).append(row["viable_up"])
	var out: Dictionary = {}
	for g: String in groups:
		out[g] = median(groups[g])
	return out


# --- economy ------------------------------------------------------------------------------------


# Points one player earns in round r with weapon w (p players share the round's zombies).
func round_points(r: int, w: WeaponDefinition, players: int = 1) -> float:
	var kills: float = float(curve.zombie_count(r, players)) / players
	var h: float = hp(r)
	var per_kill: float = 0.0
	if r <= melee_rounds:
		var knife: WeaponDefinition = weapon(&"knife")
		var pistol_hits: float = maxf(ceilf((h - knife.damage) / maxf(damage_per_shot(weapon(&"m1911")), 1.0)), 0.0)
		var melee_kill: float = PointsRules.KILL_MELEE + PointsRules.HIT * pistol_hits
		var shot_kill: float = _shot_kill_points(w, h)
		per_kill = melee_fraction * melee_kill + (1.0 - melee_fraction) * shot_kill
	else:
		per_kill = _shot_kill_points(w, h)
	var planks: int = planks_early if r <= 8 else planks_late
	var repairs: float = minf(planks * PointsRules.REPAIR_PLANK, PointsRules.REPAIR_CAP_PER_ROUND)
	# Nuke (400) and Carpenter (200) are 2 of the 6 power-ups; Double Points ignored (conservative).
	var drops: float = drops_per_round * (400.0 + 200.0) / 6.0
	return kills * per_kill + repairs + drops


func _shot_kill_points(w: WeaponDefinition, h: float) -> float:
	if is_area(w):
		return float(PointsRules.KILL_EXPLOSIVE)
	var hits: float = ceilf(h / maxf(damage_per_shot(w), 1.0))
	var kill: float = headshot_ratio * PointsRules.KILL_HEAD + (1.0 - headshot_ratio) * PointsRules.KILL_BODY
	return PointsRules.HIT * maxf(hits - 1.0, 0.0) + kill


# The purchase plan of VESPER_PEAK §2.4 for a competent solo player. Entries:
# [id, cost, kind, arg]; kind: door (shared in co-op), perk, wall (switch weapon), box (switch to
# the median box weapon), power, relay (needs power, one per round), forge (switch to upgraded).
func plan() -> Array:
	return [
		["M14 (wall)", 500, "wall", &"m14"],
		["D01", 750, "door", ""],
		["D02", 1000, "door", ""],
		["D04", 1250, "door", ""],
		["Box spin", 950, "box", &"ak47"],
		["Second Wind", 500, "perk", "first_perk"],
		["D08", 1250, "door", ""],
		["D10", 1000, "door", ""],
		["Power", 0, "power", "power"],
		["Ironhide", 2500, "perk", ""],
		["D06", 1250, "door", ""],
		["R1", 0, "relay", ""],
		["D03", 1000, "door", ""],
		["D05", 1250, "door", ""],
		["R2", 0, "relay", ""],
		["D11", 1500, "door", ""],
		["R3", 0, "relay", "forge_unlocked"],
		["Quickdraw", 3000, "perk", ""],
		["Twin-Fire", 2000, "perk", ""],
		["Ammo x2", 1000, "ammo", ""],
		["Forge", 5000, "forge", "first_upgrade"],
	]


# Simulates `rounds` rounds for one player of a `players` team. Purchases happen at the start of a
# round from the points banked so far (door costs split across the team). Returns
# {milestones: {name: round}, earned_by_r5, timeline: [[round, earned, bank, weapon]]}.
func simulate(players: int = 1, rounds: int = 25, starting_points: int = 500) -> Dictionary:
	var bank: float = starting_points
	var earned: float = starting_points
	var w: WeaponDefinition = weapon(&"m1911")
	var steps: Array = plan()
	var i: int = 0
	var milestones: Dictionary = {}
	var timeline: Array = []
	var earned_by_r5: float = 0.0
	var relay_round: int = -1
	for r: int in range(1, rounds + 1):
		while i < steps.size():
			var s: Array = steps[i]
			var kind: String = s[2]
			var cost: float = float(s[1]) / (players if kind == "door" else 1)
			if kind == "wall" and r < 2:
				break
			if kind == "relay" and relay_round == r:
				break  # one relay sequence per round
			if bank < cost:
				break
			bank -= cost
			match kind:
				"wall", "box":
					w = weapon(StringName(s[3]))
				"forge":
					w = upgraded(w) if upgraded(w) != null else w
				"relay":
					relay_round = r
			if String(s[3]) != "" and kind in ["perk", "power", "relay", "forge"]:
				milestones[String(s[3])] = r
			milestones[String(s[0])] = r
			i += 1
		var gain: float = round_points(r, w, players)
		bank += gain
		earned += gain
		if r == 5:
			earned_by_r5 = earned
		if earned >= 4000.0 and not milestones.has("earned_4000"):
			milestones["earned_4000"] = r
		timeline.append([r, roundi(earned), roundi(bank), String(w.id)])
	return {"milestones": milestones, "earned_by_r5": roundi(earned_by_r5), "timeline": timeline}


# --- curves ---------------------------------------------------------------------------------------


func curve_row(r: int, players: int = 1) -> Dictionary:
	var w: PackedFloat32Array = curve.tier_weights(r)
	return {
		"round": r,
		"hp": hp(r),
		"count": curve.zombie_count(r, players),
		"sprint_pct": roundi(w[4] * 100.0),
		"spawn_interval": snappedf(curve.spawn_interval(r, players), 0.01),
		"round_hp_total": hp(r) * curve.zombie_count(r, players),
	}


func special_rounds(seed_value: int, last: int = 50) -> PackedInt32Array:
	return curve.special_schedule(seed_value, last)


func warden_health(r: int, players: int) -> float:
	var t: WardenTuning = warden.boss_tuning
	return hp(r) * t.health_factor * players if t != null else hp(r) * 25.0 * players
