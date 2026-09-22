extends Control

const ESCENA_SELECCION_NIVELES = "res://core/scenes/seleccion_niveles.tscn"

func _on_boton_goldcanalley_pressed() -> void:
	_press_feedback(
		$ButtonGoldCanAlley,
		func():
			_iniciar_juego("goldcanalley")
	)

func _on_boton_whackamole_pressed() -> void:
	_press_feedback(
		$ButtonWhackamole,
		func():
			_iniciar_juego("whackamole")
	)
	
func _on_boton_plinko_pressed() -> void:
	_press_feedback(
		$ButtonPlinko,
		func():
			_iniciar_juego("plinko")
	)

func _on_boton_duckshoot_pressed() -> void:
	_press_feedback(
		$ButtonDuckshoot,
		func():
			_iniciar_juego("duckshoot")
	)
	
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

func _on_button_ringtoss_pressed() -> void:
	_press_feedback(
		$ButtonRingToss,
		func():
			_iniciar_juego("ringtoss")
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
