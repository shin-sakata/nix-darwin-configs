{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
in
{
  home.packages = [
    agents.claude-code
  ];

  # Claude Code 用のシンボリックリンク
  home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;
}
