{ pkgs, ... }:
{
  home.packages = [
    pkgs.argc
    pkgs.fzf
    (pkgs.writeShellScriptBin "gwt" ''
      # @describe git worktree を管理する

      # @cmd worktree を作成して VSCode で開く
      # @option -d --directory  worktree を作成するパス (default: ../<branch>)
      # @option -b --branch     新規ブランチ名 (default: <user>/yyyy-mm-dd-N)
      # @option -w --base       チェックアウト元の branch/commit (default: HEAD)
      add() {
        local branch="''${argc_branch}"
        local directory="''${argc_directory}"
        local base="''${argc_base}"

        # branch のデフォルト: <git-user>/yyyy-mm-dd-N (0, 1, 2, ...)
        if [[ -z "$branch" ]]; then
          local user=$(git config user.name)
          local date=$(date +%Y-%m-%d)
          local n=0
          branch="''${user}/''${date}-''${n}"
          while git show-ref --verify --quiet "refs/heads/''${branch}"; do
            n=$((n + 1))
            branch="''${user}/''${date}-''${n}"
          done
        fi

        # directory のデフォルト: ../<branch>
        if [[ -z "$directory" ]]; then
          directory="../''${branch}"
        fi

        local args=(-b "$branch" "$directory")
        if [[ -n "$base" ]]; then
          args+=("$base")
        fi

        git worktree add "''${args[@]}" && code "$directory"
      }

      # @cmd worktree を対話的に選択して削除する
      # @flag -f --force  未コミットの変更があっても強制削除する
      rm() {
        local selected
        selected=$(git worktree list | tail -n +2 | fzf --prompt="削除する worktree を選択: ")
        if [[ -z "$selected" ]]; then
          echo "キャンセルしました"
          return 0
        fi

        local path
        path=$(echo "$selected" | awk '{print $1}')

        if [[ -n "$argc_force" ]]; then
          git worktree remove --force "$path"
        else
          git worktree remove "$path"
        fi
      }

      eval "$(argc --argc-eval "$0" "$@")"
    '')
  ];
}
