class_name TestCase
extends RefCounted
## Base class for tests. Methods starting with test_ are run by run_tests.gd.

var failures: PackedStringArray = []


func assert_true(value: bool, message: String = "expected true") -> void:
	if not value:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s expected %s, got %s" % [message, str(expected), str(actual)])


func fail(message: String) -> void:
	failures.append(message)


## Advance only the builder when a test needs a finished building at a fixed hour.
func finish_construction(w: Node) -> void:
	for tick in 1600:
		if w.construction.projects.is_empty():
			return
		w.construction.tick(0.25)
	fail("Construction did not finish within 400 simulation seconds")
