extends Node3D

@export var duck_a_scene: PackedScene = preload("res://games/duckshoot/scenes/duck.tscn")
@export var bomb_scene: PackedScene   = preload("res://games/duckshoot/scenes/bomb.tscn")

@export_file("*.json") var level_json_path: String = "res://games/duckshoot/data/niveles.json"
@export_file("*.json") var valores_json_path: String = "res://games/duckshoot/data/valores.json"

@export_group("Decorado")
@export var wave_row_scene: PackedScene = preload("res://games/duckshoot/scenes/wave_row.tscn")
@export var wave_1_mesh: PackedScene    = preload("res://games/duckshoot/scenes/wave1.tscn")
@export var wave_2_mesh: PackedScene    = preload("res://games/duckshoot/scenes/wave2.tscn")

@export_group("Calibración Fija de Carriles (Y / Z)")
# Definición manual [Y, Z] para cada uno de los 4 carriles
@export var lane_positions: Array[Vector2] = [
	Vector2(0.03, 1.19), # Carril 1 (Abajo / Lane_1) -> [Y, Z]
	Vector2(0.61, 0.82), # Carril 2                -> [Y, Z]
	Vector2(1.2, 0.53), # Carril 3                -> [Y, Z]
	Vector2(1.8, 0.15)  # Carril 4 (Arriba / Lane_4) -> [Y, Z]
]

# Offset de la Ola [Y, Z] relativo a la posición de su respectivo carril
@export var wave_lane_offsets: Array[Vector2] = [
	Vector2(-0.2, 0.05), # Offset Ola Carril 1
	Vector2(-0.2, 0.05), # Offset Ola Carril 2
	Vector2(-0.2, 0.05), # Offset Ola Carril 3
	Vector2(-0.2, 0.05)  # Offset Ola Carril 4
]

const DISTANCIA_SPAWN: float = 0.25 # Distancia en unidades que debe avanzar el último pato para permitir otro spawn

@export_group("Ancho de Carril (X)")
@export var x_left_spawn: float = -1.5   # Punto de spawn izquierda / límite de despawn
@export var x_right_spawn: float = 1.5   # Punto de spawn derecha / límite de despawn

@export_group("Dimensiones de Escalón (Y / Z)")
@export var base_y: float = 0.0
@export var step_y: float = 0.55
@export var base_z: float = 1.1
@export var step_z: float = 0.3

@export_group("Escala de Velocidad (1 a 5)")
@export var speed_multiplier: float = 0.5

@export_group("Prefabs")
@export var wave_z_offset: float = 0.1 # Distancia hacia adelante respecto al pato para tapar su base

@onready var rifle: Rifle = $rifle
@onready var audio_juego: GameAudioBase = $AudioJuego
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var ui_level_title: Label = $UI/LevelTitle

# Definición de colores principales
const COLOR_AMARILLO : Color = Color("ffd700")
const COLOR_ROJO     : Color = Color("e63946")
const COLOR_AMBAR    : Color = Color("ff9f1c")
const COLOR_BLANCO   : Color = Color("f8f9fa")

var colores_map: Dictionary = {
	"amarillo": COLOR_AMARILLO,
	"rojo": COLOR_ROJO,
	"ambar": COLOR_AMBAR,
	"blanco": COLOR_BLANCO,
	"negro": Color("1a1a1a")
}

var valores_data: Dictionary = {}

var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
var ctrl_resultados: ControladorResultados
var nivel_actual: int = 1

var level_total_ducks: int = 0
var ducks_spawned: int = 0
var ducks_despawned: int = 0
var is_game_over: bool = false

# Array para administrar el estado de cada carril
var lanes_data: Array = []

func _ready() -> void:
	# Inyección de audio
	if audio_juego and rifle:
		rifle.audio = audio_juego

	nivel_actual = save_manager.nivel_actual_seleccionado

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	var hud: Array = [ui_puntaje, ui_level_number]
	ctrl_resultados.configurar(panel_resultados, hud, ui_puntaje, ui_level_number, reiniciar_nivel)
	
	_load_valores_config()
	load_level(str(nivel_actual))

func _load_valores_config() -> void:
	if not FileAccess.file_exists(valores_json_path):
		printerr("No se encontró el archivo valores.json en: ", valores_json_path)
		return
		
	var file = FileAccess.open(valores_json_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	
	if parsed is Dictionary:
		valores_data = parsed

func load_level(level_id: String) -> void:
	if not FileAccess.file_exists(level_json_path):
		return
		
	var file = FileAccess.open(level_json_path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not json_data or not json_data.has(level_id):
		return
		
	var level_config = json_data[level_id]
	if level_id.is_valid_int():
		nivel_actual = int(level_id)
	# Reset panel + HUD antes de limpiar escena (restaura visibilidad)
	if ctrl_resultados:
		ctrl_resultados.reset()
	# Limpiar targets y olas previas
	for child in get_children():
		if child is Target or child is WaveRow:
			child.queue_free()
	level_total_ducks = int(level_config.get("total", 50))
	ducks_spawned = 0
	ducks_despawned = 0
	puntaje_nivel = 0
	# Meta para ribbons: prioridad max_pts (schema duckshoot), fallback puntaje_maximo/meta_puntos
	puntaje_maximo_nivel = int(level_config.get("max_pts", level_config.get("puntaje_maximo", level_config.get("meta_puntos", 0))))
	if puntaje_maximo_nivel <= 0:
		# Fallback: máximo teórico = pts más alto * total
		var max_pts_por_item: int = 0
		for k in valores_data.keys():
			var v = valores_data[k]
			if v is Dictionary:
				max_pts_por_item = maxi(max_pts_por_item, int(v.get("puntos", 0)))
		puntaje_maximo_nivel = max_pts_por_item * level_total_ducks
	actualizar_ui_puntaje()
	actualizar_ui_level()
	is_game_over = false
	if audio_juego:
		audio_juego.stop_gears()
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
			
			# Lectura de la calibración individual [Y, Z] para este carril
			var pos_calibrada = lane_positions[lane_index] if lane_index < lane_positions.size() else Vector2.ZERO
			var lane_y = pos_calibrada.x
			var lane_z = pos_calibrada.y
			
			# Instanciar fila de olas con calibración independiente por carril
			var wave_type = l_info.get("wave_type", "none")
			if wave_type != "none":
				var wave_row_instance: WaveRow = wave_row_scene.instantiate()
				var chosen_wave_mesh = wave_2_mesh if wave_type == "wave2" else wave_1_mesh
				wave_row_instance.set_wave_mesh(chosen_wave_mesh)
				
				# Aplicar offset específico de la ola en este carril
				var wave_offset = wave_lane_offsets[lane_index] if lane_index < wave_lane_offsets.size() else Vector2(-0.1, 0.1)
				var wave_y = lane_y + wave_offset.x
				var wave_z = lane_z + wave_offset.y
				
				wave_row_instance.position = Vector3(0, wave_y, wave_z)
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
				"last_spawned_target": null
			})
	anunciar_nivel(nivel_actual)

func _process(_delta: float) -> void:
	if is_game_over:
		return
	if ctrl_resultados and ctrl_resultados.esta_mostrado():
		return
	for lane in lanes_data:
		_check_lane_spawn(lane)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		get_tree().paused = false

func _check_lane_spawn(lane: Dictionary) -> void:
	if ducks_spawned >= level_total_ducks:
		return
		
	var can_spawn = false
	var last_target = lane["last_spawned_target"]
	
	if not is_instance_valid(last_target):
		can_spawn = true
	else:
		var start_x = x_left_spawn if lane["dir"] == 1 else x_right_spawn
		var distance_from_spawn = abs(last_target.global_position.x - start_x)
		
		if distance_from_spawn >= DISTANCIA_SPAWN and last_target.current_state != Target.State.ENTERING:
			can_spawn = true
			
	if can_spawn:
		_spawn_next_target(lane)

func _spawn_next_target(lane: Dictionary) -> void:
	var spawn_special = false
	var especial_list = lane["especial"] as Array
	var patos_list = lane["patos"] as Array
	
	if not especial_list.is_empty():
		var rate = lane["especial_rate"]
		if randi_range(1, rate) == 1:
			spawn_special = true
			
	if not spawn_special and ducks_spawned >= level_total_ducks:
		return

	# Elegir clave del ítem (ej: "A", "B", "C", "D" o "bomb", "ray", "ice")
	var item_key: String = ""
	if spawn_special and not especial_list.is_empty():
		item_key = especial_list.pick_random()
	elif not patos_list.is_empty():
		item_key = patos_list.pick_random()
	else:
		item_key = "A"

	# Extraer configuración de valores.json
	var item_config: Dictionary = valores_data.get(item_key, {})
	var model_name: String = item_config.get("model", "duck")
	var color_name: String = item_config.get("color", "amarillo")
	var puntos_valor: int  = int(item_config.get("puntos", 0))

	# Resolver escena según la propiedad 'model'
	var target_scene: PackedScene = duck_a_scene
	if model_name == "bomb":
		target_scene = bomb_scene
	else:
		var scene_path = "res://games/duckshoot/scenes/" + model_name + ".tscn"
		if ResourceLoader.exists(scene_path):
			target_scene = load(scene_path)

	var instance: Target = target_scene.instantiate() as Target
	if not instance:
		return

	var is_duck_item = not spawn_special
	if is_duck_item:
		ducks_spawned += 1
		if ducks_spawned == 1 and audio_juego:
			audio_juego.start_gears()

	if audio_juego:
		instance.audio = audio_juego

	# Guardar valor de puntos e información de color en la instancia
	var color_albedo: Color = colores_map.get(color_name, COLOR_AMARILLO)
	if instance.has_method("set_target_data"):
		instance.set_target_data(puntos_valor, color_albedo)
	else:
		instance.set("puntos", puntos_valor)

	var start_x = x_left_spawn if lane["dir"] == 1 else x_right_spawn
	var target_x_limit = x_right_spawn if lane["dir"] == 1 else x_left_spawn

	add_child(instance)
	instance.global_position = Vector3(start_x, lane["pos_y"], lane["pos_z"])
	instance.setup(lane["speed"], lane["dir"], target_x_limit, item_key, spawn_special)
	
	instance.target_despawned.connect(_on_target_despawned)
	instance.target_hit.connect(_on_target_hit)
	lane["last_spawned_target"] = instance

func _on_target_hit(target: Target) -> void:
	if is_game_over:
		return
	if ctrl_resultados and ctrl_resultados.esta_mostrado():
		return
	var puntos: int = target.puntos
	if puntos <= 0:
		return
	puntaje_nivel += puntos
	actualizar_ui_puntaje()
	EfectosUI.crear_efecto_puntos(target.global_position, puntos)

func actualizar_ui_puntaje() -> void:
	if ctrl_resultados:
		ctrl_resultados.actualizar_puntaje(puntaje_nivel)
	elif ui_puntaje:
		ui_puntaje.establecer_puntaje(puntaje_nivel)

func actualizar_ui_level() -> void:
	if ctrl_resultados:
		ctrl_resultados.actualizar_nivel(nivel_actual)
	elif ui_level_number:
		ui_level_number.establecer_nivel(nivel_actual)

func anunciar_nivel(n: int) -> void:
	if not ui_level_title:
		return
	ui_level_title.text = game_manager.obtener_titulo_nivel(str(n), "duckshoot")
	ui_level_title.modulate.a = 1.0
	ui_level_title.visible = true
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): ui_level_title.visible = false)

func mostrar_panel_resultados() -> void:
	if ctrl_resultados and ctrl_resultados.esta_mostrado():
		return
	if is_game_over and ctrl_resultados and ctrl_resultados.esta_mostrado():
		return
	is_game_over = true
	if audio_juego:
		audio_juego.stop_gears()
	ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

func reiniciar_nivel() -> void:
	load_level(str(nivel_actual))

func _on_target_despawned(target: Target) -> void:
	if not target.is_special:
		ducks_despawned += 1
		if ducks_despawned >= level_total_ducks:
			if not is_game_over and not (ctrl_resultados and ctrl_resultados.esta_mostrado()):
				mostrar_panel_resultados()
