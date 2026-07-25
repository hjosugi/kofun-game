# 品質基準

この文書は「7 games × 7 engines」を、完成したゲームとして維持するための
確認基準です。pixel表現や同一の内部実装は必須ではありません。engineごとに
作りやすい表現を選びつつ、遊び方と判定の公平性を守ります。

## Doneの定義

変更は次の条件を満たしたときに完了です。

1. [共通ゲーム仕様](game-spec.md)の成功、失敗、入力条件と一致する。
2. game開始、通常play、成功、失敗、再開、menu復帰に到達できる。
3. frame rateの一時低下後も、極端な座標飛びや即時終了を起こさない。
4. 960×540でHUD、操作説明、結果表示が読める。
5. 対象engineのbuild/testが成功し、共通変更では`just check`が成功する。
6. 未確認のOS、GPU、入力方式が変更説明に明記されている。

## 自動検査

Nix環境ではrepository rootから全検査を実行します。

```bash
nix develop
just check
```

`just check`は次の検査をまとめて実行します。

- repository構造と49実装のPython unit test
- Phaserのunit test、TypeScript production build、Firefoxでの7ゲームsmoke test
- Defold / LÖVEのLua syntax
- Macroquadのformat、check、test、Clippy
- Ebitengineのformat、test、vet、race test
- Godotのheadless smoke test
- Defold Bob buildとruntime smoke test
- raylibのCMake buildとルール境界テスト

GitHub Actionsではrepository構造と7つのengineを8個の独立jobに分け、同時に
実行します。npm、Go、Cargo、Godot、Defold、raylibの依存・SDKはcacheし、
失敗したengineをほかのbuild完了まで待たずに判別できます。

ドキュメントだけの変更でも、linkやcommandが現在のtreeと一致するか確認します。

## 手動playの共通チェック

各engineで、変更に関係する経路を最低1回確認します。

| 場面 | 確認すること |
|---|---|
| Menu | `1`〜`7`、上下 + `Enter`で意図したgameが始まる |
| Play | HUDのgame名、操作、scoreまたは残り時間が読める |
| Result | 成功と失敗が区別でき、`Enter`で同じgameを再開できる |
| Navigation | `Esc`でいつでもmenuへ戻れる |
| Pointer | Tap Patrol、Sky Dodge、Neon Dashでmouse/touchが機能する |
| Stability | window focus復帰後にgame stateが大きく飛ばない |

game固有の重要経路も確認します。

| Game | 成功経路 | 失敗・penalty経路 |
|---|---|---|
| Kofun Courier | 45秒以内に8個回収 | 敵接触、時間切れ |
| Mound Breaker | 50block破壊 | ballを3回落とす |
| Haniwa Tap Patrol | 30秒以内にtargetを12回押す | decoyで残り時間が3秒減る |
| Dochicken Sky Dodge | 10gate通過 | 障害物または画面端に接触 |
| Neon Kofun Dash | 30秒生存 | 障害物に接触 |
| Kofun Orbit | pulseで敵を退け30秒生存 | 敵に接触 |
| Kofun Snake | 埴輪を15個回収 | 壁または自分の列に接触 |

## 描画・低スペック環境

描画問題の報告と検証では、OSだけでなくGPU、driver、rendererを記録します。
WSL、仮想machine、remote desktopなどで通常起動できない場合は、問題を隠すため
ではなく描画経路を切り分けるため、software起動も比較します。

```bash
just play-love-software
just play-godot-software
just play-raylib-software
just play-rust-software
just play-go-software
```

次の点を目視します。

- 文字が`?`や空白へ置換されていない
- 文字と背景に十分なcontrastがある
- object、hitbox、targetとdecoyを見分けられる
- 画面外に重要なUIがはみ出さない
- software rendererでもgame speedとtimerが大きく変わらない

## 不具合の再現記録

再現手順には次を残します。

- engineとgame
- commit SHAまたは公開URL
- OS、version、CPU architecture
- GPU、driver、renderer
- Nix、公式SDK、browserなどの起動方法
- 最小の再現手順、期待する動作、実際の動作
- 再現頻度と、可能ならterminal logまたは画像

修正確認では、元の手順で再現しないことに加え、隣接する成功・失敗経路も1つ
確認します。共通仕様の不具合は、1実装の修正だけでcloseせず、7エンジンの差分を
確認します。
