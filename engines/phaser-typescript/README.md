# Phaser 3.90 + TypeScript

7ゲームを1つのPhaser Sceneに収録したWeb版です。図形描画と手動collisionを
使い、各ゲームのロジック差を読み比べやすくしています。

```bash
npm ci
npm run dev
```

- 数字 `1`〜`7` または上下 + Enter: ゲーム選択
- 矢印/WASD、Space、マウス/タッチ: ゲーム操作
- touch端末: 画面の方向・action・menu button、Snakeはswipeにも対応
- Enter: 終了後に再開
- Escape: メニュー

`npm run build` で `dist/` に静的Web版を生成します。GitHub Pagesでは
調査サイトの `/play/` に配置されます。

```bash
npm test
npm run smoke:browser
```

`npm test` はmenu hit area、delta上限、Snake collision、swipeを検査します。
`smoke:browser` はproduction buildをheadless Firefoxで開き、全7 modeが
960×540 Canvas上で複数frame動作し、runtime errorがないことを検査します。
FirefoxがPATHにない場合は `FIREFOX_BIN` で指定できます。
