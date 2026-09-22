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
		(jugador as AudioStreamPlayer).stop()
	if estaba_sonando:
		play("GearsStop")

func _on_gears_finished(reproductor: AudioStreamPlayer) -> void:
	if _gears_en_bucle and sfx_habilitado():
		reproductor.play()
