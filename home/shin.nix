{
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.lazyvim.homeManagerModules.default
    ./modules/agents
    ./modules/cursor
    ./modules/vscode
    ./modules/opencode
    ./modules/ssh.nix
    ./modules/git.nix
    ./modules/direnv.nix
    ./modules/zsh.nix
  ];

  xdg.enable = true;
  home.stateVersion = "26.05";

  programs.lazyvim = {
    enable = true;
    installCoreDependencies = true;
    extras = {
      lang.nix.enable = true;
      lang.typescript.enable = true;
      lang.json.enable = true;
      lang.git.enable = true;
    };
  };

  home.packages = [
    pkgs._1password-cli
    pkgs.nodejs-slim_24
    pkgs.nodejs-slim_24.pkgs.pnpm
    pkgs.tree
  ];
}
