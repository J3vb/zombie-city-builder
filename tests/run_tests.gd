extends SceneTree
## Headless test runner. Usage:
##   godot --headless --script res://tests/run_tests.gd
## Runs every tests/test_*.gd file and every test_* method in it.
## Exits with code 1 if any test fails.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	# Autoloads are added to the tree after _initialize, so wait one frame.
	await process_frame
	var failed: int = 0
	var passed: int = 0
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		if file_name == "test_case.gd" or file_name == "world_fixture.gd":
			continue
		var script: GDScript = load(TEST_DIR + file_name)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			await test.call(method_name)
			if test.failures.is_empty():
				passed += 1
				print("PASS  %s :: %s" % [file_name, method_name])
			else:
				failed += 1
				print("FAIL  %s :: %s" % [file_name, method_name])
				for message in test.failures:
					print("      " + message)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
