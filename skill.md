# Goldcanalley — Skill Guide para Agentes

> **Para agentes (Muse, Codex, LLM).** Este README es la skill canónica del proyecto.
> Si tu tarea es **crear un nuevo minijuego, reutilizar HUD/pantallas, añadir niveles o tocar progresión/audio/localización**, lee este archivo primero y sigue la receta de la sección 4. No modifiques `core/` salvo que la tarea lo exija explícitamente.

Colección de minijuegos 3D estilo feria/carnival construida con **Godot 4.7 — Mobile renderer, portrait 720×1280, Jolt Physics**. Export: **Web + iOS**. Hub central + módulos de juego plug-in bajo `games/`.

---

## 1) Stack y convenciones rápidas

| Item | Valor |
|---|---|
| Engine | Godot 4.7 (`config/features=[4.7, Mobile]` en `project.godot:14`) |
| Renderer | `mobile` / `gl_compatibility` (`project.godot:40-41`) |
| Física 3D | Jolt Physics (`project.godot:35`) |
| Viewport | 720×1280, `canvas_items/expand` (`project.godot:27-31`) |
| Main scene | `core/scenes/title.tscn` (uid `cokb2wqhdfvfb` en `project.godot:14`) |
| Idiomas | `es` (fallback) / `en` / `pt` |
| Persistencia | `user://progreso.json` vía `save_manager.gd` |
| Export | `export_presets.cfg` (Web + iOS) |

Convenciones: código y comentarios en **español**, `snake_case` para funciones/variables, UIDs de Godot para `project.godot` y `*.tscn`.

---

## 2) Arquitectura — mapa mental

```
┌────────────────────────────── core/ ──────────────────────────────┐
│  title (hub) ──► seleccion_niveles (genérica, paginada 9/pág) ──► [main.tscn del juego] │
│       │                    ▲                                 │              │
│       ├──► premios         │                          PanelResultados       │
│       └──► options    core/data/games.json            EfectosUI            │
│                  (registry)  ▲  ▲  ▲                                    │
│                              │  │  └─► textos.json + prefijo              │
│  Autoloads: save_manager · audio_manager · game_manager · EfectosUI       │
│  HUD compartido: UIPuntaje · UITimer · UILevelNumber · PuntosFlotantes    │
│  Shaders: desenfoque / chromatic_aberration / crt_effect / logo_dissolver │
└──────────────────────────────────────────────────────────────────────────┘
              │              │               │              │
     games/goldcanalley  games/whackamole  games/plinko  games/ringtoss   (games/duckshoot → stub, solo assets/)
      (can knockdown)   (whack-a-mole)   (plinko)      (ring toss)
```

**Regla de oro:** `core/` no importa nada de `games/`. Cada juego bajo `games/<id>/` es autocontenido (`scenes/`, `scripts/`, `data/`, `assets/`, `shaders/`) y **solo** se acopla al core por 3 puntos: `games.json`, lectura de `save_manager.juego_actual_seleccionado / nivel_actual_seleccionado`, y `PanelResultados`.

---

## 3) Inventario de recursos reutilizables — `core/`

### 3.1 Autoloads (`project.godot:18-23`, `core/scripts/`)

| Autoload | Script | Qué expone (API que vas a usar) |
|---|---|---|
| `save_manager` | `core/scripts/save_manager.gd:1` | `juego_actual_seleccionado: String`, `nivel_actual_seleccionado: int`, `pagina_niveles_por_juego: Dictionary`, `premio_recien_desbloqueado: String`, `LISTA_PREMIOS: Array[String]` (18 premios). Métodos clave: `registrar_puntaje_nivel(nivel, puntaje, max, id_game) -> bool` (`save_manager.gd:73`), `obtener_puntaje_nivel`, `obtener_maximo_nivel`, `es_nivel_desbloqueado(nivel, id_game) -> bool` (desbloquea si `score_prev/max_prev >= 1/3`, `save_manager.gd:112`), `contar_ribbons_azules()`, `obtener_total_niveles_game(id)`, `obtener_total_niveles_globales()`, `calcular_cantidad_premios_desbloqueados()`, `obtener_pagina_niveles/guardar_pagina_niveles`, `obtener_opcion_audio/guardar_opcion_audio`, `obtener_idioma_guardado/guardar_idioma`. Persistencia a disco `guardar_a_disco()` (`save_manager.gd:51`). |
| `audio_manager` | `core/scripts/audio_manager.gd:1` | `music_enabled/sfx_enabled: bool`, `bgm_player: AudioStreamPlayer` (creado en `_ready`, `audio_manager.gd:19`), `set_music_enabled(bool)`, `set_sfx_enabled(bool)`, `play_bgm(stream)`, `play_start/welldone/prize/ok1()`. Estado leído de `save_manager` (`audio_manager.gd:22`). Escena contenedora: `core/scenes/audio_manager.tscn`. |
| `game_manager` | `core/scripts/game_manager.gd:1` | `idioma_actual: String`, `configuracion_juegos: Dictionary` (cache de `games.json`), `textos_locales: Dictionary`. `cargar_configuracion_juegos()` (`game_manager.gd:16`), `cargar_todos_los_textos()` (core `textos.json` sin prefijo + cada juego con su `prefijo_texto`, `game_manager.gd:37`), `obtener_config_juego_actual() -> Dictionary` (`game_manager.gd:57`), `obtener_texto(clave, defecto) -> String` con fallback a `es` (`game_manager.gd:60`), `obtener_titulo_nivel(id, game) -> String` resuelve `prefijo + num` (`game_manager.gd:72`), signal `idioma_cambiado`. |
| `EfectosUI` | `core/scripts/efectos_ui.gd:1` | Singleton `EfectosUI`. `crear_efecto_puntos(posicion_3d: Vector3, valor: int)` — proyecta `pos_3d + (0,0.3,0)` con `Camera3D.unproject_position`, instancia `core/scenes/puntos_flotantes.tscn`, ubica en el `CanvasLayer` activo y anima tween flotante + fade 1.5s (`efectos_ui.gd:6`). Usado en goldcanalley `main.gd:181`, whackamole `main.gd:223`, ringtoss `main.gd:606`, plinko `main.gd:209`. |

### 3.2 Controladores reutilizables (scripts con `class_name`)

| Script | `class_name` | Para qué |
|---|---|---|
| `core/scripts/controlador_resultados.gd:2` | `ControladorResultados` | **Elimina boilerplate de resultados.** Gestiona `reset()/al_iniciar_nivel()`, `mostrar(nivel, puntaje, max)` (guard + ocultar HUD + `panel.mostrar()`), `actualizar_puntaje/nivel`, `esta_mostrado()`, y conecta `reiniciar_solicitado -> callback`. Uso: ver §5 skeleton. Todos los juegos actuales lo usan (goldcanalley `main.gd:58`, whackamole `main.gd:36`, plinko `main.gd:47`, ringtoss `main.gd:288`). |
| `core/scripts/game_audio_base.gd:1` | `GameAudioBase` | Base para audio por juego. Agrupa `AudioStreamPlayer` hijos por prefijo (texto antes de dígitos en el nombre del nodo, `game_audio_base.gd:16`). `play(prefijo)`, `play_aleatorio(prefijo)`, respeta `sfx_enabled`. Inyección típica: `nueva_pelota.set("audio", audio_juego)` (plinko `main.gd:326`, goldcanalley `main.gd:141`). |
| `core/scripts/panel_resultados.gd:2` | `PanelResultados` | Panel fin de nivel. `mostrar(nivel_id, puntaje, max, id_game)` (`panel_resultados.gd:41`) calcula umbrales 1/3, 2/3, 3/3 → ribbons amarilla/roja/azul, llama `save_manager.registrar_puntaje_nivel()` y `audio_manager.play_welldone()`, anima desenfoque + pop. Señales `reiniciar_solicitado` / `continuar_solicitado`; botón OK navega a `premio_desbloqueado.tscn` si hay premio o a `seleccion_niveles.tscn` si no (`panel_resultados.gd:120`). |
| `core/scripts/ui_puntaje.gd:2` | `UIPuntaje` | HUD score con `pad_zeros`. `establecer_puntaje(int)` (`ui_puntaje.gd:14`). Escena: `core/scenes/ui_puntaje.tscn`. |
| `core/scripts/ui_timer.gd:2` | `UITimer` | Countdown `iniciar(segundos)`, `detener()`, signal `tiempo_agotado`. Colores blanco→amarillo (<10s)→rojo (<5s), parpadeo final 4×0.25s (`ui_timer.gd:60`). Escena: `core/scenes/ui_timer.tscn`. |
| `core/scripts/ui_level_number.gd:2` | `UILevelNumber` | `establecer_nivel(int)` (`ui_level_number.gd:12`). Escena: `core/scenes/ui_level_number.tscn`. |
| `core/scripts/label.gd:1` | — | Anima `u_time` de `ShaderMaterial` cada frame — usar en labels con shader. |
| `core/scripts/logo_script.gd:1` | — | Splash dissolve (`logo_dissolver.gshader`) con auto-transición a `title.tscn` a los `wait_time` segundos o al tap/click (`logo_script.gd:28`). |
| `core/scripts/austral_animated_logo.gd:1` | — | Anima `u_time` de label + `crt_effect` (`austral_animated_logo.gd:6`). |

### 3.3 Pantallas / escenas compartidas (`core/scenes/`)

| Escena | Script asociado | Reutilización |
|---|---|---|
| `core/scenes/title.tscn` | `core/scripts/title.gd:1` | Hub. Un `TextureButton` por juego (hoy 4 hardcodeados: `ButtonGoldCanAlley`, `ButtonWhackamole`, `ButtonPlinko`, `ButtonRingToss` en `title.tscn:66-119`). Cada handler hace `_iniciar_juego(id)` → `save_manager.juego_actual_seleccionado = id` + `change_scene_to_file(seleccion_niveles.tscn)` (`title.gd:26`). También `Prizes` → `premios.tscn` y `Options` → `options.tscn`. **Al añadir juego, tocar aquí + `games.json`.** |
| `core/scenes/seleccion_niveles.tscn` | `core/scripts/seleccion_niveles.gd:1` | **Genérica y data-driven.** Lee `game_manager.obtener_config_juego_actual()` (`seleccion_niveles.gd:18`), carga `ruta_niveles_json` para contar niveles, pone `textura_fondo/logo` del registry, pagina de 9 (`NIVELES_POR_PAGINA=9`, `seleccion_niveles.gd:11`), restaura `save_manager.obtener_pagina_niveles()` (`seleccion_niveles.gd:44`), renderiza 9× `slot_nivel.tscn` y conecta `nivel_seleccionado -> change_scene_to_file(escena_juego_destino)` (`seleccion_niveles.gd:122`). |
| `core/scenes/slot_nivel.tscn` | `core/scripts/slot_nivel.gd:1` | Slot individual. `configurar(nivel_id)` consulta `save_manager.es_nivel_desbloqueado` y pinta bloqueado (modulate oscuro, disabled, ribbons ocultas, `slot_nivel.gd:32`) vs desbloqueado (ribbons según `score/max`, `slot_nivel.gd:62`). Emite `nivel_seleccionado(nivel_id)`. |
| `core/scenes/panel_resultados.tscn` | `core/scripts/panel_resultados.gd:1` | Ver §3.2. Incrustar bajo un `CanvasLayer/UI` del juego. |
| `core/scenes/puntos_flotantes.tscn` | (sin script, usado por `EfectosUI`) | `Control + Label` con `carnivalee_freakshow.ttf` 80px, outline 3. No instanciar directo — usar `EfectosUI.crear_efecto_puntos()`. |
| `core/scenes/options.tscn` | `core/scripts/options.gd:1` | Toggles música/SFX (`icon_check_on/off.png`) vía `audio_manager` + selector idioma `es/en/pt` vía `game_manager.cambiar_idioma` (`options.gd:63`). |
| `core/scenes/premios.tscn` | `core/scripts/premios.gd:1` | Galería `GridContainer` de 18 premios (`save_manager.LISTA_PREMIOS`, `premios.gd:5`). Usa `obtener_total_niveles_globales()` + `contar_ribbons_azules()` para calcular `ribbons_necesarias = ceil(n_premio * total_niveles / 18)` y pinta bloqueado vs desbloqueado (`premios.gd:88`). Drag manual horizontal/vertical. |
| `core/scenes/premio_desbloqueado.tscn` | `core/scripts/premio_desbloqueado.gd:1` | Celebración. Lee `save_manager.premio_recien_desbloqueado`, carga `core/assets/images/prizes/<nombre>.png`, anima panel + hijos con pop cascade (`premio_desbloqueado.gd:69`). Tap → limpia flag y va a `seleccion_niveles.tscn`. |
| `core/scenes/audio_manager.tscn` | `core/scripts/audio_manager.gd:1` | Contiene `Start/Welldone/Prize/Ok1` `AudioStreamPlayer`. Puede extenderse añadiendo más hijos. |
| `core/scenes/des...` + `core/scenes/austral_animated_logo.tscn` | — | Splash / logos animados. |

### 3.4 Shaders (`core/shaders/` + `core/scenes/desenfoque.gdshader`)

| Shader | Uso |
|---|---|
| `core/shaders/desenfoque.gdshader` (uid `8qepyr3ykt3f`) | Blur + oscurecer de `PanelResultados/FondoDesenfoque` (`panel_resultados.tscn:3`). Parámetros `nivel_desenfoque`, `oscurecer`. |
| `core/scenes/desenfoque.gdshader` (uid `dtd576hrtqkjb`) | Blur de `SeleccionNiveles/Fondo` (`seleccion_niveles.tscn:4`, `blur_amount`). |
| `core/shaders/chromatic_aberration.gdshader` | Efecto cromático — aplicable a `CanvasItem`. |
| `core/shaders/crt_effect.gdshader` | CRT + scanlines (`austral_animated_logo.gd:3`). |
| `core/shaders/logo_dissolver.gshader.gdshader` | Dissolve del logo splash (`logo_script.gd:22`, `u_dissolve_amount`). |

### 3.5 Assets compartidos (`core/assets/`)

- **Fonts** (`core/assets/fonts/`): `carnivalee_freakshow.ttf` (títulos/HUD score, 64-80px) + `evereast.ttf` (título de nivel en panel, 32px). Preload vía `*.tscn`.
- **UI kit** (`core/assets/images/ui/`): `panel_level.png`, `panel_prize.png`, `panel_options.png`, `panel_levels.png`, `button_ok/restart/home/gen/start/prizes/options/arrow.png`, `icon_check_on/off.png`, `icon_sound/music.png`, `ribbon_yellow/red/blue.png` + `ribbon_tiny_yellow/blue.png` y `robbon_tinty_red.png`.
- **Premios** (`core/assets/images/prizes/`): 18 PNG (`aros`, `dino`, `drum`, `doll`, `roboto`, `duck`, `racer`, `tricep`, `horse`, `bunny`, `plane`, `train`, `rocket`, `robot`, `teddy`, `bluey`, `astro`, `rex`) — nombres = `LISTA_PREMIOS` (`save_manager.gd:5`).
- **SFX core** (`core/assets/sounds/`): `levelcomplete.wav`, `levelcomplete1.wav`, `prize1.wav`, `triunfo1.wav`, `welldone1.wav`, `ok.wav/ok1.wav/ok2.wav`, `fail1/2.wav`, `getready.wav`, `848579__huglex__windhowl4.wav`.
- **Logos**: `core/assets/images/logo.png`, `logoaustral.png`.

---

## 4) Receta — Cómo crear un nuevo minijuego (checklist para agentes)

> Tiempo estimado: 15–30 min siguiendo este orden. No requiere tocar `core/` salvo pasos 1 y 7.

**Paso 0 — Decidir `id` del juego.** Ej: `duckshoot`. Debe ser `snake_case`, sin espacios, coincide con clave en `games.json`, carpeta `games/<id>/`, y `prefijo_texto`.

**Paso 1 — Registrar en `core/data/games.json`.** Añadir entrada (ver `core/data/games.json:2-9` como ejemplo):

```json
"duckshoot": {
  "escena_juego": "res://games/duckshoot/scenes/main.tscn",
  "ruta_niveles_json": "res://games/duckshoot/data/niveles.json",
  "textos_json": "res://games/duckshoot/data/textos.json",
  "textura_fondo": "res://games/duckshoot/assets/images/fondo_selector.png",
  "textura_logo": "res://games/duckshoot/assets/images/logo.png",
  "prefijo_texto": "duckshoot_"
}
```

Campos: `escena_juego` (main jugable), `ruta_niveles_json` (obligatorio para conteo/selector), `textos_json`, `textura_fondo/logo` (opcionales, fallback a goldcanalley/whackamole), `prefijo_texto` (namespace de `textos.json` en `game_manager`).

**Paso 2 — Crear estructura de carpetas.**

```
games/duckshoot/
├── scenes/main.tscn
├── scripts/main.gd (+ otros scripts del juego)
├── data/niveles.json
├── data/valores.json   (opcional, tuning por tipo de objeto)
├── data/textos.json
├── assets/images/logo.png  (256×256+)
├── assets/images/fondo_selector.png (720×1280 o similar)
├── assets/sounds/  (opcional)
└── shaders/        (opcional)
```

Duplicar `games/ringtoss/` o `games/plinko/` como plantilla — ambos usan `ControladorResultados` ya.

**Paso 3 — Crear `data/niveles.json`.** Formato libre por juego, pero **debe ser `Dictionary` con claves `"1"`, `"2"`, ...** (el selector cuenta `keys().size()`). Cada juego define su schema:

- `goldcanalley` (`games/goldcanalley/data/niveles.json:2`): `"1": [[grid_x, grid_y, grid_z, "tipo"], ...]` (tipos `A`-`J` mapeados en `valores.json`).
- `plinko` (`games/plinko/data/niveles.json:2`): `{"1": {"puntaje":450, "color_board":"EB051B", "pegs":[{x,y}…], "ramps":[{x,y,rot}…], "slots":[{x_start,x_end,pts,color}…]}}`
- `ringtoss` (`games/ringtoss/data/niveles.json:2`): `{"1": {"rings":5, "puntaje_maximo":300, "separacion_x":0.18, ..., "cones":[{id,x,z,points,scale,rot_y}…]}}`
- `whackamole`: `{"1": {"meta_puntos":300, "tiempo_limite":30, "hoyos":[{pos:[x,y], tipo:"marron"}…]}}`

> Cualquier schema vale mientras tu `main.gd` lo lea igual y expongas `puntaje_maximo_nivel` para `PanelResultados`.

**Paso 4 — Crear `data/valores.json` y `data/textos.json`.**

- `valores.json` (tuning): ej. goldcanalley `valores.json:2` → `{"A":{"pts":100,"masa":0.45,"ancho":1.0,"alto":1.0,"textura":"a.png"}}`. Whackamole `valores.json` → por tipo de topo con `pts`, `outch`, `risa`, etc.
- `textos.json` — títulos por nivel, **claves sin prefijo** (el prefijo lo añade `game_manager`). Ej. goldcanalley `textos.json:2` → `{"1":{"es":"Pirámide Clásica","en":"Classic Pyramid","pt":"…"}}`. Core los carga como `duckshoot_1` si `prefijo_texto="duckshoot_"` (`game_manager.gd:54`).

**Paso 5 — Crear `scenes/main.tscn` y `scripts/main.gd`.** Ver skeleton §5. Requisitos del contrato con el core:

1. Leer `save_manager.nivel_actual_seleccionado` en `_ready()` para saber qué nivel cargar.
2. Exponer `puntaje_nivel: int` y `puntaje_maximo_nivel: int` (el segundo es la meta para ribbons).
3. Incrustar `PanelResultados` (`core/scenes/panel_resultados.tscn`) bajo tu `CanvasLayer/UI` y drivearlo vía `ControladorResultados`.
4. Al terminar el nivel, llamar `ctrl_resultados.mostrar(nivel, puntaje, max)` — esto ya hace `save_manager.registrar_puntaje_nivel()` y dispara `premio_recien_desbloqueado` si toca.
5. Usar `EfectosUI.crear_efecto_puntos(pos3D, pts)` para feedback flotante.
6. Opcional: `GameAudioBase` para SFX agrupados.

**Paso 6 — Añadir botón en el hub (`core/scenes/title.tscn` + `core/scripts/title.gd`).** Hoy es manual (no dinámico). Duplica un `TextureButton` existente (ej. `ButtonRingToss` `title.tscn:105`), asigna `texture_normal = tu logo`, conecta `pressed -> _on_boton_<id>_pressed` en `title.gd` y añade:

```gdscript
func _on_boton_duckshoot_pressed() -> void:
  _press_feedback($ButtonDuckshoot, func(): _iniciar_juego("duckshoot"))
```

Sigue el patrón de `title.gd:5-56` (`_press_feedback` con vibración + tween escala, `audio_manager.play_start()` en `_iniciar_juego`).

**Paso 7 — Probar flujo completo.**

```
title → pick game → save_manager.juego_actual_seleccionado = <id>
      → seleccion_niveles (lee games.json, muestra fondo/logo, pagina 9/pág)
      → tap slot → change_scene_to_file(escena_juego)
      → main.gd carga niveles.json/valores.json, ctrl_resultados.reset()
      → nivel termina → ctrl_resultados.mostrar(...) → PanelResultados
        → save_manager.registrar_puntaje_nivel() → ribbons + premio?
        → OK → premio_desbloqueado.tscn (si hay premio) o seleccion_niveles.tscn
```

---

## 5) Skeleton `main.gd` — copiar/pegar y adaptar

Patrón consolidado (goldcanalley `scripts/main.gd:46-62`, whackamole `main.gd:32-39`, plinko `main.gd:44-50`, ringtoss `main.gd:279-291`):

```gdscript
extends Node3D

@export_file("*.json") var ruta_niveles_json: String = "res://games/mijuego/data/niveles.json"
@export_file("*.json") var ruta_valores_json: String = "res://games/mijuego/data/valores.json"

@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_timer: UITimer = $UI/Timer as UITimer # si tu juego es timed
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego # opcional

var nivel_actual: int = 1
var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
var ctrl_resultados: ControladorResultados

func _ready() -> void:
  nivel_actual = save_manager.nivel_actual_seleccionado
  ctrl_resultados = ControladorResultados.new()
  add_child(ctrl_resultados)
  # Lista HUD que debe ocultarse al mostrar resultados:
  var hud: Array = [ui_puntaje, ui_level_number, ui_timer]
  ctrl_resultados.configurar(panel_resultados, hud, ui_puntaje, ui_level_number, reiniciar_nivel)
  if ui_timer:
    ui_timer.tiempo_agotado.connect(_on_tiempo_agotado)
  cargar_nivel(nivel_actual)

func cargar_nivel(n: int) -> void:
  ctrl_resultados.reset() # oculta panel + restaura HUD
  puntaje_nivel = 0
  puntaje_maximo_nivel = _leer_max_de_json(n) # ej. 300
  ctrl_resultados.actualizar_puntaje(puntaje_nivel)
  ctrl_resultados.actualizar_nivel(n)
  # ... instanciar tu nivel desde JSON ...
  anunciar_nivel(n)

func _on_puntos_ganados(pts: int, pos3d: Vector3) -> void:
  puntaje_nivel += pts
  ctrl_resultados.actualizar_puntaje(puntaje_nivel)
  EfectosUI.crear_efecto_puntos(pos3d, pts)
  if audio_juego: audio_juego.play_aleatorio("hit") # prefijo = nombre de AudioStreamPlayers sin dígitos

func _on_tiempo_agotado() -> void:
  mostrar_panel_resultados()

func mostrar_panel_resultados() -> void:
  ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

func reiniciar_nivel() -> void:
  cargar_nivel(nivel_actual)

func anunciar_nivel(n: int) -> void:
  if not ui_level_title: return
  ui_level_title.text = game_manager.obtener_titulo_nivel(str(n)) # usa prefijo del juego activo
  ui_level_title.modulate.a = 1.0
  ui_level_title.visible = true
  var tween = create_tween()
  tween.tween_interval(1.5)
  tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
  tween.tween_callback(func(): ui_level_title.visible = false)
```

Notas:
- `ControladorResultados.configurar()` espera `Array` genérico — hace cast a `CanvasItem` (`controlador_resultados.gd:42`).
- No llames `save_manager.registrar_puntaje_nivel()` directo si usas `PanelResultados.mostrar()` — ya lo hace (`panel_resultados.gd:70`). Llamarlo directo solo si no usas el panel.
- Para audio, agrupa `AudioStreamPlayer` hijos por prefijo (ej. `Hit1`, `Hit2` → prefijo `Hit`, `game_audio_base.gd:9`).

---

## 6) Progresión, premios y localización — reglas que no debes romper

- **Desbloqueo de nivel** (`save_manager.gd:112`): nivel `n` desbloqueado si `score(n-1)/max(n-1) >= 1/3`. Nivel 1 siempre desbloqueado. `SlotNivel` lo aplica (`slot_nivel.gd:27`).
- **Ribbons** (`panel_resultados.gd:57`): amarilla ≥1/3, roja ≥2/3, azul = 100% (`score >= max`). `SlotNivel` replica la misma lógica (`slot_nivel.gd:66`).
- **Premios globales** (`save_manager.gd:170`): `azules = contar_ribbons_azules()` across **todos** los juegos. `total_niveles = obtener_total_niveles_globales()` (suma de `niveles.json` de cada juego, mínimo 18, `save_manager.gd:168`). Para premio `i` (1-indexed): `requeridas = ceil(i * total_niveles / 18)`. `premios.gd:90` y `premio_desbloqueado.gd` usan la misma fórmula. `LISTA_PREMIOS` orden fijo (`save_manager.gd:5`).
- **Localización** (`game_manager.gd:37`): core `textos.json` sin prefijo + cada juego con `prefijo_texto`. `obtener_texto(clave)` busca `idioma_actual`, fallback `es`, fallback `clave` (`game_manager.gd:60`). Títulos de nivel: `obtener_titulo_nivel("3")` → busca `"<prefijo>3"` (`game_manager.gd:82`).
- **Audio prefs**: `audio_manager` persiste `music_enabled/sfx_enabled` en `save_manager` (`audio_manager.gd:22-32`). Juegos deben consultar `sfx_habilitado()` vía `GameAudioBase` o `save_manager.obtener_opcion_audio("sfx_enabled")`.

---

## 7) Estructura de archivos (actual)

```
goldcanalley/
├── project.godot              # autoloads, viewport 720×1280, Jolt, main_scene title
├── export_presets.cfg
├── core/
│   ├── data/games.json        ← registry (único punto de registro)
│   ├── data/textos.json       ← {seleccion_nivel, nuevo_premio} es/en/pt
│   ├── scripts/               # 17 scripts (ver §3.1-3.2)
│   │   ├── save_manager.gd / game_manager.gd / audio_manager.gd / efectos_ui.gd
│   │   ├── controlador_resultados.gd / game_audio_base.gd / panel_resultados.gd
│   │   ├── title.gd / seleccion_niveles.gd / slot_nivel.gd
│   │   ├── ui_puntaje/timer/level_number.gd / options.gd / premios*.gd / label.gd / logo_script.gd
│   │   └── austral_animated_logo.gd
│   ├── scenes/                # 13 scenes + 2 shaders (desenfoque)
│   │   ├── title.tscn / seleccion_niveles.tscn / slot_nivel.tscn / panel_resultados.tscn
│   │   ├── puntos_flotantes.tscn / ui_puntaje/timer/level_number.tscn
│   │   ├── options.tscn / premios.tscn / premio_desbloqueado.tscn / audio_manager.tscn
│   │   └── austral_animated_logo.tscn
│   ├── shaders/               # chromatic_aberration, crt_effect, desenfoque, logo_dissolver
│   └── assets/                # fonts, images/ui, images/prizes (18), images/logo*, sounds
└── games/
    ├── goldcanalley/          # can knockdown — 90 niveles, 10 tipos de lata (A-J), shader latas, mesa 3D
    │   └── data/niveles.json (90 keys) / valores.json (A-J) / textos.json (90 títulos)
    ├── whackamole/            # whack-a-mole — spawner random, 6 tipos de topo, mazo 3D
    ├── plinko/                # plinko — board procedural (pegs/ramps/slots), 18 niveles, ball physics
    ├── ringtoss/              # ring toss — cones + Area3D score, drag/swipe, 40+ niveles
    └── duckshoot/             # stub — solo assets/, pendiente de implementar
```

Cada `games/<id>/` replica: `scenes/`, `scripts/`, `data/`, `assets/`, `shaders/` (opcional).

---

## 8) Flujo de navegación (código)

```gdscript
# title.gd:26
save_manager.juego_actual_seleccionado = "plinko"
get_tree().change_scene_to_file("res://core/scenes/seleccion_niveles.tscn")

# seleccion_niveles.gd:18-24 — lee registry, pone fondo/logo, cuenta niveles
var cfg = game_manager.obtener_config_juego_actual() # {escena_juego, ruta_niveles_json, textura_fondo, ...}
total_niveles = obtener_total_niveles() # FileAccess + JSON.parse_string(ruta_niveles_json)

# seleccion_niveles.gd:122 — tap slot
save_manager.nivel_actual_seleccionado = numero_nivel
get_tree().change_scene_to_file(cfg["escena_juego"])

# juego/main.gd — carga nivel, juega, termina
ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)
# → panel_resultados.gd:70 save_manager.registrar_puntaje_nivel(...)
# → panel_resultados.gd:120 OK → premio_desbloqueado.tscn o seleccion_niveles.tscn
```

---

## 9) Qué NO hacer (errores comunes)

- No hardcodees `id` de juego en `save_manager` — usa `save_manager.juego_actual_seleccionado`.
- No dupliques lógica de ribbons/desbloqueo — llama a `save_manager` y `panel_resultados`.
- No instancies `puntos_flotantes.tscn` directo — usa `EfectosUI.crear_efecto_puntos(pos3D, pts)`.
- No añadas `AudioStreamPlayer` sueltos por juego sin `GameAudioBase` — pierdes respeto a `sfx_enabled`.
- No olvides `prefijo_texto` en `games.json` — sin él tus `textos.json` colisionan con otros juegos.
- No dejes `niveles.json` sin claves `"1".."N"` contiguas — `seleccion_niveles` y `save_manager.obtener_total_niveles_game` cuentan `keys().size()`.

---

## 10) Running

Abrir la raíz en **Godot 4.7+** → Run (main scene = title). Export vía `Project → Export` (presets Web/iOS en `export_presets.cfg`).

---

*Última actualización: 2026-09-24 — 4 juegos activos (goldcanalley, whackamole, plinko, ringtoss) + duckshoot stub. Para proponer mejoras al core (ej. hub dinámico que lea `games.json` sin tocar `title.gd`), abrir issue/PR con prefijo `[core]`.*
