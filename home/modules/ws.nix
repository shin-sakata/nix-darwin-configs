{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    inputs.ws-cli.homeManagerModules.default
  ];

  programs.ws = {
    enable = true;
    package = inputs.ws-cli.packages.${system}.ws;
    repos = {
      langify-notebook = {
        path = "~/Projects/langify-org/langify-notebook";
        url = "git@github.com:langify-org/langify-notebook.git";
      };
      langify-code = {
        path = "~/Projects/langify-org/langify-code";
      };
      ws-cli = {
        path = "~/Projects/langify-org/ws-cli";
        url = "git@github.com:langify-org/ws-cli.git";
      };
      nix-darwin = {
        path = "~/Projects/shin-sakata/nix-darwin";
        url = "git@github.com:shin-sakata/nix-darwin-configs.git";
      };
      shin-sakata = {
        path = "~/Projects/shin-sakata/shin-sakata";
        url = "git@github.com:shin-sakata/shin-sakata.git";
      };
      define = {
        path = "~/Projects/shin-sakata/define";
      };
      web = {
        path = "~/Projects/spirinc/web";
        url = "git@github.com:spirinc/web.git";
      };
      spir-for-agent = {
        path = "~/Projects/spirinc/spir-for-agent";
        url = "git@github.com:spirinc/spir-for-agent.git";
      };
      spir-ui = {
        path = "~/Projects/spirinc/spir-ui";
        url = "git@github.com:spirinc/spir-ui.git";
      };
    };
  };
}
