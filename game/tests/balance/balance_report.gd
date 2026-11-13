# balance_report — `tools/run_sim.sh balance`: runs BalanceModel over the shipped data and writes
# a markdown report (+ JSON) with weapon tiers, the round curve, economy milestones solo / co-op,
# special rounds, the Warden and trap value. Exit code 1 if a GAME_DESIGN §6.3 / Step 16 target is
# missed (the same checks as tests/unit/test_balance.gd).
# Usage: godot --headless --path game -- --autotest=res://tests/balance/balance_report.gd --out=<file.md>
# (an autotest node, so the autoloads the weapon scripts use exist).
extends Node

const Model: GDScript = preload("res://tests/balance/balance_model.gd")
const ASSUMPTIONS: String = (
	"Assumptions: headshots %d %%, knife %d %% of kills in rounds 1–%d, %d planks / round early, "
	+ "%.1f drops / round, viable = sustained TTK ≤ %.1f s per zombie.\n"
)
const TRAP_LINE: String = (
	"- Trap value: 1000 per activation, 50 per kill to the activator → break-even at 20 kills; "
	+ "a full train (alive cap 24) at r15 returns %.0f points + clears the train."
)
const TWIN_LINE: String = (
	"- Twin-Fire (×2 hitscan damage, ×1.33 rpm) extends the M16's viability from r%d to r%d; "
	+ "upgraded M16 from r%d to r%d."
)


func _ready() -> void:
	var out_path: String = CommandLine.get_value(
		"out", ProjectSettings.globalize_path("res://../.test-results/sim/balance.md")
	)
	var m: RefCounted = Model.new()
	var lines: PackedStringArray = []
	var failures: PackedStringArray = []
	lines.append("# Balance report (BalanceModel, Step 16)\n")
	var assumptions: Array = [
		roundi(m.headshot_ratio * 100),
		roundi(m.melee_fraction * 100),
		m.melee_rounds,
		m.planks_early,
		m.drops_per_round,
		m.VIABLE_TTK
	]
	lines.append(ASSUMPTIONS % assumptions)
	# Weapon tiers
	var t: Dictionary = m.tier_table()
	lines.append("## Weapon tiers (viable until round)\n")
	lines.append("| Weapon | Tier | Viable to | Upgraded viable to | TTK r10 s | TTK r20 s | Upgraded TTK r30 s |")
	lines.append("|---|---|---|---|---|---|---|")
	var ids: Array = t.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return int(t[a]["viable"]) > int(t[b]["viable"]))
	for id: StringName in ids:
		var row: Dictionary = t[id]
		lines.append(
			(
				"| %s | %s | %d | %d | %.2f | %.2f | %.2f |"
				% [id, row["tier"], row["viable"], row["viable_up"], row["ttk_r10"], row["ttk_r20"], row["ttk_up_r30"]]
			)
		)
	var med: Dictionary = m.tier_medians()
	lines.append(
		(
			"\nMedians — wall-buys %.0f (upgraded %.0f), box %.0f (upgraded %.0f), wonder %.0f (upgraded %.0f).\n"
			% [med["wall"], med["wall_up"], med["box"], med["box_up"], med["wonder"], med["wonder_up"]]
		)
	)
	_check(
		failures, "wall-buys viable to mid rounds (median >= r8; mid = r8-12)", float(med["wall"]) >= 8.0, med["wall"]
	)
	_check(failures, "box weapons worth the gamble (median > wall median)", float(med["box"]) > float(med["wall"]), med)
	_check(failures, "upgrades meaningful (+5 rounds or more)", float(med["box_up"]) >= float(med["box"]) + 5.0, med)
	_check(failures, "wonder weapons top tier", float(med["wonder"]) > float(med["box"]), med)
	# Round curve
	lines.append("## Zombie curve\n")
	lines.append("| Round | HP | Count solo / 4p | Sprinters | Spawn interval s | Round HP total (solo) |")
	lines.append("|---|---|---|---|---|---|")
	for r: int in [1, 5, 10, 15, 20, 30, 40, 50, 55, 60, 80, 100]:
		var c: Dictionary = m.curve_row(r, 1)
		var c4: Dictionary = m.curve_row(r, 4)
		lines.append(
			(
				"| %d | %d | %d / %d | %d %% | %.2f | %.0f k |"
				% [
					r,
					c["hp"],
					c["count"],
					c4["count"],
					c["sprint_pct"],
					c["spawn_interval"],
					float(c["round_hp_total"]) / 1000.0
				]
			)
		)
	# Economy
	lines.append("\n## Economy pacing (GAME_DESIGN §6.3)\n")
	(
		lines
		. append(
			"| Players | Earned by end of r5 | 4000 earned in round | First perk | Power on | Forge unlocked | First upgrade |"
		)
	)
	lines.append("|---|---|---|---|---|---|---|")
	for p: int in [1, 2, 3, 4]:
		var s: Dictionary = m.simulate(p, 30)
		var ms: Dictionary = s["milestones"]
		lines.append(
			(
				"| %d | %d | %s | %s | %s | %s | %s |"
				% [
					p,
					s["earned_by_r5"],
					ms.get("earned_4000", "-"),
					ms.get("first_perk", "-"),
					ms.get("power", "-"),
					ms.get("forge_unlocked", "-"),
					ms.get("first_upgrade", "-")
				]
			)
		)
		if p == 1:
			_check(
				failures, "solo 4000 earned by round 5 (±2)", _within(ms, "earned_4000", 3, 7), ms.get("earned_4000")
			)
			_check(failures, "solo first perk r6-8 (±2)", _within(ms, "first_perk", 4, 10), ms.get("first_perk"))
			_check(failures, "solo power r7-10 (±2)", _within(ms, "power", 5, 12), ms.get("power"))
			_check(
				failures,
				"solo Forge unlocked r10-14 (±2)",
				_within(ms, "forge_unlocked", 8, 16),
				ms.get("forge_unlocked")
			)
			_check(
				failures,
				"solo first upgrade r12-15 (±2)",
				_within(ms, "first_upgrade", 10, 17),
				ms.get("first_upgrade")
			)
			lines.append("")
			lines.append("Solo timeline (round, earned, bank, weapon): %s\n" % str(s["timeline"].slice(0, 16)))
	var solo_power: int = int(m.simulate(1, 30)["milestones"].get("power", 99))
	var coop_power: int = int(m.simulate(4, 30)["milestones"].get("power", 99))
	_check(
		failures,
		"co-op reaches power no later than solo (shared doors)",
		coop_power <= solo_power,
		[solo_power, coop_power]
	)
	# Specials, Warden, traps
	var sched: PackedInt32Array = m.special_rounds(12345, 50)
	lines.append("## Special rounds, Warden, traps\n")
	lines.append("- Special rounds (seed 12345) to r50: %s (%d)" % [str(sched), sched.size()])
	_check(
		failures,
		"special rounds every 4-6 from 5-7",
		sched.size() >= 8 and sched.size() <= 10 and sched[0] >= 5 and sched[0] <= 7,
		sched
	)
	for r: int in [25, 35, 50]:
		lines.append("- Warden HP at r%d: solo %.0f, 4p %.0f" % [r, m.warden_health(r, 1), m.warden_health(r, 4)])
	var trap_kills_r15: float = minf(24.0, float(m.curve.zombie_count(15, 1)))
	lines.append(TRAP_LINE % (trap_kills_r15 * 50.0))
	var twin: Array = [
		m.viable_until(m.weapon(&"m16")),
		m.viable_until(m.weapon(&"m16"), 80, 2.66),
		m.viable_until(m.weapon(&"m16_up")),
		m.viable_until(m.weapon(&"m16_up"), 80, 2.66)
	]
	lines.append(TWIN_LINE % twin)
	lines.append("\n## Checks\n")
	for f: String in failures:
		lines.append("- ❌ " + f)
	if failures.is_empty():
		lines.append("- ✅ all balance targets met")
	var text: String = "\n".join(lines) + "\n"
	var abs_out: String = ProjectSettings.globalize_path(out_path) if out_path.begins_with("res://") else out_path
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var f: FileAccess = FileAccess.open(abs_out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	Log.info(&"balance", "report written to %s (%d failed checks)" % [abs_out, failures.size()])
	for fl: String in failures:
		Log.warn(&"balance", fl)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _within(ms: Dictionary, key: String, lo: int, hi: int) -> bool:
	return ms.has(key) and int(ms[key]) >= lo and int(ms[key]) <= hi


func _check(failures: PackedStringArray, label: String, ok: bool, value: Variant) -> void:
	if not ok:
		failures.append("%s (got %s)" % [label, str(value)])
