{
  pkgs,
  config,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
in
{
  imports = [
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
    pkgs.podman
    pkgs.podman-compose
    (pkgs.writeShellScriptBin "docker" ''exec podman "$@"'')
    pkgs.tree
    agents.claude-code
    agents.gemini-cli
    agents.codex
  ];
}
