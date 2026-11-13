# Client side of the survival net test (see host_survival.gd): late-join door state, purchase
# race, revive hold, own bleedout / spectate / respawn, game over screen.
extends "res://tests/net/autotest_base.gd"

var _saw_down: bool = false
var _saw_spectate: bool = false
var _saw_respawn: bool = false
var _game_over_rows: Array = []
var _game_over_round: int = 0
var _hold_until: float = -1.0


func _ready() -> void:
	timeout = 150.0
	Net.register_message(&"_t_buy", _on_buy)
	Net.register_message(&"_t_revive", _on_revive)
	_run()


func _m() -> Match:
	return Match.current


func _until(cond: Callable, limit: float) -> bool:
	var t0: float = elapsed()
	while not cond.call():
		if elapsed() - t0 > limit:
			return false
		await get_tree().physics_frame
	return true


func _on_buy(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	var it: Interactable = m.interaction.get_by_id(int(p[0]))
	m.interaction.request(me, it)
	m.interaction.request(me, it)


func _on_revive(_sender: int, _p: Array) -> void:
	_hold_until = elapsed() + 6.0
	var me: PlayerCharacter = _m().players.local_avatar()
	me.bot_driver = func(_pl: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.interact = elapsed() < _hold_until
		return f


func _on_game_over(r: int, rows: Array) -> void:
	_game_over_round = r
	_game_over_rows = rows


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	m.downed.game_over.connect(_on_game_over)
	await get_tree().create_timer(1.5).timeout
	var d01: PurchasableDoor = m.interaction.find_by_name("D01_Buy") as PurchasableDoor
	check("late_join_d01_open", d01.is_open() and m.zones.is_unlocked(&"Z03"))
	check("late_join_points", m.points.points.size() == 2, m.points.points)
	check(
		"late_join_round",
		m.rounds.current_round >= 1 or m.rounds.phase == RoundDirector.Phase.INTRO,
		m.rounds.phase_name()
	)
	var ok: bool = await _until(func() -> bool: return m.downed.state_of(me.peer_id) == DownedSystem.State.DOWNED, 90.0)
	_saw_down = ok and me.health.is_downed
	check("own_down_seen", _saw_down)
	ok = await _until(func() -> bool: return me.spectating, 50.0)
	check("spectating_after_bleedout", ok)
	var start_ids: Array[StringName] = [&"m1911"]
	check("weapons_reset", me.weapons.inventory.ids() == start_ids, me.weapons.inventory.ids())
	ok = await _until(func() -> bool: return not me.spectating, 10.0)
	check("respawned", ok and not me.health.is_downed and m.downed.state_of(me.peer_id) == DownedSystem.State.ALIVE)
	ok = await _until(func() -> bool: return _game_over_round > 0, 20.0)
	check("game_over_received", ok and _game_over_rows.size() == 2, _game_over_rows)
	await get_tree().create_timer(DownedSystem.GAME_OVER_SCREEN_DELAY + 0.5, true, false, true).timeout
	check("game_over_screen", Game.state == Game.State.GAME_OVER, Game.state_name())
	finish(true)
