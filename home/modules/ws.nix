{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  ws = inputs.ws-cli.packages.${system}.ws;
in
{
  home.packages = [
    ws
  ];
}
