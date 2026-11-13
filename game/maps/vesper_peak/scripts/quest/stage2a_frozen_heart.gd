# Stage 2a "Frozen Heart" (Courtyard): the shard is encased in the frozen fountain's top tier. One
# blast of explosive damage >= THRESHOLD breaks the ice (VESPER_PEAK §7: LAW, Ray Pistol direct
# hit, China Lake, frag). Design interpretation (PROGRESS): one "hit" = everything one shot or
# explosion deals within HIT_WINDOW (direct + splash), and the brittle ice takes explosive damage
# x EXPLOSIVE_SCALE — so a frag (1200 centre) or China Lake (900 + 500) qualify, bullets never do.
# The shard falls into the basin; pick it up.
# Authority: HOST.
extends RequiemObjective

const THRESHOLD: float = 2000.0
const EXPLOSIVE_SCALE: float = 2.0
const HIT_WINDOW: float = 0.15

var best_hit: float = 0.0  # host (tests): largest scaled hit seen
var _acc: float = 0.0
var _acc_peer: int = -1
var _acc_until: float = 0.0


static func hit_value(kind: int, weapon: StringName, amount: float) -> float:
	if kind == DamageInfo.Kind.EXPLOSIVE:
		return amount * EXPLOSIVE_SCALE
	if String(weapon).begins_with(RAY_PREFIX):
		return amount  # the plasma bolt's direct hit (its splash arrives as EXPLOSIVE)
	return 0.0


func on_event(event: StringName, data: Dictionary) -> void:
	if event == &"damaged" and data.get("id", &"") == &"fountain_ice" and not bool(get_flag("ee.ice_broken", false)):
		var v: float = hit_value(
			int(data.get("kind", 0)), StringName(data.get("weapon", &"")), float(data.get("amount", 0.0))
		)
		if v <= 0.0:
			return
		var peer: int = int(data.get("peer", 0))
		if now() > _acc_until or peer != _acc_peer:
			_acc = 0.0
			_acc_peer = peer
		_acc_until = now() + HIT_WINDOW
		_acc += v
		best_hit = maxf(best_hit, _acc)
		if _acc >= THRESHOLD:
			_break()
	elif event == &"interact" and data.get("id", &"") == &"shard_a" and int(get_flag("ee.shard.a", 0)) == 1:
		collect_shard("a")
		complete()


func _break() -> void:
	set_flag("ee.ice_broken", true)
	set_flag("ee.shard.a", 1)
	log_info("Fountain ice broken")


func on_debug_complete() -> void:
	_break()
	collect_shard("a")
	complete()
