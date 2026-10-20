extends Node
## Test entry: godot --headless --path . res://tests/run_all.tscn
## Runs every tests/test_*.gd (TestCase subclasses). Exit code 0 = all pass.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# let autoloads finish _ready
	await get_tree().process_frame
	var files: PackedStringArray = DirAccess.get_files_at("res://tests")
	files.sort()
	for f: String in files:
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			await _run_file("res://tests/" + f)
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		_fail(path, "could not load script")
		return
	var names: Array[String] = []
	for m: Dictionary in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not names.has(n):
			names.append(n)
	for n: String in names:
		var tc: TestCase = script.new() as TestCase
		tc.tree = get_tree()
		_reset_globals()
		tc.before_each()
		await tc.call(n)
		tc.after_each()
		var label: String = "%s::%s" % [path.get_file().get_basename(), n]
		if tc.failures.is_empty():
			_passed += 1
			print("[PASS] %s" % label)
		else:
			_fail(label, "; ".join(tc.failures.slice(0, 3)))
		# free anything the test left in the tree
		for c: Node in get_tree().root.get_children():
			if c != self and not _is_autoload(c):
				c.free()
	_reset_globals()


func _reset_globals() -> void:
	var gs: Node = get_tree().root.get_node_or_null(^"GameState")
	if gs != null:
		gs.call(&"reset")
	Station.clear_all_claims()


func _is_autoload(n: Node) -> bool:
	return ProjectSettings.has_setting("autoload/" + n.name)


func _fail(label: String, why: String) -> void:
	_failed += 1
	print("[FAIL] %s: %s" % [label, why])
