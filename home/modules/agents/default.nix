{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
in
{
  home.packages = [
    agents.claude-code
    agents.codex
  ];

  # Claude Code 用のシンボリックリンク
  home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;
  home.file.".claude/commands/ralph-setup.md".source = ./commands/ralph-setup.md;
  home.file.".claude/commands/ralph-pre-setup.md".source = ./commands/ralph-pre-setup.md;
  home.file.".claude/commands/ralph-pr.md".source = ./commands/ralph-pr.md;
  home.file.".claude/skills/ws/SKILL.md".source = ./skills/ws/SKILL.md;

  # Claude Code のグローバル設定
  # settings.json は Claude Code / Cowork が動的に書き換えるため home-manager 管理外とする
}
