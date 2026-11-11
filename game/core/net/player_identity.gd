# PlayerIdentity — persistent `player_uid` (UUID v4) stored in user://, keyed by profile so
# several local instances can have distinct identities. Used for reconnect/rejoin (Step 7).
class_name PlayerIdentity
extends RefCounted

const SECTION: String = "identity"


static func path_for_profile(profile: String) -> String:
	if profile == "":
		return "user://identity.cfg"
	return "user://identity_%s.cfg" % profile


static func generate_uuid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
	)


static func is_valid_uuid(uid: String) -> bool:
	var re: RegEx = RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	return re.search(uid) != null


# Loads the uid at `path`, generating and saving a new one if missing or invalid.
static func load_or_create(path: String) -> String:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) == OK:
		var existing: String = String(cfg.get_value(SECTION, "player_uid", ""))
		if is_valid_uuid(existing):
			return existing
	var uid: String = generate_uuid()
	cfg.set_value(SECTION, "player_uid", uid)
	var err: Error = cfg.save(path)
	if err != OK:
		Log.error(&"net", "Could not save identity to %s: %s" % [path, error_string(err)])
	return uid
