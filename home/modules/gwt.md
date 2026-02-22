# gwt - git worktree マネージャー

git bare clone + worktree パターンでの開発を支援する CLI ツール。
worktree の作成・削除に加え、gitignored ファイル（`.envrc`, `.mcp.json` 等）の管理を自動化する store 機能を持つ。

## 基本操作

```bash
gwt add                          # worktree を作成して VSCode で開く
gwt add -b feature/foo           # ブランチ名を指定して作成
gwt add -b feature/foo -f main      # main から分岐して作成
gwt rm                           # fzf で選択して worktree を削除
gwt rm -f                        # 未コミットの変更があっても強制削除
```

`gwt add` はブランチ名省略時に `<git-user>/yyyy-mm-dd-N` を自動生成する。

## store 機能

worktree 間で共有したい gitignored ファイルを一元管理する。
store は `<git-common-dir>/worktree-store/` に作られ、manifest でファイルと strategy を記録する。

### セットアップ

```bash
gwt init                         # store を初期化（冪等）
gwt track -s symlink .envrc      # symlink で追跡（ファイルを即座にリンクに変換）
gwt track -s symlink .mcp.json
gwt track -s copy .env.local     # copy で追跡（worktree ごとに内容を変えたい場合）
```

### 運用

```bash
gwt status                       # 各ファイルの状態を表示（OK / MISSING / MODIFIED 等）
gwt push                         # copy ファイルの変更を store に反映（全件）
gwt push .env.local              # 特定ファイルだけ反映
gwt add -b feature/bar           # 新 worktree 作成時に store から自動配布
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
