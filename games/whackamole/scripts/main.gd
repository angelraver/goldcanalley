extends Node3D

@export_file("*.json") var ruta_niveles_json: String = "res://games/whackamole/data/niveles.json"
@export_file("*.json") var ruta_valores_json: String = "res://games/whackamole/data/valores.json"
@export var topo_hoyo_scene: PackedScene = preload("res://games/whackamole/scenes/topo_hoyo.tscn")
@export var separacion_grilla: Vector2 = Vector2(2.3, 2.3)
@export var nivel_actual: int = 1

@onready var anim_camara: AnimationPlayer = $AnimationPlayer
@onready var mazo: Node3D = $Mazo
@onready var camara: Camera3D = $CamaraPivote/Camera3D
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var ui_timer: UITimer = $UI/Timer as UITimer
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio: GameAudioBase = $AudioJuego

const ANIM_ESCONDER: StringName = &"esconder"
const TIPOS: Array[String] = ["marron", "rojo", "verde", "azul", "naranja", "dorado"]

var datos_topos: Dictionary = {}
var datos_niveles: Dictionary = {}
var hoyos_activos: Array[Node3D] = []
var sonidos_por_hoyo: Dictionary = {}
var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
var juego_activo: bool = false
var ctrl_resultados: ControladorResultados

func _ready() -> void:
	cargar_valores()
	nivel_actual = save_manager.nivel_actual_seleccionado

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	var hud: Array = [ui_puntaje, ui_level_number, ui_timer]
	ctrl_resultados.configurar(panel_resultados, hud, ui_puntaje, ui_level_number, reiniciar_nivel)
	if ui_timer:
		ui_timer.tiempo_agotado.connect(_on_tiempo_agotado)

	cargar_nivel(nivel_actual)
	
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

func cargar_valores() -> void:
	if not FileAccess.file_exists(ruta_valores_json):
		print("ERROR: No existe el archivo de valores en: ", ruta_valores_json)
		return

	var texto_json = FileAccess.get_file_as_string(ruta_valores_json)
	var datos = JSON.parse_string(texto_json)

	if datos is Dictionary:
		datos_topos.clear()
		for clave in datos.keys():
			var valor = datos[clave]
			var clave_str: String
			# Soporta valores.json con claves compactas (0-5 / "0"-"5") o clásicas ("marron", etc.)
			if clave is String and (clave as String).is_valid_int():
				var idx := int(clave)
				if idx >= 0 and idx < TIPOS.size():
					clave_str = TIPOS[idx]
				else:
					clave_str = clave
			else:
				clave_str = str(clave)
			datos_topos[clave_str] = valor
	else:
		print("ERROR: Formato inválido en valores.json")

func cargar_nivel(numero_nivel: int) -> void:
	ctrl_resultados.reset()

	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No existe el archivo de niveles")
		return

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_niveles_tmp = JSON.parse_string(texto_json)
	if not datos_niveles_tmp or not datos_niveles_tmp.has(str(numero_nivel)):
		print("ERROR: No existe el nivel ", numero_nivel)
		return

	datos_niveles = datos_niveles_tmp
	var config_nivel = datos_niveles[str(numero_nivel)]
	puntaje_maximo_nivel = int(config_nivel.get("meta_puntos", 300))
	puntaje_nivel = 0
	actualizar_ui_puntaje()
	actualizar_ui_level()
	var lista_hoyos: Array = config_nivel.get("hoyos", [])

	for hoyo in hoyos_activos:
		hoyo.queue_free()
	hoyos_activos.clear()
	sonidos_por_hoyo.clear()
	
	for configuracion_hoyo in lista_hoyos:
		var coord: Array = configuracion_hoyo.get("pos", [2, 3])
		var tipo_raw = configuracion_hoyo.get("tipo", configuracion_hoyo.get("tipo_topo", 1))
		var tipo_topo: String = _resolver_tipo(tipo_raw)
		
		var grid_x: int = coord[0]
		var grid_y: int = coord[1]
		
		var hoyo_instancia = topo_hoyo_scene.instantiate()
		add_child(hoyo_instancia)
		
		var pos_x = (grid_x - 2) * separacion_grilla.x
		var pos_z = (grid_y - 3) * separacion_grilla.y
		hoyo_instancia.position = Vector3(pos_x, 0, pos_z)
		
		if datos_topos.has(tipo_topo):
			hoyo_instancia.aplicar_configuracion(datos_topos[tipo_topo])
			sonidos_por_hoyo[hoyo_instancia] = datos_topos[tipo_topo]

		hoyo_instancia.hoyo_cliqueado.connect(_on_hoyo_cliqueado)
		if hoyo_instancia.anim_player:
			hoyo_instancia.anim_player.animation_finished.connect(
				_on_anim_hoyo_finalizada.bind(hoyo_instancia)
			)
		hoyos_activos.append(hoyo_instancia)

	anunciar_nivel(numero_nivel)

func _resolver_tipo(tipo_raw) -> String:
	# Soporta niveles.json compacto (0-5 int / "0"-"5" string) y clásico ("marron", etc.)
	if tipo_raw is int or tipo_raw is float:
		var idx := int(tipo_raw)
		if idx >= 0 and idx < TIPOS.size():
			return TIPOS[idx]
		return TIPOS[1]
	if tipo_raw is String:
		var s: String = tipo_raw
		if s.is_valid_int():
			var idx2 := int(s)
			if idx2 >= 0 and idx2 < TIPOS.size():
				return TIPOS[idx2]
		# Si es letra de un solo dígito (p.ej. "A"), también podría mapearse, pero se asume string clásico
		return s
	return TIPOS[1]

func actualizar_ui_level() -> void:
	ctrl_resultados.actualizar_nivel(nivel_actual)

func actualizar_ui_puntaje() -> void:
	ctrl_resultados.actualizar_puntaje(puntaje_nivel)

func mostrar_panel_resultados() -> void:
	ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

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

	# 1. Golpe de martillo: suena en cada clic
	if audio:
		audio.play_hit()

	if fue_acierto:
		EfectosUI.crear_efecto_puntos(hoyo_node.global_position, puntos)
		puntaje_nivel += puntos
		actualizar_ui_puntaje()
		# 2. Topo golpeado: solo cuando el topo estaba afuera
		if audio:
			audio.play_ouch(_sonido_topo(hoyo_node, "outch"))
	else:
		print("¡Golpe en falso! Sin puntos.")

func _on_anim_hoyo_finalizada(anim_nombre: StringName, hoyo_node: Node3D) -> void:
	# La risa suena cuando el topo termina de esconderse sin haber sido golpeado
	if anim_nombre != ANIM_ESCONDER:
		return
	if not juego_activo:
		return
	if audio:
		audio.play_risa(_sonido_topo(hoyo_node, "risa"))

func _sonido_topo(hoyo_node: Node3D, clave: String) -> String:
	var config: Dictionary = sonidos_por_hoyo.get(hoyo_node, {})
	return str(config.get(clave, ""))

func _on_tiempo_agotado() -> void:
	juego_activo = false
	mostrar_panel_resultados()

func reiniciar_nivel() -> void:
	cargar_nivel(nivel_actual)
	iniciar_partida()

func anunciar_nivel(numero_nivel: int) -> void:
	if not ui_level_title:
		return
	ui_level_title.text = game_manager.obtener_titulo_nivel(str(numero_nivel))
	ui_level_title.modulate.a = 1.0
	ui_level_title.visible = true
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): ui_level_title.visible = false)
