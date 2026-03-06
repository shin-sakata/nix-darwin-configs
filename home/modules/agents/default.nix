{
  pkgs,
  config,
  inputs,
  flakeRelPath,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
  flakePath = "${config.home.homeDirectory}/${flakeRelPath}";
in
{
  home.packages = [
    agents.claude-code
    agents.codex
    agents.opencode
  ];

  # Claude Code 用のシンボリックリンク
  home.file.".claude/commands/ralph-setup.md".source = ./commands/ralph-setup.md;
  home.file.".claude/commands/ralph-pre-setup.md".source = ./commands/ralph-pre-setup.md;
  home.file.".claude/commands/ralph-pr.md".source = ./commands/ralph-pr.md;
  home.file.".claude/skills/ws/SKILL.md".source = ./skills/ws/SKILL.md;

  # Nix store を経由せず直接シンボリックリンク
  # CLAUDE.md と settings.json は Claude Code が動的に書き換えるため
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/modules/agents/CLAUDE.md";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/claude/settings.json";

  # OpenCode のグローバル設定
  xdg.configFile."opencode/opencode.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/opencode/opencode.jsonc";
  xdg.configFile."opencode/tui.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/opencode/tui.jsonc";
}
