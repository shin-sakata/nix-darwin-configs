{ pkgs, ... }:
{
  home.packages = [
    pkgs.podman
    pkgs.podman-compose
    (pkgs.writeShellScriptBin "docker" ''exec podman "$@"'')
  ];
}
