{ ... }:

{
  home.file."Library/Application Support/Cursor/User/settings.json" = {
    source = ../../.vscode/settings.json;
    force = true;
  };

  # キーバインディングの設定も管理する場合は以下をアンコメント
  # home.file."Library/Application Support/Cursor/User/keybindings.json" = {
  #   source = ../cursor/keybindings.json;
  #   force = true;
  # };
}
