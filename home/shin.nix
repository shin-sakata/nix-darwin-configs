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
    ./modules/mise.nix
    ./modules/zsh.nix
    ./modules/tmux.nix
    ./modules/vscode.nix
  ];

  xdg.enable = true;
  home.stateVersion = "26.05";

  home.sessionVariables = {
    EDITOR = "code";
    MOSH_SERVER_NETWORK_TMOUT = "86400";
  };

  home.packages = [
    pkgs._1password-cli
    pkgs.tree
    pkgs.gh
    pkgs.ripgrep
    pkgs.mosh
    pkgs.ollama
    pkgs.marp-cli
    pkgs.infisical
    pkgs.lima
    pkgs.nixd
  ];
}
