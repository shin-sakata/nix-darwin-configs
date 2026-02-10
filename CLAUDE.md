# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

shin の M5 MacBook Pro (aarch64-darwin) の構成管理リポジトリ。すべての設定を宣言的に管理する。

## アーキテクチャ

3つのレイヤーで構成管理を行う:

- **nix-darwin** (`flake.nix`): システムレベル設定（sudoers、電源管理、Nix 設定）
- **nix-homebrew** (`flake.nix` の `homebrew.casks`): GUI アプリケーションのインストール管理。バージョン管理は Homebrew に委任し、リストから削除すればアンインストールされる (`cleanup = "zap"`)
- **home-manager** (`home/shin.nix` → `home/modules/`): ユーザーレベル設定（CLI ツール、dotfiles、シェル設定）

エントリーポイントは `flake.nix`。home-manager は nix-darwin の module として統合されている。

## コマンド

```bash
# フォーマット
nix fmt .

# flake 依存関係の更新
nix flake update

# 構成チェック（適用前の検証）
sudo darwin-rebuild check --flake .

# 構成の適用（システム変更を伴うため慎重に。ユーザーに確認を取ること）
sudo darwin-rebuild switch --flake .

# ガベージコレクション
sudo nix-collect-garbage --delete-older-than 7d

# ストア最適化（5分以上かかる場合あり）
sudo -H nix store optimise
```

## ルール

- 常に日本語で解答せよ
- フォーマッタは `nixfmt-tree`（`nix fmt .` で実行）
- `darwin-rebuild switch` はシステムに変更を加えるため、必ず変更内容を説明しユーザーの確認を得てから実行する
- 破壊的な変更を行う前にユーザーの確認を取れ
- SSH キーと Git 署名は 1Password 経由で管理されている。機密情報をコードに含めないこと
- 新しいモジュールを追加した場合は `home/shin.nix` の `imports` に追加が必要

## nix-darwin における例外

- casks は完全にバージョンをコード管理できない。インストールの要否のみ管理する
- 1Password の GUI と CLI/SSH Agent の連携は GUI から手動設定が必要
