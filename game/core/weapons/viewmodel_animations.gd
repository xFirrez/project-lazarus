# ViewmodelAnimations — builds the per-weapon AnimationLibrary for the greybox viewmodels:
# idle, draw, holster, fire, reload_partial, reload_empty (or reload_start / reload_shell /
# reload_end for per-shell reloads), sprint (loop) and melee. Clip lengths come from the
# WeaponDefinition so the animation matches the runtime state machine; reload sounds are
# method-track keys calling `Events.ev(kind)` (audio keyed to animation tracks, Step 3 scope 10).
# Every clip keys every animated property (Anim pose, Mag, Action, Knife) because AnimationMixer
# resets tracks missing from the playing clip to cached values, which can be a stale pose.
# Track paths are relative to the AnimationPlayer's parent (Viewmodel "Sway" node):
#   Anim:position / Anim:rotation, Anim/<gun>/Mag:position, Anim/<gun>/Action:position, Knife:*
# Authority: local presentation.
class_name ViewmodelAnimations
extends RefCounted

const KNIFE_REST: Vector3 = Vector3(-0.12, -0.12, -0.2)


class Clip:
	extends RefCounted
	var a: Animation = Animation.new()
	var keyed: Dictionary = {}

	func _init(length: float) -> void:
		a.length = maxf(length, 0.05)

	func track(path: String, keys: Array) -> void:
		var t: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath(path))
		if path.ends_with(":visible"):
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
			a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		else:
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		for k: Variant in keys:
			var pair: Array = k
			a.track_insert_key(t, minf(float(pair[0]), a.length), pair[1])
		keyed[path] = true

	func events(keys: Array) -> void:
		var t: int = a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(t, ^"Events")
		for k: Variant in keys:
			var pair: Array = k
			a.track_insert_key(t, minf(float(pair[0]), a.length), {"method": "ev", "args": [StringName(pair[1])]})

	# Rest keys for every animated property this clip doesn't animate.
	func finish(rest: Dictionary) -> Animation:
		for path: String in rest:
			if not keyed.has(path):
				track(path, [[0.0, rest[path]]])
		return a


static func build(def: WeaponDefinition, gun: Node3D, melee_time: float = 0.45) -> AnimationLibrary:
	var g: String = "Anim/%s" % gun.name
	var mag_rest: Vector3 = (gun.get_node(^"Mag") as Node3D).position
	var act_rest: Vector3 = (gun.get_node(^"Action") as Node3D).position
	var rest: Dictionary = {
		"Anim:position": Vector3.ZERO,
		"Anim:rotation": Vector3.ZERO,
		g + "/Mag:position": mag_rest,
		g + "/Action:position": act_rest,
		"Knife:visible": false,
		"Knife:position": KNIFE_REST,
	}
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation(&"idle", Clip.new(0.05).finish(rest))
	var down_p: Vector3 = Vector3(0, -0.18, 0.05)
	var down_r: Vector3 = Vector3(-0.9, 0.2, 0)
	var draw: Clip = Clip.new(def.raise_time)
	draw.track("Anim:position", [[0.0, down_p], [def.raise_time, Vector3.ZERO]])
	draw.track("Anim:rotation", [[0.0, down_r], [def.raise_time, Vector3.ZERO]])
	draw.events([[0.0, "raise"]])
	lib.add_animation(&"draw", draw.finish(rest))
	var holster: Clip = Clip.new(def.lower_time)
	holster.track("Anim:position", [[0.0, Vector3.ZERO], [def.lower_time, down_p]])
	holster.track("Anim:rotation", [[0.0, Vector3.ZERO], [def.lower_time, down_r]])
	lib.add_animation(&"holster", holster.finish(rest))
	lib.add_animation(&"fire", _fire(def, g, act_rest).finish(rest))
	lib.add_animation(&"sprint", _sprint().finish(rest))
	lib.add_animation(&"melee", _melee(melee_time).finish(rest))
	if def.reload_per_shell:
		var tilt: Vector3 = Vector3(0.2, -0.2, -0.5)
		var start: Clip = Clip.new(def.reload_start_time)
		start.track("Anim:rotation", [[0.0, Vector3.ZERO], [def.reload_start_time, tilt]])
		lib.add_animation(&"reload_start", start.finish(rest))
		var l: float = maxf(def.shell_insert_time, 0.05)
		var shell: Clip = Clip.new(l)
		shell.track("Anim:rotation", [[0.0, tilt], [l, tilt]])
		var hand: Vector3 = mag_rest + Vector3(0, -0.12, 0.06)
		shell.track(g + "/Mag:position", [[0.0, hand], [l * 0.85, mag_rest], [l, hand]])
		shell.events([[l * 0.85, "shell"]])
		lib.add_animation(&"reload_shell", shell.finish(rest))
		var end: Clip = Clip.new(def.reload_end_time)
		end.track("Anim:rotation", [[0.0, tilt], [def.reload_end_time, Vector3.ZERO]])
		end.events([[def.reload_end_time * 0.4, "pump"]])
		lib.add_animation(&"reload_end", end.finish(rest))
	else:
		lib.add_animation(&"reload_partial", _reload(def, g, mag_rest, false).finish(rest))
		lib.add_animation(&"reload_empty", _reload(def, g, mag_rest, true).finish(rest))
	return lib


static func _fire(def: WeaponDefinition, g: String, act_rest: Vector3) -> Clip:
	match def.viewmodel_style:
		&"shotgun":  # pump racks after the shot
			var l: float = def.fire_interval() * 0.85
			var c: Clip = Clip.new(l)
			var back: Vector3 = act_rest + Vector3(0, 0, 0.09)
			c.track(
				g + "/Action:position", [[0.0, act_rest], [l * 0.3, act_rest], [l * 0.55, back], [l * 0.85, act_rest]]
			)
			c.track("Anim:rotation", [[0.0, Vector3.ZERO], [l * 0.45, Vector3(0.12, 0, 0.18)], [l, Vector3.ZERO]])
			c.events([[l * 0.35, "pump"]])
			return c
		&"rifle_scoped":  # bolt cycle
			var l2: float = def.fire_interval() * 0.8
			var c2: Clip = Clip.new(l2)
			var open: Vector3 = act_rest + Vector3(0, 0, 0.08)
			c2.track(
				g + "/Action:position", [[0.0, act_rest], [l2 * 0.3, act_rest], [l2 * 0.5, open], [l2 * 0.75, act_rest]]
			)
			c2.track("Anim:rotation", [[0.0, Vector3.ZERO], [l2 * 0.45, Vector3(0.1, 0.1, -0.35)], [l2, Vector3.ZERO]])
			c2.events([[l2 * 0.3, "bolt"]])
			return c2
	var l3: float = minf(def.fire_interval() * 0.9, 0.1)
	var c3: Clip = Clip.new(l3)
	c3.track(g + "/Action:position", [[0.0, act_rest], [l3 * 0.3, act_rest + Vector3(0, 0, 0.035)], [l3, act_rest]])
	return c3


static func _reload(def: WeaponDefinition, g: String, mag_rest: Vector3, empty: bool) -> Clip:
	var l: float = def.reload_time(empty)
	var ammo_in: float = def.ammo_in_empty if empty else def.ammo_in_partial
	var c: Clip = Clip.new(l)
	var tilt: Vector3 = Vector3(0.25, 0.15, 0.55)
	var low: Vector3 = Vector3(0, -0.03, 0.02)
	c.track("Anim:rotation", [[0.0, Vector3.ZERO], [0.18, tilt], [l - 0.2, tilt], [l, Vector3.ZERO]])
	c.track("Anim:position", [[0.0, Vector3.ZERO], [0.18, low], [l - 0.2, low], [l, Vector3.ZERO]])
	var out_t: float = minf(0.3, ammo_in * 0.35)
	var mag_out: Vector3 = mag_rest + Vector3(0, -0.3, 0.05)
	c.track(
		g + "/Mag:position",
		[[0.0, mag_rest], [out_t, mag_rest], [out_t + 0.12, mag_out], [ammo_in - 0.2, mag_out], [ammo_in, mag_rest]]
	)
	var ev: Array = [[out_t, "mag_out"], [ammo_in, "mag_in"]]
	if empty:
		ev.append([minf(ammo_in + 0.3, l - 0.1), "bolt"])
	c.events(ev)
	return c


static func _sprint() -> Clip:
	var c: Clip = Clip.new(0.6)
	c.a.loop_mode = Animation.LOOP_LINEAR
	c.track("Anim:rotation", [[0.0, Vector3(0, 0, 0.06)], [0.3, Vector3(0.05, 0, -0.06)], [0.6, Vector3(0, 0, 0.06)]])
	var dip: Vector3 = Vector3(0, -0.012, 0)
	c.track("Anim:position", [[0.0, Vector3.ZERO], [0.15, dip], [0.3, Vector3.ZERO], [0.45, dip], [0.6, Vector3.ZERO]])
	return c


static func _melee(melee_time: float) -> Clip:
	var l: float = maxf(melee_time, 0.2)
	var c: Clip = Clip.new(l)
	var away: Vector3 = Vector3(0.05, -0.2, 0.05)
	c.track("Anim:position", [[0.0, Vector3.ZERO], [0.08, away], [l - 0.1, away], [l, Vector3.ZERO]])
	var tilt: Vector3 = Vector3(-0.6, 0, 0.3)
	c.track("Anim:rotation", [[0.0, Vector3.ZERO], [0.08, tilt], [l - 0.1, tilt], [l, Vector3.ZERO]])
	c.track("Knife:visible", [[0.0, true], [l, false]])
	c.track(
		"Knife:position",
		[[0.0, KNIFE_REST], [0.1, Vector3(-0.05, -0.08, -0.55)], [0.25, Vector3(-0.1, -0.1, -0.35)], [l, KNIFE_REST]]
	)
	c.events([[0.03, "swing"]])
	return c
