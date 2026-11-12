# WeaponDefinition — data for one weapon (ARCHITECTURE §6.2, GAME_DESIGN §4). Every number that
# defines how a weapon behaves lives here (and in content/weapons/<id>/<id>.tres), never in code.
# Recoil: `recoil_pattern` is a Curve2D whose point i is the kick of shot i in degrees
# (x = horizontal, +right; y = vertical, +up); shots past the last point reuse it.
# Authority: read-only data, identical on every peer (the host recomputes damage from it).
class_name WeaponDefinition
extends Resource

enum WeaponClass { PISTOL, SMG, AR, SHOTGUN, LMG, PRECISION, EXPLOSIVE, WONDER, MELEE, LETHAL, TACTICAL, PLACEABLE }
enum FireMode { SEMI, AUTO, BURST }
enum Hitzone { HEAD, NECK, TORSO, LIMB }

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var weapon_class: WeaponClass = WeaponClass.PISTOL
@export var cost: int = 0
@export var upgraded: WeaponDefinition = null
# &"hitscan" | &"pellet" | &"melee" | &"projectile"; `behavior_script` overrides it (future maps).
@export var behavior: StringName = &"hitscan"
@export var behavior_script: Script = null

@export_group("Fire")
@export var fire_mode: FireMode = FireMode.SEMI
@export var rpm: float = 400.0
@export var burst_count: int = 3
@export var damage: float = 40.0
@export var pellets: int = 1
@export var pellet_spread_deg: float = 0.0
@export var max_range: float = 120.0

@export_group("Damage model")
@export var head_multiplier: float = 4.0
@export var neck_multiplier: float = 2.0
@export var torso_multiplier: float = 1.0
@export var limb_multiplier: float = 0.75
@export var range_min: float = 15.0  # full damage up to here
@export var range_max: float = 40.0  # min damage from here on
@export var min_damage_fraction: float = 0.6
@export var penetration: int = 1  # targets one bullet can damage
@export var penetration_loss: float = 0.25  # damage lost per target passed through

@export_group("Ammo & reload")
@export var mag_size: int = 8
@export var reserve_max: int = 32
@export var reload_partial_time: float = 1.6
@export var reload_empty_time: float = 2.0
@export var ammo_in_partial: float = 1.1  # time into the reload at which the mag is refilled
@export var ammo_in_empty: float = 1.4
# Shell-by-shell reload (pump shotgun): start, then one shell per `shell_insert_time`, then end.
@export var reload_per_shell: bool = false
@export var reload_start_time: float = 0.4
@export var shell_insert_time: float = 0.5
@export var reload_end_time: float = 0.35

@export_group("Handling")
@export var raise_time: float = 0.35
@export var lower_time: float = 0.25
@export var ads_time: float = 0.2
@export var sprint_out_time: float = 0.2
@export var ads_fov_multiplier: float = 0.85
@export var move_speed_multiplier: float = 1.0

@export_group("Spread (degrees, cone half-angle)")
@export var spread_hip: float = 2.0
@export var spread_ads: float = 0.1
@export var spread_move: float = 1.5  # added at full sprint speed in hip
@export var spread_per_shot: float = 0.5
@export var spread_max: float = 5.0
@export var spread_recovery: float = 8.0  # bloom recovered per second

@export_group("Recoil")
@export var recoil_pattern: Curve2D = null
@export var recoil_random: float = 0.15  # +- horizontal degrees added per shot
@export var recoil_ads_multiplier: float = 0.7
@export var recoil_recovery: float = 0.6  # fraction of accumulated vertical recoil returned
@export var recoil_recovery_speed: float = 6.0  # 1/s
@export var view_kick: float = 0.6  # camera punch (degrees) per shot
@export var vm_kick_back: float = 0.04  # viewmodel spring impulse, metres
@export var vm_kick_rot: float = 4.0  # viewmodel spring impulse, degrees

@export_group("Explosive / lethal")
@export var splash_radius: float = 0.0
@export var splash_damage_centre: float = 0.0
@export var splash_damage_edge: float = 0.0
@export var self_damage_max: float = 60.0  # own explosives (GAME_DESIGN §3.2)
@export var fuse_time: float = 3.5
@export var throw_speed: float = 16.0
@export var carry_start: int = 2
@export var carry_max: int = 4

@export_group("Projectile (ProjectileBehavior, Step 9)")
# &"rocket" (explodes on contact) | &"grenade" (bounces, explodes on a zombie or at the fuse) |
# &"bolt" (sticks to the first zombie or wall, explodes after `fuse_time`).
# Direct-hit damage = `damage` (applied to the target struck); splash uses the group above.
@export var projectile_kind: StringName = &"rocket"
@export var projectile_speed: float = 40.0
@export var projectile_gravity: float = 0.0  # m/s^2 downward
@export var projectile_bounce: float = 0.45  # restitution for &"grenade"
@export var projectile_radius: float = 0.06
@export var projectile_arm_distance: float = 0.0  # rockets fly this far before exploding on contact

@export_group("Equipment (Step 9)")
@export var attract_radius: float = 0.0  # Drummer Decoy: path distance zombies are pulled from
@export var attract_time: float = 0.0  # seconds of attraction before the explosion
@export var trigger_radius: float = 0.0  # tripmine: a zombie this close sets it off
@export var place_limit: int = 0  # tripmines placed per player at once

@export_group("Melee")
@export var melee_time: float = 0.45
@export var melee_reach: float = 1.1
@export var melee_lunge: float = 1.5
@export var melee_cone_deg: float = 35.0

@export_group("Viewmodel & presentation")
@export var viewmodel_scene: PackedScene = null  # null -> greybox built from `viewmodel_style`
@export var world_scene: PackedScene = null  # third-person / world model (null -> greybox box); needs Muzzle
@export var viewmodel_style: StringName = &"pistol"  # pistol|smg|shotgun|rifle|rifle_scoped|lmg|launcher|crossbow
@export var viewmodel_color: Color = Color(0.25, 0.25, 0.27)
@export var viewmodel_offset: Vector3 = Vector3(0.16, -0.16, -0.32)  # hip position in camera space
@export var sight_height: float = 0.05  # sight line above the weapon pivot (greybox)
@export var viewmodel_fov: float = 65.0  # horizontal degrees
@export var scope_sway: float = 0.0  # breathing sway amplitude in ADS (degrees), snipers
@export var tracer_every: int = 1  # every nth shot draws a tracer (0 = never)
@export var shell_size: float = 0.012
@export var muzzle_flash_scale: float = 1.0

@export_group("Audio (placeholder synthesis)")
@export var sound_body_hz: float = 160.0  # body layer pitch: lower = heavier
@export var sound_mech_hz: float = 2400.0
@export var sound_tail_s: float = 0.5
@export var sound_volume_db: float = -2.0


func is_melee() -> bool:
	return weapon_class == WeaponClass.MELEE


# Not a primary-slot weapon (knife / Ice Axe, frags, decoys, tripmines).
func is_equipment() -> bool:
	return weapon_class in [WeaponClass.MELEE, WeaponClass.LETHAL, WeaponClass.TACTICAL, WeaponClass.PLACEABLE]


# Seconds between shots (or between bursts' bullets for BURST).
func fire_interval() -> float:
	return 60.0 / maxf(rpm, 1.0)


func zone_multiplier(zone: int) -> float:
	match zone:
		Hitzone.HEAD:
			return head_multiplier
		Hitzone.NECK:
			return neck_multiplier
		Hitzone.LIMB:
			return limb_multiplier
	return torso_multiplier


# Recoil kick of the n-th consecutive shot (0-based), degrees (x horizontal, y vertical).
func recoil_kick(shot_index: int) -> Vector2:
	if recoil_pattern == null or recoil_pattern.point_count == 0:
		return Vector2(0.0, 1.0)
	return recoil_pattern.get_point_position(mini(shot_index, recoil_pattern.point_count - 1))


func reload_time(empty: bool) -> float:
	return reload_empty_time if empty else reload_partial_time
