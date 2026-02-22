{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };

  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      configuration =
        { pkgs, ... }:
        {
          environment.systemPackages = [
            # pkgs.vim
          ];

          # TouchID は無効化（iPhone からのリモートアクセス用）
          security.pam.services.sudo_local.touchIdAuth = false;

          # NOPASSWD 設定（sudoers.d にファイルを配置）
          environment.etc."sudoers.d/nopasswd".text = ''
            shin ALL=(ALL) NOPASSWD: ALL
          '';

          # 電源管理設定: 電源接続時はディスプレイのみスリープ、システムは起動したまま
          system.activationScripts.postActivation.text = ''
            # 電源接続時 (-c): ディスプレイは10分でスリープ、システムはスリープしない
            /usr/bin/pmset -c displaysleep 10 sleep 0 disksleep 0

            # バッテリー駆動時 (-b): 通常通りスリープ
            /usr/bin/pmset -b displaysleep 5 sleep 15

            echo "電源管理設定を適用しました"
          '';

          nix.settings = {
            experimental-features = "nix-command flakes";
            trusted-users = [
              "root"
              "shin"
            ];
            extra-substituters = [ "https://cache.numtide.com" ];
            extra-trusted-public-keys = [
              "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
            ];
          };
          nixpkgs.config.allowUnfree = true;
          system.primaryUser = "shin";
          users.users.shin = {
            name = "shin";
            home = "/Users/shin";
          };
          system.configurationRevision = self.rev or self.dirtyRev or null;
          system.stateVersion = 6;
          nixpkgs.hostPlatform = "aarch64-darwin";

          # メニューバー設定
          system.defaults.NSGlobalDomain._HIHideMenuBar = false;
          system.defaults.CustomUserPreferences."NSGlobalDomain".AppleMenuBarVisibleInFullscreen = true;

          homebrew = {
            enable = true;
            onActivation = {
              autoUpdate = true;
              cleanup = "zap";
            };

            casks = [
              "visual-studio-code"
              "cursor"
              "1password"
              "google-chrome"
              "slack"
              "ghostty"
              "tailscale"
              "claude"
              "docker"
              "discord"
              "chatbox"
              "codex-app"
            ];
          };
        };
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in
    {
      formatter.aarch64-darwin = pkgs.nixfmt-tree;

      packages.aarch64-darwin.ws = pkgs.rustPlatform.buildRustPackage {
        pname = "ws";
        version = "0.1.0";
        src = ./packages/ws;
        cargoLock.lockFile = ./packages/ws/Cargo.lock;
      };

      darwinConfigurations."shinnoMacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = "shin";
              autoMigrate = true;
            };
          }

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.shin = import ./home/shin.nix;
          }
        ];
      };
    };
}
