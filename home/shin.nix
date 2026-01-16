{ pkgs, config, ... }:
{
  imports = [
    ./modules/agents.nix
    ./modules/cursor.nix
    ./modules/vscode.nix
    ./modules/ssh.nix
    ./modules/git.nix
    ./modules/direnv.nix
    ./modules/zsh.nix
  ];

  xdg.enable = true;
  home.stateVersion = "26.05";

  home.packages = [
    pkgs._1password-cli
    pkgs.nodejs-slim_24
    pkgs.nodejs-slim_24.pkgs.pnpm
    pkgs.tree
  ];
}
