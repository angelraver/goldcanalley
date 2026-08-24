extends Node3D

# Señal para avisar a whack_a_mole.gd: (nodo, si acertó al topo, puntos)
signal hoyo_cliqueado(hoyo_node: Node3D, fue_acierto: bool, puntos: int)

enum Estado { ESCONDIDO, ASOMANDOSE, AFUERA, GOLPEADO }

@onready var area_topo: Area3D = $TopoArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var mesh_topo: MeshInstance3D = $TopoArea/MeshTopo.get_child(0) as MeshInstance3D

const PATH_TEXTURES: String = "res://games/whackamole/assets/images/topos/"
var estado_actual: Estado = Estado.ESCONDIDO
var puntos_actuales: int = 0
var rango_expuesto: Array = [1.0, 2.0]
var audio: GameAudioBase

func _ready() -> void:
	area_topo.input_event.connect(_on_topo_input_event)

func aplicar_configuracion(datos_topo: Dictionary) -> void:
	puntos_actuales = datos_topo.get("pts", 50)
	rango_expuesto = datos_topo.get("rango_expuesto", [1.0, 2.0])
	
	# Rotación para que mire a la cámara
	mesh_topo.rotation_degrees.y = 180.0

	var path_tex = PATH_TEXTURES + datos_topo.get("textura_path", "")
	if path_tex != "" and ResourceLoader.exists(path_tex):
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = load(path_tex)

		# Aplicar el material a CADA superficie del modelo
		for i in range(mesh_topo.get_surface_override_material_count()):
			mesh_topo.set_surface_override_material(i, mat)

func emerger() -> void:
	if estado_actual != Estado.ESCONDIDO:
		return
		
	estado_actual = Estado.ASOMANDOSE
	anim_player.play("asomar")
	await anim_player.animation_finished
	
	if estado_actual == Estado.ASOMANDOSE:
		estado_actual = Estado.AFUERA
		var t_expuesto = randf_range(rango_expuesto[0], rango_expuesto[1])
		await get_tree().create_timer(t_expuesto).timeout
		
		if estado_actual == Estado.AFUERA:
			esconder_topo()

func esconder_topo() -> void:
	if estado_actual == Estado.GOLPEADO or estado_actual == Estado.ESCONDIDO:
		return
		
	anim_player.play("esconder")
	await anim_player.animation_finished
	estado_actual = Estado.ESCONDIDO

func recibir_golpe() -> void:
	if estado_actual == Estado.AFUERA or estado_actual == Estado.ASOMANDOSE:
		estado_actual = Estado.GOLPEADO
		hoyo_cliqueado.emit(self, true, puntos_actuales)
		if audio:
			audio.play_hit()
		anim_player.play("golpeado")
		await anim_player.animation_finished
		estado_actual = Estado.ESCONDIDO
	elif estado_actual == Estado.ESCONDIDO:
		# Golpe en falso sobre el hoyo vacío
		hoyo_cliqueado.emit(self, false, 0)
		if audio:
			audio.play_ouch()

func _on_topo_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		recibir_golpe()
