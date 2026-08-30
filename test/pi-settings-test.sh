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
assert settings["retry"] == {
    "enabled": True,
    "maxRetries": 8,
    "baseDelayMs": 2000,
    "provider": {"maxRetries": 0},
}
PY

printf 'pi-settings-test: ok\n'
