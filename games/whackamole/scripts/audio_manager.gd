extends GameAudioBase

func play_hit() -> void:
	play_aleatorio("Hit")

func play_ouch(variante: String = "") -> void:
	_play_variante("Ouch", variante)

func play_risa(variante: String = "") -> void:
	_play_variante("Risa", variante)

func _play_variante(prefijo: String, variante: String) -> void:
	if not sfx_habilitado():
		return
	var jugadores: Array = grupos_sonido.get(prefijo, [])
	if jugadores.is_empty():
		return

	var sufijo_buscado := _sufijo_numerico(variante)
	if sufijo_buscado.is_empty():
		jugadores.pick_random().play()
		return

	for jugador in jugadores:
		if _sufijo_numerico(String(jugador.name)) == sufijo_buscado:
			jugador.play()
			return

	jugadores.pick_random().play()

# Devuelve los dígitos al final de un texto ("outch4" -> "4", "" si no tiene)
func _sufijo_numerico(texto: String) -> String:
	var sufijo := ""
	for i in range(texto.length() - 1, -1, -1):
		var caracter := texto[i]
		if caracter >= "0" and caracter <= "9":
			sufijo = caracter + sufijo
		else:
			break
	return sufijo
