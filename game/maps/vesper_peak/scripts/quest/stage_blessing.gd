# The Lazarus Blessing (after the finale; this step never completes): every blessed player (uid
# flag "ee.blessed.<uid8>") gets all seven Vigor Tonics back, ignoring the cap, every time they are
# revived for the rest of the match. Also plays R09 ("Varga's farewell") once the victory VO ends.
# Authority: HOST.
class_name StageBlessing
extends RequiemObjective

var restores: int = 0
var _farewell_at: float = -1.0


static func blessed_key(peer_id: int) -> String:
	var info: Dictionary = Net.peers.get(peer_id, {})
	return "ee.blessed.%s" % String(info.get("uid", str(peer_id))).substr(0, 8)


static func restore(mn: Match, peer_id: int) -> int:
	var n: int = 0
	if mn.perks == null:
		return 0
	for pid: StringName in PerkCatalog.ids():
		n += int(mn.perks.host_grant(peer_id, pid, true))
	return n


func on_activate() -> void:
	if not bool(get_flag("ee.farewell_played", false)):
		_farewell_at = now() + quest.vo.lore.duration_of(&"vo_victory") + 1.0


func on_event(event: StringName, data: Dictionary) -> void:
	if event == &"player_revived":
		var peer: int = int(data.get("peer", 0))
		if bool(get_flag(blessed_key(peer), false)):
			restores += 1
			restore(m(), peer)


func on_tick(_delta: float) -> void:
	if _farewell_at > 0.0 and now() >= _farewell_at:
		_farewell_at = -1.0
		set_flag("ee.farewell_played", true)
		vo(&"R09")


func on_debug_complete() -> void:
	pass  # the blessing lasts the whole match
