extends Control

func _on_boton_start_pressed() -> void:
	audio_manager.play_start()
	get_tree().change_scene_to_file("res://scenes/seleccion_niveles.tscn")

func _on_boton_prizes_pressed() -> void:
	audio_manager.play_start()
	get_tree().change_scene_to_file("res://scenes/premios.tscn")

func _on_boton_options_pressed() -> void:
	audio_manager.play_start()
	get_tree().change_scene_to_file("res://scenes/options.tscn")
