extends RefCounted
## All original art is built from intentionally simple, flat-shaded geometry.

const TEAM = [Color("79c5b3"), Color("e6b960"), Color("9ca7e6"), Color("d994b0")]
var materials: Dictionary = {}

func mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key = str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = m
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return piece(parent, mesh, pos, color)

func cylinder(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, color: Color, sides: int = 6) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
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
	box(parent, Vector3(0.72, 0.44, 0.025), pos + Vector3(0.34, height - 0.32, 0), color)

func make_unit(kind: String, team: Color) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var enemy = kind in ["raider", "brute"]
	var cloth = Color("9c4b3c") if enemy else team
	var skin = Color("c3a17d") if not enemy else Color("a38a70")
	if kind == "brute":
		body.scale = Vector3.ONE * 1.45
	box(body, Vector3(0.4, 0.57, 0.29), Vector3(0, 0.8, 0), cloth)
	box(body, Vector3(0.14, 0.42, 0.18), Vector3(-0.12, 0.3, 0), Color("3d3d38"))
	box(body, Vector3(0.14, 0.42, 0.18), Vector3(0.12, 0.3, 0), Color("3d3d38"))
	box(body, Vector3(0.28, 0.3, 0.27), Vector3(0, 1.26, 0), skin)
	box(body, Vector3(0.12, 0.4, 0.14), Vector3(-0.29, 0.79, 0), cloth.darkened(0.16))
	box(body, Vector3(0.12, 0.4, 0.14), Vector3(0.29, 0.79, 0), cloth.darkened(0.16))
	if kind == "worker":
		cylinder(body, 0.25, 0.14, 0.16, Vector3(0, 1.45, 0), Color("ccad6c"))
		box(body, Vector3(0.06, 0.72, 0.06), Vector3(0.36, 0.95, 0.05), Color("69513b"))
		box(body, Vector3(0.3, 0.16, 0.11), Vector3(0.43, 1.22, 0.05), Color("b3b4a3"))
	elif kind == "archer":
		cylinder(body, 0.21, 0, 0.28, Vector3(0, 1.51, 0), team.darkened(0.35))
		var bow = cylinder(body, 0.025, 0.025, 0.95, Vector3(0.35, 0.95, -0.13), Color("b7a076"), 4)
		bow.rotation.z = -0.25
		box(body, Vector3(0.08, 0.65, 0.13), Vector3(-0.12, 0.9, 0.24), Color("574633"))
	else:
		cylinder(body, 0.23, 0.17, 0.22, Vector3(0, 1.43, 0), Color("929c97"), 5)
		box(body, Vector3(0.12, 0.8, 0.07), Vector3(0.37, 1.05, 0), Color("bbc8bf"))
		box(body, Vector3(0.3, 0.07, 0.09), Vector3(0.37, 0.82, 0), Color("897753"))
		box(body, Vector3(0.09, 0.51, 0.4), Vector3(-0.35, 0.86, 0), cloth.darkened(0.28))
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.57
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 4
	var ring = piece(root, ring_mesh, Vector3(0, 0.06, 0), team)
	ring.material_override = mat(team, true)
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
			cylinder(root, 0.22, 0, 0.52, Vector3(x, 1.12, 2.6), Color("eea256"), 5)
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
	return root

func make_resource(kind: String, seed_value: int) -> Node3D:
	var random = RandomNumberGenerator.new()
	random.seed = seed_value * 93
	var root = Node3D.new()
	if kind == "wood":
		var height = random.randf_range(2.8, 4.5)
		cylinder(root, 0.18, 0.11, 1.5, Vector3(0, 0.75, 0), Color("63523b"), 5)
		var colors = [Color("354e3c"), Color("46634a"), Color("526947")]
		var color: Color = colors[seed_value % 3]
		cylinder(root, 1.1, 0, height * 0.75, Vector3(0, height * 0.59, 0), color, 5)
		cylinder(root, 0.8, 0, height * 0.65, Vector3(0, height * 0.84, 0), color.lightened(0.04), 5)
	elif kind == "food":
		for i in range(3):
			var pos = Vector3(random.randf_range(-0.4, 0.4), 0.35, random.randf_range(-0.4, 0.4))
			cylinder(root, 0.48, 0.25, 0.75, pos, Color("666941"), 5)
			box(root, Vector3(0.12, 0.12, 0.12), pos + Vector3(0.1, 0.42, 0.13), Color("ce8460"))
	else:
		for i in range(3):
			var pos = Vector3(random.randf_range(-0.45, 0.45), 0.38, random.randf_range(-0.45, 0.45))
			var rock = cylinder(root, 0.58, 0.32, 0.8, pos, Color("858574"), 5)
			rock.rotation.z = random.randf_range(-0.3, 0.3)
			box(root, Vector3(0.28, 0.17, 0.3), pos + Vector3(0, 0.44, 0), Color("d3b776"))
	root.rotation.y = random.randf_range(-PI, PI)
	return root

func terrain() -> Node3D:
	var root = Node3D.new()
	var random = RandomNumberGenerator.new()
	random.seed = 126
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var greens = [Color("53664b"), Color("5d7050"), Color("617152"), Color("596b4c"), Color("667655")]
	for x in range(-44, 44, 2):
		for z in range(-44, 44, 2):
			var pos = Vector2(x, z)
			var path = absf(float(x) - float(z) * 0.3) < 2.3 or absf(float(z) + float(x) * 0.22) < 2.0
			var color: Color = greens[random.randi_range(0, 4)]
			if path or pos.length() < 5:
				color = Color("8e8765").darkened(random.randf_range(0, 0.12))
			if abs(x) > 38 or abs(z) > 38:
				color = color.darkened(0.2)
			for point in [Vector3(x, -0.04, z), Vector3(x + 2, -0.04, z), Vector3(x, -0.04, z + 2),
				Vector3(x + 2, -0.04, z), Vector3(x + 2, -0.04, z + 2), Vector3(x, -0.04, z + 2)]:
				surface.set_color(color)
				surface.add_vertex(point)
	surface.generate_normals()
	var ground = MeshInstance3D.new()
	ground.mesh = surface.commit()
	var material = mat(Color.WHITE).duplicate()
	material.vertex_color_use_as_albedo = true
	ground.material_override = material
	root.add_child(ground)
	# Impassable-looking wilderness sits beyond the actual playable boundary.
	for i in range(88):
		var angle = random.randf_range(0, TAU)
		var pos = Vector2(cos(angle), sin(angle)) * random.randf_range(43, 55)
		var rock = cylinder(root, random.randf_range(3, 7), random.randf_range(0.6, 2), random.randf_range(4, 9),
			Vector3(pos.x, 1.0, pos.y), Color("4c5b51"), 5)
		rock.rotation.y = angle
	for i in range(140):
		var pos = Vector3(random.randf_range(-38, 38), 0.12, random.randf_range(-38, 38))
		if Vector2(pos.x, pos.z).length() < 7:
			continue
		var tuft = cylinder(root, 0.14, 0, random.randf_range(0.25, 0.6), pos, Color("8b8b60"), 3)
		tuft.rotation.y = random.randf_range(0, PI)
	return root
