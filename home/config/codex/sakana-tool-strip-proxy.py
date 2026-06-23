#!/usr/bin/env python3
"""Codex -> Sakana 中継プロキシ。

Codex デスクトップアプリ (app-server) は現状、設定で無効化しても
hosted tool の image_generation を Responses API の tools[] に含めて送る。
Sakana の Responses 互換 API はその tool 型を受け付けないため、このプロキシで
該当 tool だけを取り除いてから upstream に転送する。

認証情報は扱わず、Authorization ヘッダを含むリクエストヘッダは必要なものを
そのまま転送する。レスポンスは SSE をバッファせず逐次中継する。
"""

import http.server
import json
import os
import socketserver
import urllib.error
import urllib.request

UPSTREAM = os.environ.get("CODEX_SAKANA_UPSTREAM", "https://api.sakana.ai").rstrip("/")
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("CODEX_SAKANA_PROXY_PORT", "8787"))

# Sakana が受け付けない tool 型。新たな "Invalid value: 'X'" が出たら X をここに足す。
STRIP_TOOL_TYPES = {"image_generation"}

HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "trailers",
    "transfer-encoding",
    "upgrade",
}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        # launchd のログを通常時は静かに保つ。
        pass

    def _handle(self):
        body = self._read_request_body()
        body = self._strip_unsupported_tools(body)
        upstream_request = self._build_upstream_request(body)

        try:
            upstream_response = urllib.request.urlopen(upstream_request, timeout=None)
        except urllib.error.HTTPError as error:
            upstream_response = error
        except Exception as error:  # noqa: BLE001
            self._send_proxy_error(error)
            return

        try:
            self._send_upstream_response(upstream_response)
        finally:
            try:
                upstream_response.close()
            except Exception:  # noqa: BLE001
                pass

    def _read_request_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return b""
        return self.rfile.read(length)

    def _strip_unsupported_tools(self, body):
        content_type = self.headers.get("Content-Type", "")
        if not body or "application/json" not in content_type.lower():
            return body

        try:
            payload = json.loads(body)
        except (ValueError, TypeError):
            return body

        if not isinstance(payload, dict):
            return body

        tools = payload.get("tools")
        if not isinstance(tools, list):
            return body

        filtered_tools = [
            tool
            for tool in tools
            if not (isinstance(tool, dict) and tool.get("type") in STRIP_TOOL_TYPES)
        ]
        if len(filtered_tools) == len(tools):
            return body

        payload["tools"] = filtered_tools
        return json.dumps(payload, separators=(",", ":")).encode("utf-8")

    def _build_upstream_request(self, body):
        request = urllib.request.Request(
            url=f"{UPSTREAM}{self.path}",
            data=body or None,
            method=self.command,
        )

        for key, value in self.headers.items():
            lower_key = key.lower()
            if lower_key in HOP_BY_HOP_HEADERS:
                continue
            if lower_key in {"host", "content-length", "accept-encoding"}:
                continue
            request.add_header(key, value)

        if body:
            request.add_header("Content-Length", str(len(body)))

        return request

    def _send_proxy_error(self, error):
        payload = {
            "error": {
                "message": f"proxy upstream error: {error}",
            },
        }
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")

        self.send_response(502)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _send_upstream_response(self, response):
        status = getattr(response, "status", None) or getattr(response, "code", 200)
        self.send_response(status)

        for key, value in response.headers.items():
            lower_key = key.lower()
            if lower_key in HOP_BY_HOP_HEADERS or lower_key == "content-length":
                continue
            self.send_header(key, value)

        # Content-Length を付けず close 区切りにすることで、SSE を逐次流す。
        self.send_header("Connection", "close")
        self.end_headers()

        while True:
            try:
                chunk = (
                    response.read1(65536)
                    if hasattr(response, "read1")
                    else response.read(65536)
                )
            except Exception:  # noqa: BLE001
                break
            if not chunk:
                break
            try:
                self.wfile.write(chunk)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                break

    do_DELETE = _handle
    do_GET = _handle
    do_PATCH = _handle
    do_POST = _handle
    do_PUT = _handle


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler) as httpd:
        httpd.serve_forever()
