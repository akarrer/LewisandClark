extends SceneTree
## Renders dressed Corps figures against a plain sky, standing and walking,
## plus a close look at one face, for judging the clothes (Clothes, outfit.gdshader).
## Usage: godot --path . --resolution 1600x900 -s tools/figures_lineup.gd -- <out_dir>
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var keys := ["lewis", "clark", "york", "pvt", "messenger_1"]
	var cols := [Color(0.13,0.17,0.3), Color(0.3,0.35,0.5), Color(0.3,0.3,0.25), Color(0.45,0.38,0.26), Color(0.4,0.3,0.2)]
	for i in keys.size():
		var f := CorpsFigure.new()
		f.setup(keys[i], keys[i], cols[i], i != 4)
		f.position = Vector3(i * 1.0 - 2.0, 0, 0)
		root.add_child(f)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.7,0.8,0.95)
	env.environment.ambient_light_color = Color(1,1,1); env.environment.ambient_light_energy = 0.5
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 20, 0); root.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 40; cam.look_at_from_position(Vector3(0, 1.2, 5.2), Vector3(0, 0.95, 0)); root.add_child(cam)
	await process_frame
	for i in keys.size():
		(root.get_child(i) as CorpsFigure).model.rotation.y = PI + PI + (0.5 if i % 2 == 0 else -0.4)
	var walk := ["", "Walk", "", "Walk", ""]
	for i in keys.size():
		if walk[i] != "": (root.get_child(i) as CorpsFigure).play(walk[i])
	for f in 30: await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/figures.png")
	cam.look_at_from_position(Vector3(-1.75, 1.72, 0.9), Vector3(-2.0, 1.68, 0)); cam.fov = 30
	for f in 5: await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/face.png")
	quit()
