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
  codexSakanaProxyPort = "8787";
  codexSakanaProxyScript = ../../config/codex/sakana-tool-strip-proxy.py;
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

  # Codex app / CLI / IDE extension のグローバル設定
  # Codex app が動的に更新するため、Nix store を経由せず直接リンクする
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/codex/config.toml";
  home.file.".codex/fugu.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/codex/fugu.json";

  launchd.agents.codex-sakana-proxy = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.python3}/bin/python3"
        "${codexSakanaProxyScript}"
      ];
      EnvironmentVariables = {
        CODEX_SAKANA_PROXY_PORT = codexSakanaProxyPort;
        CODEX_SAKANA_UPSTREAM = "https://api.sakana.ai";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/codex-sakana-proxy.log";
      StandardErrorPath = "/tmp/codex-sakana-proxy.err.log";
      ProcessType = "Background";
    };
  };
}
