# WardenTuning — the Warden boss's numbers (GAME_DESIGN §5.4, DEVELOPMENT_PLAN Step 12B scope 5):
# health factor, armor plates, the core weak point, the three attacks with their telegraphs, phase
# thresholds and the coolant response. Data only (content/enemies/warden/warden_tuning.tres).
# Authority: read-only data.
class_name WardenTuning
extends Resource

@export_group("Health")
@export var health_factor: float = 25.0  # x base zombie health of the round, x players in co-op
@export_group("Armor")
@export var plate_count: int = 3
@export var plate_health_fraction: float = 0.05  # each plate = this share of max health (raw damage)
@export var plate_reduction: float = 0.75  # body damage reduction while any plate holds
@export var core_multiplier: float = 2.0  # exposed core: hits from behind
@export var core_arc_deg: float = 70.0  # half-angle behind the Warden that counts as the core
@export_group("Ground slam")
@export var slam_range: float = 3.5  # starts a slam when the target is this close
@export var slam_telegraph: float = 0.9
@export var slam_radius: float = 6.0
@export var slam_damage: float = 80.0  # centre; falls to slam_damage_edge at the radius
@export var slam_damage_edge: float = 30.0
@export var slam_recover: float = 0.9
@export var slam_cooldown: float = 3.5
@export_group("Charge")
@export var charge_min: float = 7.0
@export var charge_max: float = 20.0
@export var charge_telegraph: float = 0.8
@export var charge_speed: float = 9.0
@export var charge_time: float = 1.6
@export var charge_damage: float = 70.0
@export var charge_hit_radius: float = 1.6
@export var charge_recover: float = 1.2  # stunned after a charge: the damage window
@export var charge_cooldown: float = 9.0
@export_group("Summon pulse")
@export var summon_telegraph: float = 1.0
@export var summon_count: int = 4
@export var summon_cooldown: float = 22.0
@export var summon_min_distance: float = 6.0
@export_group("Phases")
@export var phase_thresholds: PackedFloat32Array = [0.66, 0.33]  # health fractions -> phase 2 / 3
@export var phase_speed: PackedFloat32Array = [2.2, 2.6, 3.1]  # m/s per phase
@export var phase_cooldown_scale: PackedFloat32Array = [1.0, 0.75, 0.55]
@export_group("Coolant")
@export var frozen_plate_multiplier: float = 2.0  # plates take this much more while frozen (brittle)
@export var stun_immunity: float = 0.25  # Conduit / puddle stuns last this fraction on the Warden
