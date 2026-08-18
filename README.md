# Goldcanalley Project Structure

## Overview
Godot 4 project (engine 4.7, mobile renderer) for a collection-based game with mechanics involving dropping/lifting objects ("lata"). The project follows a modular, two-layer structure: a shared `core/` framework (menus, audio, save system, prizes) and a game-specific module under `games/goldcanalley/`.

## Root Directory
- `project.godot` - Godot project configuration (main scene, autoloads, viewport 720x1280, Jolt Physics)
- `export_presets.cfg` - Export presets configuration
- `icon.svg` - Project icon
- `blenders.zip` - Blender source assets archive
- `.gitignore` - Git ignore rules
- `.godot/` - Godot internal metadata (ignored)
- `.vscode/` - VS Code workspace settings
- `.git/` - Git version control
- `.DS_Store` - macOS directory metadata

## Key Directories

### `core/` - Shared game framework
Reusable systems and assets shared by all game modules.

- **`core/scripts/`** - GDScript logic, registered as autoloads where needed:
  - `save_manager.gd` - Save/load system (autoload)
  - `audio_manager.gd` - Audio control and management (autoload)
  - `game_manager.gd` - Game state and progression management (autoload)
  - `title.gd` - Title screen logic
  - `options.gd` - User options and settings
  - `premios.gd` - Prize/award system
  - `premio_desbloqueado.gd` - Unlockable prize handling
  - `slot_nivel.gd` - Level slot/instance handling

- **`core/scenes/`** - Godot `.tscn` scenes:
  - `title.tscn` - Title screen scene (main scene)
  - `options.tscn` - Options menu scene
  - `premios.tscn` - Prizes scene
  - `premio_desbloqueado.tscn` - Unlockable prize scene
  - `slot_nivel.tscn` - Level slot/instance scene
  - `audio_manager.tscn` - Audio manager scene

- **`core/shaders/`** - GDShader files:
  - `desenfoque.gdshader` - Blur/post-processing effect

- **`core/assets/`** - Shared resources:
  - `fonts/` - `carnivalee_freakshow.ttf` (display/title font), `evereast.ttf` (secondary font)
  - `images/logo.png` - Main logo
  - `images/ui/` - UI graphics (buttons, panels, ribbons, check/music/sound icons)
  - `images/prizes/` - Prize images (teddy, dino, robot, rocket, train, etc.)
  - `sounds/` - Core SFX (getready, ok, fail, levelcomplete, welldone, prize)

- **`core/data/`** - Configuration and metadata:
  - `textos.json` - Localized/UI texts

### `games/goldcanalley/` - Game module
The actual game content for the "Goldcanalley" experience.

- **`games/goldcanalley/scripts/`** - GDScript files organizing game logic:
  - `main.gd` - Entry point and main game loop
  - `lata.gd` - Core object script (the "lata" dropping/lifting mechanic)
  - `seleccion_niveles.gd` - Level selection menu

- **`games/goldcanalley/scenes/`** - Godot `.tscn` scene files:
  - `main.tscn` - Main game scene
  - `lata.tscn` - Lata object scene
  - `pelota.tscn` - Ball physics/object scene
  - `puntos_flotantes.tscn` - Floating points/scoring scene
  - `seleccion_niveles.tscn` - Level selection scene

- **`games/goldcanalley/shaders/`** - GDShader files:
  - `lata_shader.gdshader` - Shader for the lata object

- **`games/goldcanalley/data/`** - Configuration and metadata:
  - `niveles.json` - Level definitions
  - `valores.json` - Game values/settings
  - `textos.json` - Game-specific texts

- **`games/goldcanalley/assets/`** - Game-specific resources:
  - `images/cans/` - Can artwork (letter textures a-j, lata base/top, Manaos soda labels)
  - `images/ui/` - Power meter graphics (meter_bar, meter_circle)
  - `images/world/` - World elements (ball, floor, backgrounds, table, wood)
  - `models/table.glb` - 3D table model
  - `sounds/` - Gameplay SFX (lata1-8.wav, shot1-4.wav)

- `games/goldcanalley/export_presets.cfg` - Game-specific export configuration

## Project Architecture Notes
- **Godot 4 project** using Jolt Physics, mobile renderer (`gl_compatibility`), viewport 720x1280 with canvas_items stretch
- **Autoload singletons**: `save_manager`, `audio_manager`, `game_manager` (from `core/scripts/`)
- **Two-layer modular structure**: shared `core/` framework decoupled from game-specific content in `games/goldcanalley/`
- **Collection-focused gameplay** with emphasis on object collection mechanics
- **Extensive audio design** with numerous short SFX for feedback
- **Custom font** (`carnivalee_freakshow.ttf`) for visual branding
- **Scene-based architecture** with clear separation of menus, UI, and gameplay scenes

## Total Count
- **Root files**: 8 (excluding hidden dirs/files)
- **Core scripts**: 8 GDScript files
- **Core scenes**: 6 Godot scenes
- **Game scripts**: 3 GDScript files
- **Game scenes**: 5 Godot scenes
- **Shader files**: 2 GDShaders (1 core, 1 game)
- **Font files**: 2 TTF fonts
- **Prize images**: 19 PNG files
- **3D models**: 1 GLB model
- **Audio files**: 23 WAV files (11 core, 12 game)