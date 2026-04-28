{
  config,
  flakeRelPath,
  ...
}:
let
  flakePath = "${config.home.homeDirectory}/${flakeRelPath}";
in
{
  # cmux 自身が settings.json を書き換える可能性があるため
  # Nix store を経由せず直接シンボリックリンク
  xdg.configFile."cmux/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/cmux/settings.json";
}
