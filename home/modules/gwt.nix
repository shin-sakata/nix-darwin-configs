{ pkgs, ... }:
{
  home.packages = [
    pkgs.argc
    pkgs.fzf
    (pkgs.writeShellScriptBin "gwt" ''
      # @describe git worktree を管理する

      # --- ヘルパー関数 ---

      _store_dir() {
        local common_dir
        common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || {
          echo "エラー: git リポジトリ内で実行してください" >&2
          return 1
        }
        # 絶対パスに正規化
        echo "$(cd "$common_dir" && pwd)/worktree-store"
      }

      _manifest() {
        echo "$(_store_dir)/manifest"
      }

      _require_store() {
        local store
        store=$(_store_dir) || return 1
        if [[ ! -d "$store" ]] || [[ ! -f "$store/manifest" ]]; then
          echo "エラー: store が未初期化です。先に 'gwt init' を実行してください" >&2
          return 1
        fi
      }

      _worktree_root() {
        git rev-parse --show-toplevel 2>/dev/null || {
          echo "エラー: worktree 内で実行してください" >&2
          return 1
        }
      }

      _apply_file() {
        local strategy="$1"
        local filepath="$2"
        local store="$3"
        local target_root="$4"
        local target="''${target_root}/''${filepath}"
        local source="''${store}/''${filepath}"

        if [[ -e "$target" ]] || [[ -L "$target" ]]; then
          echo "  スキップ: ''${filepath} (既に存在します)" >&2
          return 0
        fi

        mkdir -p "$(dirname "$target")"

        if [[ "$strategy" == "symlink" ]]; then
          ln -s "$source" "$target"
          echo "  symlink: ''${filepath}"
        elif [[ "$strategy" == "copy" ]]; then
          cp "$source" "$target"
          echo "  copy: ''${filepath}"
        fi
      }

      # --- コマンド ---

      # @cmd worktree を作成して VSCode で開く
      # @option -d --directory  worktree を作成するパス (default: ../<branch>)
      # @option -b --branch     新規ブランチ名 (default: <user>/yyyy-mm-dd-N)
      # @option -f --from       チェックアウト元の branch/commit (default: HEAD)
      add() {
        local branch="''${argc_branch}"
        local directory="''${argc_directory}"
        local base="''${argc_from}"

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

        git worktree add "''${args[@]}" || return 1

        # store が存在すればファイルを適用
        local store
        store=$(_store_dir) 2>/dev/null
        if [[ -d "$store" ]] && [[ -f "$store/manifest" ]]; then
          local abs_directory
          abs_directory=$(cd "$directory" && pwd)
          echo "store からファイルを適用中..."
          while IFS=: read -r strategy filepath; do
            [[ -z "$strategy" ]] && continue
            _apply_file "$strategy" "$filepath" "$store" "$abs_directory"
          done < "$store/manifest"
        fi

        code "$directory"
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

      # @cmd store を初期化する（冪等）
      init() {
        local store
        store=$(_store_dir) || return 1

        mkdir -p "$store"
        if [[ ! -f "$store/manifest" ]]; then
          touch "$store/manifest"
          echo "store を初期化しました: $store"
        else
          echo "store は既に初期化済みです: $store"
        fi
      }

      # @cmd ファイルを store に登録する
      # @option -s --strategy! strategy (symlink or copy)
      # @arg file! 追跡するファイルパス
      track() {
        _require_store || return 1

        local strategy="''${argc_strategy}"
        local file="''${argc_file}"
        local store
        store=$(_store_dir) || return 1
        local manifest
        manifest=$(_manifest)
        local wt_root
        wt_root=$(_worktree_root) || return 1

        if [[ "$strategy" != "symlink" ]] && [[ "$strategy" != "copy" ]]; then
          echo "エラー: strategy は 'symlink' または 'copy' を指定してください" >&2
          return 1
        fi

        local source="''${wt_root}/''${file}"
        if [[ ! -f "$source" ]] && [[ ! -L "$source" ]]; then
          echo "エラー: ファイルが見つかりません: ''${file}" >&2
          return 1
        fi

        # 既に manifest に登録されている場合は strategy を更新
        local tmp
        tmp=$(mktemp)
        local found=false
        while IFS=: read -r s f; do
          if [[ "$f" == "$file" ]]; then
            echo "''${strategy}:''${f}" >> "$tmp"
            found=true
          else
            echo "''${s}:''${f}" >> "$tmp"
          fi
        done < "$manifest"

        if [[ "$found" == "false" ]]; then
          echo "''${strategy}:''${file}" >> "$tmp"
        fi

        mv "$tmp" "$manifest"

        # store にマスターコピーを保存
        local store_file="''${store}/''${file}"
        mkdir -p "$(dirname "$store_file")"

        # symlink の場合、実体の内容を store にコピーしてから worktree のファイルをシンボリックリンクに変換
        if [[ "$strategy" == "symlink" ]]; then
          if [[ -L "$source" ]]; then
            # 既にシンボリックリンクの場合、リンク先の内容を store にコピー
            cp "$(readlink "$source")" "$store_file" 2>/dev/null || cp "$source" "$store_file"
          else
            cp "$source" "$store_file"
            # 元のファイルをシンボリックリンクに変換
            command rm "$source"
            ln -s "$store_file" "$source"
            echo "''${file} をシンボリックリンクに変換しました"
          fi
        else
          # copy strategy: store にコピー
          if [[ -L "$source" ]]; then
            cp "$(readlink "$source")" "$store_file" 2>/dev/null || cp "$source" "$store_file"
          else
            cp "$source" "$store_file"
          fi
        fi

        echo "追跡を開始しました: ''${strategy}:''${file}"
      }

      # @cmd 追跡ファイルの状態を表示する
      status() {
        _require_store || return 1

        local store
        store=$(_store_dir) || return 1
        local manifest
        manifest=$(_manifest)
        local wt_root
        wt_root=$(_worktree_root) 2>/dev/null

        echo "Store: $store"
        echo ""

        if [[ ! -s "$manifest" ]]; then
          echo "追跡ファイルはありません"
          return 0
        fi

        printf "%-8s %-40s %s\n" "STRATEGY" "FILE" "STATUS"
        printf "%-8s %-40s %s\n" "--------" "----------------------------------------" "----------"

        while IFS=: read -r strategy filepath; do
          [[ -z "$strategy" ]] && continue

          local store_file="''${store}/''${filepath}"
          local status="OK"

          # store にマスターコピーがあるか
          if [[ ! -f "$store_file" ]]; then
            status="MISSING(store)"
            printf "%-8s %-40s %s\n" "$strategy" "$filepath" "$status"
            continue
          fi

          # worktree 内にいる場合のみ worktree 側のステータスを確認
          if [[ -n "$wt_root" ]]; then
            local wt_file="''${wt_root}/''${filepath}"

            if [[ ! -e "$wt_file" ]] && [[ ! -L "$wt_file" ]]; then
              status="MISSING"
            elif [[ "$strategy" == "symlink" ]]; then
              if [[ -L "$wt_file" ]]; then
                local link_target
                link_target=$(readlink "$wt_file")
                if [[ "$link_target" != "$store_file" ]]; then
                  status="WRONG_LINK"
                fi
              else
                status="NOT_LINK"
              fi
            elif [[ "$strategy" == "copy" ]]; then
              if ! diff -q "$store_file" "$wt_file" > /dev/null 2>&1; then
                status="MODIFIED"
              fi
            fi
          else
            status="(store のみ)"
          fi

          printf "%-8s %-40s %s\n" "$strategy" "$filepath" "$status"
        done < "$manifest"
      }

      # @cmd copy 追跡ファイルの変更を store に反映する
      # @arg file ファイルパス（省略で全 copy ファイル）
      push() {
        _require_store || return 1

        local target_file="''${argc_file}"
        local store
        store=$(_store_dir) || return 1
        local manifest
        manifest=$(_manifest)
        local wt_root
        wt_root=$(_worktree_root) || return 1

        local pushed=0

        while IFS=: read -r strategy filepath; do
          [[ -z "$strategy" ]] && continue
          [[ "$strategy" != "copy" ]] && continue

          if [[ -n "$target_file" ]] && [[ "$filepath" != "$target_file" ]]; then
            continue
          fi

          local wt_file="''${wt_root}/''${filepath}"
          local store_file="''${store}/''${filepath}"

          if [[ ! -f "$wt_file" ]]; then
            echo "スキップ: ''${filepath} (worktree に存在しません)" >&2
            continue
          fi

          cp "$wt_file" "$store_file"
          echo "push: ''${filepath}"
          pushed=$((pushed + 1))
        done < "$manifest"

        if [[ "$pushed" -eq 0 ]]; then
          if [[ -n "$target_file" ]]; then
            echo "エラー: ''${target_file} は copy strategy で追跡されていません" >&2
            return 1
          else
            echo "push 対象の copy ファイルはありません"
          fi
        fi
      }

      # @cmd store から追跡ファイルを現在の worktree に配布する
      # @arg file ファイルパス（省略で全追跡ファイル）
      # @flag -f --force  既存ファイルを上書きする
      pull() {
        _require_store || return 1

        local target_file="''${argc_file}"
        local store
        store=$(_store_dir) || return 1
        local manifest
        manifest=$(_manifest)
        local wt_root
        wt_root=$(_worktree_root) || return 1

        local pulled=0

        while IFS=: read -r strategy filepath; do
          [[ -z "$strategy" ]] && continue

          if [[ -n "$target_file" ]] && [[ "$filepath" != "$target_file" ]]; then
            continue
          fi

          local wt_file="''${wt_root}/''${filepath}"
          local store_file="''${store}/''${filepath}"

          if [[ ! -f "$store_file" ]]; then
            echo "スキップ: ''${filepath} (store に存在しません)" >&2
            continue
          fi

          if ([[ -e "$wt_file" ]] || [[ -L "$wt_file" ]]) && [[ -z "$argc_force" ]]; then
            echo "スキップ: ''${filepath} (既に存在します。-f で上書き)" >&2
            continue
          fi

          # 既存ファイル/リンクを削除してから配布
          if [[ -e "$wt_file" ]] || [[ -L "$wt_file" ]]; then
            command rm "$wt_file"
          fi

          mkdir -p "$(dirname "$wt_file")"

          if [[ "$strategy" == "symlink" ]]; then
            ln -s "$store_file" "$wt_file"
            echo "pull (symlink): ''${filepath}"
          elif [[ "$strategy" == "copy" ]]; then
            cp "$store_file" "$wt_file"
            echo "pull (copy): ''${filepath}"
          fi
          pulled=$((pulled + 1))
        done < "$manifest"

        if [[ "$pulled" -eq 0 ]]; then
          if [[ -n "$target_file" ]]; then
            echo "エラー: ''${target_file} は追跡されていません" >&2
            return 1
          else
            echo "pull 対象のファイルはありません"
          fi
        fi
      }

      eval "$(argc --argc-eval "$0" "$@")"
    '')
  ];
}
