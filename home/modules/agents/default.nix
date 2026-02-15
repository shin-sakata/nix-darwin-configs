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

  # Claude Code カスタムエージェント
  home.file.".claude/agents/spec-writer.md".source = ./claude-agents/spec-writer.md;
}
