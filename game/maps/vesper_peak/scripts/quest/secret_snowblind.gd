# Secret "Snowblind" (VESPER_PEAK §7.2): wind the three hidden music boxes (Z01 luggage pile, Z04
# room 12, Z07 observation locker) -> the original song plays map-wide, once per match. The grotto's
# fourth box (any time) plays the S2 conversation instead.
# Authority: HOST.
extends RequiemObjective


func on_event(event: StringName, data: Dictionary) -> void:
	if event != &"interact":
		return
	var id: String = String(data.get("id", ""))
	if id == "mb_grotto":
		var sw: VesperSecretsWorld = VesperSecretsWorld.of(m())
		var at: Vector3 = sw.grotto_box.global_position if sw != null and sw.grotto_box != null else Vector3.INF
		vo(grotto_entry(m()), at)
	elif id.begins_with("mb_"):
		set_flag("ee.mb.%s" % id.trim_prefix("mb_"), true)
		var n: int = 0
		for i: int in 3:
			n += int(bool(get_flag("ee.mb.%d" % (i + 1), false)))
		if n == 3:
			_play()


func _play() -> void:
	set_flag("ee.snowblind_at", now())
	vo(&"vo_snowblind")
	log_info("Snowblind")
	complete()


func on_debug_complete() -> void:
	for i: int in 3:
		set_flag("ee.mb.%d" % (i + 1), true)
	_play()


static func grotto_entry(mn: Match) -> StringName:
	for id: int in mn.players.avatars:
		var p: PlayerCharacter = mn.players.avatars[id]
		if p.character != null and p.character.id == &"brandt":
			return &"vo_grotto_brandt"
	return &"vo_grotto"
