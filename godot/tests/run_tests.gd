extends SceneTree
## Minimal test runner: runs every test_* method in res://tests/test_*.gd.
##   godot --headless --path godot -s tests/run_tests.gd
## Exits non-zero if anything fails.

var failures := 0
var passes := 0
var _current := ""


func _init() -> void:
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			var script: GDScript = load("res://tests/" + f)
			# A test file that will not compile must fail the run, not vanish
			# from it: otherwise CI goes green with a whole suite unrun.
			if script == null or not script.can_instantiate():
				failures += 1
				printerr("FAIL %s does not compile" % f)
				continue
			var suite = script.new()
			suite.set("t", self)
			for m in script.get_script_method_list():
				if str(m["name"]).begins_with("test_"):
					_current = "%s::%s" % [f, m["name"]]
					var before := failures
					suite.call(m["name"])
					if failures == before:
						passes += 1
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String = "") -> void:
	if not ok:
		failures += 1
		printerr("FAIL %s %s" % [_current, what])


func eq(a, b, what: String = "") -> void:
	check(a == b, "%s: expected %s, got %s" % [what, str(b), str(a)])
