# Secret S1 — the Director's Office (VESPER_PEAK §3 S1): read the Lobby guestbook (the Director's
# favourite room is number seven) -> use the cracked mirror in East Wing room 7 -> the mezzanine
# bookcase grinds open (NavDoor S1_BookcaseDoor; "ee.s1_open" enables the free tonic crate). The
# mirror always flashes the player's zombie reflection ("ee.mirror_uses").
# Authority: HOST.
extends RequiemObjective


func on_event(event: StringName, data: Dictionary) -> void:
	if event == &"lore" and data.get("id", &"") == &"guestbook":
		set_flag("ee.guestbook_read", true)
	elif event == &"interact" and data.get("id", &"") == &"mirror":
		set_flag("ee.mirror_uses", int(get_flag("ee.mirror_uses", 0)) + 1)
		if bool(get_flag("ee.guestbook_read", false)):
			_open()


func _open() -> void:
	var sw: VesperSecretsWorld = VesperSecretsWorld.of(m())
	if sw != null and sw.bookcase_door != null:
		sw.bookcase_door.host_set_open(true)
	set_flag("ee.s1_open", true)
	vo(&"vo_office")
	log_info("The Director's Office opens")
	complete()


func on_debug_complete() -> void:
	set_flag("ee.guestbook_read", true)
	_open()
