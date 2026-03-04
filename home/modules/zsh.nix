{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # disablesleep 有効時の手動スリープ用
      "sleep-now" = "sudo pmset sleepnow";
    };

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
      extended = true;
      expireDuplicatesFirst = true;
    };

    initContent = ''
      setopt AUTO_CD
      setopt INTERACTIVE_COMMENTS
      setopt NO_BEEP

      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      PROMPT='%n@%m:%1~ %# '

      # brew の直接利用を禁止（nix-darwin の宣言的管理を強制）
      brew() {
        echo "brew を直接使わないでください。flake.nix を編集して darwin-rebuild switch を実行してください。"
        return 1
      }
    '';
  };
}
