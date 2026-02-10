{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
in
{
  home.packages = [
    agents.codex
    agents.opencode
    agents.claude-code
  ];

  # OpenCode global rules
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

  # Claude Code 用のシンボリックリンク
  home.file.".claude/CLAUDE.md" = {
    source = ./AGENTS.md;
  };
}
