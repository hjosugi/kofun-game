# Kofun Arcade — LÖVE / Lua

A single 960×540 LÖVE application containing seven complete arcade games. It
uses only vector primitives and system fonts, so missing assets never prevent
the game from running.

## Run

Install LÖVE 11.x, then run:

```sh
love .
```

You can also package `main.lua`, `rules.lua`, `conf.lua`, and this README in a zip renamed
with a `.love` extension.

Rule-priority test:

```sh
lua tests/rules_test.lua
```

## Controls

- Menu: `1`–`7`, Up/Down, Enter
- All modes: `Esc` returns to the menu and `R` restarts
- Courier / Kofun Orbit: WASD or arrows; Orbit pulse: Space
- Breaker: A/D or Left/Right; Space launches
- Tap Patrol: click or tap the solid target, avoid the striped decoy
- Sky Dodge: Space, Up, click, or tap to flap
- Neon Dash: Space, Up, click, or tap to jump
- Snake: arrows or WASD

Every mode includes a dedicated HUD, instructions, success/failure state and
retry flow. Frame delta is clamped after stalls.
