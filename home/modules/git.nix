{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "cursor";
      user = {
        name = "shin-sakata";
        email = "shintaro.sakata.tokyo@gmail.com";
      };
    };
    ignores = [ ".direnv" ];
  };
}
