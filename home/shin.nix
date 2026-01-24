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
    ./modules/containers.nix
  ];

  xdg.enable = true;
  home.stateVersion = "26.05";

  home.packages = [
    pkgs._1password-cli
    pkgs.nodejs-slim_24
    pkgs.nodejs-slim_24.pkgs.pnpm
    pkgs.tree
    pkgs.playwright-mcp # bin/mcp-server-playwright
    pkgs.playwright
  ];
}
