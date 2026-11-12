# Match — per-match root: instances the map scene and the per-match systems (ARCHITECTURE §4.1):
# PlayerSync, TargetRegistry, WeaponSync, WeaponFx, WorldSync, ZombieSync + CrowdDirector,
# ZoneManager, PointsLedger, InteractionSystem, DownedSystem, RoundDirector, SpawnDirector, the
# map's MapRules and the match HUD. Reachable via Match.current.
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


func setup(def: MapDefinition) -> Error:
	definition = def
	name = "Match"
	var packed: PackedScene = load(def.scene_path) as PackedScene
	if packed == null:
		Log.error(&"match", "Cannot load map scene %s" % def.scene_path)
		return ERR_CANT_OPEN
	map_root = packed.instantiate()
	add_child(map_root)
	current = self
	if def.rules_script != null:
		rules = def.rules_script.new() as MapRules
	if rules == null:
		rules = MapRules.new()
	rules.match_node = self
	fx = WeaponFx.new()
	add_child(fx)
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
	zones = ZoneManager.new()
	zones.players = players
	add_child(zones)
	zones.setup(def, map_root)
	zones.zone_unlocked.connect(_on_zone_unlocked)
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
	add_child(downed)
	rounds = RoundDirector.new()
	rounds.curve = def.round_curve if def.round_curve != null else RoundCurve.new()
	rounds.zombies = zombies
	rounds.players = players
	rounds.enabled = def.survival
	add_child(rounds)
	if def.survival:
		spawns = SpawnDirector.new()
		spawns.rounds = rounds
		spawns.zombies = zombies
		spawns.zones = zones
		spawns.players = players
		spawns.curve = rounds.curve
		add_child(spawns)
	hud = MatchHud.new()
	hud.match_node = self
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MatchHudLayer"
	layer.layer = 7
	layer.add_to_group(&"hide_for_shots")
	add_child(layer)
	layer.add_child(hud)
	if Net.is_host() or not Net.is_active():
		rules.on_match_start()
	Log.info(&"match", "Match started on '%s'" % def.id)
	return OK


func _on_zone_unlocked(z: StringName) -> void:
	if Net.is_host() or not Net.is_active():
		rules.on_zone_unlocked(z)


func _exit_tree() -> void:
	if current == self:
		current = null
