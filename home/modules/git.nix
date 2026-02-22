{ ... }:
{
  programs.git = {
    enable = true;
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        dark = true;
      };
    };
    settings = {
      core.editor = "code --wait";
      user = {
        name = "shin-sakata";
        email = "shintaro.sakata.tokyo@gmail.com";
      };
      merge.conflictStyle = "zdiff3";
    };
    ignores = [
      ".direnv"
      "*.local.*"
    ];
  };
}
