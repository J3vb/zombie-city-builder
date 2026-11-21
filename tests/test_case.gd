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
