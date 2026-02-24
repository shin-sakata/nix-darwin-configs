---
name: ws
description: git worktree の作成・削除・状態確認を行う。同一リポジトリで並行作業が必要なとき、または worktree の状態を把握したいときに使用する。
---

# ws（git worktree マネージャー）

## コマンド

```bash
# 管理下の全リポジトリと worktree の状態を俯瞰
ws status

# 新しい worktree を作成（ブランチも自動作成、../<name> に配置）
ws new <name>

# worktree を削除
ws rm <name>
```

## 注意事項

- worktree は親ディレクトリ配下（`../<name>`）に作成される
- 作業完了後は `ws rm` で不要な worktree を削除すること
