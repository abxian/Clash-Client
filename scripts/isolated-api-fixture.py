#!/usr/bin/env python3
"""#211 loopback-only development fixture; no production credentials or proxy connectivity.

--port 0 (default) chooses a free local port; --state writes a base URL and sanitized request
paths for the test runner. All fixture values are deliberately fake. Stop with Ctrl-C.
"""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import subprocess
from pathlib import Path
import threading
from urllib.parse import urlsplit

CONFIG = """mixed-port: 7890
mode: rule
log-level: warning
dns:
  enable: true
  nameserver: [223.5.5.5]
proxies:
  - name: 隔离测试节点
    type: ss
    server: 127.0.0.1
    port: 9
    cipher: aes-128-gcm
    password: fake-fixture-only
proxy-groups:
  - name: 神仙云节点
    type: select
    proxies: [隔离测试节点, DIRECT]
rules:
  - DOMAIN,example.invalid,DIRECT
  - MATCH,神仙云节点
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-tests", action="store_true")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--control", type=Path, help="Optional fake recovery/migration state JSON, never production data")
    parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args()
    lock = threading.Lock()
    requests = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *unused):
            pass

        def reply(self, status, value, content_type="application/json"):
            data = json.dumps(value, ensure_ascii=False).encode() if isinstance(value, dict) else value.encode()
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            self.handle_request({})

        def do_POST(self):
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length > 16384:
                    return self.reply(413, {"ok": False})
                body = json.loads(self.rfile.read(length) or b"{}")
            except (ValueError, TypeError):
                return self.reply(400, {"ok": False})
            self.handle_request(body)

        def handle_request(self, body):
            path = urlsplit(self.path).path
            # Record only method/path/status intent; never request bodies or bearer headers.
            with lock:
                requests.append({"method": self.command, "path": path})
                args.state.write_text(json.dumps({"base": base, "requests": requests}, ensure_ascii=False, indent=2))
            control = json.loads(args.control.read_text()) if args.control and args.control.exists() else {}
            if path == "/api/update-state/fixture211":
                reason = control.get("restriction")
                if reason:
                    return self.reply(404, {"ok": False, "code": reason, "message": "隔离测试：" + reason})
                return self.reply(200, {"ok": True, "update_version": control.get("version", 10),
                    "subscription_revision": control.get("revision", "fixture-A"),
                    "expires_at": control.get("expires_at", "2099-12-31 23:59:59")})
            if path == "/api/endpoints":
                return self.reply(200, {"api_bases": [base], "sub_base": base, "version": 1})
            if path == "/api/verify":
                valid = body.get("code") == "fixture211"
                return self.reply(200, {"success": valid, "protected_mode": True,
                                       "imports": {"shenxianyun": True}, "expire_time": "2099-12-31 23:59:59",
                                       "message": "" if valid else "隔离测试：提取码无效"})
            if path == "/api/import/ticket":
                if body.get("code") != "fixture211" or body.get("target") != "shenxianyun":
                    return self.reply(403, {"ok": False})
                return self.reply(200, {"ok": True, "launch_url": base + "/import/launch/fixture-ticket"})
            if path == "/api/import/exchange":
                if body.get("ticket") != "fixture-ticket":
                    return self.reply(410, {"ok": False})
                return self.reply(200, {"ok": True, "name": "fixture211", "expires_at": "2099-12-31 23:59:59",
                                       "device_token": "fixture-device-token", "device_id": "fixture-device",
                                       "subscription_url": base + "/managed-sub/fixture-config", "limit_mode": "device"})
            if path == "/managed-sub/fixture-config":
                if control.get("fail_download"):
                    return self.reply(503, {"ok": False})
                content = CONFIG.replace("隔离测试节点", control.get("node_name", "隔离测试节点"))
                return self.reply(200, content, "text/yaml; charset=utf-8")
            if path.startswith("/api/v2/client/"):
                if self.headers.get("Authorization") != "Bearer fixture-device-token":
                    return self.reply(401, {"ok": False})
                return self.reply(200, {"ok": True, "expires_at": "2099-12-31 23:59:59"})
            return self.reply(404, {"ok": False})

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    base = "http://127.0.0.1:" + str(server.server_port)
    args.state.parent.mkdir(parents=True, exist_ok=True)
    args.state.write_text(json.dumps({"base": base, "requests": []}, indent=2))
    print(base, flush=True)
    if args.run_tests:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            result = subprocess.run(["swift", "test", "--package-path", "apple/ShenxianyunKit",
                                     "--filter", "LoopbackIntegrationTests"],
                                    env=dict(os.environ, SXY_TEST_API_BASE=base))
            if result.returncode == 0:
                result = subprocess.run(["swift", "test", "-c", "release", "--package-path", "apple/ShenxianyunKit",
                                         "--filter", "ReleaseBootstrapTests"],
                                        env=dict(os.environ, SXY_TEST_API_BASE=base))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
        raise SystemExit(result.returncode)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
