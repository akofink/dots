#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo_root/templates/dot_pi/agent/settings.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as settings_file:
    settings = json.load(settings_file)

assert settings["defaultProvider"] == "openai-codex"
assert settings["defaultModel"] == "gpt-5.6-luna"
assert settings["defaultThinkingLevel"] == "high"
# Preserve terminal scrollback and keep Pi's built-in MCP enabled.
assert settings["tuiMode"] == "regular"
assert "-builtin:mcp" not in settings.get("extensions", [])
assert not any("pi-mcp-adapter" in str(package) for package in settings["packages"])
assert "npm:pi-web-search@1.6.0" in settings["packages"]
assert settings["retry"] == {
    "enabled": True,
    "maxRetries": 8,
    "baseDelayMs": 2000,
    "provider": {"maxRetries": 0},
}
PY

printf 'pi-settings-test: ok\n'
