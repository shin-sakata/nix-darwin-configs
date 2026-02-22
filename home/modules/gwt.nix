{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  gwt = inputs.self.packages.${system}.gwt;
in
{
  home.packages = [
    pkgs.fzf
    gwt
  ];
}
