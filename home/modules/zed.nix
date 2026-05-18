{
  config,
  flakeRelPath,
  ...
}:
let
  flakePath = "${config.home.homeDirectory}/${flakeRelPath}";
in
{
  # Zed の設定を Nix store を経由せず直接シンボリックリンク
  # これにより Zed が設定を直接書き換え可能になる
  home.file.".config/zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/zed/settings.json";
}
