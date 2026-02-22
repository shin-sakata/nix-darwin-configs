{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  ws = inputs.self.packages.${system}.ws;
in
{
  home.packages = [
    pkgs.fzf
    ws
  ];
}
