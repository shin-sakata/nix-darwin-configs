---
description: "検証エビデンスから PR 用の markdown を生成する"
argument-hint: "[issue-id]"
---

# Ralph PR: 検証レポート → PR Description 生成

ralph-loop で蓄積されたエビデンス（`agent_docs/{issue-id}/`）を読み取り、PR description 用の markdown ファイルを生成する。PR の作成自体は行わない。

## 入力

$ARGUMENTS が指定されている場合、それを issue-id として扱う。

指定がない場合は `agent_docs/` 配下のディレクトリ一覧を提示し、ユーザーに選択してもらう。

## 前提条件

以下のディレクトリ構造が存在すること:

```
agent_docs/{issue-id}/
  screenshots/                  ← スクリーンショット（任意）
  logs/                         ← ログの抜粋（任意）
  task-breakdown.md             ← タスク分解ドキュメント（任意）
  verification-report.local.md  ← 検証結果サマリー（任意）
```

全てのファイルが揃っている必要はない。存在するものから最大限の情報を抽出する。

## 処理手順

### Step 1: エビデンスの収集

`agent_docs/{issue-id}/` 配下の全ファイルを読み取り、以下を把握する:

- **変更の概要**: 何が問題で、何を修正したか
- **検証結果**: どのような検証を行い、結果はどうだったか
- **スクリーンショット**: UI の Before/After（存在する場合）
- **ログ**: エラーの再現と修正の証拠（存在する場合）
- **テスト結果**: テストの実行結果（存在する場合）

### Step 2: git diff の確認

現在のブランチの変更内容を `git diff` と `git log` で確認し、実際のコード変更を把握する。エビデンスとコード変更を突き合わせて、漏れがないか確認する。

### Step 3: PR markdown の生成

以下の構成で `agent_docs/{issue-id}/pr-description.md` を生成する:

```markdown
## Summary

[1-3 行で変更の概要を説明]

## Background

[問題の背景。なぜこの変更が必要か]

## Changes

[変更内容の箇条書き。対象ファイルと変更の意図]

## Verification

[検証結果のサマリー。以下を含む:]

### Test Results
[テスト実行結果があれば記載]

### UI Verification
[スクリーンショットがあれば Before/After で掲載]

### Log Verification
[ログでの確認結果があれば記載]

## Test Plan

[レビュワーが手動で確認する場合の手順]

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Step 4: ユーザーへの提示

生成した markdown のパスと内容をユーザーに提示する。

ユーザーが PR を作成したい場合に使えるコマンド例も添える:

```bash
gh pr create --title "[タイトル]" --body-file agent_docs/{issue-id}/pr-description.md
```

## 重要な注意事項

- **PR の作成は行わない**。markdown の生成のみ
- エビデンスが不足している場合は、不足箇所を明示してユーザーに報告する
- スクリーンショットを PR description に含める場合、リポジトリにコミットされている必要がある旨をユーザーに伝える
- 検証結果が失敗を示している場合は、その旨を正直に記載する。成功に見せかけない
- markdown は簡潔に。レビュワーが短時間で変更の全体像を掴めることを優先する
