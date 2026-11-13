# Host side of the Relic Box net test (DEVELOPMENT_PLAN Step 9, AC-9.5) on vesper_peak at --netsim:
#  0. before the client joins the box is moved to Box_Z07 (late-join location replication);
#  1. both players stand at the box; the client spins (forced AK-47 result) -> spinner = client;
#     the host's own attempt to take the floating weapon is refused; the carousel sampled on the
#     host is sent to the client, which must see the identical sequence ending on the result;
#  2. the client takes the weapon (loadout replicated);
#  3. the host spins a doll: refund, the box relocates to a different location after 4 s, on both
#     peers; 4. Fire Sale: every location present on both peers.
extends "res://tests/net/autotest_base.gd"

const SAMPLES: Array = [0.2, 0.7, 1.3, 2.0, 2.8, 3.6, 4.2, 4.6]

var _client: int = 0
var _client_done: bool = false


func _ready() -> void:
	timeout = 120.0
	Net.register_message(&"_t_cdone", func(_s: int, _p: Array) -> void: _client_done = true)
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	var host_id: int = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.enabled = false
	m.zombies.host_kill_all()
	var box: RelicBoxSystem = m.box
	check("seven_locations", box.boxes.size() == 7, box.boxes.size())
	check("starts_in_lobby", String(box.boxes[box.current_index()].location_id) == "Box_Z03")
	var z07: int = box.index_of(&"Box_Z07")
	box.host_move_to(z07)
	Log.info(&"autotest", "AUTOTEST READY host")
	var found: bool = await _until(func() -> bool: return m.players.avatars.size() >= 2, 30.0)
	check("client_joined", found)
	if not found:
		finish(false)
		return
	for id: int in m.players.avatars:
		if id != host_id:
			_client = id
	var c: PlayerCharacter = m.players.avatars[_client]
	c.notarget = true
	c.health.invulnerable = true
	await _wait(2.0)
	# 1. Client spins at Box_Z07.
	var bx: RelicBox = box.boxes[z07]
	var spot: Vector3 = bx.global_position + bx.global_transform.basis.z * 1.4 + Vector3.UP * 0.1
	me.motor.teleport(spot + Vector3(1.0, 0, 0))
	m.players.host_teleport(_client, spot)
	m.points.host_set(_client, 3000)
	m.points.host_set(host_id, 3000)
	await _wait(1.5)
	box.forced = &"ak47"
	Net.send_reliable(_client, &"_t_use", [bx.interact_id])
	var spun: bool = await _until(func() -> bool: return box.phase(z07) == RelicBoxSystem.Phase.SPINNING, 8.0)
	check("client_spin_started", spun)
	check("spinner_is_client", spun and int(box.spin_of(z07)[0]) == _client, box.spin_of(z07))
	check("client_paid_950", m.points.get_points(_client) == 3000 - 950, m.points.get_points(_client))
	var samples: Array = []
	for t: float in SAMPLES:
		samples.append(String(box.carousel_item(z07, t)))
	Net.send_reliable(_client, &"_t_carousel", [z07, samples])
	await _until(func() -> bool: return box.phase(z07) == RelicBoxSystem.Phase.OFFER, 8.0)
	check("offer_phase", box.phase(z07) == RelicBoxSystem.Phase.OFFER)
	var stolen: bool = m.interaction.host_handle(host_id, bx.interact_id)
	check("host_cannot_take", not stolen and box.phase(z07) == RelicBoxSystem.Phase.OFFER)
	# 2. Client takes it.
	Net.send_reliable(_client, &"_t_use", [bx.interact_id])
	var taken: bool = await _until(func() -> bool: return box.phase(z07) == RelicBoxSystem.Phase.IDLE, 6.0)
	check("client_took_weapon", taken and m.weapons.host_owns(_client, &"ak47"))
	check("host_did_not_get_it", not m.weapons.host_owns(host_id, &"ak47"))
	# 3. Doll: refund + relocation to a different location.
	box.forced = RelicBoxRoller.DOLL
	var pts: int = m.points.get_points(host_id)
	check("host_spin_doll", m.interaction.host_handle(host_id, bx.interact_id))
	await _wait(box.pool.spin_time + 0.5)
	check("doll_refund", m.points.get_points(host_id) == pts, m.points.get_points(host_id))
	var moved_to: int = box.current_index()
	check("moved_elsewhere", moved_to != z07, moved_to)
	await _wait(box.pool.move_time + 0.5)
	check("arrived", box.is_present(moved_to) and not box.is_present(z07))
	Net.send_reliable(_client, &"_t_loc", [String(box.boxes[moved_to].location_id)])
	await _wait(1.0)
	# 4. Fire Sale.
	box.activate_all_locations(8.0)
	await _wait(1.0)
	var all_present: bool = true
	for b: RelicBox in box.boxes:
		all_present = all_present and box.is_present(b.index)
	check("fire_sale_all_present", all_present)
	check("fire_sale_cost", box.cost() == 10, box.cost())
	Net.send_reliable(_client, &"_t_firesale", [])
	await _until(func() -> bool: return _client_done, 15.0)
	check("client_done", _client_done)
	finish(true)
