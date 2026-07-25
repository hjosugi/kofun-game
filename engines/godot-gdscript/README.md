# Kofun Seven — Godot 4 / GDScript

A single lightweight Godot application containing seven complete arcade modes.
It uses `Node2D` drawing primitives and the built-in font, so no imported art is
required.

## Run

1. Install Godot 4.2 or newer.
2. Open this directory as a project, or run:

   ```sh
   godot --path engines/godot-gdscript
   ```

The project forces Godot's Compatibility renderer and a 960×540 canvas.

Headless initialization smoke test:

```sh
godot --headless --path engines/godot-gdscript \
  --script res://tests/smoke_test.gd
```

## Controls

- Menu: `1`–`7`, or `Up`/`Down` then `Enter`
- Movement: WASD or arrow keys
- Action: `Space` (Sky Dodge flap, Neon Dash jump, Kofun Orbit pulse)
- Tap Patrol: click or tap the cyan signal
- Neon Dash: click or tap also jumps
- Any result: `Enter` or `R` to retry
- Any game: `Esc` to return to the menu

## Implementation

`scripts/main.gd` is a deliberately asset-independent mini-game runtime. Every
mode has its own setup, update, input, and drawing path, while the shared shell
provides selection, HUD, timer, win/loss overlay, restart, and menu navigation.
The modes are Courier, Breaker, Tap Patrol, Sky Dodge, Neon Dash, Kofun Orbit,
and Snake.
