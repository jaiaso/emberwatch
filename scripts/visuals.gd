extends RefCounted
## Original procedural models, articulated characters and physical surface shading.

const TEAM = [Color("79c5b3"), Color("e6b960"), Color("9ca7e6"), Color("d994b0")]
var materials: Dictionary = {}
var sphere_mesh: SphereMesh

func mat(color: Color, glow: bool = false) -> Material:
	var key = str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	if glow or color.a < 1.0:
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.4
		materials[key] = m
		return m
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/surface.gdshader")
	material.set_shader_parameter("tint", color)
	var metallic = 0.78 if (color.b > color.r * 0.94 and color.r > 0.42) or (color.r > 0.75 and color.g > 0.55 and color.b < 0.4) else 0.0
	material.set_shader_parameter("metal", metallic)
	var type = 1.0 if color.r > 0.48 and color.g > 0.45 and metallic == 0 else 2.0 if color.r > color.g * 1.16 and color.r < 0.6 else 0.0
	material.set_shader_parameter("kind", type)
	materials[key] = material
	return material

func sphere(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 32
	mesh.radius = 0.5
	mesh.height = 1.0
	var node = piece(parent, mesh, pos, color)
	node.scale = size
	return node

func limb(parent: Node3D, name_value: String, pos: Vector3, color: Color, leg: bool = false) -> Node3D:
	var pivot = Node3D.new()
	pivot.name = name_value
	pivot.position = pos
	parent.add_child(pivot)
	sphere(pivot, Vector3(0.17, 0.39, 0.19), Vector3(0,-0.16,0), color)
	sphere(pivot, Vector3(0.14, 0.36, 0.16), Vector3(0,-0.44,-0.035), color.darkened(0.12))
	sphere(pivot, Vector3(0.17, 0.13, 0.28) if leg else Vector3(0.13,0.18,0.14), Vector3(0,-0.63,-0.07), Color("473c31") if leg else Color("c59f7f"))
	return pivot

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return piece(parent, mesh, pos, color)

func cylinder(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, color: Color, sides: int = 24) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 3
	return piece(parent, mesh, pos, color)

func piece(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	node.position = pos
	parent.add_child(node)
	return node

func roof(parent: Node3D, width: float, depth: float, height: float, pos: Vector3, color: Color) -> void:
	var w = width / 2
	var d = depth / 2
	var points = [Vector3(-w, 0, -d), Vector3(w, 0, -d), Vector3(0, height, -d),
		Vector3(-w, 0, d), Vector3(w, 0, d), Vector3(0, height, d)]
	var faces = [[0, 2, 1], [3, 4, 5], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 4]]
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for idx in [face[2], face[1], face[0]]:
			surface.add_vertex(points[idx])
	surface.generate_normals()
	piece(parent, surface.commit(), pos, color)

func flag(parent: Node3D, pos: Vector3, color: Color, height: float = 2.4) -> void:
	cylinder(parent, 0.045, 0.035, height, pos + Vector3(0, height / 2, 0), Color("5d4938"), 4)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(12):
		for y in range(4):
			for uv in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
				uv /= Vector2(12,4)
				st.set_uv(uv)
				st.add_vertex(Vector3(uv.x*0.78,height-0.58+uv.y*0.48,0))
	st.generate_normals()
	var cloth = piece(parent,st.commit(),pos,color)
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/flag.gdshader")
	material.set_shader_parameter("tint",color)
	cloth.material_override = material

func make_unit(kind: String, team: Color) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var enemy = kind in ["raider", "brute", "slinger", "warlord"]
	var cloth = Color("81382c") if enemy else team.darkened(0.18)
	var skin = Color("c8a183")
	if kind in ["brute", "warlord"]:
		body.scale = Vector3.ONE * (1.45 if kind == "brute" else 1.8)
	# Natural proportions, separate articulated upper/lower limb shapes.
	sphere(body, Vector3(0.48,0.63,0.32), Vector3(0,1.0,0), cloth)
	cylinder(body, 0.26,0.22,0.23,Vector3(0,0.75,0),cloth)
	limb(body,"LegL",Vector3(-0.13,0.72,0),Color("51493b"),true)
	limb(body,"LegR",Vector3(0.13,0.72,0),Color("51493b"),true)
	limb(body,"ArmL",Vector3(-0.30,1.23,0),cloth)
	var right = limb(body,"ArmR",Vector3(0.30,1.23,0),cloth)
	cylinder(body,0.09,0.09,0.15,Vector3(0,1.36,0),skin)
	sphere(body,Vector3(0.31,0.38,0.30),Vector3(0,1.57,0),skin)
	sphere(body,Vector3(0.065,0.09,0.09),Vector3(0,1.57,-0.16),skin.darkened(0.1))
	for x in [-0.075,0.075]:
		sphere(body,Vector3(0.04,0.028,0.026),Vector3(x,1.61,-0.143),Color("292c27"))
	box(body,Vector3(0.46,0.055,0.34),Vector3(0,0.79,0),Color("574332"))
	if kind == "worker":
		cylinder(body,0.36,0.36,0.035,Vector3(0,1.77,0),Color("d9b977"),32)
		cylinder(body,0.20,0.13,0.17,Vector3(0,1.85,0),Color("ba9552"),24)
		box(body,Vector3(0.32,0.40,0.04),Vector3(0,0.98,-0.18),Color("baa27b"))
		cylinder(right,0.025,0.025,0.95,Vector3(0,-0.45,-0.12),Color("705036"),12)
		box(right,Vector3(0.36,0.12,0.12),Vector3(0,-0.03,-0.12),Color("8a969b"))
	elif kind in ["archer","slinger"]:
		sphere(body,Vector3(0.36,0.34,0.34),Vector3(0,1.69,0.045),Color("315d42"))
		box(body,Vector3(0.39,0.63,0.045),Vector3(0,1.03,0.21),Color("315d42"))
		cylinder(body,0.085,0.085,0.48,Vector3(-0.16,1.1,0.25),Color("624333"),16)
		for i in range(5):
			cylinder(body,0.01,0.01,0.5,Vector3(-0.22+i*0.028,1.42,0.25),Color("cab28c"),8)
		for i in range(12):
			var angle = -1.3 + i * 2.6 / 11
			var pos = Vector3(0,-0.25+sin(angle)*0.55,-0.18-cos(angle)*0.24)
			var bow = cylinder(right,0.025,0.025,0.14,pos,Color("ae8050"),12)
			bow.rotation.x = -angle
		cylinder(right,0.006,0.006,1.06,Vector3(0,-0.25,-0.245),Color("d9caae"),6)
	else:
		sphere(body,Vector3(0.52,0.53,0.36),Vector3(0,1.06,0),Color("89979e"))
		for x in [-0.30,0.30]:
			sphere(body,Vector3(0.27,0.19,0.29),Vector3(x,1.24,0),Color("9caaae"))
		sphere(body,Vector3(0.35,0.27,0.34),Vector3(0,1.72,0.02),Color("8c999f"))
		box(body,Vector3(0.055,0.26,0.08),Vector3(0,1.61,-0.175),Color("a7b1b2"))
		box(right,Vector3(0.075,0.83,0.035),Vector3(0,-0.05,-0.21),Color("b9c6cc"))
		box(right,Vector3(0.26,0.045,0.09),Vector3(0,-0.45,-0.21),Color("b29860"))
		var shield = sphere(body,Vector3(0.09,0.67,0.48),Vector3(-0.39,0.98,-0.04),Color("afb8ba"))
		shield.rotation.z = 0.12
		sphere(body,Vector3(0.10,0.55,0.37),Vector3(-0.43,0.98,-0.04),cloth)
		for i in range(8):
			var angle = i * TAU / 8
			sphere(body,Vector3.ONE*0.035,Vector3(-0.47,0.98+cos(angle)*0.25,-0.04+sin(angle)*0.17),Color("d0bf8b"))
	if kind == "warlord":
		cylinder(body,0.22,0.22,0.13,Vector3(0,1.88,0),Color("d0ab54"),24)
		for i in range(8):
			cylinder(body,0.035,0,0.22,Vector3(cos(i*TAU/8)*0.2,2.02,sin(i*TAU/8)*0.2),Color("d0ab54"),8)
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.56
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 8
	var ring = piece(root,ring_mesh,Vector3(0,0.045,0),team)
	ring.material_override = mat(team,true)
	ring.name = "Selection"
	ring.visible = false
	return root

func make_building(kind: String, team: Color) -> Node3D:
	var root = Node3D.new()
	var stone = Color("ada68c")
	var timber = Color("67513b")
	var roofing = Color("675344")
	if kind == "hall":
		box(root, Vector3(5.7, 0.35, 5.1), Vector3(0, 0.18, 0), Color("666854"))
		box(root, Vector3(4.6, 1.9, 3.5), Vector3(0, 1.25, 0), stone)
		roof(root, 5.2, 4.1, 1.6, Vector3(0, 2.2, 0), roofing)
		for x in [-2.1, 2.1]:
			box(root, Vector3(1.1, 3.2, 1.15), Vector3(x, 1.65, 1.6), stone.darkened(0.12))
			cylinder(root, 0.9, 0, 1.1, Vector3(x, 3.75, 1.6), team.darkened(0.25), 4)
		box(root, Vector3(0.9, 1.4, 0.06), Vector3(0, 1.02, 1.78), timber.darkened(0.45))
		for x in [-1.35, 1.35]:
			box(root, Vector3(0.35, 0.55, 0.08), Vector3(x, 1.4, 1.79), Color("f2bd72"))
		flag(root, Vector3(0, 3.6, 0), team, 2.0)
		for x in [-1.0, 1.0]:
			cylinder(root, 0.14, 0.17, 0.6, Vector3(x, 0.6, 2.6), timber, 4)
			make_fire(root,Vector3(x,1.12,2.6))
	elif kind == "barracks":
		box(root, Vector3(3.7, 0.2, 3.8), Vector3(0, 0.1, 0), Color("6a6c54"))
		box(root, Vector3(3.3, 1.6, 3), Vector3(0, 0.95, 0), stone.darkened(0.12))
		roof(root, 3.9, 3.5, 1.3, Vector3(0, 1.75, 0), team.darkened(0.32))
		box(root, Vector3(1.1, 1.3, 0.1), Vector3(0, 0.85, 1.53), timber.darkened(0.4))
		for x in [-1.4, 1.4]:
			box(root, Vector3(0.15, 1.6, 0.12), Vector3(x, 1, 1.56), timber)
		flag(root, Vector3(1.8, 0, 1.6), team)
	elif kind == "house":
		box(root, Vector3(2.6, 1.4, 2.4), Vector3(0, 0.75, 0), Color("b3a27d"))
		roof(root, 3, 2.9, 1.25, Vector3(0, 1.45, 0), roofing)
		box(root, Vector3(0.6, 1.0, 0.08), Vector3(-0.5, 0.55, 1.24), timber.darkened(0.35))
		box(root, Vector3(0.45, 0.45, 0.08), Vector3(0.65, 0.95, 1.25), team)
		box(root, Vector3(0.45, 1.3, 0.5), Vector3(0.75, 2.15, -0.5), stone.darkened(0.2))
	elif kind == "tower":
		box(root, Vector3(2.2, 0.25, 2.2), Vector3(0, 0.15, 0), Color("65654e"))
		box(root, Vector3(1.7, 3.7, 1.7), Vector3(0, 2, 0), stone.darkened(0.15))
		box(root, Vector3(2.1, 0.5, 2.1), Vector3(0, 3.85, 0), timber)
		for x in [-0.84, 0.84]:
			for z in [-0.84, 0.84]:
				box(root, Vector3(0.36, 0.65, 0.36), Vector3(x, 4.38, z), stone)
		flag(root, Vector3(0, 4.0, 0), team, 1.65)
	for x in [-0.8, 0.8]:
		if kind in ["hall", "house", "barracks"]:
			box(root, Vector3(0.10, 1.1, 0.12), Vector3(x, 0.8, 1.26 if kind == "house" else 1.8), timber)
	if kind == "tower":
		for height in [0.9, 1.8, 2.7]:
			box(root, Vector3(1.76, 0.10, 1.76), Vector3(0, height, 0), stone.lightened(0.12))
	# Individually modelled courses, window frames, roof tiles and foundation stones.
	var width = 4.6 if kind == "hall" else 3.3 if kind == "barracks" else 2.6 if kind == "house" else 1.7
	var depth = 3.5 if kind == "hall" else 3.0 if kind == "barracks" else 2.4 if kind == "house" else 1.7
	for side in [-1,1]:
		for i in range(int(width / 0.5)):
			box(root,Vector3(0.46,0.23,0.22),Vector3(-width/2+0.25+i*0.5,0.22,side*depth/2),stone.darkened(0.20))
		for i in range(int(width / 0.8)):
			box(root,Vector3(0.10,1.3,0.16),Vector3(-width/2+0.4+i*0.8,1.0,side*(depth/2+0.03)),timber)
	if kind != "tower":
		var eaves = 2.2 if kind == "hall" else 1.75 if kind == "barracks" else 1.45
		var rise = 1.6 if kind == "hall" else 1.3 if kind == "barracks" else 1.25
		for side in [-1,1]:
			for row in range(5):
				for col in range(int((depth+0.6)/0.40)):
					var t = (row + 0.5)/5.0
					var tile = box(root,Vector3(width/10+0.10,0.075,0.38),Vector3(side*(width/2+0.2)*(1.0-t),eaves+rise*t+0.06,-depth/2-0.1+col*0.40),roofing.lightened(0.035*float((row+col)%3)))
					tile.rotation.z = -side*atan2(rise,width/2+0.2)
	batch_static(root)
	return root

func make_resource(kind: String, seed_value: int) -> Node3D:
	var random = RandomNumberGenerator.new()
	random.seed = seed_value * 93
	var root = Node3D.new()
	if kind == "wood":
		var height = random.randf_range(3.6,5.3)
		cylinder(root,0.24,0.09,height*0.8,Vector3(0,height*0.4,0),Color("644b36"),18)
		for i in range(9):
			var angle = i * 2.4
			var y = 1.6 + i * height * 0.065
			var spread = 1.05 * (1.0 - i * 0.065)
			var branch = cylinder(root,0.07,0.025,spread+0.2,Vector3(cos(angle)*spread*0.4,y,sin(angle)*spread*0.4),Color("6e5236"),10)
			branch.rotation = Vector3(sin(angle)*0.8,0,cos(angle)*0.8)
			var leaf = sphere(root,Vector3(spread*1.8,1.3,spread*1.5),Vector3(cos(angle)*spread*0.55,y+0.25,sin(angle)*spread*0.55),Color("3c5931").lightened(i*0.012))
			leaf.rotation.y = angle
			leaf.material_override = canopy_material()
		var top = sphere(root,Vector3(0.85,1.5,0.85),Vector3(0,height,0),Color("47643a"))
		top.material_override = canopy_material()
	elif kind == "food":
		box(root, Vector3(2.7, 0.12, 2.6), Vector3(0, 0.03, 0), Color("62442c"))
		for row in range(5):
			box(root, Vector3(0.20, 0.12, 2.4), Vector3(-1.0 + row * 0.5, 0.12, 0), Color("987143"))
			for col in range(5):
				var pos = Vector3(-1.0 + row * 0.5, 0.50, -1.0 + col * 0.5)
				cylinder(root, 0.025, 0.02, 0.70, pos, Color("c8ac4a"), 5)
				sphere(root, Vector3(0.12,0.30,0.12), pos + Vector3(0,0.40,0), Color("d8bc6b"))
				for side in [-1,1]:
					var leaf = sphere(root,Vector3(0.035,0.28,0.06),pos+Vector3(side*0.07,0.07,0),Color("9a9a45"))
					leaf.rotation.z = side*0.7
		for x in [-1.4, 1.4]:
			box(root, Vector3(0.09, 0.25, 2.8), Vector3(x, 0.15, 0), Color("b6a477"))
	else:
		cylinder(root, 1.35, 1.1, 0.15, Vector3(0, 0.06, 0), Color("625d55"), 10)
		for i in range(5):
			var angle = i * TAU / 5
			var pos = Vector3(cos(angle) * 0.65, 0.48, sin(angle) * 0.65)
			var rock = sphere(root,Vector3(1.2,1.1,1.15),pos,Color("626d77"))
			rock.material_override = rock_material()
			rock.rotation.z = random.randf_range(-0.3, 0.3)
			var ore = cylinder(root, 0.27, 0.12, 0.55, pos + Vector3(0, 0.55, 0), Color("ffcf3d"), 7)
			ore.rotation.z = 0.35
			box(root, Vector3(0.35, 0.18, 0.40), pos + Vector3(0.18, 0.20, -0.30), Color("f7b92a"))

	batch_static(root)
	root.rotation.y = random.randf_range(-PI, PI) if kind == "wood" else 0.0
	return root

func terrain() -> Node3D:
	var root = Node3D.new()
	var random = RandomNumberGenerator.new()
	random.seed = 126
	var plane = PlaneMesh.new()
	plane.size = Vector2(144,144)
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	var ground = piece(root,plane,Vector3(0,-0.055,0),Color.WHITE)
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/ground.gdshader")
	ground.material_override = material
	var terrain_data = preload("res://scripts/terrain_data.gd")
	for cliff in terrain_data.CLIFFS:
		box(root,Vector3(cliff.size.x,2.3,cliff.size.y),Vector3(cliff.get_center().x,1.05,cliff.get_center().y),Color("797b70"))
		for x in range(int(cliff.position.x),int(cliff.end.x),2):
			for z in range(int(cliff.position.y),int(cliff.end.y),2):
				var height = random.randf_range(2.8,4.2)
				var rock = sphere(root,Vector3(2.8,height,2.8),Vector3(x+1,height*0.42,z+1),Color("787e72"))
				rock.material_override = rock_material()
				rock.rotation = Vector3(random.randf_range(-0.2,0.2),random.randf_range(0,PI),random.randf_range(-0.2,0.2))
	for i in range(60):
		var angle = random.randf_range(0,TAU)
		var pos = Vector2(cos(angle),sin(angle))*random.randf_range(66,78)
		sphere(root,Vector3(random.randf_range(5,10),random.randf_range(8,17),random.randf_range(5,10)),Vector3(pos.x,0,pos.y),Color("626f65"))
	# Thousands of grass blades rendered with one MultiMesh draw, with wind.
	var grass_mesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-0.10,0,0),Vector3(0.07,0.58,0.02),Vector3(0.10,0,0),Vector3(0,0,-0.1),Vector3(0.02,0.47,0.07),Vector3(0,0,0.1)]:
		st.set_uv(Vector2(0,float(point.y>0.1)))
		st.add_vertex(point)
	st.generate_normals()
	grass_mesh = st.commit()
	var grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/foliage.gdshader")
	grass_mat.set_shader_parameter("tint",Color("6b783e"))
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = grass_mesh
	multi.instance_count = 7000
	var instance = MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = grass_mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	var count = 0
	for i in range(11000):
		var pos = Vector2(random.randf_range(-59,59),random.randf_range(-59,59))
		if terrain_data.blocked(pos,1) or pos.length()<15 or absf(pos.x-pos.y*0.3)<3 or absf(pos.y+pos.x*0.22)<3:
			continue
		var scale_value = random.randf_range(0.4,1.2)
		multi.set_instance_transform(count,Transform3D(Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value),Vector3(pos.x,0,pos.y)))
		count += 1
		if count == 7000:
			break
	multi.visible_instance_count = count
	return root

func canopy_material() -> Material:
	if not materials.has("canopy"):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/canopy.gdshader")
		m.set_shader_parameter("tint",Color("2c4e24"))
		materials.canopy = m
	return materials.canopy

func rock_material() -> Material:
	if not materials.has("rock"):
		var m = ShaderMaterial.new()
		m.shader = load("res://shaders/rock.gdshader")
		materials.rock = m
	return materials.rock

func make_fire(parent: Node3D, pos: Vector3) -> void:
	var light = OmniLight3D.new()
	light.position = pos + Vector3(0,0.35,0)
	light.light_color = Color("ff9e43")
	light.light_energy = 1.8
	light.omni_range = 3.5
	parent.add_child(light)
	var particles = GPUParticles3D.new()
	particles.position = pos
	particles.amount = 24
	particles.lifetime = 0.85
	particles.preprocess = 0.7
	particles.visibility_aabb = AABB(Vector3(-1,-1,-1),Vector3(2,4,2))
	var process = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 15
	process.initial_velocity_min = 0.45
	process.initial_velocity_max = 0.9
	process.gravity = Vector3(0,0.15,0)
	process.scale_min = 0.08
	process.scale_max = 0.18
	var gradient = Gradient.new()
	gradient.set_color(0,Color(1,0.8,0.25,0.9))
	gradient.set_color(1,Color(0.8,0.12,0.02,0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var quad = QuadMesh.new()
	quad.size = Vector2(0.28,0.44)
	var fire_material = StandardMaterial3D.new()
	var fade = Gradient.new()
	fade.set_color(0,Color(1,1,1,0.9))
	fade.set_color(1,Color(1,1,1,0))
	var texture = GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	fire_material.albedo_texture = texture
	fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_material.vertex_color_use_as_albedo = true
	fire_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fire_material.emission_enabled = true
	fire_material.emission = Color(1,0.35,0.05)
	fire_material.emission_energy_multiplier = 2.0
	quad.material = fire_material
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)

func batch_static(root: Node3D) -> void:
	var groups = {}
	for node in root.get_children():
		if not node is MeshInstance3D or node.name == "Selection":
			continue
		var material = node.material_override
		if not material is ShaderMaterial or not material.shader.resource_path.ends_with("surface.gdshader"):
			continue
		var key = material.get_instance_id()
		if not groups.has(key):
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"surface":surface,"material":material}
		for index in range(node.mesh.get_surface_count()):
			groups[key].surface.append_from(node.mesh,index,node.transform)
		root.remove_child(node)
		node.free()
	for group in groups.values():
		var mesh = MeshInstance3D.new()
		mesh.mesh = group.surface.commit()
		mesh.material_override = group.material
		root.add_child(mesh)
