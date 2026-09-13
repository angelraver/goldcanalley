extends Node3D

@export var duck_a_scene: PackedScene = preload("res://games/duckshoot/duck.tscn")
@export var bomb_scene: PackedScene   = preload("res://games/duckshoot/bomb.tscn")
@export_file("*.json") var level_json_path: String = "res://games/duckshoot/niveles.json"
@export_group("Decorado")
@export var wave_row_scene: PackedScene = preload("res://games/duckshoot/wave_row.tscn")
@export var wave_1_mesh: PackedScene    = preload("res://games/duckshoot/wave1.tscn")
@export var wave_2_mesh: PackedScene    = preload("res://games/duckshoot/wave2.tscn") # ¡Nuevo modelo!

const DISTANCIA_SPAWN: float = 0.25 # Distancia en unidades que debe avanzar el último pato para permitir otro spawn
@export_group("Ancho de Carril (X)")
@export var x_left_spawn: float = -1.5   # Punto de spawn izquierda / límite de despawn
@export var x_right_spawn: float = 1.5   # Punto de spawn derecha / límite de despawn
@export_group("Dimensiones de Escalón (Y / Z)")
@export var base_y: float = 0.0
@export var step_y: float = 0.55
@export var base_z: float = 1.4
@export var step_z: float = 0.3
@export_group("Escala de Velocidad (1 a 5)")
@export var speed_multiplier: float = 0.5
@export_group("Prefabs")
@export var wave_z_offset: float = 0 # Distancia hacia adelante respecto al pato para tapar su base

var level_total_ducks: int = 0
var ducks_spawned: int = 0
var ducks_despawned: int = 0
var is_game_over: bool = false

# Array para administrar el estado de cada carril
var lanes_data: Array = []

func _ready() -> void:
	load_level("1")

func load_level(level_id: String) -> void:
	if not FileAccess.file_exists(level_json_path):
		#printerr("No se encontró el archivo niveles.json")
		return
		
	var file = FileAccess.open(level_json_path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not json_data or not json_data.has(level_id):
		#printerr("Nivel no encontrado en el JSON: ", level_id)
		return
		
	var level_config = json_data[level_id]
	level_total_ducks = int(level_config.get("total", 50))
	ducks_spawned = 0
	ducks_despawned = 0
	is_game_over = false
	lanes_data.clear()
	
	# Procesar lane_1 a lane_4
	for i in range(1, 5):
		var lane_key = "lane_" + str(i)
		if level_config.has(lane_key):
			var l_info = level_config[lane_key]
			
			var dir_str = l_info.get("direction", "derecha")
			var dir_val = 1 if dir_str == "derecha" else -1
			
			var raw_speed = float(l_info.get("speed", "1"))
			var godot_speed = raw_speed * speed_multiplier
			
			var lane_index = i - 1
			var lane_y = base_y + (lane_index * step_y)
			var lane_z = base_z - (lane_index * step_z)
			
			# --- INSTANCIAR FILA DE OLAS DELANTE DEL ESCALÓN ---
			var wave_row_instance: WaveRow = wave_row_scene.instantiate()
			
			var wave_type = l_info.get("wave_type", "wave1")
			var chosen_wave_mesh = wave_2_mesh if wave_type == "wave2" else wave_1_mesh
			wave_row_instance.set_wave_mesh(chosen_wave_mesh)

			# La posicionamos en el centro de la escalera, a la altura del escalón 
			# y un poquito más adelante en Z que los patos (lane_z + wave_z_offset)
			var wave_y = lane_y - 0.1 # Un toque más abajo para cubrir la base del pato
			var wave_z = lane_z + wave_z_offset
			
			wave_row_instance.position = Vector3(0, wave_y, wave_z)
			# Darle un desfase de fase alternado a cada carril para que se muevan desfasados
			wave_row_instance.phase_offset = lane_index * 1.5
			add_child(wave_row_instance)
			
			lanes_data.append({
				"index": lane_index,
				"dir": dir_val,
				"speed": godot_speed,
				"especial_rate": int(l_info.get("especial_rate", 10)),
				"patos": l_info.get("patos", []),
				"especial": l_info.get("especial", []),
				"pos_y": lane_y,
				"pos_z": lane_z,
				"last_spawned_target": null # Referencia al último objetivo creado en este carril
			})

func _process(_delta: float) -> void:
	if is_game_over:
		return
		
	# Recorrer cada carril para verificar si el último elemento avanzó la DISTANCIA_SPAWN
	for lane in lanes_data:
		_check_lane_spawn(lane)

func _check_lane_spawn(lane: Dictionary) -> void:
	# Si ya alcanzamos el total de patos a spawnear, cerramos la creación de nuevos elementos
	if ducks_spawned >= level_total_ducks:
		return
		
	var can_spawn = false
	var last_target = lane["last_spawned_target"]
	
	# Caso 1: El carril está libre (aún no nació nada o el anterior ya desapareció/murió)
	if not is_instance_valid(last_target):
		can_spawn = true
	else:
		# Caso 2: Calcular la distancia recorrida en X por el último elemento
		var start_x = x_left_spawn if lane["dir"] == 1 else x_right_spawn
		var distance_traveled = abs(last_target.global_position.x - start_x)
		
		if distance_traveled >= DISTANCIA_SPAWN:
			can_spawn = true
			
	if can_spawn:
		_spawn_next_target(lane)

func _spawn_next_target(lane: Dictionary) -> void:
	# Determinar si en esta ocasión aparecerá un Especial o un Pato según especial_rate
	var spawn_special = false
	var especial_list = lane["especial"] as Array
	
	if not especial_list.is_empty():
		var rate = lane["especial_rate"]
		# Chance de 1 en especial_rate (ej. 1 en 10)
		if randi_range(1, rate) == 1:
			spawn_special = true
			
	var instance: Target = null
	var is_duck_item = false
	
	if spawn_special:
		# Instanciar el objeto especial (Bomba)
		instance = bomb_scene.instantiate() as Target
	else:
		# Instanciar Pato (Sumará a la cuota global)
		if ducks_spawned >= level_total_ducks:
			return # Protección extra para no sobrepasar el límite total
		instance = duck_a_scene.instantiate() as Target
		is_duck_item = true
		ducks_spawned += 1

	if not instance:
		return

	# Configurar posiciones
	var start_x = x_left_spawn if lane["dir"] == 1 else x_right_spawn
	var target_x_limit = x_right_spawn if lane["dir"] == 1 else x_left_spawn

	add_child(instance)
	instance.global_position = Vector3(start_x, lane["pos_y"], lane["pos_z"])
	instance.setup(lane["speed"], lane["dir"], target_x_limit, "A" if is_duck_item else "bomb", not is_duck_item)
	
	# Suscribirse al evento de despawn del objetivo
	instance.target_despawned.connect(_on_target_despawned)
	
	# Registrar este objetivo como el último de la fila para este carril
	lane["last_spawned_target"] = instance

func _on_target_despawned(target: Target) -> void:
	# Si el objeto que llegó al final era un Pato (no especial), incrementamos el contador de despawns
	if not target.is_special:
		ducks_despawned += 1
		#print("Pato completó recorrido. Progress: ", ducks_despawned, " / ", level_total_ducks)
		
		# Condición de Victoria / Fin del Juego
		if ducks_despawned >= level_total_ducks:
			is_game_over = true
			print("fin del juego")
