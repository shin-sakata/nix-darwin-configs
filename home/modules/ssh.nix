{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.orbstack/ssh/config" ];
    settings."*" = {
      IdentityAgent = "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    };
    # `tower` は Tailscale の MagicDNS 名。Tailscale が起動していないと
    # 名前解決できず `Could not resolve hostname tower` で ssh できない
    settings."tower" = {
      HostName = "tower";
      User = "shin";
      ForwardAgent = true;
    };
  };
}
