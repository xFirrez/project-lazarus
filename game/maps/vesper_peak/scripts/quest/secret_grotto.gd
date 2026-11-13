# Secret S2 — the Ice Grotto (VESPER_PEAK §3 S2): once power is on the boiler steam warms the cliff and
# the waterfall cracks; an explosive or Ray Pistol hit then shatters it (NavDoor S2_WaterfallIce).
# Inside: L14 and a fourth music box variant — winding it plays Anneliese's conversation when a
# player is Anneliese Brandt (character "brandt"), otherwise Varga's line. The step completes when
# the waterfall breaks; the music box works any time after.
# Authority: HOST.
extends RequiemObjective


func on_event(event: StringName, data: Dictionary) -> void:
	if event == &"damaged" and data.get("id", &"") == &"waterfall" and Power.is_on():
		var kind: int = int(data.get("kind", 0))
		if kind == DamageInfo.Kind.EXPLOSIVE or String(data.get("weapon", "")).begins_with(RAY_PREFIX):
			_open()


func _open() -> void:
	var sw: VesperSecretsWorld = VesperSecretsWorld.of(m())
	if sw != null and sw.waterfall_door != null:
		sw.waterfall_door.host_set_open(true)
	set_flag("ee.s2_open", true)
	log_info("The waterfall shatters: the Ice Grotto is open")
	complete()


func on_debug_complete() -> void:
	_open()
