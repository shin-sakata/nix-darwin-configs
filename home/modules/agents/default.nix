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
      ];
      defaultMode = "plan";
      additionalDirectories = [
        "/Users/shin/Projects/shin-sakata"
      ];
    };
    enabledPlugins = {
      "claude-md-management@claude-plugins-official" = true;
    };
    language = "日本語";
  };

  # Claude Code カスタムエージェント
  home.file.".claude/agents/project-init.md".source = ./claude-agents/project-init.md;
  home.file.".claude/agents/spec-writer.md".source = ./claude-agents/spec-writer.md;
  home.file.".claude/agents/spec-executor.md".source = ./claude-agents/spec-executor.md;
  home.file.".claude/agents/spec-verifier.md".source = ./claude-agents/spec-verifier.md;
}
