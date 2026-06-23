# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## 概要

shin の M5 MacBook Pro (aarch64-darwin) の構成管理リポジトリ。すべての設定を宣言的に管理する。Nix 互換実装の **Lix** を使用。

**重要**: このリポジトリは必ず `~/Projects/shin-sakata/nix-darwin` に配置する。アウトオブストア・シンボリックリンク（後述）がこの絶対パスに依存しているため、場所を変えると一部の設定リンクが壊れる。

## アーキテクチャ

3つのレイヤーで構成管理を行う:

- **nix-darwin** (`flake.nix`): システムレベル設定（sudoers、電源管理、Nix 設定、メニューバー）
- **nix-homebrew** (`flake.nix` の `homebrew.casks`): GUI アプリケーションのインストール管理。バージョン管理は Homebrew に委任し、リストから削除すればアンインストールされる (`cleanup = "zap"`)
- **home-manager** (`home/shin.nix` → `home/modules/`): ユーザーレベル設定（CLI ツール、dotfiles、シェル設定）

エントリーポイントは `flake.nix`。darwin 構成名は `shinnoMacBook-Pro`。nix-homebrew と home-manager はどちらも nix-darwin の module として統合されている。

### 設定ファイルの2つの管理方式（重要）

home-manager の dotfiles は2方式を使い分けている:

1. **Nix store 経由（通常）**: モジュール内で宣言した設定（例: `programs.git.settings`、`programs.zsh`）。ビルド時に store に焼き込まれ、読み取り専用でリンクされる。変更には `darwin-rebuild switch` が必要
2. **アウトオブストア・シンボリックリンク** (`config.lib.file.mkOutOfStoreSymlink`): **アプリ自身が動的に書き換える**設定ファイルを、Nix store を経由せずリポジトリ内の実ファイルへ直接リンクする。対象は Codex (`~/.Codex/AGENTS.md`, `settings.json`)、VSCode、OpenCode の各設定。`darwin-rebuild` なしでアプリが設定を書き換えられ、その変更がそのままリポジトリに反映される

方式2は `flakeRelPath`（`flake.nix` の `home-manager.extraSpecialArgs` で各モジュールに渡される相対パス `Projects/shin-sakata/nix-darwin`）に依存する。これが冒頭の「配置場所固定」の理由。

### home-manager モジュール構成

`home/shin.nix` がエントリーポイント。各ツールの設定は `home/modules/` 以下に分離（git, ssh, zsh, tmux, direnv, vscode, agents）。

- `agents/default.nix`: LLM エージェント (`Codex` / `codex` / `opencode`) を `llm-agents.nix` flake 経由でインストール。`~/.Codex/AGENTS.md` の実体は **`home/modules/agents/AGENTS.md`**（全プロジェクト共通のエージェント規則）で、これを編集するとグローバルなエージェント動作が変わる。ralph-* スラッシュコマンドと OpenCode 設定もここでリンク。`settings.json` で永続化されない。

### 注意すべき flake inputs

- `llm-agents` (`github:numtide/llm-agents.nix`): LLM エージェント (Codex/codex/opencode) の提供元。バイナリキャッシュ `cache.numtide.com` を substituter に設定済み

## コマンド

```bash
# フォーマット（nixfmt-tree）
nix fmt .

# flake 依存関係の更新
nix flake update

# 構成のビルド（適用前の検証、システム変更なし。sudo 不要）
darwin-rebuild build --flake .

# 構成の適用（システム変更を伴うため慎重に。ユーザーに確認を取ること）
sudo darwin-rebuild switch --flake .

# 初回セットアップ（新規マシン構築時のみ）
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .

# ガベージコレクション
sudo nix-collect-garbage --delete-older-than 7d

# ストア最適化（5分以上かかる場合あり）
sudo -H nix store optimise
```

## ルール

- 常に日本語で解答せよ
- フォーマッタは `nixfmt-tree`（`nix fmt .` で実行）
- `darwin-rebuild switch` はシステムに変更を加えるため、必ず変更内容を説明しユーザーの確認を得てから実行する。検証だけなら `darwin-rebuild build` を使う
- GUI アプリの追加/削除は `flake.nix` の `homebrew.casks` を編集する。`brew` コマンドは zsh で意図的に無効化されており、直接実行するとエラーになる（宣言的管理を強制）

## nix-darwin における例外

- casks は完全にバージョンをコード管理できない。インストールの要否のみ管理する
- 1Password の GUI と CLI/SSH Agent の連携は GUI から手動設定が必要
