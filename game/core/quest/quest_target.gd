# QuestTarget — a shootable quest object (the fountain ice, the S2 waterfall, ravens, calibration
# nodes, ...): an indestructible HitTarget whose hits become `damaged` quest events on the HOST
# {target, id, amount, kind, weapon, peer, position} — the objective decides what counts (explosive
# damage over a threshold, a Forge-upgraded weapon, ...). `accepts_fn` can make it ignore hits
# entirely (no impact credit, e.g. a hidden node). Hurtboxes are added by the builder.
# Authority: HOST (damage is applied on the host only; presentation follows quest flags).
class_name QuestTarget
extends HitTarget

var quest_key: StringName = &""
var accepts_fn: Callable = Callable()  # func() -> bool
var hits: int = 0  # host (tests)


func _ready() -> void:
	max_health = 0.0
	super()


func host_apply(info: DamageInfo) -> float:
	if accepts_fn.is_valid() and not bool(accepts_fn.call()):
		return 0.0
	hits += 1
	var applied: float = super(info)
	var q: QuestSystem = Match.current.quest if Match.current != null else null
	if q != null:
		(
			q
			. host_event(
				&"damaged",
				{
					"target": self,
					"id": quest_key,
					"amount": info.amount,
					"kind": int(info.kind),
					"weapon": info.weapon_id,
					"peer": info.source_peer,
					"position": info.position,
				}
			)
		)
	return applied
