extends Node3D

@export_file("*.json") var ruta_niveles_json: String = "res://games/plinko/data/niveles.json"
@export var board_frame_scene: PackedScene = preload("res://games/plinko/scenes/board_frame.tscn")
@export var peg_scene: PackedScene = preload("res://games/plinko/scenes/peg.tscn")
@export var ramp_scene: PackedScene = preload("res://games/plinko/scenes/ramp.tscn")
@export var slot_scene: PackedScene = preload("res://games/plinko/scenes/slot.tscn")
@export var divider_scene: PackedScene = preload("res://games/plinko/scenes/divider.tscn")
@export var nivel_actual: int = 1

# Nodos contenedores y cámara
@onready var board_frame_holder: Node3D = $BoardFrameHolder
@onready var board_elements: Node3D = $BoardElements
@onready var camera: Camera3D = $Camera3D

var score: int = 0
var cols: int = 10
var rows: int = 12
var cell_size: float = 0.2

var ball_scene: PackedScene = preload("res://games/plinko/scenes/ball.tscn")
var current_ball: RigidBody3D = null

func _ready() -> void:
	nivel_actual = save_manager.nivel_actual_seleccionado
	cargar_nivel(nivel_actual)
	spawn_next_ball()

func cargar_nivel(numero_nivel: int) -> void:
	print("generate level!")
	clear_board()

	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No existe el archivo de niveles")
		return

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_niveles = JSON.parse_string(texto_json)
	if not datos_niveles or not datos_niveles.has(str(numero_nivel)):
		print("ERROR: No existe el nivel ", numero_nivel)
		return

	var level_data = datos_niveles[str(numero_nivel)]

	var peg_color_hex: String = level_data.get("color_peg", "ff00ff")
	var board_color_hex: String = level_data.get("color_board", "ffff00")
	var ramp_color_hex: String = level_data.get("color_ramp", peg_color_hex)

	# Soporte para niveles legacy con grid_cols/grid_rows/cell_size
	if level_data.has("grid_cols"):
		cols = level_data.get("grid_cols")
	if level_data.has("grid_rows"):
		rows = level_data.get("grid_rows")
	if level_data.has("cell_size"):
		cell_size = level_data.get("cell_size")

	if board_frame_scene:
		var frame_inst = board_frame_scene.instantiate()
		board_frame_holder.add_child(frame_inst)

		_apply_element_color(frame_inst, board_color_hex)

	var pegs_array = level_data.get("pegs", [])
	for peg_info in pegs_array:
		var peg_col: float = float(peg_info["col"])
		var peg_row: int = peg_info["row"]
		
		var peg_inst = peg_scene.instantiate()
		board_elements.add_child(peg_inst)
		peg_inst.position = grid_to_world(peg_col, peg_row)

		_apply_element_color(peg_inst, peg_color_hex)

	var ramps_array = level_data.get("ramps", [])
	for ramp_info in ramps_array:
		var ramp_col: float = float(ramp_info["col"])
		var ramp_row: int = ramp_info["row"]
		var rot_deg: float = ramp_info.get("rotation_deg", 0.0)
		
		var ramp_inst = ramp_scene.instantiate()
		board_elements.add_child(ramp_inst)
		ramp_inst.position = grid_to_world(ramp_col, ramp_row)
		ramp_inst.rotation_degrees.z = rot_deg

		_apply_element_color(ramp_inst, ramp_color_hex)

	var slots_array = level_data.get("slots", [])
	build_slots(slots_array)

	setup_camera()

func build_slots(slots_data: Array) -> void:
	var row_y: float = -2.8 # Fila donde se instancian los sensores
	
	for i in range(slots_data.size()):
		var slot_info = slots_data[i]
		var col_start: float = float(slot_info["col_start"])
		var col_end: float = float(slot_info["col_end"])
		var pts: int = int(slot_info["points"])
		var color_hex: String = slot_info.get("color", "#FF0000") # Rojo por defecto si falta en JSON

		# 1. Calcular el ancho total del slot en unidades de mundo
		var total_cols_span: float = col_end - col_start
		var slot_width_world: float = total_cols_span * cell_size

		# 2. Posición central del slot
		var mid_col: float = (col_start + col_end) / 2.0
		var slot_inst = slot_scene.instantiate()
		slot_inst.points = pts
		slot_inst.position = grid_to_world(mid_col, row_y)
		
		# 3. Ajustamos el ancho dinámicamente ANTES de añadirlo a la escena
		slot_inst.setup_slot(slot_width_world, pts, color_hex)
		
		slot_inst.ball_scored.connect(_on_ball_scored)
		board_elements.add_child(slot_inst)

		# 4. Instanciar divisores (Dividers) en col_start y col_end
		var divider_inst = divider_scene.instantiate()
		divider_inst.position = grid_to_world(col_start, row_y)
		board_elements.add_child(divider_inst)

		if i == slots_data.size() - 1:
			var last_divider = divider_scene.instantiate()
			last_divider.position = grid_to_world(col_end, row_y)
			board_elements.add_child(last_divider)

func _on_ball_scored(points_awarded: int) -> void:
	score += points_awarded
	print("¡Goles/Puntos anotados!: ", points_awarded, " | Puntaje Total: ", score)
	
	# Preparamos la siguiente bola para lanzar tras un breve retraso
	get_tree().create_timer(0.5).timeout.connect(spawn_next_ball)

func setup_camera() -> void:
	var total_width_cam: float = cols * cell_size
	var total_height_cam: float = rows * cell_size

	var max_dimension_cam: float = max(total_width_cam, total_height_cam)
	# Aumentamos la distancia en Z de 1.35 a 2.5 para abarcar todo el marco
	var distance_z: float = max_dimension_cam * 1.4

	camera.position = Vector3(0.0, 0.0, distance_z)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func grid_to_world(col_pos: float, row_pos: float) -> Vector3:
	var total_width_grid: float = cols * cell_size
	var total_height_grid: float = rows * cell_size

	var start_x: float = -(total_width_grid / 2.0) + (cell_size / 2.0)
	var start_y: float = -(total_height_grid / 2.0) + (cell_size / 2.0)

	var x_pos: float = start_x + (col_pos * cell_size)
	var y_pos: float = start_y + (row_pos * cell_size)
	var z_pos: float = 0.2

	return Vector3(x_pos, y_pos, z_pos)

func _apply_element_color(node: Node, color_hex: String) -> void:
	# API genérica unificada: todos los elementos (board, peg, ramp) exponen set_element_color
	# que internamente delega a ColorUtils.apply_color. Fallback directo por si el nodo no
	# tiene el método (p.ej. escena sin script).
	if node.has_method("set_element_color"):
		node.call("set_element_color", color_hex)
	elif node.has_method("set_board_color"):
		node.call("set_board_color", color_hex)
	elif node.has_method("set_peg_color"):
		node.call("set_peg_color", color_hex)
	elif node.has_method("set_ramp_color"):
		node.call("set_ramp_color", color_hex)
	else:
		ColorUtils.apply_color(node, color_hex)

func clear_board() -> void:
	for child in board_frame_holder.get_children():
		child.queue_free()
	for child in board_elements.get_children():
		child.queue_free()

func load_level_data(level_id: String) -> Dictionary:
	# Compatibilidad: wrapper legacy que ahora usa ruta_niveles_json y get_file_as_string
	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No existe el archivo de niveles")
		return {}

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var parsed_result = JSON.parse_string(texto_json)
	
	if parsed_result == null or not parsed_result.has(level_id):
		return {}

	return parsed_result[level_id]

func spawn_next_ball() -> void:
	if current_ball == null:
		current_ball = ball_scene.instantiate()
		
		# Calculamos los límites superiores basados en el tamaño del tablero
		var board_width: float = cols * cell_size
		var board_height: float = rows * cell_size + 0.5
		
		# Ajustar el barrido horizontal dentro de los límites de las paredes
		current_ball.min_x = -(board_width / 2.0) + 0.15
		current_ball.max_x = (board_width / 2.0) - 0.15
		# Posicionarla justo por arriba de la primera fila de pilones
		current_ball.spawn_y = (board_height / 2.0) + 0.1
		
		add_child(current_ball)
		
func _unhandled_input(event: InputEvent) -> void:
	# Detectar clic de mouse o tap en pantalla táctil
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_ball != null and not current_ball.is_active:
			current_ball.release_ball()
			# Desvinculamos el puntero para preparar la siguiente cuando se requiera
			current_ball = null
