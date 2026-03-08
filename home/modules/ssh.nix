{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      identityAgent = "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    };
    matchBlocks."tower" = {
      hostname = "tower";
      user = "shin";
      forwardAgent = true;
    };
  };
}
