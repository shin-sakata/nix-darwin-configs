{
  pkgs,
  config,
  inputs,
  lib,
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

  # zlaude: Z.ai (GLM) 経由で claude を起動するラッパー
  # 環境変数で ANTHROPIC_BASE_URL と認証トークンを上書きする
  # API キーは 1Password CLI から取得する想定 (op://Personal/Z.ai/credential)
  programs.zsh.initContent = lib.mkAfter ''
    zlaude() {
      local token
      if ! token=$(op read "op://Personal/Z.ai/credential" 2>/dev/null); then
        echo "zlaude: 1Password から Z.ai の API キーを取得できませんでした。" >&2
        echo "  op://Personal/Z.ai/credential が存在するか、op signin 済みか確認してください。" >&2
        return 1
      fi
      ANTHROPIC_AUTH_TOKEN="$token" \
      ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
      API_TIMEOUT_MS="3000000" \
      ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2" \
      ANTHROPIC_DEFAULT_SONNET_MODEL="glm-5.2" \
      ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.7" \
        claude "$@"
    }
  '';

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
