# RoundCurve — the round pacing numbers of GAME_DESIGN §5.1–5.2 as data: zombies per round by
# player count, alive cap, spawn interval, intermission and the locomotion tier mix by round.
# Zombie health comes from the ZombieArchetype (`health_for_round`). Pure functions, unit-tested
# table-driven against the GDD (AC-6.1).
# Authority: read-only data (used by the host's RoundDirector / SpawnDirector).
class_name RoundCurve
extends Resource

@export var id: StringName = &"default"
@export_group("Zombie count")
@export var base_count: int = 24  # base_p = base_count + per_player * (p - 1)
@export var per_player: int = 6
@export var early_factors: PackedFloat32Array = [0.25, 0.33, 0.54, 0.75, 1.0]  # f(1..5)
@export var growth_from_round: int = 10  # f(r >= 6) = r/5 * (1 + growth * max(0, r - growth_from_round))
@export var growth_per_round: float = 0.05
@export var count_cap_base: int = 300  # N <= cap_base + cap_per_player * (p - 1)
@export var count_cap_per_player: int = 75
@export_group("Alive cap & spawning")
@export var alive_caps: PackedInt32Array = [24, 28, 32, 32]  # by player count 1..4
@export var spawn_interval_start: float = 2.0
@export var spawn_interval_decay: float = 0.95  # per round
@export var spawn_interval_min_solo: float = 0.35
@export var spawn_interval_min_coop: float = 0.3
@export_group("Timing")
@export var intro_delay: float = 5.0  # intro sting before round 1 (GAME_DESIGN §2)
@export var intermission: float = 10.0
@export var last_zombies_promoted: int = 2  # the last N zombies are promoted to Run if slower
@export_group("Tier mix")
# Keyframes: `tier_mix_rounds[i]` -> 5 weights (Shamble, Walk, Jog, Run, Sprint) at
# tier_mix[5i .. 5i+4]; linear between keyframes, clamped outside (GAME_DESIGN §5.1 table).
@export var tier_mix_rounds: PackedInt32Array = [1, 2, 3, 4, 6, 7, 8, 9, 12, 13, 20, 30]
@export var tier_mix: PackedFloat32Array = [
	1.0,
	0.0,
	0.0,
	0.0,
	0.0,
	0.8,
	0.2,
	0.0,
	0.0,
	0.0,
	0.6,
	0.4,
	0.0,
	0.0,
	0.0,
	0.35,
	0.4,
	0.25,
	0.0,
	0.0,
	0.15,
	0.4,
	0.45,
	0.0,
	0.0,
	0.0,
	0.3,
	0.5,
	0.2,
	0.0,
	0.0,
	0.1,
	0.55,
	0.35,
	0.0,
	0.0,
	0.0,
	0.55,
	0.45,
	0.0,
	0.0,
	0.0,
	0.4,
	0.6,
	0.0,
	0.0,
	0.0,
	0.3,
	0.6,
	0.1,
	0.0,
	0.0,
	0.1,
	0.4,
	0.5,
	0.0,
	0.0,
	0.0,
	0.25,
	0.75,
]


func count_factor(r: int) -> float:
	r = maxi(r, 1)
	if r <= early_factors.size():
		return early_factors[r - 1]
	return float(r) / 5.0 * (1.0 + growth_per_round * maxi(0, r - growth_from_round))


func zombie_count(r: int, players: int) -> int:
	var p: int = clampi(players, 1, 4)
	var base: int = base_count + per_player * (p - 1)
	var cap: int = count_cap_base + count_cap_per_player * (p - 1)
	return mini(roundi(base * count_factor(r)), cap)


func alive_cap(players: int) -> int:
	return alive_caps[clampi(players, 1, alive_caps.size()) - 1]


func spawn_interval(r: int, players: int) -> float:
	var floor_s: float = spawn_interval_min_solo if players <= 1 else spawn_interval_min_coop
	return maxf(spawn_interval_start * pow(spawn_interval_decay, maxi(r, 1) - 1), floor_s)


# Normalized tier weights for round r (ZombieArchetype.Tier order).
func tier_weights(r: int) -> PackedFloat32Array:
	var n: int = tier_mix_rounds.size()
	var out: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0])
	if n == 0:
		out[0] = 1.0
		return out
	var i: int = 0
	while i < n - 1 and tier_mix_rounds[i + 1] <= r:
		i += 1
	var t: float = 0.0
	if i < n - 1 and r > tier_mix_rounds[i]:
		t = float(r - tier_mix_rounds[i]) / float(tier_mix_rounds[i + 1] - tier_mix_rounds[i])
	var j: int = mini(i + 1, n - 1)
	var total: float = 0.0
	for k: int in 5:
		out[k] = lerpf(tier_mix[i * 5 + k], tier_mix[j * 5 + k], t)
		total += out[k]
	for k: int in 5:
		out[k] = out[k] / total if total > 0.0 else (1.0 if k == 0 else 0.0)
	return out


func pick_tier(r: int, roll: float) -> int:
	var w: PackedFloat32Array = tier_weights(r)
	var acc: float = 0.0
	for k: int in 5:
		acc += w[k]
		if roll < acc:
			return k
	return 4
