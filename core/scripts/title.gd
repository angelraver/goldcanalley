extends Control

const ESCENA_SELECCION_NIVELES = "res://core/scenes/seleccion_niveles.tscn"

func _on_boton_goldcanalley_pressed() -> void:
	_iniciar_juego("goldcanalley")

func _on_boton_whackamole_pressed() -> void:
	_iniciar_juego("whackamole")

func _iniciar_juego(id_juego: String) -> void:
	audio_manager.play_start()
	
	# 1. Establecer el minijuego activo en el manager global
	save_manager.juego_actual_seleccionado = id_juego
	print(save_manager.juego_actual_seleccionado)
	# 2. Cambiar a la escena genérica de selección de niveles
	get_tree().change_scene_to_file(ESCENA_SELECCION_NIVELES)

func _on_boton_prizes_pressed() -> void:
	audio_manager.play_start()
	get_tree().change_scene_to_file("res://core/scenes/premios.tscn")

func _on_boton_options_pressed() -> void:
	audio_manager.play_start()
	get_tree().change_scene_to_file("res://core/scenes/options.tscn")
