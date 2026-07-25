# Contributing

Kofun Game Matrixへの改善提案を歓迎します。日本語・英語のどちらでも構いません。
このプロジェクトでは、7つのゲームを7つのエンジンで同じ条件にそろえつつ、
各エンジンらしい実装を比較できることを重視しています。

## はじめに

不具合は
[バグ報告](https://github.com/hjosugi/kofun-game/issues/new?template=bug_report.yml)、
改善案は
[機能提案](https://github.com/hjosugi/kofun-game/issues/new?template=feature_request.yml)
から共有してください。既存issueも検索し、関連するものがあれば新規作成せず、
追加の再現情報をコメントしてください。

セキュリティに関係しないクラッシュログや画像はissueへ添付できますが、
token、個人情報、ローカルのユーザー名を必ず削除してください。

## 開発環境

推奨環境はNixです。

```bash
nix develop
just check
```

個別の導入方法とOpenGL / EGLエラーへの対処は
[開発環境ガイド](docs/development.md)を参照してください。変更対象を素早く確認する
場合は、`justfile`にある`check-phaser`、`check-rust`、`check-go`などの個別recipeを
使えます。

## 変更の進め方

1. issueで問題、対象engine・game、完了条件を明確にします。
2. `main`から目的がわかる短いbranch名を作ります。
3. まず対象実装で変更し、共通仕様への影響を確認します。
4. 共通ルールを変える場合は7エンジンすべてを同期します。
5. 自動検査と手動プレイを行い、結果を変更説明に残します。

ゲームルールの基準は[共通ゲーム仕様](docs/game-spec.md)です。演出や内部構造は
同一である必要はありませんが、クリア条件、失敗条件、主要入力、再開・メニュー
遷移は一致させてください。

## 変更範囲ごとの確認

| 変更 | 必須の確認 |
|---|---|
| 1エンジンの修正 | 対象engineのbuild/test、変更したgameの成功・失敗経路 |
| 共通ゲームルール | 7エンジンで同じ条件、`docs/game-spec.md`、49実装一覧 |
| 入力・UI | keyboard、対応するmouse/touch、`Enter`再開、`Esc`メニュー |
| Phaser・サイト | `npm test`、`npm run build`、`python3 tests/browser_smoke.py` |
| Nix・CI | `nix flake check --no-build --all-systems`、`just check` |
| 素材 | 出典、作者、licenseを`ASSETS.md`へ記載 |

詳細な確認観点は[品質基準](docs/quality.md)にまとめています。

GitHub Actionsでは、repository構造と7つのengineを独立jobとして並列検査します。
engine間に不要な依存を追加せず、対象engineのjobだけで再現できる変更にしてください。

## Pull request

変更説明には次を含めてください。

- 解決するissueと利用者への影響
- 変更したengine・game
- 実行した自動検査と結果
- 手動で確認した成功・失敗・再開経路
- UI変更がある場合は画像または短い動画
- 未確認のOS、GPU、engine SDKがある場合はその範囲

依存更新や大きな整形は、ゲーム修正と分けてください。生成物の`build/`、`dist/`、
`target/`、秘密情報はcommitしないでください。

## 素材とライセンス

このrepositoryのcode licenseは[0BSD](LICENSE)です。画像、音声、fontなど
第三者の素材を追加する場合は、再配布と改変が許可されていることを確認し、
[ASSETS.md](ASSETS.md)へ出典とlicenseを記録してください。
