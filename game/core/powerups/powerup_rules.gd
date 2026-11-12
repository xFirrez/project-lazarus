# PowerUpRules — power-up drop and effect numbers (GAME_DESIGN §11), data only
# (content/powerups/powerup_rules.tres). The drop logic is PowerUpDropper; effects PowerUpSystem.
# Authority: read-only data.
class_name PowerUpRules
extends Resource

@export var id: StringName = &"default"
@export_group("Drops")
@export var threshold_start: float = 600.0  # points earned since the last drop (GDD §11, tuned Step 10)
@export var threshold_growth: float = 1.06  # per drop this match ...
@export var growth_stop_round: int = 20  # ... for drops up to this round
@export var max_per_round: int = 4
# The shuffled bag (each type once before repeats). free_upgrade is never in it (bosses / EE).
@export var bag: Array[StringName] = [&"max_ammo", &"insta_kill", &"double_points", &"nuke", &"carpenter", &"fire_sale"]
@export var nuke_min_round: int = 4  # no Nuke on rounds 1-3
@export var carpenter_min_missing: int = 5  # planks missing map-wide
@export_group("Presentation")
@export var lifetime: float = 26.0
@export var blink_time: float = 6.0
@export var bob_height: float = 0.3
@export var pickup_radius: float = 1.4
@export_group("Effects")
@export var timed_duration: float = 30.0  # Insta-Kill, Double Points, Fire Sale
@export var nuke_points: int = 400
@export var nuke_stagger: float = 2.0
@export var carpenter_points: int = 200
@export var boss_insta_multiplier: float = 10.0
