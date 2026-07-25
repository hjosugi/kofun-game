# Kofun Arcade — raylib 6 / C11

Seven complete, lightweight 2D games share one 960×540 executable. Everything is
drawn with raylib primitives, so the arcade remains playable without external
assets.

## Run

raylib 6.0 and CMake 3.20+ are required.

```sh
cmake -S . -B build
cmake --build build -j
./build/kofun_arcade
```

## Controls

- Menu: `1`–`7`, Up/Down, Enter
- Every game: `Esc` returns to the menu; `R` restarts
- Courier / Orbit: WASD or arrows; Orbit pulse: Space
- Breaker: A/D or Left/Right; Space launches
- Tap Patrol: click targets; avoid the striped decoy
- Sky Dodge: Space or left click to flap
- Neon Dash: Space, Up, or left click to jump
- Snake: arrows or WASD

Each mode has its own win/loss conditions, HUD, in-game help, result screen, and
instant restart. The game loop clamps frame delta to remain stable after a
window stall.
