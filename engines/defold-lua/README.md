# Kofun Seven — Defold / Lua

A single 960×540 Defold application containing seven playable arcade modes. The
visuals are generated from GUI box and text nodes, so the build remains useful
even when no external art assets are present.

## Run

Open this directory in the current Defold editor and press **Build** (`Ctrl+B` /
`Cmd+B`). From a local Defold installation, the same project can be bundled or
built with Bob in the normal way:

```sh
java -jar bob.jar --root engines/defold-lua resolve build
```

The Lua-side runtime smoke test uses small Defold API doubles:

```sh
(cd engines/defold-lua && lua tests/runtime_smoke.lua)
```

## Controls

- Menu: `1`–`7`, or `Up`/`Down` then `Enter`
- Movement: WASD or arrow keys
- Action: `Space` (Sky Dodge flap, Neon Dash jump, Kofun Orbit pulse)
- Tap Patrol: click or tap the cyan signal
- Sky Dodge and Neon Dash: click or tap also activates the action
- Any result: `Enter` or `R` to retry
- Any game: `Esc` to return to the menu

## Structure

- `game.project` defines the fixed lightweight display and bootstrap collection.
- `input/game.input_binding` maps keyboard and pointer input.
- `main/main.collection` loads the GUI game object.
- `main/main.gui_script` owns the menu, seven independent state machines,
  collision and scoring rules, HUD, results, restart, and all primitive drawing.

The seven modes are Courier, Breaker, Tap Patrol, Sky Dodge, Neon Dash, Kofun
Orbit, and Snake. Every mode has its own win/loss conditions and can be replayed
without returning to the editor.
