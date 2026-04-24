{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

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
      setopt AUTO_CD              # ディレクトリ名だけで cd
      setopt AUTO_PUSHD           # cd 時に自動で pushd (cd - でスタック活用)
      setopt PUSHD_IGNORE_DUPS    # pushd スタックの重複を除去
      setopt PUSHD_SILENT         # pushd/popd のメッセージを抑制
      setopt INTERACTIVE_COMMENTS # コマンドラインで # コメントを許可
      setopt NO_BEEP              # ビープ音を無効化
      setopt CORRECT              # コマンドのタイポを自動補正提案
      setopt GLOB_DOTS            # ドットファイルも明示的な . なしでグロブ対象に
      setopt HIST_VERIFY          # 履歴展開 (!!, !$ 等) を実行前にエディタで確認
      setopt NO_FLOW_CONTROL      # Ctrl+S/Ctrl+Q のフリーズを無効化

      # 補完スタイル
      zstyle ':completion:*' menu select                              # 矢印キーで候補を選択
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'         # 小文字で大文字もマッチ
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"      # LS_COLORS に連動した色付き
      zstyle ':completion:*' group-name '''                           # 種類別にグループ表示
      zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'  # グループの説明ラベル
      zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f' # マッチなし時の警告
      zstyle ':completion:*' use-cache on                             # 補完キャッシュ有効化
      zstyle ':completion:*' cache-path "$HOME/.zcompcache"

      # キーバインド
      bindkey '^[[A' history-search-backward  # ↑ で現在の入力にマッチする履歴を検索
      bindkey '^[[B' history-search-forward   # ↓ で同上 (前方)
      bindkey '^A' beginning-of-line
      bindkey '^E' end-of-line
      bindkey '^W' backward-kill-word
      bindkey '^U' backward-kill-line

      # プロンプト: (nix) user@host:~/path branch* %
      _prompt_nix() {
        [[ -n "$IN_NIX_SHELL" ]] && echo "%F{cyan}(nix) %f"
      }
      _prompt_git() {
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
        local dirty=""
        [[ -n $(git status --porcelain 2>/dev/null) ]] && dirty="%F{red}*%f"
        echo " %F{magenta}$branch$dirty%f"
      }
      setopt PROMPT_SUBST
      PROMPT='$(_prompt_nix)%F{green}%n@%m%f:%F{blue}%~%f$(_prompt_git) %# '

      # brew の直接利用を禁止（nix-darwin の宣言的管理を強制）
      brew() {
        echo "brew を直接使わないでください。flake.nix を編集して darwin-rebuild switch を実行してください。"
        return 1
      }

      # 指定ポートを listen しているプロセスを kill する
      # usage: killport <port> [port...]
      killport() {
        if [[ $# -eq 0 ]]; then
          echo "usage: killport <port> [port...]" >&2
          return 1
        fi
        local port pids
        for port in "$@"; do
          pids=$(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null)
          if [[ -z "$pids" ]]; then
            echo "port $port: no listening process"
            continue
          fi
          echo "port $port: killing PID(s) $pids"
          echo "$pids" | xargs kill -9
        done
      }
    '';
  };
}
