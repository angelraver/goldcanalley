extends Node3D

@export var topo_hoyo_scene: PackedScene = preload("res://games/whackamole/scenes/topo_hoyo.tscn")

# Separación entre celdas (X: horizontal, Y: vertical a lo largo de Z)
@export var separacion_grilla: Vector2 = Vector2(2.3, 2.3)
@onready var anim_camara: AnimationPlayer = $AnimationPlayer

@onready var mazo: Node3D = $Mazo
@onready var camara: Camera3D = $CamaraPivote/Camera3D

var datos_topos: Dictionary = {}
var datos_niveles: Dictionary = {}

var hoyos_activos: Array[Node3D] = []
var puntaje_total: int = 0

func _ready() -> void:
	cargar_archivos_json()
	cargar_nivel("1")
	anim_camara.play("inicio_camara")
	await anim_camara.animation_finished
	
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
		
		# Centrado para Grilla 3x5
		# Columnas (1 a 3): centro en 2
		# Filas (1 a 5): centro en 3
		var pos_x = (grid_x - 2) * separacion_grilla.x
		var pos_z = (grid_y - 3) * separacion_grilla.y
		hoyo_instancia.position = Vector3(pos_x, 0, pos_z)
		
		if datos_topos.has(tipo_topo):
			hoyo_instancia.aplicar_configuracion(datos_topos[tipo_topo])
		
		# Escuchar clics directos sobre el hoyo (con o sin topo)
		hoyo_instancia.hoyo_cliqueado.connect(_on_hoyo_cliqueado)
		hoyos_activos.append(hoyo_instancia)
	
	iniciar_spawner()

func iniciar_spawner() -> void:
	while true:
		await get_tree().create_timer(randf_range(0.8, 1.8)).timeout
		
		if hoyos_activos.size() == 0:
			continue
			
		var hoyo_elegido = hoyos_activos.pick_random()
		if hoyo_elegido.estado_actual == hoyo_elegido.Estado.ESCONDIDO:
			hoyo_elegido.emerger()

func _on_hoyo_cliqueado(hoyo_node: Node3D, fue_acierto: bool, puntos: int) -> void:
	# El mazo siempre viaja a la posición del hoyo cliqueado
	if mazo != null and hoyo_node != null:
		mazo.golpear_en(hoyo_node.global_position, camara.global_position)
		
	if fue_acierto:
		puntaje_total += puntos
		print("¡Golpe certero! Puntos:", puntos, " | Total:", puntaje_total)
	else:
		print("¡Golpe en falso! Sin puntos.")
