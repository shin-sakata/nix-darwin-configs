{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      identityAgent = "~/.bitwarden-ssh-agent.sock";
    };
    matchBlocks."tower" = {
      hostname = "tower";
      user = "shin";
      forwardAgent = true;
    };
  };
}
