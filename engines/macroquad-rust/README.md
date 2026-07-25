# Kofun Arcade — Macroquad / Rust

Macroquad で実装した、960×540 の軽量な7ゲーム・アーケードです。画像や音声などの外部素材は必須ではなく、図形描画だけで全モードを遊べます。

## 起動

Rust stable を用意し、このディレクトリで実行します。

```sh
cargo run --release
```

開発時の確認:

```sh
cargo fmt --check
cargo check
cargo clippy --all-targets -- -D warnings
```

## 操作

- メニュー: `↑` / `↓` と `Enter`、または数字 `1`〜`7`
- 各ゲーム: 画面上部の操作ガイドを参照
- `Esc`: いつでもメニューへ戻る
- 勝敗表示中の `Enter`、または `R`: 現在のゲームを最初からやり直す

## 実装概要

1. Kofun Courier — 45秒以内に8個回収。WASD/矢印で移動し、追跡する敵を避けます。接触すると即失敗です。
2. Mound Breaker — 5×10ブロックを3ライフで破壊します。
3. Haniwa Tap Patrol — 30秒以内に12個のターゲットをクリック。デコイは残り時間を3秒奪います。
4. Dochicken Sky Dodge — Space/↑/クリックで羽ばたき、10ゲートを通過します。
5. Neon Kofun Dash — Space/↑/クリックまたはタッチで障害物を跳び越え、30秒走り切ります。
6. Kofun Orbit — WASD/矢印で移動、Spaceのパルスで敵を押し返し、接触せず30秒生存します。
7. Kofun Snake — 矢印/WASDで進み、15個のフードを集めます。

単一の状態機械でメニュー、プレイ、勝敗、リスタートを管理し、各モードは独立した状態を持ちます。フレーム時間を上限付きで扱うため、一時停止後の大きな座標飛びも抑えています。
