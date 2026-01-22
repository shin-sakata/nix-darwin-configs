{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
  claude-code-nix = inputs.claude-code-nix.packages.${system};
in
{
  home.packages = [
    agents.gemini-cli
    agents.codex
    agents.opencode
    # agents.claude-code 現在 bun ランタイム環境で動作しないため
    claude-code-nix.claude-code
  ];

  # OpenCode global rules
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

  # Claude Code 用のシンボリックリンク
  home.file."CLAUDE.md" = {
    source = ./AGENTS.md;
  };
}
