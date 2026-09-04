extends Node

# --- NODOS EXISTENTES DE EFECTOS ---
@onready var start: AudioStreamPlayer = $Start
@onready var welldone: AudioStreamPlayer = $Welldone
@onready var prize: AudioStreamPlayer = $Prize
@onready var ok1: AudioStreamPlayer = $Ok1

# --- CONTROL DE ESTADO GLOBAL ---
var music_enabled: bool = true
var sfx_enabled: bool = true

# Player para la música de fondo
var bgm_player: AudioStreamPlayer

func _ready() -> void:
	# 1. Inicializamos el reproductor de música de fondo
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	
	# 2. Leemos el estado persistente guardado en save_manager
	music_enabled = save_manager.obtener_opcion_audio("music_enabled", true)
	sfx_enabled = save_manager.obtener_opcion_audio("sfx_enabled", true)


# ==========================================
# GESTIÓN DE MÚSICA DE FONDO (BGM)
# ==========================================

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	save_manager.guardar_opcion_audio("music_enabled", enabled) # Guarda en el JSON
	
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
	save_manager.guardar_opcion_audio("sfx_enabled", enabled) # Guarda en el JSON

func play_start() -> void:
	if sfx_enabled and start:
		start.play()

func play_welldone() -> void:
	if sfx_enabled and welldone:
		welldone.play()

func play_prize() -> void:
	if sfx_enabled and prize:
		prize.play()

func play_ok1() -> void:
	if sfx_enabled and ok1:
		ok1.play()
