extends Control

# Carga de texturas para los botones (ajusta las rutas a tus archivos .png)
const BTN_ON = preload("res://images/icon_check_on.png")
const BTN_OFF = preload("res://images/icon_check_off.png")

# Referencias a los TextureButton según tu árbol de escena
@onready var music_button: TextureButton = $Frente/Music/Button
@onready var sfx_button: TextureButton = $Frente/SoundEffects/Button

func _ready() -> void:
	# Conectamos las señales por código si no las conectaste en el editor
	if not music_button.is_connected("pressed", _on_music_button_pressed):
		music_button.connect("pressed", _on_music_button_pressed)
		
	if not sfx_button.is_connected("pressed", _on_sfx_button_pressed):
		sfx_button.connect("pressed", _on_sfx_button_pressed)

	# Refrescamos la apariencia según los valores guardados en AudioManager
	_actualizar_boton_musica()
	_actualizar_boton_sfx()

# --- MÚSICA ---
func _on_music_button_pressed() -> void:
	var nuevo_estado = !AudioManager.music_enabled
	AudioManager.set_music_enabled(nuevo_estado)
	_actualizar_boton_musica()

func _actualizar_boton_musica() -> void:
	if AudioManager.music_enabled:
		music_button.texture_normal = BTN_ON
		music_button.texture_pressed = BTN_ON
	else:
		music_button.texture_normal = BTN_OFF
		music_button.texture_pressed = BTN_OFF

# --- EFECTOS DE SONIDO (SFX) ---
func _on_sfx_button_pressed() -> void:
	var nuevo_estado = !AudioManager.sfx_enabled
	AudioManager.set_sfx_enabled(nuevo_estado)
	_actualizar_boton_sfx()

func _actualizar_boton_sfx() -> void:
	if AudioManager.sfx_enabled:
		sfx_button.texture_normal = BTN_ON
		sfx_button.texture_pressed = BTN_ON
	else:
		sfx_button.texture_normal = BTN_OFF
		sfx_button.texture_pressed = BTN_OFF

func _on_boton_options_pressed() -> void:
	AudioManager.play_start()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
