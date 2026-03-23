{ lib, ... }:
{
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 50000;
    baseIndex = 1;
    extraConfig = ''
      # ステータスバーを上に表示
      set -g status-position top

      # Shift+Enter 等の修飾キー付きキーシーケンスをアプリケーションに渡す
      # always: アプリがリクエストしなくても常に転送
      # csi-u: Claude Code が期待する CSI u 形式で送信
      set -s extended-keys always
      set -s extended-keys-format csi-u
      set -as terminal-features 'xterm*:extkeys'

      # Neovim が外部ファイル変更を検知するために必要
      set-option -g focus-events on

      # ウィンドウ名: parent/current ディレクトリ形式で自動表示
      # Claude Code 起動時は OSC タイトルで上書きされる
      set-option -g automatic-rename on
      set-option -g automatic-rename-format '#{s|.*/([^/]+/[^/]+)$|\1|:pane_current_path}'
      set-option -g allow-rename off

      # ウィンドウ移動モード（Ctrl+Space で入り、h/l で移動、Escape/Enter で抜ける）
      bind -n C-Space switch-client -T windownav
      bind -T windownav h previous-window \; switch-client -T windownav
      bind -T windownav l next-window \; switch-client -T windownav
      bind -T windownav Escape switch-client -T root
      bind -T windownav Enter switch-client -T root

      # ペイン分割
      bind - split-window -v -c "#{pane_current_path}"
      bind | split-window -h -c "#{pane_current_path}"

      # ペイン移動 (Vim スタイル)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
    '';
  };
}
