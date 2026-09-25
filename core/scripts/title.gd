extends Control

const ESCENA_SELECCION_NIVELES = "res://core/scenes/seleccion_niveles.tscn"

## Orden preferido en el carrusel. Los juegos nuevos que aparezcan en
## games.json y no estén aquí se agregan al final automáticamente.
const ORDEN_JUEGOS: Array[String] = [
	"goldcanalley",
	"whackamole",
	"plinko",
	"ringtoss",
	"duckshoot",
]

const NOMBRES_JUEGOS: Dictionary = {
	"goldcanalley": "Gold Can Alley",
	"whackamole": "Whack-a-Mole",
	"plinko": "Plinko",
	"ringtoss": "Ring Toss",
	"duckshoot": "Duck Shoot",
}

@onready var carousel: CarouselMenu = $CarouselMenu


func _ready() -> void:
	var games_data := _construir_datos_carrusel()
	carousel.setup_carousel(games_data)
	carousel.item_selected.connect(_on_game_selected)


func _construir_datos_carrusel() -> Array[Dictionary]:
	var datos: Array[Dictionary] = []
	var vistos := {}

	var ids_ordenados: Array[String] = []
	for id in ORDEN_JUEGOS:
		if game_manager.configuracion_juegos.has(id):
			ids_ordenados.append(id)
			vistos[id] = true
	# A prueba de futuro: juegos agregados a games.json aparecen solos.
	for id in game_manager.configuracion_juegos.keys():
		if not vistos.has(id):
			ids_ordenados.append(id)

	for id in ids_ordenados:
		var config: Dictionary = game_manager.configuracion_juegos.get(id, {})
		var ruta_logo := str(config.get("textura_logo", ""))
		var tex: Texture2D = null
		if ruta_logo != "" and ResourceLoader.exists(ruta_logo):
			tex = load(ruta_logo) as Texture2D
		if tex == null:
			push_warning("Title: sin logo para juego '%s' (%s)" % [id, ruta_logo])
			continue
		datos.append({
			"id": id,
			"title": NOMBRES_JUEGOS.get(id, id.capitalize()),
			"texture": tex,
		})
	return datos


func _on_game_selected(game_id: String) -> void:
	_iniciar_juego(game_id)


func _iniciar_juego(id_juego: String) -> void:
	audio_manager.play_start()

	# 1. Establecer el minijuego activo en el manager global
	save_manager.juego_actual_seleccionado = id_juego
	print(save_manager.juego_actual_seleccionado)
	# 2. Cambiar a la escena genérica de selección de niveles
	get_tree().change_scene_to_file(ESCENA_SELECCION_NIVELES)


func _on_boton_prizes_pressed() -> void:
	_press_feedback(
		$Prizes,
		func():
			audio_manager.play_start()
			get_tree().change_scene_to_file("res://core/scenes/premios.tscn")
	)


func _on_boton_options_pressed() -> void:
	_press_feedback(
		$Options,
		func():
			audio_manager.play_start()
			get_tree().change_scene_to_file("res://core/scenes/options.tscn")
	)


func _press_feedback(button: Control, callback: Callable) -> void:
	Input.vibrate_handheld(25)

	var tween := create_tween()

	tween.tween_property(
		button,
		"scale",
		Vector2(button.scale.x - 0.05, button.scale.y - 0.05),
		0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_callback(callback)
