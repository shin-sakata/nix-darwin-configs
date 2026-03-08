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
      merge.conflictStyle = "zdiff3";
    };
    ignores = [
      ".direnv"
      "*.local.*"
      ".claude/skills/_*/SKILL.md"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      dark = true;
    };
  };
}
