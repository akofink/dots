#!/usr/bin/env python3
"""Test the Pi work launcher with an isolated home and loopback Responses fixture.

Run: python3 test/pi-work-proxy-test.py /absolute/path/to/managed/pi
"""

import json
import os
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = "gpt-6.2-sol"


class Responses(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.server.requests.append((self.path, data["model"], self.headers["Authorization"],
                                     data.get("reasoning", {}).get("effort")))
        if self.server.reject:
            self.send_response(403)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error":{"message":"fixture rejected request"}}')
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        part = {"type": "output_text", "text": "fixture-ok", "annotations": []}
        item = {"type": "message", "id": "msg_fixture", "role": "assistant", "content": [part]}
        for event in (
            {"type": "response.created", "response": {"id": "resp_fixture"}},
            {"type": "response.output_item.done", "output_index": 0, "item": item},
            {"type": "response.completed", "response": {"status": "completed", "model": MODEL}},
        ):
            self.wfile.write(f"data: {json.dumps(event)}\n\n".encode())


def script(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    path.chmod(0o700)


def main(real_pi):
    with tempfile.TemporaryDirectory(prefix="pi-work-proxy.") as tmp, HTTPServer(
        ("127.0.0.1", 0), Responses
    ) as server:
        server.requests, server.reject = [], False
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        home = Path(tmp)
        managed = home / ".pi/agent/bin/pi"
        helper = home / ".local/bin/internal-ai-proxy-api-key-helper"
        shim = home / ".local/bin/pi"
        script(managed, '#!/bin/sh\nprintf "direct:%s\\n" "$@"\n')
        launcher = ROOT / "bin/pi-work-proxy"
        shim.parent.mkdir(parents=True)
        shim.symlink_to(managed)
        env = {
            "PATH": os.environ["PATH"],
            "HOME": tmp,
            "MACHINE_CLASS": "work",
            "PI_OFFLINE": "1",
        }

        def invoke(executable, *args, **overrides):
            return subprocess.run([executable, *args], cwd=home, env=env | overrides,
                                  text=True, capture_output=True, timeout=30)

        def run(*args, **overrides):
            return invoke(launcher, *args, **overrides)

        link = ROOT / "bin/pi-work-proxy-link"
        assert invoke(link, "on").returncode and shim.readlink() == managed
        assert invoke(link, "on", MACHINE_CLASS="personal").returncode
        assert shim.readlink() == managed

        def expect_success(result, output):
            assert result.returncode == 0 and output in result.stdout, (result.stdout, result.stderr)

        expect_success(run("--direct", "--model", "other"), "direct:--model\ndirect:other")
        expect_success(run("arg with spaces", PI_DIRECT="1"), "direct:arg with spaces")
        expect_success(run("--model", "other", MACHINE_CLASS="personal"), "direct:other")
        expect_success(run("arg", MACHINE_CLASS=""), "direct:arg")
        assert "only supports" in run("--model", "other").stderr
        assert "other providers" in run("--provider", "openai", "--model", MODEL).stderr
        assert "endpoint is not configured" in run().stderr
        assert "not supported" in run("--session", "direct.jsonl").stderr
        assert "not supported" in run("--api-key", "synthetic").stderr

        origin = f"http://127.0.0.1:{server.server_port}"
        provision = home / ".config/dots/pi-work-proxy-url"
        provision.parent.mkdir(parents=True)
        provision.write_text(origin + "\n")
        assert "helper is missing" in run().stderr
        assert "HTTPS origin" in run(INTERNAL_AI_PROXY_URL="https://fake.test@other.test").stderr
        managed.unlink()
        managed.symlink_to(real_pi)
        script(helper, f'''#!/bin/sh
[ "$1" = --base-url ] && [ "$2" = "{origin}" ] || exit 1
printf '.\\n' >> "$HOME/mints"
printf 'fixture-token-%s\\n' "$(wc -l < "$HOME/mints" | tr -d ' ')"
''')
        (managed.parent.parent / "models.json").write_text(json.dumps({
            "providers": {"direct-fixture": {
                "baseUrl": origin + "/unexpected-route",
                "api": "openai-responses",
                "apiKey": "synthetic-direct",
                "models": [{"id": "direct-fixture"}],
            }},
        }))
        flags = ("--no-extensions", "--no-context-files", "--no-skills", "--no-session",
                 "--no-prompt-templates", "--no-themes", "--no-tools", "--no-approve",
                 "--thinking", "off", "-p", "synthetic")
        assert invoke(link, "on").returncode == 0 and shim.readlink() == launcher
        assert invoke(link, "on").returncode == 0  # idempotent
        expect_success(invoke(shim, *flags), "fixture-ok")
        expect_success(invoke(shim, "--provider", "openai-codex", "--model", MODEL, *flags), "fixture-ok")
        def expected(n):
            return ("/v1/responses", MODEL, f"Bearer fixture-token-{n}", "low")

        assert server.requests == [expected(1), expected(2)], server.requests
        switch = home / "switch-model.ts"
        switch.write_text('''export default function (pi) {
  pi.on("session_start", async (_event, ctx) => {
    const model = ctx.modelRegistry.find("direct-fixture", "direct-fixture");
    if (model) await pi.setModel(model);
  });
}
''')
        result = invoke(shim, "-e", str(switch), *flags)
        assert result.returncode and "route is unavailable or was changed" in result.stderr, result
        assert server.requests == [expected(1), expected(2)], server.requests

        server.reject = True
        result = run(*flags)
        assert result.returncode and "fixture rejected request" in result.stderr, result
        assert server.requests == [expected(1), expected(2), expected(3)], server.requests
        script(helper, "#!/bin/sh\nexit 19\n")
        assert run(*flags).returncode != 0
        assert len(server.requests) == 3, server.requests
        auth = home / ".pi/agent/auth.json"
        assert not auth.exists() or "fixture-token" not in auth.read_text()
        assert not (home / ".pi/agent/work-proxy-sessions").exists()
        assert invoke(link, "off").returncode == 0 and shim.readlink() == managed
        shim.unlink()
        script(shim, "#!/bin/sh\\nexit 99\\n")
        assert invoke(link, "on").returncode and shim.is_file() and not shim.is_symlink()
        server.shutdown()
        thread.join()
    print("pi-work-proxy-test: ok")


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve(strict=True))
