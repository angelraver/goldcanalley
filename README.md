# Goldcanalley

A carnival-themed collection of 3D minigames built with **Godot 4.7** (mobile renderer, portrait 720×1280, Jolt Physics). Export targets: **Web** and **iOS**.

The project follows a hub-based, plugin-style architecture: a shared `core/` framework owns all menus, progression, audio, and localization, while each minigame lives in its own self-contained module under `games/`. Adding a new minigame requires no changes to the core code — only a new folder and an entry in the game registry.

## Architecture

```
┌───────────────────────────── core/ ─────────────────────────────┐
│  Title (hub) ──► Level Selection (generic) ──► [minigame scene] │
│       │                    ▲                          │         │
│       ├──► Prizes          │                          ▼         │
│       └──► Options    games.json registry      PanelResultados  │
│                                                                 │
│  Autoloads: save_manager · audio_manager · game_manager ·       │
│             EfectosUI                                           │
│  Shared UI: UIPuntaje · UITimer · UILevelNumber ·               │
│             PanelResultados · PuntosFlotantes                   │
└──────────────────────────────────────────────────────────────────┘
            │                              │
     games/goldcanalley           games/whackamole
     (can knockdown)              (whack-a-mole)
```

### Core framework (`core/`)

Everything shared between minigames:

- **Autoload singletons** (`core/scripts/`, registered in `project.godot`):
  - `game_manager.gd` — loads the game registry and merges localization texts from core plus every registered game (per-game text prefixes); provides translated-string lookup with Spanish fallback.
  - `save_manager.gd` — persistence to `user://progreso.json`: per-game level scores, level unlocking, audio/language preferences, selected game/level, and global prize computation.
  - `audio_manager.gd` — background music player and SFX playback respecting saved user preferences.
  - `efectos_ui.gd.gd` — floating "+points" feedback effects projected from 3D world positions onto the 2D UI.

- **Data-driven game registry** (`core/data/games.json`): maps each minigame id to its main scene, levels JSON path, texts JSON path, selector background/logo textures, and text prefix. This is the single point of registration for minigames.

- **Shared scenes/scripts**:
  - `title` — hub screen with one play button per registered game, plus Prizes and Options.
  - `seleccion_niveles` + `slot_nivel` — generic, paginated (9 per page) level-select screen that adapts itself to the selected game via the registry (levels list, background, logo).
  - `options` — music/SFX toggles and language selection.
  - `premios` / `premio_desbloqueado` — prize shelf gallery and unlock celebration screens.
  - `panel_resultados` — end-of-level results panel shared by all games; records the score through `save_manager.registrar_puntaje_nivel()`.
  - Reusable gameplay HUD: `ui_puntaje` (score), `ui_timer` (countdown), `ui_level_number`, `puntos_flotantes`.

- **Progression rules** (implemented in `save_manager.gd`):
  - A level is unlocked when the previous level was scored at least ⅓ of its maximum.
  - Perfect scores earn blue ribbons; ribbons collected across *all* minigames progressively unlock the 18 global prizes.

- **Localization**: Spanish/English via `textos.json` files. Core texts load unprefixed; each game's texts are merged under its own prefix (e.g. `goldcanalley_…`, `whackamole_…`).

- **Assets**: fonts, logo, UI kit (buttons, panels, ribbons), prize artwork, common SFX, and a blur shader (`desenfoque.gdshader`).

### Minigames (`games/`)

Each minigame is a self-contained module with the same internal layout: `scenes/`, `scripts/`, `shaders/`, `data/` (`niveles.json` level definitions + `valores.json` object/tuning values + `textos.json` localized strings), and `assets/`. Games read their own JSON data on startup and reuse the core HUD and results flow — a game's contract with the core is simply:

1. Be listed in `core/data/games.json`.
2. Expose a playable main scene.
3. Show `PanelResultados` when the level ends (the core handles saving, unlocking, and prize logic).

#### `games/goldcanalley/` — Can Knockdown
Throw balls at pyramids of soda cans stacked on a table. Levels are defined as grids of can positions/types in `niveles.json`; can types (size, mass, points, label texture) come from `valores.json`. Features a hold-to-charge power meter, limited balls per level, raycast aiming, and a custom shader for texturing can meshes. Includes 3D table model and per-can SFX.

#### `games/whackamole/` — Whack-a-Mole
Timed whack-a-mole on a 3D table: holes are placed on a grid per level (`niveles.json`), moles pop up driven by a randomized spawner, and different mole types (speed, points) come from `valores.json`. Player swings a 3D mallet; hits spawn floating-score effects from the core.

## Game flow

```
title → pick game → save_manager.juego_actual_seleccionado = <id>
      → seleccion_niveles (reads games.json entry)
      → tap a slot → change_scene_to_file(escena_juego)
      → game's main.gd loads its niveles.json / valores.json
      → level ends → PanelResultados → save_manager.registrar_puntaje_nivel()
      → back to level select / prize unlock screen
```

## Project layout

```
goldcanalley/
├── project.godot            # Engine config: autoloads, viewport, physics
├── export_presets.cfg       # Web & iOS export presets
├── icon.svg
├── core/                    # Shared framework (autoloads, menus, HUD, save, audio)
│   ├── scripts/  scenes/  shaders/
│   ├── assets/   (fonts, images/ui, images/prizes, sounds)
│   └── data/     (games.json ← game registry, textos.json)
└── games/                   # Minigame modules
    ├── goldcanalley/        # Can knockdown (scenes, scripts, shaders, data, assets)
    └── whackamole/          # Whack-a-mole (scenes, scripts, shaders, data, assets)
```

## Running

Open the project root in Godot 4.7+ and run — the main scene is the core title screen. For deployment, use the Web or iOS export presets via Project → Export.
