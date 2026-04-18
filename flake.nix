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

    ws-cli = {
      url = "github:langify-org/ws-cli";
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

          system.activationScripts.postActivation.text = ''
            # まずデフォルトに戻してから設定を適用（宣言的に管理するため）
            /usr/bin/pmset restoredefaults
            echo "電源管理設定を適用しました"
          '';

          nix.settings = {
            experimental-features = "nix-command flakes";
            trusted-users = [
              "root"
              "shin"
            ];
            extra-substituters = [
              "https://cache.numtide.com"
              "https://langify-org.cachix.org"
            ];
            extra-trusted-public-keys = [
              "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
              "langify-org.cachix.org-1:zO6Hf3s6e3Ex7PDSazL1A7XwR/3Deui7G3LUrs4+nq4="
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
              "keyboardcleantool"
              "tailscale-app"
              "claude"
              "docker-desktop"
              "discord"
              "chatbox"
              "codex-app"
              "bitwarden"
              "lm-studio"
              "melonds"
              "finetune"
            ];
          };
        };
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in
    {
      formatter.aarch64-darwin = pkgs.nixfmt-tree;

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
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {
              inherit inputs;
              flakeRelPath = "Projects/shin-sakata/nix-darwin";
            };
            home-manager.users.shin = import ./home/shin.nix;
          }
        ];
      };
    };
}
