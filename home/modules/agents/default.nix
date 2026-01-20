{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
in
{
  home.packages = [
    agents.claude-code
    agents.gemini-cli
    agents.codex
    agents.opencode
  ];

  # AGENTS.md をホームディレクトリに配置
  home.file.".config/AGENTS.md" = {
    source = ./AGENTS.md;
  };

  # OpenCode 用の設定ファイルへのシンボリックリンク
  home.file."AGENTS.md" = {
    source = ./AGENTS.md;
  };

  # Cursor 用のシンボリックリンク
  home.file.".cursorrules" = {
    source = ./AGENTS.md;
  };

  # Claude Code 用のシンボリックリンク
  home.file."CLAUDE.md" = {
    source = ./AGENTS.md;
  };
}
