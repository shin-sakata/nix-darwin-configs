{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "code --wait";
      user = {
        name = "shin-sakata";
        email = "shintaro.sakata.tokyo@gmail.com";
      };
    };
    ignores = [ ".direnv" "*.local.md" ];
  };
}
