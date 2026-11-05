extends SceneTree
## S2 check: compile every GDScript under res://scripts (incl. res://scripts/view3d) and res://tests.
## Usage: godot --headless --path <proj> --script res://tools/view3d/ParseAll.gd
## Prints "PARSE ALL: N scripts, F failures" and exits 1 when any script fails.

const ROOTS := ["res://scripts", "res://scripts/view3d", "res://tests"]


func _initialize() -> void:
	var paths: Array[String] = []
	for root in ROOTS:
		_collect(root, paths)
	var failures := 0
	for path in paths:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var reason := ""
		if res == null:
			reason = "failed to load"
		elif not (res is GDScript):
			reason = "not a GDScript"
		elif not res.can_instantiate():
			reason = "cannot instantiate (parse or compile error)"
		if reason != "":
			failures += 1
			printerr("PARSE FAIL: %s (%s)" % [path, reason])
	print("PARSE ALL: %d scripts, %d failures" % [paths.size(), failures])
	quit(1 if failures else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("PARSE FAIL: cannot open %s" % dir_path)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.get_extension() == "gd":
			var p := dir_path.path_join(f)
			if not out.has(p):
				out.append(p)
	var dirs := dir.get_directories()
	dirs.sort()
	for d in dirs:
		if not d.begins_with("."):
			_collect(dir_path.path_join(d), out)
