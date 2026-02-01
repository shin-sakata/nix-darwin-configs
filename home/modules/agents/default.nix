{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
  claudeCodeBun = inputs.claude-code-nix.packages.${system}.claude-code-bun.override {
    bunBinName = "claude";
  };
in
{
  home.packages = [
    agents.gemini-cli
    agents.codex
    agents.opencode
    # agents.claude-code
    claudeCodeBun
  ];

  # OpenCode global rules
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

  # Claude Code 用のシンボリックリンク
  home.file."CLAUDE.md" = {
    source = ./AGENTS.md;
  };
}
