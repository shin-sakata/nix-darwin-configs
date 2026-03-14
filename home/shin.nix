{
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    ./modules/agents
    ./modules/ssh.nix
    ./modules/git.nix
    ./modules/direnv.nix
    ./modules/zsh.nix
    ./modules/ws.nix
    ./modules/tmux.nix
    ./modules/neovim.nix
    ./modules/vscode.nix
  ];

  xdg.enable = true;
  home.stateVersion = "26.05";

  home.sessionVariables = {
    EDITOR = "code";
    MOSH_SERVER_NETWORK_TMOUT = "86400";
    BITWARDEN_CLI_USE_DESKTOP_INTEGRATION = "true";
  };

  home.packages = [
    pkgs.bitwarden-cli
    pkgs.nodejs-slim_24
    pkgs.nodejs-slim_24.pkgs.pnpm
    pkgs.tree
    pkgs.gh
    pkgs.ripgrep
    pkgs.mosh
    pkgs.ollama
    pkgs.marp-cli
  ];
}
