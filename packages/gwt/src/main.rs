use anyhow::{bail, Context, Result};
use argh::FromArgs;
use std::fs;
use std::io::Write;
use std::os::unix::fs as unix_fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// git worktree を管理する
#[derive(FromArgs)]
struct Gwt {
    #[argh(subcommand)]
    command: GwtCommand,
}

#[derive(FromArgs)]
#[argh(subcommand)]
enum GwtCommand {
    Add(AddCmd),
    Rm(RmCmd),
    Init(InitCmd),
    Track(TrackCmd),
    Status(StatusCmd),
    Push(PushCmd),
    Pull(PullCmd),
}

/// worktree を作成して VSCode で開く
#[derive(FromArgs)]
#[argh(subcommand, name = "add")]
struct AddCmd {
    /// 新規ブランチ名 (default: <user>/yyyy-mm-dd-N)
    #[argh(option, short = 'b')]
    branch: Option<String>,

    /// worktree を作成するパス (default: ../<branch>)
    #[argh(option, short = 'd')]
    directory: Option<String>,

    /// チェックアウト元の branch/commit (default: HEAD)
    #[argh(option, short = 'f')]
    from: Option<String>,
}

/// worktree を対話的に選択して削除する
#[derive(FromArgs)]
#[argh(subcommand, name = "rm")]
struct RmCmd {
    /// 未コミットの変更があっても強制削除する
    #[argh(switch, short = 'f')]
    force: bool,
}

/// store を初期化する（冪等）
#[derive(FromArgs)]
#[argh(subcommand, name = "init")]
struct InitCmd {}

/// ファイルを store に登録する
#[derive(FromArgs)]
#[argh(subcommand, name = "track")]
struct TrackCmd {
    /// strategy (symlink or copy)
    #[argh(option, short = 's')]
    strategy: String,

    /// 追跡するファイルパス
    #[argh(positional)]
    file: String,
}

/// 追跡ファイルの状態を表示する
#[derive(FromArgs)]
#[argh(subcommand, name = "status")]
struct StatusCmd {}

/// copy 追跡ファイルの変更を store に反映する
#[derive(FromArgs)]
#[argh(subcommand, name = "push")]
struct PushCmd {
    /// ファイルパス（省略で全 copy ファイル）
    #[argh(positional)]
    file: Option<String>,
}

/// store から追跡ファイルを現在の worktree に配布する
#[derive(FromArgs)]
#[argh(subcommand, name = "pull")]
struct PullCmd {
    /// ファイルパス（省略で全追跡ファイル）
    #[argh(positional)]
    file: Option<String>,

    /// 既存ファイルを上書きする
    #[argh(switch, short = 'f')]
    force: bool,
}

// --- ヘルパー ---

struct ManifestEntry {
    strategy: String,
    filepath: String,
}

fn git_output(args: &[&str]) -> Result<String> {
    let output = Command::new("git")
        .args(args)
        .output()
        .with_context(|| format!("git {} の実行に失敗しました", args.join(" ")))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("git {} が失敗しました: {}", args.join(" "), stderr.trim());
    }

    Ok(String::from_utf8(output.stdout)?.trim().to_string())
}

fn store_dir() -> Result<PathBuf> {
    let common_dir = git_output(&["rev-parse", "--git-common-dir"])
        .context("git リポジトリ内で実行してください")?;

    let canonical = fs::canonicalize(&common_dir)
        .with_context(|| format!("パスの正規化に失敗しました: {}", common_dir))?;

    Ok(canonical.join("worktree-store"))
}

fn require_store() -> Result<PathBuf> {
    let store = store_dir()?;
    if !store.is_dir() || !store.join("manifest").is_file() {
        bail!("store が未初期化です。先に 'gwt init' を実行してください");
    }
    Ok(store)
}

fn worktree_root() -> Result<PathBuf> {
    let root = git_output(&["rev-parse", "--show-toplevel"])
        .context("worktree 内で実行してください")?;
    Ok(PathBuf::from(root))
}

fn read_manifest(store: &Path) -> Result<Vec<ManifestEntry>> {
    let manifest_path = store.join("manifest");
    let content = fs::read_to_string(&manifest_path)
        .with_context(|| format!("manifest の読み込みに失敗しました: {}", manifest_path.display()))?;

    let mut entries = Vec::new();
    for line in content.lines() {
        if line.is_empty() {
            continue;
        }
        if let Some((strategy, filepath)) = line.split_once(':') {
            if !strategy.is_empty() {
                entries.push(ManifestEntry {
                    strategy: strategy.to_string(),
                    filepath: filepath.to_string(),
                });
            }
        }
    }
    Ok(entries)
}

fn write_manifest(store: &Path, entries: &[ManifestEntry]) -> Result<()> {
    let manifest_path = store.join("manifest");
    let mut file = fs::File::create(&manifest_path)
        .with_context(|| format!("manifest の書き込みに失敗しました: {}", manifest_path.display()))?;

    for entry in entries {
        writeln!(file, "{}:{}", entry.strategy, entry.filepath)?;
    }
    Ok(())
}

fn apply_file(strategy: &str, filepath: &str, store: &Path, target_root: &Path) -> Result<()> {
    let target = target_root.join(filepath);
    let source = store.join(filepath);

    if target.exists() || target.symlink_metadata().is_ok() {
        eprintln!("  スキップ: {} (既に存在します)", filepath);
        return Ok(());
    }

    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }

    match strategy {
        "symlink" => {
            unix_fs::symlink(&source, &target)?;
            println!("  symlink: {}", filepath);
        }
        "copy" => {
            fs::copy(&source, &target)?;
            println!("  copy: {}", filepath);
        }
        _ => {}
    }

    Ok(())
}

fn current_date() -> Result<String> {
    let output = Command::new("date")
        .arg("+%Y-%m-%d")
        .output()
        .context("date コマンドの実行に失敗しました")?;
    Ok(String::from_utf8(output.stdout)?.trim().to_string())
}

// --- コマンド ---

fn cmd_add(cmd: &AddCmd) -> Result<()> {
    let branch = match &cmd.branch {
        Some(b) => b.clone(),
        None => {
            let user = git_output(&["config", "user.name"])?;
            let date = current_date()?;
            let mut n = 0u32;
            loop {
                let candidate = format!("{}/{}-{}", user, date, n);
                let status = Command::new("git")
                    .args([
                        "show-ref",
                        "--verify",
                        "--quiet",
                        &format!("refs/heads/{}", candidate),
                    ])
                    .status()?;
                if !status.success() {
                    break candidate;
                }
                n += 1;
            }
        }
    };

    let directory = cmd
        .directory
        .clone()
        .unwrap_or_else(|| format!("../{}", branch));

    let mut args = vec!["worktree", "add", "-b"];
    args.push(&branch);
    args.push(&directory);

    let from_ref;
    if let Some(from) = &cmd.from {
        from_ref = from.clone();
        args.push(&from_ref);
    }

    let status = Command::new("git")
        .args(&args)
        .status()
        .context("git worktree add の実行に失敗しました")?;

    if !status.success() {
        bail!("git worktree add が失敗しました");
    }

    // store が存在すればファイルを適用
    if let Ok(store) = store_dir() {
        if store.is_dir() && store.join("manifest").is_file() {
            let abs_directory = fs::canonicalize(&directory)
                .with_context(|| format!("ディレクトリの正規化に失敗: {}", directory))?;
            println!("store からファイルを適用中...");
            let entries = read_manifest(&store)?;
            for entry in &entries {
                apply_file(&entry.strategy, &entry.filepath, &store, &abs_directory)?;
            }
        }
    }

    Command::new("code")
        .arg(&directory)
        .status()
        .context("VSCode の起動に失敗しました")?;

    Ok(())
}

fn cmd_rm(cmd: &RmCmd) -> Result<()> {
    let worktree_list = git_output(&["worktree", "list"])?;
    let lines: Vec<&str> = worktree_list.lines().skip(1).collect();

    if lines.is_empty() {
        println!("削除可能な worktree はありません");
        return Ok(());
    }

    let input = lines.join("\n");

    let mut fzf = Command::new("fzf")
        .arg("--prompt=削除する worktree を選択: ")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .context("fzf の起動に失敗しました")?;

    if let Some(stdin) = fzf.stdin.as_mut() {
        stdin.write_all(input.as_bytes())?;
    }

    let output = fzf.wait_with_output()?;
    let selected = String::from_utf8(output.stdout)?.trim().to_string();

    if selected.is_empty() {
        println!("キャンセルしました");
        return Ok(());
    }

    let path = selected
        .split_whitespace()
        .next()
        .context("worktree のパスを取得できませんでした")?;

    let mut args = vec!["worktree", "remove"];
    if cmd.force {
        args.push("--force");
    }
    args.push(path);

    let status = Command::new("git")
        .args(&args)
        .status()
        .context("git worktree remove の実行に失敗しました")?;

    if !status.success() {
        bail!("git worktree remove が失敗しました");
    }

    Ok(())
}

fn cmd_init() -> Result<()> {
    let store = store_dir()?;

    fs::create_dir_all(&store)?;

    let manifest = store.join("manifest");
    if !manifest.is_file() {
        fs::File::create(&manifest)?;
        println!("store を初期化しました: {}", store.display());
    } else {
        println!("store は既に初期化済みです: {}", store.display());
    }

    Ok(())
}

fn cmd_track(cmd: &TrackCmd) -> Result<()> {
    let store = require_store()?;
    let wt_root = worktree_root()?;

    if cmd.strategy != "symlink" && cmd.strategy != "copy" {
        bail!("strategy は 'symlink' または 'copy' を指定してください");
    }

    let source = wt_root.join(&cmd.file);
    if !source.exists() && source.symlink_metadata().is_err() {
        bail!("ファイルが見つかりません: {}", cmd.file);
    }

    // manifest を更新
    let mut entries = read_manifest(&store)?;
    let mut found = false;
    for entry in entries.iter_mut() {
        if entry.filepath == cmd.file {
            entry.strategy = cmd.strategy.clone();
            found = true;
            break;
        }
    }
    if !found {
        entries.push(ManifestEntry {
            strategy: cmd.strategy.clone(),
            filepath: cmd.file.clone(),
        });
    }
    write_manifest(&store, &entries)?;

    // store にコピー
    let store_file = store.join(&cmd.file);
    if let Some(parent) = store_file.parent() {
        fs::create_dir_all(parent)?;
    }

    let is_symlink = source
        .symlink_metadata()
        .map(|m| m.file_type().is_symlink())
        .unwrap_or(false);

    if cmd.strategy == "symlink" {
        // store にコンテンツをコピー
        fs::copy(&source, &store_file).context("store へのコピーに失敗しました")?;

        // 通常ファイルならシンボリックリンクに変換
        if !is_symlink {
            fs::remove_file(&source)?;
            unix_fs::symlink(&store_file, &source)?;
            println!("{} をシンボリックリンクに変換しました", cmd.file);
        }
    } else {
        // copy strategy
        fs::copy(&source, &store_file).context("store へのコピーに失敗しました")?;
    }

    println!("追跡を開始しました: {}:{}", cmd.strategy, cmd.file);
    Ok(())
}

fn cmd_status() -> Result<()> {
    let store = require_store()?;
    let wt_root = worktree_root().ok();

    println!("Store: {}", store.display());
    println!();

    let entries = read_manifest(&store)?;
    if entries.is_empty() {
        println!("追跡ファイルはありません");
        return Ok(());
    }

    println!("{:<8} {:<40} {}", "STRATEGY", "FILE", "STATUS");
    println!(
        "{:<8} {:<40} {}",
        "--------", "----------------------------------------", "----------"
    );

    for entry in &entries {
        let store_file = store.join(&entry.filepath);

        if !store_file.is_file() {
            println!(
                "{:<8} {:<40} {}",
                entry.strategy, entry.filepath, "MISSING(store)"
            );
            continue;
        }

        let status = if let Some(ref root) = wt_root {
            let wt_file = root.join(&entry.filepath);
            let wt_exists = wt_file.exists() || wt_file.symlink_metadata().is_ok();

            if !wt_exists {
                "MISSING"
            } else if entry.strategy == "symlink" {
                let is_link = wt_file
                    .symlink_metadata()
                    .map(|m| m.file_type().is_symlink())
                    .unwrap_or(false);

                if is_link {
                    let link_target = fs::read_link(&wt_file)?;
                    if link_target != store_file {
                        "WRONG_LINK"
                    } else {
                        "OK"
                    }
                } else {
                    "NOT_LINK"
                }
            } else if entry.strategy == "copy" {
                let store_content = fs::read(&store_file).ok();
                let wt_content = fs::read(&wt_file).ok();
                if store_content != wt_content {
                    "MODIFIED"
                } else {
                    "OK"
                }
            } else {
                "OK"
            }
        } else {
            "(store のみ)"
        };

        println!("{:<8} {:<40} {}", entry.strategy, entry.filepath, status);
    }

    Ok(())
}

fn cmd_push(cmd: &PushCmd) -> Result<()> {
    let store = require_store()?;
    let wt_root = worktree_root()?;
    let entries = read_manifest(&store)?;

    let mut pushed = 0u32;

    for entry in &entries {
        if entry.strategy != "copy" {
            continue;
        }

        if let Some(ref target_file) = cmd.file {
            if entry.filepath != *target_file {
                continue;
            }
        }

        let wt_file = wt_root.join(&entry.filepath);
        if !wt_file.is_file() {
            eprintln!("スキップ: {} (worktree に存在しません)", entry.filepath);
            continue;
        }

        let store_file = store.join(&entry.filepath);
        fs::copy(&wt_file, &store_file)?;
        println!("push: {}", entry.filepath);
        pushed += 1;
    }

    if pushed == 0 {
        if let Some(ref target_file) = cmd.file {
            bail!("{} は copy strategy で追跡されていません", target_file);
        } else {
            println!("push 対象の copy ファイルはありません");
        }
    }

    Ok(())
}

fn cmd_pull(cmd: &PullCmd) -> Result<()> {
    let store = require_store()?;
    let wt_root = worktree_root()?;
    let entries = read_manifest(&store)?;

    let mut pulled = 0u32;

    for entry in &entries {
        if let Some(ref target_file) = cmd.file {
            if entry.filepath != *target_file {
                continue;
            }
        }

        let store_file = store.join(&entry.filepath);
        if !store_file.is_file() {
            eprintln!("スキップ: {} (store に存在しません)", entry.filepath);
            continue;
        }

        let wt_file = wt_root.join(&entry.filepath);
        let wt_exists = wt_file.exists() || wt_file.symlink_metadata().is_ok();

        if wt_exists && !cmd.force {
            eprintln!(
                "スキップ: {} (既に存在します。-f で上書き)",
                entry.filepath
            );
            continue;
        }

        // 既存ファイル/リンクを削除してから配布
        if wt_exists {
            let _ = fs::remove_file(&wt_file);
        }

        if let Some(parent) = wt_file.parent() {
            fs::create_dir_all(parent)?;
        }

        match entry.strategy.as_str() {
            "symlink" => {
                unix_fs::symlink(&store_file, &wt_file)?;
                println!("pull (symlink): {}", entry.filepath);
            }
            "copy" => {
                fs::copy(&store_file, &wt_file)?;
                println!("pull (copy): {}", entry.filepath);
            }
            _ => continue,
        }
        pulled += 1;
    }

    if pulled == 0 {
        if let Some(ref target_file) = cmd.file {
            bail!("{} は追跡されていません", target_file);
        } else {
            println!("pull 対象のファイルはありません");
        }
    }

    Ok(())
}

fn run(gwt: Gwt) -> Result<()> {
    match gwt.command {
        GwtCommand::Add(cmd) => cmd_add(&cmd),
        GwtCommand::Rm(cmd) => cmd_rm(&cmd),
        GwtCommand::Init(_) => cmd_init(),
        GwtCommand::Track(cmd) => cmd_track(&cmd),
        GwtCommand::Status(_) => cmd_status(),
        GwtCommand::Push(cmd) => cmd_push(&cmd),
        GwtCommand::Pull(cmd) => cmd_pull(&cmd),
    }
}

fn main() {
    let gwt: Gwt = argh::from_env();
    if let Err(e) = run(gwt) {
        eprintln!("エラー: {:#}", e);
        std::process::exit(1);
    }
}
