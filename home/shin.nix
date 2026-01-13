{ pkgs, config, ... }:

{
  imports = [
    ./modules/cursor/cursor.nix
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
    (pkgs.claude-code-bun.override { bunBinName = "claude"; })
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      identityAgent = "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      core.editor = "cursor";
      user = {
        name = "shin-sakata";
        email = "shintaro.sakata.tokyo@gmail.com";
      };
    };
    ignores = [ ".direnv" ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      PROMPT='%n@%m:%1~ %# '
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
