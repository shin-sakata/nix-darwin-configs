{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  programs.mise = {
    enable = true;
    # mise 公式 (jdx/mise) の flake を直接参照し、常に upstream 最新版を使う。
    # nixpkgs 側の mise が古くてエラーになる問題を回避するのが目的。
    package = inputs.mise.packages.${system}.mise.overrideAttrs (_: {
      # aarch64-darwin + Nix build sandbox では OCI layer の permission bit テスト
      # (setuid 等の特殊ビット) が落ちる。これはビルド時テスト固有の問題で、
      # 実行ファイル自体の不具合ではない。タグ付きリリースは upstream CI で
      # テスト済みのため、ここではビルド時テストを無効化する。
      # （checkPhase を丸ごとコピーすると upstream の変更に追従できず壊れやすいので、
      #   doCheck = false で済ませる方が保守的かつ将来に強い）
      doCheck = false;
    });
  };
}
