# Kofun Game Matrix

[![CI](https://github.com/hjosugi/kofun-game/actions/workflows/ci.yml/badge.svg)](https://github.com/hjosugi/kofun-game/actions/workflows/ci.yml)
[![GitHub Pages](https://github.com/hjosugi/kofun-game/actions/workflows/pages.yml/badge.svg)](https://hjosugi.github.io/kofun-game/)

7つの小さなゲームを7つの軽量ゲームエンジンへ同じ仕様で実装し、
開発体験・実行性能・配布方法の違いを比較する実験リポジトリです。

**7 games × 7 engines = 49 playable implementations**

## 収録ゲーム

| # | ゲーム | ジャンル | クリア条件 |
|---:|---|---|---|
| 1 | Kofun Courier | 回収アクション | 敵を避けて埴輪を8個集める |
| 2 | Mound Breaker | ブロック崩し | 50個の墳丘ブロックをすべて壊す |
| 3 | Haniwa Tap Patrol | タップゲーム | 30秒以内に埴輪を12回タップする |
| 4 | Dochicken Sky Dodge | フラップ回避 | 10本のゲートを通過する |
| 5 | Neon Kofun Dash | ランナー | 障害物を避けて30秒生き残る |
| 6 | Kofun Orbit | アリーナ | パルスで敵を退けて30秒生き残る |
| 7 | Kofun Snake | スネーク | 埴輪を15個集める |

## 対応エンジン

- Godot 4 + GDScript
- raylib 6.0 + C11
- Defold + Lua
- LÖVE 11 + Lua
- Phaser 3.90 + TypeScript
- Macroquad + Rust
- Ebitengine 2.9 + Go

各プロジェクトは `engines/` 以下にあります。起動方法は各ディレクトリの
READMEと [共通仕様](docs/game-spec.md) を参照してください。

## 開発環境

Nixがある場合は、リポジトリ直下で次を実行します。

```bash
nix develop
just check
```

個別に導入する場合は [環境構築ガイド](docs/development.md) を参照してください。
Defold Editorだけは公式配布物を使用します。

## Web版

Phaser版は7ゲームすべてをブラウザでプレイできます。GitHub Pagesには
調査結果・49実装の一覧・プレイ画面をまとめて公開します。

- [調査サイト / 49実装 / ブラウザ版を開く](https://hjosugi.github.io/kofun-game/)

ローカル起動:

```bash
cd engines/phaser-typescript
npm ci
npm run dev
```

## Issueと改善

- 不具合: [構造化バグ報告](https://github.com/hjosugi/kofun-game/issues/new?template=bug_report.yml)
- 改善案: [機能提案](https://github.com/hjosugi/kofun-game/issues/new?template=feature_request.yml)
- 開発手順: [CONTRIBUTING.md](CONTRIBUTING.md)
- 完了条件・手動QA: [品質基準](docs/quality.md)

## 出典とライセンス

ソースコードは [0BSD](LICENSE) です。キャラクター素材は
[`kofun-friends`](https://github.com/hjosugi/kofun-friends) by hjosugi
（CC BY 4.0）を使用します。詳細は [ASSETS.md](ASSETS.md) を参照してください。
