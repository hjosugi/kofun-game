set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

check: check-structure check-phaser check-lua check-rust check-go check-godot check-defold build-raylib

check-structure:
    python3 -m unittest discover -s tests -v

check-phaser:
    cd engines/phaser-typescript && npm ci && npm run build

check-lua:
    find engines/love2d-lua engines/defold-lua -type f \( -name '*.lua' -o -name '*.script' -o -name '*.gui_script' \) -print0 | xargs -0 -n1 luac -p

check-rust:
    cd engines/macroquad-rust && export CARGO_TARGET_DIR="$PWD/target" && cargo fmt --check && cargo check && cargo test && cargo clippy -- -D warnings

check-go:
    test -z "$(gofmt -l engines/ebitengine-go)"
    cd engines/ebitengine-go && go test ./... && go vet ./... && go test -race ./...

check-godot:
    godot --headless --path engines/godot-gdscript --script res://tests/smoke_test.gd

check-defold:
    cd engines/defold-lua && lua tests/runtime_smoke.lua
    bob --root engines/defold-lua clean build

build-raylib:
    cmake -S engines/raylib-c -B engines/raylib-c/build
    cmake --build engines/raylib-c/build

play-phaser:
    cd engines/phaser-typescript && npm run dev

play-godot:
    godot --path engines/godot-gdscript

play-godot-software:
    scripts/run-software.sh godot --path engines/godot-gdscript --rendering-method gl_compatibility --rendering-driver opengl3

play-love:
    love engines/love2d-lua

play-love-software:
    scripts/run-software.sh love engines/love2d-lua

play-raylib:
    just build-raylib
    engines/raylib-c/build/kofun_arcade

play-raylib-software:
    just build-raylib
    scripts/run-software.sh engines/raylib-c/build/kofun_arcade

play-rust:
    cd engines/macroquad-rust && cargo run --release

play-rust-software:
    scripts/run-software.sh bash -c 'cd engines/macroquad-rust && cargo run --release'

play-go:
    cd engines/ebitengine-go && go run .

play-go-software:
    scripts/run-software.sh bash -c 'cd engines/ebitengine-go && go run .'
