# ws - workspace (git worktree) マネージャー

git bare clone + worktree パターンでの開発を支援する CLI ツール。
worktree の作成・削除に加え、gitignored ファイル（`.envrc`, `.mcp.json` 等）の管理を自動化する shared 機能を持つ。

## ワークフロー

### bare 構成（推奨）

```bash
ws init <url>                      # bare clone して .bare/ を作成
ws new main                        # 同階層に worktree を作成して VSCode で開く
ws new feature/foo                 # ブランチ名を指定して作成
ws new feature/foo --from main     # main から分岐して作成
```

ディレクトリ構造:

```
my-project/
├── .bare/                         # bare リポジトリ（git clone --bare で作成）
├── main/                          # worktree
├── feature-foo/                   # worktree
└── .worktree-store/               # shared 機能の store（任意）
```

### 通常構成

既存の git clone リポジトリ内で `ws new` を使う。

```
my-project/                        # 通常の git リポジトリ（.git/ あり）
└── .worktrees/                    # worktree はリポジトリ内に作成される
    └── feature-foo/
```

### URL なしの bare 構成

```bash
mkdir my-project && cd my-project
ws init                            # 空の bare リポジトリを作成
ws new master                      # orphan ブランチで worktree を作成
```

## 基本操作

```bash
ws init [url]                      # bare リポジトリを初期化（URL 省略で空リポジトリ）
ws new [branch]                    # worktree を作成して VSCode で開く
ws new [branch] --from <ref>       # 指定した起点から分岐して作成
ws rm                              # fzf で選択して worktree を削除
ws rm -f                           # 未コミットの変更があっても強制削除
ws list                            # worktree 一覧を表示
ws status                          # worktree の状態を表示
ws i                               # fzf で選択して worktree を VSCode で開く
```

`ws new` はブランチ名省略時に `<git-user>/yyyy-mm-dd-N` を自動生成する。

## 共有ファイル管理 (ws shared)

worktree 間で共有したい gitignored ファイルを一元管理する。
store は `<git-common-dir>/worktree-store/` に作られ、manifest でファイルと strategy を記録する。

### セットアップ

```bash
ws shared init                     # store を初期化（冪等）
ws shared track -s symlink .envrc  # symlink で追跡（ファイルを即座にリンクに変換）
ws shared track -s symlink .mcp.json
ws shared track -s copy .env.local # copy で追跡（worktree ごとに内容を変えたい場合）
```

### 運用

```bash
ws shared status                   # 各ファイルの状態を表示（OK / MISSING / MODIFIED 等）
ws shared push                     # copy ファイルの変更を store に反映（全件）
ws shared push .env.local          # 特定ファイルだけ反映
ws shared pull                     # store から全追跡ファイルを配布（既存はスキップ）
ws shared pull .envrc              # 特定ファイルだけ配布
ws shared pull -f                  # 既存ファイルを上書きして配布
ws new feature/bar                 # 新 worktree 作成時に store から自動配布
```

### strategy の違い

| strategy | 動作 | 用途 |
|----------|------|------|
| `symlink` | store 内ファイルへのシンボリックリンクを作成 | 全 worktree で同じ内容を共有したいファイル |
| `copy` | store からファイルをコピー | worktree ごとに内容をカスタマイズしたいファイル |

## store のディレクトリ構造

```
<git-common-dir>/worktree-store/
├── manifest         # "strategy:filepath" の行形式
├── .mcp.json        # マスターコピー
├── .envrc           # マスターコピー
└── .env.local       # マスターコピー
```
