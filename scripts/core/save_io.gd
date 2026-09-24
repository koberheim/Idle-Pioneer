## Save file I/O: atomic write (temp file + rename) with the previous good
## save kept as a backup, so a crash mid-write or a corrupt file never costs
## the player their progress.
class_name SaveIO
extends RefCounted

const VERSION := 2


static func write(path: String, data: Dictionary) -> bool:
	data["version"] = VERSION
	var text: String = JSON.stringify(_sanitize(data))
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveIO: cannot write %s" % tmp)
		return false
	f.store_string(text)
	var werr: Error = f.get_error()
	f.close()
	# Never rotate a short or garbled temp file (a full disk, say) into place.
	if werr != OK or not _parses(tmp):
		push_warning("SaveIO: temp save did not verify (%d)" % werr)
		DirAccess.remove_absolute(tmp)
		return false
	# Only a save that still reads back becomes the backup, so two bad writes
	# in a row can't destroy both copies.
	if FileAccess.file_exists(path) and _parses(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("SaveIO: rename failed (%d)" % err)
		return false
	return true


## Returns {} when there is no usable save. Falls back to the backup when the
## main file is unreadable; if neither reads, both are set aside as .corrupt
## rather than overwritten by the next save.
static func read(path: String) -> Dictionary:
	var found_any: bool = false
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		found_any = true
		var parsed: Variant = _load(candidate)
		if parsed is Dictionary and (parsed as Dictionary).has("meta"):
			var d: Dictionary = parsed
			if int(d.get("version", 1)) > VERSION:
				push_warning("SaveIO: %s is from a newer version of the game" % candidate)
			return d
		push_warning("SaveIO: %s is corrupt, trying backup" % candidate)
	if found_any:
		for p: String in [path, path + ".bak"]:
			if FileAccess.file_exists(p):
				DirAccess.rename_absolute(p, p + ".corrupt")
	return {}


static func delete(path: String) -> void:
	for p: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _load(p: String) -> Variant:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func _parses(p: String) -> bool:
	var v: Variant = _load(p)
	return v is Dictionary and (v as Dictionary).has("meta")


## JSON has no NaN or infinity; they would come back as null and break
## loading. Clamp them to finite numbers before writing.
static func _sanitize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var x: float = v
			if is_nan(x):
				return 0.0
			if is_inf(x):
				return 1.0e300 if x > 0.0 else -1.0e300
			return x
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				d[k] = _sanitize(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for e: Variant in (v as Array):
				a.append(_sanitize(e))
			return a
	return v
