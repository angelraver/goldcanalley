extends Node

# --- NODOS EXISTENTES DE EFECTOS ---
@onready var start: AudioStreamPlayer = $Start
@onready var shot: AudioStreamPlayer = $Shot
@onready var welldone: AudioStreamPlayer = $Welldone

var sonidos_lata: Array = []

# --- CONTROL DE ESTADO GLOBAL ---
var music_enabled: bool = true
var sfx_enabled: bool = true

# Player para la música de fondo
var bgm_player: AudioStreamPlayer

func _ready() -> void:
	# 1. Agrupamos los sonidos de lata
	for hijo in get_children():
		if hijo.name.begins_with("Lata"):
			sonidos_lata.append(hijo)
			
	# 2. Inicializamos el reproductor de música de fondo
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	
	# 3. Leemos el estado persistente guardado en SaveManager
	music_enabled = SaveManager.obtener_opcion_audio("music_enabled", true)
	sfx_enabled = SaveManager.obtener_opcion_audio("sfx_enabled", true)


# ==========================================
# GESTIÓN DE MÚSICA DE FONDO (BGM)
# ==========================================

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	SaveManager.guardar_opcion_audio("music_enabled", enabled) # Guarda en el JSON
	
	if bgm_player.stream:
		bgm_player.stream_paused = !enabled
		if enabled and not bgm_player.playing:
			bgm_player.play()

func play_bgm(stream: AudioStream) -> void:
	if stream == null:
		return
	
	bgm_player.stream = stream
	if music_enabled:
		bgm_player.play()


# ==========================================
# GESTIÓN DE EFECTOS DE SONIDO (SFX)
# ==========================================

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	SaveManager.guardar_opcion_audio("sfx_enabled", enabled) # Guarda en el JSON

func play_start() -> void:
	if sfx_enabled and start:
		start.play()

func play_shot() -> void:
	if sfx_enabled and shot:
		shot.play()

func play_welldone() -> void:
	if sfx_enabled and welldone:
		welldone.play()

func play_lata() -> void:
	if sfx_enabled and not sonidos_lata.is_empty():
		sonidos_lata.pick_random().play()
