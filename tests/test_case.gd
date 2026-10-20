class_name TestCase
extends RefCounted
## Base for tests. Methods named test_* are run by tests/run_all.gd.
## A test fails if any check() fails; the first failing message is reported.

var tree: SceneTree
var failures: Array[String] = []


func check(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond


func check_eq(a: Variant, b: Variant, msg: String) -> bool:
	return check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func before_each() -> void:
	pass


func after_each() -> void:
	pass


## Adds `n` under the root and returns it (freed by after_each callers).
func add(n: Node) -> Node:
	tree.root.add_child(n)
	return n


## Steps physics/process `frames` times at a fixed delta (for simulations).
func step_frames(frames: int) -> void:
	for i: int in frames:
		await tree.physics_frame
