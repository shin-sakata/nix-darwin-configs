# AGENTS.md

## 概要
AGENTS.md は LLM AGENT 向けに書かれた README.md である

## リポジトリ概要

- shin の個人的な M5 MacBook Pro の構成管理を `nix-darwin` + `nix-homebrew` + `home-manager` にて宣言的に管理している
- 利用技術
  - `nix-darwin`
    - システムレベルのものを管理している
  - `nix-homebrew`
    - 原則として GUI アプリケーションの管理を行うために利用
    - macOS では GUI アプリケーションはシステムレベルで管理されていた方が良いとされている
  - `home-manager`
    - ユーザーレベルの構成を管理
    - dotfiles や CLI アプリケーション等

## リポジトリ構造
```
% tree -L 5 --filelimit 30 -a -I .git
.
├── .cursorrules -> AGENTS.md
├── .github
│   └── copilot-instructions.md -> ../AGENTS.md
├── .gitignore
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── flake.lock
├── flake.nix
├── home
│   ├── modules
│   │   ├── cursor.nix
│   │   ├── direnv.nix
│   │   ├── git.nix
│   │   ├── ssh.nix
│   │   ├── vscode
│   │   │   └── settings.vscode.jsonc
│   │   ├── vscode.nix
│   │   └── zsh.nix
│   └── shin.nix
└── README.md

5 directories, 16 files
```

### `flake.nix`
- 構成管理のエントリーポイントである
- `nix-darwin` と `nix-homebrew` の内容の管理と `home-manager` の import 等を行っている

### `home/`
- `home-manager` によって user の管理を行う。現状、そしてこれからも `shin` しか使わない予定

## AGENT としてのルール
- 常に日本語で解答せよ

## マシン管理の哲学
- Infrastructure as Code を心がけ、すべての設定は code 化させる

### nix-darwin における例外
- casks 等、完全にバージョンをコード管理できないものがある。それらについては homebrew-casks にまかせインストールの要否だけをチェックする
  - casks のパッケージの羅列から削除されれば PC からも削除されたい
- GUI アプリケーションと CLI アプリケーションの連携の設定
  - 1password GUI と 1password cli, 1password SSH Agent の連携については別途 GUI から設定を行う必要がある
  - 1password GUI アプリを開き、cli と ssh agent の設定を有効化させる

## COMMANDS
- `nix fmt .`
- `nix flake update`
- `sudo darwin-rebuild check --flake .`
- `sudo darwin-rebuild switch --flake .`
  - このコマンドはシステムの変更が入るため、変更点等を確認し慎重に行うか、ユーザーに任せる
