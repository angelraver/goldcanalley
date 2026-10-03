extends GameAudioBase

var _gears_en_bucle: bool = false

func _ready() -> void:
	super._ready()
	var jugadores: Array = grupos_sonido.get("Gears", [])
	for jugador in jugadores:
		var reproductor := jugador as AudioStreamPlayer
		if reproductor and not reproductor.finished.is_connected(_on_gears_finished):
			reproductor.finished.connect(_on_gears_finished.bind(reproductor))

func play_rifle() -> void:
	play("Rifle")

func play_duck() -> void:
	play_aleatorio("Duck")

func play_shotmiss1() -> void:
	_play_por_sufijo("ShotMiss", "1")

func play_shotmiss2() -> void:
	_play_por_sufijo("ShotMiss", "2")

func play_bomb() -> void:
	play("Bomb")

func play_rayo() -> void:
	play("Rayo")

func play_tictac() -> void:
	play("Tictac")

func stop_tictac() -> void:
	for jugador in grupos_sonido.get("Tictac", []):
		(jugador as AudioStreamPlayer).stop()

# Selección de variante por sufijo numérico (ver games/whackamole/scripts/audio_manager.gd: _play_variante).
# Necesario porque ShotMiss1 y ShotMiss2 comparten el grupo "ShotMiss".
func _play_por_sufijo(prefijo: String, sufijo: String) -> void:
	if not sfx_habilitado():
		return
	var jugadores: Array = grupos_sonido.get(prefijo, [])
	for jugador in jugadores:
		if String(jugador.name).ends_with(sufijo):
			jugador.play()
			return
	if not jugadores.is_empty():
		jugadores[0].play()

func start_gears() -> void:
	if not sfx_habilitado():
		return
	var jugadores: Array = grupos_sonido.get("Gears", [])
	if jugadores.is_empty():
		return
	var reproductor := jugadores[0] as AudioStreamPlayer
	if reproductor.playing:
		_gears_en_bucle = true
		return
	_gears_en_bucle = true
	reproductor.play()

func stop_gears() -> void:
	var jugadores: Array = grupos_sonido.get("Gears", [])
	var estaba_sonando := false
	for jugador in jugadores:
		if (jugador as AudioStreamPlayer).playing:
			estaba_sonando = true
			break
	_gears_en_bucle = false
	for jugador in jugadores:
		(jugador as AudioStreamPlayer).stream_paused = false
		(jugador as AudioStreamPlayer).stop()
	if estaba_sonando:
		play("GearsStop")

# Pausa del freeze (snow): silencia el bucle sin el remate GearsStop y sin
# tocar _gears_en_bucle, para retomar donde quedó al descongelar.
func pause_gears() -> void:
	for jugador in grupos_sonido.get("Gears", []):
		var reproductor := jugador as AudioStreamPlayer
		if reproductor and reproductor.playing:
			reproductor.stream_paused = true

func resume_gears() -> void:
	if not _gears_en_bucle:
		return
	for jugador in grupos_sonido.get("Gears", []):
		var reproductor := jugador as AudioStreamPlayer
		if reproductor and reproductor.stream_paused:
			reproductor.stream_paused = false

func _on_gears_finished(reproductor: AudioStreamPlayer) -> void:
	if _gears_en_bucle and sfx_habilitado():
		reproductor.play()
