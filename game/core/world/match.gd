# Match — per-match root: instances the map scene and the per-match systems (ARCHITECTURE §4.1):
# MatchSession (late join / reconnect / scene-ready gate / state hash), PlayerSync, TargetRegistry,
# WeaponSync, WeaponFx, WorldSync, ZombieSync + CrowdDirector, ZoneManager, PointsLedger,
# InteractionSystem, RelicBoxSystem, PerkSystem, DownedSystem, RoundDirector, SpawnDirector,
# PowerUpSystem, StatusEffects, RelaySystem, ForgeSystem, TrapSystem, HazardSystem (Step 11),
# WonderFx, BuildableSystem and SpecialRoundDirector (Step 12), QuestSystem (Step 14: quests, carry
# items, lore, VO), the map's MapRules, PingSystem and the match HUD. Reachable via Match.current.
# Authority: exists on every peer; host-only systems check Net.is_host().
class_name Match
extends Node

static var current: Match = null

var definition: MapDefinition = null
var map_root: Node = null
var players: PlayerSync = null
var targets: TargetRegistry = null
var weapons: WeaponSync = null
var fx: WeaponFx = null
var world: WorldSync = null
var zombies: ZombieSync = null
var zones: ZoneManager = null
var points: PointsLedger = null
var interaction: InteractionSystem = null
var downed: DownedSystem = null
var rounds: RoundDirector = null
var spawns: SpawnDirector = null
var rules: MapRules = null
var hud: MatchHud = null
var pause_menu: PauseMenu = null
var captions: Captions = null
var music: MusicDirector = null
var quips: QuipDirector = null
var session: MatchSession = null
var pings: PingSystem = null
var box: RelicBoxSystem = null
var perks: PerkSystem = null
var powerups: PowerUpSystem = null
var status: StatusEffects = null
var relays: RelaySystem = null
var forge: ForgeSystem = null
var traps: TrapSystem = null
var hazards: HazardSystem = null
var wonder_fx: WonderFx = null
var buildables: BuildableSystem = null
var specials: SpecialRoundDirector = null
var quest: QuestSystem = null
var started_at: float = 0.0  # Net.now() at setup (game-over "time played")
var session_joined_at: float = -1.0  # client: Net.now() at the session welcome (join timing)


func setup(def: MapDefinition, from_lobby: bool = false, first_round: int = 1) -> Error:
	definition = def
	started_at = Net.now()
	name = "Match"
	var packed: PackedScene = load(def.scene_path) as PackedScene
	if packed == null:
		Log.error(&"match", "Cannot load map scene %s" % def.scene_path)
		return ERR_CANT_OPEN
	map_root = packed.instantiate()
	add_child(map_root)
	current = self
	# First, so its peer_left capture runs before the other systems drop the player's state.
	session = MatchSession.new()
	session.match_node = self
	session.joined_at = session_joined_at
	add_child(session)
	# Quest engine before the map hooks: map nodes build quest interactables / carry items / lore on
	# `_on_match_setup` (before the target and interaction scans, so ids match on every peer).
	quest = QuestSystem.new()
	quest.match_node = self
	quest.setup(def)
	add_child(quest)
	# Map nodes that listen to shared state (power, machines) hook up now that the session exists.
	map_root.propagate_call(&"_on_match_setup", [self])
	if def.rules_script != null:
		rules = def.rules_script.new() as MapRules
	if rules == null:
		rules = MapRules.new()
	rules.match_node = self
	fx = WeaponFx.new()
	add_child(fx)
	wonder_fx = WonderFx.new()
	add_child(wonder_fx)
	# Hazard drums / icicles are HitTargets (tree-order ids): build them before the target scan.
	hazards = HazardSystem.new()
	hazards.match_node = self
	hazards.setup(map_root)
	targets = TargetRegistry.new()
	add_child(targets)
	targets.scan(map_root)
	world = WorldSync.new()
	add_child(world)
	world.scan(map_root)
	players = PlayerSync.new()
	for node: Node in map_root.find_children("*", "Marker3D", true, false):
		if node.is_in_group(&"player_spawn"):
			players.spawn_points.append((node as Marker3D).global_position)
			players.spawn_yaw = (node as Marker3D).global_rotation.y
	points = PointsLedger.new()
	points.starting_points = def.starting_points
	points.targets = targets
	points.players = players
	add_child(players)
	add_child(points)
	weapons = WeaponSync.new()
	weapons.players = players
	weapons.targets = targets
	weapons.starting_weapons = def.starting_weapons
	add_child(weapons)
	zombies = ZombieSync.new()
	zombies.players = players
	zombies.targets = targets
	add_child(zombies)
	zombies.scan_spawners(map_root)
	weapons.attraction = _on_attractor
	status = StatusEffects.new()
	status.targets = targets
	status.players = players
	add_child(status)
	weapons.status = status
	targets.target_damaged.connect(_on_target_damaged)
	zones = ZoneManager.new()
	zones.players = players
	add_child(zones)
	zones.setup(def, map_root)
	zones.zone_unlocked.connect(_on_zone_unlocked)
	# Relic Box locations are interactables: create them before the interaction scan (tree order).
	box = RelicBoxSystem.new()
	box.match_node = self
	box.setup(def, map_root)
	add_child(box)
	# Vigor Tonic machines stand on the perk markers (interactables too: before the scan).
	perks = PerkSystem.new()
	perks.match_node = self
	perks.setup(map_root)
	add_child(perks)
	# Step 11 progression: relays, the Forge and the trap levers are interactables too.
	relays = RelaySystem.new()
	relays.match_node = self
	relays.setup(map_root)
	forge = ForgeSystem.new()
	forge.match_node = self
	forge.setup(map_root)
	traps = TrapSystem.new()
	traps.match_node = self
	traps.setup(map_root)
	# Step 12: buildable parts and the workbench are interactables too.
	buildables = BuildableSystem.new()
	buildables.match_node = self
	buildables.setup(def.buildables, map_root)
	interaction = InteractionSystem.new()
	interaction.players = players
	interaction.ledger = points
	add_child(interaction)
	interaction.scan(map_root)
	downed = DownedSystem.new()
	downed.players = players
	downed.ledger = points
	downed.weapons = weapons
	downed.interaction = interaction
	downed.perks = perks
	add_child(downed)
	rounds = RoundDirector.new()
	rounds.curve = def.round_curve if def.round_curve != null else RoundCurve.new()
	rounds.zombies = zombies
	rounds.players = players
	rounds.enabled = def.survival
	rounds.hold = from_lobby and Net.is_host()
	rounds.first_round = first_round
	add_child(rounds)
	add_child(relays)
	add_child(forge)
	add_child(traps)
	add_child(hazards)
	add_child(buildables)
	if def.survival:
		spawns = SpawnDirector.new()
		spawns.rounds = rounds
		spawns.zombies = zombies
		spawns.zones = zones
		spawns.players = players
		spawns.curve = rounds.curve
		add_child(spawns)
	powerups = PowerUpSystem.new()
	powerups.match_node = self
	add_child(powerups)
	specials = SpecialRoundDirector.new()
	specials.match_node = self
	add_child(specials)
	pings = PingSystem.new()
	pings.match_node = self
	add_child(pings)
	hud = MatchHud.new()
	hud.match_node = self
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MatchHudLayer"
	layer.layer = 7
	layer.add_to_group(&"hide_for_shots")
	add_child(layer)
	layer.add_child(hud)
	captions = Captions.new()
	layer.add_child(captions)
	music = MusicDirector.new()
	music.match_node = self
	add_child(music)
	quips = QuipDirector.new()
	quips.match_node = self
	add_child(quips)
	var pause_layer: CanvasLayer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	pause_layer.layer = PauseMenu.LAYER
	pause_layer.add_to_group(&"hide_for_shots")
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_menu.match_node = self
	pause_menu.leave_requested.connect(func() -> void: Game.leave_game(""))
	pause_menu.quit_requested.connect(func() -> void: get_tree().quit())
	pause_layer.add_child(pause_menu)
	session.on_match_ready(from_lobby)
	if Net.is_host() or not Net.is_active():
		rules.on_match_start()
		quest.host_start()
	Log.info(&"match", "Match started on '%s'" % def.id)
	return OK


# Host: anything that damages a frozen zombie shatters it (Coolant Purge, StatusEffects).
func _on_target_damaged(t: HitTarget, _amount: float, _zone: int, kind: int, _source_peer: int) -> void:
	if status != null and t is ZombieActor and (Net.is_host() or not Net.is_active()):
		status.host_on_damaged(t as ZombieActor, kind)


# Drummer Decoys (WeaponSync, host) pull zombies through the crowd director.
func _on_attractor(node: Node3D, def: WeaponDefinition) -> void:
	if zombies != null and zombies.crowd != null:
		zombies.crowd.add_attractor(node, def.attract_radius)


func _on_zone_unlocked(z: StringName) -> void:
	if Net.is_host() or not Net.is_active():
		rules.on_zone_unlocked(z)


func _exit_tree() -> void:
	if current == self:
		current = null
