# ProgressionCommands — Step 11 debug commands (DEVELOPMENT_PLAN Step 11 scope 7):
#   relays_complete        finish every Resonance Relay now (bridge + Forge follow) (host)
#   relay <id>             start a relay (R1 / R2 / R3) without the hold or power (host)
#   relays                 state / progress / paused of every relay
#   forge <weapon_id> [peer]  give the upgraded version of a weapon (default: the held one) (host)
#   forge_unlock           wake the Lazarus Forge without the relays (host)
#   forge_all [peer]       list every upgrade / give a random upgraded weapon set (host)
#   trap <id> [peer]       activate a trap now (T1 / T2 / T3), free, re-armed first (host)
#   traps                  phase / time left / kills of every trap
#   hazards                drum / icicle / breaker state; `hazard_reset` restores them (host)
# Authority: host-only mutations (clients get "host only").
class_name ProgressionCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register("relays_complete", _cmd_relays_complete, [], "Host: finish every Resonance Relay")
	reg.register("relay", _cmd_relay, [["id", TYPE_STRING]], "Host: start a relay (R1/R2/R3)")
	reg.register("relays", _cmd_relays, [], "Relay states")
	reg.register(
		"forge", _cmd_forge, [["weapon_id", TYPE_STRING, ""], ["peer", TYPE_INT, 0]], "Host: give a weapon's upgrade"
	)
	reg.register("forge_unlock", _cmd_forge_unlock, [], "Host: wake the Lazarus Forge")
	reg.register("upgrades", _cmd_upgrades, [], "Every upgradable weapon and its Forge version")
	reg.register("trap", _cmd_trap, [["id", TYPE_STRING], ["peer", TYPE_INT, 0]], "Host: activate a trap now")
	reg.register("traps", _cmd_traps, [], "Trap phases")
	reg.register("hazards", _cmd_hazards, [], "Hazard state")
	reg.register("hazard_reset", _cmd_hazard_reset, [], "Host: respawn drums / icicles, recharge the breaker")


static func _m() -> Match:
	return Match.current


static func _host() -> bool:
	return _m() != null and (Net.is_host() or not Net.is_active())


static func _peer(arg: int) -> int:
	if arg != 0:
		return arg
	return Net.local_id() if Net.is_active() else 1


static func _cmd_relays_complete(_args: Array) -> String:
	if not _host() or _m().relays == null:
		return "host only (needs a match)"
	_m().relays.host_complete_all()
	return "%d relay(s) complete; relays_done=%s" % [_m().relays.done_count(), _m().relays.all_done()]


static func _cmd_relay(args: Array) -> String:
	if not _host() or _m().relays == null:
		return "host only (needs a match)"
	var i: int = _m().relays.index_of(StringName(String(args[0]).to_upper()))
	if i < 0:
		return "unknown relay %s" % args[0]
	return "relay %s %s" % [args[0], "charging" if _m().relays.host_activate(i) else "not idle"]


static func _cmd_relays(_args: Array) -> String:
	if _m() == null or _m().relays == null:
		return "no match"
	var rs: RelaySystem = _m().relays
	var out: PackedStringArray = []
	for i: int in rs.relays.size():
		var r: ResonanceRelay = rs.relays[i]
		out.append(
			(
				"%s (%s) state %d progress %.1f / %.0f%s"
				% [
					r.relay_id,
					r.zone,
					rs.state(i),
					rs.progress_of(i),
					RelaySystem.DEFEND_TIME,
					" PAUSED" if rs.is_paused(i) else ""
				]
			)
		)
	out.append("all done: %s, forge unlocked: %s" % [rs.all_done(), _m().forge != null and _m().forge.is_unlocked()])
	return "\n".join(out)


static func _cmd_forge(args: Array) -> String:
	if not _host() or _m().forge == null:
		return "host only (needs a match)"
	var peer: int = _peer(int(args[1]))
	var wid: StringName = StringName(args[0])
	if wid == &"" and _m().weapons.loadouts.has(peer):
		wid = StringName((_m().weapons.loadouts[peer] as Dictionary)["current"])
	if not WeaponCatalog.can_upgrade(wid):
		return "%s has no Forge upgrade (see `upgrades`)" % wid
	if not _m().forge.host_grant(peer, wid):
		return "could not give %s_up" % wid
	return "gave %s to %d" % [WeaponCatalog.upgrade_of(wid).display_name, peer]


static func _cmd_forge_unlock(_args: Array) -> String:
	if not _host():
		return "host only (needs a match)"
	_m().session.host_set_flag(ForgeSystem.FLAG_UNLOCKED, true)
	return "Lazarus Forge awake"


static func _cmd_upgrades(_args: Array) -> String:
	var out: PackedStringArray = []
	for wid: StringName in WeaponCatalog.all_ids():
		var up: WeaponDefinition = WeaponCatalog.upgrade_of(wid)
		if up != null:
			out.append("%s -> %s %s" % [wid, up.id, up.display_name])
	return "\n".join(out)


static func _cmd_trap(args: Array) -> String:
	if not _host() or _m().traps == null:
		return "host only (needs a match)"
	var t: Trap = _m().traps.by_id(StringName(args[0]))
	if t == null:
		return "unknown trap %s" % args[0]
	_m().traps.host_reset(t)
	_m().traps.host_activate(t, _peer(int(args[1])))
	return "%s active for %.0f s" % [t.def.display_name, t.def.active_time]


static func _cmd_traps(_args: Array) -> String:
	if _m() == null or _m().traps == null:
		return "no match"
	var ts: TrapSystem = _m().traps
	var out: PackedStringArray = []
	for t: Trap in ts.traps:
		out.append(
			(
				"%s %s phase %d left %.1f by %d kills %d"
				% [
					t.trap_id,
					t.def.display_name,
					ts.phase(t),
					ts.time_left(t),
					ts.activator(t),
					int(ts.kills.get(t.trap_id, 0))
				]
			)
		)
	return "\n".join(out)


static func _cmd_hazards(_args: Array) -> String:
	if _m() == null or _m().hazards == null:
		return "no match"
	var hs: HazardSystem = _m().hazards
	var alive_d: int = hs.drums.filter(func(d: ExplosiveDrum) -> bool: return d.alive).size()
	var alive_i: int = hs.icicles.filter(func(i: IcicleCluster) -> bool: return i.alive).size()
	return (
		"drums %d / %d (blasts %d), icicles %d / %d (kills %d), breaker active %s cooling %s"
		% [
			alive_d,
			hs.drums.size(),
			hs.drum_blasts,
			alive_i,
			hs.icicles.size(),
			hs.icicle_kills,
			hs.breaker_active(),
			hs.breaker_cooling()
		]
	)


static func _cmd_hazard_reset(_args: Array) -> String:
	if not _host() or _m().hazards == null:
		return "host only (needs a match)"
	var hs: HazardSystem = _m().hazards
	for d: ExplosiveDrum in hs.drums:
		_m().targets.host_revive_target(d)
	for i: IcicleCluster in hs.icicles:
		_m().targets.host_revive_target(i)
	_m().session.host_set_flag(HazardSystem.FLAG_H3 + ".until", -1.0)
	_m().session.host_set_flag(HazardSystem.FLAG_H3 + ".ready", -1.0)
	return "hazards reset"
