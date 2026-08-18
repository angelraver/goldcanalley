# Goldcanalley Project Structure

## Overview
Godot project containing a collection-based game with mechanics involving dropping/lifting objects ("lata"). The project follows a modular structure with separate directories for scripts, scenes, assets, and configuration.

## Root Directory
Root-level files and folders:
- `project.godot` - Godot project configuration
- `export_presets.cfg` - Export presets configuration
- `icon.svg` - Project icon
- `.godot/` - Godot internal metadata
- `.git/` - Git version control
- `.gitignore` - Git ignore rules
- `.DS_Store` - macOS directory metadata

## Key Directories

### `data/`
Configuration and metadata files:
- `niveles.json` - Level definitions
- `valores.json` - Game values/settings
- `titulos_niveles.json` - Level titles

### `scripts/`
GDScript files organizing game logic:
- `main.gd` - Entry point and main game loop
- `game_manager.gd` - Game state and progression management
- `save_manager.gd` - Save/load system
- `audio_manager.gd` - Audio control and management
- `options.gd` - User options and settings
- `premios.gd` - Prize/award system
- `seleccion_niveles.gd` - Level selection menu
- `title.gd` - Title screen logic
- `lata.gd` - Core object script (likely the "lata" mechanic)
- `premio_desbloqueado.gd` - Unlockable prize handling

### `scenes/`
Godot `.tscn` scene files:
- `main.tscn` - Main game scene
- `title.tscn` - Title screen scene
- `seleccion_niveles.tscn` - Level selection scene
- `options.tscn` - Options menu scene
- `lata.tscn` - Lata object scene
- `pelota.tscn` - Ball physics/object scene
- `premio_desbloqueado.tscn` - Unlockable prize scene
- `premios.tscn` - Prizes scene
- `puntos_flotantes.tscn` - Floating points/scoring scene
- `slot_nivel.tscn` - Level slot/instance scene

### `shaders/`
GDShader files:
- `lata_shader.gdshader` - Shader for lata object
- `desenfoque.gdshader` - Blur/post-processing effect

### `fonts/`
Font resources:
- `carnivalee_freakshow.ttf` - Display/title font
- `evereast.ttf` - Secondary font

### `images/`
Image assets organized into subdirectories:
- `logo.png` - Main logo
- `ui/` - User interface graphics
- `world/` - World/background elements
- `prizes/` - Prize-related images
- `cans/` - Canning/container graphics

### `models/`
3D model files:
- `table.glb` - Table model with import metadata

### `sounds/`
Audio assets (46 entries including WAV files and import metadata):
- Core SFX: `getready.wav`, `ok.wav`, `ok1.wav`, `ok2.wav`, `fail1.wav`, `fail2.wav`, `shot1.wav`-`shot4.wav`, `levelcomplete.wav`, `levelcomplete1.wav`-`levelcomplete2.wav`, `welldone1.wav`
- Prize/audio: `prize1.wav`, `lata1.wav`-`lata8.wav`

## Project Architecture Notes
- **Godot 4 project** based on `project.godot` configuration
- **Collection-focused gameplay** with emphasis on object collection mechanics
- **Modular script organization** separating core systems (manager, save, audio) from game-specific logic
- **Extensive audio design** with numerous short SFX for feedback
- **Custom font** (`carnivalee_freakshow.ttf`) for visual branding
- **Scene-based architecture** with clear separation of menus, UI, and gameplay scenes

## Missing Architecture Documentation
No `architecture/` directory was found in the current project structure. If architecture documentation exists, it may be located elsewhere or named differently.

## Total Count
- **Root files**: 7 (excluding hidden dirs)
- **Folders**: 9
- **Script files**: 22 GDScript files
- **Scene files**: 11 Godot scenes
- **Shader files**: 2 GDShaders
- **Font files**: 2 TTF fonts
- **Image files**: Numerous (with subdirectory organization)
- **3D models**: 1 GLB model
- **Audio files**: 46 WAV entries