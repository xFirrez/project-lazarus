# VesperPeakRules — Vesper Peak's MapRules (VESPER_PEAK §9). Step 6: logs zone / door progress;
# power, relays, gondola, special rounds (Galvanics) and the quest arrive in Steps 8-14.
# Authority: host only (hooks are called by core on the host).
extends MapRules


func on_match_start() -> void:
	Log.info(&"vesper_peak", "Arrival Station: hold the windows, buy D01 / D02 to expand.")


func on_zone_unlocked(zone: StringName) -> void:
	Log.info(&"vesper_peak", "Zone %s open" % zone)
