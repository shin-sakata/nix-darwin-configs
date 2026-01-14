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

          security.pam.services.sudo_local.touchIdAuth = true;

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
            ];
          };
        };
    in
    {
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

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
