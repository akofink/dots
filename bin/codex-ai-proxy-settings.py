#!/usr/bin/env python3
"""Apply and remove the work-machine Codex provider and model defaults."""
import json
import os
from pathlib import Path
import re
import sys
import tempfile


ROOT_START = "# BEGIN dots ai-proxy defaults\n"
ROOT_END = "# END dots ai-proxy defaults\n"
PROVIDER_START = "# BEGIN dots ai-proxy provider\n"
PROVIDER_END = "# END dots ai-proxy provider\n"
SAVED = "# dots ai-proxy original: "


def configure(config, enabled, url, helper):
    root, provider = "", ""
    remaining = []
    block = None
    for line in config.splitlines(keepends=True):
        if line in (ROOT_START, PROVIDER_START):
            block = line
        elif line in (ROOT_END, PROVIDER_END):
            block = None
        elif block == ROOT_START and line.startswith(SAVED):
            remaining.append(line[len(SAVED):])
        elif block is None:
            remaining.append(line)

    if not enabled:
        return "".join(remaining)

    defaults = []
    for index, line in enumerate(remaining):
        if line.lstrip().startswith("["):
            break
        if re.match(r"^\s*(model|model_provider)\s*=", line):
            defaults.append(index)

    saved = [SAVED + remaining.pop(index).rstrip("\n") + "\n" for index in reversed(defaults)]
    root = ROOT_START + "".join(reversed(saved))
    root += 'model = "gpt-6.2-sol"\nmodel_provider = "internal-ai-proxy"\n' + ROOT_END

    if not re.search(r"^\s*\[model_providers\.internal-ai-proxy[.\]]", "".join(remaining), re.M):
        provider = (
            PROVIDER_START
            + "[model_providers.internal-ai-proxy]\n"
            + 'name = "Internal AI Proxy"\n'
            + f"base_url = {json.dumps(url + '/v1')}\n"
            + 'wire_api = "responses"\n'
            + "[model_providers.internal-ai-proxy.auth]\n"
            + f"command = {json.dumps(helper)}\n"
            + f"args = {json.dumps(['--base-url', url])}\n"
            + "timeout_ms = 35000\n"
            + PROVIDER_END
        )

    if provider and remaining and not remaining[-1].endswith("\n"):
        remaining[-1] += "\n"
    return root + "".join(remaining) + provider


def main():
    settings, mode, url, helper = sys.argv[1:]
    path = Path(settings)
    original = path.read_text() if path.exists() else ""
    updated = configure(original, mode == "apply", url, helper)
    if updated == original:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as temp:
        try:
            temp.write(updated)
            temp.close()
            os.replace(temp.name, path)
        finally:
            Path(temp.name).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
