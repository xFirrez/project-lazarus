# StatModifier — one change to a player stat (DEVELOPMENT_PLAN Step 10 scope 1): SET replaces the
# base value (the last SET wins), MUL multiplies, ADD adds. Applied in that order by PlayerStats.
# Authority: read-only data (PerkDefinition.modifiers), identical on every peer.
class_name StatModifier
extends Resource

enum Op { SET, MUL, ADD }

@export var stat: StringName = &""
@export var op: Op = Op.MUL
@export var value: float = 1.0


static func make(p_stat: StringName, p_op: Op, p_value: float) -> StatModifier:
	var m: StatModifier = StatModifier.new()
	m.stat = p_stat
	m.op = p_op
	m.value = p_value
	return m
