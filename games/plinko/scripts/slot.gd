extends Area3D

var points: int = 0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

signal ball_scored(points_awarded)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup_slot(slot_width: float, pts: int, color_hex: String) -> void:
	points = pts
	
	# Referencias directas
	var col = $CollisionShape3D
	var bg_mesh = $BackgroundMesh
	var label = $PointsLabel

	# 1. Ajustar el tamaño del sensor de colisión (BoxShape3D)
	if col and col.shape:
		var new_box = BoxShape3D.new()
		var current_size = col.shape.size if col.shape is BoxShape3D else Vector3(1, 0.2, 0.3)
		new_box.size = Vector3(slot_width, current_size.y, current_size.z)
		col.shape = new_box

	# 2. Ajustar el tamaño del panel de fondo (QuadMesh / PlaneMesh)
	if bg_mesh:
		var new_quad = QuadMesh.new()
		# Asignamos el ancho dinámico y una altura fija para la franja del fondo
		new_quad.size = Vector2(slot_width, 0.3)
		
		# Crear un material único con el color del JSON
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color_hex)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Mantener color vivo sin depender de luces
		new_quad.material = mat
		
		bg_mesh.mesh = new_quad

	# 3. Actualizar el texto del Label3D
	if label:
		label.text = str(pts)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("release_ball") or body.name.begins_with("Ball"):
		emit_signal("ball_scored", points)
		body.queue_free()
