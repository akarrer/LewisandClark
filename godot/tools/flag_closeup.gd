extends SceneTree
## The colours up close against a plain sky, three moments of the wind, for
## judging the cloth (flag.gdshader).
## Usage: godot --path . --resolution 1600x900 -s tools/flag_closeup.gd -- <out_dir>
func _init() -> void:
	RenderingServer.global_shader_parameter_set("wind_strength", 1.6)
	var root := Node3D.new()
	get_root().add_child(root)
	# The Council Bluff staff as the game builds it, ring and all.
	root.add_child(Interactable.landmark_marker(Vector3.ZERO, "Close"))
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.62, 0.74, 0.92)
	env.environment.ambient_light_color = Color(1,1,1); env.environment.ambient_light_energy = 0.45
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-30, 60, 0); root.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 40; cam.look_at_from_position(Vector3(1.0, 5.0, 4.6), Vector3(0.9, 5.9, 0)); root.add_child(cam)
	var out := OS.get_cmdline_user_args()[0]
	for shot in 3:
		for k in 23: await process_frame
		get_root().get_texture().get_image().save_png("%s/flag_%d.png" % [out, shot])
	quit()
