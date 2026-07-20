# コトノコ (Kotonoko)

コトノコ (言の庫, Kotonoko) は、macOS 上で動作する EPWING 辞書ビューアです。
本リポジトリは、最近の macOS および Apple Silicon (M1/M2/M3/M4) / Intel 環境に対応させた修正版フォークです。

オリジナルは[こちら](https://github.com/attgm/kotonoko)
---

## 修正点および変更内容

### 1. 最新 macOS および Apple Silicon (arm64 & x86_64) 対応
- Universal Binary (arm64 および x86_64) に対応。
- Xcode 15/16 形式のビルド設定への適合。

### 2. EPWING 解析ライブラリ (eblib) の修正
- **EPWING カタログ構造体定数の復元**: `eblib` 内の定数不整合を修復し、EPWING 辞書の検索インデックスが読み込めない不具合を修正。
- **EBZIP 圧縮インデックス読み込み時のバッファオーバーフロー修正**: `zio.c` におけるローカルバッファ溢れ (`__stack_chk_fail` / SIGABRT) を修復。

### 3. アプリケーション動作および GUI の改善
- **本文表示処理の修復**: 単語選択時に本文テキストが除外され空白表示になる問題を修正。
- **辞書 ID 識別ロジックの修正**: 辞書セット設定やクイックタブで辞書が認識されない問題を修正。
- **ディレクトリ走査の最適化**: `isEPWINGDirectory:` による事前チェック、パッケージ (`.app`, `.framework` 等) およびシンボリックリンクのスキップ処理を追加し、フォルダ追加・削除時のクラッシュを防止。
- **KVO 通知種別の正規化**: 配列変更通知の種別（削除時の `NSKeyValueChangeRemoval`）を修正。

---
## バイナリーリリース

Github Release ページにて、macOS 用のビルド済みバイナリを配布しています。

## ビルドおよびインストール手順

### 必要環境
- macOS 11.0 以降
- Xcode または Command Line Tools

#### 準備: Command Line Tools のインストール
ターミナルで以下を実行します。
```bash
xcode-select --install
```

### ビルド手順

1. リポジトリのクローン:
   ```bash
   git clone https://github.com/YOUR_USERNAME/kotonoko.git
   cd kotonoko
   ```

2. 依存ライブラリ (eblib) のコンパイル:
   ```bash
   cd eblib/eb-4.4.3
   ./configure
   make
   cd ../..
   ```

3. コトノコ本体のビルド (Release ビルド):
   ```bash
   xcodebuild -project ebooks.xcodeproj -target kotonoko -configuration Release build
   ```
   ビルド完了後、`build/Release/kotonoko.app` が生成されます。

4. アプリケーションの配置:
   ```bash
   cp -R build/Release/kotonoko.app /Applications/
   ```

---

### 初回起動時の注意事項 (未署名アプリの起動)
開発者署名がないため、macOS の Gatekeeper により警告が表示される場合があります。

- **GUIで開く場合**: `kotonoko.app` を Control キーを押しながらクリックし、「開く」を選択してください。
- **ターミナルで属性解除する場合**:
  ```bash
  xattr -cr /Applications/kotonoko.app
  ```

---

## ライセンス

本ソフトウェアは `LICENCE.md` に定める BSD 3-Clause License に従います。

Copyright (c) 1998-2012 Atsushi Tagami. All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the conditions in `LICENCE.md` are met.
