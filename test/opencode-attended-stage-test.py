#!/usr/bin/env python3
"""Isolated inert setup and shell-selection checks. No live client is started."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
setup = (repo/'setup/llm.sh').read_text()
stage = re.search(r'^sync_opencode_attended_stage\(\) \{.*?^\}', setup, re.M | re.S).group()
shell = re.search(r'^opencode\(\) \{.*?^\}', (repo/'templates/.zshrc').read_text(), re.M | re.S).group()
with tempfile.TemporaryDirectory(prefix='attended-stage-', dir=os.environ.get('WORKFLOW_TEST_TMP')) as temporary:
    root = Path(temporary)
    home, source = root/'home', root/'source'
    (source/'opencode-attended-plugin').mkdir(parents=True)
    home.mkdir()
    launcher_source = source/'opencode-attended'
    launcher_source.write_text('#!/bin/sh\nprintf "attended:%s" "$*"\n')
    launcher_source.chmod(0o700)
    (source/'opencode-attended-plugin/tui.js').write_text('export default {setup(){}};\n')
    env = dict(os.environ, HOME=str(home), SOURCE=str(source))
    script = 'warn(){ echo "$*" >&2; }; agent_inbox_adapter(){ echo "$SOURCE/agent-inbox-mcp"; };\n'+stage+'\nsync_opencode_attended_stage'
    def run():
        return subprocess.run(['bash', '-euc', script], env=env, text=True, capture_output=True)
    switch = home/'.config/agent-workflow/opencode-attended.json'
    module = home/'.config/opencode/plugins/dots-attended-inbox/tui.js'
    launcher = home/'.local/bin/opencode-attended'
    assert run().returncode == 0
    assert not launcher.exists() and not module.exists()
    switch.parent.mkdir(parents=True)
    switch.write_text(json.dumps({'schema': 1, 'staged': True, 'enabled': False}))
    assert run().returncode == 0
    assert launcher.is_symlink() and launcher.resolve() == launcher_source
    assert module.read_text().startswith('// dots-managed attended inbox stage\n')
    assert module.stat().st_mode & 0o777 == 0o600
    before = module.stat().st_mtime_ns
    assert run().returncode == 0 and module.stat().st_mtime_ns == before
    native = root/'bin'
    native.mkdir()
    (native/'opencode').write_text('#!/bin/sh\nprintf "native:%s" "$*"\n')
    (native/'opencode').chmod(0o700)
    env['PATH'] = str(native)+':'+env['PATH']
    def invoke():
        return subprocess.check_output(['zsh', '-fc', shell+'\nopencode project'], env=env, text=True)
    assert invoke() == 'native:project', 'stage is not default activation'
    switch.write_text(json.dumps({'schema': 1, 'staged': True, 'enabled': True}))
    assert invoke() == 'attended:project'
    switch.write_text(json.dumps({'schema': 1, 'enabled': False}))
    assert invoke() == 'native:project', 'rollback affects future shell calls'
    module.write_text('foreign module\n')
    switch.write_text(json.dumps({'schema': 1, 'staged': True}))
    assert run().returncode != 0 and module.read_text() == 'foreign module\n'
print('opencode-attended-stage-test: ok')
