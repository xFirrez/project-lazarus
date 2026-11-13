# Offline renderer for the Step 15 score / presentation audio (tools/gen_audio.sh): writes every
# ScoreAudio event to game/content/audio/score/<event>.wav. ScoreAudio is loaded dynamically once
# the autoloads exist (it references Audio / Log).
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var score: GDScript = load("res://core/audio/score_audio.gd")
	var n: int = score.render_all()
	var want: int = (score.get("EVENTS") as Dictionary).size()
	printerr("render_score: %d / %d streams written" % [n, want])
	quit(0 if n == want else 1)
