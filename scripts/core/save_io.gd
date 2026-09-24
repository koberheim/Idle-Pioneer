## Save file I/O: atomic write (temp file + rename) with the previous good
## save kept as a backup, so a crash mid-write or a corrupt file never costs
## the player their progress.
class_name SaveIO
extends RefCounted

const VERSION := 1


static func write(path: String, data: Dictionary) -> bool:
	data["version"] = VERSION
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveIO: cannot write %s" % tmp)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("SaveIO: rename failed (%d)" % err)
		return false
	return true


## Returns {} when there is no usable save. Falls back to the backup when the
## main file is unreadable.
static func read(path: String) -> Dictionary:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var f := FileAccess.open(candidate, FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary and (parsed as Dictionary).has("meta"):
			return parsed
		push_warning("SaveIO: %s is corrupt, trying backup" % candidate)
	return {}


static func delete(path: String) -> void:
	for p: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
