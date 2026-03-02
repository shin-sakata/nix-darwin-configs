{
  pkgs,
  config,
  flakeRelPath,
  ...
}:
let
  flakePath = "${config.home.homeDirectory}/${flakeRelPath}";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = false;
    vimAlias = true;
    viAlias = true;
  };

  # LazyVim 設定を Nix store を経由せず直接シンボリックリンク
  # これにより lazy-lock.json 等への書き込みが可能になる
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${flakePath}/home/config/nvim";

  # LazyVim の外部依存
  home.packages = with pkgs; [
    gcc # treesitter パーサのビルドに必要
    gnumake
    fd # telescope のファイル検索
    lazygit # LazyVim の Git UI 統合
  ];
}
