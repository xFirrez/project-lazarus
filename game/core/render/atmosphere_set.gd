# AtmosphereSet — a map's per-zone AtmosphereProfiles (Step 13) for ZoneAtmosphere. `profiles`
# maps zone id → AtmosphereProfile; `fallback` is used outside every zone volume.
# Authority: data.
class_name AtmosphereSet
extends Resource

@export var fallback: AtmosphereProfile = null
@export var profiles: Dictionary = {}
