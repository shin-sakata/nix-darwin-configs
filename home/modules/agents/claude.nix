{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agents = inputs.llm-agents.packages.${system};
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "claude";
      runtimeInputs = [ pkgs._1password-cli ];
      text = ''
        ANTHROPIC_AUTH_TOKEN=$(op read "op://Development/z.ai api key/zai-api-key-for-claudecode")
        export ANTHROPIC_AUTH_TOKEN
        export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
        export API_TIMEOUT_MS="3000000"
        exec ${agents.claude-code}/bin/claude "$@"
      '';
    })
  ];
}
