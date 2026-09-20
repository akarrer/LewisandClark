class_name Props
extends RefCounted
## Small builders for placeholder props made from primitives (until real models).


static func mat(color: Color, rough := 0.9, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


static func box(size: Vector3, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	mi.position = pos
	return mi


static func cylinder(radius: float, height: float, color: Color, pos := Vector3.ZERO, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top < 0.0 else top
	cm.height = height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos
	return mi


static func sphere(radius: float, color: Color, pos := Vector3.ZERO, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat(color)
	mi.position = pos
	mi.scale = squash
	return mi


static func ring(radius: float, color: Color) -> Decal:
	## A soft band of warm light projected onto the ground (and the grass on it),
	## following the slope instead of floating as a hard hoop.
	var g := Gradient.new()
	# Radial fill: offset 1.0 is the decal's edge.
	var inner := (radius - 0.6) / radius
	var mid := (radius - 0.25) / radius
	g.offsets = PackedFloat32Array([0.0, inner, mid, 0.97, 1.0])
	var clear := Color(color, 0.0)
	g.colors = PackedColorArray([clear, clear, Color(color, 0.8), clear, clear])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var d := Decal.new()
	d.size = Vector3(radius * 2.0, 3.0, radius * 2.0)
	d.texture_albedo = tex
	d.texture_emission = tex
	d.emission_energy = 0.1
	d.albedo_mix = 0.5
	d.upper_fade = 0.6
	d.lower_fade = 0.6
	return d


static func puff_texture() -> GradientTexture2D:
	## A soft round blob: without it, smoke quads read as hard squares.
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	puff.gradient = soft
	return puff


static func flag(width: float, height: float) -> Node3D:
	## The fifteen-star colours, flying on the wind (see flag.gdshader). The node's
	## own origin is the hoist, so it can be placed straight onto a staff.
	var holder := Node3D.new()
	holder.name = "Colours"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, height)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 6
	mesh.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(width * 0.5, 0, 0)  # hoist at the holder's origin
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/world/flag.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(mi)
	return holder


static func village_smoke() -> GPUParticles3D:
	## A lodge fire seen from half a mile off: tall, slow, thinned by the distance.
	## The Corps read the country this way — Clark had the Oto towns on his map
	## days before he saw one, by the smokes standing over the prairie.
	var p := GPUParticles3D.new()
	p.amount = 42
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.visibility_aabb = AABB(Vector3(-40, 0, -40), Vector3(80, 220, 80))
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 1.0
	sp.direction = Vector3(0.3, 1, 0.12)
	sp.spread = 10.0
	sp.initial_velocity_min = 5.5
	sp.initial_velocity_max = 7.5
	sp.gravity = Vector3(0.6, 0.2, 0.25)
	sp.scale_min = 9.0
	sp.scale_max = 15.0
	var ramp := Gradient.new()
	# Densest well up the column: the foot of it is behind the ridge anyway.
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([Color(0.60, 0.59, 0.57, 0.14), Color(0.72, 0.71, 0.69, 0.48),
			Color(0.84, 0.84, 0.83, 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	sp.color_ramp = tex
	p.process_material = sp
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.disable_receive_shadows = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true       # otherwise the per-particle scale is thrown away
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = puff_texture()
	quad.material = m
	p.draw_pass_1 = quad
	return p


static func smoke_column() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 60, 40))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0.5, 0.4, 0)
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.3)); c.add_point(Vector2(1, 1.6))
	curve.curve = c
	pm.scale_curve = curve
	var grad := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.53, 0.5, 0.7))
	g.set_color(1, Color(0.75, 0.74, 0.72, 0.0))
	grad.gradient = g
	pm.color_ramp = grad
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(3, 3)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	# BILLBOARD_ENABLED, not BILLBOARD_PARTICLES: the particles mode divides by the
	# animation frame counts, which are zero here, and the quads come out invisible.
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # so it darkens at night
	m.disable_receive_shadows = true
	m.albedo_texture = puff_texture()
	quad.material = m
	p.draw_pass_1 = quad
	return p
