# presentation (Step 15: AC-15.3 audio audit, AC-15.4 mix, plus the presentation systems) — solo
# vesper_peak:
#  1. Audio audit: every registered audio event (all sound sets + every weapon) is listed in
#     content/audio/audio_manifest.json as "final" or "accepted" (accepted needs a reason), every
#     manifest entry is used, and no resource / script references a `placeholder_` asset.
#  2. Mix: 32 zombies around the player while the Ray Pistol fires continuously for 15 s — the
#     Master peak meter (post-limiter) never reaches 0 dBFS (log: .test-results/sim/mix_peaks.csv);
#     a rough integrated loudness (RMS of the Master capture) is reported for the tuning log.
#  3. Music: the dynamic layers swell with the swarm (drone + pulse audible) and fall silent after.
#  4. Quips / announcer / captions: the round-1 intro is subtitled; a downed call-out plays with a
#     subtitle; cooldowns gate repeats.
#  5. Solo pause: the tree pauses, the session clock stops (a power-up timer does not run down),
#     resume restores both.
#  6. HUD: scale 1.5 / 0.75 resizes the HUD, colorblind palettes change the semantic colours.
extends "res://tests/net/autotest_base.gd"

const MANIFEST: String = "res://content/audio/audio_manifest.json"

var _capture: AudioEffectCapture = null


func _ready() -> void:
	timeout = 200.0
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
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	await _intro_caption(m)
	m.rounds.paused = true
	m.zombies.host_kill_all()
	await _audit()
	await _mix(m, me)
	await _quips(m, me)
	await _pause(m, me)
	await _hud(m)
	finish(true)


# --- 4a. round-1 announcer -----------------------------------------------------------------------


func _intro_caption(m: Match) -> void:
	var ok: bool = await _until(
		func() -> bool: return m.captions.last_text.begins_with(Announcer.SPEAKER) or m.rounds.current_round > 1, 40.0
	)
	check("announcer_round_one_caption", ok and m.captions.last_text.contains("mountain wakes"), m.captions.last_text)


# --- 1. audit ------------------------------------------------------------------------------------


static func manifest() -> Dictionary:
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else {}


static func match_entry(entries: Dictionary, event: String) -> String:
	if entries.has(event):
		return event
	var best: String = ""
	for k: String in entries:
		if k.ends_with("*") and event.begins_with(k.trim_suffix("*")) and k.length() > best.length():
			best = k
	return best


func _audit() -> void:
	for id: StringName in WeaponCatalog.all_ids():
		WeaponAudio.ensure(WeaponCatalog.get_def(id))
	for c: Variant in [ScoreAudio, PerkAudio, PowerUpAudio, QuestAudio, ProgressionAudio, WonderAudio, RelicBoxAudio]:
		c.call(&"ensure")
	SurvivalAudio.ensure_events()
	ZombieAudio.ensure_events()
	CoopAudio.ensure_events()
	Audio.wait_for_synthesis()
	await _wait(0.5)
	var events: Dictionary = Audio.registered_events()
	var man: Dictionary = manifest()
	var entries: Dictionary = man.get("events", {})
	var missing: PackedStringArray = []
	var bad_status: PackedStringArray = []
	var used: Dictionary = {}
	for e: StringName in events:
		var key: String = match_entry(entries, String(e))
		if key == "":
			missing.append(String(e))
			continue
		used[key] = true
		var st: Dictionary = entries[key]
		var status: String = String(st.get("status", ""))
		if status == "final":
			continue
		if status != "accepted" or String(st.get("reason", "")).length() < 12:
			bad_status.append(String(e))
	var unused: PackedStringArray = []
	for k: String in entries:
		if not used.has(k) and not bool((entries[k] as Dictionary).get("optional", false)):
			unused.append(k)
	var dump: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path("res://").path_join("../.test-results/sim/audio_events.json"), FileAccess.WRITE
	)
	if dump != null:
		dump.store_string(JSON.stringify(events, " ", true))
	check("audio_events_registered", events.size() > 150, events.size())
	check("every_event_in_manifest", missing.is_empty(), ", ".join(missing))
	check("every_event_final_or_accepted", bad_status.is_empty(), ", ".join(bad_status))
	check("no_stale_manifest_entries", unused.is_empty(), ", ".join(unused))
	var refs: PackedStringArray = _placeholder_refs("res://", [])
	check("no_placeholder_asset_refs", refs.is_empty(), ", ".join(refs))
	var finals: int = 0
	for e: StringName in events:
		var k: String = match_entry(entries, String(e))
		if k != "" and String((entries[k] as Dictionary).get("status", "")) == "final":
			finals += 1
	Log.info(&"sim", "audio audit: %d events, %d final, %d accepted" % [events.size(), finals, events.size() - finals])
	# Score streams are the rendered files (not runtime synthesis).
	check("score_rendered", Audio.event_stream(&"round_start") is AudioStreamWAV and Audio.is_final(&"round_start"))
	check(
		"perk_jingle_30_45s",
		PerkAudio.arrangement_seconds(Audio.event_stream(&"perk_jingle_quickdraw") as AudioStreamPlaylist) >= 30.0
	)


# `placeholder_` file references in scenes / resources / scripts (UI placeholder_text excluded).
func _placeholder_refs(dir: String, out: PackedStringArray) -> PackedStringArray:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if not (f.ends_with(".tres") or f.ends_with(".tscn") or f.ends_with(".gd")):
			continue
		var path: String = dir.path_join(f)
		if path.begins_with("res://addons/") or path.begins_with("res://tests/"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var re: RegEx = RegEx.create_from_string("placeholder_(?!text)[a-z0-9_]*\\.(wav|ogg|mp3|tres|png|glb)")
		if re.search(text) != null:
			out.append(path)
	for sub: String in d.get_directories():
		if not sub.begins_with("."):
			_placeholder_refs(dir.path_join(sub), out)
	return out


# --- 2. mix + 3. music ----------------------------------------------------------------------------


func _mix(m: Match, me: PlayerCharacter) -> void:
	me.motor.teleport(Vector3(0, 0.1, -2))
	await _wait(0.3)
	m.weapons.request_give(&"ray_pistol")
	await _until(func() -> bool: return me.weapons.held() != null and me.weapons.held().def.id == &"ray_pistol", 5.0)
	var master: int = AudioServer.get_bus_index(&"Master")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(master, _capture)
	var zs: ZombieSync = m.zombies
	var arch: ZombieArchetype = zs.archetype(&"zombie")
	for i: int in 32:
		var a: float = TAU * i / 32.0
		var p: Vector3 = me.global_position + Vector3(cos(a), 0, sin(a)) * (6.0 + (i % 4) * 1.5)
		zs.host_spawn(arch, 0, p, 0.0, ZombieSpawner.Kind.WINDOW)
	m.rounds.paused = false
	var t_fire: float = 0.0
	me.bot_driver = func(pc: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.fire = fmod(t_fire, 0.6) < 0.4
		var rt: WeaponRuntime = pc.weapons.held()
		f.reload_pressed = rt != null and rt.mag == 0
		return f
	var peaks: PackedStringArray = ["t,master_peak_db,alive,music_intensity"]
	var max_peak: float = -200.0
	var sum_sq: float = 0.0
	var n_frames: int = 0
	var max_intensity: float = 0.0
	var t: float = 0.0
	while t < 15.0:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		t += dt
		t_fire += dt
		# Keep the swarm topped up so the fight stays at 32.
		if zs.alive_count() < 24:
			for i: int in 8:
				var a2: float = randf() * TAU
				zs.host_spawn(
					arch, 0, me.global_position + Vector3(cos(a2), 0, sin(a2)) * 9.0, 0.0, ZombieSpawner.Kind.WINDOW
				)
		var pk: float = Audio.master_peak_db()
		max_peak = maxf(max_peak, pk)
		max_intensity = maxf(max_intensity, m.music.intensity)
		peaks.append("%.3f,%.2f,%d,%.2f" % [t, pk, zs.alive_count(), m.music.intensity])
		var frames: PackedVector2Array = _capture.get_buffer(_capture.get_frames_available())
		for fr: Vector2 in frames:
			sum_sq += (fr.x * fr.x + fr.y * fr.y) * 0.5
			n_frames += 1
	me.bot_driver = Callable()
	var csv: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path("res://").path_join("../.test-results/sim/mix_peaks.csv"), FileAccess.WRITE
	)
	if csv != null:
		csv.store_string("\n".join(peaks) + "\n")
	# The capture sits in the Master effect chain (pre bus volume): add the Master gain.
	var rms_db: float = linear_to_db(sqrt(sum_sq / maxf(n_frames, 1.0))) if n_frames > 0 else -200.0
	rms_db += AudioServer.get_bus_volume_db(master)
	Log.info(
		&"sim",
		(
			"mix: master peak max %.2f dBFS over %d frames; capture %d samples, output RMS %.1f dBFS (~LUFS %.1f)"
			% [max_peak, peaks.size() - 1, n_frames, rms_db, rms_db - 0.7]
		)
	)
	check("mix_meter_live", max_peak > -60.0, max_peak)
	check("mix_no_clipping", max_peak < 0.0, max_peak)
	check("music_swells_with_swarm", max_intensity >= 0.6, max_intensity)
	check(
		"music_layers_audible",
		float(m.music.layer_db.get(&"drone", -60.0)) > -20.0 and float(m.music.layer_db.get(&"pulse", -60.0)) > -30.0,
		m.music.layer_db
	)
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master) - 1)
	m.rounds.paused = true
	m.zombies.host_kill_all()
	await _wait(4.0)
	check("music_falls_back", m.music.intensity < 0.5, m.music.intensity)


# --- 4b. quips ------------------------------------------------------------------------------------


func _quips(m: Match, me: PlayerCharacter) -> void:
	var q: QuipDirector = m.quips
	var before: int = m.captions.shown
	check("quip_downed", q.trigger(me.peer_id, &"downed"))
	await _wait(0.2)
	check("quip_caption", m.captions.shown > before and m.captions.last_text.begins_with(me.character.display_name))
	check("quip_cooldown", not q.trigger(me.peer_id, &"downed"))
	check("quip_unknown_category", not q.trigger(me.peer_id, &"nonsense"))
	check("quip_lines_for_every_survivor", q.data.get("lines", {}).size() == 4)


# --- 5. pause ---------------------------------------------------------------------------------------


func _pause(m: Match, _me: PlayerCharacter) -> void:
	var pm: PauseMenu = m.pause_menu
	check("pause_allowed_solo", Net.can_pause())
	m.powerups.host_apply(&"double_points")
	await _wait(0.2)
	var left0: float = m.powerups.time_left(&"double_points")
	var clock0: float = Net.now()
	pm.open()
	check("pause_tree_paused", get_tree().paused and pm.paused_game)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await get_tree().process_frame
	check("pause_clock_frozen", absf(Net.now() - clock0) < 0.05, Net.now() - clock0)
	check("pause_timer_frozen", absf(m.powerups.time_left(&"double_points") - left0) < 0.1)
	pm.close()
	check("pause_resumed", not get_tree().paused and not PlayerInputSource.ui_blocked)
	await _wait(0.5)
	check("clock_runs_again", Net.now() > clock0 + 0.3)


# --- 6. HUD -----------------------------------------------------------------------------------------


func _hud(m: Match) -> void:
	var hud: MatchHud = m.hud
	Config.set_value(&"gameplay", &"hud_scale", 1.5)
	await _wait(0.1)
	var f15: float = hud.hud_factor
	Config.set_value(&"gameplay", &"hud_scale", 0.75)
	await _wait(0.1)
	var f075: float = hud.hud_factor
	check("hud_scale_applies", is_equal_approx(f15 / f075, 2.0), [f15, f075])
	Config.set_value(&"gameplay", &"hud_scale", 1.0)
	var normal: Color = UiTheme.color(&"loss", "off")
	var deut: Color = UiTheme.color(&"loss", "deuteranopia")
	check("colorblind_palette_differs", not normal.is_equal_approx(deut))
	Config.set_value(&"gameplay", &"colorblind_mode", "tritanopia")
	check("colorblind_setting_used", UiTheme.color(&"gain").is_equal_approx(UiTheme.color(&"gain", "tritanopia")))
	Config.set_value(&"gameplay", &"colorblind_mode", "off")
