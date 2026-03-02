{
  config,
  flakeRelPath,
  ...
}:
let
  flakePath = "${config.home.homeDirectory}/${flakeRelPath}";
in
{
  # VSCode の設定を Nix store を経由せず直接シンボリックリンク
  # これにより VSCode が設定を直接書き換え可能になる
  home.file."Library/Application Support/Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/vscode/settings.json";
  home.file."Library/Application Support/Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/vscode/keybindings.json";
}
