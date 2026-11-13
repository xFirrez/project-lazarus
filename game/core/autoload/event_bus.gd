# EventBus — typed global signals for LOCAL decoupling (UI <-> systems).
# Authority: local only. Never used for networking (that is Net's job).
extends Node

@warning_ignore_start("unused_signal")
signal game_state_changed(previous: int, current: int)
signal match_started(map_id: StringName)
signal match_ended(reason: String)
signal console_toggled(open: bool)
