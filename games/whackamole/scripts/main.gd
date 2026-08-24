extends Node3D

@export var topo_hoyo_scene: PackedScene = preload("res://games/whackamole/scenes/topo_hoyo.tscn")
@export var separacion_grilla: Vector2 = Vector2(2.3, 2.3)
@export var escena_puntos_flotantes: PackedScene = preload("res://core/scenes/puntos_flotantes.tscn")
@export var nivel_actual: int = 1

@onready var anim_camara: AnimationPlayer = $AnimationPlayer
@onready var mazo: Node3D = $Mazo
@onready var camara: Camera3D = $CamaraPivote/Camera3D
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_timer: UITimer = $UI/Timer as UITimer
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego

var datos_topos: Dictionary = {}
var datos_niveles: Dictionary = {}
var hoyos_activos: Array[Node3D] = []
var puntaje_nivel: int = 0
var juego_activo: bool = false

func _ready() -> void:
	nivel_actual = save_manager.nivel_actual_seleccionado

	if ui_timer:
		ui_timer.tiempo_agotado.connect(_on_tiempo_agotado)
	if panel_resultados:
		panel_resultados.reiniciar_solicitado.connect(reiniciar_nivel)

	cargar_archivos_json()
	cargar_nivel(str(nivel_actual))
	
	anim_camara.play("inicio_camara")
	await anim_camara.animation_finished
	
	iniciar_partida()

func iniciar_partida() -> void:
	juego_activo = true
	var config_nivel = datos_niveles.get(str(nivel_actual), {})
	var tiempo_limite = float(config_nivel.get("tiempo_limite", 30))
	
	if ui_timer:
		ui_timer.visible = true
		ui_timer.iniciar(tiempo_limite)
		
	iniciar_spawner()

func cargar_archivos_json() -> void:
	if FileAccess.file_exists("res://games/whackamole/data/valores.json"):
		var raw = FileAccess.get_file_as_string("res://games/whackamole/data/valores.json")
		datos_topos = JSON.parse_string(raw)
		
	if FileAccess.file_exists("res://games/whackamole/data/niveles.json"):
		var raw = FileAccess.get_file_as_string("res://games/whackamole/data/niveles.json")
		datos_niveles = JSON.parse_string(raw)

func cargar_nivel(id_nivel: String) -> void:
	if not datos_niveles.has(id_nivel):
		return
		
	var config_nivel = datos_niveles[id_nivel]
	var lista_hoyos: Array = config_nivel.get("hoyos", [])
	actualizar_ui_level()

	for hoyo in hoyos_activos:
		hoyo.queue_free()
	hoyos_activos.clear()
	
	for configuracion_hoyo in lista_hoyos:
		var coord: Array = configuracion_hoyo.get("pos", [2, 3])
		var tipo_topo: String = configuracion_hoyo.get("tipo_topo", "topo_rojo")
		
		var grid_x: int = coord[0]
		var grid_y: int = coord[1]
		
		var hoyo_instancia = topo_hoyo_scene.instantiate()
		add_child(hoyo_instancia)
		
		var pos_x = (grid_x - 2) * separacion_grilla.x
		var pos_z = (grid_y - 3) * separacion_grilla.y
		hoyo_instancia.position = Vector3(pos_x, 0, pos_z)
		
		if datos_topos.has(tipo_topo):
			hoyo_instancia.aplicar_configuracion(datos_topos[tipo_topo])
		
		hoyo_instancia.hoyo_cliqueado.connect(_on_hoyo_cliqueado)
		hoyo_instancia.audio = audio_juego
		hoyos_activos.append(hoyo_instancia)

func actualizar_ui_level() -> void:
	if ui_level_number:
		ui_level_number.establecer_nivel(nivel_actual)

func iniciar_spawner() -> void:
	while juego_activo:
		await get_tree().create_timer(randf_range(0.8, 1.8)).timeout
		
		if not juego_activo or hoyos_activos.size() == 0:
			continue
			
		var hoyo_elegido = hoyos_activos.pick_random()
		if hoyo_elegido.estado_actual == hoyo_elegido.Estado.ESCONDIDO:
			hoyo_elegido.emerger()

func _on_hoyo_cliqueado(hoyo_node: Node3D, fue_acierto: bool, puntos: int) -> void:
	if not juego_activo:
		return

	if mazo != null and hoyo_node != null:
		mazo.golpear_en(hoyo_node.global_position, camara.global_position)
		
	if fue_acierto:
		EfectosUI.crear_efecto_puntos(hoyo_node.global_position, puntos)
		puntaje_nivel += puntos
		if ui_puntaje:
			ui_puntaje.establecer_puntaje(puntaje_nivel)
	else:
		print("¡Golpe en falso! Sin puntos.")

func _on_tiempo_agotado() -> void:
	juego_activo = false
	
	if ui_puntaje: ui_puntaje.visible = false
	if ui_level_number: ui_level_number.visible = false
	if ui_timer: ui_timer.visible = false

	var config_nivel = datos_niveles.get(str(nivel_actual), {})
	var meta_puntos: int = int(config_nivel.get("meta_puntos", 300))

	if panel_resultados:
		panel_resultados.mostrar(nivel_actual, puntaje_nivel, meta_puntos)

func reiniciar_nivel() -> void:
	puntaje_nivel = 0
	if ui_puntaje:
		ui_puntaje.visible = true
		ui_puntaje.establecer_puntaje(0)
	if ui_level_number:
		ui_level_number.visible = true
	
	cargar_nivel(str(nivel_actual))
	iniciar_partida()
