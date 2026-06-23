# 実装プラン: Codex デスクトップアプリで Sakana (fugu) を使うためのローカル除去プロキシ

> このドキュメントは Codex に実装させるためのタスク仕様。背景・確定事項・成果物・検証手順・受け入れ条件を含む。
> リポジトリは nix-darwin (Lix)。宣言的管理が原則。`darwin-rebuild switch` はユーザー確認後のみ実行する。

## 1. 背景と根本原因（調査済み・確定）

Codex で Sakana の `fugu` / `fugu-ultra` を使うと、リクエストが次のエラーで弾かれる:

```
Invalid value: 'image_generation'. Supported values are: 'function' and 'custom'. (param: tools)
```

- Sakana の Responses 互換 API (`https://api.sakana.ai/v1/responses`) は `tools[]` の型として
  **`function` と `custom` しか受け付けない**。Codex が hosted tool `{"type":"image_generation"}`
  を `tools[]` に同梱するため、リクエスト全体が 400 で拒否される。
- **既知の未修正バグ**: [openai/codex#21952](https://github.com/openai/codex/issues/21952)
  「`app-server` は `[features].image_generation = false` も `--disable image_generation` も無視する。
  `exec` だけが尊重する」。根本原因は app-server 経路が `ProviderCapabilities` / `ToolCapabilityBounds`
  を first-party プロバイダ向けにハードコードしており、ユーザー定義プロバイダ（= Sakana）は
  「全 capability 許可」がデフォルトになって `[features]` を上書きするため。
- 実測でも一致: `codex exec`（CLI）は `config.toml` の `image_generation = false` を尊重して当該ツールを
  落とすが、**デスクトップアプリ（app-server 経由）は無視して送る**。アプリのログに実リクエストを確認済み:
  `{"type":"web_search",...},{"type":"image_generation","output_format":"png"}`。
- したがって **config.toml の編集・アプリ再起動・PC 再起動では直らない**。issue 記載の
  ワークアラウンド（ローカルプロキシで `image_generation` を除去）が唯一の実用解。

## 2. 確定済みの設計判断（前提として扱う。再検討不要）

1. **除去対象は `image_generation` のみ**で十分。
   - 根拠: CLI 経由のリクエストは `image_generation` を除いた状態で `web_search` と
     `multi_agent_v1`（`namespace` 型）を**残したまま Sakana に通っている**。
     エラーメッセージ上は `function` / `custom` のみ対応に見えるが、手元の実測では
     `web_search` / `namespace` も受理されている。
     GUI が追加で足す mcp 系ツールも同じ `namespace` 型なので通る想定。
   - 保険として除去リストは**簡単に追記できる形**にする。万一 `Invalid value: 'X'` が新たに出たら
     `X` をリストに足すだけで対応できるようにする。
2. **方式はローカルリバースプロキシ**。Codex アプリは `config.toml` の `base_url` だけは尊重して
   そこへ送る（実際に Sakana へ到達している）。この性質を使い、`base_url` をローカルプロキシに向け、
   プロキシが `tools[]` から除去対象を落として upstream へ転送する。
3. **認証はプロキシで触らない**。Codex は `op read` で得たトークンを `Authorization: Bearer` で
   `base_url` に送る。プロキシは `Authorization` ヘッダをそのまま素通しするだけ。プロキシ自身は
   1Password も認証情報も扱わない。
4. **CLI 用の `[features] image_generation = false` は残す**。これは CLI 経路で fugu を動かすのに
   必要（消すと CLI でも弾かれる）。プロキシ導入後もそのまま。

## 3. アーキテクチャ

```
┌─────────────────┐   POST http://127.0.0.1:8787/v1/responses    ┌──────────────────────┐
│ Codex desktop   │   tools:[...,image_generation,...]           │ ローカルプロキシ      │
│ (app-server)    │ ───────────────────────────────────────────▶ │ 127.0.0.1:8787       │
│ base_url=proxy  │   Authorization: Bearer <op token>           │ - tools[] から        │
└─────────────────┘                                              │   image_generation 除去│
        ▲                                                        │ - SSE はバッファせず  │
        │   SSE ストリームをそのまま中継                          │   素通し              │
        └────────────────────────────────────────────────────── │ - 他ヘッダ/ボディ素通し│
                                                                 └──────────┬───────────┘
                                                                            │ POST https://api.sakana.ai/v1/responses
                                                                            ▼
                                                                 ┌──────────────────────┐
                                                                 │ Sakana API            │
                                                                 └──────────────────────┘
```

- プロキシは **127.0.0.1 のみ** で listen（トークンを中継するためネットワーク公開しない）。
- `8787` が使用中なら既存プロセスを勝手に停止しない。別ポートにする場合は `proxyPort` /
  `CODEX_SAKANA_PROXY_PORT` / `config.toml` の `base_url` を必ず同時に変更する。
- 受信パスをそのまま `https://api.sakana.ai` + path に転送（`/v1/responses` も `/v1/models` 等も）。
- メソッド・ヘッダ・クエリを素通し。`POST` かつ `Content-Type: application/json` のときだけ
  ボディの `tools[]` を検査して除去対象を落とし、`Content-Length` を再計算。
- レスポンスは**ストリーミング転送**（SSE をバッファすると UI が固まるため必須）。

## 4. 成果物（リポジトリへの変更）

### 4-1. プロキシ本体スクリプト

`home/config/codex/sakana-tool-strip-proxy.py` を新規作成。**Python 標準ライブラリのみ**（外部依存なし）。
以下を参照実装とする（細部の改善は可、ただし「SSE をバッファしない」「Authorization 素通し」
「127.0.0.1 限定」「除去対象を簡単に追記できる」は必須要件）。

> 重要: このファイルは Nix store に取り込むため、build 前に Git 管理対象にする。
> 未追跡のままだと flakes の source に含まれず、`darwin-rebuild build --flake .` から見えない。

```python
#!/usr/bin/env python3
"""Codex -> Sakana 中継プロキシ。tools[] から Sakana 非対応の hosted tool を除去する。

Codex デスクトップアプリ (app-server) は openai/codex#21952 のバグにより
image_generation ツールを必ず送ってしまい、Sakana は function/custom 以外を拒否する。
このプロキシが該当ツールを落としてから転送する。SSE はバッファせず素通しする。
"""
import http.server
import socketserver
import urllib.request
import urllib.error
import json
import os

UPSTREAM = os.environ.get("CODEX_SAKANA_UPSTREAM", "https://api.sakana.ai")
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("CODEX_SAKANA_PROXY_PORT", "8787"))

# Sakana が受け付けない tool 型。新たな "Invalid value: 'X'" が出たら X をここに足す。
STRIP_TOOL_TYPES = {"image_generation"}

HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade",
}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass  # 静かにする（必要なら stderr へ）

    def _handle(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""

        # JSON ボディなら tools[] から除去対象を落とす
        ctype = self.headers.get("Content-Type", "")
        if body and "application/json" in ctype.lower():
            try:
                payload = json.loads(body)
                tools = payload.get("tools")
                if isinstance(tools, list):
                    filtered = [
                        t for t in tools
                        if not (isinstance(t, dict) and t.get("type") in STRIP_TOOL_TYPES)
                    ]
                    if len(filtered) != len(tools):
                        payload["tools"] = filtered
                        body = json.dumps(payload).encode("utf-8")
            except (ValueError, TypeError):
                pass  # パースできなければ素通し

        # upstream へ転送リクエストを組む
        url = UPSTREAM + self.path
        fwd = urllib.request.Request(url=url, data=body or None, method=self.command)
        for key, value in self.headers.items():
            lk = key.lower()
            if lk in HOP_BY_HOP or lk in ("host", "content-length", "accept-encoding"):
                continue
            fwd.add_header(key, value)
        if body:
            fwd.add_header("Content-Length", str(len(body)))

        # 転送。4xx/5xx もそのままクライアントへ返す
        try:
            resp = urllib.request.urlopen(fwd, timeout=None)
        except urllib.error.HTTPError as e:
            resp = e
        except Exception as e:  # noqa: BLE001
            msg = f'{{"error":{{"message":"proxy upstream error: {e}"}}}}'.encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(msg)
            return

        status = getattr(resp, "status", None) or getattr(resp, "code", 200)
        self.send_response(status)
        for key, value in resp.headers.items():
            if key.lower() in HOP_BY_HOP or key.lower() == "content-length":
                continue
            self.send_header(key, value)
        self.send_header("Connection", "close")  # close 区切りでストリーム
        self.end_headers()

        # SSE をバッファせず逐次中継（read1 で到着分をすぐ流す）
        reader = resp
        while True:
            try:
                chunk = reader.read1(65536) if hasattr(reader, "read1") else reader.read(65536)
            except Exception:  # noqa: BLE001
                break
            if not chunk:
                break
            try:
                self.wfile.write(chunk)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                break
        try:
            resp.close()
        except Exception:  # noqa: BLE001
            pass

    do_GET = _handle
    do_POST = _handle
    do_PUT = _handle
    do_PATCH = _handle
    do_DELETE = _handle


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    with ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler) as httpd:
        httpd.serve_forever()
```

> 注意点（実装時に確認）:
> - `accept-encoding` は転送リクエストから除去している（upstream を非圧縮で返させ、SSE をそのまま中継するため）。
> - `protocol_version = "HTTP/1.1"` + `Connection: close` + Content-Length 省略で、close 区切りの
>   ストリーミングにする。クライアント (Codex) はこれで SSE を受け取れる。動作確認で UI が固まらないこと。

### 4-2. launchd 常駐サービス（home-manager）

`home/modules/agents/default.nix` に LaunchAgent を追加し、ログイン時に常駐起動する。
このリポジトリには launchd の前例が無いので新規に導入する。home-manager の `launchd.agents` を使う。

- ランタイムは **nixpkgs の `pkgs.python3`** を使う（再現性のため。`/usr/bin/python3` に依存しない）。
- スクリプトは `${./.. /config/codex/sakana-tool-strip-proxy.py}` 相当のパスで Nix store に取り込む
  （静的なので in-store で問題ない）。`default.nix` から見た相対パスに注意
  （`default.nix` は `home/modules/agents/` にあるので `../../config/codex/sakana-tool-strip-proxy.py`）。

追加するイメージ（`default.nix` 内、`let ... in` で `proxyScript` を定義し `{ ... }` 内に `launchd` を追加）:

```nix
let
  # 既存の let 束縛に追記
  proxyScript = ../../config/codex/sakana-tool-strip-proxy.py;
  proxyPort = "8787";
in
{
  # 既存定義はそのまま

  launchd.agents.codex-sakana-proxy = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.python3}/bin/python3" "${proxyScript}" ];
      EnvironmentVariables = {
        CODEX_SAKANA_PROXY_PORT = proxyPort;
        CODEX_SAKANA_UPSTREAM = "https://api.sakana.ai";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/codex-sakana-proxy.log";
      StandardErrorPath = "/tmp/codex-sakana-proxy.err.log";
      ProcessType = "Background";
    };
  };
}
```

> 確認事項: このリポジトリの home-manager で `launchd.agents.<name>.config` が利用可能か
> （home-manager の darwin サポート）。利用不可なら nix-darwin の `launchd.user.agents.<name>.serviceConfig`
> に置き換える（その場合は `home/` ではなく `flake.nix` 側の darwin module になる）。
> どちらを使ったか実装メモに残すこと。

### 4-3. `base_url` をプロキシに向ける

`home/config/codex/config.toml` の `[model_providers.sakana]` を変更:

```toml
[model_providers.sakana]
name = "Sakana API"
base_url = "http://127.0.0.1:8787/v1"   # ← プロキシ経由に変更（元: https://api.sakana.ai/v1）
wire_api = "responses"
# 他のキー（stream_idle_timeout_ms 等）と [model_providers.sakana.auth] はそのまま
```

`[model_providers.sakana.auth]`（`op read`）は**変更しない**。トークンはプロキシを素通りして Sakana に届く。

この `base_url` は Codex デスクトップアプリだけでなく `codex exec` などの CLI 経路にも効く。
したがって導入後の Sakana 利用は CLI もプロキシ稼働に依存する。

> 重要な前提（リンク状態）: 現状 `~/.codex/config.toml` は **nix store への symlink**（読み取り専用）に
> なっている一方、`default.nix` は `mkOutOfStoreSymlink`（リポジトリ実ファイルへの直リンク）を宣言している。
> これは「`default.nix` を out-of-store に変えた後 `darwin-rebuild switch` がまだ走っていない」状態。
> このプランの適用には `darwin-rebuild switch` が必要で、それにより `~/.codex/config.toml` が
> リポジトリ実ファイルへの out-of-store リンクに切り替わり、`base_url` 変更が反映される。

## 5. 適用手順

1. 4-1〜4-3 を実装。
2. `git status --short` で既存の unrelated な変更を確認し、今回の実装では触らない。
3. `git add home/config/codex/sakana-tool-strip-proxy.py` などで、Nix store に取り込む新規ファイルを
   Git 管理対象にする。
4. `nix fmt .` でフォーマット。
5. `darwin-rebuild build --flake .` でビルド検証（システム変更なし、sudo 不要）。エラーがないこと。
6. **ここで一旦停止し、ユーザーに変更内容を説明して `sudo darwin-rebuild switch --flake .` の許可を得る**
   （リポジトリのルール: switch は必ず確認後）。
7. switch 後、launchd エージェントが起動していることを確認（§6）。
8. Codex デスクトップアプリを**完全終了 → 再起動**（app-server に新 `base_url` を読ませる）。
   実装者がこの会話セッション内で勝手にアプリを終了せず、ユーザーが手動で行う。

## 6. 検証

### 6-1. プロキシ単体（オフラインで除去ロジックを確認、Sakana に課金しない）

ローカルのダミー upstream を立て、プロキシが `image_generation` を落とすことを確認する:

```bash
# ダミー upstream（受信ボディを保存して 200 を返す）を 9999 で起動
cat > /tmp/codex-sakana-dummy-upstream.py <<'PY'
import http.server

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("content-length") or 0)
        body = self.rfile.read(length)
        open("/tmp/codex-sakana-upstream-body.json", "wb").write(body)
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

http.server.ThreadingHTTPServer(("127.0.0.1", 9999), Handler).serve_forever()
PY
python3 /tmp/codex-sakana-dummy-upstream.py &
dummy_pid=$!

# プロキシの UPSTREAM を dummy へ向ける
CODEX_SAKANA_UPSTREAM="http://127.0.0.1:9999" CODEX_SAKANA_PROXY_PORT=8787 \
  python3 home/config/codex/sakana-tool-strip-proxy.py &
proxy_pid=$!

# image_generation と web_search を含む tools[] を投げる
curl -s -XPOST http://127.0.0.1:8787/v1/responses \
  -H 'Content-Type: application/json' \
  -d '{"tools":[{"type":"function","name":"f"},{"type":"web_search"},{"type":"image_generation","output_format":"png"}]}'

# ダミー upstream が受け取ったボディの tools[] に image_generation が無く、function/web_search は残ることを確認
cat /tmp/codex-sakana-upstream-body.json

# 後片付け
kill "$proxy_pid" "$dummy_pid"
```

期待: 転送後ボディの `tools[]` から `image_generation` のみ消え、`function` と `web_search` は残る。

### 6-2. launchd 常駐の確認

```bash
launchctl list | grep codex-sakana-proxy        # 登録・稼働確認
lsof -nP -iTCP:8787 -sTCP:LISTEN                 # 127.0.0.1:8787 で listen 確認
cat /tmp/codex-sakana-proxy.err.log              # エラーが無いこと
```

### 6-3. 実機（デスクトップアプリ）

アプリ再起動後、fugu / fugu-ultra で1ターン送信し、`image_generation` エラーが出ず応答がストリーミング
表示されることを確認。必要ならアプリのログ DB で送信先が `127.0.0.1:8787` になっていることを確認:

```bash
sqlite3 ~/.codex/logs_2.sqlite \
 "SELECT datetime(ts,'unixepoch','localtime'), substr(feedback_log_body,1,200)
  FROM logs WHERE feedback_log_body LIKE '%127.0.0.1:8787%' ORDER BY ts DESC LIMIT 3;"
```

## 7. 受け入れ条件

- [ ] `darwin-rebuild build --flake .` が通る。
- [ ] switch 後、`codex-sakana-proxy` が launchd で常駐し 127.0.0.1:8787 で listen している。
- [ ] 6-1 でプロキシが `image_generation` のみ除去し他ツールを保持する。
- [ ] デスクトップアプリで fugu/fugu-ultra が `image_generation` エラーなく動き、応答がストリーム表示される。
- [ ] CLI 経路（`codex exec` での fugu）も、プロキシ稼働中に従来どおり動く
      （`[features] image_generation = false` は残置）。
- [ ] 1Password 連携（`op read`）はプロキシを介しても従来どおり機能する。

## 8. ロールバック

- `home/config/codex/config.toml` の `base_url` を `https://api.sakana.ai/v1` に戻す。
- `default.nix` の `launchd.agents.codex-sakana-proxy` を削除。
- `nix fmt . && darwin-rebuild switch --flake .`。launchd エージェントは home-manager が unload する。

## 9. 既知の制約・補足

- 本対応は openai/codex#21952 が修正されれば不要になる。修正版が出たら、アプリが
  `[features].image_generation = false` を尊重するか再確認し、尊重するならプロキシを撤去してよい。
- 除去対象は現状 `image_generation` のみで十分（§2-1 の根拠）。将来 Sakana 側仕様変更や Codex が
  別の hosted tool（例: 新しい型）を足して `Invalid value: 'X'` が出たら、`STRIP_TOOL_TYPES` に `X` を追加。
- プロキシはトークンを中継するため必ず 127.0.0.1 限定で待ち受ける（外部公開しない）。
