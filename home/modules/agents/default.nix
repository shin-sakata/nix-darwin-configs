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

  # Claude Code のグローバル設定
  home.file.".claude/settings.json".text = builtins.toJSON {
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
    permissions = {
      allow = [
        "Bash"
        "WebFetch"
        "WebSearch"
        "mcp__ide__getDiagnostics"
      ];
      additionalDirectories = [
        "/Users/shin/Projects/shin-sakata"
      ];
    };
    enabledPlugins = {
      "claude-md-management@claude-plugins-official" = true;
      "ralph-loop@claude-plugins-official" = true;
    };
    hooks = {
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "osascript -e 'display notification \"Claude が完了しました\" with title \"Claude Code\" sound name \"Glass\"'";
            }
          ];
        }
      ];
      Notification = [
        {
          hooks = [
            {
              type = "command";
              command = "osascript -e 'display notification \"Claude が入力を待っています\" with title \"Claude Code\" sound name \"Submarine\"'";
            }
          ];
        }
      ];
    };
    language = "日本語";
  };
}
