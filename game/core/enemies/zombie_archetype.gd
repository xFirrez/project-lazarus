# ZombieArchetype — data for one enemy type (ARCHITECTURE §7.1, GAME_DESIGN §5.1): model
# variants, locomotion tiers, attack, health curve, hitzone multipliers, reactions and audio.
# Special enemies (Step 12) add a behavior script; the base zombie needs none.
# Authority: shared data (the host simulates with it; every peer picks visuals from it).
class_name ZombieArchetype
extends Resource

enum Tier { SHAMBLE, WALK, JOG, RUN, SPRINT }

const TIER_NAMES: PackedStringArray = ["shamble", "walk", "jog", "run", "sprint"]

@export var id: StringName = &"zombie"
@export var display_name: String = "Zombie"
@export var variants: Array[PackedScene] = []  # ZombieModel scenes (material variants)
@export_group("Locomotion")
@export var tier_speeds: PackedFloat32Array = [1.1, 1.7, 3.0, 4.3, 5.4]  # m/s per Tier
@export var speed_jitter: float = 0.08  # +-fraction per zombie
@export var crawler_speed: float = 1.0
@export var turn_rate: float = 8.0  # rad/s
@export var capsule_radius: float = 0.3  # = navmesh agent radius (2 cells of 0.15 m)
@export var capsule_height: float = 1.8
@export_group("Attack")
@export var attack_damage: float = 50.0
@export var crawler_attack_damage: float = 25.0
@export var attack_range: float = 1.4
@export var lunge_range: float = 2.0  # sprinters
@export var window_swipe_range: float = 1.6  # swipe through a partly broken window (GAME_DESIGN §12)
@export var attack_windup: float = 0.45
@export var attack_duration: float = 1.0
@export var attack_cooldown: float = 1.1
@export_group("Health")
@export var base_health: float = 150.0  # hp(1)
@export var health_step: float = 100.0  # +per round, rounds 2..9
@export var health_growth: float = 1.1  # per round from 10
@export var health_growth_late: float = 1.05  # per round from 55
# Damage multiplier per WeaponDefinition.Hitzone on top of the weapon's own multipliers.
@export var zone_multipliers: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]
@export_group("Reactions")
@export var stagger_fraction: float = 0.35  # one hit >= this share of max health staggers
@export var stagger_time: float = 0.6
@export var crawler_explosive_fraction: float = 0.2  # explosive hit >= share of max health below hips
@export var head_gib_chance: float = 0.5  # lethal headshots
@export var limb_gib_chance: float = 0.35  # lethal explosive / high-damage hits
@export_group("Barricades")
@export var tear_time: float = 1.0
@export var tear_time_fast: float = 0.8  # run / sprint tiers
@export var climb_time: float = 1.2
@export_group("Audio")
@export var voice_pitch_range: Vector2 = Vector2(0.85, 1.15)
@export var groan_interval: Vector2 = Vector2(3.0, 7.0)


func speed_for(tier: int) -> float:
	return tier_speeds[clampi(tier, 0, tier_speeds.size() - 1)]


func tear_time_for(tier: int) -> float:
	return tear_time_fast if tier >= Tier.RUN else tear_time


func reach_for(tier: int) -> float:
	return lunge_range if tier == Tier.SPRINT else attack_range


# GAME_DESIGN §5.1: 150 at round 1, +100 per round to 950 at round 9, x1.1 from 10, x1.05 from 55.
func health_for_round(round_number: int) -> float:
	var r: int = maxi(round_number, 1)
	var hp: float = base_health + health_step * (mini(r, 9) - 1)
	for i: int in range(10, mini(r, 54) + 1):
		hp *= health_growth
	for i: int in range(55, r + 1):
		hp *= health_growth_late
	return roundf(hp)


static func tier_from_name(tier_name: String) -> int:
	var i: int = TIER_NAMES.find(tier_name.to_lower())
	if i < 0 and tier_name.is_valid_int():
		i = clampi(tier_name.to_int(), 0, TIER_NAMES.size() - 1)
	return i
