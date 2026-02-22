use anyhow::{bail, Context, Result};
use argh::FromArgs;
use std::fs;
use std::io::{self, Write};
use std::os::unix::fs as unix_fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// workspace (git worktree) を管理する
#[derive(FromArgs)]
struct Ws {
    #[argh(subcommand)]
    command: WsCommand,
}

#[derive(FromArgs)]
#[argh(subcommand)]
enum WsCommand {
    New(NewCmd),
    Rm(RmCmd),
    Status(StatusCmd),
    Shared(SharedCmd),
}

/// worktree を作成して VSCode で開く
#[derive(FromArgs)]
#[argh(subcommand, name = "new")]
struct NewCmd {
    /// 既存ブランチをチェックアウト（省略でブランチ自動生成）
    #[argh(option, short = 'b')]
    branch: Option<String>,

    /// worktree を作成するパス (default: ../<branch>)
    #[argh(option, short = 'd')]
    directory: Option<String>,
}

/// worktree を対話的に選択して削除する
#[derive(FromArgs)]
#[argh(subcommand, name = "rm")]
struct RmCmd {
    /// 未コミットの変更があっても強制削除する
    #[argh(switch, short = 'f')]
    force: bool,
}

/// workspace 一覧と shared ファイル状態を統合表示する
#[derive(FromArgs)]
#[argh(subcommand, name = "status")]
struct StatusCmd {}

/// 共有ファイル管理
#[derive(FromArgs)]
#[argh(subcommand, name = "shared")]
struct SharedCmd {
    #[argh(subcommand)]
    command: SharedCommand,
}

#[derive(FromArgs)]
#[argh(subcommand)]
enum SharedCommand {
    Init(SharedInitCmd),
    Track(SharedTrackCmd),
    Status(SharedStatusCmd),
    Push(SharedPushCmd),
    Pull(SharedPullCmd),
}

/// 共有ファイル管理の初期化
#[derive(FromArgs)]
#[argh(subcommand, name = "init")]
struct SharedInitCmd {}

/// ファイルを store に登録する
#[derive(FromArgs)]
#[argh(subcommand, name = "track")]
struct SharedTrackCmd {
    /// strategy (symlink or copy)
    #[argh(option, short = 's')]
    strategy: String,

    /// 追跡するファイルパス
    #[argh(positional)]
    file: String,
}

/// 共有ファイルの状態表示（詳細）
#[derive(FromArgs)]
#[argh(subcommand, name = "status")]
struct SharedStatusCmd {}

/// copy 追跡ファイルの変更を store に反映する
#[derive(FromArgs)]
#[argh(subcommand, name = "push")]
struct SharedPushCmd {
    /// ファイルパス（省略で全 copy ファイル）
    #[argh(positional)]
    file: Option<String>,
}

/// store から追跡ファイルを現在の worktree に配布する
#[derive(FromArgs)]
#[argh(subcommand, name = "pull")]
struct SharedPullCmd {
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
        bail!("store が未初期化です。先に 'ws shared init' を実行してください");
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

// --- fzf ヘルパー ---

fn fzf_select(items: &[&str], prompt: &str) -> Result<Option<String>> {
    let input = items.join("\n");

    let mut fzf = Command::new("fzf")
        .arg(format!("--prompt={} ", prompt))
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
        Ok(None)
    } else {
        Ok(Some(selected))
    }
}

fn read_input(prompt: &str) -> Result<String> {
    eprint!("{}: ", prompt);
    io::stderr().flush()?;
    let mut buf = String::new();
    io::stdin().read_line(&mut buf)?;
    Ok(buf.trim().to_string())
}

// --- コマンド: new ---

fn generate_branch() -> Result<String> {
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
            break Ok(candidate);
        }
        n += 1;
    }
}

fn cmd_new(cmd: &NewCmd) -> Result<()> {
    let branch = match &cmd.branch {
        Some(b) => b.clone(),
        None => generate_branch()?,
    };

    let directory = cmd
        .directory
        .clone()
        .unwrap_or_else(|| format!("../{}", branch.replace('/', "-")));

    let branch_exists = Command::new("git")
        .args(["show-ref", "--verify", "--quiet", &format!("refs/heads/{}", branch)])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    let args = if branch_exists {
        // 既存ブランチをチェックアウト
        vec!["worktree", "add", &directory, &branch]
    } else {
        // 新規ブランチを作成
        vec!["worktree", "add", "-b", &branch, &directory, "HEAD"]
    };

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

// --- コマンド: rm ---

fn cmd_rm(cmd: &RmCmd) -> Result<()> {
    let worktree_list = git_output(&["worktree", "list"])?;
    let lines: Vec<&str> = worktree_list.lines().skip(1).collect();

    if lines.is_empty() {
        println!("削除可能な worktree はありません");
        return Ok(());
    }

    let selected = fzf_select(&lines, "削除する worktree を選択:")?;

    let selected = match selected {
        Some(s) => s,
        None => {
            println!("キャンセルしました");
            return Ok(());
        }
    };

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

// --- コマンド: status (統合) ---

fn cmd_status() -> Result<()> {
    let worktree_list = git_output(&["worktree", "list"])?;
    println!("Workspaces:");

    let main_wt_root = worktree_root().ok();
    let store_available = store_dir()
        .ok()
        .filter(|s| s.is_dir() && s.join("manifest").is_file());

    for line in worktree_list.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 3 {
            continue;
        }
        let wt_path = parts[0];
        let branch_info = parts[2..].join(" ");

        let is_main = main_wt_root
            .as_ref()
            .map(|r| r.to_str() == Some(wt_path))
            .unwrap_or(false);

        let marker = if is_main { "*" } else { " " };

        let tracked_info = if let Some(ref store) = store_available {
            let entries = read_manifest(store).unwrap_or_default();
            if !entries.is_empty() {
                format!("  [{} files tracked]", entries.len())
            } else {
                String::new()
            }
        } else {
            String::new()
        };

        println!(
            "  {} {:<40} {}{}",
            marker, wt_path, branch_info, tracked_info
        );
    }

    // Shared files セクション
    if let Some(store) = store_available {
        let entries = read_manifest(&store)?;
        if !entries.is_empty() {
            println!();
            println!("Shared files:");
            println!(
                "  {:<8} {:<40} {}",
                "STRATEGY", "FILE", "STATUS"
            );
            println!(
                "  {:<8} {:<40} {}",
                "--------", "----------------------------------------", "----------"
            );

            let wt_root = worktree_root().ok();

            for entry in &entries {
                let store_file = store.join(&entry.filepath);
                let status = file_status(entry, &store_file, &wt_root);
                println!(
                    "  {:<8} {:<40} {}",
                    entry.strategy, entry.filepath, status
                );
            }
        }
    }

    Ok(())
}

fn file_status(
    entry: &ManifestEntry,
    store_file: &Path,
    wt_root: &Option<PathBuf>,
) -> &'static str {
    if !store_file.is_file() {
        return "MISSING(store)";
    }

    let Some(ref root) = wt_root else {
        return "(store のみ)";
    };

    let wt_file = root.join(&entry.filepath);
    let wt_exists = wt_file.exists() || wt_file.symlink_metadata().is_ok();

    if !wt_exists {
        return "MISSING";
    }

    if entry.strategy == "symlink" {
        let is_link = wt_file
            .symlink_metadata()
            .map(|m| m.file_type().is_symlink())
            .unwrap_or(false);

        if !is_link {
            return "NOT_LINK";
        }

        let link_target = match fs::read_link(&wt_file) {
            Ok(t) => t,
            Err(_) => return "ERROR",
        };
        if link_target != *store_file {
            "WRONG_LINK"
        } else {
            "OK"
        }
    } else if entry.strategy == "copy" {
        let store_content = fs::read(store_file).ok();
        let wt_content = fs::read(&wt_file).ok();
        if store_content != wt_content {
            "MODIFIED"
        } else {
            "OK"
        }
    } else {
        "OK"
    }
}

// --- コマンド: shared ---

fn cmd_shared_init() -> Result<()> {
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

fn cmd_shared_track(cmd: &SharedTrackCmd) -> Result<()> {
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
        fs::copy(&source, &store_file).context("store へのコピーに失敗しました")?;

        if !is_symlink {
            fs::remove_file(&source)?;
            unix_fs::symlink(&store_file, &source)?;
            println!("{} をシンボリックリンクに変換しました", cmd.file);
        }
    } else {
        fs::copy(&source, &store_file).context("store へのコピーに失敗しました")?;
    }

    println!("追跡を開始しました: {}:{}", cmd.strategy, cmd.file);
    Ok(())
}

fn cmd_shared_status() -> Result<()> {
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
        let status = file_status(entry, &store_file, &wt_root);
        println!("{:<8} {:<40} {}", entry.strategy, entry.filepath, status);
    }

    Ok(())
}

fn cmd_shared_push(cmd: &SharedPushCmd) -> Result<()> {
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

fn cmd_shared_pull(cmd: &SharedPullCmd) -> Result<()> {
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

// --- インタラクティブモード ---

fn interactive_mode() -> Result<()> {
    let top_items = &[
        "new       workspace を作成",
        "rm        workspace を削除",
        "status    全体の状態表示",
        "shared    共有ファイル管理",
    ];

    let selected = fzf_select(top_items, "コマンドを選択:")?;
    let selected = match selected {
        Some(s) => s,
        None => {
            println!("キャンセルしました");
            return Ok(());
        }
    };

    let cmd = selected.split_whitespace().next().unwrap_or("");

    match cmd {
        "new" => interactive_new(),
        "rm" => cmd_rm(&RmCmd { force: false }),
        "status" => cmd_status(),
        "shared" => interactive_shared(),
        _ => bail!("不明なコマンド: {}", cmd),
    }
}

fn interactive_new() -> Result<()> {
    let branch_input = read_input("既存ブランチ名 (空で自動生成)")?;
    let branch = if branch_input.is_empty() {
        None
    } else {
        Some(branch_input)
    };

    let dir_input = read_input("ディレクトリ (空でデフォルト)")?;
    let directory = if dir_input.is_empty() {
        None
    } else {
        Some(dir_input)
    };

    cmd_new(&NewCmd {
        branch,
        directory,
    })
}

fn interactive_shared() -> Result<()> {
    let shared_items = &[
        "init      共有ファイル管理の初期化",
        "track     ファイルを登録",
        "status    共有ファイルの状態表示",
        "push      workspace → shared",
        "pull      shared → workspace",
    ];

    let selected = fzf_select(shared_items, "shared コマンドを選択:")?;
    let selected = match selected {
        Some(s) => s,
        None => {
            println!("キャンセルしました");
            return Ok(());
        }
    };

    let cmd = selected.split_whitespace().next().unwrap_or("");

    match cmd {
        "init" => cmd_shared_init(),
        "track" => interactive_shared_track(),
        "status" => cmd_shared_status(),
        "push" => {
            let file_input = read_input("ファイルパス (空で全 copy ファイル)")?;
            let file = if file_input.is_empty() {
                None
            } else {
                Some(file_input)
            };
            cmd_shared_push(&SharedPushCmd { file })
        }
        "pull" => {
            let file_input = read_input("ファイルパス (空で全追跡ファイル)")?;
            let file = if file_input.is_empty() {
                None
            } else {
                Some(file_input)
            };
            cmd_shared_pull(&SharedPullCmd { file, force: false })
        }
        _ => bail!("不明なコマンド: {}", cmd),
    }
}

fn interactive_shared_track() -> Result<()> {
    let strategy_items = &["symlink", "copy"];
    let strategy = fzf_select(strategy_items, "strategy を選択:")?;
    let strategy = match strategy {
        Some(s) => s,
        None => {
            println!("キャンセルしました");
            return Ok(());
        }
    };

    let file = read_input("追跡するファイルパス")?;
    if file.is_empty() {
        bail!("ファイルパスを入力してください");
    }

    cmd_shared_track(&SharedTrackCmd { strategy, file })
}

// --- メイン ---

fn run(ws: Ws) -> Result<()> {
    match ws.command {
        WsCommand::New(cmd) => cmd_new(&cmd),
        WsCommand::Rm(cmd) => cmd_rm(&cmd),
        WsCommand::Status(_) => cmd_status(),
        WsCommand::Shared(cmd) => match cmd.command {
            SharedCommand::Init(_) => cmd_shared_init(),
            SharedCommand::Track(c) => cmd_shared_track(&c),
            SharedCommand::Status(_) => cmd_shared_status(),
            SharedCommand::Push(c) => cmd_shared_push(&c),
            SharedCommand::Pull(c) => cmd_shared_pull(&c),
        },
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "-i" || a == "--interactive") {
        if let Err(e) = interactive_mode() {
            eprintln!("エラー: {:#}", e);
            std::process::exit(1);
        }
    } else {
        let ws: Ws = argh::from_env();
        if let Err(e) = run(ws) {
            eprintln!("エラー: {:#}", e);
            std::process::exit(1);
        }
    }
}
