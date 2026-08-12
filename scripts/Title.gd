extends Control

func _on_boton_start_pressed() -> void:
	AudioManager.play_start()
	get_tree().change_scene_to_file("res://scenes/SeleccionNiveles.tscn")

func _on_boton_prizes_pressed() -> void:
	AudioManager.play_start()
	get_tree().change_scene_to_file("res://scenes/Premios.tscn")

func _on_boton_options_pressed() -> void:
	AudioManager.play_start()
	get_tree().change_scene_to_file("res://scenes/Options.tscn")
