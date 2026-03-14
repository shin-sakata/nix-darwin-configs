# nix-darwin-configs

## 前提依存

- aarch64-darwin
- nix の実装の導入
  - nix でもいいし、互換性のある lix でも可
　- この system 構築時点では lix を使っている 

## 利用技術

- nix-darwin
- nix-homebrew
- home-manager

### nix-darwin

システム全体の構成管理、パッケージ管理をしている。
darwin における GUI アプリケーションはこのレベルで管理することが必須となる。

### nix homebrew

この repository では GUI アプリケーションの導入を nix-homebrew を nix-darwin の modules として利用し、システムレベルで管理している。

### home-manager

dotfiles や ユーザーレベルの cli パッケージ等の管理をしている。
エディタの設定、1password の設定、git の設定などなど。

## install

前提依存の導入

- aarch64-darwin のPCを買ってきてください。
- lix https://lix.systems/install/

```
$ curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

nix-dawrin の初回適用

```
$ sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .
```

## GUI アプリケーションの個別具体設定

- 1password の gui と cli や ssh エージェントの連携や設定を GUI で行う必要あり

## その後の使い方

- nix ファイル等を修正後 `sudo darwin-rebuild switch --flake .`
- たまに gc などしてね

## sudo を Touch ID（指紋認証）で通す

このリポジトリの nix-darwin 設定で `sudo` の認証に Touch ID を使うよう有効化している。
反映するには `sudo darwin-rebuild switch --flake .` を実行する。

注意:

- 非対話的な実行（CI / 一部のスクリプトなど）では Touch ID が使えず、パスワードが必要になることがある
- macOS の挙動や設定次第で、最初の一回はパスワード入力が必要なケースがある
