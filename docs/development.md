# 開発環境

## Nix

```bash
nix develop
just check
```

flakeはGodot、raylib、LÖVE、Node.js、Go、Rust、CMake、Lua、Pythonをまとめます。
Defoldのheadless builder（Bob）も含まれるため、`just check` で7エンジンを
まとめて検査できます。Defold EditorのGUIを使う場合だけ公式配布物を使用します。

## 個別起動

| エンジン | コマンド |
|---|---|
| Godot | `godot --path engines/godot-gdscript` |
| raylib | `cmake -S engines/raylib-c -B engines/raylib-c/build -DKOFUN_FETCH_RAYLIB=ON && cmake --build engines/raylib-c/build` |
| Defold | Editorで `engines/defold-lua/game.project` を開く |
| LÖVE | `love engines/love2d-lua` |
| Phaser | `cd engines/phaser-typescript && npm ci && npm run dev` |
| Macroquad | `cd engines/macroquad-rust && cargo run --release` |
| Ebitengine | `cd engines/ebitengine-go && go run .` |

低スペック端末向けに、背景は単色と小さな画像、論理解像度は960×540、
リアルタイム照明やポストエフェクトは不使用にしています。

## OpenGL / EGLエラー

WSL、仮想マシン、remote desktopで `Could not get EGL display` と表示された
場合は、host graphics driverをNixへ接続するwrapperかMesaのsoftware
rendererを使います。

```bash
nix develop
just play-love-software
```

同様に `play-godot-software`、`play-raylib-software`、
`play-rust-software`、`play-go-software` を用意しています。非NixOSでは
`nixGLIntel` wrapperでhostのMesa driverを公開します。NixOSでは
`LIBGL_ALWAYS_SOFTWARE=1` のllvmpipeへfallbackします。

ブラウザで遊ぶだけなら `just play-phaser` を使用してください。Phaser版は
WebGLではなくCanvas rendererを固定しており、OpenGL contextを必要としません。
