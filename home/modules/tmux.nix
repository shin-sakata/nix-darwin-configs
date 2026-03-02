{ lib, ... }:
{
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 50000;
    baseIndex = 1;
    extraConfig = ''
      # Neovim が外部ファイル変更を検知するために必要
      set-option -g focus-events on

      # ウィンドウ名: parent/current ディレクトリ形式で自動表示
      # Claude Code 起動時は OSC タイトルで上書きされる
      set-option -g automatic-rename on
      set-option -g automatic-rename-format '#{b:#{d:pane_current_path}}/#{b:pane_current_path}'
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
